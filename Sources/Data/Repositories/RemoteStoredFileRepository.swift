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

    // MARK: - Direct Object Storage Upload Workflow (No BLOBs in PostgreSQL)

    /// 1. Requests temporary upload authorization and presigned URL from backend.
    public func requestUploadAuthorization(
        category: StoredFileCategory,
        fileName: String,
        contentType: String,
        byteSize: Int64,
        vialId: UUID? = nil,
        biomarkerId: UUID? = nil,
        doseLogId: UUID? = nil,
        protocolId: UUID? = nil,
        symptomLogId: UUID? = nil,
        metadata: [String: String]? = nil
    ) async throws -> UploadAuthorizationResponseDTO {
        let endpoint = Endpoint.requestUploadAuthorization
        let body = UploadAuthorizationRequestDTO(
            fileName: fileName,
            contentType: contentType,
            byteSize: byteSize,
            category: category.rawValue,
            vialId: vialId,
            biomarkerId: biomarkerId,
            doseLogId: doseLogId,
            protocolId: protocolId,
            symptomLogId: symptomLogId,
            metadata: metadata
        )
        return try await apiClient.request(endpoint: endpoint, body: body, responseType: UploadAuthorizationResponseDTO.self)
    }

    /// 2. Streams binary data directly to encrypted object storage using presigned URL.
    public func uploadDirectlyToStorage(
        uploadUrlString: String,
        data: Data,
        contentType: String,
        headers: [String: String] = [:]
    ) async throws {
        guard let url = URL(string: uploadUrlString) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            let bodyText = String(data: responseData, encoding: .utf8) ?? ""
            throw NetworkError.serverError(statusCode: statusCode, message: "Direct storage upload failed: \(bodyText)")
        }
    }

    /// 3. Confirms upload with backend, recording object identifier and metadata in PostgreSQL.
    public func confirmDirectUpload(
        fileId: UUID,
        storageKey: String,
        storageBucket: String? = nil,
        fileName: String,
        contentType: String,
        byteSize: Int64,
        sha256Checksum: String,
        category: StoredFileCategory,
        encryptionIV: String? = nil,
        encryptionTag: String? = nil,
        encryptionKeyId: String? = nil,
        triggerProcessing: Bool = true,
        vialId: UUID? = nil,
        biomarkerId: UUID? = nil,
        doseLogId: UUID? = nil,
        protocolId: UUID? = nil,
        symptomLogId: UUID? = nil,
        metadata: [String: String]? = nil
    ) async throws -> (record: StoredFileRecord, job: DocumentProcessingJobDTO?) {
        let endpoint = Endpoint.confirmUpload
        let body = UploadConfirmationRequestDTO(
            fileId: fileId,
            storageKey: storageKey,
            storageBucket: storageBucket,
            fileName: fileName,
            contentType: contentType,
            byteSize: byteSize,
            sha256Checksum: sha256Checksum,
            category: category.rawValue,
            encryptionIV: encryptionIV,
            encryptionTag: encryptionTag,
            encryptionKeyId: encryptionKeyId,
            triggerProcessing: triggerProcessing,
            vialId: vialId,
            biomarkerId: biomarkerId,
            doseLogId: doseLogId,
            protocolId: protocolId,
            symptomLogId: symptomLogId,
            metadata: metadata
        )
        let resp = try await apiClient.request(endpoint: endpoint, body: body, responseType: UploadConfirmationResponseDTO.self)
        return (record: resp.file.toDomainRecord(), job: resp.processingJob)
    }

    /// 4. Convenience orchestrator: executes complete 3-step direct object storage upload pipeline.
    public func uploadDocumentDirectly(
        category: StoredFileCategory,
        fileName: String,
        data: Data,
        contentType: String,
        vialId: UUID? = nil,
        biomarkerId: UUID? = nil,
        doseLogId: UUID? = nil,
        protocolId: UUID? = nil,
        symptomLogId: UUID? = nil,
        metadata: [String: String]? = nil,
        triggerProcessing: Bool = true
    ) async throws -> (record: StoredFileRecord, job: DocumentProcessingJobDTO?) {
        let byteSize = Int64(data.count)

        // Step 1: Request temporary upload authorization from backend
        let auth = try await requestUploadAuthorization(
            category: category,
            fileName: fileName,
            contentType: contentType,
            byteSize: byteSize,
            vialId: vialId,
            biomarkerId: biomarkerId,
            doseLogId: doseLogId,
            protocolId: protocolId,
            symptomLogId: symptomLogId,
            metadata: metadata
        )

        // Step 2: Upload file directly to object storage vault
        try await uploadDirectlyToStorage(
            uploadUrlString: auth.uploadUrl,
            data: data,
            contentType: contentType,
            headers: auth.headers
        )

        // Step 3: Record object identifier and trigger worker in backend
        let sha256 = StorageEncryptionService.computeChecksum(data: data)
        return try await confirmDirectUpload(
            fileId: auth.fileId,
            storageKey: auth.storageKey,
            storageBucket: auth.storageBucket,
            fileName: fileName,
            contentType: contentType,
            byteSize: byteSize,
            sha256Checksum: sha256,
            category: category,
            triggerProcessing: triggerProcessing,
            vialId: vialId,
            biomarkerId: biomarkerId,
            doseLogId: doseLogId,
            protocolId: protocolId,
            symptomLogId: symptomLogId,
            metadata: metadata
        )
    }

    /// 5. Triggers backend worker to extract structured data from an existing stored document.
    public func processDocument(fileId: UUID) async throws -> DocumentProcessingResultDTO {
        let endpoint = Endpoint.processFile(id: fileId)
        let emptyBody: String? = nil
        return try await apiClient.request(endpoint: endpoint, body: emptyBody, responseType: DocumentProcessingResultDTO.self)
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
