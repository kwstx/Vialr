import XCTest
import Domain
import CalculationEngine
@testable import Analytics

final class ProtocolComparisonEngineTests: XCTestCase {

    var engine: ProtocolComparisonEngine!

    override func setUp() {
        super.setUp()
        engine = ProtocolComparisonEngine()
    }

    // MARK: - 1. Descriptive Statistics Mathematical Precision
    func testDescriptiveStatisticsCalculation() {
        let cal = Calendar.current
        let start = Date(timeIntervalSince1970: 1700000000)
        let end = Date(timeIntervalSince1970: 1700000000 + 86400 * 28) // 28 days

        // Known dataset: 10, 20, 30, 40, 50
        var points: [GenericTimeSeriesPoint] = []
        let rawValues = [10.0, 20.0, 30.0, 40.0, 50.0]
        for (i, val) in rawValues.enumerated() {
            let dt = cal.date(byAdding: .day, value: i * 7, to: start)!
            points.append(GenericTimeSeriesPoint(timestamp: dt, value: val, unit: "kg"))
        }

        let stats = engine.computeDescriptiveStatistics(points: points, periodStart: start, periodEnd: end)

        XCTAssertEqual(stats.sampleCount, 5)
        XCTAssertEqual(stats.firstValue, 10.0)
        XCTAssertEqual(stats.lastValue, 50.0)
        XCTAssertEqual(stats.minValue, 10.0)
        XCTAssertEqual(stats.maxValue, 50.0)
        XCTAssertEqual(stats.range, 40.0)
        XCTAssertEqual(stats.meanValue, 30.0, accuracy: 0.001)
        XCTAssertEqual(stats.medianValue, 30.0, accuracy: 0.001)

        // Sample variance for [10, 20, 30, 40, 50]: sum((x - 30)^2) / 4 = (400 + 100 + 0 + 100 + 400) / 4 = 1000 / 4 = 250
        XCTAssertEqual(stats.variance, 250.0, accuracy: 0.001)
        XCTAssertEqual(stats.standardDeviation, sqrt(250.0), accuracy: 0.001)

        // Net change: 50 - 10 = 40
        XCTAssertEqual(stats.netChange, 40.0, accuracy: 0.001)
        XCTAssertEqual(stats.percentageChange, 400.0, accuracy: 0.001) // (40 / 10) * 100

        // Weekly velocity: 40 kg / 4 weeks = 10 kg/wk
        XCTAssertEqual(stats.weeklyVelocity, 10.0, accuracy: 0.001)
    }

    // MARK: - 2. Weight Comparison & Empirical Observed Change vs Interpretation
    func testWeightComparisonAndObservedChangeVsInterpretation() {
        let cal = Calendar.current
        let now = Date()

        let startA = cal.date(byAdding: .day, value: -60, to: now)!
        let endA = cal.date(byAdding: .day, value: -31, to: now)!
        let intervalA = DateInterval(start: startA, end: endA)

        let startB = cal.date(byAdding: .day, value: -30, to: now)!
        let endB = now
        let intervalB = DateInterval(start: startB, end: endB)

        var measurements: [Measurement] = []

        // Period A: 30 days, weight: 200 lbs down to 195 lbs (Net: -5 lbs, Vel: -1.17 lbs/wk)
        for i in 0..<15 {
            let dt = cal.date(byAdding: .day, value: i * 2, to: startA)!
            let val = 200.0 - (Double(i) * 0.357)
            measurements.append(Measurement.weight(val, unit: .lbs, dateRecorded: dt))
        }

        // Period B: 30 days, weight: 195 lbs down to 183 lbs (Net: -12 lbs, Vel: -2.80 lbs/wk)
        for i in 0..<15 {
            let dt = cal.date(byAdding: .day, value: i * 2, to: startB)!
            let val = 195.0 - (Double(i) * 0.857)
            measurements.append(Measurement.weight(val, unit: .lbs, dateRecorded: dt))
        }

        let result = engine.compareWeight(
            measurements: measurements,
            rangeA: intervalA,
            rangeB: intervalB,
            nameA: "Protocol A (Semaglutide 0.5mg)",
            nameB: "Protocol B (Tirzepatide 5.0mg)",
            compoundNamesA: ["Semaglutide"],
            compoundNamesB: ["Tirzepatide"]
        )

        XCTAssertNotNil(result)
        guard let res = result else { return }

        // 1. Verify Empirical Observed Change
        XCTAssertEqual(res.observedChange.periodAStats.sampleCount, 15)
        XCTAssertEqual(res.observedChange.periodBStats.sampleCount, 15)
        XCTAssertLessThan(res.observedChange.periodBStats.netChange, res.observedChange.periodAStats.netChange)
        XCTAssertLessThan(res.observedChange.periodBStats.weeklyVelocity, res.observedChange.periodAStats.weeklyVelocity)
        XCTAssertNotNil(res.observedChange.cohensDEffectSize)
        XCTAssertGreaterThan(res.observedChange.cohensDEffectSize ?? 0, 0.5)

        // 2. Verify Qualitative Interpretation & Non-Causality Principles
        XCTAssertEqual(res.interpretation.trajectoryAssessment, .superiorPeriodB)
        XCTAssertEqual(res.interpretation.causalityClassification, .observationalAssociationOnly)
        XCTAssertFalse(res.interpretation.nonCausalityDisclaimer.isEmpty)
        XCTAssertTrue(res.interpretation.nonCausalityDisclaimer.contains("does not constitute proof of pharmacological causation"))
        XCTAssertFalse(res.interpretation.potentialConfounders.isEmpty)
        XCTAssertTrue(res.interpretation.narrativeSummary.contains("Protocol B"))
    }

    // MARK: - 3. Vital & Physical Measurements Comparison
    func testVitalMeasurementsComparison() {
        let cal = Calendar.current
        let now = Date()

        let startA = cal.date(byAdding: .day, value: -60, to: now)!
        let endA = cal.date(byAdding: .day, value: -31, to: now)!
        let intervalA = DateInterval(start: startA, end: endA)

        let startB = cal.date(byAdding: .day, value: -30, to: now)!
        let endB = now
        let intervalB = DateInterval(start: startB, end: endB)

        var measurements: [Measurement] = []

        // Resting Heart Rate in Period A (75 bpm) vs Period B (68 bpm)
        for i in 0..<10 {
            let dtA = cal.date(byAdding: .day, value: i * 3, to: startA)!
            measurements.append(Measurement.heartRate(75.0 + Double(i % 3), dateRecorded: dtA))

            let dtB = cal.date(byAdding: .day, value: i * 3, to: startB)!
            measurements.append(Measurement.heartRate(68.0 + Double(i % 2), dateRecorded: dtB))
        }

        // Blood Glucose in Period A (105 mg/dL) vs Period B (88 mg/dL)
        for i in 0..<10 {
            let dtA = cal.date(byAdding: .day, value: i * 3, to: startA)!
            measurements.append(Measurement.bloodGlucose(105.0 - Double(i % 4), dateRecorded: dtA))

            let dtB = cal.date(byAdding: .day, value: i * 3, to: startB)!
            measurements.append(Measurement.bloodGlucose(88.0 - Double(i % 3), dateRecorded: dtB))
        }

        let comps = engine.compareMeasurements(
            measurements: measurements,
            metricTypes: [.restingHeartRate, .bloodGlucose],
            rangeA: intervalA,
            rangeB: intervalB,
            nameA: "Baseline Period",
            nameB: "Active Protocol"
        )

        XCTAssertEqual(comps.count, 2)

        let hrComp = comps.first { $0.metricDefinition.code == MetricDefinition.builtIn(for: .restingHeartRate).code }
        XCTAssertNotNil(hrComp)
        XCTAssertLessThan(hrComp!.observedChange.periodBStats.meanValue, hrComp!.observedChange.periodAStats.meanValue)

        let glucoseComp = comps.first { $0.metricDefinition.code == MetricDefinition.builtIn(for: .bloodGlucose).code }
        XCTAssertNotNil(glucoseComp)
        XCTAssertLessThan(glucoseComp!.observedChange.periodBStats.meanValue, glucoseComp!.observedChange.periodAStats.meanValue)
    }

    // MARK: - 4. Dose Adherence Comparison
    func testDoseAdherenceComparison() {
        let cal = Calendar.current
        let now = Date()

        let startA = cal.date(byAdding: .day, value: -60, to: now)!
        let endA = cal.date(byAdding: .day, value: -31, to: now)!
        let intervalA = DateInterval(start: startA, end: endA)

        let startB = cal.date(byAdding: .day, value: -30, to: now)!
        let endB = now
        let intervalB = DateInterval(start: startB, end: endB)

        var doseLogs: [DoseLog] = []
        let compoundId = UUID()

        // Period A: 30 doses, 27 taken, 3 missed (90% adherence)
        for i in 0..<30 {
            let dt = cal.date(byAdding: .day, value: i, to: startA)!
            doseLogs.append(
                DoseLog(
                    compoundId: compoundId,
                    compoundName: "CJC-1295",
                    scheduledDate: dt,
                    loggedDate: dt,
                    status: i % 10 == 0 ? .missed : .taken,
                    doseAmount: 100,
                    doseUnit: .mcg
                )
            )
        }

        // Period B: 30 doses, 30 taken, 0 missed (100% adherence)
        for i in 0..<30 {
            let dt = cal.date(byAdding: .day, value: i, to: startB)!
            doseLogs.append(
                DoseLog(
                    compoundId: compoundId,
                    compoundName: "CJC-1295",
                    scheduledDate: dt,
                    loggedDate: dt,
                    status: .taken,
                    doseAmount: 100,
                    doseUnit: .mcg
                )
            )
        }

        let adhResult = engine.compareAdherence(
            doseLogs: doseLogs,
            rangeA: intervalA,
            rangeB: intervalB,
            nameA: "Protocol A",
            nameB: "Protocol B"
        )

        XCTAssertEqual(adhResult.observedChange.periodAStats.takenDoses, 27)
        XCTAssertEqual(adhResult.observedChange.periodAStats.missedDoses, 3)
        XCTAssertEqual(adhResult.observedChange.periodAStats.adherencePercentage, 90.0, accuracy: 0.1)

        XCTAssertEqual(adhResult.observedChange.periodBStats.takenDoses, 30)
        XCTAssertEqual(adhResult.observedChange.periodBStats.missedDoses, 0)
        XCTAssertEqual(adhResult.observedChange.periodBStats.adherencePercentage, 100.0, accuracy: 0.1)

        XCTAssertEqual(adhResult.observedChange.adherenceRateDifference, 10.0, accuracy: 0.1)
        XCTAssertEqual(adhResult.observedChange.missedDoseDifference, -3)
        XCTAssertFalse(adhResult.interpretation.potentialConfounders.isEmpty)
    }

    // MARK: - 5. Subjective Symptoms & Well-Being Comparison
    func testSubjectiveSymptomsComparison() {
        let cal = Calendar.current
        let now = Date()

        let startA = cal.date(byAdding: .day, value: -60, to: now)!
        let endA = cal.date(byAdding: .day, value: -31, to: now)!
        let intervalA = DateInterval(start: startA, end: endA)

        let startB = cal.date(byAdding: .day, value: -30, to: now)!
        let endB = now
        let intervalB = DateInterval(start: startB, end: endB)

        var symptomLogs: [SymptomLog] = []

        // Period A: lower energy (5), sleep (6), recovery (5), mood (6), 3 side effect reports
        for i in 0..<10 {
            let dt = cal.date(byAdding: .day, value: i * 3, to: startA)!
            symptomLogs.append(
                SymptomLog(
                    timestamp: dt,
                    energyLevel: 5,
                    sleepQuality: 6,
                    recoveryScore: 5,
                    moodScore: 6,
                    sideEffects: i % 3 == 0 ? ["Mild Nausea"] : []
                )
            )
        }

        // Period B: higher energy (8), sleep (9), recovery (9), mood (8), 0 side effects
        for i in 0..<10 {
            let dt = cal.date(byAdding: .day, value: i * 3, to: startB)!
            symptomLogs.append(
                SymptomLog(
                    timestamp: dt,
                    energyLevel: 8,
                    sleepQuality: 9,
                    recoveryScore: 9,
                    moodScore: 8,
                    sideEffects: []
                )
            )
        }

        let symResult = engine.compareSymptoms(
            symptomLogs: symptomLogs,
            rangeA: intervalA,
            rangeB: intervalB,
            nameA: "Protocol A",
            nameB: "Protocol B"
        )

        XCTAssertGreaterThan(symResult.observedChange.compositeScoreDifference, 0)
        XCTAssertEqual(symResult.observedChange.sideEffectOccurrencesA, 4) // i=0,3,6,9
        XCTAssertEqual(symResult.observedChange.sideEffectOccurrencesB, 0)
        XCTAssertEqual(symResult.interpretation.wellbeingTrajectory, .superiorPeriodB)
        XCTAssertEqual(symResult.interpretation.confidenceLevel, .high)
    }

    // MARK: - 6. Blood Biomarkers Comparison
    func testBiomarkersComparison() {
        let cal = Calendar.current
        let now = Date()

        let startA = cal.date(byAdding: .day, value: -60, to: now)!
        let endA = cal.date(byAdding: .day, value: -31, to: now)!
        let intervalA = DateInterval(start: startA, end: endA)

        let startB = cal.date(byAdding: .day, value: -30, to: now)!
        let endB = now
        let intervalB = DateInterval(start: startB, end: endB)

        let biomarkers: [Biomarker] = [
            // Total Testosterone
            Biomarker(name: "Total Testosterone", category: .bloodwork, value: 420.0, unit: "ng/dL", referenceRangeMin: 300, referenceRangeMax: 1000, dateRecorded: startA.addingTimeInterval(86400 * 15)),
            Biomarker(name: "Total Testosterone", category: .bloodwork, value: 780.0, unit: "ng/dL", referenceRangeMin: 300, referenceRangeMax: 1000, dateRecorded: startB.addingTimeInterval(86400 * 15)),

            // IGF-1
            Biomarker(name: "IGF-1", category: .bloodwork, value: 140.0, unit: "ng/mL", referenceRangeMin: 115, referenceRangeMax: 307, dateRecorded: startA.addingTimeInterval(86400 * 15)),
            Biomarker(name: "IGF-1", category: .bloodwork, value: 265.0, unit: "ng/mL", referenceRangeMin: 115, referenceRangeMax: 307, dateRecorded: startB.addingTimeInterval(86400 * 15))
        ]

        let bioResults = engine.compareBiomarkers(
            biomarkers: biomarkers,
            rangeA: intervalA,
            rangeB: intervalB,
            nameA: "Pre-Protocol",
            nameB: "Active Protocol"
        )

        XCTAssertEqual(bioResults.count, 2)

        let testMarker = bioResults.first { $0.observedChange.biomarkerName == "Total Testosterone" }
        XCTAssertNotNil(testMarker)
        XCTAssertEqual(testMarker!.observedChange.absoluteShift, 360.0, accuracy: 0.1) // 780 - 420
        XCTAssertEqual(testMarker!.observedChange.statusA, .inRange)
        XCTAssertEqual(testMarker!.observedChange.statusB, .inRange)
    }

    // MARK: - 7. Financial Cost Comparison
    func testCostComparison() {
        let cal = Calendar.current
        let now = Date()

        let startA = cal.date(byAdding: .day, value: -60, to: now)!
        let endA = cal.date(byAdding: .day, value: -31, to: now)!
        let intervalA = DateInterval(start: startA, end: endA)

        let startB = cal.date(byAdding: .day, value: -30, to: now)!
        let endB = now
        let intervalB = DateInterval(start: startB, end: endB)

        let protoAId = UUID()
        let protoBId = UUID()

        let costEvents: [CostEvent] = [
            CostEvent(title: "Semaglutide 5mg", amount: 150.0, category: .peptideVial, dateIncurred: startA, protocolId: protoAId),
            CostEvent(title: "Syringes & BAC", amount: 35.0, category: .medicalSupplies, dateIncurred: startA, protocolId: protoAId),
            CostEvent(title: "Tirzepatide 15mg", amount: 280.0, category: .peptideVial, dateIncurred: startB, protocolId: protoBId),
            CostEvent(title: "Syringes", amount: 25.0, category: .medicalSupplies, dateIncurred: startB, protocolId: protoBId),
            CostEvent(title: "Follow-up Blood Panel", amount: 95.0, category: .bloodwork, dateIncurred: startB, protocolId: protoBId)
        ]

        let costResult = engine.compareCosts(
            costEvents: costEvents,
            rangeA: intervalA,
            rangeB: intervalB,
            nameA: "Protocol A",
            nameB: "Protocol B",
            protocolAId: protoAId,
            protocolBId: protoBId
        )

        // Protocol A: 150 + 35 = $185
        XCTAssertEqual(costResult.observedChange.totalCostA, 185.0, accuracy: 0.01)
        // Protocol B: 280 + 25 + 95 = $400
        XCTAssertEqual(costResult.observedChange.totalCostB, 400.0, accuracy: 0.01)
        XCTAssertEqual(costResult.observedChange.costDeltaTotal, 215.0, accuracy: 0.01)
        XCTAssertFalse(costResult.interpretation.financialEfficiencySummary.isEmpty)
    }

    // MARK: - 8. Full Report Master Synthesis & Non-Causality Guarantee
    func testGenerateComparisonReport() {
        let cal = Calendar.current
        let now = Date()

        let pAId = UUID()
        let startA = cal.date(byAdding: .day, value: -60, to: now)!
        let endA = cal.date(byAdding: .day, value: -31, to: now)!
        let protoA = ProtocolModel(id: pAId, name: "Protocol Alpha", status: .completed, startDate: startA, endDate: endA)

        let pBId = UUID()
        let startB = cal.date(byAdding: .day, value: -30, to: now)!
        let endB = now
        let protoB = ProtocolModel(id: pBId, name: "Protocol Beta", status: .active, startDate: startB, endDate: endB)

        let periodA = ProtocolComparisonPeriod.fromProtocol(protoA)
        let periodB = ProtocolComparisonPeriod.fromProtocol(protoB)

        let report = engine.generateComparisonReport(
            periodA: periodA,
            periodB: periodB,
            measurements: [
                Measurement.weight(200.0, dateRecorded: startA),
                Measurement.weight(195.0, dateRecorded: endA),
                Measurement.weight(195.0, dateRecorded: startB),
                Measurement.weight(185.0, dateRecorded: endB)
            ],
            doseLogs: [],
            completedDoses: [],
            symptomLogs: [],
            biomarkers: [],
            costEvents: []
        )

        XCTAssertNotNil(report.weightComparison)
        XCTAssertFalse(report.executiveSummary.isEmpty)
        XCTAssertFalse(report.identifiedConfounders.isEmpty)
        XCTAssertTrue(report.nonCausalityAdvisory.contains("does not constitute proof of pharmacological causation"))
    }

    // MARK: - 9. Edge Cases: Sparse Data and Empty Intervals
    func testSparseAndEmptyIntervals() {
        let now = Date()
        let intervalA = DateInterval(start: now.addingTimeInterval(-86400 * 30), end: now.addingTimeInterval(-86400 * 15))
        let intervalB = DateInterval(start: now.addingTimeInterval(-86400 * 14), end: now)

        // Empty measurements
        let weightResult = engine.compareWeight(
            measurements: [],
            rangeA: intervalA,
            rangeB: intervalB
        )
        XCTAssertNil(weightResult)

        // Single data point in Period A, zero in Period B
        let singlePoint = [Measurement.weight(180.0, dateRecorded: intervalA.start.addingTimeInterval(3600))]
        let singleComp = engine.compareTimeSeries(
            seriesA: singlePoint,
            seriesB: singlePoint,
            rangeA: intervalA,
            rangeB: intervalB,
            metric: .bodyWeight
        )

        XCTAssertEqual(singleComp.observedChange.periodAStats.sampleCount, 1)
        XCTAssertEqual(singleComp.observedChange.periodBStats.sampleCount, 0)
        XCTAssertEqual(singleComp.interpretation.confidenceLevel, .insufficientData)
    }
}
