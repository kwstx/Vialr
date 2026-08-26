import Foundation

// MARK: - Comparison Period Inputs & Metadata

/// Target period specification for comparing protocols or date ranges.
public enum ComparisonPeriodInput: Sendable, Hashable {
    case protocols(protocolAId: UUID, protocolBId: UUID)
    case protocolModels(protocolA: ProtocolModel, protocolB: ProtocolModel)
    case dateRanges(rangeA: DateInterval, rangeB: DateInterval, nameA: String = "Period A", nameB: String = "Period B")
    case protocolVsBaseline(protocolId: UUID, baselineDays: Int = 30)
}

/// Metadata and calendar boundaries for a comparison period.
public struct ProtocolComparisonPeriod: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let protocolId: UUID?
    public let name: String
    public let startDate: Date
    public let endDate: Date
    public let compounds: [ProtocolCompound]
    public let goalSummary: String
    public let colorHex: String

    public var interval: DateInterval {
        DateInterval(start: startDate, end: endDate)
    }

    public var durationDays: Int {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(1, days)
    }

    public init(
        id: UUID = UUID(),
        protocolId: UUID? = nil,
        name: String,
        startDate: Date,
        endDate: Date,
        compounds: [ProtocolCompound] = [],
        goalSummary: String = "",
        colorHex: String = "#10B981"
    ) {
        self.id = id
        self.protocolId = protocolId
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.compounds = compounds
        self.goalSummary = goalSummary
        self.colorHex = colorHex
    }

    public static func fromProtocol(_ proto: ProtocolModel, fallbackEndDate: Date = Date()) -> ProtocolComparisonPeriod {
        ProtocolComparisonPeriod(
            protocolId: proto.id,
            name: proto.name,
            startDate: proto.startDate,
            endDate: proto.endDate ?? fallbackEndDate,
            compounds: proto.compounds,
            goalSummary: proto.goalSummary,
            colorHex: proto.colorHex
        )
    }

    public static func fromInterval(_ interval: DateInterval, name: String, colorHex: String = "#3B82F6") -> ProtocolComparisonPeriod {
        ProtocolComparisonPeriod(
            protocolId: nil,
            name: name,
            startDate: interval.start,
            endDate: interval.end,
            compounds: [],
            goalSummary: "",
            colorHex: colorHex
        )
    }
}

// MARK: - Descriptive Statistics

/// Comprehensive mathematical descriptive statistics for a time-series metric within a specific period.
public struct DescriptiveStatistics: Codable, Sendable, Hashable {
    public let sampleCount: Int
    public let startDate: Date
    public let endDate: Date
    public let durationDays: Int
    public let firstValue: Double
    public let lastValue: Double
    public let minValue: Double
    public let maxValue: Double
    public let range: Double
    public let meanValue: Double
    public let medianValue: Double
    public let standardDeviation: Double
    public let variance: Double
    public let q1: Double
    public let q3: Double
    public let iqr: Double
    public let netChange: Double
    public let percentageChange: Double
    public let ratePerDay: Double
    public let weeklyVelocity: Double
    public let loggingFrequencyPerWeek: Double

    public init(
        sampleCount: Int,
        startDate: Date,
        endDate: Date,
        durationDays: Int,
        firstValue: Double,
        lastValue: Double,
        minValue: Double,
        maxValue: Double,
        meanValue: Double,
        medianValue: Double,
        standardDeviation: Double,
        variance: Double,
        q1: Double,
        q3: Double,
        iqr: Double,
        netChange: Double,
        percentageChange: Double,
        ratePerDay: Double,
        weeklyVelocity: Double,
        loggingFrequencyPerWeek: Double
    ) {
        self.sampleCount = sampleCount
        self.startDate = startDate
        self.endDate = endDate
        self.durationDays = durationDays
        self.firstValue = firstValue
        self.lastValue = lastValue
        self.minValue = minValue
        self.maxValue = maxValue
        self.range = maxValue - minValue
        self.meanValue = meanValue
        self.medianValue = medianValue
        self.standardDeviation = standardDeviation
        self.variance = variance
        self.q1 = q1
        self.q3 = q3
        self.iqr = iqr
        self.netChange = netChange
        self.percentageChange = percentageChange
        self.ratePerDay = ratePerDay
        self.weeklyVelocity = weeklyVelocity
        self.loggingFrequencyPerWeek = loggingFrequencyPerWeek
    }
}

// MARK: - Non-Causality Framework

/// Explicitly categorizes analytical outputs to avoid claiming proof of causation.
public enum CausalityClassification: String, Codable, Sendable, CaseIterable {
    case observationalAssociationOnly = "Observational Association (Non-Causal)"
    case longitudinalCoVariation = "Longitudinal Co-Variation"
    case hypothesisGenerating = "Hypothesis Generating"

    public var badgeLabel: String { rawValue }
    public var disclaimer: String {
        "This comparison represents observed real-world time-series data and observational associations. Longitudinal variations do not constitute proof of pharmacological causation due to potential confounding lifestyle, dietary, physical, recovery, and biological variables."
    }
}

/// Qualitative direction of comparative trajectory.
public enum TrajectoryAssessment: String, Codable, Sendable, CaseIterable {
    case superiorPeriodB = "Period B Favorable"
    case superiorPeriodA = "Period A Favorable"
    case comparable = "Comparable Trajectory"
    case divergent = "Divergent Trends"
    case inconclusive = "Inconclusive / Insufficient Data"

    public var badgeColorHex: String {
        switch self {
        case .superiorPeriodB, .superiorPeriodA: return "#10B981"
        case .comparable: return "#3B82F6"
        case .divergent: return "#F59E0B"
        case .inconclusive: return "#6B7280"
        }
    }
}

/// Confidence rating in the statistical reliability of the comparison.
public enum ComparisonConfidence: String, Codable, Sendable, CaseIterable {
    case high = "High Sample Density"
    case moderate = "Moderate Sample Density"
    case preliminary = "Preliminary Trend (Low Samples)"
    case insufficientData = "Insufficient Data"

    public var badgeColorHex: String {
        switch self {
        case .high: return "#10B981"
        case .moderate: return "#3B82F6"
        case .preliminary: return "#F59E0B"
        case .insufficientData: return "#EF4444"
        }
    }
}

// MARK: - Empirical Observed Change

/// Pure, strictly mathematical and empirical delta between two periods.
/// Completely decoupled from qualitative judgment to preserve scientific and clinical integrity.
public struct ObservedChange: Codable, Sendable, Hashable {
    public let metricCode: String
    public let metricName: String
    public let unit: String
    public let periodAStats: DescriptiveStatistics
    public let periodBStats: DescriptiveStatistics
    public let meanDifference: Double // Mean(B) - Mean(A)
    public let meanPercentageDifference: Double
    public let netChangeDifference: Double // Net(B) - Net(A)
    public let velocityDifferencePerWeek: Double // Vel(B) - Vel(A)
    public let cohensDEffectSize: Double? // Standardized Mean Difference
    public let tStatistic: Double? // Welch's Two-Sample t-statistic
    public let approximatePValue: Double? // Approximate two-tailed p-value
    public let varianceRatio: Double? // F = Var(B) / Var(A)
    public let sampleCountA: Int
    public let sampleCountB: Int

    public init(
        metricCode: String,
        metricName: String,
        unit: String,
        periodAStats: DescriptiveStatistics,
        periodBStats: DescriptiveStatistics,
        meanDifference: Double,
        meanPercentageDifference: Double,
        netChangeDifference: Double,
        velocityDifferencePerWeek: Double,
        cohensDEffectSize: Double? = nil,
        tStatistic: Double? = nil,
        approximatePValue: Double? = nil,
        varianceRatio: Double? = nil
    ) {
        self.metricCode = metricCode
        self.metricName = metricName
        self.unit = unit
        self.periodAStats = periodAStats
        self.periodBStats = periodBStats
        self.meanDifference = meanDifference
        self.meanPercentageDifference = meanPercentageDifference
        self.netChangeDifference = netChangeDifference
        self.velocityDifferencePerWeek = velocityDifferencePerWeek
        self.cohensDEffectSize = cohensDEffectSize
        self.tStatistic = tStatistic
        self.approximatePValue = approximatePValue
        self.varianceRatio = varianceRatio
        self.sampleCountA = periodAStats.sampleCount
        self.sampleCountB = periodBStats.sampleCount
    }
}

// MARK: - Contextual Interpretation

/// Qualitative and clinical context explicitly isolated from empirical observed change.
/// Invariably carries non-causality disclaimers and confounding variable disclosures.
public struct ComparisonInterpretation: Codable, Sendable, Hashable {
    public let narrativeSummary: String
    public let trajectoryAssessment: TrajectoryAssessment
    public let confidenceLevel: ComparisonConfidence
    public let potentialConfounders: [String]
    public let nonCausalityDisclaimer: String
    public let causalityClassification: CausalityClassification
    public let recommendedFollowUp: [String]

    public init(
        narrativeSummary: String,
        trajectoryAssessment: TrajectoryAssessment,
        confidenceLevel: ComparisonConfidence,
        potentialConfounders: [String] = [],
        nonCausalityDisclaimer: String = CausalityClassification.observationalAssociationOnly.disclaimer,
        causalityClassification: CausalityClassification = .observationalAssociationOnly,
        recommendedFollowUp: [String] = []
    ) {
        self.narrativeSummary = narrativeSummary
        self.trajectoryAssessment = trajectoryAssessment
        self.confidenceLevel = confidenceLevel
        self.potentialConfounders = potentialConfounders
        self.nonCausalityDisclaimer = nonCausalityDisclaimer
        self.causalityClassification = causalityClassification
        self.recommendedFollowUp = recommendedFollowUp
    }
}

// MARK: - Domain Comparison Results

/// Standard metric comparison pairing empirical observed change with qualitative non-causal interpretation.
public struct MetricComparisonResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let metricDefinition: MetricDefinition
    public let observedChange: ObservedChange
    public let interpretation: ComparisonInterpretation
    public let targetDirection: TargetDirection

    public init(
        id: UUID = UUID(),
        metricDefinition: MetricDefinition,
        observedChange: ObservedChange,
        interpretation: ComparisonInterpretation,
        targetDirection: TargetDirection? = nil
    ) {
        self.id = id
        self.metricDefinition = metricDefinition
        self.observedChange = observedChange
        self.interpretation = interpretation
        self.targetDirection = targetDirection ?? metricDefinition.targetDirection
    }
}

// MARK: - Adherence Comparison

public struct AdherencePeriodStats: Codable, Sendable, Hashable {
    public let totalScheduledDoses: Int
    public let takenDoses: Int
    public let missedDoses: Int
    public let adherencePercentage: Double
    public let activeStreakDays: Int
    public let loggedDaysCount: Int

    public init(
        totalScheduledDoses: Int,
        takenDoses: Int,
        missedDoses: Int,
        adherencePercentage: Double,
        activeStreakDays: Int,
        loggedDaysCount: Int
    ) {
        self.totalScheduledDoses = totalScheduledDoses
        self.takenDoses = takenDoses
        self.missedDoses = missedDoses
        self.adherencePercentage = adherencePercentage
        self.activeStreakDays = activeStreakDays
        self.loggedDaysCount = loggedDaysCount
    }
}

public struct ObservedAdherenceChange: Codable, Sendable, Hashable {
    public let periodAStats: AdherencePeriodStats
    public let periodBStats: AdherencePeriodStats
    public let adherenceRateDifference: Double // B% - A%
    public let missedDoseDifference: Int // B_missed - A_missed
    public let streakDifferenceDays: Int

    public init(
        periodAStats: AdherencePeriodStats,
        periodBStats: AdherencePeriodStats,
        adherenceRateDifference: Double,
        missedDoseDifference: Int,
        streakDifferenceDays: Int
    ) {
        self.periodAStats = periodAStats
        self.periodBStats = periodBStats
        self.adherenceRateDifference = adherenceRateDifference
        self.missedDoseDifference = missedDoseDifference
        self.streakDifferenceDays = streakDifferenceDays
    }
}

public struct AdherenceInterpretation: Codable, Sendable, Hashable {
    public let narrativeSummary: String
    public let complianceImpactAssessment: String
    public let potentialConfounders: [String]
    public let nonCausalityDisclaimer: String

    public init(
        narrativeSummary: String,
        complianceImpactAssessment: String,
        potentialConfounders: [String] = [],
        nonCausalityDisclaimer: String = CausalityClassification.observationalAssociationOnly.disclaimer
    ) {
        self.narrativeSummary = narrativeSummary
        self.complianceImpactAssessment = complianceImpactAssessment
        self.potentialConfounders = potentialConfounders
        self.nonCausalityDisclaimer = nonCausalityDisclaimer
    }
}

public struct AdherenceComparisonResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let observedChange: ObservedAdherenceChange
    public let interpretation: AdherenceInterpretation

    public init(
        id: UUID = UUID(),
        observedChange: ObservedAdherenceChange,
        interpretation: AdherenceInterpretation
    ) {
        self.id = id
        self.observedChange = observedChange
        self.interpretation = interpretation
    }
}

// MARK: - Symptom & Well-Being Comparison

public struct ObservedSymptomChange: Codable, Sendable, Hashable {
    public let domainStatsA: [String: DescriptiveStatistics] // e.g. "Energy", "Sleep Quality", "Recovery", "Mood", "Pain", "Composite"
    public let domainStatsB: [String: DescriptiveStatistics]
    public let compositeScoreDifference: Double
    public let sideEffectOccurrencesA: Int
    public let sideEffectOccurrencesB: Int
    public let sideEffectsReportedA: [String]
    public let sideEffectsReportedB: [String]

    public init(
        domainStatsA: [String: DescriptiveStatistics],
        domainStatsB: [String: DescriptiveStatistics],
        compositeScoreDifference: Double,
        sideEffectOccurrencesA: Int,
        sideEffectOccurrencesB: Int,
        sideEffectsReportedA: [String],
        sideEffectsReportedB: [String]
    ) {
        self.domainStatsA = domainStatsA
        self.domainStatsB = domainStatsB
        self.compositeScoreDifference = compositeScoreDifference
        self.sideEffectOccurrencesA = sideEffectOccurrencesA
        self.sideEffectOccurrencesB = sideEffectOccurrencesB
        self.sideEffectsReportedA = sideEffectsReportedA
        self.sideEffectsReportedB = sideEffectsReportedB
    }
}

public struct SymptomInterpretation: Codable, Sendable, Hashable {
    public let narrativeSummary: String
    public let wellbeingTrajectory: TrajectoryAssessment
    public let confidenceLevel: ComparisonConfidence
    public let potentialConfounders: [String]
    public let nonCausalityDisclaimer: String

    public init(
        narrativeSummary: String,
        wellbeingTrajectory: TrajectoryAssessment,
        confidenceLevel: ComparisonConfidence,
        potentialConfounders: [String] = [],
        nonCausalityDisclaimer: String = CausalityClassification.observationalAssociationOnly.disclaimer
    ) {
        self.narrativeSummary = narrativeSummary
        self.wellbeingTrajectory = wellbeingTrajectory
        self.confidenceLevel = confidenceLevel
        self.potentialConfounders = potentialConfounders
        self.nonCausalityDisclaimer = nonCausalityDisclaimer
    }
}

public struct SymptomComparisonResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let observedChange: ObservedSymptomChange
    public let interpretation: SymptomInterpretation

    public init(
        id: UUID = UUID(),
        observedChange: ObservedSymptomChange,
        interpretation: SymptomInterpretation
    ) {
        self.id = id
        self.observedChange = observedChange
        self.interpretation = interpretation
    }
}

// MARK: - Lab & Biomarker Comparison

public struct ObservedBiomarkerChange: Codable, Sendable, Hashable {
    public let biomarkerName: String
    public let category: BiomarkerCategory
    public let unit: String
    public let referenceRangeMin: Double?
    public let referenceRangeMax: Double?
    public let periodAStats: DescriptiveStatistics
    public let periodBStats: DescriptiveStatistics
    public let absoluteShift: Double // Mean(B) - Mean(A) or Endpoint(B) - Endpoint(A)
    public let percentageShift: Double
    public let statusA: BiomarkerStatus
    public let statusB: BiomarkerStatus
    public let statusTransitionDescription: String // e.g. "Optimal -> Optimal" or "Low -> Optimal"

    public init(
        biomarkerName: String,
        category: BiomarkerCategory,
        unit: String,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        periodAStats: DescriptiveStatistics,
        periodBStats: DescriptiveStatistics,
        absoluteShift: Double,
        percentageShift: Double,
        statusA: BiomarkerStatus,
        statusB: BiomarkerStatus,
        statusTransitionDescription: String
    ) {
        self.biomarkerName = biomarkerName
        self.category = category
        self.unit = unit
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.periodAStats = periodAStats
        self.periodBStats = periodBStats
        self.absoluteShift = absoluteShift
        self.percentageShift = percentageShift
        self.statusA = statusA
        self.statusB = statusB
        self.statusTransitionDescription = statusTransitionDescription
    }
}

public struct BiomarkerInterpretation: Codable, Sendable, Hashable {
    public let clinicalContext: String
    public let statusAssessment: String
    public let potentialConfounders: [String]
    public let nonCausalityDisclaimer: String

    public init(
        clinicalContext: String,
        statusAssessment: String,
        potentialConfounders: [String] = [],
        nonCausalityDisclaimer: String = CausalityClassification.observationalAssociationOnly.disclaimer
    ) {
        self.clinicalContext = clinicalContext
        self.statusAssessment = statusAssessment
        self.potentialConfounders = potentialConfounders
        self.nonCausalityDisclaimer = nonCausalityDisclaimer
    }
}

public struct BiomarkerComparisonResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let observedChange: ObservedBiomarkerChange
    public let interpretation: BiomarkerInterpretation

    public init(
        id: UUID = UUID(),
        observedChange: ObservedBiomarkerChange,
        interpretation: BiomarkerInterpretation
    ) {
        self.id = id
        self.observedChange = observedChange
        self.interpretation = interpretation
    }
}

// MARK: - Cost & Financial Comparison

public struct ObservedCostChange: Codable, Sendable, Hashable {
    public let totalCostA: Double
    public let totalCostB: Double
    public let costPerDayA: Double
    public let costPerDayB: Double
    public let costPerDoseA: Double
    public let costPerDoseB: Double
    public let categoryBreakdownA: [CostCategory: Double]
    public let categoryBreakdownB: [CostCategory: Double]
    public let costDeltaTotal: Double // Total(B) - Total(A)
    public let costDeltaPerDay: Double // Day(B) - Day(A)
    public let costEffectivenessRatio: Double? // e.g. Cost per unit primary outcome change
    public let currencyCode: String

    public init(
        totalCostA: Double,
        totalCostB: Double,
        costPerDayA: Double,
        costPerDayB: Double,
        costPerDoseA: Double,
        costPerDoseB: Double,
        categoryBreakdownA: [CostCategory: Double] = [:],
        categoryBreakdownB: [CostCategory: Double] = [:],
        costDeltaTotal: Double,
        costDeltaPerDay: Double,
        costEffectivenessRatio: Double? = nil,
        currencyCode: String = "USD"
    ) {
        self.totalCostA = totalCostA
        self.totalCostB = totalCostB
        self.costPerDayA = costPerDayA
        self.costPerDayB = costPerDayB
        self.costPerDoseA = costPerDoseA
        self.costPerDoseB = costPerDoseB
        self.categoryBreakdownA = categoryBreakdownA
        self.categoryBreakdownB = categoryBreakdownB
        self.costDeltaTotal = costDeltaTotal
        self.costDeltaPerDay = costDeltaPerDay
        self.costEffectivenessRatio = costEffectivenessRatio
        self.currencyCode = currencyCode
    }
}

public struct CostInterpretation: Codable, Sendable, Hashable {
    public let financialEfficiencySummary: String
    public let budgetaryProjection: String
    public let potentialConfounders: [String]
    public let nonCausalityDisclaimer: String

    public init(
        financialEfficiencySummary: String,
        budgetaryProjection: String,
        potentialConfounders: [String] = [],
        nonCausalityDisclaimer: String = CausalityClassification.observationalAssociationOnly.disclaimer
    ) {
        self.financialEfficiencySummary = financialEfficiencySummary
        self.budgetaryProjection = budgetaryProjection
        self.potentialConfounders = potentialConfounders
        self.nonCausalityDisclaimer = nonCausalityDisclaimer
    }
}

public struct CostComparisonResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let observedChange: ObservedCostChange
    public let interpretation: CostInterpretation

    public init(
        id: UUID = UUID(),
        observedChange: ObservedCostChange,
        interpretation: CostInterpretation
    ) {
        self.id = id
        self.observedChange = observedChange
        self.interpretation = interpretation
    }
}

// MARK: - Master Protocol Comparison Report

/// Master analytical synthesis packaging all multi-domain comparisons.
/// Strictly enforces the separation between empirical observations and non-causal interpretations.
public struct ProtocolComparisonReport: Identifiable, Sendable {
    public let id: UUID
    public let generatedAt: Date
    public let periodA: ProtocolComparisonPeriod
    public let periodB: ProtocolComparisonPeriod
    public let weightComparison: MetricComparisonResult?
    public let measurementComparisons: [MetricComparisonResult]
    public let adherenceComparison: AdherenceComparisonResult?
    public let symptomComparison: SymptomComparisonResult?
    public let biomarkerComparisons: [BiomarkerComparisonResult]
    public let costComparison: CostComparisonResult?
    public let customMetricComparisons: [MetricComparisonResult]
    public let executiveSummary: String
    public let identifiedConfounders: [String]
    public let nonCausalityAdvisory: String

    public init(
        id: UUID = UUID(),
        generatedAt: Date = Date(),
        periodA: ProtocolComparisonPeriod,
        periodB: ProtocolComparisonPeriod,
        weightComparison: MetricComparisonResult? = nil,
        measurementComparisons: [MetricComparisonResult] = [],
        adherenceComparison: AdherenceComparisonResult? = nil,
        symptomComparison: SymptomComparisonResult? = nil,
        biomarkerComparisons: [BiomarkerComparisonResult] = [],
        costComparison: CostComparisonResult? = nil,
        customMetricComparisons: [MetricComparisonResult] = [],
        executiveSummary: String = "",
        identifiedConfounders: [String] = [],
        nonCausalityAdvisory: String = CausalityClassification.observationalAssociationOnly.disclaimer
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.periodA = periodA
        self.periodB = periodB
        self.weightComparison = weightComparison
        self.measurementComparisons = measurementComparisons
        self.adherenceComparison = adherenceComparison
        self.symptomComparison = symptomComparison
        self.biomarkerComparisons = biomarkerComparisons
        self.costComparison = costComparison
        self.customMetricComparisons = customMetricComparisons
        self.executiveSummary = executiveSummary
        self.identifiedConfounders = identifiedConfounders
        self.nonCausalityAdvisory = nonCausalityAdvisory
    }

    /// All metric comparisons combined (weight, vitals, custom metrics).
    public var allMetricComparisons: [MetricComparisonResult] {
        var list: [MetricComparisonResult] = []
        if let w = weightComparison { list.append(w) }
        list.append(contentsOf: measurementComparisons)
        list.append(contentsOf: customMetricComparisons)
        return list
    }
}
