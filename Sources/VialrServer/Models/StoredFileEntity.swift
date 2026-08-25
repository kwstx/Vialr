import Fluent
import Vapor
import Domain

/// PostgreSQL Fluent model storing metadata, integrity checksums, encryption attributes,
/// and entity relationships for files whose binary data is kept in encrypted object storage.
public final class StoredFileEntity: Model, Content, @unchecked Sendable {
    public static let schema = "stored_files"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Field(key: "category")
    public var category: String

    @Field(key: "file_name")
    public var fileName: String

    @Field(key: "content_type")
    public var contentType: String

    @Field(key: "byte_size")
    public var byteSize: Int64

    @Field(key: "sha256_checksum")
    public var sha256Checksum: String

    @Field(key: "storage_bucket")
    public var storageBucket: String

    @Field(key: "storage_key")
    public var storageKey: String

    @Field(key: "encryption_algorithm")
    public var encryptionAlgorithm: String

    @Field(key: "encryption_key_id")
    public var encryptionKeyId: String

    @Field(key: "encryption_iv")
    public var encryptionIV: String

    @Field(key: "encryption_tag")
    public var encryptionTag: String

    @Field(key: "is_encrypted")
    public var isEncrypted: Bool

    // MARK: - Relational Foreign Keys in PostgreSQL
    
    @OptionalParent(key: "vial_id")
    public var vial: VialEntity?

    @OptionalParent(key: "biomarker_id")
    public var biomarker: BiomarkerEntity?

    @OptionalParent(key: "dose_log_id")
    public var doseLog: DoseLogEntity?

    @OptionalParent(key: "protocol_id")
    public var protocolEntity: ProtocolEntity?

    @OptionalParent(key: "symptom_log_id")
    public var symptomLog: SymptomLogEntity?

    @Field(key: "metadata_json")
    public var metadataJson: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userId: UUID,
        category: StoredFileCategory,
        fileName: String,
        contentType: String,
        byteSize: Int64,
        sha256Checksum: String,
        storageBucket: String,
        storageKey: String,
        encryption: StorageEncryptionMetadata,
        vialId: UUID? = nil,
        biomarkerId: UUID? = nil,
        doseLogId: UUID? = nil,
        protocolId: UUID? = nil,
        symptomLogId: UUID? = nil,
        metadataJson: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.category = category.rawValue
        self.fileName = fileName
        self.contentType = contentType
        self.byteSize = byteSize
        self.sha256Checksum = sha256Checksum
        self.storageBucket = storageBucket
        self.storageKey = storageKey
        self.encryptionAlgorithm = encryption.algorithm
        self.encryptionKeyId = encryption.keyId
        self.encryptionIV = encryption.initializationVector
        self.encryptionTag = encryption.authenticationTag
        self.isEncrypted = encryption.isEncrypted
        self.$vial.id = vialId
        self.$biomarker.id = biomarkerId
        self.$doseLog.id = doseLogId
        self.$protocolEntity.id = protocolId
        self.$symptomLog.id = symptomLogId
        self.metadataJson = metadataJson
    }

    /// Extracts domain encryption metadata structure.
    public var encryptionMetadata: StorageEncryptionMetadata {
        StorageEncryptionMetadata(
            algorithm: encryptionAlgorithm,
            keyId: encryptionKeyId,
            initializationVector: encryptionIV,
            authenticationTag: encryptionTag,
            isEncrypted: isEncrypted
        )
    }

    /// Converts to domain model record.
    public func toDomainRecord() -> StoredFileRecord {
        let cat = StoredFileCategory(rawValue: category) ?? .userDocument
        var metaMap: [String: String] = [:]
        if let json = metadataJson, let data = json.data(using: .utf8),
           let parsed = try? JSONDecoder().decode([String: String].self, from: data) {
            metaMap = parsed
        }

        return StoredFileRecord(
            id: self.id ?? UUID(),
            userId: self.$user.id,
            category: cat,
            fileName: self.fileName,
            contentType: self.contentType,
            byteSize: self.byteSize,
            sha256Checksum: self.sha256Checksum,
            storageBucket: self.storageBucket,
            storageKey: self.storageKey,
            encryption: self.encryptionMetadata,
            vialId: self.$vial.id,
            biomarkerId: self.$biomarker.id,
            doseLogId: self.$doseLog.id,
            protocolId: self.$protocolEntity.id,
            symptomLogId: self.$symptomLog.id,
            metadata: metaMap,
            createdAt: self.createdAt ?? Date(),
            updatedAt: self.updatedAt
        )
    }
}
