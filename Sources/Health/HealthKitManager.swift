import Foundation
import Domain

#if canImport(HealthKit)
import HealthKit
#endif

public enum HealthKitError: Error, LocalizedError, Sendable {
    case healthDataUnavailable
    case notAuthorized
    case queryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .healthDataUnavailable: return "Apple Health is not available on this device."
        case .notAuthorized: return "Health data authorization was denied."
        case .queryFailed(let msg): return "Health query failed: \(msg)"
        }
    }
}

public protocol HealthServiceProtocol: Sendable {
    var isAvailable: Bool { get }
    func requestAuthorization() async throws -> Bool
    func fetchLatestWeight() async throws -> Double?
    func fetchLatestRestingHeartRate() async throws -> Double?
    func fetchLatestHRV() async throws -> Double?
    func fetchLatestBloodGlucose() async throws -> Double?
}

/// Production HealthKit service managing Apple Health synchronization.
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

    public func requestAuthorization() async throws -> Bool {
        #if canImport(HealthKit)
        guard let healthStore = healthStore else {
            throw HealthKitError.healthDataUnavailable
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
        #else
        return false
        #endif
    }

    public func fetchLatestWeight() async throws -> Double? {
        #if canImport(HealthKit)
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        return try await fetchMostRecentQuantity(for: quantityType, unit: .pound())
        #else
        return nil
        #endif
    }

    public func fetchLatestRestingHeartRate() async throws -> Double? {
        #if canImport(HealthKit)
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        return try await fetchMostRecentQuantity(for: quantityType, unit: HKUnit.count().unitDivided(by: .minute()))
        #else
        return nil
        #endif
    }

    public func fetchLatestHRV() async throws -> Double? {
        #if canImport(HealthKit)
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        return try await fetchMostRecentQuantity(for: quantityType, unit: .secondUnit(with: .milli))
        #else
        return nil
        #endif
    }

    public func fetchLatestBloodGlucose() async throws -> Double? {
        #if canImport(HealthKit)
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return nil }
        let mgDlUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
        return try await fetchMostRecentQuantity(for: quantityType, unit: mgDlUnit)
        #else
        return nil
        #endif
    }

    #if canImport(HealthKit)
    private func fetchMostRecentQuantity(for quantityType: HKQuantityType, unit: HKUnit) async throws -> Double? {
        guard let healthStore = healthStore else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sample = results?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
    #endif
}
