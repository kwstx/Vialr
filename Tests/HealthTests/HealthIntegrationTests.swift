import XCTest
import Domain
import Data
@testable import Health

final class HealthIntegrationTests: XCTestCase {

    var mockHealthService: MockHealthService!
    var mockMeasurementRepo: LocalMeasurementRepository!
    var settingsManager: HealthSettingsManager!
    var repository: HealthRepository!

    override func setUp() async throws {
        try await super.setUp()
        mockHealthService = MockHealthService(isAvailable: true, isAuthorized: true)
        mockMeasurementRepo = LocalMeasurementRepository()
        settingsManager = HealthSettingsManager(userDefaults: UserDefaults(suiteName: "HealthTestsSuite_\(UUID().uuidString)")!)
        settingsManager.setIntegrationEnabled(true)
        repository = HealthRepository(
            healthService: mockHealthService,
            measurementRepository: mockMeasurementRepo,
            settingsManager: settingsManager
        )
    }

    override func tearDown() async throws {
        mockHealthService = nil
        mockMeasurementRepo = nil
        settingsManager = nil
        repository = nil
        try await super.tearDown()
    }

    // MARK: - 1. Permissions & Granular Authorization Tests

    func testGranularPermissionsRequest() async throws {
        let metrics: Set<HealthMetricType> = [.weight, .restingHeartRate, .sleepAnalysis]
        let granted = try await mockHealthService.requestAuthorization(for: metrics)
        XCTAssertTrue(granted)

        let weightStatus = mockHealthService.authorizationStatus(for: .weight)
        XCTAssertEqual(weightStatus, .sharingAuthorized)

        let rhrStatus = mockHealthService.authorizationStatus(for: .restingHeartRate)
        XCTAssertEqual(rhrStatus, .sharingAuthorized)
    }

    func testPermissionRequestFailsWhenUnauthorized() async throws {
        mockHealthService.isAuthorized = false
        do {
            _ = try await mockHealthService.requestAuthorization(for: [.weight])
            XCTFail("Should have thrown unauthorized error")
        } catch let error as HealthKitError {
            if case .notAuthorized = error {
                // Expected
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - 2. Data Transformation & Source Metadata Retention

    func testTransformQuantitySampleToDomainMeasurement() {
        let sampleId = UUID()
        let now = Date()
        let metadata = HealthSourceMetadata(
            sampleId: sampleId,
            sourceName: "Withings Body Scan",
            sourceBundleIdentifier: "com.withings.wiscale2",
            deviceModel: "WBS08",
            deviceManufacturer: "Withings",
            isUserEntered: false,
            originalUnit: "lbs",
            startDate: now.addingTimeInterval(-60),
            endDate: now,
            hkSampleType: "HKQuantityTypeIdentifierBodyMass",
            customMetadata: ["ScaleModel": "BodyScanPro"]
        )

        let sample = HealthSample(
            id: sampleId,
            metricType: .weight,
            value: 184.5,
            unit: "lbs",
            startDate: now.addingTimeInterval(-60),
            endDate: now,
            metadata: metadata
        )

        let measurement = repository.transformQuantityToMeasurement(from: sample)

        XCTAssertEqual(measurement.name, "Body Weight")
        XCTAssertEqual(measurement.type, .weight)
        XCTAssertEqual(measurement.category, .bodyComposition)
        XCTAssertEqual(measurement.value, 184.5)
        XCTAssertEqual(measurement.unit, "lbs")
        XCTAssertEqual(measurement.source, .appleHealth)
        XCTAssertEqual(measurement.dateRecorded, now)

        // Verify Source Metadata Retention
        let extracted = repository.extractHealthMetadata(from: measurement)
        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.sampleId, sampleId)
        XCTAssertEqual(extracted?.sourceName, "Withings Body Scan")
        XCTAssertEqual(extracted?.deviceModel, "WBS08")
        XCTAssertEqual(extracted?.customMetadata["ScaleModel"], "BodyScanPro")
    }

    func testTransformWorkoutSampleToDomainMeasurement() {
        let workoutId = UUID()
        let now = Date()
        let metadata = HealthSourceMetadata(
            sampleId: workoutId,
            sourceName: "Apple Watch Ultra 2",
            sourceBundleIdentifier: "com.apple.health",
            deviceModel: "Watch6,18",
            deviceManufacturer: "Apple Inc.",
            originalUnit: "min",
            startDate: now.addingTimeInterval(-3600),
            endDate: now,
            hkSampleType: "workout"
        )

        let workout = HealthWorkoutSample(
            id: workoutId,
            workoutActivityName: "Traditional Strength Training",
            workoutActivityTypeRaw: 50,
            durationSeconds: 3600,
            totalEnergyBurnedKcal: 450.0,
            totalDistanceMeters: nil,
            startDate: now.addingTimeInterval(-3600),
            endDate: now,
            metadata: metadata
        )

        let measurement = repository.transformWorkoutToMeasurement(from: workout)

        XCTAssertEqual(measurement.name, "Traditional Strength Training")
        XCTAssertEqual(measurement.type, .workout)
        XCTAssertEqual(measurement.category, .athletic)
        XCTAssertEqual(measurement.value, 60.0) // 3600s = 60 min
        XCTAssertEqual(measurement.secondaryValue, 450.0) // 450 kcal
        XCTAssertEqual(measurement.unit, "min")
        XCTAssertEqual(measurement.source, .appleHealth)

        let extracted = repository.extractHealthMetadata(from: measurement)
        XCTAssertEqual(extracted?.sampleId, workoutId)
        XCTAssertEqual(extracted?.sourceName, "Apple Watch Ultra 2")
    }

    func testTransformSleepSampleToDomainMeasurement() {
        let sleepId = UUID()
        let now = Date()
        let metadata = HealthSourceMetadata(
            sampleId: sleepId,
            sourceName: "Oura Ring Gen 3",
            sourceBundleIdentifier: "com.ouraring.oura",
            deviceModel: "Ring3",
            deviceManufacturer: "Oura",
            originalUnit: "hrs",
            startDate: now.addingTimeInterval(-3600 * 2),
            endDate: now,
            hkSampleType: "sleepAnalysis"
        )

        let sleep = HealthSleepSample(
            id: sleepId,
            stage: .deep,
            durationHours: 2.0,
            startDate: now.addingTimeInterval(-3600 * 2),
            endDate: now,
            metadata: metadata
        )

        let measurement = repository.transformSleepToMeasurement(from: sleep)

        XCTAssertEqual(measurement.name, "Sleep (Deep Sleep)")
        XCTAssertEqual(measurement.type, .sleep)
        XCTAssertEqual(measurement.category, .sleepRecovery)
        XCTAssertEqual(measurement.value, 2.0)
        XCTAssertEqual(measurement.unit, "hrs")
        XCTAssertEqual(measurement.source, .appleHealth)

        let extracted = repository.extractHealthMetadata(from: measurement)
        XCTAssertEqual(extracted?.sourceName, "Oura Ring Gen 3")
    }

    func testTransformBloodPressureSampleToDomainMeasurement() {
        let bpId = UUID()
        let now = Date()
        let metadata = HealthSourceMetadata(
            sampleId: bpId,
            sourceName: "Withings BPM Core",
            sourceBundleIdentifier: "com.withings.wiscale2",
            deviceModel: "BPM04",
            deviceManufacturer: "Withings",
            originalUnit: "mmHg",
            startDate: now,
            endDate: now,
            hkSampleType: "bloodPressure"
        )

        let bp = HealthBloodPressureSample(
            id: bpId,
            systolic: 122.0,
            diastolic: 79.0,
            unit: "mmHg",
            dateRecorded: now,
            metadata: metadata
        )

        let measurement = repository.transformBloodPressureToMeasurement(from: bp)

        XCTAssertEqual(measurement.name, "Blood Pressure")
        XCTAssertEqual(measurement.type, .bloodPressure)
        XCTAssertEqual(measurement.category, .cardiovascular)
        XCTAssertEqual(measurement.value, 122.0)
        XCTAssertEqual(measurement.secondaryValue, 79.0)
        XCTAssertEqual(measurement.unit, "mmHg")
        XCTAssertEqual(measurement.source, .appleHealth)
        XCTAssertEqual(measurement.formattedValue, "122/79 mmHg")

        let extracted = repository.extractHealthMetadata(from: measurement)
        XCTAssertEqual(extracted?.sampleId, bpId)
    }

    // MARK: - 3. Metadata Round-Trip & Notes Parsing

    func testHealthSourceMetadataRoundTripAndNotesExtraction() {
        let meta = HealthSourceMetadata(
            sampleId: UUID(),
            sourceName: "Garmin Connect",
            sourceBundleIdentifier: "com.garmin.connect",
            deviceModel: "Forerunner 965",
            deviceManufacturer: "Garmin",
            isUserEntered: false,
            originalUnit: "bpm",
            startDate: Date(),
            endDate: Date(),
            hkSampleType: "HKQuantityTypeIdentifierHeartRate"
        )

        let embeddedNotes = meta.embedInNotes(existingNotes: "Morning fasted reading after cardio.")
        let (extracted, userNotes) = HealthSourceMetadata.extract(fromNotes: embeddedNotes)

        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.sourceName, "Garmin Connect")
        XCTAssertEqual(extracted?.deviceModel, "Forerunner 965")
        XCTAssertEqual(userNotes, "Morning fasted reading after cardio.")
    }

    // MARK: - 4. Idempotent Synchronization & Deduplication

    func testHealthRepositorySyncDeduplication() async throws {
        let now = Date()
        let dateInterval = DateInterval(start: now.addingTimeInterval(-86400 * 7), end: now)

        // First sync run
        let firstSync = try await repository.syncMeasurements(for: ["weight", "resting_heart_rate"], dateInterval: dateInterval)
        XCTAssertGreaterThan(firstSync.count, 0)

        let countAfterFirst = try await mockMeasurementRepo.fetchAll().filter { $0.source == .appleHealth }.count
        XCTAssertEqual(countAfterFirst, firstSync.count)

        // Second sync run with identical date interval
        let secondSync = try await repository.syncMeasurements(for: ["weight", "resting_heart_rate"], dateInterval: dateInterval)
        XCTAssertEqual(secondSync.count, 0, "Second sync of identical samples must deduplicate and return 0 new inserts")

        let countAfterSecond = try await mockMeasurementRepo.fetchAll().filter { $0.source == .appleHealth }.count
        XCTAssertEqual(countAfterSecond, countAfterFirst, "Total stored count must not grow on redundant syncs")
    }

    // MARK: - 5. Disabling HealthKit Integration at Any Time

    func testDisablingHealthKitIntegrationHaltsSync() async throws {
        // Disable integration
        try await repository.setIntegrationEnabled(false)
        XCTAssertFalse(repository.isIntegrationEnabled)

        let now = Date()
        let interval = DateInterval(start: now.addingTimeInterval(-86400), end: now)

        let results = try await repository.syncMeasurements(for: nil, dateInterval: interval)
        XCTAssertTrue(results.isEmpty, "When disabled, sync must immediately return empty array")

        // Permission request should throw integrationDisabled
        do {
            _ = try await repository.requestPermissions(for: nil)
            XCTFail("Should have failed with integrationDisabled")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .integrationDisabled)
        }
    }

    // MARK: - 6. Purging Imported HealthKit Data

    func testPurgeImportedAppleHealthMeasurements() async throws {
        let now = Date()
        let interval = DateInterval(start: now.addingTimeInterval(-86400), end: now)

        // 1. Add a manual measurement
        let manualMeasurement = Measurement.weight(180.0, dateRecorded: now, source: .manualEntry, notes: "Logged manually")
        try await mockMeasurementRepo.save(manualMeasurement)

        // 2. Sync from Apple Health
        let synced = try await repository.syncMeasurements(for: ["weight"], dateInterval: interval)
        XCTAssertGreaterThan(synced.count, 0)

        // Verify total measurements has both
        let allBeforePurge = try await mockMeasurementRepo.fetchAll()
        XCTAssertTrue(allBeforePurge.contains(where: { $0.source == .manualEntry }))
        XCTAssertTrue(allBeforePurge.contains(where: { $0.source == .appleHealth }))

        // 3. Purge Apple Health
        try await repository.purgeImportedMeasurements()

        // 4. Verify only manual measurements remain
        let allAfterPurge = try await mockMeasurementRepo.fetchAll()
        XCTAssertTrue(allAfterPurge.contains(where: { $0.source == .manualEntry }), "Manual measurements must be preserved")
        XCTAssertFalse(allAfterPurge.contains(where: { $0.source == .appleHealth }), "Apple Health measurements must be purged")
    }
}
