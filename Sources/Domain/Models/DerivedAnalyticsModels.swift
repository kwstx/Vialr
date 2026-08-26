import Foundation

// MARK: - Moving Average Models

public enum MovingAverageType: String, Codable, Sendable, CaseIterable, Identifiable {
    case simple = "Simple Moving Average (SMA)"
    case exponential = "Exponential Moving Average (EMA)"
    case timeWeighted = "Time-Weighted Moving Average"

    public var id: String { rawValue }
}

/// Represents a single smoothed data point in a derived moving average series.
/// Completely decoupled from raw measurement records to ensure immutability.
public struct MovingAveragePoint: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let rawValue: Double
    public let movingAverage: Double
    public let standardDeviation: Double?
    public let upperBand: Double? // e.g. Bollinger Upper Band (+2 std dev)
    public let lowerBand: Double? // e.g. Bollinger Lower Band (-2 std dev)
    public let sampleCountInWindow: Int

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        rawValue: Double,
        movingAverage: Double,
        standardDeviation: Double? = nil,
        upperBand: Double? = nil,
        lowerBand: Double? = nil,
        sampleCountInWindow: Int = 1
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rawValue = rawValue
        self.movingAverage = movingAverage
        self.standardDeviation = standardDeviation
        self.upperBand = upperBand
        self.lowerBand = lowerBand
        self.sampleCountInWindow = sampleCountInWindow
    }
}

/// A complete derived moving average series for a metric over a given time window.
public struct MovingAverageSeries: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricCode: String
    public let windowDays: Int
    public let calculationType: MovingAverageType
    public let points: [MovingAveragePoint]
    public let currentSmoothedValue: Double?
    public let weeklyVelocity: Double?

    public init(
        id: UUID = UUID(),
        metricCode: String,
        windowDays: Int,
        calculationType: MovingAverageType = .simple,
        points: [MovingAveragePoint] = []
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
    }
}

// MARK: - Percentage Change Analytics

public enum AnalyticsTrendDirection: String, Codable, Sendable {
    case improving = "Improving"
    case stable = "Stable / Steady"
    case regressing = "Regressing"

    public var badgeColorHex: String {
        switch self {
        case .improving: return "#10B981"
        case .stable: return "#3B82F6"
        case .regressing: return "#EF4444"
        }
    }
}

/// Represents the calculated percentage and absolute change across a specific observation period.
public struct PercentageChangeResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let periodName: String
    public let startDate: Date
    public let endDate: Date
    public let startValue: Double
    public let endValue: Double
    public let absoluteDelta: Double
    public let percentageChange: Double // e.g. -5.2%
    public let ratePerWeek: Double?
    public let trendDirection: AnalyticsTrendDirection

    public init(
        id: UUID = UUID(),
        periodName: String,
        startDate: Date,
        endDate: Date,
        startValue: Double,
        endValue: Double,
        absoluteDelta: Double,
        percentageChange: Double,
        ratePerWeek: Double? = nil,
        trendDirection: AnalyticsTrendDirection = .improving
    ) {
        self.id = id
        self.periodName = periodName
        self.startDate = startDate
        self.endDate = endDate
        self.startValue = startValue
        self.endValue = endValue
        self.absoluteDelta = absoluteDelta
        self.percentageChange = percentageChange
        self.ratePerWeek = ratePerWeek
        self.trendDirection = trendDirection
    }

    public var formattedPercentage: String {
        let sign = percentageChange > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", percentageChange))%"
    }
}

// MARK: - Baseline Difference Analytics

public enum BaselineSourceType: String, Codable, Sendable {
    case firstRecorded = "First Recorded Log"
    case preProtocolWindowAverage = "Pre-Protocol Baseline Average"
    case userSpecifiedTarget = "Target Goal Baseline"
}

/// Represents derived differences, z-scores, and goal progress relative to baseline.
public struct BaselineDifferenceResult: Identifiable, Codable, Sendable, Hashable {
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

    public init(
        id: UUID = UUID(),
        metricName: String,
        unit: String,
        baselineValue: Double,
        baselineDate: Date,
        baselineSource: BaselineSourceType = .firstRecorded,
        currentValue: Double,
        currentDate: Date,
        absoluteDifference: Double,
        percentageDifference: Double,
        zScore: Double? = nil,
        targetValue: Double? = nil,
        targetAttainmentPercentage: Double? = nil,
        isTargetAchieved: Bool = false,
        evaluationStatus: MetricEvaluationStatus = .onTrack
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
    }

    public var formattedDifference: String {
        let sign = absoluteDifference > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", absoluteDifference)) \(unit) (\(sign)\(String(format: "%.1f", percentageDifference))%)"
    }
}

// MARK: - Adherence Relationship Analytics

/// Quantifies the statistical correlation and observed impact between dose adherence and metric outcomes.
public struct AdherenceRelationshipResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricCode: String
    public let metricName: String
    public let overallAdherencePercentage: Double
    public let adherentDaysCount: Int
    public let missedDaysCount: Int
    public let highAdherenceAverageValue: Double? // Average metric value during >=80% adherence weeks
    public let lowAdherenceAverageValue: Double?  // Average metric value during <50% adherence weeks
    public let adherenceDelta: Double?            // High Adherence vs Low Adherence delta
    public let correlationCoefficient: Double?    // Pearson r correlation between weekly adherence & metric trajectory
    public let statisticalSignificance: String
    public let doseResponseLagDays: Int?          // Optimal lag interval (e.g. 1-day or 3-day post-dose peak response)
    public let clinicalInsight: String

    public init(
        id: UUID = UUID(),
        metricCode: String,
        metricName: String,
        overallAdherencePercentage: Double,
        adherentDaysCount: Int,
        missedDaysCount: Int,
        highAdherenceAverageValue: Double? = nil,
        lowAdherenceAverageValue: Double? = nil,
        adherenceDelta: Double? = nil,
        correlationCoefficient: Double? = nil,
        statisticalSignificance: String = "Observational",
        doseResponseLagDays: Int? = nil,
        clinicalInsight: String = ""
    ) {
        self.id = id
        self.metricCode = metricCode
        self.metricName = metricName
        self.overallAdherencePercentage = overallAdherencePercentage
        self.adherentDaysCount = adherentDaysCount
        self.missedDaysCount = missedDaysCount
        self.highAdherenceAverageValue = highAdherenceAverageValue
        self.lowAdherenceAverageValue = lowAdherenceAverageValue
        self.adherenceDelta = adherenceDelta
        self.correlationCoefficient = correlationCoefficient
        self.statisticalSignificance = statisticalSignificance
        self.doseResponseLagDays = doseResponseLagDays
        self.clinicalInsight = clinicalInsight
    }
}

// MARK: - Protocol-Period Comparison Analytics

/// Summary statistics for a metric during a specific protocol period or observation window.
public struct PeriodStatistics: Codable, Sendable, Hashable {
    public let periodName: String
    public let sampleCount: Int
    public let startDate: Date
    public let endDate: Date
    public let durationDays: Int
    public let firstValue: Double
    public let lastValue: Double
    public let meanValue: Double
    public let medianValue: Double
    public let minValue: Double
    public let maxValue: Double
    public let standardDeviation: Double
    public let netChange: Double
    public let percentageChange: Double
    public let weeklyVelocity: Double

    public init(
        periodName: String,
        sampleCount: Int,
        startDate: Date,
        endDate: Date,
        durationDays: Int,
        firstValue: Double,
        lastValue: Double,
        meanValue: Double,
        medianValue: Double,
        minValue: Double,
        maxValue: Double,
        standardDeviation: Double,
        netChange: Double,
        percentageChange: Double,
        weeklyVelocity: Double
    ) {
        self.periodName = periodName
        self.sampleCount = sampleCount
        self.startDate = startDate
        self.endDate = endDate
        self.durationDays = durationDays
        self.firstValue = firstValue
        self.lastValue = lastValue
        self.meanValue = meanValue
        self.medianValue = medianValue
        self.minValue = minValue
        self.maxValue = maxValue
        self.standardDeviation = standardDeviation
        self.netChange = netChange
        self.percentageChange = percentageChange
        self.weeklyVelocity = weeklyVelocity
    }
}

/// Side-by-side comparative analysis of a metric across two distinct protocol periods or protocol phases.
public struct ProtocolPeriodComparison: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricName: String
    public let unit: String
    public let protocolAId: UUID?
    public let protocolAName: String
    public let periodAStats: PeriodStatistics
    public let protocolBId: UUID?
    public let protocolBName: String
    public let periodBStats: PeriodStatistics
    public let meanDifference: Double // Mean B - Mean A
    public let meanPercentageDifference: Double
    public let velocityDifferencePerWeek: Double
    public let cohensDEffectSize: Double?
    public let superiorProtocolName: String?
    public let summaryConclusion: String

    public init(
        id: UUID = UUID(),
        metricName: String,
        unit: String,
        protocolAId: UUID? = nil,
        protocolAName: String,
        periodAStats: PeriodStatistics,
        protocolBId: UUID? = nil,
        protocolBName: String,
        periodBStats: PeriodStatistics,
        meanDifference: Double,
        meanPercentageDifference: Double,
        velocityDifferencePerWeek: Double,
        cohensDEffectSize: Double? = nil,
        superiorProtocolName: String? = nil,
        summaryConclusion: String = ""
    ) {
        self.id = id
        self.metricName = metricName
        self.unit = unit
        self.protocolAId = protocolAId
        self.protocolAName = protocolAName
        self.periodAStats = periodAStats
        self.protocolBId = protocolBId
        self.protocolBName = protocolBName
        self.periodBStats = periodBStats
        self.meanDifference = meanDifference
        self.meanPercentageDifference = meanPercentageDifference
        self.velocityDifferencePerWeek = velocityDifferencePerWeek
        self.cohensDEffectSize = cohensDEffectSize
        self.superiorProtocolName = superiorProtocolName
        self.summaryConclusion = summaryConclusion
    }
}

// MARK: - Comprehensive Metric Analytics Report

/// Master analytical synthesis packaging all derived intelligence for a single metric.
/// Guarantees that raw data points are preserved separately and never overwritten.
public struct ComprehensiveMetricAnalytics: Identifiable, Sendable {
    public var id: UUID { definition.id }
    public let definition: MetricDefinition
    public let rawMeasurementsCount: Int
    public let rawTimeSeries: TimeSeries<Measurement>
    public let baselineResult: BaselineDifferenceResult?
    public let movingAverages: [MovingAverageSeries]
    public let percentageChanges: [PercentageChangeResult]
    public let adherenceRelationship: AdherenceRelationshipResult?
    public let protocolComparisons: [ProtocolPeriodComparison]
    public let evaluationStatus: MetricEvaluationStatus

    public init(
        definition: MetricDefinition,
        rawMeasurementsCount: Int,
        rawTimeSeries: TimeSeries<Measurement>,
        baselineResult: BaselineDifferenceResult? = nil,
        movingAverages: [MovingAverageSeries] = [],
        percentageChanges: [PercentageChangeResult] = [],
        adherenceRelationship: AdherenceRelationshipResult? = nil,
        protocolComparisons: [ProtocolPeriodComparison] = [],
        evaluationStatus: MetricEvaluationStatus = .onTrack
    ) {
        self.definition = definition
        self.rawMeasurementsCount = rawMeasurementsCount
        self.rawTimeSeries = rawTimeSeries
        self.baselineResult = baselineResult
        self.movingAverages = movingAverages
        self.percentageChanges = percentageChanges
        self.adherenceRelationship = adherenceRelationship
        self.protocolComparisons = protocolComparisons
        self.evaluationStatus = evaluationStatus
    }
}
