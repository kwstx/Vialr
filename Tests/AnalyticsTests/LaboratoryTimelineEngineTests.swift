import XCTest
import Domain
import CalculationEngine
@testable import Analytics

final class LaboratoryTimelineEngineTests: XCTestCase {

    var engine: LaboratoryTimelineEngine!

    override func setUp() {
        super.setUp()
        engine = LaboratoryTimelineEngine()
    }

    // MARK: - 1. Event Alignment Chronological Integrity Test
    func testEventAlignmentChronologicalIntegrity() {
        let cal = Calendar.current
        let now = Date()

        // 1. Baseline Lab Draw (Day -60)
        let t1 = cal.date(byAdding: .day, value: -60, to: now)!
        let baselinePanel = LabPanel(
            panelName: "Baseline Hormone Panel",
            labName: "Quest Diagnostics",
            collectionDate: t1,
            results: [
                LabResult(biomarkerName: "Total Testosterone", category: .hormones, value: 450, unit: "ng/dL", referenceRangeMin: 300, referenceRangeMax: 1000, flag: .inRange)
            ]
        )

        // 2. Protocol A Start (Day -45)
        let protoAId = UUID()
        let t2 = cal.date(byAdding: .day, value: -45, to: now)!
        let t3 = cal.date(byAdding: .day, value: -20, to: now)!
        let protocolA = ProtocolModel(
            id: protoAId,
            name: "Protocol A (BPC-157 250mcg)",
            status: .completed,
            startDate: t2,
            endDate: t3,
            compounds: [ProtocolCompound(compoundName: "BPC-157", dosageAmount: 250, unit: .mcg)]
        )

        // 3. Dose Event (Day -30)
        let t4 = cal.date(byAdding: .day, value: -30, to: now)!
        let dose = DoseLog(
            compoundId: UUID(),
            compoundName: "BPC-157",
            scheduledDate: t4,
            loggedDate: t4,
            status: .taken,
            associatedProtocolId: protoAId,
            doseAmount: 250,
            doseUnit: .mcg
        )

        // 4. Dose Change / Titration Revision (Day -15)
        let t5 = cal.date(byAdding: .day, value: -15, to: now)!
        let protoBId = UUID()
        let protocolB = ProtocolModel(
            id: protoBId,
            name: "Protocol B (TB-500 2mg)",
            status: .active,
            startDate: t5,
            endDate: nil,
            compounds: [ProtocolCompound(compoundName: "TB-500", dosageAmount: 2, unit: .mg)]
        )

        let revB = ProtocolRevision(
            protocolId: protoBId,
            revisionNumber: 2,
            name: "Protocol B Titration",
            compounds: [ProtocolCompound(compoundName: "TB-500", dosageAmount: 3, unit: .mg)],
            reasonForChange: "Increased to 3mg",
            effectiveDate: cal.date(byAdding: .day, value: -7, to: now)!
        )

        // 5. Follow-Up Lab Draw (Day -2)
        let t6 = cal.date(byAdding: .day, value: -2, to: now)!
        let followUpPanel = LabPanel(
            panelName: "Follow-Up Hormone Panel",
            labName: "Labcorp",
            collectionDate: t6,
            results: [
                LabResult(biomarkerName: "Total Testosterone", category: .hormones, value: 720, unit: "ng/dL", referenceRangeMin: 300, referenceRangeMax: 1000, flag: .inRange)
            ]
        )

        let analysis = engine.generateAnalysis(
            labPanels: [followUpPanel, baselinePanel], // intentionally out of order
            protocols: [protocolB, protocolA], // intentionally out of order
            protocolRevisions: [revB],
            doseLogs: [dose]
        )

        // Verify total aligned events
        XCTAssertGreaterThanOrEqual(analysis.alignedEvents.count, 5)

        // Verify strict chronological ordering: each event timestamp <= next event timestamp
        for i in 0..<(analysis.alignedEvents.count - 1) {
            let current = analysis.alignedEvents[i]
            let next = analysis.alignedEvents[i + 1]
            XCTAssertLessThanOrEqual(current.timestamp, next.timestamp, "Event alignment violation at index \(i)")
        }

        // Verify first event is Baseline Lab
        XCTAssertEqual(analysis.alignedEvents.first?.type, .baselineDraw)
    }

    // MARK: - 2. Protocol Period Overlay Synthesis Test
    func testProtocolPeriodOverlaySynthesis() {
        let cal = Calendar.current
        let now = Date()

        let baseDate = cal.date(byAdding: .day, value: -90, to: now)!
        let baselinePanel = LabPanel(
            panelName: "Baseline",
            collectionDate: baseDate,
            results: [LabResult(biomarkerName: "Fasting Blood Glucose", value: 95, unit: "mg/dL")]
        )

        let startA = cal.date(byAdding: .day, value: -60, to: now)!
        let endA = cal.date(byAdding: .day, value: -30, to: now)!
        let protocolA = ProtocolModel(name: "Protocol A", status: .completed, startDate: startA, endDate: endA)

        let startB = cal.date(byAdding: .day, value: -20, to: now)! // 10 day gap -> should create Washout
        let protocolB = ProtocolModel(name: "Protocol B", status: .active, startDate: startB, endDate: nil)

        let overlays = engine.buildProtocolOverlays(
            protocols: [protocolA, protocolB],
            labPanels: [baselinePanel]
        )

        // Expected Overlays: Baseline -> Protocol A -> Washout (10d) -> Protocol B
        XCTAssertEqual(overlays.count, 4)

        XCTAssertEqual(overlays[0].phaseType, .baseline)
        XCTAssertEqual(overlays[1].phaseType, .activeProtocol)
        XCTAssertEqual(overlays[1].name, "Protocol A")
        XCTAssertEqual(overlays[2].phaseType, .washout)
        XCTAssertTrue(overlays[2].name.contains("Washout"))
        XCTAssertEqual(overlays[3].phaseType, .activeProtocol)
        XCTAssertEqual(overlays[3].name, "Protocol B")
        XCTAssertTrue(overlays[3].isOngoing)
    }

    // MARK: - 3. Lab Time Series Points Extraction & Phase Attribution Test
    func testLabTimeSeriesPointExtractionAndPhaseAttribution() {
        let cal = Calendar.current
        let now = Date()

        let startA = cal.date(byAdding: .day, value: -50, to: now)!
        let endA = cal.date(byAdding: .day, value: -10, to: now)!
        let protoAId = UUID()
        let protocolA = ProtocolModel(id: protoAId, name: "Protocol A", status: .completed, startDate: startA, endDate: endA)

        // Lab drawn on Day 20 of Protocol A
        let drawDate = cal.date(byAdding: .day, value: 20, to: startA)!
        let panel = LabPanel(
            panelName: "Mid-Cycle Check",
            labName: "Quest Diagnostics",
            collectionDate: drawDate,
            results: [
                LabResult(
                    biomarkerName: "IGF-1 (Somatomedin C)",
                    category: .hormones,
                    value: 280,
                    unit: "ng/mL",
                    referenceRangeMin: 115,
                    referenceRangeMax: 355,
                    flag: .inRange
                )
            ]
        )

        // 10 daily doses of 200mcg taken prior to draw = 2000mcg cumulative
        var doses: [DoseLog] = []
        for i in 0..<10 {
            let dt = cal.date(byAdding: .day, value: i, to: startA)!
            doses.append(
                DoseLog(
                    compoundId: UUID(),
                    compoundName: "CJC-1295",
                    scheduledDate: dt,
                    loggedDate: dt,
                    status: .taken,
                    associatedProtocolId: protoAId,
                    doseAmount: 200,
                    doseUnit: .mcg
                )
            )
        }

        let overlays = engine.buildProtocolOverlays(protocols: [protocolA])
        let series = engine.buildBiomarkerTimeSeries(
            labPanels: [panel],
            overlays: overlays,
            doseLogs: doses
        )

        let igfPoints = series["IGF-1 (Somatomedin C)"]
        XCTAssertNotNil(igfPoints)
        XCTAssertEqual(igfPoints?.count, 1)

        guard let pt = igfPoints?.first else { return }
        XCTAssertEqual(pt.value, 280)
        XCTAssertEqual(pt.unit, "ng/mL")
        XCTAssertEqual(pt.protocolPhase, .activeProtocol)
        XCTAssertEqual(pt.protocolName, "Protocol A")
        XCTAssertEqual(pt.daysOnProtocolAtDraw, 20)
        XCTAssertEqual(pt.cumulativeDosePriorToDraw, 2000.0)
        XCTAssertEqual(pt.isNormal, true)
    }

    // MARK: - 4. Phase Transition Milestones & Delta Test
    func testPhaseTransitionMilestonesAndDeltas() {
        let cal = Calendar.current
        let now = Date()

        // 1. Baseline: 450 ng/dL (Day -60)
        let baseDate = cal.date(byAdding: .day, value: -60, to: now)!
        let basePanel = LabPanel(
            panelName: "Baseline",
            collectionDate: baseDate,
            results: [LabResult(biomarkerName: "Total Testosterone", value: 450, unit: "ng/dL", referenceRangeMin: 300, referenceRangeMax: 1000)]
        )

        // 2. Protocol A: 550 ng/dL (Day -30) -> Delta +100 (+22.2%)
        let startA = cal.date(byAdding: .day, value: -45, to: now)!
        let endA = cal.date(byAdding: .day, value: -16, to: now)!
        let protoA = ProtocolModel(name: "Protocol A", status: .completed, startDate: startA, endDate: endA)
        let midDateA = cal.date(byAdding: .day, value: -30, to: now)!
        let midPanelA = LabPanel(
            panelName: "Mid A",
            collectionDate: midDateA,
            results: [LabResult(biomarkerName: "Total Testosterone", value: 550, unit: "ng/dL", referenceRangeMin: 300, referenceRangeMax: 1000)]
        )

        // 3. Protocol B: 750 ng/dL (Day -2) -> Delta +200 (+36.4% vs Proto A, +300 vs Baseline)
        let startB = cal.date(byAdding: .day, value: -15, to: now)!
        let protoB = ProtocolModel(name: "Protocol B", status: .active, startDate: startB, endDate: nil)
        let followUpDate = cal.date(byAdding: .day, value: -2, to: now)!
        let followUpPanel = LabPanel(
            panelName: "Follow-Up",
            collectionDate: followUpDate,
            results: [LabResult(biomarkerName: "Total Testosterone", value: 750, unit: "ng/dL", referenceRangeMin: 300, referenceRangeMax: 1000)]
        )

        let analysis = engine.generateAnalysis(
            labPanels: [basePanel, midPanelA, followUpPanel],
            protocols: [protoA, protoB],
            selectedBiomarkerName: "Total Testosterone"
        )

        let milestones = analysis.phaseMilestones
        XCTAssertEqual(milestones.count, 3)

        // Milestone 0: Baseline
        XCTAssertEqual(milestones[0].phaseType, .baseline)
        XCTAssertEqual(milestones[0].analyteValue, 450)
        XCTAssertNil(milestones[0].deltaFromPrevious)

        // Milestone 1: Protocol A
        XCTAssertEqual(milestones[1].phaseType, .activeProtocol)
        XCTAssertEqual(milestones[1].analyteValue, 550)
        XCTAssertEqual(milestones[1].deltaFromPrevious ?? 0, 100.0, accuracy: 0.01)
        XCTAssertEqual(milestones[1].percentageDeltaFromPrevious ?? 0, 22.22, accuracy: 0.01)
        XCTAssertEqual(milestones[1].deltaFromBaseline ?? 0, 100.0, accuracy: 0.01)

        // Milestone 2: Protocol B
        XCTAssertEqual(milestones[2].phaseType, .activeProtocol)
        XCTAssertEqual(milestones[2].analyteValue, 750)
        XCTAssertEqual(milestones[2].deltaFromPrevious ?? 0, 200.0, accuracy: 0.01)
        XCTAssertEqual(milestones[2].percentageDeltaFromPrevious ?? 0, 36.36, accuracy: 0.01)
        XCTAssertEqual(milestones[2].deltaFromBaseline ?? 0, 300.0, accuracy: 0.01)
        XCTAssertEqual(milestones[2].percentageDeltaFromBaseline ?? 0, 66.66, accuracy: 0.01)

        // Pairwise Phase Deltas
        XCTAssertEqual(analysis.phaseDeltas.count, 2)
        XCTAssertEqual(analysis.phaseDeltas[0].absoluteDelta, 100.0, accuracy: 0.01)
        XCTAssertEqual(analysis.phaseDeltas[1].absoluteDelta, 200.0, accuracy: 0.01)
    }

    // MARK: - 5. Empty and Sparse Data Edge Cases Test
    func testEmptyAndSparseDataGracefulHandling() {
        let emptyAnalysis = engine.generateAnalysis()
        XCTAssertTrue(emptyAnalysis.alignedEvents.isEmpty)
        XCTAssertTrue(emptyAnalysis.protocolOverlays.isEmpty)
        XCTAssertTrue(emptyAnalysis.phaseMilestones.isEmpty)
        XCTAssertTrue(emptyAnalysis.phaseDeltas.isEmpty)
        XCTAssertEqual(emptyAnalysis.totalLabDraws, 0)
        XCTAssertEqual(emptyAnalysis.totalDosesAligned, 0)
        XCTAssertFalse(emptyAnalysis.overallSummaryText.isEmpty)
    }
}
