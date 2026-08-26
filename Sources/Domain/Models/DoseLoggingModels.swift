import Foundation

/// Represents protocol adherence, logging consistency, and streak statistics.
public struct AdherenceReport: Sendable, Codable, Hashable {
    public let overallPercentage: Double
    public let totalScheduled: Int
    public let totalTaken: Int
    public let totalSkipped: Int
    public let totalMissed: Int
    public let currentStreakDays: Int
    public let compoundBreakdown: [String: Double]

    public init(
        overallPercentage: Double,
        totalScheduled: Int,
        totalTaken: Int,
        totalSkipped: Int,
        totalMissed: Int,
        currentStreakDays: Int,
        compoundBreakdown: [String: Double] = [:]
    ) {
        self.overallPercentage = overallPercentage
        self.totalScheduled = totalScheduled
        self.totalTaken = totalTaken
        self.totalSkipped = totalSkipped
        self.totalMissed = totalMissed
        self.currentStreakDays = currentStreakDays
        self.compoundBreakdown = compoundBreakdown
    }
}

/// Represents user confirmation and ground-truth execution parameters submitted when logging a dose.
/// Carries both the expected protocol context and any actual modifications made by the user.
public struct DoseConfirmationRequest: Sendable, Codable, Hashable {
    public var doseEventId: UUID?
    public var protocolId: UUID?
    public var protocolCompoundId: UUID?
    public var compoundId: UUID
    public var compoundName: String
    public var plannedDoseAmount: Double?
    public var actualDoseAmount: Double
    public var doseUnit: DoseUnit
    public var actualRoute: AdministrationRoute
    public var injectionSiteId: String?
    public var injectionSiteName: String?
    public var vialId: UUID?
    public var actualTimestamp: Date
    public var scheduledTimestamp: Date?
    public var needleGauge: String?
    public var needleLength: String?
    public var siteReaction: SiteReactionSeverity
    public var painScore: Int? // 0 to 10
    public var notes: String
    public var subjectiveEffectScore: Int? // 1 to 10
    public var deductSupplies: Bool

    public init(
        doseEventId: UUID? = nil,
        protocolId: UUID? = nil,
        protocolCompoundId: UUID? = nil,
        compoundId: UUID,
        compoundName: String,
        plannedDoseAmount: Double? = nil,
        actualDoseAmount: Double,
        doseUnit: DoseUnit = .mcg,
        actualRoute: AdministrationRoute = .subcutaneous,
        injectionSiteId: String? = nil,
        injectionSiteName: String? = nil,
        vialId: UUID? = nil,
        actualTimestamp: Date = Date(),
        scheduledTimestamp: Date? = nil,
        needleGauge: String? = "31G",
        needleLength: String? = "5/16\"",
        siteReaction: SiteReactionSeverity = .none,
        painScore: Int? = 0,
        notes: String = "",
        subjectiveEffectScore: Int? = nil,
        deductSupplies: Bool = true
    ) {
        self.doseEventId = doseEventId
        self.protocolId = protocolId
        self.protocolCompoundId = protocolCompoundId
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.plannedDoseAmount = plannedDoseAmount ?? actualDoseAmount
        self.actualDoseAmount = actualDoseAmount
        self.doseUnit = doseUnit
        self.actualRoute = actualRoute
        self.injectionSiteId = injectionSiteId
        self.injectionSiteName = injectionSiteName
        self.vialId = vialId
        self.actualTimestamp = actualTimestamp
        self.scheduledTimestamp = scheduledTimestamp ?? actualTimestamp
        self.needleGauge = needleGauge
        self.needleLength = needleLength
        self.siteReaction = siteReaction
        self.painScore = painScore
        self.notes = notes
        self.subjectiveEffectScore = subjectiveEffectScore
        self.deductSupplies = deductSupplies
    }

    /// Convenience builder from an existing `DoseLog` or `DoseEvent`.
    public init(from doseLog: DoseLog, actualTimestamp: Date = Date()) {
        self.init(
            doseEventId: doseLog.id,
            protocolId: doseLog.protocolId,
            protocolCompoundId: doseLog.protocolCompoundId,
            compoundId: doseLog.compoundId,
            compoundName: doseLog.compoundName,
            plannedDoseAmount: doseLog.plannedDoseAmount,
            actualDoseAmount: doseLog.actualDoseAmount,
            doseUnit: doseLog.doseUnit,
            actualRoute: doseLog.actualRoute,
            injectionSiteId: doseLog.injectionSiteId,
            injectionSiteName: doseLog.injectionSiteName,
            vialId: doseLog.vialId,
            actualTimestamp: actualTimestamp,
            scheduledTimestamp: doseLog.scheduledTimestamp,
            notes: doseLog.notes,
            subjectiveEffectScore: doseLog.subjectiveEffectScore
        )
    }

    /// Convenience builder from an expected scheduled occurrence.
    public init(from occurrence: ExpectedDoseOccurrence, actualTimestamp: Date = Date()) {
        self.init(
            doseEventId: occurrence.associatedDoseLogId ?? occurrence.id,
            protocolId: occurrence.protocolId,
            protocolCompoundId: occurrence.protocolCompoundId,
            compoundId: occurrence.compoundId,
            compoundName: occurrence.compoundName,
            plannedDoseAmount: occurrence.plannedDoseAmount,
            actualDoseAmount: occurrence.actualDoseAmount ?? occurrence.plannedDoseAmount,
            doseUnit: occurrence.doseUnit,
            actualRoute: occurrence.route,
            injectionSiteId: nil,
            injectionSiteName: occurrence.injectionSiteName,
            vialId: occurrence.attachedVialId,
            actualTimestamp: actualTimestamp,
            scheduledTimestamp: occurrence.scheduledTimestamp,
            notes: occurrence.notes
        )
    }
}

/// The comprehensive outcome produced when a dose is logged by the `DoseLoggingEngine`.
/// Encapsulates the results of coordinating all six domain subsystems.
public struct DoseLoggingResult: Sendable {
    /// 1. The recorded or updated ground-truth dose event.
    public let doseEvent: DoseEvent

    /// 2. The anatomical injection site event linking the administration to the site rotation engine.
    public let injectionSiteEvent: InjectionSiteEvent?

    /// 3. The updated vial inventory record with consumed volume deducted.
    public let updatedVial: Vial?

    /// 4. The exact liquid volume in mL consumed from the vial.
    public let consumedVolumeMl: Double?

    /// 5. The updated protocol adherence and streak calculations from the analytics engine.
    public let adherenceReport: AdherenceReport

    /// 6. The unified timeline event emitted into the longitudinal health stream.
    public let timelineEvent: TimelineEvent

    /// 7. Information regarding the next scheduled reminder determined by the notification scheduler.
    public let nextScheduledReminder: ScheduledReminderInfo?

    public init(
        doseEvent: DoseEvent,
        injectionSiteEvent: InjectionSiteEvent?,
        updatedVial: Vial?,
        consumedVolumeMl: Double?,
        adherenceReport: AdherenceReport,
        timelineEvent: TimelineEvent,
        nextScheduledReminder: ScheduledReminderInfo?
    ) {
        self.doseEvent = doseEvent
        self.injectionSiteEvent = injectionSiteEvent
        self.updatedVial = updatedVial
        self.consumedVolumeMl = consumedVolumeMl
        self.adherenceReport = adherenceReport
        self.timelineEvent = timelineEvent
        self.nextScheduledReminder = nextScheduledReminder
    }
}

/// Metadata and timing for an upcoming scheduled dose reminder.
public struct ScheduledReminderInfo: Sendable, Codable, Hashable {
    public let protocolId: UUID?
    public let compoundId: UUID
    public let compoundName: String
    public let nextDoseTimestamp: Date
    public let reminderTriggerDate: Date
    public let plannedDoseAmount: Double
    public let doseUnit: DoseUnit
    public let notificationIdentifier: String

    public init(
        protocolId: UUID?,
        compoundId: UUID,
        compoundName: String,
        nextDoseTimestamp: Date,
        reminderTriggerDate: Date,
        plannedDoseAmount: Double,
        doseUnit: DoseUnit,
        notificationIdentifier: String
    ) {
        self.protocolId = protocolId
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.nextDoseTimestamp = nextDoseTimestamp
        self.reminderTriggerDate = reminderTriggerDate
        self.plannedDoseAmount = plannedDoseAmount
        self.doseUnit = doseUnit
        self.notificationIdentifier = notificationIdentifier
    }
}

/// Protocol for scheduling and managing dose reminders and restock notifications.
public protocol NotificationSchedulerProtocol: Sendable {
    /// Determines and schedules the next upcoming dose reminder for a given compound or protocol.
    func scheduleNextDoseReminder(
        protocolModel: ProtocolModel?,
        compoundId: UUID,
        compoundName: String,
        referenceDate: Date,
        leadTimeMinutes: Int
    ) async throws -> ScheduledReminderInfo?

    /// Schedules all upcoming dose reminders for an active protocol across a time horizon.
    func scheduleReminders(
        for protocolModel: ProtocolModel,
        referenceDate: Date,
        horizonDays: Int,
        timeZone: TimeZone
    ) async throws -> [ScheduledReminderInfo]

    /// Cancels obsolete notifications for a protocol and schedules new ones from the updated protocol definition.
    func rescheduleReminders(
        for protocolModel: ProtocolModel,
        referenceDate: Date,
        horizonDays: Int,
        timeZone: TimeZone
    ) async throws -> [ScheduledReminderInfo]

    /// Cancels a previously scheduled reminder by its identifier.
    func cancelReminder(identifier: String) async throws

    /// Cancels all pending dose reminders for a protocol.
    func cancelReminders(forProtocol protocolId: UUID) async throws

    /// Reschedules all reminders across multiple protocols (e.g., app launch or global sync).
    func rescheduleAll(
        protocols: [ProtocolModel],
        referenceDate: Date,
        horizonDays: Int,
        timeZone: TimeZone
    ) async throws -> [ScheduledReminderInfo]

    /// Handles daylight-saving time shifts or user timezone changes by recalculating all calendar triggers.
    func handleTimezoneOrDSTChange(
        protocols: [ProtocolModel],
        timeZone: TimeZone
    ) async throws -> [ScheduledReminderInfo]

    /// Returns the currently pending scheduled reminders.
    func getPendingReminders() async -> [ScheduledReminderInfo]

    /// Registers the custom notification action categories with UserNotifications framework.
    func registerNotificationCategories() async throws

    /// Requests user authorization for local notifications.
    func requestAuthorization(options: NotificationAuthorizationOptions) async throws -> Bool

    /// Checks the current notification authorization status.
    func getAuthorizationStatus() async -> NotificationAuthorizationStatus
}

