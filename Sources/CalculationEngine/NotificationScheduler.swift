import Foundation
import Domain

#if canImport(UserNotifications)
import UserNotifications
#endif

/// Notification scheduler responsible for computing upcoming protocol occurrences,
/// managing local notification lifecycles (scheduling, cancellation, rescheduling),
/// and handling timezone and daylight-saving shifts using Apple's UserNotifications framework.
public final class NotificationScheduler: NotificationSchedulerProtocol, @unchecked Sendable {
    private let schedulingEngine: ProtocolSchedulingEngine
    private let defaultCalendar: Calendar
    private let maxPendingNotificationLimit: Int = 64
    public var privacyMode: NotificationPrivacyMode

    // In-memory fallback tracking for cross-platform compatibility and unit testing
    private let stateLock = NSLock()
    private var inMemoryScheduledReminders: [String: ScheduledReminderInfo] = [:]
    private var inMemoryAuthorizationStatus: NotificationAuthorizationStatus = .authorized

    public init(
        schedulingEngine: ProtocolSchedulingEngine = ProtocolSchedulingEngine(),
        calendar: Calendar = .current,
        privacyMode: NotificationPrivacyMode = .redacted
    ) {
        self.schedulingEngine = schedulingEngine
        self.defaultCalendar = calendar
        self.privacyMode = privacyMode
    }

    // MARK: - 1. Schedule Next Single Dose Reminder
    /// Determines and schedules the next immediate dose reminder for a protocol compound.
    public func scheduleNextDoseReminder(
        protocolModel: ProtocolModel?,
        compoundId: UUID,
        compoundName: String,
        referenceDate: Date = Date(),
        leadTimeMinutes: Int = 15
    ) async throws -> ScheduledReminderInfo? {
        guard let proto = protocolModel, proto.status == .active else {
            return nil
        }

        guard let compound = proto.compounds.first(where: { $0.compoundId == compoundId && $0.isActive }) else {
            return nil
        }

        let timeZone = defaultCalendar.timeZone
        let reminders = try await scheduleReminders(
            for: proto,
            referenceDate: referenceDate,
            horizonDays: 60,
            timeZone: timeZone
        )

        return reminders.first(where: { $0.compoundId == compoundId })
    }

    // MARK: - 2. Batch Schedule Reminders for an Active Protocol
    /// Schedules upcoming dose reminders for an active protocol across a time horizon,
    /// converting mathematically generated occurrences into system notification requests.
    public func scheduleReminders(
        for protocolModel: ProtocolModel,
        referenceDate: Date = Date(),
        horizonDays: Int = 30,
        timeZone: TimeZone = .current
    ) async throws -> [ScheduledReminderInfo] {
        guard protocolModel.status == .active else {
            return []
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard let endDate = calendar.date(byAdding: .day, value: horizonDays, to: referenceDate) else {
            return []
        }

        let engine = ProtocolSchedulingEngine(calendar: calendar)
        let occurrences = engine.generateOccurrences(for: protocolModel, in: referenceDate...endDate)
            .filter { $0.scheduledTimestamp > referenceDate && !$0.isTaken }

        var scheduled: [ScheduledReminderInfo] = []

        for occurrence in occurrences {
            guard let compound = protocolModel.compounds.first(where: { $0.id == occurrence.protocolCompoundId || $0.compoundId == occurrence.compoundId }),
                  compound.isActive && compound.reminderEnabled else {
                continue
            }

            let effectiveLeadTime = compound.reminderLeadTimeMinutes
            let triggerDate = occurrence.scheduledTimestamp.addingTimeInterval(-Double(effectiveLeadTime * 60))
            
            // If trigger date has passed, trigger slightly in future (5 seconds) if dose timestamp is still upcoming
            let finalTriggerDate = max(Date().addingTimeInterval(5), triggerDate)
            guard occurrence.scheduledTimestamp > Date() else { continue }

            let identifier = generateNotificationIdentifier(
                protocolId: protocolModel.id,
                compoundId: occurrence.compoundId,
                timestamp: occurrence.scheduledTimestamp
            )

            let reminderInfo = ScheduledReminderInfo(
                protocolId: protocolModel.id,
                compoundId: occurrence.compoundId,
                compoundName: occurrence.compoundName,
                nextDoseTimestamp: occurrence.scheduledTimestamp,
                reminderTriggerDate: finalTriggerDate,
                plannedDoseAmount: occurrence.plannedDoseAmount,
                doseUnit: occurrence.doseUnit,
                notificationIdentifier: identifier
            )

            let payload = ScheduledNotificationPayload(
                notificationIdentifier: identifier,
                protocolId: protocolModel.id,
                protocolName: protocolModel.name,
                compoundId: occurrence.compoundId,
                compoundName: occurrence.compoundName,
                doseAmount: occurrence.plannedDoseAmount,
                doseUnit: occurrence.doseUnit,
                route: occurrence.route,
                scheduledTimestamp: occurrence.scheduledTimestamp,
                triggerTimestamp: finalTriggerDate,
                occurrenceId: occurrence.id,
                attachedVialId: occurrence.attachedVialId,
                foodRequirement: occurrence.foodRequirement,
                deepLinkUri: "vialr://dose/log?compoundId=\(occurrence.compoundId.uuidString)&protocolId=\(protocolModel.id.uuidString)"
            )

            // Save in in-memory state
            stateLock.lock()
            inMemoryScheduledReminders[identifier] = reminderInfo
            stateLock.unlock()

            // Dispatch to UserNotifications framework
            #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
            try await dispatchLocalNotification(payload: payload, triggerDate: finalTriggerDate, calendar: calendar)
            #endif

            scheduled.append(reminderInfo)

            if scheduled.count >= maxPendingNotificationLimit {
                break
            }
        }

        return scheduled
    }

    // MARK: - 3. Protocol Rescheduling Lifecycle (Cancel Obsolete & Reschedule)
    /// Cancels obsolete notifications for a modified protocol and creates the new schedule.
    public func rescheduleReminders(
        for protocolModel: ProtocolModel,
        referenceDate: Date = Date(),
        horizonDays: Int = 30,
        timeZone: TimeZone = .current
    ) async throws -> [ScheduledReminderInfo] {
        // 1. Cancel all existing pending notifications for this protocol
        try await cancelReminders(forProtocol: protocolModel.id)

        // 2. If protocol is active, schedule fresh reminders
        guard protocolModel.status == .active else {
            return []
        }

        return try await scheduleReminders(
            for: protocolModel,
            referenceDate: referenceDate,
            horizonDays: horizonDays,
            timeZone: timeZone
        )
    }

    // MARK: - 4. Cancellation Methods
    /// Cancels a specific scheduled reminder by its identifier.
    public func cancelReminder(identifier: String) async throws {
        stateLock.lock()
        inMemoryScheduledReminders.removeValue(forKey: identifier)
        stateLock.unlock()

        #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        #endif
    }

    /// Cancels all pending notifications for a specific protocol.
    public func cancelReminders(forProtocol protocolId: UUID) async throws {
        let prefix1 = "vialr_dose_\(protocolId.uuidString)"
        let prefix2 = "dose_reminder_\(protocolId.uuidString)"

        stateLock.lock()
        let matchingKeys = inMemoryScheduledReminders.keys.filter {
            $0.hasPrefix(prefix1) || $0.hasPrefix(prefix2) || inMemoryScheduledReminders[$0]?.protocolId == protocolId
        }
        for key in matchingKeys {
            inMemoryScheduledReminders.removeValue(forKey: key)
        }
        stateLock.unlock()

        #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let toRemove = pending.filter { req in
            req.identifier.hasPrefix(prefix1) ||
            req.identifier.hasPrefix(prefix2) ||
            (req.content.userInfo["protocolId"] as? String) == protocolId.uuidString
        }.map(\.identifier)

        if !toRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
        #endif
    }

    // MARK: - 5. Global Reschedule Across All Protocols
    /// Reschedules all reminders across all active protocols.
    public func rescheduleAll(
        protocols: [ProtocolModel],
        referenceDate: Date = Date(),
        horizonDays: Int = 30,
        timeZone: TimeZone = .current
    ) async throws -> [ScheduledReminderInfo] {
        // Cancel all pending reminders first
        #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let allIdentifiers = pending.map(\.identifier)
        if !allIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
        }
        #endif

        stateLock.lock()
        inMemoryScheduledReminders.removeAll()
        stateLock.unlock()

        var allScheduled: [ScheduledReminderInfo] = []
        let activeProtocols = protocols.filter { $0.status == .active }

        for proto in activeProtocols {
            let scheduled = try await scheduleReminders(
                for: proto,
                referenceDate: referenceDate,
                horizonDays: horizonDays,
                timeZone: timeZone
            )
            allScheduled.append(contentsOf: scheduled)
            if allScheduled.count >= maxPendingNotificationLimit {
                break
            }
        }

        return allScheduled
    }

    // MARK: - 6. Timezone & Daylight-Saving Change Handling
    /// Handles daylight-saving time shifts or user timezone changes by recalculating all calendar triggers.
    public func handleTimezoneOrDSTChange(
        protocols: [ProtocolModel],
        timeZone: TimeZone = .current
    ) async throws -> [ScheduledReminderInfo] {
        return try await rescheduleAll(
            protocols: protocols,
            referenceDate: Date(),
            horizonDays: 30,
            timeZone: timeZone
        )
    }

    // MARK: - 7. Query Pending Reminders
    /// Returns the currently pending scheduled reminders.
    public func getPendingReminders() async -> [ScheduledReminderInfo] {
        #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        var results: [ScheduledReminderInfo] = []

        for req in pendingRequests {
            if let payload = ScheduledNotificationPayload.from(userInfo: req.content.userInfo) {
                results.append(ScheduledReminderInfo(
                    protocolId: payload.protocolId,
                    compoundId: payload.compoundId,
                    compoundName: payload.compoundName,
                    nextDoseTimestamp: payload.scheduledTimestamp,
                    reminderTriggerDate: payload.triggerTimestamp,
                    plannedDoseAmount: payload.doseAmount,
                    doseUnit: payload.doseUnit,
                    notificationIdentifier: payload.notificationIdentifier
                ))
            } else if let cached = inMemoryScheduledReminders[req.identifier] {
                results.append(cached)
            }
        }
        return results.sorted { $0.nextDoseTimestamp < $1.nextDoseTimestamp }
        #else
        stateLock.lock()
        defer { stateLock.unlock() }
        return Array(inMemoryScheduledReminders.values).sorted { $0.nextDoseTimestamp < $1.nextDoseTimestamp }
        #endif
    }

    // MARK: - 8. Category & Interactive Action Registration
    /// Registers custom notification categories and interactive actions with the UserNotifications framework.
    public func registerNotificationCategories() async throws {
        #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
        let center = UNUserNotificationCenter.current()

        // Action: Log Dose Now
        let logDoseAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.logDose.rawIdentifier,
            title: "Log Dose Now",
            options: [.foreground]
        )

        // Action: Snooze 15 Minutes
        let snooze15Action = UNNotificationAction(
            identifier: NotificationActionIdentifier.snooze15.rawIdentifier,
            title: "Snooze (15m)",
            options: []
        )

        // Action: Skip Dose
        let skipDoseAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.skipDose.rawIdentifier,
            title: "Skip Dose",
            options: [.destructive]
        )

        // Category: Dose Reminder
        let doseReminderCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.doseReminder.rawIdentifier,
            actions: [logDoseAction, snooze15Action, skipDoseAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Action: View Vial / Inventory
        let viewVialAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.viewVial.rawIdentifier,
            title: "Check Inventory",
            options: [.foreground]
        )

        // Category: Restock Alert
        let restockCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.restockAlert.rawIdentifier,
            actions: [viewVialAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Action: View Lab Panel
        let viewLabAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.viewLab.rawIdentifier,
            title: "View Lab Panel",
            options: [.foreground]
        )

        // Category: Lab Reminder
        let labCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.labReminder.rawIdentifier,
            actions: [viewLabAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Category: System Alert
        let systemCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.systemAlert.rawIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([
            doseReminderCategory,
            restockCategory,
            labCategory,
            systemCategory
        ])
        #endif
    }

    // MARK: - 9. Authorization Management
    /// Requests user authorization for local notifications.
    public func requestAuthorization(options: NotificationAuthorizationOptions = .standard) async throws -> Bool {
        #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
        let center = UNUserNotificationCenter.current()
        var unOptions: UNAuthorizationOptions = []
        if options.contains(.badge) { unOptions.insert(.badge) }
        if options.contains(.sound) { unOptions.insert(.sound) }
        if options.contains(.alert) { unOptions.insert(.alert) }
        if options.contains(.provisional) { unOptions.insert(.provisional) }
        if options.contains(.criticalAlert) { unOptions.insert(.criticalAlert) }

        let granted = try await center.requestAuthorization(options: unOptions)
        try await registerNotificationCategories()
        return granted
        #else
        stateLock.lock()
        inMemoryAuthorizationStatus = .authorized
        stateLock.unlock()
        return true
        #endif
    }

    /// Checks the current notification authorization status.
    public func getAuthorizationStatus() async -> NotificationAuthorizationStatus {
        #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .ephemeral: return .ephemeral
        @unknown default: return .authorized
        }
        #else
        stateLock.lock()
        defer { stateLock.unlock() }
        return inMemoryAuthorizationStatus
        #endif
    }

    // MARK: - Internal Helpers
    private func generateNotificationIdentifier(protocolId: UUID, compoundId: UUID, timestamp: Date) -> String {
        return "vialr_dose_\(protocolId.uuidString)_\(compoundId.uuidString)_\(Int(timestamp.timeIntervalSince1970))"
    }

    #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
    private func dispatchLocalNotification(
        payload: ScheduledNotificationPayload,
        triggerDate: Date,
        calendar: Calendar
    ) async throws {
        let center = UNUserNotificationCenter.current()

        let privacyFormatted = NotificationPrivacyFormatter.formatDoseReminder(
            compoundName: payload.compoundName,
            doseAmount: payload.doseAmount,
            doseUnit: payload.doseUnit,
            route: payload.route,
            mode: privacyMode
        )

        let content = UNMutableNotificationContent()
        content.title = privacyFormatted.title
        content.body = privacyFormatted.body
        if let sub = privacyFormatted.subtitle {
            content.subtitle = sub
        }
        content.sound = .default
        content.categoryIdentifier = privacyFormatted.categoryIdentifier
        content.threadIdentifier = privacyFormatted.threadIdentifier
        content.userInfo = payload.userInfoDictionary

        // Extract components in the user's specific timezone to preserve wall-clock time across DST transitions
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: payload.notificationIdentifier, content: content, trigger: trigger)

        try await center.add(request)
    }
    #endif
}
