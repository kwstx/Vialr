import Foundation
import Domain

/// Repository responsible for orchestrating Apple Health data synchronization,
/// transforming raw HealthKit samples into application domain `Measurement` models,
/// preserving full source provenance metadata, and managing local storage and user preferences.
public final class HealthRepository: HealthRepositoryProtocol, @unchecked Sendable {
    private let healthService: HealthServiceProtocol
    private let measurementRepository: MeasurementRepositoryProtocol
    private let settingsManager: HealthSettingsManaging

    public var isIntegrationEnabled: Bool {
        settingsManager.isIntegrationEnabled
    }

    public init(
        healthService: HealthServiceProtocol = HealthKitManager.shared,
        measurementRepository: MeasurementRepositoryProtocol,
        settingsManager: HealthSettingsManaging = HealthSettingsManager.shared
    ) {
        self.healthService = healthService
        self.measurementRepository = measurementRepository
        self.settingsManager = settingsManager
    }

    // MARK: - Permission Management

    public func requestPermissions(for metricCodes: [String]?) async throws -> Bool {
        guard settingsManager.isIntegrationEnabled else {
            throw HealthKitError.integrationDisabled
        }

        let metricsToRequest: Set<HealthMetricType>
        if let codes = metricCodes, !codes.isEmpty {
            let parsed = codes.compactMap { HealthMetricType(rawValue: $0) }
            metricsToRequest = Set(parsed)
        } else {
            metricsToRequest = settingsManager.enabledMetrics
        }

        let granted = try await healthService.requestAuthorization(for: metricsToRequest)
        return granted
    }

    // MARK: - Synchronization

    public func syncMeasurements(for metricCodes: [String]?, dateInterval: DateInterval) async throws -> [Measurement] {
        guard settingsManager.isIntegrationEnabled else {
            return []
        }

        let targetMetrics: Set<HealthMetricType>
        if let codes = metricCodes, !codes.isEmpty {
            let parsed = codes.compactMap { HealthMetricType(rawValue: $0) }
            targetMetrics = Set(parsed).intersection(settingsManager.enabledMetrics)
        } else {
            targetMetrics = settingsManager.enabledMetrics
        }

        guard !targetMetrics.isEmpty else {
            return []
        }

        var incomingMeasurements: [Measurement] = []

        // 1. Query and transform standard quantity metrics
        for metric in targetMetrics {
            switch metric {
            case .workout:
                let workouts = try await healthService.fetchWorkouts(
                    startDate: dateInterval.start,
                    endDate: dateInterval.end,
                    limit: nil
                )
                let transformed = workouts.map { transformWorkoutToMeasurement(from: $0) }
                incomingMeasurements.append(contentsOf: transformed)

            case .sleepAnalysis:
                let sleepList = try await healthService.fetchSleep(
                    startDate: dateInterval.start,
                    endDate: dateInterval.end
                )
                let transformed = sleepList.map { transformSleepToMeasurement(from: $0) }
                incomingMeasurements.append(contentsOf: transformed)

            case .bloodPressure:
                let bpList = try await healthService.fetchBloodPressure(
                    startDate: dateInterval.start,
                    endDate: dateInterval.end,
                    limit: nil
                )
                let transformed = bpList.map { transformBloodPressureToMeasurement(from: $0) }
                incomingMeasurements.append(contentsOf: transformed)

            default:
                let samples = try await healthService.fetchSamples(
                    for: metric,
                    startDate: dateInterval.start,
                    endDate: dateInterval.end,
                    limit: nil
                )
                let transformed = samples.map { transformQuantityToMeasurement(from: $0) }
                incomingMeasurements.append(contentsOf: transformed)
            }
        }

        // 2. Load existing measurements to ensure idempotent deduplication
        let existingMeasurements = try await measurementRepository.fetchAll()
        var savedMeasurements: [Measurement] = []

        for incoming in incomingMeasurements {
            let isDuplicate = isMeasurementDuplicate(incoming, against: existingMeasurements)
            if !isDuplicate {
                try await measurementRepository.save(incoming)
                savedMeasurements.append(incoming)
            }
        }

        settingsManager.recordSyncCompleted(at: Date())
        return savedMeasurements
    }

    public func syncLatestMeasurements() async throws -> [Measurement] {
        guard settingsManager.isIntegrationEnabled else {
            return []
        }

        let now = Date()
        let cal = Calendar.current
        let defaultStart = cal.date(byAdding: .day, value: -30, to: now) ?? now.addingTimeInterval(-86400 * 30)
        let interval = DateInterval(start: defaultStart, end: now)

        return try await syncMeasurements(for: nil, dateInterval: interval)
    }

    // MARK: - Enable / Disable / Purge

    public func setIntegrationEnabled(_ enabled: Bool) async throws {
        settingsManager.setIntegrationEnabled(enabled)
    }

    public func purgeImportedMeasurements() async throws {
        let allMeasurements = try await measurementRepository.fetchAll()
        let healthKitMeasurements = allMeasurements.filter { $0.source == .appleHealth }

        for measurement in healthKitMeasurements {
            try await measurementRepository.delete(byId: measurement.id)
        }
    }

    // MARK: - Transformation to Internal Measurement Model

    public func transformQuantityToMeasurement(from sample: HealthSample) -> Measurement {
        let notesWithMetadata = sample.metadata.embedInNotes(existingNotes: "Imported via Apple Health (\(sample.metadata.sourceName))")

        return Measurement(
            name: sample.metricType.displayName,
            type: sample.metricType.domainMeasurementType,
            category: sample.metricType.domainCategory,
            value: sample.value,
            unit: sample.unit,
            dateRecorded: sample.endDate,
            source: .appleHealth,
            referenceRangeMin: defaultRefRangeMin(for: sample.metricType),
            referenceRangeMax: defaultRefRangeMax(for: sample.metricType),
            customMetricCode: sample.metricType.rawValue,
            notes: notesWithMetadata
        )
    }

    public func transformWorkoutToMeasurement(from workout: HealthWorkoutSample) -> Measurement {
        let notesWithMetadata = workout.metadata.embedInNotes(
            existingNotes: "Activity: \(workout.workoutActivityName)\nSource: \(workout.metadata.sourceName)"
        )

        return Measurement(
            name: workout.workoutActivityName,
            type: .workout,
            category: .athletic,
            value: workout.durationMinutes,
            secondaryValue: workout.totalEnergyBurnedKcal,
            unit: "min",
            dateRecorded: workout.endDate,
            source: .appleHealth,
            customMetricCode: "apple_health_workout",
            notes: notesWithMetadata
        )
    }

    public func transformSleepToMeasurement(from sleep: HealthSleepSample) -> Measurement {
        let notesWithMetadata = sleep.metadata.embedInNotes(
            existingNotes: "Sleep Stage: \(sleep.stage.rawValue)\nSource: \(sleep.metadata.sourceName)"
        )

        return Measurement(
            name: "Sleep (\(sleep.stage.rawValue))",
            type: .sleep,
            category: .sleepRecovery,
            value: sleep.durationHours,
            unit: "hrs",
            dateRecorded: sleep.endDate,
            source: .appleHealth,
            referenceRangeMin: 7.0,
            referenceRangeMax: 9.0,
            customMetricCode: "apple_health_sleep",
            notes: notesWithMetadata
        )
    }

    public func transformBloodPressureToMeasurement(from bp: HealthBloodPressureSample) -> Measurement {
        let notesWithMetadata = bp.metadata.embedInNotes(
            existingNotes: "Blood Pressure Reading\nSource: \(bp.metadata.sourceName)"
        )

        return Measurement(
            name: "Blood Pressure",
            type: .bloodPressure,
            category: .cardiovascular,
            value: bp.systolic,
            secondaryValue: bp.diastolic,
            unit: bp.unit,
            dateRecorded: bp.dateRecorded,
            source: .appleHealth,
            referenceRangeMin: 90.0,
            referenceRangeMax: 120.0,
            customMetricCode: "apple_health_blood_pressure",
            notes: notesWithMetadata
        )
    }

    // MARK: - Metadata Provenance Extraction

    public func extractHealthMetadata(from measurement: Measurement) -> HealthSourceMetadata? {
        let (metadata, _) = HealthSourceMetadata.extract(fromNotes: measurement.notes)
        return metadata
    }

    // MARK: - Deduplication Helper

    private func isMeasurementDuplicate(_ incoming: Measurement, against existing: [Measurement]) -> Bool {
        guard let incomingMeta = extractHealthMetadata(from: incoming) else {
            // Fallback: Match by exact type, date recorded within 2 minutes, and value
            return existing.contains { ex in
                ex.source == .appleHealth &&
                ex.type == incoming.type &&
                abs(ex.dateRecorded.timeIntervalSince(incoming.dateRecorded)) < 120.0 &&
                abs(ex.value - incoming.value) < 0.001
            }
        }

        // Exact HealthKit UUID Match
        for item in existing where item.source == .appleHealth {
            if let existingMeta = extractHealthMetadata(from: item) {
                if existingMeta.sampleId == incomingMeta.sampleId {
                    return true
                }
            } else {
                // Secondary check for legacy/imported samples without parsed metadata
                if item.type == incoming.type &&
                   abs(item.dateRecorded.timeIntervalSince(incoming.dateRecorded)) < 60.0 &&
                   abs(item.value - incoming.value) < 0.001 {
                    return true
                }
            }
        }

        return false
    }

    private func defaultRefRangeMin(for metric: HealthMetricType) -> Double? {
        switch metric {
        case .restingHeartRate, .heartRate: return 50.0
        case .heartRateVariability: return 40.0
        case .bloodGlucose: return 70.0
        case .sleepAnalysis: return 7.0
        case .oxygenSaturation: return 95.0
        case .respiratoryRate: return 12.0
        case .bodyTemperature: return 97.0
        default: return nil
        }
    }

    private func defaultRefRangeMax(for metric: HealthMetricType) -> Double? {
        switch metric {
        case .restingHeartRate: return 75.0
        case .heartRate: return 100.0
        case .heartRateVariability: return 120.0
        case .bloodGlucose: return 99.0
        case .sleepAnalysis: return 9.0
        case .oxygenSaturation: return 100.0
        case .respiratoryRate: return 20.0
        case .bodyTemperature: return 99.0
        default: return nil
        }
    }
}
