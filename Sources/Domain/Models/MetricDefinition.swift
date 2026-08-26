import Foundation

// MARK: - Aggregation Method

/// Determines how historical measurements are combined in summaries.
public enum AggregationMethod: String, Codable, Sendable, CaseIterable, Identifiable {
    case average = "Average (Mean)"
    case latest = "Latest Value"
    case sum = "Sum Total"
    case minimum = "Minimum"
    case maximum = "Maximum"

    public var id: String { rawValue }
}

// MARK: - Metric Definition

/// Defines a quantitative or qualitative trackable health metric.
/// Supports both curated built-in system metrics and dynamic custom user-defined metrics.
public struct MetricDefinition: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var code: String
    public var category: MeasurementCategory
    public var type: MeasurementType
    public var defaultUnit: String
    public var supportedUnits: [String]
    public var isCustom: Bool
    public var referenceRangeMin: Double?
    public var referenceRangeMax: Double?
    public var targetDirection: TargetDirection
    public var iconName: String
    public var colorHex: String
    public var metricDescription: String
    public var preferredAggregation: AggregationMethod
    public var decimalPlaces: Int
    public var allowsSecondaryValue: Bool
    public var secondaryUnit: String?
    public var createdByUserId: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        code: String,
        category: MeasurementCategory = .bodyComposition,
        type: MeasurementType = .custom,
        defaultUnit: String,
        supportedUnits: [String] = [],
        isCustom: Bool = false,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        targetDirection: TargetDirection = .decrease,
        iconName: String = "chart.xyaxis.line",
        colorHex: String = "#3B82F6",
        metricDescription: String = "",
        preferredAggregation: AggregationMethod = .average,
        decimalPlaces: Int = 1,
        allowsSecondaryValue: Bool = false,
        secondaryUnit: String? = nil,
        createdByUserId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.category = category
        self.type = type
        self.defaultUnit = defaultUnit
        self.supportedUnits = supportedUnits.isEmpty ? [defaultUnit] : supportedUnits
        self.isCustom = isCustom
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.targetDirection = targetDirection
        self.iconName = iconName
        self.colorHex = colorHex
        self.metricDescription = metricDescription
        self.preferredAggregation = preferredAggregation
        self.decimalPlaces = decimalPlaces
        self.allowsSecondaryValue = allowsSecondaryValue
        self.secondaryUnit = secondaryUnit
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Built-in Metrics Catalog
    public static let bodyWeight = MetricDefinition(
        name: "Body Weight",
        code: "body_weight",
        category: .bodyComposition,
        type: .weight,
        defaultUnit: "lbs",
        supportedUnits: ["lbs", "kg"],
        isCustom: false,
        targetDirection: .decrease,
        iconName: "scalemass.fill",
        colorHex: "#3B82F6",
        metricDescription: "Total body mass measurement over time.",
        preferredAggregation: .average,
        decimalPlaces: 1
    )

    public static let waistCircumference = MetricDefinition(
        name: "Waist Circumference",
        code: "waist_circumference",
        category: .bodyComposition,
        type: .waist,
        defaultUnit: "inches",
        supportedUnits: ["inches", "cm"],
        isCustom: false,
        targetDirection: .decrease,
        iconName: "figure.arms.open",
        colorHex: "#6366F1",
        metricDescription: "Abdominal circumference measured at navel height.",
        preferredAggregation: .average,
        decimalPlaces: 1
    )

    public static let bodyFatPercentage = MetricDefinition(
        name: "Body Fat %",
        code: "body_fat_pct",
        category: .bodyComposition,
        type: .bodyFat,
        defaultUnit: "%",
        supportedUnits: ["%"],
        isCustom: false,
        referenceRangeMin: 10.0,
        referenceRangeMax: 20.0,
        targetDirection: .decrease,
        iconName: "percent",
        colorHex: "#8B5CF6",
        metricDescription: "Estimated or DEXA-verified body fat percentage.",
        preferredAggregation: .average,
        decimalPlaces: 1
    )

    public static let bloodPressure = MetricDefinition(
        name: "Blood Pressure",
        code: "blood_pressure",
        category: .cardiovascular,
        type: .bloodPressure,
        defaultUnit: "mmHg",
        supportedUnits: ["mmHg"],
        isCustom: false,
        referenceRangeMin: 90.0,
        referenceRangeMax: 120.0,
        targetDirection: .decrease,
        iconName: "waveform.path.ecg.rectangle.fill",
        colorHex: "#EF4444",
        metricDescription: "Systolic and diastolic blood pressure reading.",
        preferredAggregation: .average,
        decimalPlaces: 0,
        allowsSecondaryValue: true,
        secondaryUnit: "mmHg"
    )

    public static let restingHeartRate = MetricDefinition(
        name: "Resting Heart Rate",
        code: "resting_heart_rate",
        category: .cardiovascular,
        type: .restingHeartRate,
        defaultUnit: "bpm",
        supportedUnits: ["bpm"],
        isCustom: false,
        referenceRangeMin: 50.0,
        referenceRangeMax: 75.0,
        targetDirection: .decrease,
        iconName: "heart.fill",
        colorHex: "#F43F5E",
        metricDescription: "Basal resting heart rate upon waking.",
        preferredAggregation: .average,
        decimalPlaces: 0
    )

    public static let heartRateVariability = MetricDefinition(
        name: "Heart Rate Variability (HRV)",
        code: "hrv",
        category: .cardiovascular,
        type: .hrv,
        defaultUnit: "ms",
        supportedUnits: ["ms"],
        isCustom: false,
        referenceRangeMin: 40.0,
        referenceRangeMax: 120.0,
        targetDirection: .increase,
        iconName: "bolt.heart.fill",
        colorHex: "#EC4899",
        metricDescription: "Autonomic nervous system recovery and vagal tone.",
        preferredAggregation: .average,
        decimalPlaces: 0
    )

    public static let fastingBloodGlucose = MetricDefinition(
        name: "Fasting Blood Glucose",
        code: "fasting_glucose",
        category: .metabolic,
        type: .bloodGlucose,
        defaultUnit: "mg/dL",
        supportedUnits: ["mg/dL", "mmol/L"],
        isCustom: false,
        referenceRangeMin: 70.0,
        referenceRangeMax: 99.0,
        targetDirection: .decrease,
        iconName: "drop.fill",
        colorHex: "#F59E0B",
        metricDescription: "Morning fasted capillary or venous blood glucose.",
        preferredAggregation: .average,
        decimalPlaces: 1
    )

    public static let sleepDuration = MetricDefinition(
        name: "Sleep Duration",
        code: "sleep_duration",
        category: .sleepRecovery,
        type: .sleep,
        defaultUnit: "hrs",
        supportedUnits: ["hrs"],
        isCustom: false,
        referenceRangeMin: 7.0,
        referenceRangeMax: 9.0,
        targetDirection: .increase,
        iconName: "bed.double.fill",
        colorHex: "#10B981",
        metricDescription: "Total nocturnal sleep duration in hours.",
        preferredAggregation: .average,
        decimalPlaces: 1,
        allowsSecondaryValue: true,
        secondaryUnit: "/10 Quality"
    )

    public static let energyLevel = MetricDefinition(
        name: "Energy Level",
        code: "energy_level",
        category: .subjectiveWellbeing,
        type: .energy,
        defaultUnit: "/10",
        supportedUnits: ["/10"],
        isCustom: false,
        referenceRangeMin: 7.0,
        referenceRangeMax: 10.0,
        targetDirection: .increase,
        iconName: "bolt.fill",
        colorHex: "#FBBF24",
        metricDescription: "Subjective vitality and cognitive drive score.",
        preferredAggregation: .average,
        decimalPlaces: 1
    )

    public static let appetiteRating = MetricDefinition(
        name: "Appetite & Satiety",
        code: "appetite_satiety",
        category: .subjectiveWellbeing,
        type: .appetite,
        defaultUnit: "/10",
        supportedUnits: ["/10"],
        isCustom: false,
        targetDirection: .maintain,
        iconName: "fork.knife",
        colorHex: "#14B8A6",
        metricDescription: "Subjective hunger suppression and satiety score.",
        preferredAggregation: .average,
        decimalPlaces: 1
    )

    public static let painIndex = MetricDefinition(
        name: "Pain Index",
        code: "pain_index",
        category: .subjectiveWellbeing,
        type: .pain,
        defaultUnit: "/10",
        supportedUnits: ["/10"],
        isCustom: false,
        referenceRangeMin: 0.0,
        referenceRangeMax: 2.0,
        targetDirection: .decrease,
        iconName: "bandage.fill",
        colorHex: "#F97316",
        metricDescription: "Subjective localized tendon, joint, or muscle pain rating.",
        preferredAggregation: .average,
        decimalPlaces: 1
    )

    public static let moodScore = MetricDefinition(
        name: "Mood Score",
        code: "mood_score",
        category: .subjectiveWellbeing,
        type: .mood,
        defaultUnit: "/10",
        supportedUnits: ["/10"],
        isCustom: false,
        referenceRangeMin: 7.0,
        referenceRangeMax: 10.0,
        targetDirection: .increase,
        iconName: "face.smiling.inverse",
        colorHex: "#A855F7",
        metricDescription: "Subjective mood and emotional well-being rating.",
        preferredAggregation: .average,
        decimalPlaces: 1
    )

    public static let fastingInsulin = MetricDefinition(
        name: "Fasting Insulin",
        code: "fasting_insulin",
        category: .metabolic,
        type: .bloodwork,
        defaultUnit: "uIU/mL",
        supportedUnits: ["uIU/mL", "pmol/L"],
        isCustom: false,
        referenceRangeMin: 2.0,
        referenceRangeMax: 6.0,
        targetDirection: .decrease,
        iconName: "testtube.2",
        colorHex: "#D97706",
        metricDescription: "Fasting serum insulin level for HOMA-IR evaluation.",
        preferredAggregation: .latest,
        decimalPlaces: 1
    )

    public static let igf1 = MetricDefinition(
        name: "IGF-1 (Somatomedin C)",
        code: "igf1",
        category: .bloodwork,
        type: .bloodwork,
        defaultUnit: "ng/mL",
        supportedUnits: ["ng/mL", "nmol/L"],
        isCustom: false,
        referenceRangeMin: 150.0,
        referenceRangeMax: 350.0,
        targetDirection: .increase,
        iconName: "testtube.2",
        colorHex: "#06B6D4",
        metricDescription: "Insulin-like Growth Factor 1 biomarker.",
        preferredAggregation: .latest,
        decimalPlaces: 0
    )

    public static let hsCrp = MetricDefinition(
        name: "hs-CRP (High-Sensitivity CRP)",
        code: "hs_crp",
        category: .bloodwork,
        type: .bloodwork,
        defaultUnit: "mg/L",
        supportedUnits: ["mg/L"],
        isCustom: false,
        referenceRangeMin: 0.0,
        referenceRangeMax: 0.9,
        targetDirection: .decrease,
        iconName: "flame.circle.fill",
        colorHex: "#E11D48",
        metricDescription: "High-sensitivity C-reactive protein systemic inflammation marker.",
        preferredAggregation: .latest,
        decimalPlaces: 2
    )

    /// Comprehensive list of all pre-packaged built-in metrics.
    public static let allBuiltIns: [MetricDefinition] = [
        .bodyWeight,
        .waistCircumference,
        .bodyFatPercentage,
        .bloodPressure,
        .restingHeartRate,
        .heartRateVariability,
        .fastingBloodGlucose,
        .sleepDuration,
        .energyLevel,
        .appetiteRating,
        .painIndex,
        .moodScore,
        .fastingInsulin,
        .igf1,
        .hsCrp
    ]

    /// Lookup built-in metric for a given measurement type.
    public static func builtIn(for type: MeasurementType) -> MetricDefinition {
        switch type {
        case .weight: return .bodyWeight
        case .waist: return .waistCircumference
        case .bodyFat: return .bodyFatPercentage
        case .bloodPressure: return .bloodPressure
        case .restingHeartRate: return .restingHeartRate
        case .hrv: return .heartRateVariability
        case .bloodGlucose: return .fastingBloodGlucose
        case .sleep: return .sleepDuration
        case .energy: return .energyLevel
        case .appetite: return .appetiteRating
        case .pain: return .painIndex
        case .mood: return .moodScore
        case .bloodwork: return .igf1
        case .custom:
            return MetricDefinition(
                name: "Custom Metric",
                code: "custom_\(UUID().uuidString.prefix(8).lowercased())",
                category: .custom,
                type: .custom,
                defaultUnit: "pts",
                isCustom: true,
                iconName: "chart.xyaxis.line",
                colorHex: "#64748B"
            )
        }
    }

    /// Helper to construct a customized user-defined metric definition.
    public static func custom(
        name: String,
        category: MeasurementCategory = .custom,
        defaultUnit: String,
        supportedUnits: [String] = [],
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        targetDirection: TargetDirection = .decrease,
        iconName: String = "chart.xyaxis.line",
        colorHex: String = "#3B82F6",
        metricDescription: String = "",
        preferredAggregation: AggregationMethod = .average,
        decimalPlaces: Int = 1,
        createdByUserId: UUID? = nil
    ) -> MetricDefinition {
        let code = "custom_" + name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")

        return MetricDefinition(
            name: name,
            code: code,
            category: category,
            type: .custom,
            defaultUnit: defaultUnit,
            supportedUnits: supportedUnits.isEmpty ? [defaultUnit] : supportedUnits,
            isCustom: true,
            referenceRangeMin: referenceRangeMin,
            referenceRangeMax: referenceRangeMax,
            targetDirection: targetDirection,
            iconName: iconName,
            colorHex: colorHex,
            metricDescription: metricDescription,
            preferredAggregation: preferredAggregation,
            decimalPlaces: decimalPlaces,
            createdByUserId: createdByUserId
        )
    }
}
