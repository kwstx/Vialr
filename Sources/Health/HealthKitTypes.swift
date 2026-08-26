import Foundation
import Domain

/// Enumeration of health and fitness metrics supported by the Apple Health integration layer.
public enum HealthMetricType: String, Codable, Sendable, CaseIterable, Identifiable {
    case weight = "weight"
    case bodyFatPercentage = "body_fat_percentage"
    case leanBodyMass = "lean_body_mass"
    case waistCircumference = "waist_circumference"
    case heartRate = "heart_rate"
    case restingHeartRate = "resting_heart_rate"
    case walkingHeartRateAverage = "walking_heart_rate_average"
    case heartRateVariability = "heart_rate_variability"
    case bloodPressureSystolic = "blood_pressure_systolic"
    case bloodPressureDiastolic = "blood_pressure_diastolic"
    case bloodPressure = "blood_pressure"
    case bloodGlucose = "blood_glucose"
    case sleepAnalysis = "sleep_analysis"
    case workout = "workout"
    case activeEnergyBurned = "active_energy_burned"
    case basalEnergyBurned = "basal_energy_burned"
    case stepCount = "step_count"
    case distanceWalkingRunning = "distance_walking_running"
    case oxygenSaturation = "oxygen_saturation"
    case respiratoryRate = "respiratory_rate"
    case bodyTemperature = "body_temperature"
    case vo2Max = "vo2_max"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .weight: return "Body Weight"
        case .bodyFatPercentage: return "Body Fat %"
        case .leanBodyMass: return "Lean Body Mass"
        case .waistCircumference: return "Waist Circumference"
        case .heartRate: return "Heart Rate"
        case .restingHeartRate: return "Resting Heart Rate"
        case .walkingHeartRateAverage: return "Walking Heart Rate Average"
        case .heartRateVariability: return "Heart Rate Variability (HRV)"
        case .bloodPressureSystolic: return "Systolic Blood Pressure"
        case .bloodPressureDiastolic: return "Diastolic Blood Pressure"
        case .bloodPressure: return "Blood Pressure (Systolic / Diastolic)"
        case .bloodGlucose: return "Blood Glucose"
        case .sleepAnalysis: return "Sleep Duration & Stages"
        case .workout: return "Workouts & Exercises"
        case .activeEnergyBurned: return "Active Energy (Calories)"
        case .basalEnergyBurned: return "Resting Energy (Basal Calories)"
        case .stepCount: return "Step Count"
        case .distanceWalkingRunning: return "Walking & Running Distance"
        case .oxygenSaturation: return "Oxygen Saturation (SpO2)"
        case .respiratoryRate: return "Respiratory Rate"
        case .bodyTemperature: return "Body Temperature"
        case .vo2Max: return "Cardio Fitness (VO2 Max)"
        }
    }

    public var defaultUnitSymbol: String {
        switch self {
        case .weight, .leanBodyMass: return "lbs"
        case .bodyFatPercentage, .oxygenSaturation: return "%"
        case .waistCircumference: return "inches"
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage: return "bpm"
        case .heartRateVariability: return "ms"
        case .bloodPressureSystolic, .bloodPressureDiastolic, .bloodPressure: return "mmHg"
        case .bloodGlucose: return "mg/dL"
        case .sleepAnalysis: return "hrs"
        case .workout: return "min"
        case .activeEnergyBurned, .basalEnergyBurned: return "kcal"
        case .stepCount: return "steps"
        case .distanceWalkingRunning: return "miles"
        case .respiratoryRate: return "brpm"
        case .bodyTemperature: return "°F"
        case .vo2Max: return "mL/kg·min"
        }
    }

    public var domainCategory: MeasurementCategory {
        switch self {
        case .weight, .bodyFatPercentage, .leanBodyMass, .waistCircumference:
            return .bodyComposition
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage, .heartRateVariability,
             .bloodPressureSystolic, .bloodPressureDiastolic, .bloodPressure, .oxygenSaturation,
             .respiratoryRate, .bodyTemperature, .vo2Max:
            return .cardiovascular
        case .bloodGlucose:
            return .metabolic
        case .sleepAnalysis:
            return .sleepRecovery
        case .workout, .activeEnergyBurned, .basalEnergyBurned, .stepCount, .distanceWalkingRunning:
            return .athletic
        }
    }

    public var domainMeasurementType: MeasurementType {
        switch self {
        case .weight: return .weight
        case .bodyFatPercentage: return .bodyFat
        case .waistCircumference: return .waist
        case .restingHeartRate, .heartRate, .walkingHeartRateAverage: return .restingHeartRate
        case .heartRateVariability: return .hrv
        case .bloodPressure, .bloodPressureSystolic, .bloodPressureDiastolic: return .bloodPressure
        case .bloodGlucose: return .bloodGlucose
        case .sleepAnalysis: return .sleep
        case .workout: return .workout
        case .stepCount: return .stepCount
        case .activeEnergyBurned: return .activeEnergy
        case .oxygenSaturation: return .oxygenSaturation
        case .respiratoryRate: return .respiratoryRate
        case .bodyTemperature: return .bodyTemperature
        case .leanBodyMass, .basalEnergyBurned, .distanceWalkingRunning, .vo2Max: return .custom
        }
    }
}

/// Status of HealthKit authorization for a specific metric.
public enum HealthAuthorizationStatus: String, Codable, Sendable {
    case notDetermined = "Not Determined"
    case sharingDenied = "Access Denied"
    case sharingAuthorized = "Authorized"
    case unavailable = "Unavailable"

    public var isAuthorized: Bool {
        self == .sharingAuthorized
    }
}

/// Errors originating from the Apple Health integration layer.
public enum HealthKitError: Error, LocalizedError, Sendable, Equatable {
    case healthDataUnavailable
    case notAuthorized(String)
    case integrationDisabled
    case queryFailed(String)
    case typeNotSupported(String)
    case saveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Apple Health is not available on this device or platform."
        case .notAuthorized(let metric):
            return "Apple Health authorization was denied or not granted for: \(metric)."
        case .integrationDisabled:
            return "Apple Health integration is currently disabled in Vialr Settings."
        case .queryFailed(let reason):
            return "Apple Health query failed: \(reason)"
        case .typeNotSupported(let identifier):
            return "The metric type '\(identifier)' is not supported by this device configuration."
        case .saveFailed(let details):
            return "Failed to save data to Apple Health: \(details)"
        }
    }
}

/// Configurable background synchronization frequency for Apple Health.
public enum HealthSyncFrequency: String, Codable, Sendable, CaseIterable, Identifiable {
    case manual = "Manual Only"
    case hourly = "Hourly Background Sync"
    case daily = "Daily Summary"
    case backgroundContinuous = "Real-Time / Continuous"

    public var id: String { rawValue }
}

/// Token representing a persisted query anchor for incremental sync.
public struct HealthQueryAnchor: Codable, Sendable, Hashable {
    public let metricCode: String
    public let anchorData: Data?
    public let lastSyncTimestamp: Date

    public init(metricCode: String, anchorData: Data?, lastSyncTimestamp: Date = Date()) {
        self.metricCode = metricCode
        self.anchorData = anchorData
        self.lastSyncTimestamp = lastSyncTimestamp
    }
}
