import XCTest
import Domain
import CalculationEngine
@testable import Analytics

final class ResultsTrackingEngineTests: XCTestCase {

    var engine: ResultsTrackingEngine!

    override func setUp() {
        super.setUp()
        engine = ResultsTrackingEngine()
    }

    // MARK: - 1. Generic Time Series Tests
    func testGenericTimeSeriesOperations() {
        let cal = Calendar.current
        let now = Date()

        let p1 = GenericTimeSeriesPoint(timestamp: cal.date(byAdding: .day, value: -4, to: now)!, value: 100.0, unit: "lbs")
        let p2 = GenericTimeSeriesPoint(timestamp: cal.date(byAdding: .day, value: -2, to: now)!, value: 110.0, unit: "lbs")
        let p3 = GenericTimeSeriesPoint(timestamp: cal.date(byAdding: .day, value: 0, to: now)!, value: 120.0, unit: "lbs")

        // Intentionally create unsorted time series
        let series = TimeSeries(points: [p3, p1, p2])

        // Verify automatic chronological sorting
        XCTAssertEqual(series.points.first?.value, 100.0)
        XCTAssertEqual(series.points.last?.value, 120.0)
        XCTAssertEqual(series.count, 3)

        // Verify statistical aggregations
        XCTAssertEqual(series.minValue, 100.0)
        XCTAssertEqual(series.maxValue, 120.0)
        XCTAssertEqual(series.meanValue ?? 0, 110.0, accuracy: 0.001)
        XCTAssertEqual(series.medianValue ?? 0, 110.0, accuracy: 0.001)
        XCTAssertEqual(series.overallDelta ?? 0, 20.0, accuracy: 0.001)
        XCTAssertEqual(series.overallPercentageChange ?? 0, 20.0, accuracy: 0.001)

        // Verify linear interpolation
        let midDate = cal.date(byAdding: .day, value: -3, to: now)!
        let interpolated = series.linearInterpolate(at: midDate)
        XCTAssertNotNil(interpolated)
        XCTAssertEqual(interpolated ?? 0, 105.0, accuracy: 0.01)

        // Verify daily bucketing
        let buckets = series.dailyBuckets(strategy: .mean)
        XCTAssertEqual(buckets.count, 3)
    }

    // MARK: - 2. Moving Average Calculations Tests
    func testMovingAverageCalculations() {
        let cal = Calendar.current
        let now = Date()

        // 7 days of steady values: 10, 20, 30, 40, 50, 60, 70
        var measurements: [Measurement] = []
        for i in 0..<7 {
            let dt = cal.date(byAdding: .day, value: i - 6, to: now)!
            measurements.append(
                Measurement(
                    name: "Body Weight",
                    type: .weight,
                    category: .bodyComposition,
                    value: Double((i + 1) * 10),
                    unit: "lbs",
                    dateRecorded: dt
                )
            )
        }

        // Count-based SMA with window size 3
        let sma = engine.calculateCountSMA(points: measurements, metricCode: "weight", windowSize: 3)
        XCTAssertEqual(sma.points.count, 7)

        // Point 0 (10) -> avg: 10
        XCTAssertEqual(sma.points[0].movingAverage, 10.0, accuracy: 0.01)
        // Point 1 (10, 20) -> avg: 15
        XCTAssertEqual(sma.points[1].movingAverage, 15.0, accuracy: 0.01)
        // Point 2 (10, 20, 30) -> avg: 20
        XCTAssertEqual(sma.points[2].movingAverage, 20.0, accuracy: 0.01)
        // Point 6 (50, 60, 70) -> avg: 60
        XCTAssertEqual(sma.points[6].movingAverage, 60.0, accuracy: 0.01)

        // Exponential Moving Average (EMA)
        let ema = engine.calculateEMA(points: measurements, metricCode: "weight", windowDays: 7)
        XCTAssertEqual(ema.points.count, 7)
        XCTAssertEqual(ema.points.first?.movingAverage, 10.0)
        XCTAssertGreaterThan(ema.points.last?.movingAverage ?? 0, 50.0)
    }

    // MARK: - 3. Percentage Change Calculations Tests
    func testPercentageChangeCalculations() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let end = Date(timeIntervalSince1970: 1700000000 + 86400 * 14) // 2 weeks later

        // Weight decreasing from 200 lbs to 190 lbs (-10 lbs = -5%)
        let result = engine.calculatePercentageChange(
            startValue: 200.0,
            endValue: 190.0,
            startDate: start,
            endDate: end,
            periodName: "14-Day Cycle",
            targetDirection: .decrease
        )

        XCTAssertEqual(result.absoluteDelta, -10.0, accuracy: 0.01)
        XCTAssertEqual(result.percentageChange, -5.0, accuracy: 0.01)
        XCTAssertEqual(result.ratePerWeek ?? 0, -5.0, accuracy: 0.01) // -10 lbs / 2 weeks = -5 lbs/wk
        XCTAssertEqual(result.trendDirection, .improving) // Target is decrease, so -5% is improving
    }

    // MARK: - 4. Baseline Difference Calculations Tests
    func testBaselineDifferenceCalculations() {
        let cal = Calendar.current
        let now = Date()

        let baseDate = cal.date(byAdding: .day, value: -30, to: now)!
        let latestDate = now

        let m1 = Measurement(name: "Fasting Glucose", type: .bloodGlucose, value: 110.0, unit: "mg/dL", dateRecorded: baseDate)
        let m2 = Measurement(name: "Fasting Glucose", type: .bloodGlucose, value: 100.0, unit: "mg/dL", dateRecorded: cal.date(byAdding: .day, value: -15, to: now)!)
        let m3 = Measurement(name: "Fasting Glucose", type: .bloodGlucose, value: 85.0, unit: "mg/dL", dateRecorded: latestDate)

        let baselineResult = engine.calculateBaselineDifference(
            points: [m1, m2, m3],
            metricName: "Fasting Glucose",
            unit: "mg/dL",
            baselineMode: .firstRecorded,
            targetValue: 80.0,
            targetDirection: .decrease
        )

        XCTAssertNotNil(baselineResult)
        guard let base = baselineResult else { return }

        XCTAssertEqual(base.baselineValue, 110.0)
        XCTAssertEqual(base.currentValue, 85.0)
        XCTAssertEqual(base.absoluteDifference, -25.0, accuracy: 0.01)
        XCTAssertEqual(base.percentageDifference, -22.727, accuracy: 0.01)
        XCTAssertEqual(base.evaluationStatus, .onTrack)

        // Needed: 110 -> 80 (delta needed: -30). Achieved: 110 -> 85 (delta: -25). Progress: 25/30 = 83.33%
        XCTAssertEqual(base.targetAttainmentPercentage ?? 0, 83.333, accuracy: 0.01)
    }

    // MARK: - 5. Adherence Relationship Calculations Tests
    func testAdherenceRelationshipCalculations() {
        let cal = Calendar.current
        let now = Date()
        let protocolId = UUID()
        let bpcId = UUID()

        var measurements: [Measurement] = []
        var doseLogs: [DoseLog] = []

        // 4 weeks of data (28 days)
        for day in 0..<28 {
            let dt = cal.date(byAdding: .day, value: day - 27, to: now)!

            // Days 0-13 (Weeks 1-2): High Adherence (Taken every day) -> Pain drops from 8 to 4
            // Days 14-27 (Weeks 3-4): Lower Adherence (Missed 4 days) -> Pain drops from 4 to 2
            let isFirstTwoWeeks = day < 14
            let isTaken = isFirstTwoWeeks ? true : (day % 3 != 0)

            doseLogs.append(
                DoseLog(
                    compoundId: bpcId,
                    compoundName: "BPC-157",
                    scheduledDate: dt,
                    loggedDate: dt,
                    status: isTaken ? .taken : .missed,
                    associatedProtocolId: protocolId,
                    doseAmount: 250,
                    doseUnit: .mcg
                )
            )

            let painVal = max(1.0, 8.0 - (Double(day) * 0.22))
            measurements.append(
                Measurement(
                    name: "Pain Index",
                    type: .pain,
                    category: .subjectiveWellbeing,
                    value: painVal,
                    unit: "/10",
                    dateRecorded: dt,
                    associatedProtocolId: protocolId
                )
            )
        }

        let metricDef = MetricDefinition.painIndex
        let relationship = engine.calculateAdherenceRelationship(
            measurements: measurements,
            doseLogs: doseLogs,
            metricDefinition: metricDef
        )

        XCTAssertNotNil(relationship)
        guard let rel = relationship else { return }

        XCTAssertGreaterThan(rel.overallAdherencePercentage, 70.0)
        XCTAssertNotNil(rel.highAdherenceAverageValue)
        XCTAssertFalse(rel.clinicalInsight.isEmpty)
    }

    // MARK: - 6. Protocol Period Comparisons Tests
    func testProtocolPeriodComparisons() {
        let cal = Calendar.current
        let now = Date()

        let protoAId = UUID()
        let startA = cal.date(byAdding: .day, value: -60, to: now)!
        let endA = cal.date(byAdding: .day, value: -31, to: now)!
        let protocolA = ProtocolModel(id: protoAId, name: "Protocol A (Semaglutide 0.5mg)", status: .completed, startDate: startA, endDate: endA)

        let protoBId = UUID()
        let startB = cal.date(byAdding: .day, value: -30, to: now)!
        let endB = now
        let protocolB = ProtocolModel(id: protoBId, name: "Protocol B (Tirzepatide 5mg)", status: .active, startDate: startB, endDate: endB)

        var measurements: [Measurement] = []

        // Protocol A: 30 days, weight: 200 lbs -> 195 lbs (Loss of 5 lbs)
        for day in 0..<30 {
            let dt = cal.date(byAdding: .day, value: day, to: startA)!
            let val = 200.0 - (Double(day) * 0.166)
            measurements.append(Measurement(name: "Body Weight", type: .weight, value: val, unit: "lbs", dateRecorded: dt, associatedProtocolId: protoAId))
        }

        // Protocol B: 30 days, weight: 195 lbs -> 183 lbs (Loss of 12 lbs)
        for day in 0..<30 {
            let dt = cal.date(byAdding: .day, value: day, to: startB)!
            let val = 195.0 - (Double(day) * 0.4)
            measurements.append(Measurement(name: "Body Weight", type: .weight, value: val, unit: "lbs", dateRecorded: dt, associatedProtocolId: protoBId))
        }

        let comparison = engine.compareProtocolPeriods(
            measurements: measurements,
            protocolA: protocolA,
            protocolB: protocolB,
            metricDefinition: .bodyWeight
        )

        XCTAssertNotNil(comparison)
        guard let comp = comparison else { return }

        XCTAssertEqual(comp.periodAStats.sampleCount, 30)
        XCTAssertEqual(comp.periodBStats.sampleCount, 30)
        XCTAssertEqual(comp.protocolAName, "Protocol A (Semaglutide 0.5mg)")
        XCTAssertEqual(comp.protocolBName, "Protocol B (Tirzepatide 5mg)")

        // Protocol B lost 12 lbs vs Protocol A lost 5 lbs -> Protocol B is superior
        XCTAssertEqual(comp.superiorProtocolName, "Protocol B (Tirzepatide 5mg)")
        XCTAssertNotNil(comp.cohensDEffectSize)
        XCTAssertTrue(comp.summaryConclusion.contains("Protocol B"))
    }

    // MARK: - 7. Raw Data Immutability Guarantee Test
    func testRawDataImmutabilityInvariant() {
        let originalDate = Date(timeIntervalSince1970: 1700000000)
        let originalMeasurement = Measurement(
            id: UUID(),
            name: "Body Weight",
            type: .weight,
            category: .bodyComposition,
            value: 185.5,
            unit: "lbs",
            dateRecorded: originalDate,
            source: .manualEntry,
            notes: "Morning fasted log"
        )

        let initialValue = originalMeasurement.value
        let initialUnit = originalMeasurement.unit
        let initialDate = originalMeasurement.dateRecorded
        let initialNotes = originalMeasurement.notes

        // Run engine calculations across multiple functions
        _ = engine.calculateCountSMA(points: [originalMeasurement], metricCode: "weight", windowSize: 3)
        _ = engine.calculateTimeWindowSMA(points: [originalMeasurement], metricCode: "weight", windowDays: 7)
        _ = engine.calculateEMA(points: [originalMeasurement], metricCode: "weight", windowDays: 14)
        _ = engine.calculateBaselineDifference(points: [originalMeasurement], metricName: "Weight", unit: "lbs")
        _ = engine.generateAnalyticsSummary(metric: .bodyWeight, measurements: [originalMeasurement])

        // Verify the original measurement is completely untouched and was never mutated
        XCTAssertEqual(originalMeasurement.value, initialValue)
        XCTAssertEqual(originalMeasurement.unit, initialUnit)
        XCTAssertEqual(originalMeasurement.dateRecorded, initialDate)
        XCTAssertEqual(originalMeasurement.notes, initialNotes)
    }

    // MARK: - 8. Built-in vs Custom Metrics Definition Tests
    func testBuiltInAndCustomMetricDefinitions() {
        let weight = MetricDefinition.builtIn(for: .weight)
        XCTAssertEqual(weight.name, "Body Weight")
        XCTAssertEqual(weight.defaultUnit, "lbs")
        XCTAssertEqual(weight.targetDirection, .decrease)
        XCTAssertFalse(weight.isCustom)

        let bp = MetricDefinition.builtIn(for: .bloodPressure)
        XCTAssertTrue(bp.allowsSecondaryValue)

        let customMetric = MetricDefinition.custom(
            name: "VO2 Max",
            category: .athletic,
            defaultUnit: "mL/kg/min",
            referenceRangeMin: 45.0,
            referenceRangeMax: 65.0,
            targetDirection: .increase,
            iconName: "figure.run",
            colorHex: "#10B981",
            metricDescription: "Cardiorespiratory aerobic fitness."
        )

        XCTAssertTrue(customMetric.isCustom)
        XCTAssertEqual(customMetric.name, "VO2 Max")
        XCTAssertEqual(customMetric.code, "custom_vo2_max")
        XCTAssertEqual(customMetric.defaultUnit, "mL/kg/min")
        XCTAssertEqual(customMetric.targetDirection, .increase)
    }
}
