import Foundation

/// Represents a physical inventory vial item in stock (either lyophilized dry powder or reconstituted solution).
/// Encapsulates compound information, physical quantity, concentration dynamics, dates/shelf-life,
/// lot/batch tracking, financial cost breakdown, and lifecycle status.
public struct Vial: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var userId: UUID?
    
    // MARK: - Compound Association
    public var compoundId: UUID
    public var compoundName: String
    public var compoundCategory: CompoundCategory?
    
    // MARK: - Lot & Sourcing Information
    public var lotNumber: String
    public var batchNumber: String?
    public var vendor: String
    public var purityPercentage: Double? // e.g. 99.4
    public var coaReportFileId: UUID?
    public var photoFileId: UUID?
    public var barcodeOrQrCode: String?
    
    // MARK: - Quantity & Reconstitution
    public var totalDryMassMg: Double
    public var bacWaterAddedMl: Double?
    public var currentVolumeRemainingMl: Double?
    public var isReconstituted: Bool
    
    // MARK: - Dates & Shelf Life
    public var purchaseDate: Date?
    public var receivedDate: Date?
    public var reconstitutedDate: Date?
    public var expirationDate: Date?
    public var openedDate: Date?
    public var depletedDate: Date?
    public var discardDate: Date?
    public var createdAt: Date
    public var updatedAt: Date
    
    // MARK: - Cost & Financial Information
    public var costUsd: Double?
    public var currencyCode: String
    
    // MARK: - Storage & Status
    public var storageCondition: StorageCondition
    public var status: VialStatus
    public var notes: String

    // MARK: - Primary Initializer
    public init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        compoundId: UUID,
        compoundName: String,
        compoundCategory: CompoundCategory? = nil,
        lotNumber: String = "",
        batchNumber: String? = nil,
        vendor: String = "",
        purityPercentage: Double? = nil,
        coaReportFileId: UUID? = nil,
        photoFileId: UUID? = nil,
        barcodeOrQrCode: String? = nil,
        totalDryMassMg: Double,
        bacWaterAddedMl: Double? = nil,
        currentVolumeRemainingMl: Double? = nil,
        isReconstituted: Bool = false,
        purchaseDate: Date? = nil,
        receivedDate: Date? = nil,
        reconstitutedDate: Date? = nil,
        expirationDate: Date? = nil,
        openedDate: Date? = nil,
        depletedDate: Date? = nil,
        discardDate: Date? = nil,
        costUsd: Double? = nil,
        currencyCode: String = "USD",
        storageCondition: StorageCondition = .refrigerated,
        notes: String = "",
        status: VialStatus = .unopened,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.compoundCategory = compoundCategory
        self.lotNumber = lotNumber
        self.batchNumber = batchNumber
        self.vendor = vendor
        self.purityPercentage = purityPercentage
        self.coaReportFileId = coaReportFileId
        self.photoFileId = photoFileId
        self.barcodeOrQrCode = barcodeOrQrCode
        self.totalDryMassMg = totalDryMassMg
        self.bacWaterAddedMl = bacWaterAddedMl
        self.currentVolumeRemainingMl = currentVolumeRemainingMl ?? bacWaterAddedMl
        self.isReconstituted = isReconstituted
        self.purchaseDate = purchaseDate
        self.receivedDate = receivedDate
        self.reconstitutedDate = reconstitutedDate
        self.expirationDate = expirationDate
        self.openedDate = openedDate
        self.depletedDate = depletedDate
        self.discardDate = discardDate
        self.costUsd = costUsd
        self.currencyCode = currencyCode
        self.storageCondition = storageCondition
        self.notes = notes
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Concentration & Solution Dynamics
    /// Concentration in milligrams per milliliter (mg/mL).
    public var concentrationMgMl: Double? {
        guard let bacWater = bacWaterAddedMl, bacWater > 0 else { return nil }
        return totalDryMassMg / bacWater
    }

    /// Concentration in micrograms per milliliter (mcg/mL).
    public var concentrationMcgMl: Double? {
        guard let conc = concentrationMgMl else { return nil }
        return conc * 1000.0
    }

    /// Remaining fraction from 0.0 to 1.0.
    public var remainingFraction: Double {
        guard let current = currentVolumeRemainingMl, let total = bacWaterAddedMl, total > 0 else {
            return isReconstituted ? 0.0 : 1.0
        }
        return max(0.0, min(1.0, current / total))
    }

    /// Remaining percentage (0% to 100%).
    public var remainingPercentage: Double {
        remainingFraction * 100.0
    }

    /// Calculated active dry mass remaining in the vial solution.
    public var remainingMassMg: Double? {
        guard let conc = concentrationMgMl, let remVol = currentVolumeRemainingMl else {
            return isReconstituted ? 0.0 : totalDryMassMg
        }
        return conc * remVol
    }

    /// Calculates the required liquid draw volume in mL for a given dose amount and unit.
    public func drawVolumeMl(for doseAmount: Double, unit: DoseUnit) -> Double? {
        guard let conc = concentrationMgMl, conc > 0 else { return nil }
        let doseMg = (unit == .mg) ? doseAmount : (doseAmount / 1000.0)
        return doseMg / conc
    }

    /// Calculates syringe tick marks on a standard U-100 insulin syringe (100 units = 1.0 mL).
    public func u100SyringeUnits(for doseAmount: Double, unit: DoseUnit) -> Double? {
        guard let volMl = drawVolumeMl(for: doseAmount, unit: unit) else { return nil }
        return volMl * 100.0
    }

    /// Estimated remaining doses in this vial for a specific dose configuration.
    public func estimatedDosesRemaining(doseAmount: Double, unit: DoseUnit) -> Int? {
        guard let drawMl = drawVolumeMl(for: doseAmount, unit: unit), drawMl > 0,
              let remaining = currentVolumeRemainingMl else { return nil }
        return Int(remaining / drawMl)
    }

    // MARK: - Cost Metrics
    /// Cost per milligram (USD).
    public var costPerMgUsd: Double? {
        guard let cost = costUsd, totalDryMassMg > 0 else { return nil }
        return cost / totalDryMassMg
    }

    /// Calculates the exact financial cost per individual dose injection.
    public func costPerDoseUsd(doseAmount: Double, unit: DoseUnit) -> Double? {
        guard let costPerMg = costPerMgUsd else { return nil }
        let doseMg = (unit == .mg) ? doseAmount : (doseAmount / 1000.0)
        return costPerMg * doseMg
    }

    // MARK: - Freshness & Shelf-Life Analytics
    /// Days elapsed since reconstitution.
    public var daysSinceReconstitution: Int? {
        guard let recon = reconstitutedDate else { return nil }
        let diff = Calendar.current.dateComponents([.day], from: recon, to: Date()).day ?? 0
        return max(0, diff)
    }

    /// Whether the vial has surpassed its expiration date.
    public var isExpired: Bool {
        if let exp = expirationDate, Date() > exp {
            return true
        }
        return status == .expired
    }

    /// Whether a reconstituted peptide solution is still within its optimal freshness window (default: 30 days).
    public func isWithinOptimalFreshness(maxDays: Int = 30) -> Bool {
        guard let days = daysSinceReconstitution else { return true }
        return days <= maxDays
    }
}

// MARK: - Vial Status
public enum VialStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case unopened = "Unopened (Dry)"
    case reconstituted = "Reconstituted & In Use"
    case depleted = "Depleted"
    case expired = "Expired"
    case discarded = "Discarded"
    case damaged = "Damaged / Spoiled"

    public var id: String { rawValue }

    public var badgeColorHex: String {
        switch self {
        case .unopened: return "#3B82F6"
        case .reconstituted: return "#10B981"
        case .depleted: return "#6B7280"
        case .expired: return "#EF4444"
        case .discarded: return "#9CA3AF"
        case .damaged: return "#DC2626"
        }
    }
}
