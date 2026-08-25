import Vapor
import Fluent
import Domain

/// Controller managing file uploads, downloads, relationship associations, and deletion.
/// Persists binary data exclusively into Encrypted Object Storage (AES-256-GCM) while
/// storing metadata, encryption keys/tags, and relational links in PostgreSQL.
public struct StoredFilesController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let filesGroup = routes.grouped("files")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        filesGroup.post("upload", use: uploadFile)
        filesGroup.get(use: listFiles)
        filesGroup.get(":fileId", use: getFileMetadata)
        filesGroup.get(":fileId", "download", use: downloadFile)
        filesGroup.patch(":fileId", "relate", use: relateFile)
        filesGroup.delete(":fileId", use: deleteFile)
    }

    // MARK: - Multipart Form Input Struct

    public struct FileUploadInput: Content {
        public var file: File
        public var category: String
        public var vialId: UUID?
        public var biomarkerId: UUID?
        public var doseLogId: UUID?
        public var protocolId: UUID?
        public var symptomLogId: UUID?
        public var notes: String?
    }

    // MARK: - 1. Upload File & Encrypt into Object Storage

    public func uploadFile(req: Request) async throws -> FileUploadResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let input = try req.content.decode(FileUploadInput.self)

        // Parse category
        guard let category = StoredFileCategory(rawValue: input.category) else {
            throw Abort(.badRequest, reason: "Invalid category. Allowed: \(StoredFileCategory.allCases.map { $0.rawValue }.joined(separator: ", "))")
        }

        // Validate related entities ownership if supplied
        if let vialId = input.vialId {
            let vial = try await VialEntity.query(on: req.db)
                .filter(\.$id == vialId)
                .filter(\.$user.$id == payload.userId)
                .first()
            guard vial != nil else {
                throw Abort(.badRequest, reason: "Referenced vial not found or unauthorized.")
            }
        }

        if let biomarkerId = input.biomarkerId {
            let marker = try await BiomarkerEntity.query(on: req.db)
                .filter(\.$id == biomarkerId)
                .filter(\.$user.$id == payload.userId)
                .first()
            guard marker != nil else {
                throw Abort(.badRequest, reason: "Referenced biomarker not found or unauthorized.")
            }
        }

        if let doseLogId = input.doseLogId {
            let dose = try await DoseLogEntity.query(on: req.db)
                .filter(\.$id == doseLogId)
                .filter(\.$user.$id == payload.userId)
                .first()
            guard dose != nil else {
                throw Abort(.badRequest, reason: "Referenced dose log not found or unauthorized.")
            }
        }

        // Extract raw data and content type
        let rawData = Data(buffer: input.file.data)
        let inferredContentType: String
        if let mime = input.file.contentType?.serialize() {
            inferredContentType = mime
        } else {
            let ext = (input.file.filename as NSString).pathExtension.lowercased()
            switch ext {
            case "pdf": inferredContentType = "application/pdf"
            case "jpg", "jpeg": inferredContentType = "image/jpeg"
            case "png": inferredContentType = "image/png"
            case "heic": inferredContentType = "image/heic"
            case "webp": inferredContentType = "image/webp"
            case "csv": inferredContentType = "text/csv"
            case "json": inferredContentType = "application/json"
            default: inferredContentType = "application/octet-stream"
            }
        }

        let fileId = UUID()
        let fileName = input.file.filename.isEmpty ? "\(fileId.uuidString).bin" : input.file.filename

        // 1. Encrypt and persist binary in Object Storage (AES-256-GCM)
        let uploadResult = try await req.encryptedStorage.upload(
            userId: payload.userId,
            category: category,
            fileId: fileId,
            fileName: fileName,
            rawData: rawData,
            contentType: inferredContentType
        )

        // 2. Build metadata JSON
        var metaDict: [String: String] = [:]
        if let notes = input.notes, !notes.isEmpty {
            metaDict["notes"] = notes
        }
        metaDict["originalExtension"] = (fileName as NSString).pathExtension
        let metaJsonData = try? JSONEncoder().encode(metaDict)
        let metaJsonString = metaJsonData.flatMap { String(data: $0, encoding: .utf8) }

        // 3. Persist metadata and relational links into PostgreSQL
        let entity = StoredFileEntity(
            id: fileId,
            userId: payload.userId,
            category: category,
            fileName: fileName,
            contentType: inferredContentType,
            byteSize: uploadResult.byteSize,
            sha256Checksum: uploadResult.sha256,
            storageBucket: uploadResult.bucket,
            storageKey: uploadResult.storageKey,
            encryption: uploadResult.encryption,
            vialId: input.vialId,
            biomarkerId: input.biomarkerId,
            doseLogId: input.doseLogId,
            protocolId: input.protocolId,
            symptomLogId: input.symptomLogId,
            metadataJson: metaJsonString
        )
        try await entity.save(on: req.db)

        let dto = makeDTO(from: entity, req: req)
        return FileUploadResponseDTO(file: dto, message: "File securely encrypted and stored.")
    }

    // MARK: - 2. List Files with Filtering

    public func listFiles(req: Request) async throws -> [StoredFileDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let filter = try req.query.decode(FileListFilterQueryDTO.self)

        var query = StoredFileEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)

        if let cat = filter.category {
            query = query.filter(\.$category == cat)
        }
        if let vialId = filter.vialId {
            query = query.filter(\.$vial.$id == vialId)
        }
        if let markerId = filter.biomarkerId {
            query = query.filter(\.$biomarker.$id == markerId)
        }
        if let doseId = filter.doseLogId {
            query = query.filter(\.$doseLog.$id == doseId)
        }
        if let protoId = filter.protocolId {
            query = query.filter(\.$protocolEntity.$id == protoId)
        }
        if let sympId = filter.symptomLogId {
            query = query.filter(\.$symptomLog.$id == sympId)
        }

        let entities = try await query
            .sort(\.$createdAt, .descending)
            .all()

        return entities.map { makeDTO(from: $0, req: req) }
    }

    // MARK: - 3. Get Single File Metadata

    public func getFileMetadata(req: Request) async throws -> StoredFileDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let fileId = req.parameters.get("fileId", as: UUID.self),
              let entity = try await StoredFileEntity.query(on: req.db)
                .filter(\.$id == fileId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Stored file metadata not found.")
        }

        return makeDTO(from: entity, req: req)
    }

    // MARK: - 4. Download & Decrypt Binary from Object Storage

    public func downloadFile(req: Request) async throws -> Response {
        let payload = try req.auth.require(UserPayload.self)
        guard let fileId = req.parameters.get("fileId", as: UUID.self),
              let entity = try await StoredFileEntity.query(on: req.db)
                .filter(\.$id == fileId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Stored file not found.")
        }

        // Fetch ciphertext from Object Storage and decrypt with AES-256-GCM
        let decryptedData = try await req.encryptedStorage.download(
            storageKey: entity.storageKey,
            bucket: entity.storageBucket,
            encryption: entity.encryptionMetadata
        )

        // Verify SHA-256 integrity against PostgreSQL stored checksum
        let computedChecksum = StorageEncryptionService.computeChecksum(data: decryptedData)
        if computedChecksum != entity.sha256Checksum {
            req.logger.error("Data checksum mismatch for file \(entity.id?.uuidString ?? ""): expected \(entity.sha256Checksum), got \(computedChecksum)")
            throw StorageError.checksumMismatch(expected: entity.sha256Checksum, actual: computedChecksum)
        }

        var headers = HTTPHeaders()
        headers.contentType = HTTPMediaType.parse(entity.contentType) ?? .binary
        headers.contentDisposition = .init(.inline, filename: entity.fileName)
        headers.add(name: "Content-Length", value: "\(decryptedData.count)")
        headers.add(name: "X-SHA256-Checksum", value: entity.sha256Checksum)

        return Response(
            status: .ok,
            headers: headers,
            body: .init(data: decryptedData)
        )
    }

    // MARK: - 5. Relate File to Entities in PostgreSQL

    public func relateFile(req: Request) async throws -> StoredFileDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let fileId = req.parameters.get("fileId", as: UUID.self),
              let entity = try await StoredFileEntity.query(on: req.db)
                .filter(\.$id == fileId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Stored file not found.")
        }

        let relateReq = try req.content.decode(FileRelateRequestDTO.self)
        if let vId = relateReq.vialId { entity.$vial.id = vId }
        if let bId = relateReq.biomarkerId { entity.$biomarker.id = bId }
        if let dId = relateReq.doseLogId { entity.$doseLog.id = dId }
        if let pId = relateReq.protocolId { entity.$protocolEntity.id = pId }
        if let sId = relateReq.symptomLogId { entity.$symptomLog.id = sId }

        if let notes = relateReq.notes {
            var currentMeta: [String: String] = [:]
            if let json = entity.metadataJson, let data = json.data(using: .utf8),
               let parsed = try? JSONDecoder().decode([String: String].self, from: data) {
                currentMeta = parsed
            }
            currentMeta["notes"] = notes
            if let updatedData = try? JSONEncoder().encode(currentMeta) {
                entity.metadataJson = String(data: updatedData, encoding: .utf8)
            }
        }

        try await entity.save(on: req.db)
        return makeDTO(from: entity, req: req)
    }

    // MARK: - 6. Delete File (Ciphertext from Storage + Metadata from PostgreSQL)

    public func deleteFile(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let fileId = req.parameters.get("fileId", as: UUID.self),
              let entity = try await StoredFileEntity.query(on: req.db)
                .filter(\.$id == fileId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Stored file not found.")
        }

        // 1. Delete encrypted object from Object Storage
        try await req.encryptedStorage.delete(
            storageKey: entity.storageKey,
            bucket: entity.storageBucket
        )

        // 2. Delete metadata row from PostgreSQL
        try await entity.delete(on: req.db)

        return .noContent
    }

    // MARK: - Helper

    private func makeDTO(from entity: StoredFileEntity, req: Request) -> StoredFileDTO {
        var metaMap: [String: String]? = nil
        if let json = entity.metadataJson, let data = json.data(using: .utf8),
           let parsed = try? JSONDecoder().decode([String: String].self, from: data) {
            metaMap = parsed
        }

        let downloadPath = "/api/v1/files/\(entity.id?.uuidString ?? "")/download"

        return StoredFileDTO(
            id: entity.id ?? UUID(),
            category: entity.category,
            fileName: entity.fileName,
            contentType: entity.contentType,
            byteSize: entity.byteSize,
            sha256Checksum: entity.sha256Checksum,
            isEncrypted: entity.isEncrypted,
            encryptionAlgorithm: entity.encryptionAlgorithm,
            vialId: entity.$vial.id,
            biomarkerId: entity.$biomarker.id,
            doseLogId: entity.$doseLog.id,
            protocolId: entity.$protocolEntity.id,
            symptomLogId: entity.$symptomLog.id,
            metadata: metaMap,
            createdAt: entity.createdAt,
            downloadUrl: downloadPath
        )
    }
}
