import XCTest
import Domain
@testable import CalculationEngine

final class ProtocolSchedulingEngineTests: XCTestCase {

    var engine: ProtocolSchedulingEngine!
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar.current
        engine = ProtocolSchedulingEngine(calendar: calendar)
    }

    // MARK: - 1. Daily Recurrence
    func testDailyRecurrenceOccurrences() {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 6, to: start)! // 7 days (day 0 to day 6)

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay
        )

        let proto = ProtocolModel(
            name: "BPC Daily",
            status: .active,
            startDate: start,
            compounds: [compound]
        )

        let occurrences = engine.generateOccurrences(for: proto, in: start...end)

        XCTAssertEqual(occurrences.count, 7, "Daily schedule over 7 days must produce exactly 7 occurrences")
        XCTAssertEqual(occurrences.first?.plannedDoseAmount, 250)
        XCTAssertEqual(occurrences.first?.compoundName, "BPC-157")
    }

    // MARK: - 2. Every Other Day (EOD) Recurrence
    func testEveryOtherDayOccurrences() {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 9, to: start)! // 10 days (day 0 to day 9)

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "TB-500",
            doseAmount: 2.0,
            doseUnit: .mg,
            scheduleRule: .everyOtherDay
        )

        let proto = ProtocolModel(
            name: "TB-500 EOD",
            status: .active,
            startDate: start,
            compounds: [compound]
        )

        let occurrences = engine.generateOccurrences(for: proto, in: start...end)

        // Days 0, 2, 4, 6, 8 = 5 occurrences
        XCTAssertEqual(occurrences.count, 5, "EOD schedule over 10 days must produce exactly 5 occurrences")
    }

    // MARK: - 3. Days of Week Recurrence (MWF)
    func testDaysOfWeekRecurrence() {
        // Find next Monday
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 31 // Monday, Aug 31, 2026 (weekday 2)
        guard let monday = calendar.date(from: comps) else {
            XCTFail("Failed to create start Monday")
            return
        }
        let endTwoWeeks = calendar.date(byAdding: .day, value: 13, to: monday)! // 14 days

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "Ipamorelin",
            doseAmount: 300,
            doseUnit: .mcg,
            scheduleRule: .daysOfWeek([2, 4, 6]) // Mon, Wed, Fri
        )

        let proto = ProtocolModel(
            name: "MWF Protocol",
            status: .active,
            startDate: monday,
            compounds: [compound]
        )

        let occurrences = engine.generateOccurrences(for: proto, in: monday...endTwoWeeks)

        // Mon, Wed, Fri across 2 weeks = 6 occurrences
        XCTAssertEqual(occurrences.count, 6, "MWF schedule across 14 days must produce exactly 6 occurrences")
        for occ in occurrences {
            let weekday = calendar.component(.weekday, from: occ.scheduledTimestamp)
            XCTAssertTrue([2, 4, 6].contains(weekday), "Occurrence must only fall on Mon (2), Wed (4), or Fri (6)")
        }
    }

    // MARK: - 4. Cycling Recurrence (5 on / 2 off)
    func testCyclingRecurrence5On2Off() {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 13, to: start)! // 14 days

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "CJC-1295",
            doseAmount: 200,
            doseUnit: .mcg,
            scheduleRule: .cycle(daysOn: 5, daysOff: 2)
        )

        let proto = ProtocolModel(
            name: "CJC Cycle",
            status: .active,
            startDate: start,
            compounds: [compound]
        )

        let occurrences = engine.generateOccurrences(for: proto, in: start...end)

        // 5 on, 2 off, 5 on, 2 off = 10 occurrences
        XCTAssertEqual(occurrences.count, 10, "5 on / 2 off cycle across 14 days must produce 10 occurrences")
    }

    // MARK: - 5. Every N Days Recurrence
    func testEveryNDaysRecurrence() {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 9, to: start)! // 10 days

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "Tirzepatide",
            doseAmount: 5.0,
            doseUnit: .mg,
            scheduleRule: .everyNDays(3)
        )

        let proto = ProtocolModel(
            name: "Tirzepatide Every 3 Days",
            status: .active,
            startDate: start,
            compounds: [compound]
        )

        let occurrences = engine.generateOccurrences(for: proto, in: start...end)

        // Days 0, 3, 6, 9 = 4 occurrences
        XCTAssertEqual(occurrences.count, 4, "Every 3 days over 10 days must produce 4 occurrences")
    }

    // MARK: - 6. Titration Dose Evolution
    func testTitrationEffectiveDose() {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 20, to: start)! // 21 days (3 weeks)

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "Semaglutide",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyNDays(7),
            titrationStep: TitrationRule(
                startDose: 250,
                targetDose: 1000,
                stepAmount: 250,
                stepIntervalDays: 7
            )
        )

        let proto = ProtocolModel(
            name: "Semaglutide Titration",
            status: .active,
            startDate: start,
            compounds: [compound]
        )

        let occurrences = engine.generateOccurrences(for: proto, in: start...end)

        XCTAssertEqual(occurrences.count, 3)
        XCTAssertEqual(occurrences[0].plannedDoseAmount, 250, "Week 1: 250 mcg")
        XCTAssertEqual(occurrences[1].plannedDoseAmount, 500, "Week 2: 500 mcg")
        XCTAssertEqual(occurrences[2].plannedDoseAmount, 750, "Week 3: 750 mcg")
    }

    // MARK: - 7. End Date Boundary
    func testProtocolEndDateBoundary() {
        let start = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: 7, to: start)! // 8 total days (0..7)
        let queryEnd = calendar.date(byAdding: .day, value: 30, to: start)!

        let compound = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay
        )

        let proto = ProtocolModel(
            name: "BPC Fixed Duration",
            status: .active,
            startDate: start,
            endDate: endDate,
            compounds: [compound]
        )

        let occurrences = engine.generateOccurrences(for: proto, in: start...queryEnd)

        XCTAssertEqual(occurrences.count, 8, "Occurrences must stop after protocol end date")
        XCTAssertTrue(occurrences.allSatisfy { $0.scheduledTimestamp <= endDate.addingTimeInterval(86400) })
    }

    // MARK: - 8. Reconciliation with Ground-Truth Logged Events
    func testReconciliationWithLoggedEvents() {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 2, to: start)! // 3 days

        let compoundId = UUID()
        let protoId = UUID()

        let compound = ProtocolCompound(
            compoundId: compoundId,
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay
        )

        let proto = ProtocolModel(
            id: protoId,
            name: "BPC Daily",
            status: .active,
            startDate: start,
            compounds: [compound]
        )

        // Day 1 was taken
        let loggedDate = start.addingTimeInterval(3600 * 8)
        let loggedDose = DoseEvent(
            protocolId: protoId,
            compoundId: compoundId,
            compoundName: "BPC-157",
            scheduledTimestamp: loggedDate,
            actualTimestamp: loggedDate,
            plannedDoseAmount: 250,
            actualDoseAmount: 250,
            doseUnit: .mcg,
            status: .taken,
            injectionSiteName: "Abdomen Upper Left"
        )

        let occurrences = engine.generateOccurrences(for: proto, in: start...end, loggedEvents: [loggedDose])

        XCTAssertEqual(occurrences.count, 3)
        XCTAssertEqual(occurrences[0].status, .taken)
        XCTAssertEqual(occurrences[0].associatedDoseLogId, loggedDose.id)
        XCTAssertEqual(occurrences[0].injectionSiteName, "Abdomen Upper Left")
        XCTAssertEqual(occurrences[1].status, .scheduled)
    }

    // MARK: - 9. Vial Depletion Forecasting
    func testVialDepletionForecasting() {
        let start = calendar.startOfDay(for: Date())
        let compoundId = UUID()

        let compound = ProtocolCompound(
            compoundId: compoundId,
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay
        )

        let proto = ProtocolModel(
            name: "BPC Daily Protocol",
            status: .active,
            startDate: start,
            compounds: [compound]
        )

        // 5mg dry mass in 2.0 mL BAC water = 2.5 mg/mL (2500 mcg/mL)
        // Draw volume for 250 mcg = 0.1 mL
        // Current remaining = 1.0 mL -> 10 doses remaining
        let vial = Vial(
            compoundId: compoundId,
            compoundName: "BPC-157",
            totalDryMassMg: 5.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 1.0,
            isReconstituted: true,
            status: .reconstituted
        )

        let forecast = engine.calculateVialDepletion(
            vial: vial,
            protocolModel: proto,
            compound: compound,
            from: start
        )

        XCTAssertEqual(forecast.totalPlannedDosesRemaining, 10, "1.0 mL remaining at 0.1 mL/dose must equal 10 doses")
        XCTAssertNotNil(forecast.projectedDepletionDate)
        XCTAssertEqual(forecast.daysRemaining, 9, "Daily dosing will deplete 10 doses in 9 days from start")
    }

    // MARK: - 10. Adherence Percentage Projection
    func testAdherenceCalculation() {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 3, to: start)! // 4 days

        let compoundId = UUID()
        let protoId = UUID()

        let compound = ProtocolCompound(
            compoundId: compoundId,
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay
        )

        let proto = ProtocolModel(
            id: protoId,
            name: "BPC Daily",
            status: .active,
            startDate: start,
            compounds: [compound]
        )

        // 3 of 4 doses taken
        var logged: [DoseEvent] = []
        for i in 0..<3 {
            let d = calendar.date(byAdding: .day, value: i, to: start)!
            logged.append(DoseEvent(
                protocolId: protoId,
                compoundId: compoundId,
                compoundName: "BPC-157",
                scheduledTimestamp: d,
                actualTimestamp: d,
                plannedDoseAmount: 250,
                actualDoseAmount: 250,
                status: .taken
            ))
        }

        let report = engine.calculateProjectedAdherence(protocols: [proto], loggedEvents: logged, dateRange: start...end)

        XCTAssertEqual(report.totalExpectedDoses, 4)
        XCTAssertEqual(report.totalTakenDoses, 3)
        XCTAssertEqual(report.adherencePercentage, 75.0, accuracy: 0.01)
    }
}
