import Foundation
import Domain

/// Remote repository communicating with VialrServer API for stored files and encrypted object storage.
public final class RemoteStoredFileRepository: StoredFileRepositoryProtocol, @unchecked Sendable {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    public func fetchAll() async throws -> [StoredFileRecord] {
        let endpoint = Endpoint.listFiles()
        let dtos = try await apiClient.request(endpoint: endpoint, responseType: [StoredFileRemoteDTO].self)
        return dtos.map { $0.toDomainRecord() }
    }

    public func fetchByCategory(_ category: StoredFileCategory) async throws -> [StoredFileRecord] {
        let endpoint = Endpoint.listFiles(category: category.rawValue)
        let dtos = try await apiClient.request(endpoint: endpoint, responseType: [StoredFileRemoteDTO].self)
        return dtos.map { $0.toDomainRecord() }
    }

    public func fetchForVial(vialId: UUID) async throws -> [StoredFileRecord] {
        let endpoint = Endpoint.listFiles(vialId: vialId)
        let dtos = try await apiClient.request(endpoint: endpoint, responseType: [StoredFileRemoteDTO].self)
        return dtos.map { $0.toDomainRecord() }
    }

    public func fetchForBiomarker(biomarkerId: UUID) async throws -> [StoredFileRecord] {
        let endpoint = Endpoint.listFiles(biomarkerId: biomarkerId)
        let dtos = try await apiClient.request(endpoint: endpoint, responseType: [StoredFileRemoteDTO].self)
        return dtos.map { $0.toDomainRecord() }
    }

    public func fetchForDoseLog(doseLogId: UUID) async throws -> [StoredFileRecord] {
        let endpoint = Endpoint.listFiles(doseLogId: doseLogId)
        let dtos = try await apiClient.request(endpoint: endpoint, responseType: [StoredFileRemoteDTO].self)
        return dtos.map { $0.toDomainRecord() }
    }

    public func fetchForProtocol(protocolId: UUID) async throws -> [StoredFileRecord] {
        let endpoint = Endpoint.listFiles()
        let dtos = try await apiClient.request(endpoint: endpoint, responseType: [StoredFileRemoteDTO].self)
        return dtos.filter { $0.protocolId == protocolId }.map { $0.toDomainRecord() }
    }

    public func fetch(byId id: UUID) async throws -> StoredFileRecord? {
        let endpoint = Endpoint.getFileMetadata(id: id)
        let dto = try await apiClient.request(endpoint: endpoint, responseType: StoredFileRemoteDTO.self)
        return dto.toDomainRecord()
    }

    public func save(_ record: StoredFileRecord) async throws {
        // Handled via multipart upload or relate endpoint
        let endpoint = Endpoint.relateFile(id: record.id)
        let body = [
            "vialId": record.vialId?.uuidString,
            "biomarkerId": record.biomarkerId?.uuidString,
            "doseLogId": record.doseLogId?.uuidString,
            "protocolId": record.protocolId?.uuidString,
            "symptomLogId": record.symptomLogId?.uuidString
        ]
        _ = try await apiClient.request(endpoint: endpoint, body: body, responseType: StoredFileRemoteDTO.self)
    }

    public func delete(byId id: UUID) async throws {
        let endpoint = Endpoint.deleteFile(id: id)
        try await apiClient.request(endpoint: endpoint)
    }
}

/// DTO for decoding remote stored file metadata on client
public struct StoredFileRemoteDTO: Codable, Sendable {
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

    public func toDomainRecord() -> StoredFileRecord {
        let cat = StoredFileCategory(rawValue: category) ?? .userDocument
        return StoredFileRecord(
            id: id,
            userId: UUID(), // Managed by backend session
            category: cat,
            fileName: fileName,
            contentType: contentType,
            byteSize: byteSize,
            sha256Checksum: sha256Checksum,
            storageBucket: "vialr-secure-vault",
            storageKey: "",
            encryption: StorageEncryptionMetadata(
                algorithm: encryptionAlgorithm,
                keyId: "vialr-vault-primary",
                initializationVector: "",
                authenticationTag: "",
                isEncrypted: isEncrypted
            ),
            vialId: vialId,
            biomarkerId: biomarkerId,
            doseLogId: doseLogId,
            protocolId: protocolId,
            symptomLogId: symptomLogId,
            metadata: metadata ?? [:],
            createdAt: createdAt ?? Date()
        )
    }
}
