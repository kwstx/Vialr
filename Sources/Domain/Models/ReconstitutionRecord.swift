import Foundation

/// Represents the precise preparation and chemical solution parameters for a reconstituted vial.
/// To preserve clinical and mathematical integrity across historical dose logs, confirmed records
/// are immutable and maintain an audited revision history.
public struct ReconstitutionRecord: SyncableRecord, Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var vialId: UUID
    public var userId: UUID?
    public var compoundId: UUID
    public var compoundName: String
    
    // MARK: - Preparation Inputs
    public var dryMassMg: Double
    public var diluentVolumeMl: Double
    public var diluentType: DiluentType
    public var diluentLotNumber: String?
    public var diluentBrand: String?
    public var reconstitutedAt: Date
    
    // MARK: - Resulting Solution Dynamics (Immutable Snapshot)
    public var concentrationMgMl: Double
    public var concentrationMcgMl: Double
    public var totalLiquidVolumeMl: Double
    public var storageCondition: StorageCondition
    public var expectedShelfLifeDays: Int
    public var expirationDate: Date?
    
    // MARK: - Immutability & Confirmation Lock
    public var isConfirmed: Bool
    public var confirmedAt: Date?
    public var confirmedByUserId: UUID?
    
    // MARK: - Revision History & Temporal Tracking
    public var version: Int
    public var effectiveFrom: Date
    public var effectiveTo: Date?
    public var isCurrentActiveRevision: Bool
    public var previousRecordId: UUID?
    public var supersededByRecordId: UUID?
    public var revisionReason: String?
    
    // MARK: - Quality & Visual Verification
    public var solutionClarity: SolutionClarity
    public var photoFileId: UUID?
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date
    public var syncState: SyncState

    // MARK: - Primary Initializer
    public init(
        id: UUID = UUID(),
        vialId: UUID,
        userId: UUID? = nil,
        compoundId: UUID,
        compoundName: String,
        dryMassMg: Double,
        diluentVolumeMl: Double,
        diluentType: DiluentType = .bacteriostaticWater,
        diluentLotNumber: String? = nil,
        diluentBrand: String? = nil,
        reconstitutedAt: Date = Date(),
        storageCondition: StorageCondition = .refrigerated,
        expectedShelfLifeDays: Int = 30,
        isConfirmed: Bool = true,
        confirmedAt: Date? = Date(),
        confirmedByUserId: UUID? = nil,
        version: Int = 1,
        effectiveFrom: Date = Date(),
        effectiveTo: Date? = nil,
        isCurrentActiveRevision: Bool = true,
        previousRecordId: UUID? = nil,
        supersededByRecordId: UUID? = nil,
        revisionReason: String? = nil,
        solutionClarity: SolutionClarity = .clearColorless,
        photoFileId: UUID? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncState: SyncState = .synced
    ) {
        self.id = id
        self.vialId = vialId
        self.userId = userId
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.dryMassMg = dryMassMg
        self.diluentVolumeMl = diluentVolumeMl
        self.diluentType = diluentType
        self.diluentLotNumber = diluentLotNumber
        self.diluentBrand = diluentBrand
        self.reconstitutedAt = reconstitutedAt
        
        let conc = diluentVolumeMl > 0 ? (dryMassMg / diluentVolumeMl) : 0.0
        self.concentrationMgMl = conc
        self.concentrationMcgMl = conc * 1000.0
        self.totalLiquidVolumeMl = diluentVolumeMl
        self.storageCondition = storageCondition
        self.expectedShelfLifeDays = expectedShelfLifeDays
        self.expirationDate = Calendar.current.date(byAdding: .day, value: expectedShelfLifeDays, to: reconstitutedAt)
        
        self.isConfirmed = isConfirmed
        self.confirmedAt = confirmedAt
        self.confirmedByUserId = confirmedByUserId
        
        self.version = version
        self.effectiveFrom = effectiveFrom
        self.effectiveTo = effectiveTo
        self.isCurrentActiveRevision = isCurrentActiveRevision
        self.previousRecordId = previousRecordId
        self.supersededByRecordId = supersededByRecordId
        self.revisionReason = revisionReason
        self.solutionClarity = solutionClarity
        self.photoFileId = photoFileId
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }

    // MARK: - Mathematical Helpers
    /// Liquid draw volume in mL required for a target dose under this specific historical reconstitution state.
    public func drawVolumeMl(for doseAmount: Double, unit: DoseUnit) -> Double {
        guard concentrationMgMl > 0 else { return 0.0 }
        let doseMg = (unit == .mg) ? doseAmount : (doseAmount / 1000.0)
        return doseMg / concentrationMgMl
    }

    /// Syringe tick marks on a standard U-100 syringe (100 units = 1.0 mL).
    public func u100SyringeUnits(for doseAmount: Double, unit: DoseUnit) -> Double {
        drawVolumeMl(for: doseAmount, unit: unit) * 100.0
    }

    // MARK: - Immutability & Safe Revision Factory
    /// Creates a new revision of this reconstitution record (e.g. after adding diluent or correcting an error),
    /// closing out the current record's active window and preserving past calculation history without corruption.
    public func createSupersedingRevision(
        newDiluentVolumeMl: Double,
        newDryMassMg: Double? = nil,
        diluentType: DiluentType? = nil,
        revisionReason: String,
        effectiveDate: Date = Date()
    ) -> (superseded: ReconstitutionRecord, newRevision: ReconstitutionRecord) {
        let newRecordId = UUID()
        
        // 1. Copy and supersede self
        var updatedSelf = self
        updatedSelf.effectiveTo = effectiveDate
        updatedSelf.isCurrentActiveRevision = false
        updatedSelf.supersededByRecordId = newRecordId
        updatedSelf.updatedAt = effectiveDate
        
        // 2. Create the child revision
        let newRevision = ReconstitutionRecord(
            id: newRecordId,
            vialId: self.vialId,
            userId: self.userId,
            compoundId: self.compoundId,
            compoundName: self.compoundName,
            dryMassMg: newDryMassMg ?? self.dryMassMg,
            diluentVolumeMl: newDiluentVolumeMl,
            diluentType: diluentType ?? self.diluentType,
            diluentLotNumber: self.diluentLotNumber,
            diluentBrand: self.diluentBrand,
            reconstitutedAt: self.reconstitutedAt,
            storageCondition: self.storageCondition,
            expectedShelfLifeDays: self.expectedShelfLifeDays,
            isConfirmed: true,
            confirmedAt: effectiveDate,
            confirmedByUserId: self.confirmedByUserId,
            version: self.version + 1,
            effectiveFrom: effectiveDate,
            effectiveTo: nil,
            isCurrentActiveRevision: true,
            previousRecordId: self.id,
            supersededByRecordId: nil,
            revisionReason: revisionReason,
            solutionClarity: self.solutionClarity,
            photoFileId: self.photoFileId,
            notes: "Revision \(self.version + 1): \(revisionReason)",
            createdAt: effectiveDate,
            updatedAt: effectiveDate,
            syncState: .pendingCreation
        )
        
        return (superseded: updatedSelf, newRevision: newRevision)
    }
}

// MARK: - Diluent Type
public enum DiluentType: String, Codable, Sendable, CaseIterable, Identifiable {
    case bacteriostaticWater = "Bacteriostatic Water (0.9% Benzyl Alcohol)"
    case sterileSaline = "0.9% Sodium Chloride (Sterile Saline)"
    case sterileWater = "Sterile Water for Injection"
    case bacteriostaticSaline = "Bacteriostatic Sodium Chloride"
    case custom = "Custom Diluent"

    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .bacteriostaticWater: return "BAC Water"
        case .sterileSaline: return "Saline"
        case .sterileWater: return "Sterile Water"
        case .bacteriostaticSaline: return "BAC Saline"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Solution Clarity
public enum SolutionClarity: String, Codable, Sendable, CaseIterable, Identifiable {
    case clearColorless = "Clear & Colorless (Optimal)"
    case slightHaze = "Slight Haze / Translucent"
    case particulateVisible = "Particulate Visible (Do Not Use)"
    case discolored = "Discolored / Precipitation (Discard)"

    public var id: String { rawValue }

    public var isSafeForAdministration: Bool {
        self == .clearColorless || self == .slightHaze
    }
}
