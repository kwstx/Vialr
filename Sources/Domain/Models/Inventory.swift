import Foundation

/// Represents ancillary supplies such as syringes, bacteriostatic water, needles, and alcohol swabs.
public struct SupplyItem: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var category: SupplyCategory
    public var quantityRemaining: Int
    public var packageUnit: String // e.g. "100-pack", "30mL bottle", "box"
    public var reorderThreshold: Int
    public var costUsd: Double?
    public var notes: String
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        category: SupplyCategory,
        quantityRemaining: Int,
        packageUnit: String = "pieces",
        reorderThreshold: Int = 10,
        costUsd: Double? = nil,
        notes: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.quantityRemaining = quantityRemaining
        self.packageUnit = packageUnit
        self.reorderThreshold = reorderThreshold
        self.costUsd = costUsd
        self.notes = notes
        self.updatedAt = updatedAt
    }

    public var isLowStock: Bool {
        quantityRemaining <= reorderThreshold
    }
}

public enum SupplyCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case syringes = "Insulin Syringes (U-100)"
    case bacWater = "Bacteriostatic Water"
    case needles = "Drawing Needles"
    case prepPads = "Alcohol Prep Pads"
    case sharpsContainer = "Sharps Disposal"
    case accessories = "Other Supplies"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .syringes: return "syringe.fill"
        case .bacWater: return "drop.fill"
        case .needles: return "cross.fill"
        case .prepPads: return "square.fill"
        case .sharpsContainer: return "trash.fill"
        case .accessories: return "cube.box.fill"
        }
    }
}
