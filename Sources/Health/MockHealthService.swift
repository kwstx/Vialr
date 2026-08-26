import Foundation
import Domain

/// Mock HealthKit service for simulator, previews, and testing environments.
public final class MockHealthService: HealthServiceProtocol, @unchecked Sendable {
    public var isAvailable: Bool = true
    public var isAuthorized: Bool = true
    public var simulatedError: HealthKitError? = nil

    // In-memory configurable mock datasets
    public var mockWeight: Double? = 182.4
    public var mockRestingHeartRate: Double? = 54.0
    public var mockHeartRate: Double? = 68.0
    public var mockHRV: Double? = 78.0
    public var mockBloodGlucose: Double? = 86.0
    public var mockBodyFat: Double? = 14.5
    public var mockStepCount: Double? = 10450.0
    public var mockActiveEnergy: Double? = 640.0
    public var mockSpO2: Double? = 98.5
    public var mockRespiratoryRate: Double? = 14.0
    public var mockBodyTemperature: Double? = 98.4

    public var mockWorkouts: [HealthWorkoutSample] = []
    public var mockSleepSamples: [HealthSleepSample] = []
    public var mockBloodPressures: [HealthBloodPressureSample] = []
    public var customQuantitySamples: [HealthMetricType: [HealthSample]] = [:]

    private var grantedMetrics: Set<HealthMetricType> = Set(HealthMetricType.allCases)

    public init(isAvailable: Bool = true, isAuthorized: Bool = true) {
        self.isAvailable = isAvailable
        self.isAuthorized = isAuthorized
        setupDefaultMockSamples()
    }

    public func authorizationStatus(for metric: HealthMetricType) -> HealthAuthorizationStatus {
        guard isAvailable else { return .unavailable }
        guard isAuthorized else { return .sharingDenied }
        return grantedMetrics.contains(metric) ? .sharingAuthorized : .notDetermined
    }

    public func requestAuthorization(for metrics: Set<HealthMetricType>) async throws -> Bool {
        if let error = simulatedError { throw error }
        guard isAvailable else { throw HealthKitError.healthDataUnavailable }
        if !isAuthorized { throw HealthKitError.notAuthorized("User denied permission") }
        grantedMetrics.formUnion(metrics)
        return true
    }

    public func fetchLatestSample(for metric: HealthMetricType) async throws -> HealthSample? {
        if let error = simulatedError { throw error }
        guard isAvailable else { throw HealthKitError.healthDataUnavailable }

        if let custom = customQuantitySamples[metric]?.sorted(by: { $0.endDate > $1.endDate }).first {
            return custom
        }

        let now = Date()
        let metadata = HealthSourceMetadata(
            sourceName: "Apple Watch Ultra 2",
            sourceBundleIdentifier: "com.apple.health",
            deviceModel: "Watch6,18",
            deviceManufacturer: "Apple Inc.",
            originalUnit: metric.defaultUnitSymbol,
            startDate: now.addingTimeInterval(-3600),
            endDate: now,
            hkSampleType: metric.rawValue
        )

        let val: Double?
        switch metric {
        case .weight: val = mockWeight
        case .restingHeartRate: val = mockRestingHeartRate
        case .heartRate, .walkingHeartRateAverage: val = mockHeartRate
        case .heartRateVariability: val = mockHRV
        case .bloodGlucose: val = mockBloodGlucose
        case .bodyFatPercentage: val = mockBodyFat
        case .stepCount: val = mockStepCount
        case .activeEnergyBurned: val = mockActiveEnergy
        case .oxygenSaturation: val = mockSpO2
        case .respiratoryRate: val = mockRespiratoryRate
        case .bodyTemperature: val = mockBodyTemperature
        default: val = 100.0
        }

        guard let value = val else { return nil }

        return HealthSample(
            metricType: metric,
            value: value,
            unit: metric.defaultUnitSymbol,
            startDate: now.addingTimeInterval(-1800),
            endDate: now,
            metadata: metadata
        )
    }

    public func fetchSamples(
        for metric: HealthMetricType,
        startDate: Date,
        endDate: Date,
        limit: Int?
    ) async throws -> [HealthSample] {
        if let error = simulatedError { throw error }
        guard isAvailable else { throw HealthKitError.healthDataUnavailable }

        if let existing = customQuantitySamples[metric] {
            let filtered = existing.filter { $0.endDate >= startDate && $0.endDate <= endDate }
            let sorted = filtered.sorted(by: { $0.endDate > $1.endDate })
            if let max = limit {
                return Array(sorted.prefix(max))
            }
            return sorted
        }

        if let latest = try await fetchLatestSample(for: metric) {
            return [latest]
        }
        return []
    }

    public func fetchWorkouts(
        startDate: Date,
        endDate: Date,
        limit: Int?
    ) async throws -> [HealthWorkoutSample] {
        if let error = simulatedError { throw error }
        guard isAvailable else { throw HealthKitError.healthDataUnavailable }

        let filtered = mockWorkouts.filter { $0.endDate >= startDate && $0.endDate <= endDate }
            .sorted(by: { $0.endDate > $1.endDate })
        if let max = limit {
            return Array(filtered.prefix(max))
        }
        return filtered
    }

    public func fetchSleep(
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthSleepSample] {
        if let error = simulatedError { throw error }
        guard isAvailable else { throw HealthKitError.healthDataUnavailable }

        return mockSleepSamples.filter { $0.endDate >= startDate && $0.endDate <= endDate }
            .sorted(by: { $0.endDate > $1.endDate })
    }

    public func fetchBloodPressure(
        startDate: Date,
        endDate: Date,
        limit: Int?
    ) async throws -> [HealthBloodPressureSample] {
        if let error = simulatedError { throw error }
        guard isAvailable else { throw HealthKitError.healthDataUnavailable }

        let filtered = mockBloodPressures.filter { $0.dateRecorded >= startDate && $0.dateRecorded <= endDate }
            .sorted(by: { $0.dateRecorded > $1.dateRecorded })
        if let max = limit {
            return Array(filtered.prefix(max))
        }
        return filtered
    }

    // MARK: - Convenience Fetchers

    public func fetchLatestWeight() async throws -> Double? { mockWeight }
    public func fetchLatestRestingHeartRate() async throws -> Double? { mockRestingHeartRate }
    public func fetchLatestHRV() async throws -> Double? { mockHRV }
    public func fetchLatestBloodGlucose() async throws -> Double? { mockBloodGlucose }
    public func fetchLatestBodyFat() async throws -> Double? { mockBodyFat }

    public func fetchLatestSleepDuration() async throws -> Double? {
        let total = mockSleepSamples.filter { $0.stage.isRestorativeSleep }.map(\.durationHours).reduce(0.0, +)
        return total > 0 ? total : 7.8
    }

    public func fetchLatestWorkout() async throws -> HealthWorkoutSample? {
        mockWorkouts.sorted(by: { $0.endDate > $1.endDate }).first
    }

    public func fetchLatestBloodPressure() async throws -> HealthBloodPressureSample? {
        mockBloodPressures.sorted(by: { $0.dateRecorded > $1.dateRecorded }).first
    }

    // MARK: - Default Mock Setup

    private func setupDefaultMockSamples() {
        let now = Date()
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now

        let defaultMeta = HealthSourceMetadata(
            sourceName: "Apple Watch Series 9",
            sourceBundleIdentifier: "com.apple.health",
            deviceModel: "Watch6,17",
            deviceManufacturer: "Apple Inc.",
            originalUnit: "min",
            startDate: yesterday,
            endDate: now,
            hkSampleType: "workout"
        )

        mockWorkouts = [
            HealthWorkoutSample(
                workoutActivityName: "Traditional Strength Training",
                workoutActivityTypeRaw: 50,
                durationSeconds: 3600,
                totalEnergyBurnedKcal: 420.0,
                totalDistanceMeters: nil,
                startDate: yesterday.addingTimeInterval(3600 * 8),
                endDate: yesterday.addingTimeInterval(3600 * 9),
                metadata: defaultMeta
            ),
            HealthWorkoutSample(
                workoutActivityName: "HIIT Session",
                workoutActivityTypeRaw: 63,
                durationSeconds: 1800,
                totalEnergyBurnedKcal: 290.0,
                totalDistanceMeters: nil,
                startDate: now.addingTimeInterval(-7200),
                endDate: now.addingTimeInterval(-5400),
                metadata: defaultMeta
            )
        ]

        let sleepMeta = HealthSourceMetadata(
            sourceName: "Apple Watch Series 9",
            sourceBundleIdentifier: "com.apple.health",
            deviceModel: "Watch6,17",
            deviceManufacturer: "Apple Inc.",
            originalUnit: "hrs",
            startDate: yesterday.addingTimeInterval(3600 * 22),
            endDate: now.addingTimeInterval(3600 * 6),
            hkSampleType: "sleepAnalysis"
        )

        mockSleepSamples = [
            HealthSleepSample(
                stage: .core,
                durationHours: 4.6,
                startDate: yesterday.addingTimeInterval(3600 * 22),
                endDate: yesterday.addingTimeInterval(3600 * 26 + 1800),
                metadata: sleepMeta
            ),
            HealthSleepSample(
                stage: .deep,
                durationHours: 1.7,
                startDate: yesterday.addingTimeInterval(3600 * 23),
                endDate: yesterday.addingTimeInterval(3600 * 24 + 2500),
                metadata: sleepMeta
            ),
            HealthSleepSample(
                stage: .rem,
                durationHours: 1.5,
                startDate: yesterday.addingTimeInterval(3600 * 25),
                endDate: yesterday.addingTimeInterval(3600 * 26 + 1800),
                metadata: sleepMeta
            )
        ]

        let bpMeta = HealthSourceMetadata(
            sourceName: "Withings BPM Connect",
            sourceBundleIdentifier: "com.withings.wiscale2",
            deviceModel: "BPM05",
            deviceManufacturer: "Withings",
            originalUnit: "mmHg",
            startDate: yesterday.addingTimeInterval(3600 * 7),
            endDate: yesterday.addingTimeInterval(3600 * 7),
            hkSampleType: "bloodPressure"
        )

        mockBloodPressures = [
            HealthBloodPressureSample(
                systolic: 118.0,
                diastolic: 76.0,
                unit: "mmHg",
                dateRecorded: yesterday.addingTimeInterval(3600 * 7),
                metadata: bpMeta
            ),
            HealthBloodPressureSample(
                systolic: 120.0,
                diastolic: 78.0,
                unit: "mmHg",
                dateRecorded: now.addingTimeInterval(-3600 * 3),
                metadata: bpMeta
            )
        ]
    }
}
