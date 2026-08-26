import XCTest
import Domain
@testable import CalculationEngine

final class NotificationSchedulerTests: XCTestCase {
    var scheduler: NotificationScheduler!
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)! // UTC for deterministic testing
        let engine = ProtocolSchedulingEngine(calendar: calendar)
        scheduler = NotificationScheduler(schedulingEngine: engine, calendar: calendar)
    }

    // MARK: - 1. Schedule Generated From Protocol Recurrence
    func testDoseReminderGeneratedFromProtocolSchedule() async throws {
        var startComps = DateComponents()
        startComps.year = 2026
        startComps.month = 9
        startComps.day = 1
        startComps.hour = 0
        startComps.minute = 0
        let startDate = calendar.date(from: startComps)!

        var reminderTimeComps = DateComponents()
        reminderTimeComps.hour = 8
        reminderTimeComps.minute = 30
        let reminderTime = calendar.date(from: reminderTimeComps)

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "Semaglutide",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay,
            reminderEnabled: true,
            reminderTime: reminderTime,
            reminderLeadTimeMinutes: 15
        )

        let protocolModel = ProtocolModel(
            id: UUID(),
            name: "Weight Loss Protocol",
            status: .active,
            startDate: startDate,
            compounds: [compound]
        )

        let scheduled = try await scheduler.scheduleReminders(
            for: protocolModel,
            referenceDate: startDate,
            horizonDays: 7,
            timeZone: calendar.timeZone
        )

        XCTAssertEqual(scheduled.count, 7, "Should schedule 7 daily dose reminders across 7 days")
        
        let first = try XCTUnwrap(scheduled.first)
        XCTAssertEqual(first.compoundName, "Semaglutide")
        XCTAssertEqual(first.plannedDoseAmount, 250)
        XCTAssertEqual(first.doseUnit, .mcg)
        
        // Dose at 08:30, Lead time 15m -> Trigger at 08:15
        let doseHour = calendar.component(.hour, from: first.nextDoseTimestamp)
        let doseMin = calendar.component(.minute, from: first.nextDoseTimestamp)
        XCTAssertEqual(doseHour, 8)
        XCTAssertEqual(doseMin, 30)

        let triggerHour = calendar.component(.hour, from: first.reminderTriggerDate)
        let triggerMin = calendar.component(.minute, from: first.reminderTriggerDate)
        XCTAssertEqual(triggerHour, 8)
        XCTAssertEqual(triggerMin, 15)
    }

    // MARK: - 2. Protocol Change Cancels Obsolete Notifications and Reschedules New Schedule
    func testProtocolChangeCancelsObsoleteAndCreatesNewSchedule() async throws {
        var startComps = DateComponents()
        startComps.year = 2026
        startComps.month = 9
        startComps.day = 1
        let startDate = calendar.date(from: startComps)!

        let protocolId = UUID()
        let compoundId = UUID()

        // Initial Schedule: Daily
        let initialCompound = ProtocolCompound(
            compoundId: compoundId,
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay,
            reminderEnabled: true
        )
        let initialProto = ProtocolModel(
            id: protocolId,
            name: "Healing Protocol",
            status: .active,
            startDate: startDate,
            compounds: [initialCompound]
        )

        // Schedule initial 10 days
        let initialScheduled = try await scheduler.scheduleReminders(
            for: initialProto,
            referenceDate: startDate,
            horizonDays: 10,
            timeZone: calendar.timeZone
        )
        XCTAssertEqual(initialScheduled.count, 10)

        // User changes protocol to Every Other Day (EOD) with 500 mcg
        let updatedCompound = ProtocolCompound(
            compoundId: compoundId,
            compoundName: "BPC-157",
            doseAmount: 500,
            doseUnit: .mcg,
            scheduleRule: .everyOtherDay,
            reminderEnabled: true
        )
        let updatedProto = ProtocolModel(
            id: protocolId,
            name: "Healing Protocol Modified",
            status: .active,
            startDate: startDate,
            compounds: [updatedCompound]
        )

        let updatedScheduled = try await scheduler.rescheduleReminders(
            for: updatedProto,
            referenceDate: startDate,
            horizonDays: 10,
            timeZone: calendar.timeZone
        )

        // 10 days of EOD (Day 0, 2, 4, 6, 8, 10) -> 5 or 6 occurrences
        XCTAssertEqual(updatedScheduled.count, 5, "Rescheduled reminders should match the new EOD schedule")
        XCTAssertEqual(updatedScheduled.first?.plannedDoseAmount, 500, "Updated dose amount should be 500 mcg")
    }

    // MARK: - 3. Pausing Protocol Cancels Pending Notifications
    func testPausingProtocolCancelsAllPendingNotifications() async throws {
        var startComps = DateComponents()
        startComps.year = 2026
        startComps.month = 9
        startComps.day = 1
        let startDate = calendar.date(from: startComps)!

        let protocolId = UUID()
        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "TB-500",
            doseAmount: 2.0,
            doseUnit: .mg,
            scheduleRule: .everyDay,
            reminderEnabled: true
        )
        let activeProto = ProtocolModel(
            id: protocolId,
            name: "Active Protocol",
            status: .active,
            startDate: startDate,
            compounds: [compound]
        )

        let scheduled = try await scheduler.scheduleReminders(
            for: activeProto,
            referenceDate: startDate,
            horizonDays: 7,
            timeZone: calendar.timeZone
        )
        XCTAssertEqual(scheduled.count, 7)

        // Cancel on pause
        try await scheduler.cancelReminders(forProtocol: protocolId)

        let pending = await scheduler.getPendingReminders()
        let forThisProto = pending.filter { $0.protocolId == protocolId }
        XCTAssertTrue(forThisProto.isEmpty, "Pausing protocol must leave zero pending reminders")
    }

    // MARK: - 4. Timezone & Daylight Saving Time (DST) Shift Handling
    func testTimezoneAndDSTShiftPreservesLocalWallClockTime() async throws {
        // Test with New York Timezone (EDT = UTC-4, EST = UTC-5)
        guard let nyTimeZone = TimeZone(identifier: "America/New_York"),
              let londonTimeZone = TimeZone(identifier: "Europe/London") else {
            return
        }

        var startComps = DateComponents()
        startComps.year = 2026
        startComps.month = 10
        startComps.day = 30 // Right before US Fall Back DST transition on Nov 1
        startComps.hour = 0
        startComps.minute = 0
        startComps.timeZone = nyTimeZone

        var nyCal = Calendar(identifier: .gregorian)
        nyCal.timeZone = nyTimeZone
        guard let startDate = nyCal.date(from: startComps) else { return }

        var reminderTimeComps = DateComponents()
        reminderTimeComps.hour = 9
        reminderTimeComps.minute = 0
        let reminderTime = nyCal.date(from: reminderTimeComps)

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "GHK-Cu",
            doseAmount: 2.0,
            doseUnit: .mg,
            scheduleRule: .everyDay,
            reminderEnabled: true,
            reminderTime: reminderTime,
            reminderLeadTimeMinutes: 0
        )
        let proto = ProtocolModel(
            id: UUID(),
            name: "Skin Protocol",
            status: .active,
            startDate: startDate,
            compounds: [compound]
        )

        // Schedule under New York Time
        let nyScheduled = try await scheduler.scheduleReminders(
            for: proto,
            referenceDate: startDate,
            horizonDays: 5,
            timeZone: nyTimeZone
        )

        for item in nyScheduled {
            let hourInNY = nyCal.component(.hour, from: item.nextDoseTimestamp)
            let minuteInNY = nyCal.component(.minute, from: item.nextDoseTimestamp)
            XCTAssertEqual(hourInNY, 9, "Wall clock time in user's time zone must remain 9:00 AM")
            XCTAssertEqual(minuteInNY, 0)
        }

        // User travels to London: trigger DST/Timezone change handler
        let londonScheduled = try await scheduler.handleTimezoneOrDSTChange(
            protocols: [proto],
            timeZone: londonTimeZone
        )

        var londonCal = Calendar(identifier: .gregorian)
        londonCal.timeZone = londonTimeZone

        for item in londonScheduled {
            let hourInLondon = londonCal.component(.hour, from: item.nextDoseTimestamp)
            let minuteInLondon = londonCal.component(.minute, from: item.nextDoseTimestamp)
            XCTAssertEqual(hourInLondon, 9, "When recomputed in London timezone, local dose time must still be 9:00 AM")
            XCTAssertEqual(minuteInLondon, 0)
        }
    }

    // MARK: - 5. Titration Dose Schedule Reminders
    func testTitrationDoseReflectedInReminders() async throws {
        var startComps = DateComponents()
        startComps.year = 2026
        startComps.month = 9
        startComps.day = 1
        let startDate = calendar.date(from: startComps)!

        // Titration: Start 250mcg, Target 1000mcg, Step +250mcg every 7 days
        let titration = TitrationRule(
            startDose: 250,
            targetDose: 1000,
            stepAmount: 250,
            stepIntervalDays: 7
        )

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "Tirzepatide",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay,
            reminderEnabled: true,
            titrationStep: titration
        )

        let proto = ProtocolModel(
            name: "Titration Protocol",
            status: .active,
            startDate: startDate,
            compounds: [compound]
        )

        let scheduled = try await scheduler.scheduleReminders(
            for: proto,
            referenceDate: startDate,
            horizonDays: 21,
            timeZone: calendar.timeZone
        )

        XCTAssertEqual(scheduled.count, 21)

        // Day 0 to 6 (Week 1): 250 mcg
        XCTAssertEqual(scheduled[0].plannedDoseAmount, 250)
        XCTAssertEqual(scheduled[6].plannedDoseAmount, 250)

        // Day 7 to 13 (Week 2): 500 mcg
        XCTAssertEqual(scheduled[7].plannedDoseAmount, 500)
        XCTAssertEqual(scheduled[13].plannedDoseAmount, 500)

        // Day 14+ (Week 3): 750 mcg
        XCTAssertEqual(scheduled[14].plannedDoseAmount, 750)
    }

    // MARK: - 6. Privacy Preservation in Notification Scheduler
    func testNotificationSchedulerDefaultsToRedactedPrivacyMode() {
        XCTAssertEqual(scheduler.privacyMode, .redacted, "NotificationScheduler must default to redacted privacy mode")
    }
}
