import Foundation

/// Represents an individual expected dose occurrence projected dynamically from a protocol's recurrence rule.
/// Occurrences are generated on-the-fly across calendar windows without generating infinite database records.
public struct ExpectedDoseOccurrence: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var protocolId: UUID
    public var protocolName: String
    public var protocolCompoundId: UUID
    public var compoundId: UUID
    public var compoundName: String
    public var scheduledTimestamp: Date
    public var plannedDoseAmount: Double
    public var doseUnit: DoseUnit
    public var route: AdministrationRoute
    public var preferredTimeOfDay: TimeOfDay
    public var foodRequirement: FoodRequirement
    public var reminderTime: Date?
    public var reminderEnabled: Bool
    public var reminderLeadTimeMinutes: Int
    public var attachedVialId: UUID?
    
    // Execution State (reconciled against ground-truth DoseEvents)
    public var status: DoseEventStatus
    public var associatedDoseLogId: UUID?
    public var actualTimestamp: Date?
    public var actualDoseAmount: Double?
    public var injectionSiteName: String?
    public var notes: String

    public init(
        id: UUID = UUID(),
        protocolId: UUID,
        protocolName: String,
        protocolCompoundId: UUID,
        compoundId: UUID,
        compoundName: String,
        scheduledTimestamp: Date,
        plannedDoseAmount: Double,
        doseUnit: DoseUnit = .mcg,
        route: AdministrationRoute = .subcutaneous,
        preferredTimeOfDay: TimeOfDay = .morning,
        foodRequirement: FoodRequirement = .fasted,
        reminderTime: Date? = nil,
        reminderEnabled: Bool = true,
        reminderLeadTimeMinutes: Int = 15,
        attachedVialId: UUID? = nil,
        status: DoseEventStatus = .scheduled,
        associatedDoseLogId: UUID? = nil,
        actualTimestamp: Date? = nil,
        actualDoseAmount: Double? = nil,
        injectionSiteName: String? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.protocolId = protocolId
        self.protocolName = protocolName
        self.protocolCompoundId = protocolCompoundId
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.scheduledTimestamp = scheduledTimestamp
        self.plannedDoseAmount = plannedDoseAmount
        self.doseUnit = doseUnit
        self.route = route
        self.preferredTimeOfDay = preferredTimeOfDay
        self.foodRequirement = foodRequirement
        self.reminderTime = reminderTime
        self.reminderEnabled = reminderEnabled
        self.reminderLeadTimeMinutes = reminderLeadTimeMinutes
        self.attachedVialId = attachedVialId
        self.status = status
        self.associatedDoseLogId = associatedDoseLogId
        self.actualTimestamp = actualTimestamp
        self.actualDoseAmount = actualDoseAmount
        self.injectionSiteName = injectionSiteName
        self.notes = notes
    }

    /// Whether this dose has already been executed.
    public var isTaken: Bool {
        status == .taken
    }

    /// Whether the scheduled time falls on today's calendar date.
    public var isToday: Bool {
        Calendar.current.isDateInToday(scheduledTimestamp)
    }

    /// Whether the scheduled timestamp is strictly in the past (by more than 60 mins) and not taken.
    public var isOverdue: Bool {
        guard status == .scheduled else { return false }
        return scheduledTimestamp.addingTimeInterval(3600) < Date()
    }

    /// Formatted dose string (e.g., "250 mcg" or "2.5 mg").
    public var formattedDose: String {
        let amount = actualDoseAmount ?? plannedDoseAmount
        let formattedNumber = amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", amount)
            : String(format: "%.2f", amount)
        return "\(formattedNumber) \(doseUnit.rawValue)"
    }

    /// Convenience method to create a draft DoseLog/DoseEvent from this expected occurrence.
    public func toDoseLog(
        actualDose: Double? = nil,
        injectionSiteId: String? = nil,
        injectionSiteName: String? = nil,
        vialId: UUID? = nil,
        status: DoseEventStatus = .taken,
        actualTimestamp: Date = Date(),
        notes: String = ""
    ) -> DoseEvent {
        DoseEvent(
            protocolId: protocolId,
            protocolCompoundId: protocolCompoundId,
            compoundId: compoundId,
            compoundName: compoundName,
            scheduledTimestamp: scheduledTimestamp,
            actualTimestamp: actualTimestamp,
            plannedDoseAmount: plannedDoseAmount,
            actualDoseAmount: actualDose ?? plannedDoseAmount,
            doseUnit: doseUnit,
            status: status,
            injectionSiteId: injectionSiteId,
            injectionSiteName: injectionSiteName,
            vialId: vialId ?? attachedVialId,
            actualRoute: route,
            plannedRoute: route,
            notes: notes.isEmpty ? self.notes : notes
        )
    }
}
