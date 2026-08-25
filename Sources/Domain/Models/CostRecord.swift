import Foundation

/// Represents a financial expense tied to compounds, vials, accessories, or bloodwork.
public struct CostRecord: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var title: String
    public var category: CostCategory
    public var amountUsd: Double
    public var dateIncurred: Date
    public var vendor: String
    public var associatedVialId: UUID?
    public var associatedCompoundId: UUID?
    public var notes: String

    public init(
        id: UUID = UUID(),
        title: String,
        category: CostCategory,
        amountUsd: Double,
        dateIncurred: Date = Date(),
        vendor: String = "",
        associatedVialId: UUID? = nil,
        associatedCompoundId: UUID? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.amountUsd = amountUsd
        self.dateIncurred = dateIncurred
        self.vendor = vendor
        self.associatedVialId = associatedVialId
        self.associatedCompoundId = associatedCompoundId
        self.notes = notes
    }
}

public enum CostCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case peptideVial = "Peptide / Compound Vial"
    case medicalSupplies = "Supplies (Syringes, BAC Water)"
    case bloodwork = "Bloodwork / Lab Tests"
    case doctorConsult = "Physician / Clinic Consult"
    case shipping = "Shipping & Handling"
    case other = "Other"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .peptideVial: return "cylinder.split.1x2.fill"
        case .medicalSupplies: return "syringe"
        case .bloodwork: return "drop.triangle.fill"
        case .doctorConsult: return "stethoscope"
        case .shipping: return "shippingbox.fill"
        case .other: return "dollarsign.circle.fill"
        }
    }
}
