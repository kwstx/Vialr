import XCTest
import Domain
@testable import CalculationEngine

final class ProtocolEngineComprehensiveTests: XCTestCase {

    private var calendar: Calendar!
    private var engine: ProtocolSchedulingEngine!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        calendar = cal
        engine = ProtocolSchedulingEngine(calendar: cal)
    }

    // MARK: - 1. Recurring Schedules

    func testDailyScheduleOccurrences() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 0, minute: 0, second: 0))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 23, minute: 59, second: 59))!

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay
        )
        let proto = ProtocolModel(name: "BPC Daily", status: .active, startDate: start, compounds: [compound])

        let occurrences = engine.generateOccurrences(for: proto, in: start...end)
        XCTAssertEqual(occurrences.count, 7)
        for (index, occ) in occurrences.enumerated() {
            let expectedDay = calendar.date(byAdding: .day, value: index, to: start)!
            XCTAssertTrue(calendar.isDate(occ.scheduledTimestamp, inSameDayAs: expectedDay))
        }
    }

    func testEveryOtherDayScheduleOccurrences() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 0, minute: 0, second: 0))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 23, minute: 59, second: 59))!

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "TB-500",
            doseAmount: 2.5,
            doseUnit: .mg,
            scheduleRule: .everyOtherDay
        )
        let proto = ProtocolModel(name: "TB EOD", status: .active, startDate: start, compounds: [compound])

        let occurrences = engine.generateOccurrences(for: proto, in: start...end)
        // Days 1, 3, 5, 7, 9 = 5 occurrences
        XCTAssertEqual(occurrences.count, 5)
    }

    func testDaysOfWeekScheduleMWF() {
        // Monday Aug 31, 2026 (weekday 2 in Gregorian: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat)
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 0, minute: 0, second: 0))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 23, minute: 59, second: 59))! // 14 days

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "Ipamorelin",
            doseAmount: 300,
            doseUnit: .mcg,
            scheduleRule: .daysOfWeek([2, 4, 6]) // Mon, Wed, Fri
        )
        let proto = ProtocolModel(name: "MWF Ipamorelin", status: .active, startDate: start, compounds: [compound])

        let occurrences = engine.generateOccurrences(for: proto, in: start...end)
        XCTAssertEqual(occurrences.count, 6)
        for occ in occurrences {
            let weekday = calendar.component(.weekday, from: occ.scheduledTimestamp)
            XCTAssertTrue([2, 4, 6].contains(weekday))
        }
    }

    func testCycleSchedule5On2Off() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 0, minute: 0, second: 0))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 23, minute: 59, second: 59))! // 14 days

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "CJC-1295",
            doseAmount: 100,
            doseUnit: .mcg,
            scheduleRule: .cycle(daysOn: 5, daysOff: 2)
        )
        let proto = ProtocolModel(name: "CJC Cycle", status: .active, startDate: start, compounds: [compound])

        let occurrences = engine.generateOccurrences(for: proto, in: start...end)
        // 5 on, 2 off, 5 on, 2 off = 10 occurrences
        XCTAssertEqual(occurrences.count, 10)
    }

    func testMultiDosePerDaySpacing() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 0, minute: 0, second: 0))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 23, minute: 59, second: 59))!

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay,
            timesPerDay: 2 // 2x daily
        )
        let proto = ProtocolModel(name: "BPC 2x Daily", status: .active, startDate: start, compounds: [compound])

        let occurrences = engine.generateOccurrences(for: proto, in: start...end)
        XCTAssertEqual(occurrences.count, 2)
        let hours = occurrences.map { calendar.component(.hour, from: $0.scheduledTimestamp) }
        XCTAssertEqual(hours[0], 8)  // Morning 08:00
        XCTAssertEqual(hours[1], 20) // Evening (8 + 12 = 20:00)
    }

    // MARK: - 2. Timezone Changes & Daylight Saving Transitions

    func testDaylightSavingTimeSpringForwardPreservation() {
        // In US Eastern, Spring forward occurs in March (clocks jump from 02:00 to 03:00)
        guard let nyTZ = TimeZone(identifier: "America/New_York") else { return }
        var nyCal = Calendar(identifier: .gregorian)
        nyCal.timeZone = nyTZ
        let nyEngine = ProtocolSchedulingEngine(calendar: nyCal)

        // March 6 to March 10, 2026 (DST shift is March 8, 2026)
        let start = nyCal.date(from: DateComponents(timeZone: nyTZ, year: 2026, month: 3, day: 6, hour: 0, minute: 0, second: 0))!
        let end = nyCal.date(from: DateComponents(timeZone: nyTZ, year: 2026, month: 3, day: 10, hour: 23, minute: 59, second: 59))!

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "Semaglutide",
            doseAmount: 500,
            doseUnit: .mcg,
            scheduleRule: .everyDay,
            preferredTimeOfDay: .morning
        )
        let proto = ProtocolModel(name: "DST Test", status: .active, startDate: start, compounds: [compound])

        let occurrences = nyEngine.generateOccurrences(for: proto, in: start...end)
        XCTAssertEqual(occurrences.count, 5)

        // Every occurrence must remain strictly at 08:00 AM local New York time regardless of UTC offset change (UTC-5 vs UTC-4)
        for occ in occurrences {
            let hour = nyCal.component(.hour, from: occ.scheduledTimestamp)
            let minute = nyCal.component(.minute, from: occ.scheduledTimestamp)
            XCTAssertEqual(hour, 8, "Occurrence must stay at 8:00 AM local time across DST")
            XCTAssertEqual(minute, 0)
        }
    }

    func testCrossTimezoneIndependence() {
        let tokyoTZ = TimeZone(identifier: "Asia/Tokyo")! // UTC+9
        let londonTZ = TimeZone(identifier: "Europe/London")! // UTC+0/1
        let laTZ = TimeZone(identifier: "America/Los_Angeles")! // UTC-8/7

        for tz in [tokyoTZ, londonTZ, laTZ] {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz
            let tzEngine = ProtocolSchedulingEngine(calendar: cal)

            let start = cal.date(from: DateComponents(timeZone: tz, year: 2026, month: 9, day: 1, hour: 0, minute: 0, second: 0))!
            let end = cal.date(from: DateComponents(timeZone: tz, year: 2026, month: 9, day: 3, hour: 23, minute: 59, second: 59))!

            let compound = ProtocolCompound(
                compoundId: UUID(),
                compoundName: "GHK-Cu",
                doseAmount: 2.0,
                doseUnit: .mg,
                scheduleRule: .everyDay,
                preferredTimeOfDay: .evening // 21:00
            )
            let proto = ProtocolModel(name: "GHK Local", status: .active, startDate: start, compounds: [compound])

            let occurrences = tzEngine.generateOccurrences(for: proto, in: start...end)
            XCTAssertEqual(occurrences.count, 3)
            for occ in occurrences {
                let hour = cal.component(.hour, from: occ.scheduledTimestamp)
                XCTAssertEqual(hour, 21, "Must be 21:00 in \(tz.identifier)")
            }
        }
    }

    // MARK: - 3. Missed Events & Adherence Analytics

    func testAdherenceWithLoggedAndMissedDoses() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 0, minute: 0, second: 0))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 23, minute: 59, second: 59))! // 10 days

        let compoundId = UUID()
        let protoId = UUID()
        let compound = ProtocolCompound(
            compoundId: compoundId,
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay
        )
        let proto = ProtocolModel(id: protoId, name: "BPC 10-day", status: .active, startDate: start, compounds: [compound])

        // User logged doses on Days 1, 2, 3, 4, 5, 6, 7 (7 doses logged, 3 missed/pending)
        var logs: [DoseEvent] = []
        for day in 0..<7 {
            let logDate = calendar.date(byAdding: .day, value: day, to: start)!
            logs.append(DoseEvent(
                protocolId: protoId,
                compoundId: compoundId,
                compoundName: "BPC-157",
                scheduledTimestamp: logDate,
                actualTimestamp: logDate,
                plannedDoseAmount: 250,
                actualDoseAmount: 250,
                status: .taken
            ))
        }

        let adherence = engine.calculateProjectedAdherence(protocols: [proto], loggedEvents: logs, dateRange: start...end)
        XCTAssertEqual(adherence.totalExpectedDoses, 10)
        XCTAssertEqual(adherence.totalTakenDoses, 7)
        XCTAssertEqual(adherence.adherencePercentage, 70.0, accuracy: 0.01)
    }

    // MARK: - 4. Protocol Modifications & Titrations

    func testTitrationEscalationSchedule() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 0, minute: 0, second: 0))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 23, minute: 59, second: 59))! // 4 weeks

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "Tirzepatide",
            doseAmount: 2.5,
            doseUnit: .mg,
            scheduleRule: .everyNDays(7), // Weekly
            titrationStep: TitrationRule(
                startDose: 2.5,
                targetDose: 10.0,
                stepAmount: 2.5,
                stepIntervalDays: 7
            )
        )
        let proto = ProtocolModel(name: "Tirzepatide Ramp", status: .active, startDate: start, compounds: [compound])

        let occurrences = engine.generateOccurrences(for: proto, in: start...end)
        XCTAssertEqual(occurrences.count, 4)
        XCTAssertEqual(occurrences[0].plannedDoseAmount, 2.5)  // Week 1: 2.5 mg
        XCTAssertEqual(occurrences[1].plannedDoseAmount, 5.0)  // Week 2: 5.0 mg
        XCTAssertEqual(occurrences[2].plannedDoseAmount, 7.5)  // Week 3: 7.5 mg
        XCTAssertEqual(occurrences[3].plannedDoseAmount, 10.0) // Week 4: 10.0 mg (Target ceiling)
    }

    func testMultiCompoundProtocolWithStaggeredDates() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 0, minute: 0, second: 0))!
        let queryEnd = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 23, minute: 59, second: 59))!

        let compound1 = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay,
            startDate: start,
            endDate: calendar.date(byAdding: .day, value: 13, to: start) // 14 days (Sept 1 - Sept 14)
        )

        let compound2 = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "TB-500",
            doseAmount: 2.0,
            doseUnit: .mg,
            scheduleRule: .everyOtherDay,
            startDate: calendar.date(byAdding: .day, value: 7, to: start), // Staggered start on Sept 8
            endDate: calendar.date(byAdding: .day, value: 21, to: start)  // 14 days (Sept 8 - Sept 22)
        )

        let proto = ProtocolModel(
            name: "Wolverine Stack",
            status: .active,
            startDate: start,
            compounds: [compound1, compound2]
        )

        let occurrences = engine.generateOccurrences(for: proto, in: start...queryEnd)
        let bpcOccurrences = occurrences.filter { $0.compoundName == "BPC-157" }
        let tbOccurrences = occurrences.filter { $0.compoundName == "TB-500" }

        XCTAssertEqual(bpcOccurrences.count, 14)
        XCTAssertEqual(tbOccurrences.count, 8) // EOD over 14-day window (Days 0, 2, 4, 6, 8, 10, 12, 14)
    }
}
