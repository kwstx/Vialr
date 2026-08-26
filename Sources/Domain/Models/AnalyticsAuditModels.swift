import Foundation

// MARK: - 1. Core Audit Trail & Explainability Models

/// Represents the mathematical formula and methodology used for a deterministic calculation.
public struct CalculationFormula: Codable, Sendable, Hashable {
    public let name: String
    public let expression: String
    public let variableDescriptions: [String: String]
    public let methodology: String

    public init(
        name: String,
        expression: String,
        variableDescriptions: [String: String] = [:],
        methodology: String = ""
    ) {
        self.name = name
        self.expression = expression
        self.variableDescriptions = variableDescriptions
        self.methodology = methodology
    }
}

/// Represents an individual step in the deterministic computation trace.
public struct CalculationStep: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let stepNumber: Int
    public let title: String
    public let description: String
    public let inputValues: [String: Double]
    public let formulaApplied: String
    public let outputValue: Double
    public let unit: String?

    public init(
        id: UUID = UUID(),
        stepNumber: Int,
        title: String,
        description: String,
        inputValues: [String: Double] = [:],
        formulaApplied: String = "",
        outputValue: Double,
        unit: String? = nil
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.title = title
        self.description = description
        self.inputValues = inputValues
        self.formulaApplied = formulaApplied
        self.outputValue = outputValue
        self.unit = unit
    }
}

/// Represents a standardized snapshot of a raw data point that fed into a calculation.
/// Enables full drill-down transparency to the underlying physical/recorded event.
public struct UnderlyingDataPoint: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let originalRecordId: UUID
    public let recordType: String // e.g. "Measurement", "DoseEvent", "CostEvent", "Biomarker"
    public let timestamp: Date
    public let value: Double
    public let secondaryValue: Double?
    public let unit: String
    public let label: String
    public let source: String
    public let notes: String
    public let isOutlierOrExcluded: Bool

    public init(
        id: UUID = UUID(),
        originalRecordId: UUID,
        recordType: String,
        timestamp: Date,
        value: Double,
        secondaryValue: Double? = nil,
        unit: String,
        label: String = "",
        source: String = "Manual",
        notes: String = "",
        isOutlierOrExcluded: Bool = false
    ) {
        self.id = id
        self.originalRecordId = originalRecordId
        self.recordType = recordType
        self.timestamp = timestamp
        self.value = value
        self.secondaryValue = secondaryValue
        self.unit = unit
        self.label = label
        self.source = source
        self.notes = notes
        self.isOutlierOrExcluded = isOutlierOrExcluded
    }

    /// Convenience converter from any `TimeSeriesDataPoint`
    public static func from<P: TimeSeriesDataPoint>(_ point: P, recordType: String = "Measurement", label: String = "") -> UnderlyingDataPoint {
        UnderlyingDataPoint(
            originalRecordId: point.id,
            recordType: recordType,
            timestamp: point.timestamp,
            value: point.value,
            secondaryValue: point.secondaryValue,
            unit: point.unit,
            label: label.isEmpty ? point.notes : label,
            source: point.source.rawValue,
            notes: point.notes
        )
    }

    /// Convenience converter from `Measurement`
    public static func from(measurement: Measurement) -> UnderlyingDataPoint {
        UnderlyingDataPoint(
            originalRecordId: measurement.id,
            recordType: "Measurement",
            timestamp: measurement.dateRecorded,
            value: measurement.value,
            secondaryValue: measurement.secondaryValue,
            unit: measurement.unit,
            label: measurement.name,
            source: measurement.source.rawValue,
            notes: measurement.notes
        )
    }

    /// Convenience converter from `DoseEvent`
    public static func from(dose: DoseEvent) -> UnderlyingDataPoint {
        UnderlyingDataPoint(
            originalRecordId: dose.id,
            recordType: "DoseEvent",
            timestamp: dose.actualTimestamp ?? dose.scheduledTimestamp,
            value: dose.actualDoseAmount,
            secondaryValue: dose.plannedDoseAmount,
            unit: dose.doseUnit.symbol,
            label: "\(dose.compoundName) (\(dose.status.rawValue))",
            source: dose.actualRoute.rawValue,
            notes: dose.notes
        )
    }

    /// Convenience converter from `CostEvent`
    public static func from(cost: CostEvent) -> UnderlyingDataPoint {
        UnderlyingDataPoint(
            originalRecordId: cost.id,
            recordType: "CostEvent",
            timestamp: cost.dateIncurred,
            value: cost.amount,
            unit: cost.currencyCode,
            label: "\(cost.title) [\(cost.category.rawValue)]",
            source: cost.vendor,
            notes: cost.notes
        )
    }
}

/// A comprehensive audit trail providing complete explainability for any derived analytical metric.
public struct CalculationAuditTrail: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let calculationName: String
    public let calculatedAt: Date
    public let formula: CalculationFormula
    public let steps: [CalculationStep]
    public let underlyingDataPoints: [UnderlyingDataPoint]
    public let parameters: [String: String]
    public let sampleSize: Int
    public let humanReadableExplanation: String

    public init(
        id: UUID = UUID(),
        calculationName: String,
        calculatedAt: Date = Date(),
        formula: CalculationFormula,
        steps: [CalculationStep] = [],
        underlyingDataPoints: [UnderlyingDataPoint] = [],
        parameters: [String: String] = [:],
        humanReadableExplanation: String = ""
    ) {
        self.id = id
        self.calculationName = calculationName
        self.calculatedAt = calculatedAt
        self.formula = formula
        self.steps = steps
        self.underlyingDataPoints = underlyingDataPoints
        self.parameters = parameters
        self.sampleSize = underlyingDataPoints.count
        self.humanReadableExplanation = humanReadableExplanation
    }
}

/// Generic wrapper that pairs any computed value with its full deterministic audit trail.
public struct ExplainableResult<T: Sendable & Codable & Hashable>: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let value: T
    public let auditTrail: CalculationAuditTrail

    public init(
        id: UUID = UUID(),
        value: T,
        auditTrail: CalculationAuditTrail
    ) {
        self.id = id
        self.value = value
        self.auditTrail = auditTrail
    }
}

// MARK: - 2. Specific Calculation Result Models

/// 1. Percentage Change Result with audit trail.
public struct ExplainablePercentageChange: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let periodName: String
    public let startDate: Date
    public let endDate: Date
    public let startValue: Double
    public let endValue: Double
    public let absoluteDelta: Double
    public let percentageChange: Double // e.g. -5.2%
    public let ratePerDay: Double?
    public let ratePerWeek: Double?
    public let trendDirection: AnalyticsTrendDirection
    public let auditTrail: CalculationAuditTrail

    public init(
        id: UUID = UUID(),
        periodName: String,
        startDate: Date,
        endDate: Date,
        startValue: Double,
        endValue: Double,
        absoluteDelta: Double,
        percentageChange: Double,
        ratePerDay: Double? = nil,
        ratePerWeek: Double? = nil,
        trendDirection: AnalyticsTrendDirection = .improving,
        auditTrail: CalculationAuditTrail
    ) {
        self.id = id
        self.periodName = periodName
        self.startDate = startDate
        self.endDate = endDate
        self.startValue = startValue
        self.endValue = endValue
        self.absoluteDelta = absoluteDelta
        self.percentageChange = percentageChange
        self.ratePerDay = ratePerDay
        self.ratePerWeek = ratePerWeek
        self.trendDirection = trendDirection
        self.auditTrail = auditTrail
    }

    public var formattedPercentage: String {
        let sign = percentageChange > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", percentageChange))%"
    }
}

/// 2. Absolute Change Result with audit trail.
public struct ExplainableAbsoluteChange: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let periodName: String
    public let unit: String
    public let startValue: Double
    public let endValue: Double
    public let delta: Double
    public let ratePerDay: Double?
    public let ratePerWeek: Double?
    public let auditTrail: CalculationAuditTrail

    public init(
        id: UUID = UUID(),
        periodName: String,
        unit: String,
        startValue: Double,
        endValue: Double,
        delta: Double,
        ratePerDay: Double? = nil,
        ratePerWeek: Double? = nil,
        auditTrail: CalculationAuditTrail
    ) {
        self.id = id
        self.periodName = periodName
        self.unit = unit
        self.startValue = startValue
        self.endValue = endValue
        self.delta = delta
        self.ratePerDay = ratePerDay
        self.ratePerWeek = ratePerWeek
        self.auditTrail = auditTrail
    }

    public var formattedDelta: String {
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", delta)) \(unit)"
    }
}

/// 3. Deterministic Averages & Statistical Moments.
public struct ExplainableAverages: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricName: String
    public let unit: String
    public let sampleCount: Int
    public let arithmeticMean: Double
    public let median: Double
    public let weightedAverage: Double?
    public let trimmedMean: Double? // Trimmed (e.g. 10% outer percentiles excluded)
    public let geometricMean: Double?
    public let variance: Double
    public let standardDeviation: Double
    public let standardError: Double
    public let auditTrail: CalculationAuditTrail

    public init(
        id: UUID = UUID(),
        metricName: String,
        unit: String,
        sampleCount: Int,
        arithmeticMean: Double,
        median: Double,
        weightedAverage: Double? = nil,
        trimmedMean: Double? = nil,
        geometricMean: Double? = nil,
        variance: Double = 0.0,
        standardDeviation: Double = 0.0,
        standardError: Double = 0.0,
        auditTrail: CalculationAuditTrail
    ) {
        self.id = id
        self.metricName = metricName
        self.unit = unit
        self.sampleCount = sampleCount
        self.arithmeticMean = arithmeticMean
        self.median = median
        self.weightedAverage = weightedAverage
        self.trimmedMean = trimmedMean
        self.geometricMean = geometricMean
        self.variance = variance
        self.standardDeviation = standardDeviation
        self.standardError = standardError
        self.auditTrail = auditTrail
    }
}

/// 4. Rolling Averages & Moving Windows (SMA, EMA, Bollinger bands).
public struct ExplainableRollingAverages: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricCode: String
    public let windowDays: Int
    public let calculationType: MovingAverageType
    public let points: [MovingAveragePoint]
    public let currentSmoothedValue: Double?
    public let weeklyVelocity: Double?
    public let auditTrail: CalculationAuditTrail

    public init(
        id: UUID = UUID(),
        metricCode: String,
        windowDays: Int,
        calculationType: MovingAverageType,
        points: [MovingAveragePoint],
        auditTrail: CalculationAuditTrail
    ) {
        self.id = id
        self.metricCode = metricCode
        self.windowDays = windowDays
        self.calculationType = calculationType
        self.points = points
        self.currentSmoothedValue = points.last?.movingAverage
        if points.count >= 2, let first = points.first, let last = points.last {
            let days = max(1.0, last.timestamp.timeIntervalSince(first.timestamp) / 86400.0)
            let weeks = days / 7.0
            self.weeklyVelocity = (last.movingAverage - first.movingAverage) / weeks
        } else {
            self.weeklyVelocity = nil
        }
        self.auditTrail = auditTrail
    }
}

/// 5. Deterministic Minimum / Maximum & Percentiles.
public struct ExplainableMinMax: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricName: String
    public let unit: String
    public let sampleCount: Int
    public let minValue: Double
    public let minDate: Date
    public let maxValue: Double
    public let maxDate: Date
    public let rangeSpan: Double // Max - Min
    public let p25Value: Double?
    public let p50Median: Double
    public let p75Value: Double?
    public let p90Value: Double?
    public let p95Value: Double?
    public let interquartileRange: Double?
    public let auditTrail: CalculationAuditTrail

    public init(
        id: UUID = UUID(),
        metricName: String,
        unit: String,
        sampleCount: Int,
        minValue: Double,
        minDate: Date,
        maxValue: Double,
        maxDate: Date,
        rangeSpan: Double,
        p25Value: Double? = nil,
        p50Median: Double,
        p75Value: Double? = nil,
        p90Value: Double? = nil,
        p95Value: Double? = nil,
        interquartileRange: Double? = nil,
        auditTrail: CalculationAuditTrail
    ) {
        self.id = id
        self.metricName = metricName
        self.unit = unit
        self.sampleCount = sampleCount
        self.minValue = minValue
        self.minDate = minDate
        self.maxValue = maxValue
        self.maxDate = maxDate
        self.rangeSpan = rangeSpan
        self.p25Value = p25Value
        self.p50Median = p50Median
        self.p75Value = p75Value
        self.p90Value = p90Value
        self.p95Value = p95Value
        self.interquartileRange = interquartileRange
        self.auditTrail = auditTrail
    }
}

/// 6. Deterministic Protocol Adherence & Streak Analytics.
public struct ExplainableAdherence: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let overallAdherencePercentage: Double
    public let totalScheduledDoses: Int
    public let totalTakenDoses: Int
    public let totalSkippedDoses: Int
    public let totalMissedDoses: Int
    public let totalPartialDoses: Int
    public let onTimePercentage: Double // Doses taken within tolerance window
    public let averageTimingVarianceMinutes: Double?
    public let currentStreakDays: Int
    public let longestStreakDays: Int
    public let compoundBreakdown: [String: Double]
    public let highAdherenceCohortAvgMetric: Double? // Avg metric during >=80% adherence weeks
    public let lowAdherenceCohortAvgMetric: Double?  // Avg metric during <80% adherence weeks
    public let adherenceDelta: Double?
    public let auditTrail: CalculationAuditTrail

    public init(
        id: UUID = UUID(),
        overallAdherencePercentage: Double,
        totalScheduledDoses: Int,
        totalTakenDoses: Int,
        totalSkippedDoses: Int,
        totalMissedDoses: Int,
        totalPartialDoses: Int = 0,
        onTimePercentage: Double = 100.0,
        averageTimingVarianceMinutes: Double? = nil,
        currentStreakDays: Int = 0,
        longestStreakDays: Int = 0,
        compoundBreakdown: [String: Double] = [:],
        highAdherenceCohortAvgMetric: Double? = nil,
        lowAdherenceCohortAvgMetric: Double? = nil,
        adherenceDelta: Double? = nil,
        auditTrail: CalculationAuditTrail
    ) {
        self.id = id
        self.overallAdherencePercentage = overallAdherencePercentage
        self.totalScheduledDoses = totalScheduledDoses
        self.totalTakenDoses = totalTakenDoses
        self.totalSkippedDoses = totalSkippedDoses
        self.totalMissedDoses = totalMissedDoses
        self.totalPartialDoses = totalPartialDoses
        self.onTimePercentage = onTimePercentage
        self.averageTimingVarianceMinutes = averageTimingVarianceMinutes
        self.currentStreakDays = currentStreakDays
        self.longestStreakDays = longestStreakDays
        self.compoundBreakdown = compoundBreakdown
        self.highAdherenceCohortAvgMetric = highAdherenceCohortAvgMetric
        self.lowAdherenceCohortAvgMetric = lowAdherenceCohortAvgMetric
        self.adherenceDelta = adherenceDelta
        self.auditTrail = auditTrail
    }
}

/// 7. Deterministic Period Comparisons (Side-by-Side).
public struct ExplainablePeriodComparison: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricName: String
    public let unit: String
    public let periodAName: String
    public let periodAStats: PeriodStatistics
    public let periodBName: String
    public let periodBStats: PeriodStatistics
    public let meanDifference: Double // Mean B - Mean A
    public let meanPercentageDifference: Double
    public let velocityDifferencePerWeek: Double
    public let cohensDEffectSize: Double?
    public let superiorPeriodName: String?
    public let summaryConclusion: String
    public let auditTrail: CalculationAuditTrail

    public init(
        id: UUID = UUID(),
        metricName: String,
        unit: String,
        periodAName: String,
        periodAStats: PeriodStatistics,
        periodBName: String,
        periodBStats: PeriodStatistics,
        meanDifference: Double,
        meanPercentageDifference: Double,
        velocityDifferencePerWeek: Double,
        cohensDEffectSize: Double? = nil,
        superiorPeriodName: String? = nil,
        summaryConclusion: String = "",
        auditTrail: CalculationAuditTrail
    ) {
        self.id = id
        self.metricName = metricName
        self.unit = unit
        self.periodAName = periodAName
        self.periodAStats = periodAStats
        self.periodBName = periodBName
        self.periodBStats = periodBStats
        self.meanDifference = meanDifference
        self.meanPercentageDifference = meanPercentageDifference
        self.velocityDifferencePerWeek = velocityDifferencePerWeek
        self.cohensDEffectSize = cohensDEffectSize
        self.superiorPeriodName = superiorPeriodName
        self.summaryConclusion = summaryConclusion
        self.auditTrail = auditTrail
    }
}

/// 8. Deterministic Baseline Difference Result.
public struct ExplainableBaselineDifference: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricName: String
    public let unit: String
    public let baselineValue: Double
    public let baselineDate: Date
    public let baselineSource: BaselineSourceType
    public let currentValue: Double
    public let currentDate: Date
    public let absoluteDifference: Double
    public let percentageDifference: Double
    public let zScore: Double?
    public let targetValue: Double?
    public let targetAttainmentPercentage: Double?
    public let isTargetAchieved: Bool
    public let evaluationStatus: MetricEvaluationStatus
    public let auditTrail: CalculationAuditTrail

    public init(
        id: UUID = UUID(),
        metricName: String,
        unit: String,
        baselineValue: Double,
        baselineDate: Date,
        baselineSource: BaselineSourceType,
        currentValue: Double,
        currentDate: Date,
        absoluteDifference: Double,
        percentageDifference: Double,
        zScore: Double? = nil,
        targetValue: Double? = nil,
        targetAttainmentPercentage: Double? = nil,
        isTargetAchieved: Bool = false,
        evaluationStatus: MetricEvaluationStatus = .onTrack,
        auditTrail: CalculationAuditTrail
    ) {
        self.id = id
        self.metricName = metricName
        self.unit = unit
        self.baselineValue = baselineValue
        self.baselineDate = baselineDate
        self.baselineSource = baselineSource
        self.currentValue = currentValue
        self.currentDate = currentDate
        self.absoluteDifference = absoluteDifference
        self.percentageDifference = percentageDifference
        self.zScore = zScore
        self.targetValue = targetValue
        self.targetAttainmentPercentage = targetAttainmentPercentage
        self.isTargetAchieved = isTargetAchieved
        self.evaluationStatus = evaluationStatus
        self.auditTrail = auditTrail
    }

    public var formattedDifference: String {
        let sign = absoluteDifference > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", absoluteDifference)) \(unit) (\(sign)\(String(format: "%.1f", percentageDifference))%)"
    }
}

/// 9. Deterministic Trend Direction & Linear Slope.
public struct ExplainableTrendDirection: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricName: String
    public let trendDirection: AnalyticsTrendDirection
    public let linearSlopePerDay: Double // Linear regression slope m
    public let linearSlopePerWeek: Double
    public let rSquared: Double? // Goodness of linear fit
    public let mannKendallS: Int? // Non-parametric monotonic trend statistic
    public let rateOfChangeVelocity: Double
    public let confidenceCategory: String
    public let auditTrail: CalculationAuditTrail

    public init(
        id: UUID = UUID(),
        metricName: String,
        trendDirection: AnalyticsTrendDirection,
        linearSlopePerDay: Double,
        linearSlopePerWeek: Double,
        rSquared: Double? = nil,
        mannKendallS: Int? = nil,
        rateOfChangeVelocity: Double,
        confidenceCategory: String = "High",
        auditTrail: CalculationAuditTrail
    ) {
        self.id = id
        self.metricName = metricName
        self.trendDirection = trendDirection
        self.linearSlopePerDay = linearSlopePerDay
        self.linearSlopePerWeek = linearSlopePerWeek
        self.rSquared = rSquared
        self.mannKendallS = mannKendallS
        self.rateOfChangeVelocity = rateOfChangeVelocity
        self.confidenceCategory = confidenceCategory
        self.auditTrail = auditTrail
    }
}

/// 10. Dose / Event Alignment & Pharmacodynamic Correlation.
public struct ExplainableDoseEventAlignment: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricName: String
    public let totalAlignedEventsCount: Int
    public let averagePreDoseValue: Double?
    public let averagePostDose24hValue: Double?
    public let averagePostDose48hValue: Double?
    public let acutePostDoseDelta: Double?
    public let optimalResponseLagDays: Int?
    public let correlationWithDoseAmount: Double? // Pearson r between administered dose mg and acute outcome delta
    public let alignmentSummaryText: String
    public let auditTrail: CalculationAuditTrail

    public init(
        id: UUID = UUID(),
        metricName: String,
        totalAlignedEventsCount: Int,
        averagePreDoseValue: Double? = nil,
        averagePostDose24hValue: Double? = nil,
        averagePostDose48hValue: Double? = nil,
        acutePostDoseDelta: Double? = nil,
        optimalResponseLagDays: Int? = nil,
        correlationWithDoseAmount: Double? = nil,
        alignmentSummaryText: String = "",
        auditTrail: CalculationAuditTrail
    ) {
        self.id = id
        self.metricName = metricName
        self.totalAlignedEventsCount = totalAlignedEventsCount
        self.averagePreDoseValue = averagePreDoseValue
        self.averagePostDose24hValue = averagePostDose24hValue
        self.averagePostDose48hValue = averagePostDose48hValue
        self.acutePostDoseDelta = acutePostDoseDelta
        self.optimalResponseLagDays = optimalResponseLagDays
        self.correlationWithDoseAmount = correlationWithDoseAmount
        self.alignmentSummaryText = alignmentSummaryText
        self.auditTrail = auditTrail
    }
}

/// 11. Deterministic Financial Spend & Cost Metrics.
public struct ExplainableCostMetrics: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let currencyCode: String
    public let totalSpend: Double
    public let dailyBurnRate: Double
    public let projectedMonthlyCost: Double
    public let costPerTakenDose: Double
    public let costPerProtocolDay: Double
    public let categoryBreakdown: [CostCategory: Double]
    public let compoundSpendBreakdown: [String: Double]
    public let totalDosesDelivered: Int
    public let totalElapsedDays: Int
    public let auditTrail: CalculationAuditTrail

    public init(
        id: UUID = UUID(),
        currencyCode: String = "USD",
        totalSpend: Double,
        dailyBurnRate: Double,
        projectedMonthlyCost: Double,
        costPerTakenDose: Double,
        costPerProtocolDay: Double,
        categoryBreakdown: [CostCategory: Double] = [:],
        compoundSpendBreakdown: [String: Double] = [:],
        totalDosesDelivered: Int,
        totalElapsedDays: Int,
        auditTrail: CalculationAuditTrail
    ) {
        self.id = id
        self.currencyCode = currencyCode
        self.totalSpend = totalSpend
        self.dailyBurnRate = dailyBurnRate
        self.projectedMonthlyCost = projectedMonthlyCost
        self.costPerTakenDose = costPerTakenDose
        self.costPerProtocolDay = costPerProtocolDay
        self.categoryBreakdown = categoryBreakdown
        self.compoundSpendBreakdown = compoundSpendBreakdown
        self.totalDosesDelivered = totalDosesDelivered
        self.totalElapsedDays = totalElapsedDays
        self.auditTrail = auditTrail
    }

    public var formattedTotalSpend: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: totalSpend)) ?? "$\(String(format: "%.2f", totalSpend))"
    }

    public var formattedDailyBurn: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return "\(formatter.string(from: NSNumber(value: dailyBurnRate)) ?? "$\(String(format: "%.2f", dailyBurnRate))")/day"
    }
}

// MARK: - 12. Master Analytics Report

/// Master analytical synthesis containing all 11 deterministic calculation modules,
/// each guaranteed to carry full underlying data audit trails for non-destructive drill-down.
public struct MasterAnalyticsReport: Identifiable, Sendable {
    public let id: UUID
    public let metricDefinition: MetricDefinition
    public let rawMeasurementsCount: Int
    public let rawTimeSeries: TimeSeries<Measurement>
    public let percentageChange: ExplainablePercentageChange?
    public let standardPeriodPercentageChanges: [ExplainablePercentageChange]
    public let absoluteChange: ExplainableAbsoluteChange?
    public let averages: ExplainableAverages?
    public let rollingAverages: [ExplainableRollingAverages]
    public let minMax: ExplainableMinMax?
    public let adherence: ExplainableAdherence?
    public let periodComparisons: [ExplainablePeriodComparison]
    public let baselineDifference: ExplainableBaselineDifference?
    public let trendDirection: ExplainableTrendDirection?
    public let doseEventAlignment: ExplainableDoseEventAlignment?
    public let costMetrics: ExplainableCostMetrics?
    public let evaluationStatus: MetricEvaluationStatus

    public init(
        id: UUID = UUID(),
        metricDefinition: MetricDefinition,
        rawMeasurementsCount: Int,
        rawTimeSeries: TimeSeries<Measurement>,
        percentageChange: ExplainablePercentageChange? = nil,
        standardPeriodPercentageChanges: [ExplainablePercentageChange] = [],
        absoluteChange: ExplainableAbsoluteChange? = nil,
        averages: ExplainableAverages? = nil,
        rollingAverages: [ExplainableRollingAverages] = [],
        minMax: ExplainableMinMax? = nil,
        adherence: ExplainableAdherence? = nil,
        periodComparisons: [ExplainablePeriodComparison] = [],
        baselineDifference: ExplainableBaselineDifference? = nil,
        trendDirection: ExplainableTrendDirection? = nil,
        doseEventAlignment: ExplainableDoseEventAlignment? = nil,
        costMetrics: ExplainableCostMetrics? = nil,
        evaluationStatus: MetricEvaluationStatus = .onTrack
    ) {
        self.id = id
        self.metricDefinition = metricDefinition
        self.rawMeasurementsCount = rawMeasurementsCount
        self.rawTimeSeries = rawTimeSeries
        self.percentageChange = percentageChange
        self.standardPeriodPercentageChanges = standardPeriodPercentageChanges
        self.absoluteChange = absoluteChange
        self.averages = averages
        self.rollingAverages = rollingAverages
        self.minMax = minMax
        self.adherence = adherence
        self.periodComparisons = periodComparisons
        self.baselineDifference = baselineDifference
        self.trendDirection = trendDirection
        self.doseEventAlignment = doseEventAlignment
        self.costMetrics = costMetrics
        self.evaluationStatus = evaluationStatus
    }
}
