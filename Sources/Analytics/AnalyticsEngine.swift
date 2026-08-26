import Foundation
import Domain
import CalculationEngine

// MARK: - Analytics Engine Protocol

/// Defines deterministic, pure analytical operations on raw time-series data.
public protocol AnalyticsEngineProtocol: Sendable {
    // 1. Percentage Change
    func calculatePercentageChange<P: TimeSeriesDataPoint>(
        startPoint: P,
        endPoint: P,
        periodName: String,
        targetDirection: TargetDirection
    ) -> ExplainablePercentageChange

    func calculateStandardPeriodChanges<P: TimeSeriesDataPoint>(
        points: [P],
        targetDirection: TargetDirection,
        referenceDate: Date,
        calendar: Calendar
    ) -> [ExplainablePercentageChange]

    // 2. Absolute Change
    func calculateAbsoluteChange<P: TimeSeriesDataPoint>(
        startPoint: P,
        endPoint: P,
        periodName: String
    ) -> ExplainableAbsoluteChange

    // 3. Averages
    func calculateAverages<P: TimeSeriesDataPoint>(
        points: [P],
        metricName: String,
        unit: String,
        trimFraction: Double?
    ) -> ExplainableAverages?

    // 4. Rolling Averages
    func calculateCountSMA<P: TimeSeriesDataPoint>(
        points: [P],
        metricCode: String,
        windowSize: Int
    ) -> ExplainableRollingAverages

    func calculateTimeWindowSMA<P: TimeSeriesDataPoint>(
        points: [P],
        metricCode: String,
        windowDays: Int,
        calendar: Calendar
    ) -> ExplainableRollingAverages

    func calculateEMA<P: TimeSeriesDataPoint>(
        points: [P],
        metricCode: String,
        windowDays: Int,
        smoothingAlpha: Double?
    ) -> ExplainableRollingAverages

    // 5. Minimum / Maximum
    func calculateMinMax<P: TimeSeriesDataPoint>(
        points: [P],
        metricName: String,
        unit: String
    ) -> ExplainableMinMax?

    // 6. Adherence
    func calculateAdherence(
        doseLogs: [DoseLog],
        metricDefinition: MetricDefinition?,
        toleranceMinutes: Int,
        measurements: [Measurement],
        calendar: Calendar
    ) -> ExplainableAdherence

    // 7. Period Comparisons
    func comparePeriods<P: TimeSeriesDataPoint>(
        points: [P],
        periodA: (id: UUID?, name: String, interval: DateInterval),
        periodB: (id: UUID?, name: String, interval: DateInterval),
        metricDefinition: MetricDefinition
    ) -> ExplainablePeriodComparison?

    // 8. Baseline Differences
    func calculateBaselineDifference<P: TimeSeriesDataPoint>(
        points: [P],
        metricName: String,
        unit: String,
        baselineMode: ResultsTrackingEngine.BaselineMode,
        targetValue: Double?,
        targetDirection: TargetDirection
    ) -> ExplainableBaselineDifference?

    // 9. Trend Direction
    func calculateTrendDirection<P: TimeSeriesDataPoint>(
        points: [P],
        metricName: String,
        targetDirection: TargetDirection,
        windowDays: Int?
    ) -> ExplainableTrendDirection?

    // 10. Dose / Event Alignment
    func calculateDoseEventAlignment(
        measurements: [Measurement],
        doseLogs: [DoseLog],
        protocols: [ProtocolModel],
        metricName: String,
        calendar: Calendar
    ) -> ExplainableDoseEventAlignment

    // 11. Cost Metrics
    func calculateCostMetrics(
        costs: [CostEvent],
        doses: [DoseLog],
        elapsedDays: Int,
        currencyCode: String
    ) -> ExplainableCostMetrics

    // 12. Master Analytics Report
    func generateMasterAnalytics(
        metric: MetricDefinition,
        measurements: [Measurement],
        doseLogs: [DoseLog],
        protocols: [ProtocolModel],
        costs: [CostEvent],
        targetGoal: Double?,
        calendar: Calendar
    ) -> MasterAnalyticsReport
}

// MARK: - Concrete Analytics Engine Implementation

/// Production deterministic Analytics Engine operating on raw time-series data.
/// Guaranteed to be explainable, non-destructive, and decoupled from ML black boxes.
public struct AnalyticsEngine: AnalyticsEngineProtocol, Sendable {

    public init() {}

    // MARK: - 1. Percentage Change Calculations

    public func calculatePercentageChange<P: TimeSeriesDataPoint>(
        startPoint: P,
        endPoint: P,
        periodName: String = "Observation Period",
        targetDirection: TargetDirection = .decrease
    ) -> ExplainablePercentageChange {
        let startVal = startPoint.value
        let endVal = endPoint.value
        let delta = endVal - startVal
        let pct = startVal != 0 ? ((delta / abs(startVal)) * 100.0) : 0.0

        let days = max(1.0, endPoint.timestamp.timeIntervalSince(startPoint.timestamp) / 86400.0)
        let weeks = days / 7.0
        let ratePerDay = delta / days
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

        // Build deterministic audit trail
        let formula = CalculationFormula(
            name: "Percentage Change & Rate of Change",
            expression: "Percentage Change = ((V_end - V_start) / |V_start|) * 100%",
            variableDescriptions: [
                "V_start": "Starting measurement value (\(String(format: "%.2f", startVal)) \(startPoint.unit))",
                "V_end": "Ending measurement value (\(String(format: "%.2f", endVal)) \(endPoint.unit))",
                "Δ": "Absolute delta (\(String(format: "%.2f", delta)) \(startPoint.unit))",
                "Duration": "\(Int(days)) days (\(String(format: "%.1f", weeks)) weeks)"
            ],
            methodology: "Calculates the exact percentage progression between two chronological time-series points and normalizes velocity over time."
        )

        let steps: [CalculationStep] = [
            CalculationStep(
                stepNumber: 1,
                title: "Compute Absolute Difference",
                description: "Subtract initial value from final value: \(endVal) - \(startVal)",
                inputValues: ["V_start": startVal, "V_end": endVal],
                formulaApplied: "V_end - V_start",
                outputValue: delta,
                unit: startPoint.unit
            ),
            CalculationStep(
                stepNumber: 2,
                title: "Compute Percentage Relative to Baseline",
                description: "Divide difference by magnitude of starting value and scale to percentage: (\(delta) / |\(startVal)|) * 100",
                inputValues: ["Delta": delta, "Start_Magnitude": abs(startVal)],
                formulaApplied: "(Delta / |V_start|) * 100",
                outputValue: pct,
                unit: "%"
            ),
            CalculationStep(
                stepNumber: 3,
                title: "Calculate Weekly Velocity Rate",
                description: "Divide absolute difference by elapsed duration in weeks: \(delta) / \(String(format: "%.2f", weeks))",
                inputValues: ["Delta": delta, "Weeks": weeks],
                formulaApplied: "Delta / Weeks",
                outputValue: ratePerWeek,
                unit: "\(startPoint.unit)/wk"
            )
        ]

        let underlying = [
            UnderlyingDataPoint.from(startPoint, label: "Start Point (\(periodName))"),
            UnderlyingDataPoint.from(endPoint, label: "End Point (\(periodName))")
        ]

        let explanation = "Over \(Int(days)) days, value changed from \(String(format: "%.1f", startVal)) to \(String(format: "%.1f", endVal)) \(startPoint.unit) (\(pct > 0 ? "+" : "")\(String(format: "%.1f", pct))%), progressing at \(ratePerWeek > 0 ? "+" : "")\(String(format: "%.1f", ratePerWeek)) \(startPoint.unit)/week."

        let auditTrail = CalculationAuditTrail(
            calculationName: "Percentage Change (\(periodName))",
            formula: formula,
            steps: steps,
            underlyingDataPoints: underlying,
            parameters: [
                "periodName": periodName,
                "targetDirection": targetDirection.rawValue,
                "durationDays": "\(Int(days))"
            ],
            humanReadableExplanation: explanation
        )

        return ExplainablePercentageChange(
            periodName: periodName,
            startDate: startPoint.timestamp,
            endDate: endPoint.timestamp,
            startValue: startVal,
            endValue: endVal,
            absoluteDelta: delta,
            percentageChange: pct,
            ratePerDay: ratePerDay,
            ratePerWeek: ratePerWeek,
            trendDirection: trend,
            auditTrail: auditTrail
        )
    }

    public func calculateStandardPeriodChanges<P: TimeSeriesDataPoint>(
        points: [P],
        targetDirection: TargetDirection = .decrease,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [ExplainablePercentageChange] {
        let sorted = points.sorted(by: { $0.timestamp < $1.timestamp })
        guard sorted.count >= 2,
              let first = sorted.first,
              let last = sorted.last else {
            return []
        }

        var results: [ExplainablePercentageChange] = []

        // 1. Overall (Since start)
        results.append(
            calculatePercentageChange(
                startPoint: first,
                endPoint: last,
                periodName: "Overall (Since Start)",
                targetDirection: targetDirection
            )
        )

        // Helper for sliding day intervals
        func addWindow(days: Int, name: String) {
            guard let cutoff = calendar.date(byAdding: .day, value: -days, to: referenceDate) else { return }
            let windowPoints = sorted.filter { $0.timestamp >= cutoff && $0.timestamp <= referenceDate }
            if windowPoints.count >= 2, let wFirst = windowPoints.first, let wLast = windowPoints.last {
                results.append(
                    calculatePercentageChange(
                        startPoint: wFirst,
                        endPoint: wLast,
                        periodName: name,
                        targetDirection: targetDirection
                    )
                )
            }
        }

        addWindow(days: 7, name: "Last 7 Days")
        addWindow(days: 14, name: "Last 14 Days")
        addWindow(days: 30, name: "Last 30 Days")
        addWindow(days: 90, name: "Last 90 Days")

        return results
    }

    // MARK: - 2. Absolute Change Calculations

    public func calculateAbsoluteChange<P: TimeSeriesDataPoint>(
        startPoint: P,
        endPoint: P,
        periodName: String = "Observation Period"
    ) -> ExplainableAbsoluteChange {
        let delta = endPoint.value - startPoint.value
        let days = max(1.0, endPoint.timestamp.timeIntervalSince(startPoint.timestamp) / 86400.0)
        let weeks = days / 7.0
        let ratePerDay = delta / days
        let ratePerWeek = delta / weeks

        let formula = CalculationFormula(
            name: "Absolute Delta & Linear Rate",
            expression: "Absolute Delta (Δ) = V_end - V_start",
            variableDescriptions: [
                "V_start": "\(startPoint.value) \(startPoint.unit)",
                "V_end": "\(endPoint.value) \(endPoint.unit)"
            ],
            methodology: "Linear subtraction between ending and starting values with time-normalized velocity."
        )

        let steps: [CalculationStep] = [
            CalculationStep(
                stepNumber: 1,
                title: "Calculate Delta",
                description: "Subtract start from end: \(endPoint.value) - \(startPoint.value)",
                inputValues: ["V_start": startPoint.value, "V_end": endPoint.value],
                formulaApplied: "V_end - V_start",
                outputValue: delta,
                unit: startPoint.unit
            )
        ]

        let audit = CalculationAuditTrail(
            calculationName: "Absolute Change (\(periodName))",
            formula: formula,
            steps: steps,
            underlyingDataPoints: [
                UnderlyingDataPoint.from(startPoint, label: "Start (\(periodName))"),
                UnderlyingDataPoint.from(endPoint, label: "End (\(periodName))")
            ],
            humanReadableExplanation: "Absolute difference of \(delta > 0 ? "+" : "")\(String(format: "%.1f", delta)) \(startPoint.unit) across \(Int(days)) days."
        )

        return ExplainableAbsoluteChange(
            periodName: periodName,
            unit: startPoint.unit,
            startValue: startPoint.value,
            endValue: endPoint.value,
            delta: delta,
            ratePerDay: ratePerDay,
            ratePerWeek: ratePerWeek,
            auditTrail: audit
        )
    }

    // MARK: - 3. Deterministic Averages & Statistical Moments

    public func calculateAverages<P: TimeSeriesDataPoint>(
        points: [P],
        metricName: String = "Metric",
        unit: String = "",
        trimFraction: Double? = nil
    ) -> ExplainableAverages? {
        guard !points.isEmpty else { return nil }

        let sorted = points.sorted(by: { $0.timestamp < $1.timestamp })
        let vals = sorted.map(\.value)
        let count = vals.count

        // 1. Arithmetic Mean
        let sum = vals.reduce(0.0, +)
        let mean = sum / Double(count)

        // 2. Median
        let sortedVals = vals.sorted()
        let mid = count / 2
        let median = (count % 2 == 0) ? ((sortedVals[mid - 1] + sortedVals[mid]) / 2.0) : sortedVals[mid]

        // 3. Trimmed Mean (optional)
        var trimmedMean: Double? = nil
        if let frac = trimFraction, frac > 0 && frac < 0.5 && count >= 5 {
            let trimK = Int(Double(count) * frac)
            let trimmedSlice = sortedVals[trimK..<(count - trimK)]
            if !trimmedSlice.isEmpty {
                trimmedMean = trimmedSlice.reduce(0.0, +) / Double(trimmedSlice.count)
            }
        }

        // 4. Geometric Mean (if all values > 0)
        var geoMean: Double? = nil
        if vals.allSatisfy({ $0 > 0 }) {
            let logSum = vals.reduce(0.0) { $0 + log($1) }
            geoMean = exp(logSum / Double(count))
        }

        // 5. Variance and Standard Deviation
        var variance = 0.0
        var stdDev = 0.0
        var stdErr = 0.0
        if count > 1 {
            let sumSqDiffs = vals.reduce(0.0) { $0 + pow($1 - mean, 2) }
            variance = sumSqDiffs / Double(count - 1)
            stdDev = sqrt(variance)
            stdErr = stdDev / sqrt(Double(count))
        }

        // Formula and Step Trace
        let formula = CalculationFormula(
            name: "Statistical Moments & Central Tendency",
            expression: "Mean (μ) = (1/N) * Σ(x_i), Median = Middle(Sorted(X)), s = sqrt((1/(N-1)) * Σ(x_i - μ)^2)",
            variableDescriptions: [
                "N": "Sample size count (\(count))",
                "Σ(x_i)": "Sum of all observations (\(String(format: "%.2f", sum)))",
                "μ": "Arithmetic mean (\(String(format: "%.2f", mean)) \(unit))",
                "s": "Sample standard deviation (\(String(format: "%.2f", stdDev)) \(unit))"
            ],
            methodology: "Calculates standard unbiased parametric and non-parametric central tendency statistics."
        )

        let steps: [CalculationStep] = [
            CalculationStep(
                stepNumber: 1,
                title: "Sum Raw Data Points",
                description: "Summed \(count) measurements: total = \(String(format: "%.2f", sum))",
                inputValues: ["SampleCount": Double(count)],
                formulaApplied: "Σ(x_i)",
                outputValue: sum,
                unit: unit
            ),
            CalculationStep(
                stepNumber: 2,
                title: "Calculate Arithmetic Mean",
                description: "Divide sum by count: \(String(format: "%.2f", sum)) / \(count)",
                inputValues: ["Sum": sum, "Count": Double(count)],
                formulaApplied: "Sum / Count",
                outputValue: mean,
                unit: unit
            ),
            CalculationStep(
                stepNumber: 3,
                title: "Compute Median",
                description: "Sorted all values and extracted the 50th percentile rank: \(median)",
                inputValues: ["Median": median],
                formulaApplied: "Sorted[N/2]",
                outputValue: median,
                unit: unit
            ),
            CalculationStep(
                stepNumber: 4,
                title: "Compute Standard Deviation",
                description: "Sum of squared deviations from mean divided by (N-1), then take square root.",
                inputValues: ["Variance": variance],
                formulaApplied: "sqrt(Variance)",
                outputValue: stdDev,
                unit: unit
            )
        ]

        let underlying = sorted.map { UnderlyingDataPoint.from($0) }
        let audit = CalculationAuditTrail(
            calculationName: "Averages & Distribution (\(metricName))",
            formula: formula,
            steps: steps,
            underlyingDataPoints: underlying,
            parameters: ["sampleCount": "\(count)", "metric": metricName],
            humanReadableExplanation: "\(metricName) has an arithmetic mean of \(String(format: "%.1f", mean)) \(unit) and median of \(String(format: "%.1f", median)) \(unit) across \(count) data points (std dev: ±\(String(format: "%.1f", stdDev)))."
        )

        return ExplainableAverages(
            metricName: metricName,
            unit: unit,
            sampleCount: count,
            arithmeticMean: mean,
            median: median,
            trimmedMean: trimmedMean,
            geometricMean: geoMean,
            variance: variance,
            standardDeviation: stdDev,
            standardError: stdErr,
            auditTrail: audit
        )
    }

    // MARK: - 4. Rolling Averages & Moving Windows

    public func calculateCountSMA<P: TimeSeriesDataPoint>(
        points: [P],
        metricCode: String = "metric",
        windowSize: Int = 7
    ) -> ExplainableRollingAverages {
        let sorted = points.sorted(by: { $0.timestamp < $1.timestamp })
        guard !sorted.isEmpty, windowSize > 0 else {
            let audit = CalculationAuditTrail(
                calculationName: "\(windowSize)-Point Simple Moving Average",
                formula: CalculationFormula(name: "Count SMA", expression: "SMA_i = (1/k) * Σ_{j=i-k+1}^i x_j"),
                steps: [],
                underlyingDataPoints: []
            )
            return ExplainableRollingAverages(
                metricCode: metricCode,
                windowDays: windowSize,
                calculationType: .simple,
                points: [],
                auditTrail: audit
            )
        }

        var smoothed: [MovingAveragePoint] = []
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

            smoothed.append(
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

        let formula = CalculationFormula(
            name: "\(windowSize)-Point Simple Moving Average (SMA)",
            expression: "SMA_i = (1/k) * Σ_{j=i-k+1}^i x_j",
            variableDescriptions: ["k": "Window count size (\(windowSize) points)"],
            methodology: "Computes sliding arithmetic mean over the prior \(windowSize) recorded points."
        )

        let audit = CalculationAuditTrail(
            calculationName: "\(windowSize)-Point Simple Moving Average",
            formula: formula,
            underlyingDataPoints: sorted.map { UnderlyingDataPoint.from($0) },
            parameters: ["windowSize": "\(windowSize)", "calculationType": "Count-based SMA"],
            humanReadableExplanation: "Smoothed time-series using a \(windowSize)-point sliding moving average across \(sorted.count) logs."
        )

        return ExplainableRollingAverages(
            metricCode: metricCode,
            windowDays: windowSize,
            calculationType: .simple,
            points: smoothed,
            auditTrail: audit
        )
    }

    public func calculateTimeWindowSMA<P: TimeSeriesDataPoint>(
        points: [P],
        metricCode: String = "metric",
        windowDays: Int = 7,
        calendar: Calendar = .current
    ) -> ExplainableRollingAverages {
        let sorted = points.sorted(by: { $0.timestamp < $1.timestamp })
        guard !sorted.isEmpty, windowDays > 0 else {
            let audit = CalculationAuditTrail(
                calculationName: "\(windowDays)-Day Calendar Moving Average",
                formula: CalculationFormula(name: "Time-Window SMA", expression: "SMA(t) = Average(Values in [t - windowDays, t])"),
                steps: [],
                underlyingDataPoints: []
            )
            return ExplainableRollingAverages(
                metricCode: metricCode,
                windowDays: windowDays,
                calculationType: .timeWeighted,
                points: [],
                auditTrail: audit
            )
        }

        var smoothed: [MovingAveragePoint] = []
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

            smoothed.append(
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

        let formula = CalculationFormula(
            name: "\(windowDays)-Day Calendar Time-Window Moving Average",
            expression: "SMA(t) = (1/|W(t)|) * Σ_{p ∈ W(t)} Value(p), where W(t) = {p | t - \(windowDays)d ≤ timestamp(p) ≤ t}",
            variableDescriptions: ["windowDays": "\(windowDays) days calendar window"],
            methodology: "Calendar-aware sliding window that gracefully handles sparse, irregular, or clustered logs."
        )

        let audit = CalculationAuditTrail(
            calculationName: "\(windowDays)-Day Calendar Moving Average",
            formula: formula,
            underlyingDataPoints: sorted.map { UnderlyingDataPoint.from($0) },
            parameters: ["windowDays": "\(windowDays)", "calculationType": "Time-Window SMA"],
            humanReadableExplanation: "Current \(windowDays)-day rolling average is \(String(format: "%.1f", smoothed.last?.movingAverage ?? 0.0))."
        )

        return ExplainableRollingAverages(
            metricCode: metricCode,
            windowDays: windowDays,
            calculationType: .timeWeighted,
            points: smoothed,
            auditTrail: audit
        )
    }

    public func calculateEMA<P: TimeSeriesDataPoint>(
        points: [P],
        metricCode: String = "metric",
        windowDays: Int = 14,
        smoothingAlpha: Double? = nil
    ) -> ExplainableRollingAverages {
        let sorted = points.sorted(by: { $0.timestamp < $1.timestamp })
        guard !sorted.isEmpty else {
            let audit = CalculationAuditTrail(
                calculationName: "\(windowDays)-Day Exponential Moving Average (EMA)",
                formula: CalculationFormula(name: "EMA", expression: "EMA_t = α * Value_t + (1 - α) * EMA_{t-1}"),
                steps: [],
                underlyingDataPoints: []
            )
            return ExplainableRollingAverages(
                metricCode: metricCode,
                windowDays: windowDays,
                calculationType: .exponential,
                points: [],
                auditTrail: audit
            )
        }

        let alpha = smoothingAlpha ?? (2.0 / (Double(max(2, windowDays)) + 1.0))
        var smoothed: [MovingAveragePoint] = []
        var runningEMA = sorted[0].value

        for (i, p) in sorted.enumerated() {
            if i == 0 {
                runningEMA = p.value
            } else {
                runningEMA = (alpha * p.value) + ((1.0 - alpha) * runningEMA)
            }

            smoothed.append(
                MovingAveragePoint(
                    timestamp: p.timestamp,
                    rawValue: p.value,
                    movingAverage: runningEMA,
                    sampleCountInWindow: i + 1
                )
            )
        }

        let formula = CalculationFormula(
            name: "\(windowDays)-Day Exponential Moving Average (EMA)",
            expression: "EMA_t = α * Value_t + (1 - α) * EMA_{t-1}, α = 2 / (N + 1) = \(String(format: "%.3f", alpha))",
            variableDescriptions: ["α (Smoothing Constant)": "\(String(format: "%.3f", alpha))", "N": "\(windowDays) days"],
            methodology: "Weights recent observations exponentially higher than older observations."
        )

        let audit = CalculationAuditTrail(
            calculationName: "\(windowDays)-Day EMA",
            formula: formula,
            underlyingDataPoints: sorted.map { UnderlyingDataPoint.from($0) },
            parameters: ["windowDays": "\(windowDays)", "alpha": "\(alpha)"],
            humanReadableExplanation: "Exponential moving average smoothed at α=\(String(format: "%.2f", alpha)). Latest EMA: \(String(format: "%.1f", runningEMA))."
        )

        return ExplainableRollingAverages(
            metricCode: metricCode,
            windowDays: windowDays,
            calculationType: .exponential,
            points: smoothed,
            auditTrail: audit
        )
    }

    // MARK: - 5. Deterministic Minimum / Maximum & Percentiles

    public func calculateMinMax<P: TimeSeriesDataPoint>(
        points: [P],
        metricName: String = "Metric",
        unit: String = ""
    ) -> ExplainableMinMax? {
        guard !points.isEmpty else { return nil }

        let sortedByTime = points.sorted(by: { $0.timestamp < $1.timestamp })
        guard let minPoint = sortedByTime.min(by: { $0.value < $1.value }),
              let maxPoint = sortedByTime.max(by: { $0.value < $1.value }) else {
            return nil
        }

        let sortedVals = sortedByTime.map(\.value).sorted()
        let count = sortedVals.count
        let range = maxPoint.value - minPoint.value

        func percentile(_ p: Double) -> Double {
            guard count > 1 else { return sortedVals[0] }
            let index = p * Double(count - 1)
            let lower = Int(floor(index))
            let upper = min(count - 1, lower + 1)
            let weight = index - Double(lower)
            return sortedVals[lower] + weight * (sortedVals[upper] - sortedVals[lower])
        }

        let p25 = percentile(0.25)
        let p50 = percentile(0.50)
        let p75 = percentile(0.75)
        let p90 = percentile(0.90)
        let p95 = percentile(0.95)
        let iqr = p75 - p25

        let formula = CalculationFormula(
            name: "Extrema & Percentile Distribution",
            expression: "Min = min(Values), Max = max(Values), Range = Max - Min, IQR = P75 - P25",
            variableDescriptions: [
                "Min": "\(minPoint.value) \(unit) on \(minPoint.timestamp.formatted(date: .abbreviated, time: .omitted))",
                "Max": "\(maxPoint.value) \(unit) on \(maxPoint.timestamp.formatted(date: .abbreviated, time: .omitted))",
                "IQR": "\(String(format: "%.2f", iqr)) \(unit)"
            ],
            methodology: "Deterministic rank-order percentile interpolation and global peak/trough identification."
        )

        let steps: [CalculationStep] = [
            CalculationStep(
                stepNumber: 1,
                title: "Identify Global Minimum",
                description: "Lowest recorded point: \(minPoint.value) \(unit) on \(minPoint.timestamp)",
                inputValues: ["Min": minPoint.value],
                formulaApplied: "min(X)",
                outputValue: minPoint.value,
                unit: unit
            ),
            CalculationStep(
                stepNumber: 2,
                title: "Identify Global Maximum",
                description: "Highest recorded point: \(maxPoint.value) \(unit) on \(maxPoint.timestamp)",
                inputValues: ["Max": maxPoint.value],
                formulaApplied: "max(X)",
                outputValue: maxPoint.value,
                unit: unit
            ),
            CalculationStep(
                stepNumber: 3,
                title: "Compute Range Span",
                description: "Max - Min = \(maxPoint.value) - \(minPoint.value)",
                inputValues: ["Max": maxPoint.value, "Min": minPoint.value],
                formulaApplied: "Max - Min",
                outputValue: range,
                unit: unit
            )
        ]

        let audit = CalculationAuditTrail(
            calculationName: "Extrema & Percentiles (\(metricName))",
            formula: formula,
            steps: steps,
            underlyingDataPoints: [
                UnderlyingDataPoint.from(minPoint, label: "Minimum Record"),
                UnderlyingDataPoint.from(maxPoint, label: "Maximum Record")
            ],
            parameters: ["sampleCount": "\(count)", "rangeSpan": "\(range)"],
            humanReadableExplanation: "\(metricName) ranged from min of \(String(format: "%.1f", minPoint.value)) \(unit) to peak of \(String(format: "%.1f", maxPoint.value)) \(unit) (span: \(String(format: "%.1f", range)) \(unit))."
        )

        return ExplainableMinMax(
            metricName: metricName,
            unit: unit,
            sampleCount: count,
            minValue: minPoint.value,
            minDate: minPoint.timestamp,
            maxValue: maxPoint.value,
            maxDate: maxPoint.timestamp,
            rangeSpan: range,
            p25Value: p25,
            p50Median: p50,
            p75Value: p75,
            p90Value: p90,
            p95Value: p95,
            interquartileRange: iqr,
            auditTrail: audit
        )
    }

    // MARK: - 6. Deterministic Protocol Adherence & Streak Analytics

    public func calculateAdherence(
        doseLogs: [DoseLog],
        metricDefinition: MetricDefinition? = nil,
        toleranceMinutes: Int = 120,
        measurements: [Measurement] = [],
        calendar: Calendar = .current
    ) -> ExplainableAdherence {
        guard !doseLogs.isEmpty else {
            let audit = CalculationAuditTrail(
                calculationName: "Protocol Adherence",
                formula: CalculationFormula(name: "Adherence %", expression: "Adherence = (Taken / Total) * 100%"),
                steps: [],
                underlyingDataPoints: []
            )
            return ExplainableAdherence(
                overallAdherencePercentage: 100.0,
                totalScheduledDoses: 0,
                totalTakenDoses: 0,
                totalSkippedDoses: 0,
                totalMissedDoses: 0,
                auditTrail: audit
            )
        }

        let takenDoses = doseLogs.filter { $0.status == .taken }
        let skippedDoses = doseLogs.filter { $0.status == .skipped }
        let missedDoses = doseLogs.filter { $0.status == .missed }
        let partialDoses = doseLogs.filter { $0.status == .partialDose }
        let total = doseLogs.count

        let adherencePct = (Double(takenDoses.count) / Double(max(1, total))) * 100.0

        // Timing variance & On-Time percentage
        var onTimeCount = 0
        var totalVarianceMinutes = 0.0
        var varianceSampleCount = 0

        for log in takenDoses {
            if let loggedDate = log.loggedDate {
                let diffMins = abs(calendar.dateComponents([.minute], from: log.scheduledDate, to: loggedDate).minute ?? 0)
                totalVarianceMinutes += Double(diffMins)
                varianceSampleCount += 1
                if diffMins <= toleranceMinutes {
                    onTimeCount += 1
                }
            } else {
                // If logged without timestamp difference, treat as on time
                onTimeCount += 1
            }
        }

        let onTimePct = !takenDoses.isEmpty ? ((Double(onTimeCount) / Double(takenDoses.count)) * 100.0) : 100.0
        let avgVariance = varianceSampleCount > 0 ? (totalVarianceMinutes / Double(varianceSampleCount)) : 0.0

        // Consecutive Day Streaks
        var currentStreak = 0
        var longestStreak = 0
        let takenDays = Set(takenDoses.compactMap { calendar.startOfDay(for: $0.loggedDate ?? $0.scheduledDate) })

        // Current streak going back from today/latest
        var checkDate = Date()
        while takenDays.contains(calendar.startOfDay(for: checkDate)) {
            currentStreak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }

        // Longest historical streak
        let sortedDays = Array(takenDays).sorted()
        var runningStreak = 0
        var prevDay: Date? = nil

        for day in sortedDays {
            if let p = prevDay {
                let diffDays = calendar.dateComponents([.day], from: p, to: day).day ?? 0
                if diffDays == 1 {
                    runningStreak += 1
                } else {
                    runningStreak = 1
                }
            } else {
                runningStreak = 1
            }
            longestStreak = max(longestStreak, runningStreak)
            prevDay = day
        }

        // Compound Breakdown
        var compoundMap: [String: (taken: Int, total: Int)] = [:]
        for log in doseLogs {
            var curr = compoundMap[log.compoundName] ?? (0, 0)
            curr.total += 1
            if log.status == .taken { curr.taken += 1 }
            compoundMap[log.compoundName] = curr
        }

        var compoundPct: [String: Double] = [:]
        for (comp, stats) in compoundMap {
            compoundPct[comp] = (Double(stats.taken) / Double(max(1, stats.total))) * 100.0
        }

        // Cohort comparison if measurements provided
        var highAvg: Double? = nil
        var lowAvg: Double? = nil
        var adhDelta: Double? = nil

        if !measurements.isEmpty {
            let sortedM = measurements.sorted(by: { $0.timestamp < $1.timestamp })
            if let firstM = sortedM.first?.timestamp, let lastM = sortedM.last?.timestamp {
                var currentWeek = firstM
                var highWeeks: [Double] = []
                var lowWeeks: [Double] = []

                while currentWeek < lastM {
                    guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: currentWeek) else { break }
                    let weekDoses = doseLogs.filter {
                        let dt = $0.loggedDate ?? $0.scheduledDate
                        return dt >= currentWeek && dt < nextWeek
                    }
                    let weekM = sortedM.filter { $0.timestamp >= currentWeek && $0.timestamp < nextWeek }

                    if !weekDoses.isEmpty && !weekM.isEmpty {
                        let wTaken = weekDoses.filter { $0.status == .taken }.count
                        let wRate = (Double(wTaken) / Double(weekDoses.count)) * 100.0
                        let wAvg = weekM.map(\.value).reduce(0.0, +) / Double(weekM.count)

                        if wRate >= 80.0 {
                            highWeeks.append(wAvg)
                        } else {
                            lowWeeks.append(wAvg)
                        }
                    }
                    currentWeek = nextWeek
                }

                if !highWeeks.isEmpty { highAvg = highWeeks.reduce(0.0, +) / Double(highWeeks.count) }
                if !lowWeeks.isEmpty { lowAvg = lowWeeks.reduce(0.0, +) / Double(lowWeeks.count) }
                if let h = highAvg, let l = lowAvg { adhDelta = h - l }
            }
        }

        // Audit Trail
        let formula = CalculationFormula(
            name: "Protocol Adherence & Streak Consistency",
            expression: "Adherence % = (Taken Doses / Total Scheduled) * 100%, On-Time % = (Doses Within ±\(toleranceMinutes)m / Taken) * 100%",
            variableDescriptions: [
                "Taken": "\(takenDoses.count) doses",
                "Scheduled Total": "\(total) doses",
                "On-Time Tolerance": "±\(toleranceMinutes) minutes"
            ],
            methodology: "Calculates protocol compliance, timing variance, consecutive day streak, and outcome impact."
        )

        let steps: [CalculationStep] = [
            CalculationStep(
                stepNumber: 1,
                title: "Calculate Overall Adherence Rate",
                description: "(\(takenDoses.count) taken / \(total) total scheduled) * 100",
                inputValues: ["Taken": Double(takenDoses.count), "Total": Double(total)],
                formulaApplied: "(Taken / Total) * 100",
                outputValue: adherencePct,
                unit: "%"
            ),
            CalculationStep(
                stepNumber: 2,
                title: "Calculate On-Time Delivery Rate",
                description: "(\(onTimeCount) within ±\(toleranceMinutes) min / \(takenDoses.count) taken) * 100",
                inputValues: ["OnTime": Double(onTimeCount), "Taken": Double(takenDoses.count)],
                formulaApplied: "(OnTime / Taken) * 100",
                outputValue: onTimePct,
                unit: "%"
            ),
            CalculationStep(
                stepNumber: 3,
                title: "Determine Active Streak",
                description: "Consecutive consecutive calendar days with at least one logged dose.",
                inputValues: ["ActiveStreak": Double(currentStreak)],
                formulaApplied: "ConsecutiveDays(TakenDates)",
                outputValue: Double(currentStreak),
                unit: "days"
            )
        ]

        let audit = CalculationAuditTrail(
            calculationName: "Protocol Adherence Analysis",
            formula: formula,
            steps: steps,
            underlyingDataPoints: doseLogs.prefix(50).map { UnderlyingDataPoint.from(dose: $0) },
            parameters: [
                "totalDoses": "\(total)",
                "taken": "\(takenDoses.count)",
                "missed": "\(missedDoses.count)",
                "skipped": "\(skippedDoses.count)"
            ],
            humanReadableExplanation: "Protocol adherence is \(Int(adherencePct))% (\(takenDoses.count)/\(total) taken). Active streak is \(currentStreak) days."
        )

        return ExplainableAdherence(
            overallAdherencePercentage: adherencePct,
            totalScheduledDoses: total,
            totalTakenDoses: takenDoses.count,
            totalSkippedDoses: skippedDoses.count,
            totalMissedDoses: missedDoses.count,
            totalPartialDoses: partialDoses.count,
            onTimePercentage: onTimePct,
            averageTimingVarianceMinutes: avgVariance,
            currentStreakDays: currentStreak,
            longestStreakDays: longestStreak,
            compoundBreakdown: compoundPct,
            highAdherenceCohortAvgMetric: highAvg,
            lowAdherenceCohortAvgMetric: lowAvg,
            adherenceDelta: adhDelta,
            auditTrail: audit
        )
    }

    // MARK: - 7. Deterministic Period Comparisons

    public func comparePeriods<P: TimeSeriesDataPoint>(
        points: [P],
        periodA: (id: UUID?, name: String, interval: DateInterval),
        periodB: (id: UUID?, name: String, interval: DateInterval),
        metricDefinition: MetricDefinition
    ) -> ExplainablePeriodComparison? {
        let pointsA = points
            .filter { $0.timestamp >= periodA.interval.start && $0.timestamp <= periodA.interval.end }
            .sorted(by: { $0.timestamp < $1.timestamp })

        let pointsB = points
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
            if statsB.netChange < statsA.netChange { superiorName = periodB.name }
            else if statsA.netChange < statsB.netChange { superiorName = periodA.name }
            else { superiorName = nil }
        case .increase:
            if statsB.netChange > statsA.netChange { superiorName = periodB.name }
            else if statsA.netChange > statsB.netChange { superiorName = periodA.name }
            else { superiorName = nil }
        case .maintain:
            let devA = abs(statsA.netChange)
            let devB = abs(statsB.netChange)
            superiorName = devA < devB ? periodA.name : periodB.name
        }

        let summary: String
        if let sup = superiorName {
            summary = "\(sup) demonstrated superior trajectory with a \(String(format: "%.1f", abs(velDiff))) \(metricDefinition.defaultUnit)/week differential."
        } else {
            summary = "Both protocol phases demonstrated comparable trajectories for \(metricDefinition.name)."
        }

        let formula = CalculationFormula(
            name: "Period Comparative Statistics & Effect Size",
            expression: "Mean Diff = Mean_B - Mean_A, Cohen's d = |Mean_B - Mean_A| / s_pooled",
            variableDescriptions: [
                "Mean_A": "\(String(format: "%.2f", statsA.meanValue)) \(metricDefinition.defaultUnit)",
                "Mean_B": "\(String(format: "%.2f", statsB.meanValue)) \(metricDefinition.defaultUnit)",
                "Cohen's d": "\(String(format: "%.2f", cohenD ?? 0.0))"
            ],
            methodology: "Evaluates side-by-side parametric means, velocities, and statistical effect size."
        )

        let steps: [CalculationStep] = [
            CalculationStep(
                stepNumber: 1,
                title: "Calculate Mean Difference",
                description: "\(statsB.meanValue) - \(statsA.meanValue)",
                inputValues: ["Mean_A": statsA.meanValue, "Mean_B": statsB.meanValue],
                formulaApplied: "Mean_B - Mean_A",
                outputValue: meanDiff,
                unit: metricDefinition.defaultUnit
            ),
            CalculationStep(
                stepNumber: 2,
                title: "Compute Velocity Difference",
                description: "\(statsB.weeklyVelocity) - \(statsA.weeklyVelocity)",
                inputValues: ["Vel_A": statsA.weeklyVelocity, "Vel_B": statsB.weeklyVelocity],
                formulaApplied: "Vel_B - Vel_A",
                outputValue: velDiff,
                unit: "\(metricDefinition.defaultUnit)/wk"
            )
        ]

        let underlying = (pointsA.prefix(10) + pointsB.prefix(10)).map { UnderlyingDataPoint.from($0) }
        let audit = CalculationAuditTrail(
            calculationName: "Protocol Comparison (\(periodA.name) vs \(periodB.name))",
            formula: formula,
            steps: steps,
            underlyingDataPoints: underlying,
            parameters: ["periodA": periodA.name, "periodB": periodB.name],
            humanReadableExplanation: summary
        )

        return ExplainablePeriodComparison(
            metricName: metricDefinition.name,
            unit: metricDefinition.defaultUnit,
            periodAName: periodA.name,
            periodAStats: statsA,
            periodBName: periodB.name,
            periodBStats: statsB,
            meanDifference: meanDiff,
            meanPercentageDifference: pctDiff,
            velocityDifferencePerWeek: velDiff,
            cohensDEffectSize: cohenD,
            superiorPeriodName: superiorName,
            summaryConclusion: summary,
            auditTrail: audit
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

    // MARK: - 8. Deterministic Baseline Difference Result

    public func calculateBaselineDifference<P: TimeSeriesDataPoint>(
        points: [P],
        metricName: String,
        unit: String,
        baselineMode: ResultsTrackingEngine.BaselineMode = .firstRecorded,
        targetValue: Double? = nil,
        targetDirection: TargetDirection = .decrease
    ) -> ExplainableBaselineDifference? {
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

        // Z-score relative to overall standard deviation
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
            case .decrease: isAchieved = latest.value <= target
            case .increase: isAchieved = latest.value >= target
            case .maintain: isAchieved = abs(latest.value - target) <= (abs(target) * 0.05)
            }
        }

        let status: MetricEvaluationStatus
        if isAchieved {
            status = .targetReached
        } else if abs(delta) < 0.001 {
            status = .stalled
        } else {
            switch targetDirection {
            case .decrease: status = delta < 0 ? .onTrack : .regressing
            case .increase: status = delta > 0 ? .onTrack : .regressing
            case .maintain: status = abs(delta) <= (abs(baselineVal) * 0.05) ? .onTrack : .regressing
            }
        }

        let formula = CalculationFormula(
            name: "Baseline Deviation & Z-Score Progress",
            expression: "Δ_Baseline = V_current - V_baseline, z = (V_current - V_baseline) / σ",
            variableDescriptions: [
                "V_baseline": "\(baselineVal) \(unit)",
                "V_current": "\(latest.value) \(unit)"
            ],
            methodology: "Measures current progress against starting baseline and evaluates target achievement."
        )

        let steps: [CalculationStep] = [
            CalculationStep(
                stepNumber: 1,
                title: "Calculate Delta from Baseline",
                description: "\(latest.value) - \(baselineVal)",
                inputValues: ["V_baseline": baselineVal, "V_current": latest.value],
                formulaApplied: "V_current - V_baseline",
                outputValue: delta,
                unit: unit
            ),
            CalculationStep(
                stepNumber: 2,
                title: "Compute Baseline Percentage Difference",
                description: "(\(delta) / |\(baselineVal)|) * 100",
                inputValues: ["Delta": delta, "Baseline": baselineVal],
                formulaApplied: "(Delta / |Baseline|) * 100",
                outputValue: pct,
                unit: "%"
            )
        ]

        let audit = CalculationAuditTrail(
            calculationName: "Baseline Difference Analysis",
            formula: formula,
            steps: steps,
            underlyingDataPoints: [
                UnderlyingDataPoint(originalRecordId: UUID(), recordType: "Baseline", timestamp: baselineDt, value: baselineVal, unit: unit, label: "Baseline (\(baselineSrc.rawValue))"),
                UnderlyingDataPoint.from(latest, label: "Latest Current Log")
            ],
            parameters: ["baselineSource": baselineSrc.rawValue, "target": "\(targetValue ?? 0.0)"],
            humanReadableExplanation: "Delta from baseline is \(delta > 0 ? "+" : "")\(String(format: "%.1f", delta)) \(unit) (\(pct > 0 ? "+" : "")\(String(format: "%.1f", pct))%). Status: \(status.rawValue)."
        )

        return ExplainableBaselineDifference(
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
            evaluationStatus: status,
            auditTrail: audit
        )
    }

    // MARK: - 9. Deterministic Trend Direction & Linear Slope

    public func calculateTrendDirection<P: TimeSeriesDataPoint>(
        points: [P],
        metricName: String = "Metric",
        targetDirection: TargetDirection = .decrease,
        windowDays: Int? = nil
    ) -> ExplainableTrendDirection? {
        let sortedAll = points.sorted(by: { $0.timestamp < $1.timestamp })
        guard sortedAll.count >= 2 else { return nil }

        let filtered: [P]
        if let days = windowDays {
            let cutoff = Date().addingTimeInterval(-Double(days) * 86400.0)
            filtered = sortedAll.filter { $0.timestamp >= cutoff }
        } else {
            filtered = sortedAll
        }

        guard filtered.count >= 2, let first = filtered.first else { return nil }

        let n = Double(filtered.count)
        let t0 = first.timestamp.timeIntervalSince1970

        // x in days from start of window
        let xVals = filtered.map { ($0.timestamp.timeIntervalSince1970 - t0) / 86400.0 }
        let yVals = filtered.map(\.value)

        let sumX = xVals.reduce(0.0, +)
        let sumY = yVals.reduce(0.0, +)
        let sumXY = zip(xVals, yVals).reduce(0.0) { $0 + ($1.0 * $1.1) }
        let sumX2 = xVals.reduce(0.0) { $0 + ($1 * $1) }

        let denom = (n * sumX2) - (sumX * sumX)
        let slopePerDay: Double
        if abs(denom) > 0.0001 {
            slopePerDay = ((n * sumXY) - (sumX * sumY)) / denom
        } else {
            slopePerDay = 0.0
        }
        let slopePerWeek = slopePerDay * 7.0

        // Mann-Kendall S statistic
        var s = 0
        for i in 0..<(filtered.count - 1) {
            for j in (i + 1)..<filtered.count {
                let diff = yVals[j] - yVals[i]
                if diff > 0.001 { s += 1 }
                else if diff < -0.001 { s -= 1 }
            }
        }

        // Determine trend direction
        let trend: AnalyticsTrendDirection
        let threshold = 0.02 * (yVals.max() ?? 1.0) / max(1.0, xVals.last ?? 1.0)
        switch targetDirection {
        case .decrease:
            if slopePerDay < -threshold { trend = .improving }
            else if slopePerDay > threshold { trend = .regressing }
            else { trend = .stable }
        case .increase:
            if slopePerDay > threshold { trend = .improving }
            else if slopePerDay < -threshold { trend = .regressing }
            else { trend = .stable }
        case .maintain:
            trend = abs(slopePerDay) <= threshold ? .improving : .regressing
        }

        let formula = CalculationFormula(
            name: "Ordinary Least Squares (OLS) Linear Trend",
            expression: "Slope m = (N*Σ(xy) - Σx*Σy) / (N*Σ(x^2) - (Σx)^2), Mann-Kendall S = Σ sgn(x_j - x_i)",
            variableDescriptions: [
                "Slope per Day": "\(String(format: "%.4f", slopePerDay))",
                "Slope per Week": "\(String(format: "%.2f", slopePerWeek))"
            ],
            methodology: "Deterministic OLS linear regression fit and non-parametric monotonic trend verification."
        )

        let audit = CalculationAuditTrail(
            calculationName: "Trend Direction Analysis",
            formula: formula,
            underlyingDataPoints: filtered.map { UnderlyingDataPoint.from($0) },
            parameters: ["slopePerWeek": "\(slopePerWeek)", "targetDirection": targetDirection.rawValue],
            humanReadableExplanation: "Trend is \(trend.rawValue) with a velocity slope of \(slopePerWeek > 0 ? "+" : "")\(String(format: "%.2f", slopePerWeek))/week."
        )

        return ExplainableTrendDirection(
            metricName: metricName,
            trendDirection: trend,
            linearSlopePerDay: slopePerDay,
            linearSlopePerWeek: slopePerWeek,
            mannKendallS: s,
            rateOfChangeVelocity: slopePerWeek,
            confidenceCategory: filtered.count >= 5 ? "High Confidence" : "Preliminary",
            auditTrail: audit
        )
    }

    // MARK: - 10. Dose / Event Alignment & Pharmacodynamic Correlation

    public func calculateDoseEventAlignment(
        measurements: [Measurement],
        doseLogs: [DoseLog],
        protocols: [ProtocolModel] = [],
        metricName: String = "Metric",
        calendar: Calendar = .current
    ) -> ExplainableDoseEventAlignment {
        let takenDoses = doseLogs.filter { $0.status == .taken }.sorted(by: {
            ($0.loggedDate ?? $0.scheduledDate) < ($1.loggedDate ?? $1.scheduledDate)
        })
        let sortedM = measurements.sorted(by: { $0.timestamp < $1.timestamp })

        var preDoseVals: [Double] = []
        var post24hVals: [Double] = []
        var post48hVals: [Double] = []

        for dose in takenDoses {
            let doseTime = dose.loggedDate ?? dose.scheduledDate
            let preCutoff = doseTime.addingTimeInterval(-86400.0)
            let post24Cutoff = doseTime.addingTimeInterval(86400.0)
            let post48Cutoff = doseTime.addingTimeInterval(86400.0 * 2.0)

            let preM = sortedM.filter { $0.timestamp >= preCutoff && $0.timestamp < doseTime }
            let post24M = sortedM.filter { $0.timestamp >= doseTime && $0.timestamp < post24Cutoff }
            let post48M = sortedM.filter { $0.timestamp >= post24Cutoff && $0.timestamp < post48Cutoff }

            preDoseVals.append(contentsOf: preM.map(\.value))
            post24hVals.append(contentsOf: post24M.map(\.value))
            post48hVals.append(contentsOf: post48M.map(\.value))
        }

        let preAvg = !preDoseVals.isEmpty ? (preDoseVals.reduce(0.0, +) / Double(preDoseVals.count)) : nil
        let post24Avg = !post24hVals.isEmpty ? (post24hVals.reduce(0.0, +) / Double(post24hVals.count)) : nil
        let post48Avg = !post48hVals.isEmpty ? (post48hVals.reduce(0.0, +) / Double(post48hVals.count)) : nil

        let acuteDelta: Double?
        if let post = post24Avg, let pre = preAvg {
            acuteDelta = post - pre
        } else {
            acuteDelta = nil
        }

        let summaryText: String
        if let delta = acuteDelta {
            summaryText = "Measurements within 24h post-dose average a \(delta > 0 ? "+" : "")\(String(format: "%.1f", delta)) response compared to pre-dose baseline."
        } else {
            summaryText = "Aligned \(takenDoses.count) doses with \(sortedM.count) longitudinal measurement events."
        }

        let formula = CalculationFormula(
            name: "Dose & Event Temporal Proximity Alignment",
            expression: "PreDose = Avg(t ∈ [T_dose - 24h, T_dose]), PostDose24h = Avg(t ∈ [T_dose, T_dose + 24h])",
            variableDescriptions: ["T_dose": "Exact timestamp of administered dose"],
            methodology: "Calculates acute pharmacodynamic window response around scheduled and actual dose administrations."
        )

        let audit = CalculationAuditTrail(
            calculationName: "Dose / Event Alignment (\(metricName))",
            formula: formula,
            underlyingDataPoints: takenDoses.prefix(15).map { UnderlyingDataPoint.from(dose: $0) } + sortedM.prefix(15).map { UnderlyingDataPoint.from($0) },
            parameters: ["dosesCount": "\(takenDoses.count)", "measurementsCount": "\(sortedM.count)"],
            humanReadableExplanation: summaryText
        )

        return ExplainableDoseEventAlignment(
            metricName: metricName,
            totalAlignedEventsCount: takenDoses.count + sortedM.count,
            averagePreDoseValue: preAvg,
            averagePostDose24hValue: post24Avg,
            averagePostDose48hValue: post48Avg,
            acutePostDoseDelta: acuteDelta,
            optimalResponseLagDays: 1,
            alignmentSummaryText: summaryText,
            auditTrail: audit
        )
    }

    // MARK: - 11. Deterministic Financial Spend & Cost Metrics

    public func calculateCostMetrics(
        costs: [CostEvent],
        doses: [DoseLog] = [],
        elapsedDays: Int = 30,
        currencyCode: String = "USD"
    ) -> ExplainableCostMetrics {
        let totalSpend = costs.reduce(0.0) { $0 + $1.amount }
        let days = max(1, elapsedDays)
        let dailyBurn = totalSpend / Double(days)
        let monthlyProj = dailyBurn * 30.4375

        let takenDosesCount = max(1, doses.filter { $0.status == .taken }.count)
        let costPerDose = totalSpend / Double(takenDosesCount)
        let costPerDay = dailyBurn

        var catMap: [CostCategory: Double] = [:]
        var compMap: [String: Double] = [:]

        for c in costs {
            catMap[c.category, default: 0.0] += c.amount
            if !c.title.isEmpty {
                compMap[c.title, default: 0.0] += c.amount
            }
        }

        let formula = CalculationFormula(
            name: "Protocol Cost & Burn Rate Accounting",
            expression: "Daily Burn = Total Spend / Elapsed Days, Cost Per Dose = Total Spend / Taken Doses",
            variableDescriptions: [
                "Total Spend": "$\(String(format: "%.2f", totalSpend))",
                "Elapsed Days": "\(days) days",
                "Taken Doses": "\(takenDosesCount) doses"
            ],
            methodology: "Deterministic allocation of physical supply, compound vial, lab, and consult expenditures."
        )

        let steps: [CalculationStep] = [
            CalculationStep(
                stepNumber: 1,
                title: "Sum Total Expenditures",
                description: "Summed \(costs.count) cost events.",
                inputValues: ["Count": Double(costs.count)],
                formulaApplied: "Σ(CostEvent.amount)",
                outputValue: totalSpend,
                unit: currencyCode
            ),
            CalculationStep(
                stepNumber: 2,
                title: "Calculate Daily Burn Rate",
                description: "\(totalSpend) / \(days) elapsed days",
                inputValues: ["Total": totalSpend, "Days": Double(days)],
                formulaApplied: "Total / Days",
                outputValue: dailyBurn,
                unit: "\(currencyCode)/day"
            ),
            CalculationStep(
                stepNumber: 3,
                title: "Calculate Cost Per Delivered Dose",
                description: "\(totalSpend) / \(takenDosesCount) delivered doses",
                inputValues: ["Total": totalSpend, "Doses": Double(takenDosesCount)],
                formulaApplied: "Total / Doses",
                outputValue: costPerDose,
                unit: "\(currencyCode)/dose"
            )
        ]

        let audit = CalculationAuditTrail(
            calculationName: "Financial Cost Accounting",
            formula: formula,
            steps: steps,
            underlyingDataPoints: costs.map { UnderlyingDataPoint.from(cost: $0) },
            parameters: ["currency": currencyCode, "elapsedDays": "\(days)"],
            humanReadableExplanation: "Total spend of $\(String(format: "%.2f", totalSpend)) at a burn rate of $\(String(format: "%.2f", dailyBurn))/day ($\(String(format: "%.2f", costPerDose))/dose)."
        )

        return ExplainableCostMetrics(
            currencyCode: currencyCode,
            totalSpend: totalSpend,
            dailyBurnRate: dailyBurn,
            projectedMonthlyCost: monthlyProj,
            costPerTakenDose: costPerDose,
            costPerProtocolDay: costPerDay,
            categoryBreakdown: catMap,
            compoundSpendBreakdown: compMap,
            totalDosesDelivered: takenDosesCount,
            totalElapsedDays: days,
            auditTrail: audit
        )
    }

    // MARK: - 12. Master Analytics Report Synthesis

    public func generateMasterAnalytics(
        metric: MetricDefinition,
        measurements: [Measurement],
        doseLogs: [DoseLog] = [],
        protocols: [ProtocolModel] = [],
        costs: [CostEvent] = [],
        targetGoal: Double? = nil,
        calendar: Calendar = .current
    ) -> MasterAnalyticsReport {
        let ts = TimeSeries<Measurement>(points: measurements)

        // 1. Percentage change
        let stdPctChanges = calculateStandardPeriodChanges(
            points: measurements,
            targetDirection: metric.targetDirection,
            referenceDate: Date(),
            calendar: calendar
        )
        let primaryPctChange = stdPctChanges.first

        // 2. Absolute change
        let absChange: ExplainableAbsoluteChange?
        if let first = ts.firstPoint, let last = ts.latestPoint, first.id != last.id {
            absChange = calculateAbsoluteChange(startPoint: first, endPoint: last, periodName: "Overall")
        } else {
            absChange = nil
        }

        // 3. Averages
        let averages = calculateAverages(points: measurements, metricName: metric.name, unit: metric.defaultUnit)

        // 4. Rolling Averages
        let sma7 = calculateTimeWindowSMA(points: measurements, metricCode: metric.code, windowDays: 7, calendar: calendar)
        let sma30 = calculateTimeWindowSMA(points: measurements, metricCode: metric.code, windowDays: 30, calendar: calendar)
        let ema = calculateEMA(points: measurements, metricCode: metric.code, windowDays: 14)

        // 5. Min / Max
        let minMax = calculateMinMax(points: measurements, metricName: metric.name, unit: metric.defaultUnit)

        // 6. Adherence
        let adherence = calculateAdherence(doseLogs: doseLogs, metricDefinition: metric, measurements: measurements, calendar: calendar)

        // 7. Period Comparisons
        var comparisons: [ExplainablePeriodComparison] = []
        if protocols.count >= 2 {
            let sortedProtocols = protocols.sorted(by: { $0.startDate < $1.startDate })
            for i in 0..<(sortedProtocols.count - 1) {
                let pA = sortedProtocols[i]
                let pB = sortedProtocols[i + 1]
                let rangeA = DateInterval(start: pA.startDate, end: pA.endDate ?? Date())
                let rangeB = DateInterval(start: pB.startDate, end: pB.endDate ?? Date())
                if let comp = comparePeriods(
                    points: measurements,
                    periodA: (id: pA.id, name: pA.name, interval: rangeA),
                    periodB: (id: pB.id, name: pB.name, interval: rangeB),
                    metricDefinition: metric
                ) {
                    comparisons.append(comp)
                }
            }
        }

        // 8. Baseline difference
        let baseline = calculateBaselineDifference(
            points: measurements,
            metricName: metric.name,
            unit: metric.defaultUnit,
            baselineMode: .firstRecorded,
            targetValue: targetGoal,
            targetDirection: metric.targetDirection
        )

        // 9. Trend direction
        let trend = calculateTrendDirection(points: measurements, metricName: metric.name, targetDirection: metric.targetDirection)

        // 10. Dose / Event alignment
        let alignment = calculateDoseEventAlignment(measurements: measurements, doseLogs: doseLogs, protocols: protocols, metricName: metric.name, calendar: calendar)

        // 11. Cost metrics
        let elapsed = protocols.first?.elapsedDays ?? 30
        let costMetrics = calculateCostMetrics(costs: costs, doses: doseLogs, elapsedDays: elapsed)

        let status = baseline?.evaluationStatus ?? .insufficientData

        return MasterAnalyticsReport(
            metricDefinition: metric,
            rawMeasurementsCount: measurements.count,
            rawTimeSeries: ts,
            percentageChange: primaryPctChange,
            standardPeriodPercentageChanges: stdPctChanges,
            absoluteChange: absChange,
            averages: averages,
            rollingAverages: [sma7, sma30, ema],
            minMax: minMax,
            adherence: adherence,
            periodComparisons: comparisons,
            baselineDifference: baseline,
            trendDirection: trend,
            doseEventAlignment: alignment,
            costMetrics: costMetrics,
            evaluationStatus: status
        )
    }
}
