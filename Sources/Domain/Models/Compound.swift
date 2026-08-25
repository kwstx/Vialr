import Foundation

/// Defines a compound, peptide, supplement, or medicine tracked in Vialr.
/// Supports both curated library compounds and fully customizable user-created compounds.
public struct Compound: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var shortCode: String
    public var category: CompoundCategory
    public var customCategoryName: String?
    public var isCustom: Bool
    public var source: CompoundSource
    public var createdByUserId: UUID?
    public var defaultUnit: DoseUnit
    public var typicalDose: Double
    public var doseRangeMin: Double?
    public var doseRangeMax: Double?
    public var halfLifeHours: Double?
    public var administrationRoute: AdministrationRoute
    public var storageCondition: StorageCondition
    public var requiresReconstitution: Bool
    public var description: String
    public var instructions: String
    public var tags: [String]
    public var aliases: [String]
    public var colorHex: String?
    public var iconName: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        shortCode: String = "",
        category: CompoundCategory = .supplementOther,
        customCategoryName: String? = nil,
        isCustom: Bool = false,
        source: CompoundSource = .curatedLibrary,
        createdByUserId: UUID? = nil,
        defaultUnit: DoseUnit = .mcg,
        typicalDose: Double = 250,
        doseRangeMin: Double? = nil,
        doseRangeMax: Double? = nil,
        halfLifeHours: Double? = nil,
        administrationRoute: AdministrationRoute = .subcutaneous,
        storageCondition: StorageCondition = .refrigerated,
        requiresReconstitution: Bool = false,
        description: String = "",
        instructions: String = "",
        tags: [String] = [],
        aliases: [String] = [],
        colorHex: String? = nil,
        iconName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.shortCode = shortCode.isEmpty ? Compound.generateShortCode(from: name) : shortCode
        self.category = category
        self.customCategoryName = customCategoryName
        self.isCustom = isCustom
        self.source = source
        self.createdByUserId = createdByUserId
        self.defaultUnit = defaultUnit
        self.typicalDose = typicalDose
        self.doseRangeMin = doseRangeMin
        self.doseRangeMax = doseRangeMax
        self.halfLifeHours = halfLifeHours
        self.administrationRoute = administrationRoute
        self.storageCondition = storageCondition
        self.requiresReconstitution = requiresReconstitution
        self.description = description
        self.instructions = instructions
        self.tags = tags
        self.aliases = aliases
        self.colorHex = colorHex
        self.iconName = iconName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Convenience factory for creating a custom user-defined compound without requiring a database entry.
    public static func custom(
        id: UUID = UUID(),
        name: String,
        shortCode: String? = nil,
        category: CompoundCategory = .custom,
        customCategoryName: String? = nil,
        createdByUserId: UUID? = nil,
        defaultUnit: DoseUnit = .mg,
        typicalDose: Double = 100,
        halfLifeHours: Double? = nil,
        administrationRoute: AdministrationRoute = .oral,
        storageCondition: StorageCondition = .roomTemperature,
        requiresReconstitution: Bool = false,
        description: String = "",
        instructions: String = "",
        tags: [String] = []
    ) -> Compound {
        Compound(
            id: id,
            name: name,
            shortCode: shortCode ?? Compound.generateShortCode(from: name),
            category: category,
            customCategoryName: customCategoryName,
            isCustom: true,
            source: .customUserCreated,
            createdByUserId: createdByUserId,
            defaultUnit: defaultUnit,
            typicalDose: typicalDose,
            halfLifeHours: halfLifeHours,
            administrationRoute: administrationRoute,
            storageCondition: storageCondition,
            requiresReconstitution: requiresReconstitution,
            description: description,
            instructions: instructions,
            tags: tags
        )
    }

    /// Generates a concise uppercase short code / abbreviation from a compound name.
    public static func generateShortCode(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "CMP" }

        // If name has hyphen/slash/space separators (e.g., "BPC-157", "CJC-1295 / Ipamorelin")
        let components = trimmed.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        if components.count == 1 {
            let word = components[0]
            if word.count <= 4 {
                return word.uppercased()
            }
            return String(word.prefix(4)).uppercased()
        }

        // Multiple words or separated tokens: take first letter of each or primary token
        let initials = components.compactMap { $0.first.map(String.init) }.joined()
        if initials.count >= 2 && initials.count <= 5 {
            return initials.uppercased()
        }

        return String(components[0].prefix(3)).uppercased()
    }

    /// Displays the short code or fallback initials.
    public var displayShortCode: String {
        if !shortCode.isEmpty {
            return shortCode
        }
        return Compound.generateShortCode(from: name)
    }

    /// Returns the active icon name, falling back to the category default icon.
    public var effectiveIconName: String {
        if let icon = iconName, !icon.isEmpty {
            return icon
        }
        return category.iconName
    }

    /// Display category name taking into account user custom category override.
    public var displayCategory: String {
        if category == .custom, let custom = customCategoryName, !custom.isEmpty {
            return custom
        }
        return category.rawValue
    }
}

// MARK: - Compound Source
public enum CompoundSource: String, Codable, Sendable, CaseIterable, Identifiable {
    case curatedLibrary = "Curated Library"
    case customUserCreated = "User Custom"
    case imported = "Imported"
    case community = "Community"

    public var id: String { rawValue }
}

// MARK: - Compound Category
public enum CompoundCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case recovery = "Recovery & Tissue Repair"
    case glp1Metabolic = "GLP-1 / Metabolic"
    case growthHormoneSecretagogue = "GH Secretagogue"
    case longevityNootropic = "Longevity & Nootropic"
    case cosmeticSkin = "Cosmetic & Skin"
    case hormonalSupport = "Hormonal Support"
    case supplementOther = "Supplements & Other"
    case custom = "Custom / Other"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .recovery: return "cross.case.fill"
        case .glp1Metabolic: return "flame.fill"
        case .growthHormoneSecretagogue: return "bolt.fill"
        case .longevityNootropic: return "brain.head.profile"
        case .cosmeticSkin: return "sparkles"
        case .hormonalSupport: return "waveform.path.ecg"
        case .supplementOther: return "pills.fill"
        case .custom: return "flask.fill"
        }
    }
}

// MARK: - Dose Unit
public enum DoseUnit: String, Codable, Sendable, CaseIterable, Identifiable {
    case mcg = "mcg"
    case mg = "mg"
    case iu = "IU"
    case ml = "mL"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mcg: return "Micrograms (mcg)"
        case .mg: return "Milligrams (mg)"
        case .iu: return "International Units (IU)"
        case .ml: return "Milliliters (mL)"
        }
    }
}

// MARK: - Administration Route
public enum AdministrationRoute: String, Codable, Sendable, CaseIterable, Identifiable {
    case subcutaneous = "Subcutaneous (SubQ)"
    case intramuscular = "Intramuscular (IM)"
    case oral = "Oral"
    case nasal = "Intranasal"
    case topical = "Topical"
    case sublingual = "Sublingual"
    case transdermal = "Transdermal Patch"
    case intravenous = "Intravenous (IV)"

    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .subcutaneous: return "SubQ"
        case .intramuscular: return "IM"
        case .oral: return "Oral"
        case .nasal: return "Nasal"
        case .topical: return "Topical"
        case .sublingual: return "Sublingual"
        case .transdermal: return "Patch"
        case .intravenous: return "IV"
        }
    }
}

// MARK: - Storage Condition
public enum StorageCondition: String, Codable, Sendable, CaseIterable, Identifiable {
    case roomTemperature = "Room Temperature"
    case refrigerated = "Refrigerated (2–8°C)"
    case frozen = "Frozen (-20°C)"
    case protectFromLight = "Protect from Light"

    public var id: String { rawValue }
}
