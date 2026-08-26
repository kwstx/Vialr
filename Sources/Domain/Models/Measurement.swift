import Foundation

/// Represents a recorded measurement across physical body metrics, vitals, sleep,
/// subjective scores (energy, appetite, mood), bloodwork, or custom user-defined metrics.
public struct Measurement: SyncableRecord, TimeSeriesDataPoint, Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var userId: UUID?
    public var name: String
    public var type: MeasurementType
    public var category: MeasurementCategory
    public var value: Double
    public var secondaryValue: Double? // For dual measurements (e.g., Diastolic BP in 120/80 mmHg)
    public var unit: String
    public var dateRecorded: Date
    public var source: MeasurementSource
    public var referenceRangeMin: Double?
    public var referenceRangeMax: Double?
    public var associatedProtocolId: UUID?
    public var customMetricId: UUID?
    public var customMetricCode: String?
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var syncState: SyncState

    /// Canonical timestamp for TimeSeriesDataPoint conformance.
    public var timestamp: Date {
        get { dateRecorded }
        set { dateRecorded = newValue }
    }

    // MARK: - Primary Initializer
    public init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        name: String,
        type: MeasurementType = .custom,
        category: MeasurementCategory = .bodyComposition,
        value: Double,
        secondaryValue: Double? = nil,
        unit: String,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .manualEntry,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        associatedProtocolId: UUID? = nil,
        customMetricId: UUID? = nil,
        customMetricCode: String? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        syncState: SyncState = .synced
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.type = type
        self.category = category
        self.value = value
        self.secondaryValue = secondaryValue
        self.unit = unit
        self.dateRecorded = dateRecorded
        self.source = source
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.associatedProtocolId = associatedProtocolId
        self.customMetricId = customMetricId
        self.customMetricCode = customMetricCode
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.syncState = syncState
    }

    // MARK: - Convenience Static Factories
    /// Body weight measurement (e.g., 182.4 lbs or 82.7 kg)
    public static func weight(
        _ value: Double,
        unit: WeightUnit = .lbs,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .manualEntry,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Body Weight",
            type: .weight,
            category: .bodyComposition,
            value: value,
            unit: unit.symbol,
            dateRecorded: dateRecorded,
            source: source,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Waist circumference measurement (e.g., 32.5 inches or 82 cm)
    public static func waist(
        _ value: Double,
        unit: HeightUnit = .inches,
        dateRecorded: Date = Date(),
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Waist Circumference",
            type: .waist,
            category: .bodyComposition,
            value: value,
            unit: unit.symbol,
            dateRecorded: dateRecorded,
            source: .manualEntry,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Blood pressure measurement (e.g., 120 / 80 mmHg)
    public static func bloodPressure(
        systolic: Double,
        diastolic: Double,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .manualEntry,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Blood Pressure",
            type: .bloodPressure,
            category: .cardiovascular,
            value: systolic,
            secondaryValue: diastolic,
            unit: "mmHg",
            dateRecorded: dateRecorded,
            source: source,
            referenceRangeMin: 90.0,
            referenceRangeMax: 120.0,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Sleep measurement (hours slept, optional quality score 1-10)
    public static func sleep(
        hours: Double,
        qualityScore: Double? = nil,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .appleHealth,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Sleep Duration",
            type: .sleep,
            category: .sleepRecovery,
            value: hours,
            secondaryValue: qualityScore,
            unit: "hrs",
            dateRecorded: dateRecorded,
            source: source,
            referenceRangeMin: 7.0,
            referenceRangeMax: 9.0,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Subjective energy level (1 to 10 scale)
    public static func energy(
        level: Double,
        dateRecorded: Date = Date(),
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Energy Level",
            type: .energy,
            category: .subjectiveWellbeing,
            value: min(10.0, max(1.0, level)),
            unit: "/10",
            dateRecorded: dateRecorded,
            source: .manualEntry,
            referenceRangeMin: 7.0,
            referenceRangeMax: 10.0,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Subjective appetite or satiety rating (1 to 10 scale)
    public static func appetite(
        level: Double,
        dateRecorded: Date = Date(),
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Appetite / Hunger",
            type: .appetite,
            category: .subjectiveWellbeing,
            value: min(10.0, max(1.0, level)),
            unit: "/10",
            dateRecorded: dateRecorded,
            source: .manualEntry,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Heart rate measurement (bpm)
    public static func heartRate(
        _ bpm: Double,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .appleHealth,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Heart Rate",
            type: .restingHeartRate,
            category: .cardiovascular,
            value: bpm,
            unit: "bpm",
            dateRecorded: dateRecorded,
            source: source,
            referenceRangeMin: 50.0,
            referenceRangeMax: 100.0,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Heart rate variability (SDNN in ms)
    public static func hrv(
        _ ms: Double,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .appleHealth,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Heart Rate Variability (HRV)",
            type: .hrv,
            category: .cardiovascular,
            value: ms,
            unit: "ms",
            dateRecorded: dateRecorded,
            source: source,
            referenceRangeMin: 40.0,
            referenceRangeMax: 120.0,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Fasting / blood glucose measurement (mg/dL)
    public static func bloodGlucose(
        _ mgDl: Double,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .appleHealth,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Fasting Blood Glucose",
            type: .bloodGlucose,
            category: .metabolic,
            value: mgDl,
            unit: "mg/dL",
            dateRecorded: dateRecorded,
            source: source,
            referenceRangeMin: 70.0,
            referenceRangeMax: 99.0,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Body fat percentage (%)
    public static func bodyFat(
        _ percentage: Double,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .appleHealth,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Body Fat %",
            type: .bodyFat,
            category: .bodyComposition,
            value: percentage,
            unit: "%",
            dateRecorded: dateRecorded,
            source: source,
            referenceRangeMin: 10.0,
            referenceRangeMax: 20.0,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Workout / Physical activity measurement (duration in minutes, calories burned in secondaryValue)
    public static func workout(
        activityName: String,
        durationMinutes: Double,
        caloriesBurned: Double? = nil,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .appleHealth,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: activityName.isEmpty ? "Workout / Activity" : activityName,
            type: .workout,
            category: .athletic,
            value: durationMinutes,
            secondaryValue: caloriesBurned,
            unit: "min",
            dateRecorded: dateRecorded,
            source: source,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Daily steps measurement
    public static func stepCount(
        _ steps: Double,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .appleHealth,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Daily Steps",
            type: .stepCount,
            category: .athletic,
            value: steps,
            unit: "steps",
            dateRecorded: dateRecorded,
            source: source,
            referenceRangeMin: 8000.0,
            referenceRangeMax: 15000.0,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Active energy / calories burned (kcal)
    public static func activeCalories(
        _ kcal: Double,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .appleHealth,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Active Calories",
            type: .activeEnergy,
            category: .athletic,
            value: kcal,
            unit: "kcal",
            dateRecorded: dateRecorded,
            source: source,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Oxygen saturation (SpO2 in %)
    public static func oxygenSaturation(
        _ percentage: Double,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .appleHealth,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Oxygen Saturation (SpO2)",
            type: .oxygenSaturation,
            category: .cardiovascular,
            value: percentage,
            unit: "%",
            dateRecorded: dateRecorded,
            source: source,
            referenceRangeMin: 95.0,
            referenceRangeMax: 100.0,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Respiratory rate (breaths per minute)
    public static func respiratoryRate(
        _ breathsPerMin: Double,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .appleHealth,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Respiratory Rate",
            type: .respiratoryRate,
            category: .cardiovascular,
            value: breathsPerMin,
            unit: "brpm",
            dateRecorded: dateRecorded,
            source: source,
            referenceRangeMin: 12.0,
            referenceRangeMax: 20.0,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Body temperature (degrees)
    public static func bodyTemperature(
        _ degrees: Double,
        unit: String = "°F",
        dateRecorded: Date = Date(),
        source: MeasurementSource = .appleHealth,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: "Body Temperature",
            type: .bodyTemperature,
            category: .cardiovascular,
            value: degrees,
            unit: unit,
            dateRecorded: dateRecorded,
            source: source,
            referenceRangeMin: unit == "°C" ? 36.1 : 97.0,
            referenceRangeMax: unit == "°C" ? 37.2 : 99.0,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Custom user-defined metric (e.g. "Grip Strength", "Water Intake", "VO2 Max")
    public static func custom(
        name: String,
        value: Double,
        unit: String,
        category: MeasurementCategory = .custom,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        dateRecorded: Date = Date(),
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Measurement {
        Measurement(
            name: name,
            type: .custom,
            category: category,
            value: value,
            unit: unit,
            dateRecorded: dateRecorded,
            source: .manualEntry,
            referenceRangeMin: referenceRangeMin,
            referenceRangeMax: referenceRangeMax,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    // MARK: - Display & Status Helpers
    /// Nicely formatted value string taking secondary value into account.
    public var formattedValue: String {
        if type == .bloodPressure, let diastolic = secondaryValue {
            return "\(Int(value))/\(Int(diastolic)) \(unit)"
        }
        if type == .workout, let kcal = secondaryValue {
            let mins = Int(value)
            return "\(mins) min (\(Int(kcal)) kcal)"
        }
        if unit == "/10" {
            return "\(String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", value)) / 10"
        }
        let valStr = String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", value)
        return "\(valStr) \(unit)"
    }

    /// Status evaluation against reference ranges.
    public var status: MeasurementStatus {
        if let min = referenceRangeMin, value < min {
            return .low
        }
        if let max = referenceRangeMax, value > max {
            return .high
        }
        return .inRange
    }
}

// MARK: - Measurement Types
public enum MeasurementType: String, Codable, Sendable, CaseIterable, Identifiable {
    case weight = "Body Weight"
    case waist = "Waist Circumference"
    case bodyFat = "Body Fat %"
    case bloodPressure = "Blood Pressure"
    case restingHeartRate = "Resting Heart Rate"
    case hrv = "Heart Rate Variability (HRV)"
    case bloodGlucose = "Fasting Blood Glucose"
    case sleep = "Sleep Duration & Quality"
    case workout = "Workout / Activity"
    case stepCount = "Daily Steps"
    case activeEnergy = "Active Calories"
    case oxygenSaturation = "Oxygen Saturation (SpO2)"
    case respiratoryRate = "Respiratory Rate"
    case bodyTemperature = "Body Temperature"
    case energy = "Energy Level"
    case appetite = "Appetite & Satiety"
    case pain = "Pain Index"
    case mood = "Mood Score"
    case bloodwork = "Bloodwork / Biomarker"
    case custom = "Custom Metric"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .waist: return "figure.arms.open"
        case .bodyFat: return "percent"
        case .bloodPressure: return "waveform.path.ecg.rectangle.fill"
        case .restingHeartRate: return "heart.fill"
        case .hrv: return "bolt.heart.fill"
        case .bloodGlucose: return "drop.fill"
        case .sleep: return "bed.double.fill"
        case .workout: return "figure.run"
        case .stepCount: return "shoeprints.fill"
        case .activeEnergy: return "flame.fill"
        case .oxygenSaturation: return "lungs.fill"
        case .respiratoryRate: return "wind"
        case .bodyTemperature: return "thermometer.medium"
        case .energy: return "bolt.fill"
        case .appetite: return "fork.knife"
        case .pain: return "bandage.fill"
        case .mood: return "face.smiling.inverse"
        case .bloodwork: return "testtube.2"
        case .custom: return "chart.xyaxis.line"
        }
    }
}

// MARK: - Measurement Category
public enum MeasurementCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case bodyComposition = "Body Composition"
    case cardiovascular = "Cardiovascular & Vitals"
    case metabolic = "Metabolic & Glucose"
    case sleepRecovery = "Sleep & Recovery"
    case subjectiveWellbeing = "Subjective & Well-Being"
    case athletic = "Athletic & Performance"
    case bloodwork = "Bloodwork / Lab"
    case custom = "Custom Metrics"

    public var id: String { rawValue }
}

// MARK: - Measurement Status
public enum MeasurementStatus: String, Codable, Sendable {
    case low = "Low"
    case inRange = "Optimal / Normal"
    case high = "High"

    public var colorHex: String {
        switch self {
        case .low: return "#F59E0B"
        case .inRange: return "#10B981"
        case .high: return "#EF4444"
        }
    }
}
