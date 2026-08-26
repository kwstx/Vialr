import Foundation
import Domain

/// Defines the contract for isolated Apple Health data retrieval and permissions.
public protocol HealthServiceProtocol: Sendable {
    /// Indicates whether HealthKit hardware/framework is available on the current device.
    var isAvailable: Bool { get }

    /// Checks the current authorization status for a specific metric.
    func authorizationStatus(for metric: HealthMetricType) -> HealthAuthorizationStatus

    /// Requests user authorization strictly for the specified subset of health metrics.
    func requestAuthorization(for metrics: Set<HealthMetricType>) async throws -> Bool

    /// Fetches the single most recent quantity sample for a metric.
    func fetchLatestSample(for metric: HealthMetricType) async throws -> HealthSample?

    /// Fetches historical quantity samples for a metric within a given date interval.
    func fetchSamples(
        for metric: HealthMetricType,
        startDate: Date,
        endDate: Date,
        limit: Int?
    ) async throws -> [HealthSample]

    /// Fetches workout sessions within a date range.
    func fetchWorkouts(
        startDate: Date,
        endDate: Date,
        limit: Int?
    ) async throws -> [HealthWorkoutSample]

    /// Fetches sleep analysis intervals within a date range.
    func fetchSleep(
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthSleepSample]

    /// Fetches blood pressure correlations (systolic/diastolic pairs) within a date range.
    func fetchBloodPressure(
        startDate: Date,
        endDate: Date,
        limit: Int?
    ) async throws -> [HealthBloodPressureSample]

    // MARK: - Convenience Metric Fetchers
    func fetchLatestWeight() async throws -> Double?
    func fetchLatestRestingHeartRate() async throws -> Double?
    func fetchLatestHRV() async throws -> Double?
    func fetchLatestBloodGlucose() async throws -> Double?
    func fetchLatestBodyFat() async throws -> Double?
    func fetchLatestSleepDuration() async throws -> Double?
    func fetchLatestWorkout() async throws -> HealthWorkoutSample?
    func fetchLatestBloodPressure() async throws -> HealthBloodPressureSample?
}

// MARK: - Default Protocol Extensions
public extension HealthServiceProtocol {
    /// Requests authorization for all supported metrics by default.
    func requestAuthorization() async throws -> Bool {
        try await requestAuthorization(for: Set(HealthMetricType.allCases))
    }

    func fetchSamples(for metric: HealthMetricType, startDate: Date, endDate: Date) async throws -> [HealthSample] {
        try await fetchSamples(for: metric, startDate: startDate, endDate: endDate, limit: nil)
    }

    func fetchWorkouts(startDate: Date, endDate: Date) async throws -> [HealthWorkoutSample] {
        try await fetchWorkouts(startDate: startDate, endDate: endDate, limit: nil)
    }

    func fetchBloodPressure(startDate: Date, endDate: Date) async throws -> [HealthBloodPressureSample] {
        try await fetchBloodPressure(startDate: startDate, endDate: endDate, limit: nil)
    }
}
