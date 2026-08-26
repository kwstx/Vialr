import Foundation
import Domain

#if canImport(UserNotifications)
import UserNotifications
#endif

/// Notification scheduler responsible for computing upcoming protocol occurrences and scheduling system reminders.
public final class NotificationScheduler: NotificationSchedulerProtocol, @unchecked Sendable {
    private let schedulingEngine: ProtocolSchedulingEngine
    private let calendar: Calendar

    public init(
        schedulingEngine: ProtocolSchedulingEngine = ProtocolSchedulingEngine(),
        calendar: Calendar = .current
    ) {
        self.schedulingEngine = schedulingEngine
        self.calendar = calendar
    }

    /// Determines and schedules the next upcoming dose reminder for a protocol compound.
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

        // Generate upcoming occurrences from referenceDate looking forward up to 60 days
        let horizonDays = 60
        guard let endDate = calendar.date(byAdding: .day, value: horizonDays, to: referenceDate) else {
            return nil
        }

        let occurrences = schedulingEngine.generateOccurrences(for: proto, in: referenceDate...endDate)
            .filter { $0.compoundId == compoundId && $0.scheduledTimestamp > referenceDate && !$0.isTaken }

        guard let nextOccurrence = occurrences.first else {
            return nil
        }

        let effectiveLeadTime = compound.reminderLeadTimeMinutes ?? leadTimeMinutes
        let triggerDate = nextOccurrence.scheduledTimestamp.addingTimeInterval(-Double(effectiveLeadTime * 60))
        let identifier = "dose_reminder_\(proto.id.uuidString)_\(compoundId.uuidString)_\(Int(nextOccurrence.scheduledTimestamp.timeIntervalSince1970))"

        let reminderInfo = ScheduledReminderInfo(
            protocolId: proto.id,
            compoundId: compoundId,
            compoundName: compoundName,
            nextDoseTimestamp: nextOccurrence.scheduledTimestamp,
            reminderTriggerDate: max(Date().addingTimeInterval(5), triggerDate),
            plannedDoseAmount: nextOccurrence.plannedDoseAmount,
            doseUnit: nextOccurrence.doseUnit,
            notificationIdentifier: identifier
        )

        // Schedule system notification if available on platform
        #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
        try await dispatchLocalNotification(for: reminderInfo, route: nextOccurrence.route)
        #endif

        return reminderInfo
    }

    /// Cancels a scheduled notification by identifier.
    public func cancelReminder(identifier: String) async throws {
        #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        #endif
    }

    /// Cancels all pending notifications for a specific protocol.
    public func cancelReminders(forProtocol protocolId: UUID) async throws {
        #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let prefix = "dose_reminder_\(protocolId.uuidString)"
        let toRemove = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        if !toRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
        #endif
    }

    #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
    private func dispatchLocalNotification(for reminder: ScheduledReminderInfo, route: AdministrationRoute) async throws {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Dose Reminder: \(reminder.compoundName)"
        let amountStr = reminder.plannedDoseAmount.truncatingRemainder(dividingBy: 1) == 0 ?
            String(format: "%.0f", reminder.plannedDoseAmount) :
            String(format: "%.1f", reminder.plannedDoseAmount)
        content.body = "Scheduled dose of \(amountStr) \(reminder.doseUnit.rawValue) (\(route.rawValue)). Tap to log dose."
        content.sound = .default
        content.userInfo = [
            "protocolId": reminder.protocolId?.uuidString ?? "",
            "compoundId": reminder.compoundId.uuidString,
            "compoundName": reminder.compoundName,
            "doseAmount": reminder.plannedDoseAmount,
            "doseUnit": reminder.doseUnit.rawValue
        ]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.reminderTriggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: reminder.notificationIdentifier, content: content, trigger: trigger)

        try? await center.add(request)
    }
    #endif
}
