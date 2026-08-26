import Foundation
import Domain

#if canImport(HealthKit)
import HealthKit
#endif

/// Production HealthKit manager providing isolated access to Apple Health APIs.
public final class HealthKitManager: HealthServiceProtocol, @unchecked Sendable {
    public static let shared = HealthKitManager()

    #if canImport(HealthKit)
    private let healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    #endif

    public var isAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    public init() {}

    // MARK: - Authorization

    public func authorizationStatus(for metric: HealthMetricType) -> HealthAuthorizationStatus {
        #if canImport(HealthKit)
        guard let healthStore = healthStore,
              let objectType = hkObjectType(for: metric) else {
            return .unavailable
        }
        let status = healthStore.authorizationStatus(for: objectType)
        switch status {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .sharingDenied
        case .sharingAuthorized:
            return .sharingAuthorized
        @unknown default:
            return .notDetermined
        }
        #else
        return .unavailable
        #endif
    }

    public func requestAuthorization(for metrics: Set<HealthMetricType>) async throws -> Bool {
        #if canImport(HealthKit)
        guard let healthStore = healthStore else {
            throw HealthKitError.healthDataUnavailable
        }

        var readTypes = Set<HKObjectType>()
        for metric in metrics {
            if let type = hkObjectType(for: metric) {
                readTypes.insert(type)
            }
        }

        guard !readTypes.isEmpty else {
            return true
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
        #else
        throw HealthKitError.healthDataUnavailable
        #endif
    }

    // MARK: - Quantity Sample Queries

    public func fetchLatestSample(for metric: HealthMetricType) async throws -> HealthSample? {
        let samples = try await fetchSamples(for: metric, startDate: .distantPast, endDate: Date(), limit: 1)
        return samples.first
    }

    public func fetchSamples(
        for metric: HealthMetricType,
        startDate: Date,
        endDate: Date,
        limit: Int?
    ) async throws -> [HealthSample] {
        #if canImport(HealthKit)
        guard let healthStore = healthStore else {
            throw HealthKitError.healthDataUnavailable
        }
        guard let quantityType = hkQuantityType(for: metric) else {
            throw HealthKitError.typeNotSupported(metric.rawValue)
        }

        let hkUnit = self.hkUnit(for: metric)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let queryLimit = limit ?? HKObjectQueryNoLimit

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: queryLimit,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, results, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }

                guard let samples = results as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let domainSamples: [HealthSample] = samples.compactMap { sample in
                    let val = sample.quantity.doubleValue(for: hkUnit)
                    let metadata = self?.extractMetadata(from: sample, originalUnit: metric.defaultUnitSymbol) ?? HealthSourceMetadata(
                        sampleId: sample.uuid,
                        sourceName: sample.sourceRevision.source.name,
                        sourceBundleIdentifier: sample.sourceRevision.source.bundleIdentifier,
                        originalUnit: metric.defaultUnitSymbol,
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        hkSampleType: metric.rawValue
                    )

                    return HealthSample(
                        id: sample.uuid,
                        metricType: metric,
                        value: val,
                        unit: metric.defaultUnitSymbol,
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        metadata: metadata
                    )
                }

                continuation.resume(returning: domainSamples)
            }

            healthStore.execute(query)
        }
        #else
        throw HealthKitError.healthDataUnavailable
        #endif
    }

    // MARK: - Workouts Query

    public func fetchWorkouts(
        startDate: Date,
        endDate: Date,
        limit: Int?
    ) async throws -> [HealthWorkoutSample] {
        #if canImport(HealthKit)
        guard let healthStore = healthStore else {
            throw HealthKitError.healthDataUnavailable
        }

        let workoutType = HKWorkoutType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let queryLimit = limit ?? HKObjectQueryNoLimit

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: queryLimit,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, results, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }

                guard let workouts = results as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                let items: [HealthWorkoutSample] = workouts.map { workout in
                    let activityName = self?.formatWorkoutActivityType(workout.workoutActivityType) ?? "Workout"
                    let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                    let distance = workout.totalDistance?.doubleValue(for: .meter())

                    let metadata = self?.extractMetadata(from: workout, originalUnit: "min") ?? HealthSourceMetadata(
                        sampleId: workout.uuid,
                        sourceName: workout.sourceRevision.source.name,
                        sourceBundleIdentifier: workout.sourceRevision.source.bundleIdentifier,
                        originalUnit: "min",
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        hkSampleType: "workout"
                    )

                    return HealthWorkoutSample(
                        id: workout.uuid,
                        workoutActivityName: activityName,
                        workoutActivityTypeRaw: workout.workoutActivityType.rawValue,
                        durationSeconds: workout.duration,
                        totalEnergyBurnedKcal: energy,
                        totalDistanceMeters: distance,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        metadata: metadata
                    )
                }

                continuation.resume(returning: items)
            }

            healthStore.execute(query)
        }
        #else
        throw HealthKitError.healthDataUnavailable
        #endif
    }

    // MARK: - Sleep Query

    public func fetchSleep(
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthSleepSample] {
        #if canImport(HealthKit)
        guard let healthStore = healthStore else {
            throw HealthKitError.healthDataUnavailable
        }
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.typeNotSupported("sleepAnalysis")
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, results, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }

                guard let categorySamples = results as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let items: [HealthSleepSample] = categorySamples.compactMap { sample in
                    let stage: HealthSleepStage
                    if #available(iOS 16.0, macOS 13.0, *) {
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                            stage = .core
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                            stage = .deep
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            stage = .rem
                        case HKCategoryValueSleepAnalysis.awake.rawValue:
                            stage = .awake
                        case HKCategoryValueSleepAnalysis.inBed.rawValue:
                            stage = .inBed
                        default:
                            stage = .asleepUnspecified
                        }
                    } else {
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.inBed.rawValue:
                            stage = .inBed
                        case HKCategoryValueSleepAnalysis.awake.rawValue:
                            stage = .awake
                        default:
                            stage = .asleepUnspecified
                        }
                    }

                    let durationHours = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
                    let metadata = self?.extractMetadata(from: sample, originalUnit: "hrs") ?? HealthSourceMetadata(
                        sampleId: sample.uuid,
                        sourceName: sample.sourceRevision.source.name,
                        sourceBundleIdentifier: sample.sourceRevision.source.bundleIdentifier,
                        originalUnit: "hrs",
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        hkSampleType: "sleepAnalysis"
                    )

                    return HealthSleepSample(
                        id: sample.uuid,
                        stage: stage,
                        durationHours: max(0.0, durationHours),
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        metadata: metadata
                    )
                }

                continuation.resume(returning: items)
            }

            healthStore.execute(query)
        }
        #else
        throw HealthKitError.healthDataUnavailable
        #endif
    }

    // MARK: - Blood Pressure Query

    public func fetchBloodPressure(
        startDate: Date,
        endDate: Date,
        limit: Int?
    ) async throws -> [HealthBloodPressureSample] {
        #if canImport(HealthKit)
        guard let healthStore = healthStore else {
            throw HealthKitError.healthDataUnavailable
        }
        guard let correlationType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure),
              let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            throw HealthKitError.typeNotSupported("bloodPressure")
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let queryLimit = limit ?? HKObjectQueryNoLimit

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKCorrelationQuery(
                type: correlationType,
                predicate: predicate,
                samplePredicates: nil
            ) { [weak self] _, correlations, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }

                guard let correlations = correlations else {
                    continuation.resume(returning: [])
                    return
                }

                var results: [HealthBloodPressureSample] = []
                let mmBpHkUnit = HKUnit.millimeterOfMercury()

                for correlation in correlations.prefix(queryLimit) {
                    guard let sysSample = correlation.objects(for: systolicType).first as? HKQuantitySample,
                          let diaSample = correlation.objects(for: diastolicType).first as? HKQuantitySample else {
                        continue
                    }

                    let systolicVal = sysSample.quantity.doubleValue(for: mmBpHkUnit)
                    let diastolicVal = diaSample.quantity.doubleValue(for: mmBpHkUnit)

                    let metadata = self?.extractMetadata(from: correlation, originalUnit: "mmHg") ?? HealthSourceMetadata(
                        sampleId: correlation.uuid,
                        sourceName: correlation.sourceRevision.source.name,
                        sourceBundleIdentifier: correlation.sourceRevision.source.bundleIdentifier,
                        originalUnit: "mmHg",
                        startDate: correlation.startDate,
                        endDate: correlation.endDate,
                        hkSampleType: "bloodPressure"
                    )

                    results.append(
                        HealthBloodPressureSample(
                            id: correlation.uuid,
                            systolic: systolicVal,
                            diastolic: diastolicVal,
                            unit: "mmHg",
                            dateRecorded: correlation.endDate,
                            metadata: metadata
                        )
                    )
                }

                continuation.resume(returning: results)
            }

            healthStore.execute(query)
        }
        #else
        throw HealthKitError.healthDataUnavailable
        #endif
    }

    // MARK: - Convenience Metric Fetchers

    public func fetchLatestWeight() async throws -> Double? {
        let sample = try await fetchLatestSample(for: .weight)
        return sample?.value
    }

    public func fetchLatestRestingHeartRate() async throws -> Double? {
        let sample = try await fetchLatestSample(for: .restingHeartRate)
        return sample?.value
    }

    public func fetchLatestHRV() async throws -> Double? {
        let sample = try await fetchLatestSample(for: .heartRateVariability)
        return sample?.value
    }

    public func fetchLatestBloodGlucose() async throws -> Double? {
        let sample = try await fetchLatestSample(for: .bloodGlucose)
        return sample?.value
    }

    public func fetchLatestBodyFat() async throws -> Double? {
        let sample = try await fetchLatestSample(for: .bodyFatPercentage)
        return sample?.value
    }

    public func fetchLatestSleepDuration() async throws -> Double? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        let sleepSamples = try await fetchSleep(startDate: yesterday, endDate: Date())
        let restorativeHours = sleepSamples.filter { $0.stage.isRestorativeSleep }.map(\.durationHours).reduce(0.0, +)
        return restorativeHours > 0 ? restorativeHours : nil
    }

    public func fetchLatestWorkout() async throws -> HealthWorkoutSample? {
        let workouts = try await fetchWorkouts(startDate: .distantPast, endDate: Date(), limit: 1)
        return workouts.first
    }

    public func fetchLatestBloodPressure() async throws -> HealthBloodPressureSample? {
        let bpList = try await fetchBloodPressure(startDate: .distantPast, endDate: Date(), limit: 1)
        return bpList.first
    }

    // MARK: - Private HealthKit Mapping Helpers

    #if canImport(HealthKit)
    private func hkObjectType(for metric: HealthMetricType) -> HKObjectType? {
        switch metric {
        case .workout:
            return HKWorkoutType.workoutType()
        case .sleepAnalysis:
            return HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        case .bloodPressure:
            return HKCorrelationType.correlationType(forIdentifier: .bloodPressure)
        default:
            return hkQuantityType(for: metric)
        }
    }

    private func hkQuantityType(for metric: HealthMetricType) -> HKQuantityType? {
        switch metric {
        case .weight:
            return HKQuantityType.quantityType(forIdentifier: .bodyMass)
        case .bodyFatPercentage:
            return HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)
        case .leanBodyMass:
            return HKQuantityType.quantityType(forIdentifier: .leanBodyMass)
        case .waistCircumference:
            return HKQuantityType.quantityType(forIdentifier: .waistCircumference)
        case .heartRate:
            return HKQuantityType.quantityType(forIdentifier: .heartRate)
        case .restingHeartRate:
            return HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
        case .walkingHeartRateAverage:
            return HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage)
        case .heartRateVariability:
            return HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .bloodPressureSystolic:
            return HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
        case .bloodPressureDiastolic:
            return HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)
        case .bloodGlucose:
            return HKQuantityType.quantityType(forIdentifier: .bloodGlucose)
        case .activeEnergyBurned:
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case .basalEnergyBurned:
            return HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)
        case .stepCount:
            return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case .distanceWalkingRunning:
            return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .oxygenSaturation:
            return HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)
        case .respiratoryRate:
            return HKQuantityType.quantityType(forIdentifier: .respiratoryRate)
        case .bodyTemperature:
            return HKQuantityType.quantityType(forIdentifier: .bodyTemperature)
        case .vo2Max:
            return HKQuantityType.quantityType(forIdentifier: .vo2Max)
        case .workout, .sleepAnalysis, .bloodPressure:
            return nil
        }
    }

    private func hkUnit(for metric: HealthMetricType) -> HKUnit {
        switch metric {
        case .weight, .leanBodyMass:
            return HKUnit.pound()
        case .bodyFatPercentage, .oxygenSaturation:
            return HKUnit.percent()
        case .waistCircumference:
            return HKUnit.inch()
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage:
            return HKUnit.count().unitDivided(by: .minute())
        case .heartRateVariability:
            return HKUnit.secondUnit(with: .milli)
        case .bloodPressureSystolic, .bloodPressureDiastolic, .bloodPressure:
            return HKUnit.millimeterOfMercury()
        case .bloodGlucose:
            return HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
        case .activeEnergyBurned, .basalEnergyBurned:
            return HKUnit.kilocalorie()
        case .stepCount:
            return HKUnit.count()
        case .distanceWalkingRunning:
            return HKUnit.mile()
        case .respiratoryRate:
            return HKUnit.count().unitDivided(by: .minute())
        case .bodyTemperature:
            return HKUnit.degreeFahrenheit()
        case .vo2Max:
            return HKUnit(from: "ml/(kg*min)")
        case .sleepAnalysis, .workout:
            return HKUnit.count()
        }
    }

    private func extractMetadata(from sample: HKSample, originalUnit: String) -> HealthSourceMetadata {
        let isUser = (sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool) ?? false
        var customMeta: [String: String] = [:]

        if let dict = sample.metadata {
            for (k, v) in dict {
                customMeta[k] = String(describing: v)
            }
        }

        return HealthSourceMetadata(
            sampleId: sample.uuid,
            sourceName: sample.sourceRevision.source.name,
            sourceBundleIdentifier: sample.sourceRevision.source.bundleIdentifier,
            deviceModel: sample.device?.model,
            deviceManufacturer: sample.device?.manufacturer,
            deviceHardwareVersion: sample.device?.hardwareVersion,
            deviceSoftwareVersion: sample.device?.softwareVersion,
            isUserEntered: isUser,
            originalUnit: originalUnit,
            startDate: sample.startDate,
            endDate: sample.endDate,
            hkSampleType: sample.sampleType.identifier,
            customMetadata: customMeta
        )
    }

    private func formatWorkoutActivityType(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .traditionalStrengthTraining: return "Traditional Strength Training"
        case .functionalStrengthTraining: return "Functional Strength Training"
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .highIntensityIntervalTraining: return "HIIT Session"
        case .coreTraining: return "Core Training"
        case .crossTraining: return "Cross Training"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        default: return "Workout"
        }
    }
    #endif
}
