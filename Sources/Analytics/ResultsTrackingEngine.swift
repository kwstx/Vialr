import Foundation
import Domain
import CalculationEngine

public typealias Measurement = Domain.Measurement

/// High-performance analytics and statistical computation engine for longitudinal results tracking.
/// Computes moving averages, percentage changes, baseline comparisons, adherence correlations,
/// and protocol-period comparisons without ever mutating or overwriting raw measurement data.
public struct ResultsTrackingEngine: Sendable {

    public init() {}

    // MARK: - 1. Moving Average Calculations

    /// Computes a count-based Simple Moving Average (SMA) over a sliding window of `windowSize` data points.
    public func calculateCountSMA<P: TimeSeriesDataPoint>(
        points: [P],
        metricCode: String = "metric",
        windowSize: Int = 7
    ) -> MovingAverageSeries {
        let sorted = points.sorted(by: { $0.timestamp < $1.timestamp })
        guard !sorted.isEmpty, windowSize > 0 else {
            return MovingAverageSeries(metricCode: metricCode, windowDays: windowSize, calculationType: .simple, points: [])
        }

        var smoothedPoints: [MovingAveragePoint] = []
        for i in 0..<sorted.count {
            let startIdx = max(0, i - windowSize + 1)
            let window = sorted[startIdx...i]
            let values = window.map(\.value)
            let count = values.count
            let avg = values.reduce(0.0, +) / Double(count)

            var stdDev: Double? = nil
            if count > 1 {
                let sumSq = values.reduce(0.0) { $0 + pow($1 - avg, 2) }
                stdDev = sqrt(sumSq / Double(count - 1))
            }

            let currentPoint = sorted[i]
            let upper = stdDev.map { avg + 2.0 * $0 }
            let lower = stdDev.map { avg - 2.0 * $0 }

            smoothedPoints.append(
                MovingAveragePoint(
                    timestamp: currentPoint.timestamp,
                    rawValue: currentPoint.value,
                    movingAverage: avg,
                    standardDeviation: stdDev,
                    upperBand: upper,
                    lowerBand: lower,
                    sampleCountInWindow: count
                )
            )
        }

        return MovingAverageSeries(
            metricCode: metricCode,
            windowDays: windowSize,
            calculationType: .simple,
            points: smoothedPoints
        )
    }

    /// Computes a calendar-time-window moving average (e.g. 7-Day, 14-Day, 30-Day SMA),
    /// properly handling sparse, missing, or irregular daily measurement logs.
    public func calculateTimeWindowSMA<P: TimeSeriesDataPoint>(
        points: [P],
        metricCode: String = "metric",
        windowDays: Int = 7,
        calendar: Calendar = .current
    ) -> MovingAverageSeries {
        let sorted = points.sorted(by: { $0.timestamp < $1.timestamp })
        guard !sorted.isEmpty, windowDays > 0 else {
            return MovingAverageSeries(metricCode: metricCode, windowDays: windowDays, calculationType: .timeWeighted, points: [])
        }

        var smoothedPoints: [MovingAveragePoint] = []
        let windowSeconds = Double(windowDays) * 86400.0

        for currentPoint in sorted {
            let cutoff = currentPoint.timestamp.addingTimeInterval(-windowSeconds)
            let windowPoints = sorted.filter { $0.timestamp >= cutoff && $0.timestamp <= currentPoint.timestamp }
            let values = windowPoints.map(\.value)
            let count = values.count
            let avg = count > 0 ? (values.reduce(0.0, +) / Double(count)) : currentPoint.value

            var stdDev: Double? = nil
            if count > 1 {
                let sumSq = values.reduce(0.0) { $0 + pow($1 - avg, 2) }
                stdDev = sqrt(sumSq / Double(count - 1))
            }

            let upper = stdDev.map { avg + 2.0 * $0 }
            let lower = stdDev.map { avg - 2.0 * $0 }

            smoothedPoints.append(
                MovingAveragePoint(
                    timestamp: currentPoint.timestamp,
                    rawValue: currentPoint.value,
                    movingAverage: avg,
                    standardDeviation: stdDev,
                    upperBand: upper,
                    lowerBand: lower,
                    sampleCountInWindow: count
                )
            )
        }

        return MovingAverageSeries(
            metricCode: metricCode,
            windowDays: windowDays,
            calculationType: .timeWeighted,
            points: smoothedPoints
        )
    }

    /// Computes an Exponential Moving Average (EMA) with optional custom smoothing factor $\alpha$.
    public func calculateEMA<P: TimeSeriesDataPoint>(
        points: [P],
        metricCode: String = "metric",
        windowDays: Int = 14,
        smoothingAlpha: Double? = nil
    ) -> MovingAverageSeries {
        let sorted = points.sorted(by: { $0.timestamp < $1.timestamp })
        guard !sorted.isEmpty else {
            return MovingAverageSeries(metricCode: metricCode, windowDays: windowDays, calculationType: .exponential, points: [])
        }

        let alpha = smoothingAlpha ?? (2.0 / (Double(max(2, windowDays)) + 1.0))
        var smoothedPoints: [MovingAveragePoint] = []
        var runningEMA = sorted[0].value

        for (i, p) in sorted.enumerated() {
            if i == 0 {
                runningEMA = p.value
            } else {
                runningEMA = (alpha * p.value) + ((1.0 - alpha) * runningEMA)
            }

            smoothedPoints.append(
                MovingAveragePoint(
                    timestamp: p.timestamp,
                    rawValue: p.value,
                    movingAverage: runningEMA,
                    sampleCountInWindow: i + 1
                )
            )
        }

        return MovingAverageSeries(
            metricCode: metricCode,
            windowDays: windowDays,
            calculationType: .exponential,
            points: smoothedPoints
        )
    }

    // MARK: - 2. Percentage Change Calculations

    /// Computes the percentage and absolute change between two explicit points or timestamps.
    public func calculatePercentageChange(
        startValue: Double,
        endValue: Double,
        startDate: Date,
        endDate: Date,
        periodName: String = "Observation Period",
        targetDirection: TargetDirection = .decrease
    ) -> PercentageChangeResult {
        let delta = endValue - startValue
        let pct = startValue != 0 ? ((delta / abs(startValue)) * 100.0) : 0.0

        let days = max(1.0, endDate.timeIntervalSince(startDate) / 86400.0)
        let weeks = days / 7.0
        let ratePerWeek = delta / weeks

        let trend: AnalyticsTrendDirection
        switch targetDirection {
        case .decrease:
            if pct < -0.5 { trend = .improving }
            else if pct > 0.5 { trend = .regressing }
            else { trend = .stable }
        case .increase:
            if pct > 0.5 { trend = .improving }
            else if pct < -0.5 { trend = .regressing }
            else { trend = .stable }
        case .maintain:
            trend = abs(pct) <= 3.0 ? .improving : .regressing
        }

        return PercentageChangeResult(
            periodName: periodName,
            startDate: startDate,
            endDate: endDate,
            startValue: startValue,
            endValue: endValue,
            absoluteDelta: delta,
            percentageChange: pct,
            ratePerWeek: ratePerWeek,
            trendDirection: trend
        )
    }

    /// Generates standard multi-period percentage change comparisons:
    /// Overall, Last 7 Days, Last 14 Days, Last 30 Days, and Month-over-Month.
    public func calculateStandardPeriodChanges<P: TimeSeriesDataPoint>(
        points: [P],
        targetDirection: TargetDirection = .decrease,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [PercentageChangeResult] {
        let sorted = points.sorted(by: { $0.timestamp < $1.timestamp })
        guard sorted.count >= 2,
              let first = sorted.first,
              let last = sorted.last else {
            return []
        }

        var results: [PercentageChangeResult] = []

        // 1. Overall change since first log
        results.append(
            calculatePercentageChange(
                startValue: first.value,
                endValue: last.value,
                startDate: first.timestamp,
                endDate: last.timestamp,
                periodName: "Overall (Since Start)",
                targetDirection: targetDirection
            )
        )

        // Helper for fixed day intervals
        func addWindowResult(days: Int, name: String) {
            guard let cutoff = calendar.date(byAdding: .day, value: -days, to: referenceDate) else { return }
            let windowPoints = sorted.filter { $0.timestamp >= cutoff && $0.timestamp <= referenceDate }
            if windowPoints.count >= 2, let wFirst = windowPoints.first, let wLast = windowPoints.last {
                results.append(
                    calculatePercentageChange(
                        startValue: wFirst.value,
                        endValue: wLast.value,
                        startDate: wFirst.timestamp,
                        endDate: wLast.timestamp,
                        periodName: name,
                        targetDirection: targetDirection
                    )
                )
            }
        }

        addWindowResult(days: 7, name: "Last 7 Days")
        addWindowResult(days: 14, name: "Last 14 Days")
        addWindowResult(days: 30, name: "Last 30 Days")
        addWindowResult(days: 90, name: "Last 90 Days")

        return results
    }

    // MARK: - 3. Baseline Difference Calculations

    public enum BaselineMode: Sendable {
        case firstRecorded
        case preProtocolAverage(days: Int)
        case explicitValue(Double, date: Date)
    }

    /// Evaluates current metric performance, deviations, and z-score against a baseline.
    public func calculateBaselineDifference<P: TimeSeriesDataPoint>(
        points: [P],
        metricName: String,
        unit: String,
        baselineMode: BaselineMode = .firstRecorded,
        targetValue: Double? = nil,
        targetDirection: TargetDirection = .decrease
    ) -> BaselineDifferenceResult? {
        let sorted = points.sorted(by: { $0.timestamp < $1.timestamp })
        guard let latest = sorted.last else { return nil }

        let baselineVal: Double
        let baselineDt: Date
        let baselineSrc: BaselineSourceType

        switch baselineMode {
        case .firstRecorded:
            guard let first = sorted.first else { return nil }
            baselineVal = first.value
            baselineDt = first.timestamp
            baselineSrc = .firstRecorded

        case .preProtocolAverage(let days):
            guard let first = sorted.first else { return nil }
            let cutoff = first.timestamp.addingTimeInterval(Double(days) * 86400.0)
            let basePoints = sorted.filter { $0.timestamp <= cutoff }
            let vals = basePoints.map(\.value)
            baselineVal = vals.isEmpty ? first.value : (vals.reduce(0.0, +) / Double(vals.count))
            baselineDt = first.timestamp
            baselineSrc = .preProtocolWindowAverage

        case .explicitValue(let val, let dt):
            baselineVal = val
            baselineDt = dt
            baselineSrc = .userSpecifiedTarget
        }

        let delta = latest.value - baselineVal
        let pct = baselineVal != 0 ? ((delta / abs(baselineVal)) * 100.0) : 0.0

        // Z-Score relative to overall standard deviation
        var zScore: Double? = nil
        if sorted.count > 2 {
            let mean = sorted.map(\.value).reduce(0.0, +) / Double(sorted.count)
            let sumSq = sorted.map(\.value).reduce(0.0) { $0 + pow($1 - mean, 2) }
            let stdDev = sqrt(sumSq / Double(sorted.count - 1))
            if stdDev > 0.0001 {
                zScore = (latest.value - baselineVal) / stdDev
            }
        }

        // Goal Attainment
        var attainmentPct: Double? = nil
        var isAchieved = false
        if let target = targetValue {
            let totalNeeded = target - baselineVal
            if totalNeeded != 0 {
                let progress = ((latest.value - baselineVal) / totalNeeded) * 100.0
                attainmentPct = max(0.0, progress)
            }

            switch targetDirection {
            case .decrease:
                isAchieved = latest.value <= target
            case .increase:
                isAchieved = latest.value >= target
            case .maintain:
                isAchieved = abs(latest.value - target) <= (abs(target) * 0.05)
            }
        }

        // Clinical Evaluation Status
        let status: MetricEvaluationStatus
        if isAchieved {
            status = .targetReached
        } else if abs(delta) < 0.001 {
            status = .stalled
        } else {
            switch targetDirection {
            case .decrease:
                status = delta < 0 ? .onTrack : .regressing
            case .increase:
                status = delta > 0 ? .onTrack : .regressing
            case .maintain:
                status = abs(delta) <= (abs(baselineVal) * 0.05) ? .onTrack : .regressing
            }
        }

        return BaselineDifferenceResult(
            metricName: metricName,
            unit: unit,
            baselineValue: baselineVal,
            baselineDate: baselineDt,
            baselineSource: baselineSrc,
            currentValue: latest.value,
            currentDate: latest.timestamp,
            absoluteDifference: delta,
            percentageDifference: pct,
            zScore: zScore,
            targetValue: targetValue,
            targetAttainmentPercentage: attainmentPct,
            isTargetAchieved: isAchieved,
            evaluationStatus: status
        )
    }

    // MARK: - 4. Adherence Relationship Calculations

    /// Computes statistical correlations and clinical relationships between protocol dose adherence and metric outcomes.
    public func calculateAdherenceRelationship(
        measurements: [Measurement],
        doseLogs: [DoseLog],
        metricDefinition: MetricDefinition,
        calendar: Calendar = .current
    ) -> AdherenceRelationshipResult? {
        guard !measurements.isEmpty, !doseLogs.isEmpty else { return nil }

        let sortedM = measurements.sorted(by: { $0.timestamp < $1.timestamp })
        let sortedD = doseLogs.sorted(by: { ($0.loggedDate ?? $0.scheduledDate) < ($1.loggedDate ?? $1.scheduledDate) })

        guard let firstDate = sortedM.first?.timestamp,
              let lastDate = sortedM.last?.timestamp,
              lastDate.timeIntervalSince(firstDate) >= 86400.0 * 7.0 else {
            // Under 1 week of data - return early with basic counts
            let taken = sortedD.filter { $0.status == .taken }.count
            let missed = sortedD.filter { $0.status == .missed }.count
            let total = max(1, taken + missed)
            let overallPct = (Double(taken) / Double(total)) * 100.0

            return AdherenceRelationshipResult(
                metricCode: metricDefinition.code,
                metricName: metricDefinition.name,
                overallAdherencePercentage: overallPct,
                adherentDaysCount: taken,
                missedDaysCount: missed,
                clinicalInsight: "Collecting initial baseline protocol adherence data."
            )
        }

        // Group into weekly buckets
        var weekAdherencePairs: [(adherencePct: Double, metricAvg: Double)] = []
        var currentWeekStart = firstDate

        while currentWeekStart < lastDate {
            guard let currentWeekEnd = calendar.date(byAdding: .day, value: 7, to: currentWeekStart) else { break }

            let weekDoses = sortedD.filter {
                let d = $0.loggedDate ?? $0.scheduledDate
                return d >= currentWeekStart && d < currentWeekEnd
            }
            let weekMeasurements = sortedM.filter { $0.timestamp >= currentWeekStart && $0.timestamp < currentWeekEnd }

            if !weekDoses.isEmpty && !weekMeasurements.isEmpty {
                let taken = weekDoses.filter { $0.status == .taken }.count
                let total = max(1, weekDoses.count)
                let adhRate = (Double(taken) / Double(total)) * 100.0
                let mAvg = weekMeasurements.map(\.value).reduce(0.0, +) / Double(weekMeasurements.count)

                weekAdherencePairs.append((adherencePct: adhRate, metricAvg: mAvg))
            }

            currentWeekStart = currentWeekEnd
        }

        let takenCount = sortedD.filter { $0.status == .taken }.count
        let missedCount = sortedD.filter { $0.status == .missed }.count
        let totalDoses = max(1, takenCount + missedCount)
        let overallAdherence = (Double(takenCount) / Double(totalDoses)) * 100.0

        guard !weekAdherencePairs.isEmpty else {
            return AdherenceRelationshipResult(
                metricCode: metricDefinition.code,
                metricName: metricDefinition.name,
                overallAdherencePercentage: overallAdherence,
                adherentDaysCount: takenCount,
                missedDaysCount: missedCount,
                clinicalInsight: "Adherence is currently \(Int(overallAdherence))% across all recorded doses."
            )
        }

        // Calculate High Adherence (>=80%) vs Low Adherence (<80%) cohorts
        let highCohort = weekAdherencePairs.filter { $0.adherencePct >= 80.0 }.map(\.metricAvg)
        let lowCohort = weekAdherencePairs.filter { $0.adherencePct < 80.0 }.map(\.metricAvg)

        let highAvg = !highCohort.isEmpty ? (highCohort.reduce(0.0, +) / Double(highCohort.count)) : nil
        let lowAvg = !lowCohort.isEmpty ? (lowCohort.reduce(0.0, +) / Double(lowCohort.count)) : nil
        let delta = (highAvg != nil && lowAvg != nil) ? (highAvg! - lowAvg!) : nil

        // Pearson Correlation Coefficient between Adherence and Metric Level
        var r: Double? = nil
        if weekAdherencePairs.count >= 3 {
            let meanAdh = weekAdherencePairs.map(\.adherencePct).reduce(0.0, +) / Double(weekAdherencePairs.count)
            let meanMet = weekAdherencePairs.map(\.metricAvg).reduce(0.0, +) / Double(weekAdherencePairs.count)

            var numerator = 0.0
            var denomAdh = 0.0
            var denomMet = 0.0

            for pair in weekAdherencePairs {
                let diffAdh = pair.adherencePct - meanAdh
                let diffMet = pair.metricAvg - meanMet
                numerator += diffAdh * diffMet
                denomAdh += diffAdh * diffAdh
                denomMet += diffMet * diffMet
            }

            let denom = sqrt(denomAdh * denomMet)
            if denom > 0.0001 {
                r = max(-1.0, min(1.0, numerator / denom))
            }
        }

        // Generate clinical insight text
        let insight: String
        if let h = highAvg, let l = lowAvg, let d = delta {
            let dStr = String(format: "%.1f", abs(d))
            if metricDefinition.targetDirection == .decrease && d < 0 {
                insight = "High adherence (≥80%) correlated with a \(dStr) \(metricDefinition.defaultUnit) greater reduction compared to lower adherence weeks."
            } else if metricDefinition.targetDirection == .increase && d > 0 {
                insight = "High adherence (≥80%) produced a +\(dStr) \(metricDefinition.defaultUnit) higher average outcome score."
            } else {
                insight = "Average outcome during high adherence periods was \(String(format: "%.1f", h)) \(metricDefinition.defaultUnit) vs \(String(format: "%.1f", l)) \(metricDefinition.defaultUnit) during lower compliance."
            }
        } else {
            insight = "Dose adherence is steady at \(Int(overallAdherence))% with \(takenCount) logged doses."
        }

        return AdherenceRelationshipResult(
            metricCode: metricDefinition.code,
            metricName: metricDefinition.name,
            overallAdherencePercentage: overallAdherence,
            adherentDaysCount: takenCount,
            missedDaysCount: missedCount,
            highAdherenceAverageValue: highAvg,
            lowAdherenceAverageValue: lowAvg,
            adherenceDelta: delta,
            correlationCoefficient: r,
            statisticalSignificance: weekAdherencePairs.count >= 4 ? "Strong Statistical Sample" : "Early Observational Trend",
            doseResponseLagDays: 1,
            clinicalInsight: insight
        )
    }

    // MARK: - 5. Protocol-Period Comparisons

    /// Compares metric outcomes across two distinct protocol periods (e.g. Protocol A vs Protocol B).
    public func compareProtocolPeriods(
        measurements: [Measurement],
        protocolA: ProtocolModel,
        protocolB: ProtocolModel,
        metricDefinition: MetricDefinition
    ) -> ProtocolPeriodComparison? {
        let rangeA = DateInterval(start: protocolA.startDate, end: protocolA.endDate ?? Date())
        let rangeB = DateInterval(start: protocolB.startDate, end: protocolB.endDate ?? Date())

        return compareDateIntervals(
            measurements: measurements,
            periodA: (id: protocolA.id, name: protocolA.name, interval: rangeA),
            periodB: (id: protocolB.id, name: protocolB.name, interval: rangeB),
            metricDefinition: metricDefinition
        )
    }

    /// Compares metric outcomes across any two arbitrary time periods.
    public func compareDateIntervals(
        measurements: [Measurement],
        periodA: (id: UUID?, name: String, interval: DateInterval),
        periodB: (id: UUID?, name: String, interval: DateInterval),
        metricDefinition: MetricDefinition
    ) -> ProtocolPeriodComparison? {
        let pointsA = measurements
            .filter { $0.timestamp >= periodA.interval.start && $0.timestamp <= periodA.interval.end }
            .sorted(by: { $0.timestamp < $1.timestamp })

        let pointsB = measurements
            .filter { $0.timestamp >= periodB.interval.start && $0.timestamp <= periodB.interval.end }
            .sorted(by: { $0.timestamp < $1.timestamp })

        guard !pointsA.isEmpty, !pointsB.isEmpty else { return nil }

        let statsA = computePeriodStats(points: pointsA, name: periodA.name)
        let statsB = computePeriodStats(points: pointsB, name: periodB.name)

        let meanDiff = statsB.meanValue - statsA.meanValue
        let pctDiff = statsA.meanValue != 0 ? ((meanDiff / abs(statsA.meanValue)) * 100.0) : 0.0
        let velDiff = statsB.weeklyVelocity - statsA.weeklyVelocity

        // Cohen's d Effect Size: d = (MeanB - MeanA) / PooledStdDev
        var cohenD: Double? = nil
        let nA = Double(statsA.sampleCount)
        let nB = Double(statsB.sampleCount)
        if nA > 1 && nB > 1 {
            let pooledVar = (((nA - 1) * pow(statsA.standardDeviation, 2)) + ((nB - 1) * pow(statsB.standardDeviation, 2))) / (nA + nB - 2.0)
            let pooledSD = sqrt(max(0.0001, pooledVar))
            cohenD = abs(meanDiff) / pooledSD
        }

        // Determine superior protocol
        let superiorName: String?
        switch metricDefinition.targetDirection {
        case .decrease:
            if statsB.netChange < statsA.netChange {
                superiorName = periodB.name
            } else if statsA.netChange < statsB.netChange {
                superiorName = periodA.name
            } else {
                superiorName = nil
            }
        case .increase:
            if statsB.netChange > statsA.netChange {
                superiorName = periodB.name
            } else if statsA.netChange > statsB.netChange {
                superiorName = periodA.name
            } else {
                superiorName = nil
            }
        case .maintain:
            let devA = abs(statsA.netChange)
            let devB = abs(statsB.netChange)
            superiorName = devA < devB ? periodA.name : periodB.name
        }

        let summary: String
        if let sup = superiorName {
            summary = "\(sup) demonstrated superior efficacy with a \(String(format: "%.1f", abs(velDiff))) \(metricDefinition.defaultUnit)/week velocity differential."
        } else {
            summary = "Both protocols exhibited comparable trajectories for \(metricDefinition.name)."
        }

        return ProtocolPeriodComparison(
            metricName: metricDefinition.name,
            unit: metricDefinition.defaultUnit,
            protocolAId: periodA.id,
            protocolAName: periodA.name,
            periodAStats: statsA,
            protocolBId: periodB.id,
            protocolBName: periodB.name,
            periodBStats: statsB,
            meanDifference: meanDiff,
            meanPercentageDifference: pctDiff,
            velocityDifferencePerWeek: velDiff,
            cohensDEffectSize: cohenD,
            superiorProtocolName: superiorName,
            summaryConclusion: summary
        )
    }

    private func computePeriodStats<P: TimeSeriesDataPoint>(points: [P], name: String) -> PeriodStatistics {
        let sorted = points.sorted(by: { $0.timestamp < $1.timestamp })
        let first = sorted.first!
        let last = sorted.last!
        let vals = sorted.map(\.value)
        let count = vals.count

        let mean = vals.reduce(0.0, +) / Double(count)
        let sVals = vals.sorted()
        let mid = count / 2
        let median = (count % 2 == 0) ? ((sVals[mid - 1] + sVals[mid]) / 2.0) : sVals[mid]

        let minVal = vals.min() ?? first.value
        let maxVal = vals.max() ?? last.value

        var stdDev = 0.0
        if count > 1 {
            let sumSq = vals.reduce(0.0) { $0 + pow($1 - mean, 2) }
            stdDev = sqrt(sumSq / Double(count - 1))
        }

        let net = last.value - first.value
        let pct = first.value != 0 ? ((net / abs(first.value)) * 100.0) : 0.0

        let days = max(1.0, last.timestamp.timeIntervalSince(first.timestamp) / 86400.0)
        let weeks = days / 7.0
        let velocity = net / weeks

        return PeriodStatistics(
            periodName: name,
            sampleCount: count,
            startDate: first.timestamp,
            endDate: last.timestamp,
            durationDays: Int(days),
            firstValue: first.value,
            lastValue: last.value,
            meanValue: mean,
            medianValue: median,
            minValue: minVal,
            maxValue: maxVal,
            standardDeviation: stdDev,
            netChange: net,
            percentageChange: pct,
            weeklyVelocity: velocity
        )
    }

    // MARK: - 6. Comprehensive Metric Synthesis

    /// Generates a complete non-destructive analytics package for a metric.
    /// Pure function guaranteeing the immutability of raw measurement data.
    public func generateAnalyticsSummary(
        metric: MetricDefinition,
        measurements: [Measurement],
        doseLogs: [DoseLog] = [],
        protocols: [ProtocolModel] = [],
        targetGoal: Double? = nil
    ) -> ComprehensiveMetricAnalytics {
        let ts = TimeSeries<Measurement>(points: measurements)

        // 1. Baseline Analysis
        let baseline = calculateBaselineDifference(
            points: measurements,
            metricName: metric.name,
            unit: metric.defaultUnit,
            baselineMode: .firstRecorded,
            targetValue: targetGoal,
            targetDirection: metric.targetDirection
        )

        // 2. Moving Average Series (7-Day and 30-Day)
        let sma7 = calculateTimeWindowSMA(points: measurements, metricCode: metric.code, windowDays: 7)
        let sma30 = calculateTimeWindowSMA(points: measurements, metricCode: metric.code, windowDays: 30)
        let ema = calculateEMA(points: measurements, metricCode: metric.code, windowDays: 14)

        // 3. Percentage Changes
        let pctChanges = calculateStandardPeriodChanges(
            points: measurements,
            targetDirection: metric.targetDirection
        )

        // 4. Adherence Correlation
        let adhRelation = calculateAdherenceRelationship(
            measurements: measurements,
            doseLogs: doseLogs,
            metricDefinition: metric
        )

        // 5. Protocol Comparisons
        var comparisons: [ProtocolPeriodComparison] = []
        if protocols.count >= 2 {
            let sortedProtocols = protocols.sorted(by: { $0.startDate < $1.startDate })
            for i in 0..<(sortedProtocols.count - 1) {
                let pA = sortedProtocols[i]
                let pB = sortedProtocols[i + 1]
                if let comp = compareProtocolPeriods(measurements: measurements, protocolA: pA, protocolB: pB, metricDefinition: metric) {
                    comparisons.append(comp)
                }
            }
        }

        let finalStatus = baseline?.evaluationStatus ?? .insufficientData

        return ComprehensiveMetricAnalytics(
            definition: metric,
            rawMeasurementsCount: measurements.count,
            rawTimeSeries: ts,
            baselineResult: baseline,
            movingAverages: [sma7, sma30, ema],
            percentageChanges: pctChanges,
            adherenceRelationship: adhRelation,
            protocolComparisons: comparisons,
            evaluationStatus: finalStatus
        )
    }
}
