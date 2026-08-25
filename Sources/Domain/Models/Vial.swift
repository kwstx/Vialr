import Foundation

/// Represents an individual physical vial in stock (either lyophilized powder or reconstituted solution).
public struct Vial: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var compoundId: UUID
    public var compoundName: String
    public var lotNumber: String
    public var vendor: String
    public var totalDryMassMg: Double
    public var bacWaterAddedMl: Double?
    public var currentVolumeRemainingMl: Double?
    public var concentrationMgMl: Double? {
        guard let bacWater = bacWaterAddedMl, bacWater > 0 else { return nil }
        return totalDryMassMg / bacWater
    }
    public var isReconstituted: Bool
    public var reconstitutedDate: Date?
    public var expirationDate: Date?
    public var costUsd: Double?
    public var storageCondition: StorageCondition
    public var notes: String
    public var status: VialStatus
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        compoundId: UUID,
        compoundName: String,
        lotNumber: String = "",
        vendor: String = "",
        totalDryMassMg: Double,
        bacWaterAddedMl: Double? = nil,
        currentVolumeRemainingMl: Double? = nil,
        isReconstituted: Bool = false,
        reconstitutedDate: Date? = nil,
        expirationDate: Date? = nil,
        costUsd: Double? = nil,
        storageCondition: StorageCondition = .refrigerated,
        notes: String = "",
        status: VialStatus = .unopened,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.lotNumber = lotNumber
        self.vendor = vendor
        self.totalDryMassMg = totalDryMassMg
        self.bacWaterAddedMl = bacWaterAddedMl
        self.currentVolumeRemainingMl = currentVolumeRemainingMl ?? bacWaterAddedMl
        self.isReconstituted = isReconstituted
        self.reconstitutedDate = reconstitutedDate
        self.expirationDate = expirationDate
        self.costUsd = costUsd
        self.storageCondition = storageCondition
        self.notes = notes
        self.status = status
        self.createdAt = createdAt
    }

    /// Remaining fraction from 0.0 to 1.0.
    public var remainingFraction: Double {
        guard let current = currentVolumeRemainingMl, let total = bacWaterAddedMl, total > 0 else {
            return isReconstituted ? 0.0 : 1.0
        }
        return max(0.0, min(1.0, current / total))
    }
}

public enum VialStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case unopened = "Unopened (Dry)"
    case reconstituted = "Reconstituted & In Use"
    case depleted = "Depleted"
    case expired = "Expired"
    case discarded = "Discarded"

    public var id: String { rawValue }

    public var badgeColorHex: String {
        switch self {
        case .unopened: return "#3B82F6"
        case .reconstituted: return "#10B981"
        case .depleted: return "#6B7280"
        case .expired: return "#EF4444"
        case .discarded: return "#9CA3AF"
        }
    }
}
