import Vapor
import Foundation

// MARK: - Stored File DTOs

public struct StoredFileDTO: Content {
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

public struct FileUploadResponseDTO: Content {
    public let file: StoredFileDTO
    public let message: String
}

public struct FileRelateRequestDTO: Content {
    public let vialId: UUID?
    public let biomarkerId: UUID?
    public let doseLogId: UUID?
    public let protocolId: UUID?
    public let symptomLogId: UUID?
    public let notes: String?
}

public struct FileListFilterQueryDTO: Content {
    public let category: String?
    public let vialId: UUID?
    public let biomarkerId: UUID?
    public let doseLogId: UUID?
    public let protocolId: UUID?
    public let symptomLogId: UUID?
}
