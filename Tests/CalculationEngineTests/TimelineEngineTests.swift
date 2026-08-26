import XCTest
import Domain
@testable import CalculationEngine

final class TimelineEngineTests: XCTestCase {

    var engine: TimelineEngine!
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        engine = TimelineEngine()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    override func tearDown() {
        engine = nil
        calendar = nil
        super.tearDown()
    }

    // MARK: - 1. Dose Event Transformation Tests

    func testDoseEventTransformation() {
        let compoundId = UUID()
        let dose = DoseEvent(
            compoundId: compoundId,
            compoundName: "Semaglutide",
            scheduledTimestamp: Date(timeIntervalSince1970: 1700000000),
            actualTimestamp: Date(timeIntervalSince1970: 1700000000),
            actualDoseAmount: 0.5,
            doseUnit: .mg,
            status: .taken,
            injectionSiteId: "abdomen_ur",
            injectionSiteName: "Abdomen - Upper Right",
            actualRoute: .subcutaneous,
            notes: "Routine weekly dose"
        )

        let timelineEvent = TimelineEvent(from: dose)

        XCTAssertEqual(timelineEvent.category, .dose)
        XCTAssertEqual(timelineEvent.title, "Semaglutide Dose")
        XCTAssertTrue(timelineEvent.subtitle.contains("0.5 mg"))
        XCTAssertTrue(timelineEvent.subtitle.contains("Subcutaneous"))
        XCTAssertTrue(timelineEvent.subtitle.contains("Abdomen - Upper Right"))
        XCTAssertEqual(timelineEvent.detailText, "Routine weekly dose")
        XCTAssertEqual(timelineEvent.badgeText, "Taken")
        XCTAssertEqual(timelineEvent.associatedEntityType, .doseEvent)
        XCTAssertEqual(timelineEvent.associatedEntityId, dose.id)
        XCTAssertFalse(timelineEvent.isHighlighted)
        XCTAssertEqual(timelineEvent.metadata["compoundName"], "Semaglutide")
        XCTAssertEqual(timelineEvent.metadata["isTaken"], "true")
    }

    func testMissedDoseIsHighlighted() {
        let dose = DoseEvent(
            compoundId: UUID(),
            compoundName: "BPC-157",
            scheduledTimestamp: Date(timeIntervalSince1970: 1700000000),
            actualDoseAmount: 250,
            doseUnit: .mcg,
            status: .missed,
            skippedReason: "Traveled without cooler"
        )

        let timelineEvent = TimelineEvent(from: dose)

        XCTAssertEqual(timelineEvent.category, .dose)
        XCTAssertEqual(timelineEvent.badgeText, "Missed")
        XCTAssertTrue(timelineEvent.isHighlighted)
        XCTAssertEqual(timelineEvent.detailText, "Traveled without cooler")
    }

    // MARK: - 2. Lab Panel Transformation Tests

    func testLabPanelTransformation() {
        let panelId = UUID()
        let result1 = LabResult(biomarkerName: "Total Testosterone", value: 850, unit: "ng/dL", flag: .inRange)
        let result2 = LabResult(biomarkerName: "Estradiol (E2)", value: 52, unit: "pg/mL", flag: .high)
        let panel = LabPanel(
            id: panelId,
            panelName: "Comprehensive Hormone Panel",
            labName: "Quest Diagnostics",
            collectionDate: Date(timeIntervalSince1970: 1700000000),
            status: .completed,
            results: [result1, result2],
            notes: "Morning fasting draw"
        )

        let timelineEvent = TimelineEvent(from: panel)

        XCTAssertEqual(timelineEvent.category, .labPanel)
        XCTAssertEqual(timelineEvent.title, "Comprehensive Hormone Panel")
        XCTAssertTrue(timelineEvent.subtitle.contains("Quest Diagnostics"))
        XCTAssertTrue(timelineEvent.subtitle.contains("2 biomarkers"))
        XCTAssertTrue(timelineEvent.subtitle.contains("1 flagged out of range"))
        XCTAssertEqual(timelineEvent.badgeText, "Completed & Final")
        XCTAssertTrue(timelineEvent.isHighlighted) // Due to abnormal result
        XCTAssertEqual(timelineEvent.associatedEntityId, panelId)
        XCTAssertEqual(timelineEvent.associatedEntityType, .labPanel)
        XCTAssertEqual(timelineEvent.metadata["abnormalCount"], "1")
    }

    // MARK: - 3. Measurement Transformation Tests

    func testMeasurementTransformation() {
        let measurement = Measurement.bloodPressure(
            systolic: 128,
            diastolic: 84,
            dateRecorded: Date(timeIntervalSince1970: 1700000000),
            notes: "Post-workout check"
        )

        let timelineEvent = TimelineEvent(from: measurement)

        XCTAssertEqual(timelineEvent.category, .measurement)
        XCTAssertEqual(timelineEvent.title, "Blood Pressure")
        XCTAssertEqual(timelineEvent.subtitle, "128/84 mmHg")
        XCTAssertEqual(timelineEvent.detailText, "Post-workout check")
        XCTAssertEqual(timelineEvent.badgeText, "High")
        XCTAssertTrue(timelineEvent.isHighlighted)
        XCTAssertEqual(timelineEvent.associatedEntityType, .measurement)
    }

    // MARK: - 4. Protocol Revision & Change Transformation Tests

    func testProtocolRevisionTransformation() {
        let protocolId = UUID()
        let revCompound = ProtocolCompound(compoundName: "Tirzepatide", dosageAmount: 5.0, unit: .mg)
        let revision = ProtocolRevision(
            protocolId: protocolId,
            revisionNumber: 2,
            name: "GLP-1 Weight Management",
            compounds: [revCompound],
            reasonForChange: "Titration step up from 2.5mg to 5.0mg",
            effectiveDate: Date(timeIntervalSince1970: 1700000000)
        )

        let timelineEvent = TimelineEvent(from: revision)

        XCTAssertEqual(timelineEvent.category, .protocolChange)
        XCTAssertTrue(timelineEvent.title.contains("Protocol Change (v2)"))
        XCTAssertEqual(timelineEvent.subtitle, "Titration step up from 2.5mg to 5.0mg")
        XCTAssertTrue(timelineEvent.detailText?.contains("Tirzepatide 5mg") ?? false)
        XCTAssertEqual(timelineEvent.badgeText, "Revision v2")
        XCTAssertTrue(timelineEvent.isHighlighted)
        XCTAssertEqual(timelineEvent.associatedEntityType, .protocolRevision)
    }

    // MARK: - 5. Inventory Event Transformation Tests

    func testInventoryEventTransformation() {
        let vialId = UUID()
        let invEvent = InventoryEvent.reconciliation(
            vialId: vialId,
            compoundId: UUID(),
            compoundName: "Ipamorelin",
            volumeVarianceMl: -0.05,
            massVarianceMg: -0.25,
            newVolumeRemainingMl: 1.95,
            newMassRemainingMg: 9.75,
            concentrationMgMl: 5.0,
            reason: .deadSpaceLoss,
            userNotes: "Syringe hub dead space reconciliation",
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        let timelineEvent = TimelineEvent(from: invEvent)

        XCTAssertEqual(timelineEvent.category, .inventory)
        XCTAssertTrue(timelineEvent.title.contains("Inventory Reconciliation: Ipamorelin"))
        XCTAssertTrue(timelineEvent.subtitle.contains("Physical reconciliation: Syringe Dead Space Cumulative Loss"))
        XCTAssertTrue(timelineEvent.isHighlighted)
        XCTAssertEqual(timelineEvent.associatedEntityType, .inventoryEvent)
        XCTAssertEqual(timelineEvent.associatedEntityId, invEvent.id)
    }

    // MARK: - 6. Day Grouping Tests

    func testGroupEventsByDay() {
        // Base timestamp (2026-08-26 10:00:00 UTC)
        let day1Time1 = Date(timeIntervalSince1970: 1787738400) // Aug 26 10:00
        let day1Time2 = Date(timeIntervalSince1970: 1787752800) // Aug 26 14:00
        let day2Time1 = Date(timeIntervalSince1970: 1787652000) // Aug 25 10:00
        let day3Time1 = Date(timeIntervalSince1970: 1787565600) // Aug 24 10:00

        let ev1 = TimelineEvent(timestamp: day1Time1, category: .dose, title: "Dose 1", subtitle: "Sub 1")
        let ev2 = TimelineEvent(timestamp: day1Time2, category: .measurement, title: "Measurement 1", subtitle: "Sub 2")
        let ev3 = TimelineEvent(timestamp: day2Time1, category: .labPanel, title: "Lab 1", subtitle: "Sub 3")
        let ev4 = TimelineEvent(timestamp: day3Time1, category: .inventory, title: "Inv 1", subtitle: "Sub 4")

        let dayGroups = engine.groupEventsByDay([ev1, ev2, ev3, ev4], calendar: calendar)

        XCTAssertEqual(dayGroups.count, 3)

        // Verify day 1 group has 2 events
        let firstGroup = dayGroups[0]
        XCTAssertEqual(firstGroup.events.count, 2)
        XCTAssertEqual(firstGroup.countsByCategory[.dose], 1)
        XCTAssertEqual(firstGroup.countsByCategory[.measurement], 1)
        XCTAssertTrue(firstGroup.summaryText.contains("1 Dose"))
        XCTAssertTrue(firstGroup.summaryText.contains("1 Measurement"))

        // Verify reverse-chronological order of groups
        XCTAssertTrue(dayGroups[0].date > dayGroups[1].date)
        XCTAssertTrue(dayGroups[1].date > dayGroups[2].date)
    }

    // MARK: - 7. Filtering Tests

    func testFilterByCategory() {
        let ev1 = TimelineEvent(category: .dose, title: "Dose A", subtitle: "")
        let ev2 = TimelineEvent(category: .labPanel, title: "Lab B", subtitle: "")
        let ev3 = TimelineEvent(category: .measurement, title: "Metric C", subtitle: "")

        let filter = TimelineFilter(categories: [.dose, .labPanel])
        let filtered = engine.filterEvents([ev1, ev2, ev3], using: filter)

        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains(where: { $0.title == "Dose A" }))
        XCTAssertTrue(filtered.contains(where: { $0.title == "Lab B" }))
        XCTAssertFalse(filtered.contains(where: { $0.title == "Metric C" }))
    }

    func testFilterBySearchKeyword() {
        let ev1 = TimelineEvent(category: .dose, title: "Tirzepatide 5mg Dose", subtitle: "Subcutaneous")
        let ev2 = TimelineEvent(category: .labPanel, title: "Lipid Panel", subtitle: "Quest Diagnostics")
        let ev3 = TimelineEvent(category: .inventory, title: "Restock: Bacteriostatic Water", subtitle: "Added 30mL", metadata: ["notes": "medical supplies"])

        let filterTirz = TimelineFilter(searchQuery: "tirzepatide")
        let match1 = engine.filterEvents([ev1, ev2, ev3], using: filterTirz)
        XCTAssertEqual(match1.count, 1)
        XCTAssertEqual(match1.first?.title, "Tirzepatide 5mg Dose")

        let filterQuest = TimelineFilter(searchQuery: "quest")
        let match2 = engine.filterEvents([ev1, ev2, ev3], using: filterQuest)
        XCTAssertEqual(match2.count, 1)
        XCTAssertEqual(match2.first?.title, "Lipid Panel")

        let filterMeta = TimelineFilter(searchQuery: "medical supplies")
        let match3 = engine.filterEvents([ev1, ev2, ev3], using: filterMeta)
        XCTAssertEqual(match3.count, 1)
        XCTAssertEqual(match3.first?.title, "Restock: Bacteriostatic Water")
    }

    func testFilterByDateInterval() {
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 2000)
        let t3 = Date(timeIntervalSince1970: 3000)

        let ev1 = TimelineEvent(timestamp: t1, category: .dose, title: "Event 1", subtitle: "")
        let ev2 = TimelineEvent(timestamp: t2, category: .dose, title: "Event 2", subtitle: "")
        let ev3 = TimelineEvent(timestamp: t3, category: .dose, title: "Event 3", subtitle: "")

        let filter = TimelineFilter(startDate: Date(timeIntervalSince1970: 1500), endDate: Date(timeIntervalSince1970: 2500))
        let filtered = engine.filterEvents([ev1, ev2, ev3], using: filter)

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "Event 2")
    }

    // MARK: - 8. Statistics Calculation Tests

    func testStatisticsCalculation() {
        let d1 = TimelineEvent(category: .dose, title: "Dose 1", subtitle: "", badgeText: "Taken", metadata: ["isTaken": "true"])
        let d2 = TimelineEvent(category: .dose, title: "Dose 2", subtitle: "", badgeText: "Taken", metadata: ["isTaken": "true"])
        let d3 = TimelineEvent(category: .dose, title: "Dose 3", subtitle: "", badgeText: "Missed", metadata: ["isTaken": "false"])
        let l1 = TimelineEvent(category: .labPanel, title: "Lab 1", subtitle: "", isHighlighted: false)
        let l2 = TimelineEvent(category: .labPanel, title: "Lab 2", subtitle: "", isHighlighted: true)
        let m1 = TimelineEvent(category: .measurement, title: "Metric 1", subtitle: "")
        let p1 = TimelineEvent(category: .protocolChange, title: "Protocol 1", subtitle: "")
        let i1 = TimelineEvent(category: .inventory, title: "Inv 1", subtitle: "")

        let stats = engine.calculateStatistics(from: [d1, d2, d3, l1, l2, m1, p1, i1])

        XCTAssertEqual(stats.totalEventsCount, 8)
        XCTAssertEqual(stats.totalDosesCount, 3)
        XCTAssertEqual(stats.takenDosesCount, 2)
        XCTAssertEqual(stats.missedDosesCount, 1)
        XCTAssertEqual(stats.totalLabPanelsCount, 2)
        XCTAssertEqual(stats.abnormalLabCount, 1)
        XCTAssertEqual(stats.totalMeasurementsCount, 1)
        XCTAssertEqual(stats.totalProtocolChangesCount, 1)
        XCTAssertEqual(stats.totalInventoryEventsCount, 1)
        XCTAssertEqual(Int(stats.adherenceScore ?? 0), 66)
    }

    // MARK: - 9. Process Timeline End-to-End

    func testProcessTimelineEndToEnd() {
        let dayTime1 = Date(timeIntervalSince1970: 1787738400)
        let dayTime2 = Date(timeIntervalSince1970: 1787652000)

        let ev1 = TimelineEvent(timestamp: dayTime1, category: .dose, title: "Dose Alpha", subtitle: "Sub", badgeText: "Taken", metadata: ["isTaken": "true"])
        let ev2 = TimelineEvent(timestamp: dayTime2, category: .labPanel, title: "Lab Beta", subtitle: "Sub", isHighlighted: false)

        let result = engine.processTimeline(events: [ev1, ev2], filter: nil, calendar: calendar)

        XCTAssertEqual(result.dayGroups.count, 2)
        XCTAssertEqual(result.allEvents.count, 2)
        XCTAssertEqual(result.statistics.totalEventsCount, 2)
        XCTAssertEqual(result.statistics.takenDosesCount, 1)
        XCTAssertEqual(result.statistics.totalLabPanelsCount, 1)
        XCTAssertNotNil(result.dateInterval)
    }
}
