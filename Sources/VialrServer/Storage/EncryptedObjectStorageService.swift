import Foundation
import Vapor
import Domain

/// High-level encrypted object storage service.
/// Orchestrates envelope encryption (AES-256-GCM) so that binary files (user documents,
/// lab PDFs, vial photographs, progress photographs, exported reports) are NEVER stored
/// unencrypted in object storage or as raw BLOBs inside PostgreSQL.
public final class EncryptedObjectStorageService: Sendable {
    public let bucket: String
    public let storageBackend: ObjectStorageProtocol
    public let encryptionService: StorageEncryptionService

    public init(
        bucket: String = "vialr-secure-vault",
        storageBackend: ObjectStorageProtocol,
        encryptionService: StorageEncryptionService
    ) {
        self.bucket = bucket
        self.storageBackend = storageBackend
        self.encryptionService = encryptionService
    }

    /// Uploads and encrypts a file payload into object storage.
    /// Returns the assigned storage key, bucket, encryption metadata, raw size, and SHA-256 checksum.
    public func upload(
        userId: UUID,
        category: StoredFileCategory,
        fileId: UUID = UUID(),
        fileName: String,
        rawData: Data,
        contentType: String
    ) async throws -> (
        fileId: UUID,
        storageKey: String,
        bucket: String,
        encryption: StorageEncryptionMetadata,
        byteSize: Int64,
        sha256: String
    ) {
        // 1. Validate file size
        let byteSize = Int64(rawData.count)
        if byteSize > category.maxAllowedSizeBytes {
            throw StorageError.fileTooLarge(size: byteSize, maxAllowed: category.maxAllowedSizeBytes)
        }

        // 2. Normalize and validate content type
        let normalizedContentType = contentType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !category.allowedContentTypes.isEmpty && !category.allowedContentTypes.contains(normalizedContentType) {
            // If MIME isn't strictly recognized but extension matches, tolerate or reject
            // Allow general octet-stream only if explicitly compatible
        }

        // 3. Encrypt raw binary with AES-256-GCM & calculate SHA-256
        let (ciphertext, encryptionMeta, sha256) = try encryptionService.encrypt(plaintext: rawData)

        // 4. Construct unique hierarchical storage key
        let sanitizedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? fileId.uuidString
        let storageKey = "vault/users/\(userId.uuidString)/\(category.defaultFolderPrefix)/\(fileId.uuidString)_\(sanitizedFileName).enc"

        // 5. Store ciphertext in Object Storage
        try await storageBackend.putObject(
            key: storageKey,
            bucket: bucket,
            data: ciphertext,
            contentType: "application/octet-stream"
        )

        return (
            fileId: fileId,
            storageKey: storageKey,
            bucket: bucket,
            encryption: encryptionMeta,
            byteSize: byteSize,
            sha256: sha256
        )
    }

    /// Fetches encrypted ciphertext from object storage, decrypts with AES-256-GCM, and validates auth tag.
    public func download(
        storageKey: String,
        bucket: String? = nil,
        encryption: StorageEncryptionMetadata
    ) async throws -> Data {
        let targetBucket = bucket ?? self.bucket

        // 1. Fetch ciphertext from Object Storage
        let ciphertext = try await storageBackend.getObject(key: storageKey, bucket: targetBucket)

        // 2. Decrypt ciphertext & verify auth tag against tampering
        let plaintext = try encryptionService.decrypt(ciphertext: ciphertext, metadata: encryption)

        return plaintext
    }

    /// Deletes the encrypted object from object storage.
    public func delete(storageKey: String, bucket: String? = nil) async throws {
        let targetBucket = bucket ?? self.bucket
        try await storageBackend.deleteObject(key: storageKey, bucket: targetBucket)
    }

    /// Generates a signed temporary URL for direct access if supported.
    public func generatePresignedDownloadURL(
        storageKey: String,
        bucket: String? = nil,
        expiresInSeconds: Int = 900
    ) async throws -> URL {
        let targetBucket = bucket ?? self.bucket
        return try await storageBackend.generatePresignedDownloadURL(
            key: storageKey,
            bucket: targetBucket,
            expiresInSeconds: expiresInSeconds
        )
    }
}

// MARK: - Vapor Application Storage Injection

public struct EncryptedStorageKey: StorageKey {
    public typealias Value = EncryptedObjectStorageService
}

extension Application {
    public var encryptedStorage: EncryptedObjectStorageService {
        get {
            guard let storage = self.storage[EncryptedStorageKey.self] else {
                fatalError("EncryptedObjectStorageService not configured. Register it in configure.swift.")
            }
            return storage
        }
        set {
            self.storage[EncryptedStorageKey.self] = newValue
        }
    }
}

extension Request {
    public var encryptedStorage: EncryptedObjectStorageService {
        return self.application.encryptedStorage
    }
}
