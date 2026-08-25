import Foundation

/// Defines a compound, peptide, or supplement tracked in Vialr.
public struct Compound: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var shortCode: String
    public var category: CompoundCategory
    public var defaultUnit: DoseUnit
    public var typicalDose: Double
    public var halfLifeHours: Double?
    public var description: String
    public var administrationRoute: AdministrationRoute
    public var storageCondition: StorageCondition
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        shortCode: String,
        category: CompoundCategory,
        defaultUnit: DoseUnit = .mcg,
        typicalDose: Double = 250,
        halfLifeHours: Double? = nil,
        description: String = "",
        administrationRoute: AdministrationRoute = .subcutaneous,
        storageCondition: StorageCondition = .refrigerated,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.shortCode = shortCode
        self.category = category
        self.defaultUnit = defaultUnit
        self.typicalDose = typicalDose
        self.halfLifeHours = halfLifeHours
        self.description = description
        self.administrationRoute = administrationRoute
        self.storageCondition = storageCondition
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum CompoundCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case recovery = "Recovery & Tissue Repair"
    case glp1Metabolic = "GLP-1 / Metabolic"
    case growthHormoneSecretagogue = "GH Secretagogue"
    case longevityNootropic = "Longevity & Nootropic"
    case cosmeticSkin = "Cosmetic & Skin"
    case hormonalSupport = "Hormonal Support"
    case supplementOther = "Supplements & Other"

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
        }
    }
}

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

public enum AdministrationRoute: String, Codable, Sendable, CaseIterable, Identifiable {
    case subcutaneous = "Subcutaneous (SubQ)"
    case intramuscular = "Intramuscular (IM)"
    case oral = "Oral"
    case nasal = "Intranasal"
    case topical = "Topical"

    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .subcutaneous: return "SubQ"
        case .intramuscular: return "IM"
        case .oral: return "Oral"
        case .nasal: return "Nasal"
        case .topical: return "Topical"
        }
    }
}

public enum StorageCondition: String, Codable, Sendable, CaseIterable, Identifiable {
    case roomTemperature = "Room Temperature"
    case refrigerated = "Refrigerated (2–8°C)"
    case frozen = "Frozen (-20°C)"
    case protectFromLight = "Protect from Light"

    public var id: String { rawValue }
}
