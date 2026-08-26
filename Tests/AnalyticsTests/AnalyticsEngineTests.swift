import XCTest
import Domain
import CalculationEngine
@testable import Analytics

final class AnalyticsEngineTests: XCTestCase {

    var engine: AnalyticsEngine!

    override func setUp() {
        super.setUp()
        engine = AnalyticsEngine()
    }

    // MARK: - 1. Percentage Change Tests
    func testPercentageChangeCalculation() {
        let cal = Calendar.current
        let start = Date(timeIntervalSince1970: 1700000000)
        let end = cal.date(byAdding: .day, value: 14, to: start)!

        let p1 = GenericTimeSeriesPoint(timestamp: start, value: 200.0, unit: "lbs")
        let p2 = GenericTimeSeriesPoint(timestamp: end, value: 190.0, unit: "lbs")

        let result = engine.calculatePercentageChange(
            startPoint: p1,
            endPoint: p2,
            periodName: "14-Day Cut",
            targetDirection: .decrease
        )

        // Math: (190 - 200) / 200 * 100% = -5.0%
        XCTAssertEqual(result.startValue, 200.0)
        XCTAssertEqual(result.endValue, 190.0)
        XCTAssertEqual(result.absoluteDelta, -10.0, accuracy: 0.001)
        XCTAssertEqual(result.percentageChange, -5.0, accuracy: 0.001)
        XCTAssertEqual(result.ratePerWeek ?? 0, -5.0, accuracy: 0.001)
        XCTAssertEqual(result.trendDirection, .improving)
        XCTAssertEqual(result.formattedPercentage, "-5.0%")

        // Audit trail verification
        XCTAssertEqual(result.auditTrail.steps.count, 3)
        XCTAssertEqual(result.auditTrail.underlyingDataPoints.count, 2)
        XCTAssertEqual(result.auditTrail.formula.name, "Percentage Change & Rate of Change")
        XCTAssertFalse(result.auditTrail.humanReadableExplanation.isEmpty)
    }

    func testPercentageChangeZeroBaselineSafety() {
        let now = Date()
        let p1 = GenericTimeSeriesPoint(timestamp: now, value: 0.0, unit: "score")
        let p2 = GenericTimeSeriesPoint(timestamp: now.addingTimeInterval(86400), value: 10.0, unit: "score")

        let result = engine.calculatePercentageChange(startPoint: p1, endPoint: p2)
        // Zero start value should return 0.0 without division by zero crash
        XCTAssertEqual(result.percentageChange, 0.0)
        XCTAssertEqual(result.absoluteDelta, 10.0)
    }

    func testStandardPeriodPercentageChanges() {
        let cal = Calendar.current
        let now = Date()

        var points: [GenericTimeSeriesPoint] = []
        for i in 0..<30 {
            let dt = cal.date(byAdding: .day, value: i - 29, to: now)!
            points.append(GenericTimeSeriesPoint(timestamp: dt, value: 200.0 - Double(i), unit: "lbs"))
        }

        let changes = engine.calculateStandardPeriodChanges(points: points, targetDirection: .decrease, referenceDate: now)

        XCTAssertFalse(changes.isEmpty)
        let overall = changes.first(where: { $0.periodName.contains("Overall") })
        XCTAssertNotNil(overall)
        XCTAssertEqual(overall?.startValue, 200.0)
        XCTAssertEqual(overall?.endValue, 171.0)
        XCTAssertEqual(overall?.absoluteDelta, -29.0, accuracy: 0.01)
    }

    // MARK: - 2. Absolute Change Tests
    func testAbsoluteChangeCalculation() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let end = Date(timeIntervalSince1970: 1700000000 + 86400 * 7)

        let p1 = GenericTimeSeriesPoint(timestamp: start, value: 100.0, unit: "mg/dL")
        let p2 = GenericTimeSeriesPoint(timestamp: end, value: 85.0, unit: "mg/dL")

        let absChange = engine.calculateAbsoluteChange(startPoint: p1, endPoint: p2, periodName: "Fasting Week")

        XCTAssertEqual(absChange.delta, -15.0, accuracy: 0.001)
        XCTAssertEqual(absChange.unit, "mg/dL")
        XCTAssertEqual(absChange.ratePerWeek ?? 0, -15.0, accuracy: 0.001)
        XCTAssertEqual(absChange.formattedDelta, "-15.0 mg/dL")
        XCTAssertEqual(absChange.auditTrail.steps.count, 1)
    }

    // MARK: - 3. Deterministic Averages & Statistical Moments Tests
    func testAveragesAndStatisticalMoments() {
        let now = Date()
        // Data: [10, 20, 30, 40, 50]
        // Sum = 150, Mean = 30, Median = 30
        // Variance = ((10-30)^2 + (20-30)^2 + (30-30)^2 + (40-30)^2 + (50-30)^2) / 4 = (400+100+0+100+400)/4 = 1000/4 = 250
        // Std Dev = sqrt(250) ≈ 15.811
        let points = [10.0, 20.0, 30.0, 40.0, 50.0].enumerated().map { i, val in
            GenericTimeSeriesPoint(timestamp: now.addingTimeInterval(Double(i * 3600)), value: val, unit: "bpm")
        }

        let averages = engine.calculateAverages(points: points, metricName: "Heart Rate", unit: "bpm")

        XCTAssertNotNil(averages)
        guard let avg = averages else { return }

        XCTAssertEqual(avg.sampleCount, 5)
        XCTAssertEqual(avg.arithmeticMean, 30.0, accuracy: 0.001)
        XCTAssertEqual(avg.median, 30.0, accuracy: 0.001)
        XCTAssertEqual(avg.variance, 250.0, accuracy: 0.001)
        XCTAssertEqual(avg.standardDeviation, sqrt(250.0), accuracy: 0.001)
        XCTAssertEqual(avg.standardError, sqrt(250.0) / sqrt(5.0), accuracy: 0.001)
        XCTAssertNotNil(avg.geometricMean)

        // Audit Trail check
        XCTAssertEqual(avg.auditTrail.steps.count, 4)
        XCTAssertEqual(avg.auditTrail.underlyingDataPoints.count, 5)
    }

    func testEvenCountMedian() {
        let now = Date()
        // [10, 20, 30, 40] -> Median is (20+30)/2 = 25
        let points = [10.0, 20.0, 30.0, 40.0].enumerated().map { i, val in
            GenericTimeSeriesPoint(timestamp: now.addingTimeInterval(Double(i * 3600)), value: val, unit: "lbs")
        }

        let averages = engine.calculateAverages(points: points, metricName: "Weight", unit: "lbs")
        XCTAssertEqual(averages?.median, 25.0, accuracy: 0.001)
    }

    // MARK: - 4. Rolling Averages (SMA & EMA) Tests
    func testRollingAveragesSMAandEMA() {
        let cal = Calendar.current
        let now = Date()

        var points: [GenericTimeSeriesPoint] = []
        for i in 0..<7 {
            let dt = cal.date(byAdding: .day, value: i - 6, to: now)!
            points.append(GenericTimeSeriesPoint(timestamp: dt, value: Double((i + 1) * 10), unit: "mg"))
        }

        // Count-based SMA (window = 3)
        let countSMA = engine.calculateCountSMA(points: points, metricCode: "dose", windowSize: 3)
        XCTAssertEqual(countSMA.points.count, 7)
        XCTAssertEqual(countSMA.points[0].movingAverage, 10.0) // [10]
        XCTAssertEqual(countSMA.points[1].movingAverage, 15.0) // [10, 20]
        XCTAssertEqual(countSMA.points[2].movingAverage, 20.0) // [10, 20, 30]
        XCTAssertEqual(countSMA.points[6].movingAverage, 60.0) // [50, 60, 70]
        XCTAssertNotNil(countSMA.points[6].upperBand)
        XCTAssertNotNil(countSMA.points[6].lowerBand)

        // Time-window SMA (7 days)
        let timeSMA = engine.calculateTimeWindowSMA(points: points, metricCode: "dose", windowDays: 7)
        XCTAssertEqual(timeSMA.points.count, 7)
        XCTAssertEqual(timeSMA.points.last?.movingAverage, 40.0, accuracy: 0.001) // Average of all 7 days: (10..70)/7 = 40

        // Exponential Moving Average (EMA)
        let ema = engine.calculateEMA(points: points, metricCode: "dose", windowDays: 7)
        XCTAssertEqual(ema.points.count, 7)
        XCTAssertEqual(ema.points.first?.movingAverage, 10.0)
        XCTAssertGreaterThan(ema.points.last?.movingAverage ?? 0, 45.0)
    }

    // MARK: - 5. Minimum / Maximum & Percentiles Tests
    func testMinMaxAndPercentiles() {
        let now = Date()
        let rawValues = [100.0, 105.0, 95.0, 110.0, 90.0, 115.0, 85.0, 120.0, 80.0, 125.0]

        let points = rawValues.enumerated().map { i, val in
            GenericTimeSeriesPoint(timestamp: now.addingTimeInterval(Double(i * 86400)), value: val, unit: "lbs")
        }

        let minMax = engine.calculateMinMax(points: points, metricName: "Weight", unit: "lbs")

        XCTAssertNotNil(minMax)
        guard let mm = minMax else { return }

        XCTAssertEqual(mm.sampleCount, 10)
        XCTAssertEqual(mm.minValue, 80.0)
        XCTAssertEqual(mm.maxValue, 125.0)
        XCTAssertEqual(mm.rangeSpan, 45.0) // 125 - 80
        XCTAssertEqual(mm.p50Median, 102.5, accuracy: 0.1) // Sorted: 80, 85, 90, 95, 100, 105, 110, 115, 120, 125 -> Mid is (100+105)/2 = 102.5
        XCTAssertNotNil(mm.p25Value)
        XCTAssertNotNil(mm.p75Value)
        XCTAssertNotNil(mm.interquartileRange)

        // Audit Trail check
        XCTAssertEqual(mm.auditTrail.underlyingDataPoints.count, 2)
        XCTAssertEqual(mm.auditTrail.steps.count, 3)
    }

    // MARK: - 6. Protocol Adherence & Streaks Tests
    func testDeterministicAdherenceAndStreaks() {
        let cal = Calendar.current
        let now = Date()
        let bpcId = UUID()

        var doseLogs: [DoseLog] = []

        // 10 scheduled doses: 8 taken, 1 skipped, 1 missed (80% adherence)
        // Last 5 days consecutive taken (streak = 5)
        for i in 0..<10 {
            let dt = cal.date(byAdding: .day, value: i - 9, to: now)!
            let status: DoseEventStatus
            if i == 0 { status = .missed }
            else if i == 1 { status = .skipped }
            else { status = .taken }

            doseLogs.append(
                DoseLog(
                    compoundId: bpcId,
                    compoundName: "BPC-157",
                    scheduledDate: dt,
                    loggedDate: status == .taken ? dt.addingTimeInterval(1800) : nil, // 30 mins variance
                    doseAmount: 250,
                    doseUnit: .mcg,
                    status: status
                )
            )
        }

        let adherence = engine.calculateAdherence(doseLogs: doseLogs, toleranceMinutes: 120, calendar: cal)

        XCTAssertEqual(adherence.totalScheduledDoses, 10)
        XCTAssertEqual(adherence.totalTakenDoses, 8)
        XCTAssertEqual(adherence.totalSkippedDoses, 1)
        XCTAssertEqual(adherence.totalMissedDoses, 1)
        XCTAssertEqual(adherence.overallAdherencePercentage, 80.0, accuracy: 0.001)
        XCTAssertEqual(adherence.onTimePercentage, 100.0) // 30 min variance is within 120 min tolerance
        XCTAssertEqual(adherence.currentStreakDays, 8)
        XCTAssertEqual(adherence.compoundBreakdown["BPC-157"] ?? 0, 80.0, accuracy: 0.001)

        // Audit Trail check
        XCTAssertFalse(adherence.auditTrail.humanReadableExplanation.isEmpty)
        XCTAssertEqual(adherence.auditTrail.steps.count, 3)
    }

    // MARK: - 7. Period Comparisons & Cohen's d Tests
    func testPeriodComparisonsAndEffectSize() {
        let cal = Calendar.current
        let now = Date()

        let startA = cal.date(byAdding: .day, value: -60, to: now)!
        let endA = cal.date(byAdding: .day, value: -31, to: now)!

        let startB = cal.date(byAdding: .day, value: -30, to: now)!
        let endB = now

        var points: [GenericTimeSeriesPoint] = []

        // Period A: 200 -> 195 (5 lbs loss)
        for i in 0..<30 {
            let dt = cal.date(byAdding: .day, value: i, to: startA)!
            points.append(GenericTimeSeriesPoint(timestamp: dt, value: 200.0 - (Double(i) * 0.166), unit: "lbs"))
        }

        // Period B: 195 -> 183 (12 lbs loss)
        for i in 0..<30 {
            let dt = cal.date(byAdding: .day, value: i, to: startB)!
            points.append(GenericTimeSeriesPoint(timestamp: dt, value: 195.0 - (Double(i) * 0.4), unit: "lbs"))
        }

        let comparison = engine.comparePeriods(
            points: points,
            periodA: (id: UUID(), name: "Protocol A", interval: DateInterval(start: startA, end: endA)),
            periodB: (id: UUID(), name: "Protocol B", interval: DateInterval(start: startB, end: endB)),
            metricDefinition: .bodyWeight
        )

        XCTAssertNotNil(comparison)
        guard let comp = comparison else { return }

        XCTAssertEqual(comp.periodAName, "Protocol A")
        XCTAssertEqual(comp.periodBName, "Protocol B")
        XCTAssertEqual(comp.superiorPeriodName, "Protocol B")
        XCTAssertNotNil(comp.cohensDEffectSize)
        XCTAssertTrue(comp.summaryConclusion.contains("Protocol B"))
        XCTAssertEqual(comp.auditTrail.steps.count, 2)
    }

    // MARK: - 8. Baseline Difference Tests
    func testBaselineDifferenceCalculations() {
        let cal = Calendar.current
        let now = Date()

        let baseDt = cal.date(byAdding: .day, value: -30, to: now)!
        let p1 = GenericTimeSeriesPoint(timestamp: baseDt, value: 100.0, unit: "mg/dL")
        let p2 = GenericTimeSeriesPoint(timestamp: cal.date(byAdding: .day, value: -15, to: now)!, value: 90.0, unit: "mg/dL")
        let p3 = GenericTimeSeriesPoint(timestamp: now, value: 80.0, unit: "mg/dL")

        let baseResult = engine.calculateBaselineDifference(
            points: [p1, p2, p3],
            metricName: "Fasting Glucose",
            unit: "mg/dL",
            baselineMode: .firstRecorded,
            targetValue: 80.0,
            targetDirection: .decrease
        )

        XCTAssertNotNil(baseResult)
        guard let b = baseResult else { return }

        XCTAssertEqual(b.baselineValue, 100.0)
        XCTAssertEqual(b.currentValue, 80.0)
        XCTAssertEqual(b.absoluteDifference, -20.0, accuracy: 0.001)
        XCTAssertEqual(b.percentageDifference, -20.0, accuracy: 0.001)
        XCTAssertTrue(b.isTargetAchieved)
        XCTAssertEqual(b.evaluationStatus, .targetReached)
        XCTAssertEqual(b.targetAttainmentPercentage ?? 0, 100.0, accuracy: 0.001)
        XCTAssertNotNil(b.zScore)
    }

    // MARK: - 9. Trend Direction with Linear Regression Tests
    func testTrendDirectionWithLinearRegression() {
        let cal = Calendar.current
        let now = Date()

        // 10 days of steady downward progression: 100, 98, 96, 94, 92, 90, 88, 86, 84, 82
        var points: [GenericTimeSeriesPoint] = []
        for i in 0..<10 {
            let dt = cal.date(byAdding: .day, value: i - 9, to: now)!
            points.append(GenericTimeSeriesPoint(timestamp: dt, value: 100.0 - (Double(i) * 2.0), unit: "lbs"))
        }

        let trend = engine.calculateTrendDirection(
            points: points,
            metricName: "Weight",
            targetDirection: .decrease
        )

        XCTAssertNotNil(trend)
        guard let t = trend else { return }

        // Slope is -2.0 lbs/day = -14.0 lbs/week
        XCTAssertEqual(t.linearSlopePerDay, -2.0, accuracy: 0.01)
        XCTAssertEqual(t.linearSlopePerWeek, -14.0, accuracy: 0.01)
        XCTAssertEqual(t.trendDirection, .improving) // Decrease target + negative slope = improving
        XCTAssertNotNil(t.mannKendallS)
        XCTAssertLessThan(t.mannKendallS ?? 0, 0) // Monotonically decreasing -> negative S
    }

    // MARK: - 10. Dose / Event Alignment Tests
    func testDoseEventAlignmentAndResponseWindows() {
        let cal = Calendar.current
        let now = Date()
        let bpcId = UUID()

        var doses: [DoseLog] = []
        var measurements: [Measurement] = []

        // Day 1: Pre-dose measurement (Pain = 8)
        // Day 1 at 12:00: Dose taken
        // Day 1 at 18:00 (6h post-dose): Measurement (Pain = 5)
        // Day 2 at 12:00 (24h post-dose): Measurement (Pain = 4)
        let day1Dose = cal.date(byAdding: .day, value: -2, to: now)!
        let preMDate = day1Dose.addingTimeInterval(-3600 * 4) // 4h pre-dose
        let post24MDate = day1Dose.addingTimeInterval(3600 * 12) // 12h post-dose

        doses.append(
            DoseLog(
                compoundId: bpcId,
                compoundName: "BPC-157",
                scheduledDate: day1Dose,
                loggedDate: day1Dose,
                status: .taken,
                doseAmount: 250,
                doseUnit: .mcg
            )
        )

        measurements.append(Measurement(name: "Pain", type: .pain, value: 8.0, unit: "/10", dateRecorded: preMDate))
        measurements.append(Measurement(name: "Pain", type: .pain, value: 4.0, unit: "/10", dateRecorded: post24MDate))

        let alignment = engine.calculateDoseEventAlignment(
            measurements: measurements,
            doseLogs: doses,
            metricName: "Pain",
            calendar: cal
        )

        XCTAssertEqual(alignment.totalAlignedEventsCount, 3)
        XCTAssertEqual(alignment.averagePreDoseValue ?? 0, 8.0, accuracy: 0.01)
        XCTAssertEqual(alignment.averagePostDose24hValue ?? 0, 4.0, accuracy: 0.01)
        XCTAssertEqual(alignment.acutePostDoseDelta ?? 0, -4.0, accuracy: 0.01)
        XCTAssertFalse(alignment.alignmentSummaryText.isEmpty)
        XCTAssertEqual(alignment.auditTrail.formula.name, "Dose & Event Temporal Proximity Alignment")
    }

    // MARK: - 11. Cost Metrics Tests
    func testCostMetricsAndBurnRate() {
        let now = Date()
        let costs = [
            CostEvent(title: "BPC-157 Vial (5mg)", category: .peptideVial, amountUsd: 60.0, dateIncurred: now),
            CostEvent(title: "Insulin Syringes (100ct)", category: .medicalSupplies, amountUsd: 20.0, dateIncurred: now),
            CostEvent(title: "Comprehensive Lab Panel", category: .bloodwork, amountUsd: 120.0, dateIncurred: now)
        ]

        let doses = [
            DoseLog(compoundId: UUID(), compoundName: "BPC-157", scheduledDate: now, loggedDate: now, status: .taken, doseAmount: 250),
            DoseLog(compoundId: UUID(), compoundName: "BPC-157", scheduledDate: now, loggedDate: now, status: .taken, doseAmount: 250),
            DoseLog(compoundId: UUID(), compoundName: "BPC-157", scheduledDate: now, loggedDate: now, status: .taken, doseAmount: 250),
            DoseLog(compoundId: UUID(), compoundName: "BPC-157", scheduledDate: now, loggedDate: now, status: .taken, doseAmount: 250)
        ]

        let costMetrics = engine.calculateCostMetrics(costs: costs, doses: doses, elapsedDays: 20, currencyCode: "USD")

        // Total = 60 + 20 + 120 = 200 USD
        // Daily burn = 200 / 20 = 10 USD/day
        // Cost per taken dose = 200 / 4 = 50 USD/dose
        XCTAssertEqual(costMetrics.totalSpend, 200.0, accuracy: 0.001)
        XCTAssertEqual(costMetrics.dailyBurnRate, 10.0, accuracy: 0.001)
        XCTAssertEqual(costMetrics.costPerTakenDose, 50.0, accuracy: 0.001)
        XCTAssertEqual(costMetrics.categoryBreakdown[.peptideVial] ?? 0, 60.0)
        XCTAssertEqual(costMetrics.categoryBreakdown[.medicalSupplies] ?? 0, 20.0)
        XCTAssertEqual(costMetrics.categoryBreakdown[.bloodwork] ?? 0, 120.0)

        // Audit Trail check
        XCTAssertEqual(costMetrics.auditTrail.steps.count, 3)
        XCTAssertEqual(costMetrics.auditTrail.underlyingDataPoints.count, 3)
    }

    // MARK: - 12. Master Analytics Report Synthesis & Immutability Test
    func testMasterAnalyticsReportSynthesisAndImmutability() {
        let cal = Calendar.current
        let now = Date()
        let protoId = UUID()
        let bpcId = UUID()

        var measurements: [Measurement] = []
        var doses: [DoseLog] = []

        for i in 0..<14 {
            let dt = cal.date(byAdding: .day, value: i - 13, to: now)!
            let val = 190.0 - (Double(i) * 0.5)
            measurements.append(
                Measurement(
                    name: "Body Weight",
                    type: .weight,
                    category: .bodyComposition,
                    value: val,
                    unit: "lbs",
                    dateRecorded: dt,
                    associatedProtocolId: protoId
                )
            )
            doses.append(
                DoseLog(
                    compoundId: bpcId,
                    compoundName: "BPC-157",
                    scheduledDate: dt,
                    loggedDate: dt,
                    status: .taken,
                    associatedProtocolId: protoId,
                    doseAmount: 250
                )
            )
        }

        let originalValues = measurements.map(\.value)
        let originalDates = measurements.map(\.dateRecorded)

        let report = engine.generateMasterAnalytics(
            metric: .bodyWeight,
            measurements: measurements,
            doseLogs: doses,
            protocols: [ProtocolModel(id: protoId, name: "Cutting Protocol", status: .active, startDate: measurements.first!.dateRecorded)],
            costs: [CostEvent(title: "BPC-157", category: .peptideVial, amountUsd: 50.0)]
        )

        // Verify synthesis
        XCTAssertEqual(report.rawMeasurementsCount, 14)
        XCTAssertNotNil(report.percentageChange)
        XCTAssertNotNil(report.absoluteChange)
        XCTAssertNotNil(report.averages)
        XCTAssertEqual(report.rollingAverages.count, 3) // SMA7, SMA30, EMA14
        XCTAssertNotNil(report.minMax)
        XCTAssertNotNil(report.adherence)
        XCTAssertNotNil(report.baselineDifference)
        XCTAssertNotNil(report.trendDirection)
        XCTAssertNotNil(report.doseEventAlignment)
        XCTAssertNotNil(report.costMetrics)

        // Verify raw data immutability guarantee: raw data was never mutated
        XCTAssertEqual(measurements.map(\.value), originalValues)
        XCTAssertEqual(measurements.map(\.dateRecorded), originalDates)
    }
}
