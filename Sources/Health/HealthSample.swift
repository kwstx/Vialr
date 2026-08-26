import Foundation
import Domain

// MARK: - HealthKit Source Metadata Retention

/// Preserves the raw provenance and device metadata from the original HealthKit sample.
public struct HealthSourceMetadata: Codable, Sendable, Hashable {
    public let sampleId: UUID
    public let sourceName: String
    public let sourceBundleIdentifier: String
    public let deviceModel: String?
    public let deviceManufacturer: String?
    public let deviceHardwareVersion: String?
    public let deviceSoftwareVersion: String?
    public let isUserEntered: Bool
    public let originalUnit: String
    public let startDate: Date
    public let endDate: Date
    public let hkSampleType: String
    public let customMetadata: [String: String]

    public init(
        sampleId: UUID = UUID(),
        sourceName: String,
        sourceBundleIdentifier: String,
        deviceModel: String? = nil,
        deviceManufacturer: String? = nil,
        deviceHardwareVersion: String? = nil,
        deviceSoftwareVersion: String? = nil,
        isUserEntered: Bool = false,
        originalUnit: String,
        startDate: Date,
        endDate: Date,
        hkSampleType: String,
        customMetadata: [String: String] = [:]
    ) {
        self.sampleId = sampleId
        self.sourceName = sourceName
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.deviceModel = deviceModel
        self.deviceManufacturer = deviceManufacturer
        self.deviceHardwareVersion = deviceHardwareVersion
        self.deviceSoftwareVersion = deviceSoftwareVersion
        self.isUserEntered = isUserEntered
        self.originalUnit = originalUnit
        self.startDate = startDate
        self.endDate = endDate
        self.hkSampleType = hkSampleType
        self.customMetadata = customMetadata
    }

    // MARK: - JSON Encoding / Extraction Helpers
    private static let metadataTagPrefix = "--- [HEALTHKIT_METADATA_START] ---"
    private static let metadataTagSuffix = "--- [HEALTHKIT_METADATA_END] ---"

    public func encodeToJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self),
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    public static func decodeFromJSON(_ string: String) -> HealthSourceMetadata? {
        guard let data = string.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HealthSourceMetadata.self, from: data)
    }

    /// Embeds the metadata JSON safely into a domain measurement's `notes` string.
    public func embedInNotes(existingNotes: String = "") -> String {
        guard let json = encodeToJSON() else { return existingNotes }
        let cleanNotes = existingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanNotes.isEmpty {
            return "\(Self.metadataTagPrefix)\n\(json)\n\(Self.metadataTagSuffix)"
        } else {
            return "\(cleanNotes)\n\n\(Self.metadataTagPrefix)\n\(json)\n\(Self.metadataTagSuffix)"
        }
    }

    /// Extracts `HealthSourceMetadata` and strips the metadata block from user notes.
    public static func extract(fromNotes notes: String) -> (metadata: HealthSourceMetadata?, userNotes: String) {
        guard let startRange = notes.range(of: metadataTagPrefix),
              let endRange = notes.range(of: metadataTagSuffix) else {
            return (nil, notes)
        }

        let jsonSubstring = notes[startRange.upperBound..<endRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let metadata = decodeFromJSON(jsonSubstring)

        var cleanNotes = notes
        let blockRange = startRange.lowerBound..<endRange.upperBound
        cleanNotes.removeSubrange(blockRange)
        let trimmedNotes = cleanNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        return (metadata, trimmedNotes)
    }
}

// MARK: - Health Sample (General Quantity)

/// Internal sample representation returned from isolated HealthKit queries.
public struct HealthSample: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let metricType: HealthMetricType
    public let value: Double
    public let unit: String
    public let startDate: Date
    public let endDate: Date
    public let metadata: HealthSourceMetadata

    public init(
        id: UUID = UUID(),
        metricType: HealthMetricType,
        value: Double,
        unit: String,
        startDate: Date,
        endDate: Date,
        metadata: HealthSourceMetadata
    ) {
        self.id = id
        self.metricType = metricType
        self.value = value
        self.unit = unit
        self.startDate = startDate
        self.endDate = endDate
        self.metadata = metadata
    }
}

// MARK: - Workout Sample

/// Workout session imported from Apple Health.
public struct HealthWorkoutSample: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let workoutActivityName: String
    public let workoutActivityTypeRaw: UInt
    public let durationSeconds: Double
    public let totalEnergyBurnedKcal: Double?
    public let totalDistanceMeters: Double?
    public let startDate: Date
    public let endDate: Date
    public let metadata: HealthSourceMetadata

    public var durationMinutes: Double {
        durationSeconds / 60.0
    }

    public init(
        id: UUID = UUID(),
        workoutActivityName: String,
        workoutActivityTypeRaw: UInt = 0,
        durationSeconds: Double,
        totalEnergyBurnedKcal: Double? = nil,
        totalDistanceMeters: Double? = nil,
        startDate: Date,
        endDate: Date,
        metadata: HealthSourceMetadata
    ) {
        self.id = id
        self.workoutActivityName = workoutActivityName
        self.workoutActivityTypeRaw = workoutActivityTypeRaw
        self.durationSeconds = durationSeconds
        self.totalEnergyBurnedKcal = totalEnergyBurnedKcal
        self.totalDistanceMeters = totalDistanceMeters
        self.startDate = startDate
        self.endDate = endDate
        self.metadata = metadata
    }
}

// MARK: - Sleep Stages & Sleep Sample

public enum HealthSleepStage: String, Codable, Sendable, CaseIterable {
    case inBed = "In Bed"
    case asleepUnspecified = "Asleep"
    case awake = "Awake"
    case core = "Core / Light Sleep"
    case deep = "Deep Sleep"
    case rem = "REM Sleep"

    public var isRestorativeSleep: Bool {
        self == .asleepUnspecified || self == .core || self == .deep || self == .rem
    }
}

/// Sleep interval or session imported from Apple Health.
public struct HealthSleepSample: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let stage: HealthSleepStage
    public let durationHours: Double
    public let startDate: Date
    public let endDate: Date
    public let metadata: HealthSourceMetadata

    public init(
        id: UUID = UUID(),
        stage: HealthSleepStage,
        durationHours: Double,
        startDate: Date,
        endDate: Date,
        metadata: HealthSourceMetadata
    ) {
        self.id = id
        self.stage = stage
        self.durationHours = durationHours
        self.startDate = startDate
        self.endDate = endDate
        self.metadata = metadata
    }
}

// MARK: - Blood Pressure Sample

/// Paired systolic & diastolic reading from Apple Health.
public struct HealthBloodPressureSample: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let systolic: Double
    public let diastolic: Double
    public let unit: String
    public let dateRecorded: Date
    public let metadata: HealthSourceMetadata

    public init(
        id: UUID = UUID(),
        systolic: Double,
        diastolic: Double,
        unit: String = "mmHg",
        dateRecorded: Date = Date(),
        metadata: HealthSourceMetadata
    ) {
        self.id = id
        self.systolic = systolic
        self.diastolic = diastolic
        self.unit = unit
        self.dateRecorded = dateRecorded
        self.metadata = metadata
    }
}

// MARK: - Health Sync Result Summary

/// Detailed synchronization report returned after importing from Apple Health.
public struct HealthSyncResult: Codable, Sendable, Hashable {
    public let totalImported: Int
    public let totalUpdated: Int
    public let totalSkipped: Int
    public let errors: [String]
    public let syncTimestamp: Date

    public var isSuccessful: Bool {
        errors.isEmpty
    }

    public init(
        totalImported: Int = 0,
        totalUpdated: Int = 0,
        totalSkipped: Int = 0,
        errors: [String] = [],
        syncTimestamp: Date = Date()
    ) {
        self.totalImported = totalImported
        self.totalUpdated = totalUpdated
        self.totalSkipped = totalSkipped
        self.errors = errors
        self.syncTimestamp = syncTimestamp
    }
}
