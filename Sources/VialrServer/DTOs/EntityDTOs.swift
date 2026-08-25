import Vapor
import Foundation

// MARK: - Compound DTOs
public struct CompoundDTO: Content {
    public let id: UUID?
    public let name: String
    public let category: String
    public let defaultDose: Double
    public let defaultUnit: String
    public let halfLifeHours: Double
    public let notes: String?
}

// MARK: - Protocol DTOs
public struct ProtocolDTO: Content {
    public let id: UUID?
    public let compoundId: UUID
    public let name: String
    public let scheduleFrequency: String
    public let doseAmount: Double
    public let doseUnit: String
    public let cycleDurationWeeks: Int
    public let startDate: Date
    public let endDate: Date?
    public let notes: String?
    public let status: String?
}

// MARK: - Dose Log DTOs
public struct DoseLogDTO: Content {
    public let id: UUID?
    public let protocolId: UUID?
    public let compoundId: UUID
    public let scheduledDate: Date
    public let administeredDate: Date?
    public let doseAmount: Double
    public let doseUnit: String
    public let injectionSite: String?
    public let status: String
    public let notes: String?
    public let painScore: Int?
}

// MARK: - Vial DTOs
public struct VialDTO: Content {
    public let id: UUID?
    public let compoundId: UUID
    public let lotNumber: String?
    public let dryMassMg: Double
    public let diluentVolumeMl: Double?
    public let concentrationMgMl: Double?
    public let currentVolumeRemainingMl: Double?
    public let expirationDate: Date?
    public let costUsd: Double?
    public let status: String?
    public let notes: String?
}

// MARK: - Biomarker DTOs
public struct BiomarkerDTO: Content {
    public let id: UUID?
    public let name: String
    public let value: Double
    public let unit: String
    public let referenceRangeMin: Double?
    public let referenceRangeMax: Double?
    public let testDate: Date
    public let labName: String?
    public let notes: String?
}

// MARK: - Offline Delta Sync DTOs
public struct SyncDeltaItemDTO: Content {
    public let id: UUID
    public let entityType: String
    public let entityId: UUID
    public let operation: String // "create", "update", "delete"
    public let payloadJson: String?
    public let timestamp: Date
}

public struct SyncPushRequestDTO: Content {
    public let changes: [SyncDeltaItemDTO]
}

public struct SyncPullResponseDTO: Content {
    public let serverTimestamp: Date
    public let changes: [SyncDeltaItemDTO]
}

// MARK: - Clinician Report DTOs
public struct ClinicianReportRequestDTO: Content {
    public let dateRangeStart: Date
    public let dateRangeEnd: Date
    public let patientName: String
    public let dateOfBirth: String
    public let clinicianName: String
    public let practiceOrClinic: String
}

public struct ClinicianReportResponseDTO: Content {
    public let generatedAt: Date
    public let patientName: String
    public let activeProtocolsCount: Int
    public let adherenceRate: Double
    public let dosesLoggedCount: Int
    public let biomarkersCount: Int
    public let summaryText: String
    public let storedFileId: UUID?
    public let downloadUrl: String?

    public init(
        generatedAt: Date,
        patientName: String,
        activeProtocolsCount: Int,
        adherenceRate: Double,
        dosesLoggedCount: Int,
        biomarkersCount: Int,
        summaryText: String,
        storedFileId: UUID? = nil,
        downloadUrl: String? = nil
    ) {
        self.generatedAt = generatedAt
        self.patientName = patientName
        self.activeProtocolsCount = activeProtocolsCount
        self.adherenceRate = adherenceRate
        self.dosesLoggedCount = dosesLoggedCount
        self.biomarkersCount = biomarkersCount
        self.summaryText = summaryText
        self.storedFileId = storedFileId
        self.downloadUrl = downloadUrl
    }
}

