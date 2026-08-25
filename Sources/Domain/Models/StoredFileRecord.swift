import Foundation

/// Represents a secure file record whose binary contents reside in encrypted object storage
/// while its structured metadata, relationships, and integrity checksums reside in PostgreSQL.
public struct StoredFileRecord: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var userId: UUID
    public var category: StoredFileCategory
    public var fileName: String
    public var contentType: String
    public var byteSize: Int64
    public var sha256Checksum: String
    public var storageBucket: String
    public var storageKey: String
    public var encryption: StorageEncryptionMetadata
    
    // Relational Foreign Key References in PostgreSQL
    public var vialId: UUID?
    public var biomarkerId: UUID?
    public var doseLogId: UUID?
    public var protocolId: UUID?
    public var symptomLogId: UUID?
    
    // Extensible Metadata (e.g. dimensions, page count, notes)
    public var metadata: [String: String]
    public var createdAt: Date
    public var updatedAt: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        category: StoredFileCategory,
        fileName: String,
        contentType: String,
        byteSize: Int64,
        sha256Checksum: String,
        storageBucket: String,
        storageKey: String,
        encryption: StorageEncryptionMetadata = StorageEncryptionMetadata(),
        vialId: UUID? = nil,
        biomarkerId: UUID? = nil,
        doseLogId: UUID? = nil,
        protocolId: UUID? = nil,
        symptomLogId: UUID? = nil,
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.category = category
        self.fileName = fileName
        self.contentType = contentType
        self.byteSize = byteSize
        self.sha256Checksum = sha256Checksum
        self.storageBucket = storageBucket
        self.storageKey = storageKey
        self.encryption = encryption
        self.vialId = vialId
        self.biomarkerId = biomarkerId
        self.doseLogId = doseLogId
        self.protocolId = protocolId
        self.symptomLogId = symptomLogId
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
