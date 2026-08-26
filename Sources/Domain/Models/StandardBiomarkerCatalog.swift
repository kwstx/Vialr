import Foundation

/// Represents a standardized clinical biomarker definition in the reference catalog.
public struct StandardBiomarkerDefinition: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let standardUnit: String
    public let category: LabCategory
    public let defaultReferenceMin: Double?
    public let defaultReferenceMax: Double?
    public let referenceRangeText: String?
    public let aliases: [String]
    public let description: String
    public let isCommon: Bool

    public init(
        id: String,
        name: String,
        standardUnit: String,
        category: LabCategory,
        defaultReferenceMin: Double? = nil,
        defaultReferenceMax: Double? = nil,
        referenceRangeText: String? = nil,
        aliases: [String] = [],
        description: String = "",
        isCommon: Bool = false
    ) {
        self.id = id
        self.name = name
        self.standardUnit = standardUnit
        self.category = category
        self.defaultReferenceMin = defaultReferenceMin
        self.defaultReferenceMax = defaultReferenceMax
        self.referenceRangeText = referenceRangeText
        self.aliases = aliases
        self.description = description
        self.isCommon = isCommon
    }

    /// Evaluates whether a given numeric value falls within normal reference bounds.
    public func evaluateFlag(value: Double) -> LabResultFlag {
        if let min = defaultReferenceMin, value < min {
            // Check critical bounds (e.g. < 50% min)
            if value < min * 0.5 { return .criticalLow }
            return .low
        }
        if let max = defaultReferenceMax, value > max {
            // Check critical bounds (e.g. > 150% max)
            if value > max * 1.5 { return .criticalHigh }
            return .high
        }
        return .inRange
    }
}

/// Comprehensive built-in catalog of standard clinical biomarkers used across bloodwork panels.
public struct StandardBiomarkerCatalog: Sendable {
    public static let shared = StandardBiomarkerCatalog()

    public let allBiomarkers: [StandardBiomarkerDefinition]

    public init() {
        self.allBiomarkers = Self.buildCatalog()
    }

    /// Searches the catalog by query against biomarker name, aliases, description, and category.
    public func search(query: String, category: LabCategory? = nil) -> [StandardBiomarkerDefinition] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        var filtered = allBiomarkers
        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }

        if cleaned.isEmpty {
            return filtered.sorted { (a, b) -> Bool in
                if a.isCommon != b.isCommon { return a.isCommon && !b.isCommon }
                return a.name < b.name
            }
        }

        return filtered.compactMap { marker -> (marker: StandardBiomarkerDefinition, score: Int)? in
            let nameLower = marker.name.lowercased()
            let idLower = marker.id.lowercased()
            
            // Exact match gets highest priority
            if nameLower == cleaned || idLower == cleaned {
                return (marker, 100)
            }
            // Starts with query
            if nameLower.hasPrefix(cleaned) {
                return (marker, 80)
            }
            // Alias exact match
            if marker.aliases.contains(where: { $0.lowercased() == cleaned }) {
                return (marker, 75)
            }
            // Name contains query
            if nameLower.contains(cleaned) {
                return (marker, 60)
            }
            // Alias contains query
            if marker.aliases.contains(where: { $0.lowercased().contains(cleaned) }) {
                return (marker, 50)
            }
            // Description contains query
            if marker.description.lowercased().contains(cleaned) {
                return (marker, 30)
            }
            return nil
        }
        .sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.marker.isCommon != $1.marker.isCommon { return $0.marker.isCommon && !$1.marker.isCommon }
            return $0.marker.name < $1.marker.name
        }
        .map { $0.marker }
    }

    /// Looks up a standard biomarker by its unique ID or exact name/alias.
    public func find(identifier: String) -> StandardBiomarkerDefinition? {
        let target = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allBiomarkers.first {
            $0.id.lowercased() == target ||
            $0.name.lowercased() == target ||
            $0.aliases.contains(where: { $0.lowercased() == target })
        }
    }

    // MARK: - Built-in Biomarker Seed Catalog
    private static func buildCatalog() -> [StandardBiomarkerDefinition] {
        [
            // MARK: - 1. Hormones & Endocrine
            StandardBiomarkerDefinition(
                id: "total_testosterone",
                name: "Total Testosterone",
                standardUnit: "ng/dL",
                category: .hormones,
                defaultReferenceMin: 300,
                defaultReferenceMax: 1000,
                referenceRangeText: "300 – 1000 ng/dL",
                aliases: ["Testosterone, Total", "Total T", "TT", "Serum Testosterone"],
                description: "Primary androgenic hormone influencing muscle protein synthesis, bone density, libido, and erythropoiesis.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "free_testosterone",
                name: "Free Testosterone",
                standardUnit: "pg/mL",
                category: .hormones,
                defaultReferenceMin: 9.0,
                defaultReferenceMax: 30.0,
                referenceRangeText: "9.0 – 30.0 pg/mL",
                aliases: ["Free T", "FT", "Direct Free Testosterone", "Calculated Free Testosterone"],
                description: "Unbound, biologically active fraction of testosterone available to cellular androgen receptors.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "estradiol_sensitive",
                name: "Estradiol (Sensitive / LC-MS)",
                standardUnit: "pg/mL",
                category: .hormones,
                defaultReferenceMin: 15.0,
                defaultReferenceMax: 40.0,
                referenceRangeText: "15.0 – 40.0 pg/mL",
                aliases: ["Estradiol", "E2", "Sensitive E2", "17-Beta Estradiol", "Serum Estradiol"],
                description: "Primary estrogenic hormone regulating joint lubrication, cardiovascular health, mood, and bone mineral density.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "shbg",
                name: "Sex Hormone Binding Globulin (SHBG)",
                standardUnit: "nmol/L",
                category: .hormones,
                defaultReferenceMin: 16.5,
                defaultReferenceMax: 55.9,
                referenceRangeText: "16.5 – 55.9 nmol/L",
                aliases: ["SHBG", "Sex Hormone-Binding Globulin", "TeBG"],
                description: "High-affinity glycoprotein that binds and transports sex steroids, dictating bioavailable androgen ratios.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "dhea_sulfate",
                name: "DHEA-Sulfate",
                standardUnit: "ug/dL",
                category: .hormones,
                defaultReferenceMin: 160,
                defaultReferenceMax: 450,
                referenceRangeText: "160 – 450 ug/dL",
                aliases: ["DHEA-S", "DHEAS", "Dehydroepiandrosterone Sulfate"],
                description: "Major adrenal androgen precursor reflecting adrenal output and longevity status.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "progesterone",
                name: "Progesterone",
                standardUnit: "ng/mL",
                category: .hormones,
                defaultReferenceMin: 0.1,
                defaultReferenceMax: 0.8,
                referenceRangeText: "0.1 – 0.8 ng/mL (male)",
                aliases: ["Serum Progesterone", "P4"],
                description: "Neurosteroid and steroid hormone modulating GABA receptors and neuroprotection."
            ),
            StandardBiomarkerDefinition(
                id: "prolactin",
                name: "Prolactin",
                standardUnit: "ng/mL",
                category: .hormones,
                defaultReferenceMin: 4.0,
                defaultReferenceMax: 15.2,
                referenceRangeText: "4.0 – 15.2 ng/mL",
                aliases: ["PRL", "Serum Prolactin"],
                description: "Pituitary hormone; elevated levels can suppress gonadotropins and blunt libido."
            ),
            StandardBiomarkerDefinition(
                id: "cortisol_am",
                name: "Cortisol (Morning / AM)",
                standardUnit: "ug/dL",
                category: .hormones,
                defaultReferenceMin: 6.2,
                defaultReferenceMax: 19.4,
                referenceRangeText: "6.2 – 19.4 ug/dL",
                aliases: ["Cortisol", "AM Cortisol", "Serum Cortisol"],
                description: "Primary glucocorticoid stress hormone regulating circadian rhythm, glucose mobilization, and immune response.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "igf_1",
                name: "IGF-1 (Somatomedin C)",
                standardUnit: "ng/mL",
                category: .hormones,
                defaultReferenceMin: 115,
                defaultReferenceMax: 307,
                referenceRangeText: "115 – 307 ng/mL",
                aliases: ["IGF1", "Insulin-Like Growth Factor 1", "Somatomedin C", "IGF-I"],
                description: "Direct downstream mediator of growth hormone (GH) secretagogues, tissue regeneration, and cellular hypertrophy.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "growth_hormone",
                name: "Growth Hormone (GH)",
                standardUnit: "ng/mL",
                category: .hormones,
                defaultReferenceMin: 0.05,
                defaultReferenceMax: 3.0,
                referenceRangeText: "0.05 – 3.0 ng/mL",
                aliases: ["GH", "Human Growth Hormone", "HGH", "Somatotropin"],
                description: "Pulsatile anterior pituitary hormone driving lipolysis and hepatic IGF-1 synthesis."
            ),
            StandardBiomarkerDefinition(
                id: "luteinizing_hormone",
                name: "Luteinizing Hormone (LH)",
                standardUnit: "mIU/mL",
                category: .hormones,
                defaultReferenceMin: 1.7,
                defaultReferenceMax: 8.6,
                referenceRangeText: "1.7 – 8.6 mIU/mL",
                aliases: ["LH", "Serum LH", "Lutropin"],
                description: "Pituitary gonadotropin stimulating Leydig cells for endogenous testosterone synthesis.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "fsh",
                name: "Follicle-Stimulating Hormone (FSH)",
                standardUnit: "mIU/mL",
                category: .hormones,
                defaultReferenceMin: 1.5,
                defaultReferenceMax: 12.4,
                referenceRangeText: "1.5 – 12.4 mIU/mL",
                aliases: ["FSH", "Serum FSH", "Follitropin"],
                description: "Pituitary gonadotropin supporting Sertoli cell function and spermatogenesis."
            ),

            // MARK: - 2. Metabolic & Glucose
            StandardBiomarkerDefinition(
                id: "fasting_glucose",
                name: "Fasting Blood Glucose",
                standardUnit: "mg/dL",
                category: .metabolic,
                defaultReferenceMin: 70,
                defaultReferenceMax: 99,
                referenceRangeText: "70 – 99 mg/dL",
                aliases: ["Fasting Glucose", "Glucose, Serum", "Blood Sugar", "FBS"],
                description: "Circulating serum glucose after an 8–12 hr fast; central marker for insulin sensitivity.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "fasting_insulin",
                name: "Fasting Insulin",
                standardUnit: "uIU/mL",
                category: .metabolic,
                defaultReferenceMin: 2.0,
                defaultReferenceMax: 6.0,
                referenceRangeText: "2.0 – 6.0 uIU/mL (optimal < 5.0)",
                aliases: ["Insulin, Fasting", "Serum Insulin", "Fasting Serum Insulin"],
                description: "Basal pancreatic insulin secretion; early warning indicator for metabolic syndrome and insulin resistance.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "hba1c",
                name: "Hemoglobin A1c (HbA1c)",
                standardUnit: "%",
                category: .metabolic,
                defaultReferenceMin: 4.5,
                defaultReferenceMax: 5.6,
                referenceRangeText: "< 5.7 %",
                aliases: ["HbA1c", "A1c", "Glycated Hemoglobin", "Glycohemoglobin"],
                description: "Percentage of glycated hemoglobin reflecting the average 90-day glycemic control.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "homa_ir",
                name: "HOMA-IR (Homeostatic Model Assessment)",
                standardUnit: "index",
                category: .metabolic,
                defaultReferenceMin: 0.5,
                defaultReferenceMax: 1.5,
                referenceRangeText: "< 1.5 (Optimal < 1.0)",
                aliases: ["HOMA-IR", "HOMA Index", "Insulin Resistance Index"],
                description: "Calculated ratio of fasting glucose and fasting insulin evaluating peripheral insulin resistance.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "c_peptide",
                name: "C-Peptide",
                standardUnit: "ng/mL",
                category: .metabolic,
                defaultReferenceMin: 1.1,
                defaultReferenceMax: 4.4,
                referenceRangeText: "1.1 – 4.4 ng/mL",
                aliases: ["Connecting Peptide", "Serum C-Peptide"],
                description: "Equimolar byproduct of proinsulin cleavage indicating endogenous pancreatic beta-cell reserve."
            ),

            // MARK: - 3. Lipid Panel & Cardiovascular
            StandardBiomarkerDefinition(
                id: "total_cholesterol",
                name: "Total Cholesterol",
                standardUnit: "mg/dL",
                category: .lipids,
                defaultReferenceMin: 125,
                defaultReferenceMax: 200,
                referenceRangeText: "< 200 mg/dL",
                aliases: ["Cholesterol, Total", "Total Chol"],
                description: "Aggregate measure of cholesterol carried in all lipoprotein particles.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "ldl_cholesterol",
                name: "LDL-C (Calculated / Direct)",
                standardUnit: "mg/dL",
                category: .lipids,
                defaultReferenceMin: 50,
                defaultReferenceMax: 100,
                referenceRangeText: "< 100 mg/dL (optimal < 70)",
                aliases: ["LDL", "LDL-C", "Low-Density Lipoprotein", "Direct LDL"],
                description: "Low-density lipoprotein cholesterol content; primary target for atherogenic risk evaluation.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "hdl_cholesterol",
                name: "HDL-C (High-Density Lipoprotein)",
                standardUnit: "mg/dL",
                category: .lipids,
                defaultReferenceMin: 40,
                defaultReferenceMax: 80,
                referenceRangeText: "> 40 mg/dL (optimal > 50)",
                aliases: ["HDL", "HDL-C", "High-Density Lipoprotein Cholesterol"],
                description: "Reverse cholesterol transport particle aiding vascular clearance.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "triglycerides",
                name: "Triglycerides",
                standardUnit: "mg/dL",
                category: .lipids,
                defaultReferenceMin: 40,
                defaultReferenceMax: 150,
                referenceRangeText: "< 150 mg/dL (optimal < 90)",
                aliases: ["Trigs", "Serum Triglycerides", "TG"],
                description: "Circulating blood fats derived from diet and hepatic lipogenesis; strong marker for hepatic insulin resistance.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "apob",
                name: "Apolipoprotein B (ApoB)",
                standardUnit: "mg/dL",
                category: .lipids,
                defaultReferenceMin: 50,
                defaultReferenceMax: 90,
                referenceRangeText: "< 90 mg/dL (optimal < 70)",
                aliases: ["ApoB", "Apo B", "Apolipoprotein B-100"],
                description: "Direct particle count of all atherogenic lipoproteins (LDL, VLDL, IDL, Lp(a)); superior to LDL-C for cardiovascular risk.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "lipoprotein_a",
                name: "Lipoprotein(a) / Lp(a)",
                standardUnit: "nmol/L",
                category: .lipids,
                defaultReferenceMin: 0,
                defaultReferenceMax: 75,
                referenceRangeText: "< 75 nmol/L (< 30 mg/dL)",
                aliases: ["Lp(a)", "Lipoprotein (a)", "LPA"],
                description: "Genetically determined atherogenic and thrombogenic variant particle carrying Apo(a)."
            ),
            StandardBiomarkerDefinition(
                id: "hs_crp",
                name: "High-Sensitivity CRP (hs-CRP)",
                standardUnit: "mg/L",
                category: .inflammatory,
                defaultReferenceMin: 0.1,
                defaultReferenceMax: 1.0,
                referenceRangeText: "< 1.0 mg/L (optimal < 0.5)",
                aliases: ["hs-CRP", "hsCRP", "High Sensitivity C-Reactive Protein", "Cardio CRP"],
                description: "Hepatic acute-phase reactant measuring baseline systemic vascular and tissue inflammation.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "homocysteine",
                name: "Homocysteine",
                standardUnit: "umol/L",
                category: .lipids,
                defaultReferenceMin: 5.0,
                defaultReferenceMax: 11.0,
                referenceRangeText: "5.0 – 11.0 umol/L (optimal < 9.0)",
                aliases: ["Serum Homocysteine", "HCY"],
                description: "Sulfur amino acid intermediate indicating methylation efficiency and endothelial integrity."
            ),

            // MARK: - 4. Complete Blood Count (CBC)
            StandardBiomarkerDefinition(
                id: "wbc",
                name: "White Blood Cell Count (WBC)",
                standardUnit: "x10E3/uL",
                category: .cbcHematology,
                defaultReferenceMin: 4.0,
                defaultReferenceMax: 10.5,
                referenceRangeText: "4.0 – 10.5 x10E3/uL",
                aliases: ["WBC", "White Blood Count", "Leukocytes"],
                description: "Total circulating immune cells reflecting infection, inflammation, or bone marrow stimulation.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "rbc",
                name: "Red Blood Cell Count (RBC)",
                standardUnit: "x10E6/uL",
                category: .cbcHematology,
                defaultReferenceMin: 4.14,
                defaultReferenceMax: 5.80,
                referenceRangeText: "4.14 – 5.80 x10E6/uL",
                aliases: ["RBC", "Red Blood Count", "Erythrocytes"],
                description: "Total erythrocytes carrying oxygen throughout capillary beds.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "hemoglobin",
                name: "Hemoglobin",
                standardUnit: "g/dL",
                category: .cbcHematology,
                defaultReferenceMin: 13.0,
                defaultReferenceMax: 17.5,
                referenceRangeText: "13.0 – 17.5 g/dL",
                aliases: ["Hgb", "Hb", "Hemoglobin A"],
                description: "Iron-rich metalloprotein inside red cells responsible for oxygen transport.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "hematocrit",
                name: "Hematocrit",
                standardUnit: "%",
                category: .cbcHematology,
                defaultReferenceMin: 38.5,
                defaultReferenceMax: 50.0,
                referenceRangeText: "38.5 – 50.0 % (alert > 52.0%)",
                aliases: ["Hct", "PCV", "Packed Cell Volume"],
                description: "Percentage volume of whole blood composed of red blood cells; critical safety metric during androgen and peptide protocols.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "platelets",
                name: "Platelets (Thrombocytes)",
                standardUnit: "x10E3/uL",
                category: .cbcHematology,
                defaultReferenceMin: 140,
                defaultReferenceMax: 400,
                referenceRangeText: "140 – 400 x10E3/uL",
                aliases: ["Platelet Count", "PLT", "Thrombocytes"],
                description: "Cell fragments essential for hemostasis and vascular clotting.",
                isCommon: true
            ),

            // MARK: - 5. Liver & Hepatic Function
            StandardBiomarkerDefinition(
                id: "alt",
                name: "ALT (Alanine Aminotransferase)",
                standardUnit: "IU/L",
                category: .liverHepatic,
                defaultReferenceMin: 9,
                defaultReferenceMax: 44,
                referenceRangeText: "9 – 44 IU/L (optimal < 30)",
                aliases: ["ALT", "SGPT", "Alanine Transaminase"],
                description: "Liver-specific enzyme released during hepatocyte stress or cell turnover.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "ast",
                name: "AST (Aspartate Aminotransferase)",
                standardUnit: "IU/L",
                category: .liverHepatic,
                defaultReferenceMin: 10,
                defaultReferenceMax: 40,
                referenceRangeText: "10 – 40 IU/L",
                aliases: ["AST", "SGOT", "Aspartate Transaminase"],
                description: "Enzyme present in liver, cardiac, and skeletal muscle cells; can elevate post intense eccentric resistance training.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "alp",
                name: "Alkaline Phosphatase (ALP)",
                standardUnit: "IU/L",
                category: .liverHepatic,
                defaultReferenceMin: 44,
                defaultReferenceMax: 121,
                referenceRangeText: "44 – 121 IU/L",
                aliases: ["ALP", "Alk Phos"],
                description: "Enzyme associated with bile ducts and osteoblastic bone remodeling."
            ),
            StandardBiomarkerDefinition(
                id: "bilirubin_total",
                name: "Total Bilirubin",
                standardUnit: "mg/dL",
                category: .liverHepatic,
                defaultReferenceMin: 0.2,
                defaultReferenceMax: 1.2,
                referenceRangeText: "0.2 – 1.2 mg/dL",
                aliases: ["Total Bili", "Bilirubin, Total"],
                description: "Breakdown product of hemoglobin processed by the liver.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "ggt",
                name: "GGT (Gamma-Glutamyl Transferase)",
                standardUnit: "IU/L",
                category: .liverHepatic,
                defaultReferenceMin: 9,
                defaultReferenceMax: 48,
                referenceRangeText: "9 – 48 IU/L",
                aliases: ["GGT", "GGTP", "Gamma-Glutamyl Transpeptidase"],
                description: "Sensitive biliary and hepatic microsomal enzyme; excellent indicator for oxidative stress and glutathione turnover."
            ),

            // MARK: - 6. Kidney & Renal Function
            StandardBiomarkerDefinition(
                id: "creatinine",
                name: "Creatinine",
                standardUnit: "mg/dL",
                category: .kidneyRenal,
                defaultReferenceMin: 0.70,
                defaultReferenceMax: 1.30,
                referenceRangeText: "0.70 – 1.30 mg/dL",
                aliases: ["Serum Creatinine", "Creat", "Cr"],
                description: "Waste product of muscle creatine breakdown filtered by renal glomeruli.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "egfr",
                name: "eGFR (Estimated Glomerular Filtration Rate)",
                standardUnit: "mL/min/1.73m2",
                category: .kidneyRenal,
                defaultReferenceMin: 60,
                defaultReferenceMax: 120,
                referenceRangeText: "> 60 mL/min/1.73m2 (optimal > 90)",
                aliases: ["eGFR", "GFR", "Estimated GFR"],
                description: "Calculated index of renal filtration efficiency.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "bun",
                name: "BUN (Blood Urea Nitrogen)",
                standardUnit: "mg/dL",
                category: .kidneyRenal,
                defaultReferenceMin: 7,
                defaultReferenceMax: 20,
                referenceRangeText: "7 – 20 mg/dL",
                aliases: ["BUN", "Urea Nitrogen"],
                description: "End product of dietary and systemic protein metabolism excreted by the kidneys.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "cystatin_c",
                name: "Cystatin C",
                standardUnit: "mg/L",
                category: .kidneyRenal,
                defaultReferenceMin: 0.60,
                defaultReferenceMax: 0.99,
                referenceRangeText: "0.60 – 0.99 mg/L",
                aliases: ["Cystatin-C", "Serum Cystatin C"],
                description: "Protease inhibitor filtered by glomeruli that is independent of muscle mass or dietary creatine intake."
            ),

            // MARK: - 7. Thyroid Panel
            StandardBiomarkerDefinition(
                id: "tsh",
                name: "TSH (Thyroid Stimulating Hormone)",
                standardUnit: "uIU/mL",
                category: .thyroid,
                defaultReferenceMin: 0.45,
                defaultReferenceMax: 4.50,
                referenceRangeText: "0.45 – 4.50 uIU/mL (optimal 1.0 – 2.0)",
                aliases: ["TSH", "Thyrotropin", "Serum TSH"],
                description: "Pituitary hormone orchestrating thyroid gland hormone production and basal metabolic rate.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "free_t3",
                name: "Free T3 (Triiodothyronine)",
                standardUnit: "pg/mL",
                category: .thyroid,
                defaultReferenceMin: 2.0,
                defaultReferenceMax: 4.4,
                referenceRangeText: "2.0 – 4.4 pg/mL (optimal > 3.2)",
                aliases: ["FT3", "Free Triiodothyronine"],
                description: "Active thyroid hormone regulating mitochondrial uncoupling, body temperature, and cellular energy.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "free_t4",
                name: "Free T4 (Thyroxine)",
                standardUnit: "ng/dL",
                category: .thyroid,
                defaultReferenceMin: 0.82,
                defaultReferenceMax: 1.77,
                referenceRangeText: "0.82 – 1.77 ng/dL",
                aliases: ["FT4", "Free Thyroxine"],
                description: "Primary prohormone output of the thyroid gland, converted peripherally to Free T3.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "reverse_t3",
                name: "Reverse T3 (rT3)",
                standardUnit: "ng/dL",
                category: .thyroid,
                defaultReferenceMin: 9.0,
                defaultReferenceMax: 24.0,
                referenceRangeText: "9.0 – 24.0 ng/dL (optimal < 15.0)",
                aliases: ["rT3", "Reverse Triiodothyronine"],
                description: "Inactive thyroid isomer produced during systemic stress or severe caloric deficit."
            ),

            // MARK: - 8. Vitamins, Minerals & Micronutrients
            StandardBiomarkerDefinition(
                id: "vitamin_d",
                name: "Vitamin D (25-Hydroxy)",
                standardUnit: "ng/mL",
                category: .vitaminsElectrolytes,
                defaultReferenceMin: 30.0,
                defaultReferenceMax: 100.0,
                referenceRangeText: "30.0 – 100.0 ng/mL (optimal 50 – 80)",
                aliases: ["25-OH Vitamin D", "Vitamin D3", "Calcidiol"],
                description: "Secosteroid hormone regulating calcium homeostasis, immune signaling, and steroidogenesis.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "vitamin_b12",
                name: "Vitamin B12 (Cobalamin)",
                standardUnit: "pg/mL",
                category: .vitaminsElectrolytes,
                defaultReferenceMin: 200,
                defaultReferenceMax: 1100,
                referenceRangeText: "200 – 1100 pg/mL (optimal > 500)",
                aliases: ["B12", "Cobalamin", "Serum B12"],
                description: "Crucial cofactor for myelin synthesis, RBC production, and one-carbon methylation.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "ferritin",
                name: "Serum Ferritin",
                standardUnit: "ng/mL",
                category: .vitaminsElectrolytes,
                defaultReferenceMin: 30,
                defaultReferenceMax: 400,
                referenceRangeText: "30 – 400 ng/mL (optimal 70 – 150)",
                aliases: ["Ferritin", "Iron Storage"],
                description: "Primary intracellular iron storage protein; acute-phase reactant.",
                isCommon: true
            ),
            StandardBiomarkerDefinition(
                id: "iron_serum",
                name: "Serum Iron",
                standardUnit: "ug/dL",
                category: .vitaminsElectrolytes,
                defaultReferenceMin: 50,
                defaultReferenceMax: 180,
                referenceRangeText: "50 – 180 ug/dL",
                aliases: ["Iron", "Total Serum Iron"],
                description: "Circulating iron bound to transferrin in serum."
            ),
            StandardBiomarkerDefinition(
                id: "psa_total",
                name: "Prostate-Specific Antigen (PSA, Total)",
                standardUnit: "ng/mL",
                category: .hormones,
                defaultReferenceMin: 0.0,
                defaultReferenceMax: 4.0,
                referenceRangeText: "< 4.0 ng/mL (optimal < 1.0)",
                aliases: ["PSA", "Total PSA", "Prostate Specific Antigen"],
                description: "Glycoprotein enzyme secreted by prostate epithelial cells; key safety marker during hormone protocols.",
                isCommon: true
            )
        ]
    }
}
