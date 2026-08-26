import XCTest
import Domain
import CalculationEngine
@testable import Analytics

final class ProtocolReplayEngineTests: XCTestCase {

    var engine: ProtocolReplayEngine!
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        engine = ProtocolReplayEngine()
        calendar = Calendar.current
    }

    // MARK: - 1. Empty / Minimal Protocol Sequence
    func testBuildReplaySequence_MinimalProtocol() {
        let protoId = UUID()
        let start = Date(timeIntervalSince1970: 1700000000)
        let proto = ProtocolModel(
            id: protoId,
            name: "Test Stack",
            status: .active,
            startDate: start,
            notes: "Test notes",
            compounds: [
                ProtocolCompound(compoundName: "BPC-157", doseAmount: 250, doseUnit: .mcg)
            ]
        )

        let sequence = engine.buildReplaySequence(for: proto, calendar: calendar)

        XCTAssertEqual(sequence.protocolId, protoId)
        XCTAssertEqual(sequence.protocolName, "Test Stack")
        XCTAssertFalse(sequence.events.isEmpty)
        // Should contain the start launch milestone
        XCTAssertEqual(sequence.events.first?.category, .milestone)
        XCTAssertEqual(sequence.events.first?.protocolDay, 1)
        XCTAssertEqual(sequence.totalDosesCount, 0)
        XCTAssertEqual(sequence.totalMeasurementsCount, 0)
        XCTAssertEqual(sequence.totalLabDrawsCount, 0)
    }

    // MARK: - 2. Sequential Chronological Alignment (Dose -> Measurement -> Lab -> Revision -> Measurement)
    func testBuildReplaySequence_SequentialChronologicalOrdering() {
        let protoId = UUID()
        let bpcId = UUID()
        let trzId = UUID()
        let start = Date(timeIntervalSince1970: 1700000000) // Day 1

        let proto = ProtocolModel(
            id: protoId,
            name: "Wolverine Replay Stack",
            status: .active,
            startDate: start,
            endDate: start.addingTimeInterval(86400 * 30),
            compounds: [
                ProtocolCompound(compoundId: bpcId, compoundName: "BPC-157", doseAmount: 250, doseUnit: .mcg),
                ProtocolCompound(compoundId: trzId, compoundName: "Tirzepatide", doseAmount: 2.5, doseUnit: .mg)
            ]
        )

        // Day 1: Baseline weight measurement
        let m1 = Measurement(
            name: "Body Weight",
            type: .weight,
            value: 190.0,
            unit: "lbs",
            dateRecorded: start,
            associatedProtocolId: protoId
        )

        // Day 2: First BPC-157 dose taken
        let d1 = DoseLog(
            protocolId: protoId,
            compoundId: bpcId,
            compoundName: "BPC-157",
            scheduledDate: start.addingTimeInterval(86400 * 1),
            loggedDate: start.addingTimeInterval(86400 * 1),
            doseAmount: 250,
            doseUnit: .mcg,
            status: .taken,
            injectionSiteName: "Abdomen Lower Left"
        )

        // Day 5: Weight measurement
        let m2 = Measurement(
            name: "Body Weight",
            type: .weight,
            value: 188.0,
            unit: "lbs",
            dateRecorded: start.addingTimeInterval(86400 * 4),
            associatedProtocolId: protoId
        )

        // Day 7: Lab Panel Diagnostic
        let lab = LabPanel(
            panelName: "Metabolic Panel",
            labName: "Quest Diagnostics",
            collectionDate: start.addingTimeInterval(86400 * 6),
            status: .completed,
            results: [
                LabResult(biomarkerName: "IGF-1", value: 245, unit: "ng/mL", flag: .inRange),
                LabResult(biomarkerName: "Fasting Glucose", value: 88, unit: "mg/dL", flag: .inRange)
            ],
            associatedProtocolId: protoId
        )

        // Day 14: Protocol Revision (Titration of Tirzepatide to 5.0mg)
        let rev = ProtocolRevision(
            protocolId: protoId,
            revisionNumber: 2,
            name: "Titration Step 1",
            compounds: [
                ProtocolCompound(compoundId: bpcId, compoundName: "BPC-157", doseAmount: 250, doseUnit: .mcg),
                ProtocolCompound(compoundId: trzId, compoundName: "Tirzepatide", doseAmount: 5.0, doseUnit: .mg)
            ],
            reasonForChange: "Escalated Tirzepatide dose for glycemic optimization",
            effectiveDate: start.addingTimeInterval(86400 * 13)
        )

        // Day 16: Another weight measurement
        let m3 = Measurement(
            name: "Body Weight",
            type: .weight,
            value: 185.5,
            unit: "lbs",
            dateRecorded: start.addingTimeInterval(86400 * 15),
            associatedProtocolId: protoId
        )

        let sequence = engine.buildReplaySequence(
            for: proto,
            doses: [d1],
            measurements: [m1, m2, m3],
            labPanels: [lab],
            protocolRevisions: [rev],
            calendar: calendar
        )

        XCTAssertEqual(sequence.totalDosesCount, 1)
        XCTAssertEqual(sequence.totalMeasurementsCount, 3)
        XCTAssertEqual(sequence.totalLabDrawsCount, 1)
        XCTAssertEqual(sequence.totalRevisionsCount, 1)

        // Verify timestamps are strictly monotonic non-decreasing
        for i in 0..<(sequence.events.count - 1) {
            let current = sequence.events[i]
            let next = sequence.events[i + 1]
            XCTAssertLessThanOrEqual(current.timestamp, next.timestamp, "Events should be strictly sorted chronologically")
        }

        // Verify categories sequence
        let categories = sequence.events.map(\.category)
        XCTAssertTrue(categories.contains(.milestone)) // Start launch
        XCTAssertTrue(categories.contains(.dose))
        XCTAssertTrue(categories.contains(.measurement))
        XCTAssertTrue(categories.contains(.labPanel))
        XCTAssertTrue(categories.contains(.protocolRevision))
    }

    // MARK: - 3. Cumulative State Progression
    func testBuildReplaySequence_CumulativeStateProgression() {
        let protoId = UUID()
        let bpcId = UUID()
        let start = Date(timeIntervalSince1970: 1700000000)

        let proto = ProtocolModel(
            id: protoId,
            name: "BPC Protocol",
            status: .active,
            startDate: start,
            compounds: [
                ProtocolCompound(compoundId: bpcId, compoundName: "BPC-157", doseAmount: 250, doseUnit: .mcg)
            ]
        )

        // 3 consecutive doses taken
        let d1 = DoseLog(protocolId: protoId, compoundId: bpcId, compoundName: "BPC-157", scheduledDate: start.addingTimeInterval(86400 * 1), loggedDate: start.addingTimeInterval(86400 * 1), doseAmount: 250, doseUnit: .mcg, status: .taken)
        let d2 = DoseLog(protocolId: protoId, compoundId: bpcId, compoundName: "BPC-157", scheduledDate: start.addingTimeInterval(86400 * 2), loggedDate: start.addingTimeInterval(86400 * 2), doseAmount: 250, doseUnit: .mcg, status: .taken)
        let d3 = DoseLog(protocolId: protoId, compoundId: bpcId, compoundName: "BPC-157", scheduledDate: start.addingTimeInterval(86400 * 3), loggedDate: start.addingTimeInterval(86400 * 3), doseAmount: 250, doseUnit: .mcg, status: .missed)

        let sequence = engine.buildReplaySequence(
            for: proto,
            doses: [d1, d2, d3],
            calendar: calendar
        )

        // Find event for d1
        let evD1 = sequence.events.first(where: { $0.dosePayload?.doseAmount == 250 && $0.timestamp == d1.scheduledDate })
        XCTAssertEqual(evD1?.cumulativeState?.cumulativeDosesByCompound["BPC-157"], 250.0)
        XCTAssertEqual(evD1?.cumulativeState?.totalDosesAdministered, 1)

        // Find event for d2
        let evD2 = sequence.events.first(where: { $0.timestamp == d2.scheduledDate })
        XCTAssertEqual(evD2?.cumulativeState?.cumulativeDosesByCompound["BPC-157"], 500.0)
        XCTAssertEqual(evD2?.cumulativeState?.totalDosesAdministered, 2)

        // Find event for d3 (missed dose) -> cumulative administered amount remains 500
        let evD3 = sequence.events.first(where: { $0.timestamp == d3.scheduledDate })
        XCTAssertEqual(evD3?.cumulativeState?.cumulativeDosesByCompound["BPC-157"], 500.0)
        XCTAssertEqual(evD3?.cumulativeState?.totalDosesAdministered, 2)

        // Final overall adherence: 2 taken out of 3 = 66.67%
        XCTAssertEqual(sequence.overallAdherenceRate ?? 0, 66.67, accuracy: 0.1)
    }

    // MARK: - 4. Measurement Baseline Delta Calculation
    func testBuildReplaySequence_MeasurementBaselineDelta() {
        let protoId = UUID()
        let start = Date(timeIntervalSince1970: 1700000000)

        let proto = ProtocolModel(
            id: protoId,
            name: "Weight Loss Protocol",
            status: .active,
            startDate: start
        )

        let m1 = Measurement(name: "Body Weight", type: .weight, value: 200.0, unit: "lbs", dateRecorded: start, associatedProtocolId: protoId)
        let m2 = Measurement(name: "Body Weight", type: .weight, value: 195.0, unit: "lbs", dateRecorded: start.addingTimeInterval(86400 * 10), associatedProtocolId: protoId)

        let sequence = engine.buildReplaySequence(for: proto, measurements: [m1, m2], calendar: calendar)

        let evM2 = sequence.events.first(where: { $0.timestamp == m2.dateRecorded })
        XCTAssertNotNil(evM2?.measurementPayload)
        XCTAssertEqual(evM2?.measurementPayload?.deltaFromBaseline, -5.0)
    }

    // MARK: - 5. Chapters Generation
    func testBuildReplaySequence_ChaptersGeneration() {
        let protoId = UUID()
        let start = Date(timeIntervalSince1970: 1700000000)

        let proto = ProtocolModel(
            id: protoId,
            name: "Protocol With Chapters",
            status: .completed,
            startDate: start,
            endDate: start.addingTimeInterval(86400 * 28)
        )

        let lab = LabPanel(panelName: "Diagnostic Bloodwork", collectionDate: start.addingTimeInterval(86400 * 7), associatedProtocolId: protoId)
        let rev = ProtocolRevision(protocolId: protoId, revisionNumber: 2, reasonForChange: "Titration", effectiveDate: start.addingTimeInterval(86400 * 14))

        let sequence = engine.buildReplaySequence(for: proto, labPanels: [lab], protocolRevisions: [rev], calendar: calendar)

        XCTAssertFalse(sequence.chapters.isEmpty)
        // Should have Start Chapter
        XCTAssertTrue(sequence.chapters.contains(where: { $0.title.contains("Protocol Initiated") || $0.title.contains("Launch") }))
        // Should have Titration Chapter
        XCTAssertTrue(sequence.chapters.contains(where: { $0.title.contains("Modification") || $0.title.contains("Titration") }))
        // Should have Lab Chapter
        XCTAssertTrue(sequence.chapters.contains(where: { $0.title.contains("Bloodwork") || $0.title.contains("Labs") }))
    }
}
