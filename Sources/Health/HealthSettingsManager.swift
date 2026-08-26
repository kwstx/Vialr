import Foundation
import Observation
import Domain

/// Protocol defining configuration and toggle controls for Apple Health integration.
public protocol HealthSettingsManaging: Sendable {
    var isIntegrationEnabled: Bool { get }
    var enabledMetrics: Set<HealthMetricType> { get }
    var syncFrequency: HealthSyncFrequency { get }
    var lastSyncDate: Date? { get }

    func setIntegrationEnabled(_ enabled: Bool)
    func toggleMetric(_ metric: HealthMetricType, enabled: Bool)
    func isMetricEnabled(_ metric: HealthMetricType) -> Bool
    func setSyncFrequency(_ frequency: HealthSyncFrequency)
    func recordSyncCompleted(at date: Date)
    func resetSettings()
}

/// Observable settings manager allowing users to enable, disable, or selectively configure Apple Health.
@Observable
public final class HealthSettingsManager: HealthSettingsManaging, @unchecked Sendable {
    public static let shared = HealthSettingsManager()

    private let userDefaults: UserDefaults
    private let enabledKey = "vialr_healthkit_integration_enabled"
    private let enabledMetricsKey = "vialr_healthkit_enabled_metrics"
    private let syncFrequencyKey = "vialr_healthkit_sync_frequency"
    private let lastSyncDateKey = "vialr_healthkit_last_sync_date"

    public var isIntegrationEnabled: Bool {
        didSet {
            userDefaults.set(isIntegrationEnabled, forKey: enabledKey)
        }
    }

    public var enabledMetrics: Set<HealthMetricType> {
        didSet {
            let codes = enabledMetrics.map(\.rawValue)
            userDefaults.set(codes, forKey: enabledMetricsKey)
        }
    }

    public var syncFrequency: HealthSyncFrequency {
        didSet {
            userDefaults.set(syncFrequency.rawValue, forKey: syncFrequencyKey)
        }
    }

    public var lastSyncDate: Date? {
        didSet {
            userDefaults.set(lastSyncDate, forKey: lastSyncDateKey)
        }
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // Default integration enabled to true on first launch if not explicitly set
        if userDefaults.object(forKey: enabledKey) == nil {
            self.isIntegrationEnabled = true
        } else {
            self.isIntegrationEnabled = userDefaults.bool(forKey: enabledKey)
        }

        // Default enabled metrics
        if let stored = userDefaults.stringArray(forKey: enabledMetricsKey) {
            let valid = stored.compactMap { HealthMetricType(rawValue: $0) }
            self.enabledMetrics = Set(valid)
        } else {
            self.enabledMetrics = [
                .weight,
                .restingHeartRate,
                .heartRateVariability,
                .bloodGlucose,
                .sleepAnalysis,
                .workout,
                .bloodPressure,
                .bodyFatPercentage,
                .stepCount
            ]
        }

        if let freqRaw = userDefaults.string(forKey: syncFrequencyKey),
           let freq = HealthSyncFrequency(rawValue: freqRaw) {
            self.syncFrequency = freq
        } else {
            self.syncFrequency = .hourly
        }

        self.lastSyncDate = userDefaults.object(forKey: lastSyncDateKey) as? Date
    }

    public func setIntegrationEnabled(_ enabled: Bool) {
        self.isIntegrationEnabled = enabled
    }

    public func toggleMetric(_ metric: HealthMetricType, enabled: Bool) {
        if enabled {
            enabledMetrics.insert(metric)
        } else {
            enabledMetrics.remove(metric)
        }
    }

    public func isMetricEnabled(_ metric: HealthMetricType) -> Bool {
        isIntegrationEnabled && enabledMetrics.contains(metric)
    }

    public func setSyncFrequency(_ frequency: HealthSyncFrequency) {
        self.syncFrequency = frequency
    }

    public func recordSyncCompleted(at date: Date = Date()) {
        self.lastSyncDate = date
    }

    public func resetSettings() {
        self.isIntegrationEnabled = false
        self.enabledMetrics = Set(HealthMetricType.allCases)
        self.lastSyncDate = nil
        userDefaults.removeObject(forKey: enabledKey)
        userDefaults.removeObject(forKey: enabledMetricsKey)
        userDefaults.removeObject(forKey: lastSyncDateKey)
    }
}
