import Foundation
import Vapor

/// Object storage backend using the local filesystem (ideal for development, tests, Docker volume mounts).
public struct FileSystemObjectStorageService: ObjectStorageProtocol {
    public let rootDirectoryURL: URL
    private let fileManager = FileManager.default
    private let baseURL: URL

    public init(
        rootDirectoryURL: URL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("vialr-object-store"),
        baseURL: URL = URL(string: "http://localhost:8080")!
    ) {
        self.rootDirectoryURL = rootDirectoryURL
        self.baseURL = baseURL
        
        // Ensure root directory exists
        try? fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)
    }

    private func fileURL(for key: String, bucket: String) -> URL {
        let safeBucket = bucket.replacingOccurrences(of: "..", with: "")
        let safeKey = key.replacingOccurrences(of: "..", with: "")
        return rootDirectoryURL
            .appendingPathComponent(safeBucket)
            .appendingPathComponent(safeKey)
    }

    public func putObject(key: String, bucket: String, data: Data, contentType: String) async throws {
        let targetURL = fileURL(for: key, bucket: bucket)
        let parentDir = targetURL.deletingLastPathComponent()

        do {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try data.write(to: targetURL, options: .atomic)
        } catch {
            throw StorageError.writeFailed("Failed to write \(key) to disk: \(error.localizedDescription)")
        }
    }

    public func getObject(key: String, bucket: String) async throws -> Data {
        let targetURL = fileURL(for: key, bucket: bucket)
        guard fileManager.fileExists(atPath: targetURL.path) else {
            throw StorageError.objectNotFound(key: key, bucket: bucket)
        }

        do {
            return try Data(contentsOf: targetURL)
        } catch {
            throw StorageError.readFailed("Failed to read \(key) from disk: \(error.localizedDescription)")
        }
    }

    public func deleteObject(key: String, bucket: String) async throws {
        let targetURL = fileURL(for: key, bucket: bucket)
        if fileManager.fileExists(atPath: targetURL.path) {
            do {
                try fileManager.removeItem(at: targetURL)
            } catch {
                throw StorageError.deleteFailed("Failed to delete \(key) from disk: \(error.localizedDescription)")
            }
        }
    }

    public func objectExists(key: String, bucket: String) async throws -> Bool {
        let targetURL = fileURL(for: key, bucket: bucket)
        return fileManager.fileExists(atPath: targetURL.path)
    }

    public func generatePresignedDownloadURL(key: String, bucket: String, expiresInSeconds: Int) async throws -> URL {
        let expiresTimestamp = Int(Date().timeIntervalSince1970) + expiresInSeconds
        let path = "/api/v1/files/direct/\(bucket)/\(key)?expires=\(expiresTimestamp)"
        return URL(string: path, relativeTo: baseURL) ?? baseURL
    }

    public func generatePresignedUploadURL(key: String, bucket: String, expiresInSeconds: Int, contentType: String) async throws -> URL {
        let expiresTimestamp = Int(Date().timeIntervalSince1970) + expiresInSeconds
        let path = "/api/v1/files/direct/\(bucket)/\(key)?upload=true&expires=\(expiresTimestamp)"
        return URL(string: path, relativeTo: baseURL) ?? baseURL
    }
}
