import Foundation

/// Represents a recorded dose event capturing what actually happened vs what was planned.
/// While the planned schedule defines expectations, DoseEvent captures the ground-truth
/// execution (actual timestamp, actual dosage, site, vial, skipped reasons), enabling exact adherence analytics.
public struct DoseEvent: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var protocolId: UUID?
    public var protocolCompoundId: UUID?
    public var compoundId: UUID
    public var compoundName: String
    public var scheduledTimestamp: Date
    public var actualTimestamp: Date?
    public var plannedDoseAmount: Double?
    public var actualDoseAmount: Double
    public var doseUnit: DoseUnit
    public var status: DoseEventStatus
    public var injectionSiteId: String?
    public var injectionSiteName: String?
    public var vialId: UUID?
    public var actualRoute: AdministrationRoute
    public var plannedRoute: AdministrationRoute?
    public var isPRNOrUnscheduled: Bool
    public var skippedReason: String?
    public var subjectiveEffectScore: Int? // 1 to 10
    public var notes: String
    public var loggedByUserId: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    // MARK: - Compatibility Accessors for Legacy DoseLog Interface
    public var scheduledDate: Date {
        get { scheduledTimestamp }
        set { scheduledTimestamp = newValue }
    }

    public var loggedDate: Date? {
        get { actualTimestamp }
        set { actualTimestamp = newValue }
    }

    public var doseAmount: Double {
        get { actualDoseAmount }
        set { actualDoseAmount = newValue }
    }

    public var administrationRoute: AdministrationRoute {
        get { actualRoute }
        set { actualRoute = newValue }
    }

    public var protocolItemId: UUID? {
        get { protocolCompoundId }
        set { protocolCompoundId = newValue }
    }

    // MARK: - Primary Initializer
    public init(
        id: UUID = UUID(),
        protocolId: UUID? = nil,
        protocolCompoundId: UUID? = nil,
        compoundId: UUID,
        compoundName: String,
        scheduledTimestamp: Date = Date(),
        actualTimestamp: Date? = nil,
        plannedDoseAmount: Double? = nil,
        actualDoseAmount: Double,
        doseUnit: DoseUnit = .mcg,
        status: DoseEventStatus = .scheduled,
        injectionSiteId: String? = nil,
        injectionSiteName: String? = nil,
        vialId: UUID? = nil,
        actualRoute: AdministrationRoute = .subcutaneous,
        plannedRoute: AdministrationRoute? = nil,
        isPRNOrUnscheduled: Bool = false,
        skippedReason: String? = nil,
        subjectiveEffectScore: Int? = nil,
        notes: String = "",
        loggedByUserId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.protocolId = protocolId
        self.protocolCompoundId = protocolCompoundId
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.scheduledTimestamp = scheduledTimestamp
        self.actualTimestamp = actualTimestamp
        self.plannedDoseAmount = plannedDoseAmount ?? actualDoseAmount
        self.actualDoseAmount = actualDoseAmount
        self.doseUnit = doseUnit
        self.status = status
        self.injectionSiteId = injectionSiteId
        self.injectionSiteName = injectionSiteName
        self.vialId = vialId
        self.actualRoute = actualRoute
        self.plannedRoute = plannedRoute ?? actualRoute
        self.isPRNOrUnscheduled = isPRNOrUnscheduled
        self.skippedReason = skippedReason
        self.subjectiveEffectScore = subjectiveEffectScore
        self.notes = notes
        self.loggedByUserId = loggedByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Compatibility Initializer for Existing Call Sites
    public init(
        id: UUID = UUID(),
        protocolId: UUID? = nil,
        protocolItemId: UUID? = nil,
        compoundId: UUID,
        compoundName: String,
        scheduledDate: Date,
        loggedDate: Date? = nil,
        doseAmount: Double,
        doseUnit: DoseUnit = .mcg,
        status: DoseEventStatus = .scheduled,
        injectionSiteId: String? = nil,
        injectionSiteName: String? = nil,
        vialId: UUID? = nil,
        administrationRoute: AdministrationRoute = .subcutaneous,
        notes: String = "",
        skippedReason: String? = nil,
        subjectiveEffectScore: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.init(
            id: id,
            protocolId: protocolId,
            protocolCompoundId: protocolItemId,
            compoundId: compoundId,
            compoundName: compoundName,
            scheduledTimestamp: scheduledDate,
            actualTimestamp: loggedDate,
            plannedDoseAmount: doseAmount,
            actualDoseAmount: doseAmount,
            doseUnit: doseUnit,
            status: status,
            injectionSiteId: injectionSiteId,
            injectionSiteName: injectionSiteName,
            vialId: vialId,
            actualRoute: administrationRoute,
            plannedRoute: administrationRoute,
            isPRNOrUnscheduled: protocolId == nil,
            skippedReason: skippedReason,
            subjectiveEffectScore: subjectiveEffectScore,
            notes: notes,
            loggedByUserId: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    // MARK: - Adherence & Timing Analytics Helpers
    /// Whether the dose was successfully completed.
    public var isTaken: Bool {
        status == .taken
    }

    /// Time variance in minutes between planned schedule and actual administration.
    public var adherenceVarianceMinutes: Int? {
        guard let actual = actualTimestamp else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute], from: scheduledTimestamp, to: actual)
        return components.minute
    }

    /// Checks if the dose was taken within an acceptable schedule window (default: ±2 hours).
    public func isTakenOnTime(toleranceMinutes: Int = 120) -> Bool {
        guard status == .taken, let variance = adherenceVarianceMinutes else { return false }
        return abs(variance) <= toleranceMinutes
    }

    /// Difference between actual dose taken and planned schedule dose.
    public var dosageDeviation: Double {
        guard let planned = plannedDoseAmount else { return 0.0 }
        return actualDoseAmount - planned
    }
}

// MARK: - Dose Event Status
public enum DoseEventStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case scheduled = "Scheduled"
    case taken = "Taken"
    case skipped = "Skipped"
    case missed = "Missed"
    case partialDose = "Partial Dose"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .scheduled: return "clock"
        case .taken: return "checkmark.circle.fill"
        case .skipped: return "slash.circle"
        case .missed: return "exclamationmark.circle.fill"
        case .partialDose: return "circle.lefthalf.filled"
        }
    }

    public var badgeColorHex: String {
        switch self {
        case .scheduled: return "#3B82F6"
        case .taken: return "#10B981"
        case .skipped: return "#F59E0B"
        case .missed: return "#EF4444"
        case .partialDose: return "#8B5CF6"
        }
    }
}

// MARK: - Compatibility Typealiases
public typealias DoseLog = DoseEvent
public typealias DoseStatus = DoseEventStatus
