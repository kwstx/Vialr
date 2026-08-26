import Foundation

/// Represents an immutable inventory event in the double-entry event-sourced accounting system.
/// Every physical creation, chemical reconstitution, dose consumption draw, reconciliation adjustment,
/// or disposal is captured as an audited event from which inventory levels and concentrations are derived.
public struct InventoryEvent: SyncableRecord, Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var userId: UUID?
    
    // MARK: - Relational Associations
    public var vialId: UUID?
    public var supplyItemId: UUID?
    public var compoundId: UUID?
    public var compoundName: String?
    
    // MARK: - Event Classification
    public var eventType: InventoryEventType
    public var timestamp: Date
    public var reason: String
    public var reconciliationReason: ReconciliationReason?
    public var disposalReason: DisposalReason?
    
    // MARK: - Quantities & Adjustments (Deltas)
    public var changeMassMg: Double?        // Positive for stock addition, negative for consumption/waste
    public var changeVolumeMl: Double?      // Positive for diluent addition, negative for dose draw/loss
    public var changeQuantityCount: Int?    // For ancillary supplies (e.g. -1 syringe, +100 pack)
    
    // MARK: - Resulting State Snapshot (Post-Event Calculation)
    public var resultingVolumeRemainingMl: Double?
    public var resultingMassRemainingMg: Double?
    public var resultingConcentrationMgMl: Double?
    public var resultingStatus: VialStatus?
    
    // MARK: - Audited Operational Links
    public var doseEventId: UUID?           // Links directly to ground-truth DoseEvent
    public var reconstitutionRecordId: UUID?// Links directly to ReconstitutionRecord
    public var costEventId: UUID?           // Links to financial expenditure
    public var lotNumber: String?
    public var performedByUserId: UUID?
    public var notes: String
    public var metadata: [String: String]
    
    // MARK: - Record Lifecycle & Synchronization
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var syncState: SyncState

    // MARK: - Primary Initializer
    public init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        vialId: UUID? = nil,
        supplyItemId: UUID? = nil,
        compoundId: UUID? = nil,
        compoundName: String? = nil,
        eventType: InventoryEventType,
        timestamp: Date = Date(),
        reason: String = "",
        reconciliationReason: ReconciliationReason? = nil,
        disposalReason: DisposalReason? = nil,
        changeMassMg: Double? = nil,
        changeVolumeMl: Double? = nil,
        changeQuantityCount: Int? = nil,
        resultingVolumeRemainingMl: Double? = nil,
        resultingMassRemainingMg: Double? = nil,
        resultingConcentrationMgMl: Double? = nil,
        resultingStatus: VialStatus? = nil,
        doseEventId: UUID? = nil,
        reconstitutionRecordId: UUID? = nil,
        costEventId: UUID? = nil,
        lotNumber: String? = nil,
        performedByUserId: UUID? = nil,
        notes: String = "",
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        syncState: SyncState = .synced
    ) {
        self.id = id
        self.userId = userId
        self.vialId = vialId
        self.supplyItemId = supplyItemId
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.eventType = eventType
        self.timestamp = timestamp
        self.reason = reason.isEmpty ? eventType.defaultReason : reason
        self.reconciliationReason = reconciliationReason
        self.disposalReason = disposalReason
        self.changeMassMg = changeMassMg
        self.changeVolumeMl = changeVolumeMl
        self.changeQuantityCount = changeQuantityCount
        self.resultingVolumeRemainingMl = resultingVolumeRemainingMl
        self.resultingMassRemainingMg = resultingMassRemainingMg
        self.resultingConcentrationMgMl = resultingConcentrationMgMl
        self.resultingStatus = resultingStatus
        self.doseEventId = doseEventId
        self.reconstitutionRecordId = reconstitutionRecordId
        self.costEventId = costEventId
        self.lotNumber = lotNumber
        self.performedByUserId = performedByUserId
        self.notes = notes
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.syncState = syncState
    }

    // MARK: - Static Convenience Factories
    
    /// Creates an initial stock creation event for a newly received vial.
    public static func initialStock(
        vialId: UUID,
        compoundId: UUID,
        compoundName: String,
        initialDryMassMg: Double,
        lotNumber: String = "",
        costEventId: UUID? = nil,
        timestamp: Date = Date(),
        notes: String = ""
    ) -> InventoryEvent {
        InventoryEvent(
            vialId: vialId,
            compoundId: compoundId,
            compoundName: compoundName,
            eventType: .initialStock,
            timestamp: timestamp,
            reason: "Initial vial receipt and stock intake",
            changeMassMg: initialDryMassMg,
            changeVolumeMl: 0.0,
            resultingVolumeRemainingMl: 0.0,
            resultingMassRemainingMg: initialDryMassMg,
            resultingConcentrationMgMl: nil,
            resultingStatus: .unopened,
            costEventId: costEventId,
            lotNumber: lotNumber,
            notes: notes
        )
    }

    /// Creates a reconstitution event that changes the vial's physical state from dry powder to liquid solution.
    public static func reconstitution(
        vialId: UUID,
        compoundId: UUID,
        compoundName: String,
        diluentVolumeMl: Double,
        dryMassMg: Double,
        reconstitutionRecordId: UUID? = nil,
        lotNumber: String? = nil,
        timestamp: Date = Date(),
        notes: String = ""
    ) -> InventoryEvent {
        let conc = diluentVolumeMl > 0 ? (dryMassMg / diluentVolumeMl) : 0.0
        return InventoryEvent(
            vialId: vialId,
            compoundId: compoundId,
            compoundName: compoundName,
            eventType: .reconstitution,
            timestamp: timestamp,
            reason: "Reconstitution with \(String(format: "%.2f", diluentVolumeMl)) mL diluent",
            changeMassMg: 0.0,
            changeVolumeMl: diluentVolumeMl,
            resultingVolumeRemainingMl: diluentVolumeMl,
            resultingMassRemainingMg: dryMassMg,
            resultingConcentrationMgMl: conc,
            resultingStatus: .reconstituted,
            reconstitutionRecordId: reconstitutionRecordId,
            lotNumber: lotNumber,
            notes: notes
        )
    }

    /// Creates a dose consumption event recording exact draw volume and mass deducted from the active vial.
    public static func doseConsumption(
        vialId: UUID,
        compoundId: UUID,
        compoundName: String,
        doseEventId: UUID,
        consumedVolumeMl: Double,
        consumedMassMg: Double,
        newVolumeRemainingMl: Double,
        newMassRemainingMg: Double,
        concentrationMgMl: Double,
        isDepleted: Bool = false,
        timestamp: Date = Date(),
        notes: String = ""
    ) -> InventoryEvent {
        InventoryEvent(
            vialId: vialId,
            compoundId: compoundId,
            compoundName: compoundName,
            eventType: .doseConsumption,
            timestamp: timestamp,
            reason: "Dose administration draw (\(String(format: "%.3f", consumedVolumeMl)) mL)",
            changeMassMg: -abs(consumedMassMg),
            changeVolumeMl: -abs(consumedVolumeMl),
            resultingVolumeRemainingMl: max(0.0, newVolumeRemainingMl),
            resultingMassRemainingMg: max(0.0, newMassRemainingMg),
            resultingConcentrationMgMl: concentrationMgMl,
            resultingStatus: isDepleted ? .depleted : .reconstituted,
            doseEventId: doseEventId,
            notes: notes
        )
    }

    /// Creates an audited inventory reconciliation adjustment event.
    public static func reconciliation(
        vialId: UUID,
        compoundId: UUID,
        compoundName: String,
        volumeVarianceMl: Double,
        massVarianceMg: Double,
        newVolumeRemainingMl: Double,
        newMassRemainingMg: Double,
        concentrationMgMl: Double?,
        reason: ReconciliationReason,
        userNotes: String = "",
        timestamp: Date = Date()
    ) -> InventoryEvent {
        let signStr = volumeVarianceMl >= 0 ? "+\(String(format: "%.3f", volumeVarianceMl))" : "\(String(format: "%.3f", volumeVarianceMl))"
        let fullReason = "Physical reconciliation: \(reason.rawValue) (\(signStr) mL variance)"
        return InventoryEvent(
            vialId: vialId,
            compoundId: compoundId,
            compoundName: compoundName,
            eventType: .reconciliation,
            timestamp: timestamp,
            reason: fullReason,
            reconciliationReason: reason,
            changeMassMg: massVarianceMg,
            changeVolumeMl: volumeVarianceMl,
            resultingVolumeRemainingMl: max(0.0, newVolumeRemainingMl),
            resultingMassRemainingMg: max(0.0, newMassRemainingMg),
            resultingConcentrationMgMl: concentrationMgMl,
            resultingStatus: newVolumeRemainingMl <= 0.0001 ? .depleted : .reconstituted,
            notes: userNotes
        )
    }

    /// Creates an audited vial disposal event.
    public static func disposal(
        vialId: UUID,
        compoundId: UUID,
        compoundName: String,
        remainingVolumeBeforeDisposalMl: Double,
        remainingMassBeforeDisposalMg: Double,
        reason: DisposalReason,
        userNotes: String = "",
        timestamp: Date = Date()
    ) -> InventoryEvent {
        InventoryEvent(
            vialId: vialId,
            compoundId: compoundId,
            compoundName: compoundName,
            eventType: .disposal,
            timestamp: timestamp,
            reason: "Vial disposal: \(reason.rawValue)",
            disposalReason: reason,
            changeMassMg: -abs(remainingMassBeforeDisposalMg),
            changeVolumeMl: -abs(remainingVolumeBeforeDisposalMl),
            resultingVolumeRemainingMl: 0.0,
            resultingMassRemainingMg: 0.0,
            resultingConcentrationMgMl: 0.0,
            resultingStatus: reason == .depleted ? .depleted : .discarded,
            notes: userNotes
        )
    }
}

// MARK: - Inventory Event Type
public enum InventoryEventType: String, Codable, Sendable, CaseIterable, Identifiable {
    case initialStock = "Initial Stock Intake"
    case reconstitution = "Chemical Reconstitution"
    case doseConsumption = "Dose Draw Consumption"
    case reconciliation = "Inventory Reconciliation"
    case disposal = "Vial Disposal / Discard"
    case quarantine = "Quarantine / Hold"
    case restock = "Supply Restock"
    case transfer = "Storage Transfer"
    case other = "Manual Adjustment"

    public var id: String { rawValue }

    public var defaultReason: String {
        switch self {
        case .initialStock: return "Vial stock intake"
        case .reconstitution: return "Lyophilized powder reconstituted"
        case .doseConsumption: return "Dose administration"
        case .reconciliation: return "Physical inventory reconciliation"
        case .disposal: return "Vial discarded"
        case .quarantine: return "Vial placed on safety quarantine"
        case .restock: return "Supplies replenishment"
        case .transfer: return "Relocated storage"
        case .other: return "Inventory event"
        }
    }

    public var iconName: String {
        switch self {
        case .initialStock: return "shippingbox.fill"
        case .reconstitution: return "drop.fill"
        case .doseConsumption: return "syringe.fill"
        case .reconciliation: return "arrow.left.arrow.right.circle.fill"
        case .disposal: return "trash.fill"
        case .quarantine: return "exclamationmark.shield.fill"
        case .restock: return "plus.square.fill"
        case .transfer: return "arrow.triangle.2.circlepath"
        case .other: return "pencil.and.list.clipboard"
        }
    }

    public var badgeColorHex: String {
        switch self {
        case .initialStock: return "#3B82F6"
        case .reconstitution: return "#06B6D4"
        case .doseConsumption: return "#10B981"
        case .reconciliation: return "#F59E0B"
        case .disposal: return "#6B7280"
        case .quarantine: return "#EF4444"
        case .restock: return "#8B5CF6"
        case .transfer: return "#6366F1"
        case .other: return "#9CA3AF"
        }
    }
}

// MARK: - Reconciliation Reason
public enum ReconciliationReason: String, Codable, Sendable, CaseIterable, Identifiable {
    case deadSpaceLoss = "Syringe Dead Space Cumulative Loss"
    case measurementVariance = "Visual / Physical Measurement Variance"
    case spillOrLeak = "Accidental Spill or Draw Leak"
    case evaporation = "Vaporization / Diluent Evaporation"
    case countingError = "Historical Dose Logging Count Error"
    case physicalInspection = "Routine Physical Inventory Check"
    case vialOverfill = "Manufacturer Vial Overfill"
    case other = "Other Clinical Reason"

    public var id: String { rawValue }

    public var descriptionText: String {
        switch self {
        case .deadSpaceLoss:
            return "Small residual liquid remaining in the needle hub and syringe dead space after repeated injections (typical: ~0.02–0.05 mL per draw)."
        case .measurementVariance:
            return "Physical fluid meniscus level differs slightly from mathematical expectations."
        case .spillOrLeak:
            return "Liquid lost during needle priming, accidental bubble purge, or rubber stopper venting."
        case .evaporation:
            return "Gradual loss over extended multi-week refrigerated storage."
        case .countingError:
            return "Correction for a previously unlogged or miscalculated dose."
        case .physicalInspection:
            return "Regular scheduled manual inventory verification."
        case .vialOverfill:
            return "Manufacturer included extra active solution or dry mass exceeding nominal label."
        case .other:
            return "Specific user-provided reconciliation observation."
        }
    }
}

// MARK: - Disposal Reason
public enum DisposalReason: String, Codable, Sendable, CaseIterable, Identifiable {
    case depleted = "Fully Depleted (0 mL Remaining)"
    case expired = "Beyond Expiration / Shelf-Life Window"
    case contaminated = "Bacterial Contamination / Core Rubber Puncture"
    case particulateVisible = "Particulate Matter / Precipitation Observed"
    case cloudySolution = "Loss of Clarity / Turbid Discoloration"
    case storageCompromised = "Temperature Excursion (Unrefrigerated / Frozen)"
    case protocolCompleted = "Protocol Completed / Discontinued Compound"
    case other = "Other Disposal Rationale"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .depleted: return "checkmark.seal.fill"
        case .expired: return "clock.badge.exclamationmark"
        case .contaminated: return "biohazard"
        case .particulateVisible: return "eye.trianglebadge.exclamationmark"
        case .cloudySolution: return "smoke.fill"
        case .storageCompromised: return "thermometer.snowflake"
        case .protocolCompleted: return "flag.checkered"
        case .other: return "trash.fill"
        }
    }
}

// MARK: - Vial Accounting State
/// The deterministic state of a vial computed from its immutable event history.
public struct VialAccountingState: Identifiable, Codable, Sendable, Hashable {
    public let vialId: UUID
    public var compoundId: UUID
    public var compoundName: String
    public var lotNumber: String
    
    // Core physical mass & volume derived metrics
    public var initialDryMassMg: Double
    public var totalDiluentVolumeMl: Double
    public var isReconstituted: Bool
    public var currentConcentrationMgMl: Double?
    public var currentConcentrationMcgMl: Double?
    
    // Consumption & Accounting Summaries
    public var totalDoseVolumeConsumedMl: Double
    public var totalDoseMassConsumedMg: Double
    public var totalDosesAdministered: Int
    public var totalReconciliationVolumeAdjustmentMl: Double
    public var totalReconciliationMassAdjustmentMg: Double
    public var reconciliationCount: Int
    
    // Live derived levels
    public var currentVolumeRemainingMl: Double
    public var currentMassRemainingMg: Double
    public var remainingFraction: Double
    public var remainingPercentage: Double
    public var status: VialStatus
    
    // Temporal milestones
    public var initialStockDate: Date
    public var reconstitutedDate: Date?
    public var expirationDate: Date?
    public var depletedDate: Date?
    public var discardDate: Date?
    public var lastEventTimestamp: Date
    
    // Audit Trail Metadata
    public var auditTrailCount: Int
    public var isReconciled: Bool { reconciliationCount > 0 }
    
    public var id: UUID { vialId }

    public init(
        vialId: UUID,
        compoundId: UUID,
        compoundName: String,
        lotNumber: String = "",
        initialDryMassMg: Double,
        totalDiluentVolumeMl: Double = 0.0,
        isReconstituted: Bool = false,
        currentConcentrationMgMl: Double? = nil,
        currentConcentrationMcgMl: Double? = nil,
        totalDoseVolumeConsumedMl: Double = 0.0,
        totalDoseMassConsumedMg: Double = 0.0,
        totalDosesAdministered: Int = 0,
        totalReconciliationVolumeAdjustmentMl: Double = 0.0,
        totalReconciliationMassAdjustmentMg: Double = 0.0,
        reconciliationCount: Int = 0,
        currentVolumeRemainingMl: Double = 0.0,
        currentMassRemainingMg: Double = 0.0,
        remainingFraction: Double = 1.0,
        remainingPercentage: Double = 100.0,
        status: VialStatus = .unopened,
        initialStockDate: Date = Date(),
        reconstitutedDate: Date? = nil,
        expirationDate: Date? = nil,
        depletedDate: Date? = nil,
        discardDate: Date? = nil,
        lastEventTimestamp: Date = Date(),
        auditTrailCount: Int = 1
    ) {
        self.vialId = vialId
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.lotNumber = lotNumber
        self.initialDryMassMg = initialDryMassMg
        self.totalDiluentVolumeMl = totalDiluentVolumeMl
        self.isReconstituted = isReconstituted
        self.currentConcentrationMgMl = currentConcentrationMgMl
        self.currentConcentrationMcgMl = currentConcentrationMcgMl
        self.totalDoseVolumeConsumedMl = totalDoseVolumeConsumedMl
        self.totalDoseMassConsumedMg = totalDoseMassConsumedMg
        self.totalDosesAdministered = totalDosesAdministered
        self.totalReconciliationVolumeAdjustmentMl = totalReconciliationVolumeAdjustmentMl
        self.totalReconciliationMassAdjustmentMg = totalReconciliationMassAdjustmentMg
        self.reconciliationCount = reconciliationCount
        self.currentVolumeRemainingMl = currentVolumeRemainingMl
        self.currentMassRemainingMg = currentMassRemainingMg
        self.remainingFraction = remainingFraction
        self.remainingPercentage = remainingPercentage
        self.status = status
        self.initialStockDate = initialStockDate
        self.reconstitutedDate = reconstitutedDate
        self.expirationDate = expirationDate
        self.depletedDate = depletedDate
        self.discardDate = discardDate
        self.lastEventTimestamp = lastEventTimestamp
        self.auditTrailCount = auditTrailCount
    }
}

// MARK: - Supply Accounting State
public struct SupplyAccountingState: Identifiable, Codable, Sendable, Hashable {
    public let supplyItemId: UUID
    public var name: String
    public var category: SupplyCategory
    public var initialQuantity: Int
    public var totalConsumed: Int
    public var totalRestocked: Int
    public var totalReconciliationAdjustment: Int
    public var currentQuantityRemaining: Int
    public var isLowStock: Bool
    public var lastEventTimestamp: Date
    public var auditTrailCount: Int

    public var id: UUID { supplyItemId }

    public init(
        supplyItemId: UUID,
        name: String,
        category: SupplyCategory,
        initialQuantity: Int,
        totalConsumed: Int = 0,
        totalRestocked: Int = 0,
        totalReconciliationAdjustment: Int = 0,
        currentQuantityRemaining: Int = 0,
        isLowStock: Bool = false,
        lastEventTimestamp: Date = Date(),
        auditTrailCount: Int = 1
    ) {
        self.supplyItemId = supplyItemId
        self.name = name
        self.category = category
        self.initialQuantity = initialQuantity
        self.totalConsumed = totalConsumed
        self.totalRestocked = totalRestocked
        self.totalReconciliationAdjustment = totalReconciliationAdjustment
        self.currentQuantityRemaining = currentQuantityRemaining
        self.isLowStock = isLowStock
        self.lastEventTimestamp = lastEventTimestamp
        self.auditTrailCount = auditTrailCount
    }
}
