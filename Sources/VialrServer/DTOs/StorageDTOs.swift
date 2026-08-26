import Vapor
import Foundation
import Domain

// MARK: - Stored File DTOs

public struct StoredFileDTO: Content, Sendable {
    public let id: UUID
    public let category: String
    public let fileName: String
    public let contentType: String
    public let byteSize: Int64
    public let sha256Checksum: String
    public let isEncrypted: Bool
    public let encryptionAlgorithm: String
    public let vialId: UUID?
    public let biomarkerId: UUID?
    public let doseLogId: UUID?
    public let protocolId: UUID?
    public let symptomLogId: UUID?
    public let metadata: [String: String]?
    public let createdAt: Date?
    public let downloadUrl: String

    public init(
        id: UUID,
        category: String,
        fileName: String,
        contentType: String,
        byteSize: Int64,
        sha256Checksum: String,
        isEncrypted: Bool = true,
        encryptionAlgorithm: String = "AES-256-GCM",
        vialId: UUID? = nil,
        biomarkerId: UUID? = nil,
        doseLogId: UUID? = nil,
        protocolId: UUID? = nil,
        symptomLogId: UUID? = nil,
        metadata: [String: String]? = nil,
        createdAt: Date? = nil,
        downloadUrl: String
    ) {
        self.id = id
        self.category = category
        self.fileName = fileName
        self.contentType = contentType
        self.byteSize = byteSize
        self.sha256Checksum = sha256Checksum
        self.isEncrypted = isEncrypted
        self.encryptionAlgorithm = encryptionAlgorithm
        self.vialId = vialId
        self.biomarkerId = biomarkerId
        self.doseLogId = doseLogId
        self.protocolId = protocolId
        self.symptomLogId = symptomLogId
        self.metadata = metadata
        self.createdAt = createdAt
        self.downloadUrl = downloadUrl
    }
}

public struct FileUploadResponseDTO: Content, Sendable {
    public let file: StoredFileDTO
    public let message: String
}

public struct FileRelateRequestDTO: Content, Sendable {
    public let vialId: UUID?
    public let biomarkerId: UUID?
    public let doseLogId: UUID?
    public let protocolId: UUID?
    public let symptomLogId: UUID?
    public let notes: String?
}

public struct FileListFilterQueryDTO: Content, Sendable {
    public let category: String?
    public let vialId: UUID?
    public let biomarkerId: UUID?
    public let doseLogId: UUID?
    public let protocolId: UUID?
    public let symptomLogId: UUID?
}

// MARK: - Direct Object Storage Upload Authorization DTOs

/// Request sent by client to obtain temporary upload authorization for direct storage upload.
public struct UploadAuthorizationRequestDTO: Content, Sendable {
    public let fileName: String
    public let contentType: String
    public let byteSize: Int64
    public let category: String
    public let vialId: UUID?
    public let biomarkerId: UUID?
    public let doseLogId: UUID?
    public let protocolId: UUID?
    public let symptomLogId: UUID?
    public let metadata: [String: String]?

    public init(
        fileName: String,
        contentType: String,
        byteSize: Int64,
        category: String,
        vialId: UUID? = nil,
        biomarkerId: UUID? = nil,
        doseLogId: UUID? = nil,
        protocolId: UUID? = nil,
        symptomLogId: UUID? = nil,
        metadata: [String: String]? = nil
    ) {
        self.fileName = fileName
        self.contentType = contentType
        self.byteSize = byteSize
        self.category = category
        self.vialId = vialId
        self.biomarkerId = biomarkerId
        self.doseLogId = doseLogId
        self.protocolId = protocolId
        self.symptomLogId = symptomLogId
        self.metadata = metadata
    }
}

/// Response returned to client with signed presigned URL and parameters for direct upload to encrypted object storage.
public struct UploadAuthorizationResponseDTO: Content, Sendable {
    public let fileId: UUID
    public let storageKey: String
    public let storageBucket: String
    public let uploadUrl: String
    public let httpMethod: String
    public let headers: [String: String]
    public let expiresAt: Date
    public let maxAllowedSizeBytes: Int64
    public let encryptionAlgorithm: String

    public init(
        fileId: UUID,
        storageKey: String,
        storageBucket: String,
        uploadUrl: String,
        httpMethod: String = "PUT",
        headers: [String: String] = [:],
        expiresAt: Date,
        maxAllowedSizeBytes: Int64,
        encryptionAlgorithm: String = "AES-256-GCM"
    ) {
        self.fileId = fileId
        self.storageKey = storageKey
        self.storageBucket = storageBucket
        self.uploadUrl = uploadUrl
        self.httpMethod = httpMethod
        self.headers = headers
        self.expiresAt = expiresAt
        self.maxAllowedSizeBytes = maxAllowedSizeBytes
        self.encryptionAlgorithm = encryptionAlgorithm
    }
}

/// Request sent by client after direct upload completes to record the object identifier in PostgreSQL.
public struct UploadConfirmationRequestDTO: Content, Sendable {
    public let fileId: UUID
    public let storageKey: String
    public let storageBucket: String?
    public let fileName: String
    public let contentType: String
    public let byteSize: Int64
    public let sha256Checksum: String
    public let category: String
    public let encryptionIV: String?
    public let encryptionTag: String?
    public let encryptionKeyId: String?
    public let triggerProcessing: Bool?
    public let vialId: UUID?
    public let biomarkerId: UUID?
    public let doseLogId: UUID?
    public let protocolId: UUID?
    public let symptomLogId: UUID?
    public let metadata: [String: String]?

    public init(
        fileId: UUID,
        storageKey: String,
        storageBucket: String? = nil,
        fileName: String,
        contentType: String,
        byteSize: Int64,
        sha256Checksum: String,
        category: String,
        encryptionIV: String? = nil,
        encryptionTag: String? = nil,
        encryptionKeyId: String? = nil,
        triggerProcessing: Bool? = true,
        vialId: UUID? = nil,
        biomarkerId: UUID? = nil,
        doseLogId: UUID? = nil,
        protocolId: UUID? = nil,
        symptomLogId: UUID? = nil,
        metadata: [String: String]? = nil
    ) {
        self.fileId = fileId
        self.storageKey = storageKey
        self.storageBucket = storageBucket
        self.fileName = fileName
        self.contentType = contentType
        self.byteSize = byteSize
        self.sha256Checksum = sha256Checksum
        self.category = category
        self.encryptionIV = encryptionIV
        self.encryptionTag = encryptionTag
        self.encryptionKeyId = encryptionKeyId
        self.triggerProcessing = triggerProcessing
        self.vialId = vialId
        self.biomarkerId = biomarkerId
        self.doseLogId = doseLogId
        self.protocolId = protocolId
        self.symptomLogId = symptomLogId
        self.metadata = metadata
    }
}

public struct UploadConfirmationResponseDTO: Content, Sendable {
    public let file: StoredFileDTO
    public let processingJob: DocumentProcessingJobDTO?
    public let message: String

    public init(
        file: StoredFileDTO,
        processingJob: DocumentProcessingJobDTO? = nil,
        message: String = "Object identifier recorded and registered in database."
    ) {
        self.file = file
        self.processingJob = processingJob
        self.message = message
    }
}

// MARK: - Document Processing Job DTOs

public struct DocumentProcessingJobDTO: Content, Sendable {
    public let jobId: UUID
    public let fileId: UUID
    public let status: String // "pending", "processing", "completed", "failed"
    public let extractedCandidatesCount: Int
    public let resultSummary: String?
    public let panelId: UUID?
    public let createdAt: Date
    public let completedAt: Date?

    public init(
        jobId: UUID = UUID(),
        fileId: UUID,
        status: String = "pending",
        extractedCandidatesCount: Int = 0,
        resultSummary: String? = nil,
        panelId: UUID? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.jobId = jobId
        self.fileId = fileId
        self.status = status
        self.extractedCandidatesCount = extractedCandidatesCount
        self.resultSummary = resultSummary
        self.panelId = panelId
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

public struct DocumentProcessingResultDTO: Content, Sendable {
    public let job: DocumentProcessingJobDTO
    public let candidates: [ExtractedCandidateItemDTO]
    public let warnings: [String]

    public init(
        job: DocumentProcessingJobDTO,
        candidates: [ExtractedCandidateItemDTO] = [],
        warnings: [String] = []
    ) {
        self.job = job
        self.candidates = candidates
        self.warnings = warnings
    }
}
