import Foundation
import Domain

/// Mock HealthKit service for simulator, previews, and testing environments.
public final class MockHealthService: HealthServiceProtocol, @unchecked Sendable {
    public var isAvailable: Bool { true }
    public var isAuthorized: Bool = true

    public init() {}

    public func requestAuthorization() async throws -> Bool {
        return true
    }

    public func fetchLatestWeight() async throws -> Double? {
        return 182.4
    }

    public func fetchLatestRestingHeartRate() async throws -> Double? {
        return 54.0
    }

    public func fetchLatestHRV() async throws -> Double? {
        return 78.0
    }

    public func fetchLatestBloodGlucose() async throws -> Double? {
        return 86.0
    }
}

/// Bridges raw health metrics into Domain `Biomarker` entries.
public struct HealthDataBridge: Sendable {
    public init() {}

    public func buildBiomarkers(from service: HealthServiceProtocol) async -> [Biomarker] {
        var results: [Biomarker] = []
        let now = Date()

        if let weight = try? await service.fetchLatestWeight() {
            results.append(
                Biomarker(
                    name: "Body Weight",
                    category: .bodyComposition,
                    value: weight,
                    unit: "lbs",
                    referenceRangeMin: 160,
                    referenceRangeMax: 195,
                    dateRecorded: now,
                    source: .appleHealth
                )
            )
        }

        if let rhr = try? await service.fetchLatestRestingHeartRate() {
            results.append(
                Biomarker(
                    name: "Resting Heart Rate",
                    category: .cardiovascular,
                    value: rhr,
                    unit: "bpm",
                    referenceRangeMin: 50,
                    referenceRangeMax: 75,
                    dateRecorded: now,
                    source: .appleHealth
                )
            )
        }

        if let hrv = try? await service.fetchLatestHRV() {
            results.append(
                Biomarker(
                    name: "Heart Rate Variability",
                    category: .sleepRecovery,
                    value: hrv,
                    unit: "ms",
                    referenceRangeMin: 45,
                    referenceRangeMax: 110,
                    dateRecorded: now,
                    source: .appleHealth
                )
            )
        }

        if let glucose = try? await service.fetchLatestBloodGlucose() {
            results.append(
                Biomarker(
                    name: "Blood Glucose",
                    category: .metabolic,
                    value: glucose,
                    unit: "mg/dL",
                    referenceRangeMin: 70,
                    referenceRangeMax: 99,
                    dateRecorded: now,
                    source: .appleHealth
                )
            )
        }

        return results
    }
}
