import Foundation
import Domain

/// Provides realistic, pre-populated seed data for Vialr demonstrations, tests, and preview canvases.
public struct MockDataFactory: Sendable {
    public init() {}

    // MARK: - Compounds
    public var defaultCompounds: [Compound] {
        [
            Compound(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "BPC-157",
                shortCode: "BPC",
                category: .recovery,
                defaultUnit: .mcg,
                typicalDose: 250,
                halfLifeHours: 4.0,
                description: "Body Protection Compound-157. Known for tendon, ligament, and gut mucosal tissue healing.",
                administrationRoute: .subcutaneous,
                storageCondition: .refrigerated,
                tags: ["Healing", "Tendons", "Gut Health"]
            ),
            Compound(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "TB-500 (Thymosin Beta-4)",
                shortCode: "TB4",
                category: .recovery,
                defaultUnit: .mg,
                typicalDose: 2.5,
                halfLifeHours: 24.0,
                description: "Promotes cellular migration, angiogenesis, and deep muscular repair.",
                administrationRoute: .subcutaneous,
                storageCondition: .refrigerated,
                tags: ["Systemic Repair", "Muscle", "Wound Healing"]
            ),
            Compound(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                name: "Tirzepatide",
                shortCode: "TRZ",
                category: .glp1Metabolic,
                defaultUnit: .mg,
                typicalDose: 5.0,
                halfLifeHours: 120.0, // 5 days
                description: "Dual GLP-1 and GIP receptor agonist for glycemic control and metabolic optimization.",
                administrationRoute: .subcutaneous,
                storageCondition: .refrigerated,
                tags: ["GLP-1", "GIP", "Metabolic", "Insulin Sensitivity"]
            ),
            Compound(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                name: "CJC-1295 / Ipamorelin",
                shortCode: "CJC/IPA",
                category: .growthHormoneSecretagogue,
                defaultUnit: .mcg,
                typicalDose: 300,
                halfLifeHours: 2.0,
                description: "Synergistic GHRH + Ghrelin mimetic blend for natural nocturnal growth hormone release.",
                administrationRoute: .subcutaneous,
                storageCondition: .refrigerated,
                tags: ["GH Pulse", "Deep Sleep", "Collagen"]
            ),
            Compound(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                name: "GHK-Cu",
                shortCode: "GHK",
                category: .cosmeticSkin,
                defaultUnit: .mg,
                typicalDose: 2.0,
                halfLifeHours: 1.0,
                description: "Copper tripeptide involved in skin remodeling, collagen synthesis, and anti-fibrotic action.",
                administrationRoute: .subcutaneous,
                storageCondition: .refrigerated,
                tags: ["Skin", "Collagen", "Anti-Aging"]
            ),
            Compound(
                id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
                name: "NAD+",
                shortCode: "NAD",
                category: .longevityNootropic,
                defaultUnit: .mg,
                typicalDose: 50.0,
                halfLifeHours: 4.0,
                description: "Nicotinamide adenine dinucleotide for cellular energy and mitochondrial biogenesis.",
                administrationRoute: .subcutaneous,
                storageCondition: .refrigerated,
                tags: ["Cellular Energy", "Mitochondria", "Longevity"]
            )
        ]
    }

    // MARK: - Protocols
    public var defaultProtocols: [ProtocolModel] {
        let bpcId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let tbId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let cjcId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let trzId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

        let cal = Calendar.current
        let now = Date()
        let startDate = cal.date(byAdding: .day, value: -21, to: now) ?? now

        return [
            ProtocolModel(
                id: UUID(uuidString: "aaaa1111-aaaa-1111-aaaa-111111111111")!,
                name: "Wolverine Tissue Healing Stack",
                goalSummary: "Targeted shoulder rotator cuff tendon and labrum recovery.",
                status: .active,
                items: [
                    ProtocolItem(
                        id: UUID(uuidString: "item-bpc-1")!,
                        compoundId: bpcId,
                        compoundName: "BPC-157",
                        doseAmount: 250,
                        doseUnit: .mcg,
                        scheduleRule: .everyDay,
                        preferredTimeOfDay: .morning,
                        preferredRoute: .subcutaneous,
                        notes: "Administer near shoulder or abdomen SubQ"
                    ),
                    ProtocolItem(
                        id: UUID(uuidString: "item-tb-1")!,
                        compoundId: tbId,
                        compoundName: "TB-500",
                        doseAmount: 2.5,
                        doseUnit: .mg,
                        scheduleRule: .daysOfWeek([2, 5]), // Mon, Thu
                        preferredTimeOfDay: .evening,
                        preferredRoute: .subcutaneous,
                        notes: "Twice weekly loading phase"
                    )
                ],
                startDate: startDate,
                endDate: cal.date(byAdding: .day, value: 42, to: startDate),
                notes: "Review with orthopedic physical therapist at week 6.",
                colorHex: "#10B981"
            ),
            ProtocolModel(
                id: UUID(uuidString: "bbbb2222-bbbb-2222-bbbb-222222222222")!,
                name: "Nocturnal GH Optimization",
                goalSummary: "Enhance Stage 3/4 slow-wave sleep and recovery.",
                status: .active,
                items: [
                    ProtocolItem(
                        id: UUID(uuidString: "item-cjc-1")!,
                        compoundId: cjcId,
                        compoundName: "CJC-1295 / Ipamorelin",
                        doseAmount: 300,
                        doseUnit: .mcg,
                        scheduleRule: .cycle(daysOn: 5, daysOff: 2),
                        preferredTimeOfDay: .evening,
                        preferredRoute: .subcutaneous,
                        notes: "Take 90 minutes after last food intake before sleep"
                    )
                ],
                startDate: startDate,
                colorHex: "#8B5CF6"
            ),
            ProtocolModel(
                id: UUID(uuidString: "cccc3333-cccc-3333-cccc-333333333333")!,
                name: "Metabolic & Insulin Modulation",
                goalSummary: "Maintain glucose stability and lean body composition.",
                status: .paused,
                items: [
                    ProtocolItem(
                        id: UUID(uuidString: "item-trz-1")!,
                        compoundId: trzId,
                        compoundName: "Tirzepatide",
                        doseAmount: 5.0,
                        doseUnit: .mg,
                        scheduleRule: .everyNDays(7),
                        preferredTimeOfDay: .morning,
                        preferredRoute: .subcutaneous,
                        notes: "Sunday morning dose"
                    )
                ],
                startDate: cal.date(byAdding: .day, value: -60, to: now) ?? now,
                endDate: cal.date(byAdding: .day, value: -10, to: now),
                colorHex: "#06B6D4"
            )
        ]
    }

    // MARK: - Vials
    public var defaultVials: [Vial] {
        let bpcId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let tbId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let cjcId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let trzId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

        let cal = Calendar.current
        let now = Date()

        return [
            Vial(
                id: UUID(uuidString: "vial-bpc-1")!,
                compoundId: bpcId,
                compoundName: "BPC-157",
                lotNumber: "LOT-9821A",
                vendor: "Precision Peptides",
                totalDryMassMg: 5.0,
                bacWaterAddedMl: 2.0,
                currentVolumeRemainingMl: 1.2,
                isReconstituted: true,
                reconstitutedDate: cal.date(byAdding: .day, value: -12, to: now),
                expirationDate: cal.date(byAdding: .day, value: 16, to: now),
                costUsd: 48.0,
                status: .reconstituted
            ),
            Vial(
                id: UUID(uuidString: "vial-tb-1")!,
                compoundId: tbId,
                compoundName: "TB-500",
                lotNumber: "LOT-4412B",
                vendor: "Precision Peptides",
                totalDryMassMg: 10.0,
                bacWaterAddedMl: 2.0,
                currentVolumeRemainingMl: 1.5,
                isReconstituted: true,
                reconstitutedDate: cal.date(byAdding: .day, value: -10, to: now),
                expirationDate: cal.date(byAdding: .day, value: 18, to: now),
                costUsd: 75.0,
                status: .reconstituted
            ),
            Vial(
                id: UUID(uuidString: "vial-cjc-1")!,
                compoundId: cjcId,
                compoundName: "CJC-1295 / Ipamorelin (5mg/5mg)",
                lotNumber: "LOT-7731C",
                vendor: "BioTech Research",
                totalDryMassMg: 10.0,
                bacWaterAddedMl: 3.0,
                currentVolumeRemainingMl: 2.1,
                isReconstituted: true,
                reconstitutedDate: cal.date(byAdding: .day, value: -8, to: now),
                expirationDate: cal.date(byAdding: .day, value: 20, to: now),
                costUsd: 85.0,
                status: .reconstituted
            ),
            Vial(
                id: UUID(uuidString: "vial-trz-dry")!,
                compoundId: trzId,
                compoundName: "Tirzepatide (Dry Reserve)",
                lotNumber: "LOT-1092D",
                vendor: "Apex Lab",
                totalDryMassMg: 15.0,
                bacWaterAddedMl: nil,
                currentVolumeRemainingMl: nil,
                isReconstituted: false,
                costUsd: 110.0,
                status: .unopened
            )
        ]
    }

    // MARK: - Supplies
    public var defaultSupplies: [SupplyItem] {
        [
            SupplyItem(
                name: "EasyTouch U-100 31G 5/16\" 0.5mL",
                category: .syringes,
                quantityRemaining: 68,
                packageUnit: "100-pack",
                reorderThreshold: 20,
                costUsd: 22.0
            ),
            SupplyItem(
                name: "Hospira Bacteriostatic Water 30mL",
                category: .bacWater,
                quantityRemaining: 2,
                packageUnit: "30mL Vials",
                reorderThreshold: 1,
                costUsd: 18.0
            ),
            SupplyItem(
                name: "BD 21G 1.5\" Mixing Needles",
                category: .needles,
                quantityRemaining: 14,
                packageUnit: "50-pack",
                reorderThreshold: 10,
                costUsd: 12.0
            ),
            SupplyItem(
                name: "Alcohol Prep Pads (70% IPA)",
                category: .prepPads,
                quantityRemaining: 180,
                packageUnit: "200-box",
                reorderThreshold: 30,
                costUsd: 8.50
            )
        ]
    }

    // MARK: - Dose Logs (Past 14 days + Today's Scheduled)
    public var defaultDoseLogs: [DoseLog] {
        let cal = Calendar.current
        let now = Date()
        let bpcId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let cjcId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let protoId = UUID(uuidString: "aaaa1111-aaaa-1111-aaaa-111111111111")!
        let vialBpcId = UUID(uuidString: "vial-bpc-1")!
        let vialCjcId = UUID(uuidString: "vial-cjc-1")!

        var logs: [DoseLog] = []

        let sites = [
            ("ab_l_uo", "Abdomen - Left Upper Outer"),
            ("ab_r_uo", "Abdomen - Right Upper Outer"),
            ("ab_l_lo", "Abdomen - Left Lower Outer"),
            ("ab_r_lo", "Abdomen - Right Lower Outer"),
            ("thigh_l_outer", "Left Thigh - Outer Mid"),
            ("delt_l", "Left Deltoid")
        ]

        // Past 10 days of BPC-157 taken doses
        for dayOffset in (1...10).reversed() {
            let logDate = cal.date(byAdding: .day, value: -dayOffset, to: now)!
            let site = sites[dayOffset % sites.count]
            logs.append(
                DoseLog(
                    protocolId: protoId,
                    compoundId: bpcId,
                    compoundName: "BPC-157",
                    scheduledDate: logDate,
                    loggedDate: logDate,
                    doseAmount: 250,
                    doseUnit: .mcg,
                    status: .taken,
                    injectionSiteId: site.0,
                    injectionSiteName: site.1,
                    vialId: vialBpcId,
                    notes: "Morning routine, zero irritation."
                )
            )
        }

        // Today's Scheduled doses
        logs.append(
            DoseLog(
                protocolId: protoId,
                compoundId: bpcId,
                compoundName: "BPC-157",
                scheduledDate: now,
                doseAmount: 250,
                doseUnit: .mcg,
                status: .scheduled,
                vialId: vialBpcId
            )
        )
        logs.append(
            DoseLog(
                protocolId: UUID(uuidString: "bbbb2222-bbbb-2222-bbbb-222222222222")!,
                compoundId: cjcId,
                compoundName: "CJC-1295 / Ipamorelin",
                scheduledDate: cal.date(bySettingHour: 22, minute: 30, second: 0, of: now) ?? now,
                doseAmount: 300,
                doseUnit: .mcg,
                status: .scheduled,
                vialId: vialCjcId
            )
        )

        return logs
    }

    // MARK: - Biomarkers
    public var defaultBiomarkers: [Biomarker] {
        let cal = Calendar.current
        let now = Date()

        return [
            Biomarker(
                name: "IGF-1 (Somatomedin-C)",
                category: .bloodwork,
                value: 245.0,
                unit: "ng/mL",
                referenceRangeMin: 115.0,
                referenceRangeMax: 307.0,
                dateRecorded: cal.date(byAdding: .day, value: -14, to: now)!,
                source: .labImport,
                notes: "Healthy upper quartile response on secretagogues."
            ),
            Biomarker(
                name: "Fasting Blood Glucose",
                category: .metabolic,
                value: 86.0,
                unit: "mg/dL",
                referenceRangeMin: 70.0,
                referenceRangeMax: 99.0,
                dateRecorded: cal.date(byAdding: .day, value: -1, to: now)!,
                source: .appleHealth
            ),
            Biomarker(
                name: "HbA1c",
                category: .metabolic,
                value: 5.1,
                unit: "%",
                referenceRangeMin: 4.0,
                referenceRangeMax: 5.6,
                dateRecorded: cal.date(byAdding: .day, value: -30, to: now)!,
                source: .labImport
            ),
            Biomarker(
                name: "Body Weight",
                category: .bodyComposition,
                value: 182.4,
                unit: "lbs",
                referenceRangeMin: 165.0,
                referenceRangeMax: 195.0,
                dateRecorded: now,
                source: .appleHealth
            ),
            Biomarker(
                name: "Resting Heart Rate",
                category: .cardiovascular,
                value: 54.0,
                unit: "bpm",
                referenceRangeMin: 50.0,
                referenceRangeMax: 75.0,
                dateRecorded: now,
                source: .appleHealth
            ),
            Biomarker(
                name: "Heart Rate Variability (HRV)",
                category: .sleepRecovery,
                value: 78.0,
                unit: "ms",
                referenceRangeMin: 45.0,
                referenceRangeMax: 110.0,
                dateRecorded: now,
                source: .appleHealth
            )
        ]
    }

    // MARK: - Subjective Symptoms
    public var defaultSymptomLogs: [SymptomLog] {
        let cal = Calendar.current
        let now = Date()

        return [
            SymptomLog(
                timestamp: cal.date(byAdding: .day, value: -3, to: now)!,
                energyLevel: 9,
                sleepQuality: 9,
                recoveryScore: 8,
                moodScore: 9,
                painScore: 2,
                notes: "Right shoulder tendon pain significantly diminished during bench press."
            ),
            SymptomLog(
                timestamp: cal.date(byAdding: .day, value: -1, to: now)!,
                energyLevel: 8,
                sleepQuality: 9,
                recoveryScore: 9,
                moodScore: 9,
                painScore: 1,
                notes: "Excellent deep sleep tracking on Apple Watch."
            )
        ]
    }

    // MARK: - Costs
    public var defaultCosts: [CostRecord] {
        let cal = Calendar.current
        let now = Date()

        return [
            CostRecord(
                title: "BPC-157 (5mg) + TB-500 (10mg)",
                category: .peptideVial,
                amountUsd: 123.0,
                dateIncurred: cal.date(byAdding: .day, value: -14, to: now)!,
                vendor: "Precision Peptides"
            ),
            CostRecord(
                title: "Insulin Syringes + BAC Water",
                category: .medicalSupplies,
                amountUsd: 40.50,
                dateIncurred: cal.date(byAdding: .day, value: -20, to: now)!,
                vendor: "Medical Supply Co"
            ),
            CostRecord(
                title: "Comprehensive Metabolic & Hormone Panel",
                category: .bloodwork,
                amountUsd: 189.0,
                dateIncurred: cal.date(byAdding: .day, value: -30, to: now)!,
                vendor: "Quest Diagnostics"
            )
        ]
    }
}
