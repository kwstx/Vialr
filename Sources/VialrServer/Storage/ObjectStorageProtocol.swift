import Foundation

/// Interface defining primitive object storage operations (S3, MinIO, FileSystem, etc.)
public protocol ObjectStorageProtocol: Sendable {
    /// Persists raw bytes under the given storage key and bucket.
    func putObject(key: String, bucket: String, data: Data, contentType: String) async throws
    
    /// Retrieves raw bytes stored under the given storage key and bucket.
    func getObject(key: String, bucket: String) async throws -> Data
    
    /// Deletes the object stored under the given storage key and bucket.
    func deleteObject(key: String, bucket: String) async throws
    
    /// Checks whether an object exists under the given storage key and bucket.
    func objectExists(key: String, bucket: String) async throws -> Bool
    
    /// Generates a signed, temporary download URL for the object.
    func generatePresignedDownloadURL(key: String, bucket: String, expiresInSeconds: Int) async throws -> URL
    
    /// Generates a signed, temporary upload URL for direct client upload.
    func generatePresignedUploadURL(key: String, bucket: String, expiresInSeconds: Int, contentType: String) async throws -> URL
}

public enum StorageError: Error, LocalizedError, Sendable {
    case objectNotFound(key: String, bucket: String)
    case writeFailed(String)
    case readFailed(String)
    case deleteFailed(String)
    case invalidKey(String)
    case encryptionFailed(String)
    case decryptionFailed(String)
    case authenticationTagMismatch
    case checksumMismatch(expected: String, actual: String)
    case fileTooLarge(size: Int64, maxAllowed: Int64)
    case unsupportedContentType(String)
    case configurationError(String)

    public var errorDescription: String? {
        switch self {
        case .objectNotFound(let key, let bucket):
            return "Object '\(key)' not found in storage bucket '\(bucket)'."
        case .writeFailed(let msg):
            return "Failed to write object to storage: \(msg)"
        case .readFailed(let msg):
            return "Failed to read object from storage: \(msg)"
        case .deleteFailed(let msg):
            return "Failed to delete object from storage: \(msg)"
        case .invalidKey(let key):
            return "Invalid storage key: \(key)"
        case .encryptionFailed(let msg):
            return "Encryption error: \(msg)"
        case .decryptionFailed(let msg):
            return "Decryption error: \(msg)"
        case .authenticationTagMismatch:
            return "Authentication tag mismatch: The stored encrypted file has been tampered with or corrupted."
        case .checksumMismatch(let expected, let actual):
            return "Integrity checksum mismatch (expected: \(expected), actual: \(actual))."
        case .fileTooLarge(let size, let maxAllowed):
            return "File size (\(size) bytes) exceeds maximum limit (\(maxAllowed) bytes)."
        case .unsupportedContentType(let type):
            return "Content type '\(type)' is not permitted for this document category."
        case .configurationError(let msg):
            return "Storage configuration error: \(msg)"
        }
    }
}
