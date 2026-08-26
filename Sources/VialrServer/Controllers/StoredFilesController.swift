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

        // 1. Direct Object Storage Authorization & Lifecycle (Scalable Architecture)
        filesGroup.post("upload-authorization", use: requestUploadAuthorization)
        filesGroup.post("confirm-upload", use: confirmUpload)
        filesGroup.post(":fileId", "process", use: processDocumentFile)

        // 2. Standard Multipart Fallback & Metadata Queries
        filesGroup.post("upload", use: uploadFile)
        filesGroup.get(use: listFiles)
        filesGroup.get(":fileId", use: getFileMetadata)
        filesGroup.get(":fileId", "download", use: downloadFile)
        filesGroup.patch(":fileId", "relate", use: relateFile)
        filesGroup.delete(":fileId", use: deleteFile)

        // 3. Direct Storage Streaming Endpoint (for dev/local filesystem storage backend)
        routes.grouped("files", "direct")
            .on(.PUT, ":bucket", "**", body: .collect(max: "55mb"), use: handleDirectStorageUpload)
        routes.grouped("files", "direct")
            .on(.POST, ":bucket", "**", body: .collect(max: "55mb"), use: handleDirectStorageUpload)
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

    // MARK: - 7. Direct Object Storage Upload Authorization (Scalable Architecture)

    public func requestUploadAuthorization(req: Request) async throws -> UploadAuthorizationResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let input = try req.content.decode(UploadAuthorizationRequestDTO.self)

        guard let category = StoredFileCategory(rawValue: input.category) else {
            throw Abort(.badRequest, reason: "Invalid category. Allowed: \(StoredFileCategory.allCases.map { $0.rawValue }.joined(separator: ", "))")
        }

        // Validate related entity ownership if specified
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

        // Generate signed upload authorization directly to object storage
        let fileId = UUID()
        let authResult = try await req.encryptedStorage.authorizeDirectUpload(
            userId: payload.userId,
            category: category,
            fileId: fileId,
            fileName: input.fileName,
            byteSize: input.byteSize,
            contentType: input.contentType,
            expiresInSeconds: 900
        )

        return UploadAuthorizationResponseDTO(
            fileId: authResult.fileId,
            storageKey: authResult.storageKey,
            storageBucket: authResult.bucket,
            uploadUrl: authResult.uploadUrl.absoluteString,
            httpMethod: "PUT",
            headers: authResult.headers,
            expiresAt: authResult.expiresAt,
            maxAllowedSizeBytes: category.maxAllowedSizeBytes,
            encryptionAlgorithm: "AES-256-GCM"
        )
    }

    // MARK: - 8. Confirm Direct Upload & Record Object Identifier in PostgreSQL

    public func confirmUpload(req: Request) async throws -> UploadConfirmationResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let input = try req.content.decode(UploadConfirmationRequestDTO.self)

        guard let category = StoredFileCategory(rawValue: input.category) else {
            throw Abort(.badRequest, reason: "Invalid category. Allowed: \(StoredFileCategory.allCases.map { $0.rawValue }.joined(separator: ", "))")
        }

        let targetBucket = input.storageBucket ?? req.encryptedStorage.bucket

        // 1. Verify object exists in Object Storage vault
        let exists = try await req.encryptedStorage.objectExists(storageKey: input.storageKey, bucket: targetBucket)
        guard exists else {
            throw Abort(.badRequest, reason: "Object '\(input.storageKey)' not found in storage bucket '\(targetBucket)'. Verify direct upload succeeded before confirmation.")
        }

        // 2. Construct encryption metadata
        let encryptionMeta = StorageEncryptionMetadata(
            algorithm: "AES-256-GCM",
            keyId: input.encryptionKeyId ?? "vialr-vault-primary",
            initializationVector: input.encryptionIV ?? "",
            authenticationTag: input.encryptionTag ?? "",
            isEncrypted: true
        )

        // 3. Build metadata JSON
        var metaDict = input.metadata ?? [:]
        metaDict["originalExtension"] = (input.fileName as NSString).pathExtension
        metaDict["uploadedVia"] = "direct_object_storage"
        let metaJsonData = try? JSONEncoder().encode(metaDict)
        let metaJsonString = metaJsonData.flatMap { String(data: $0, encoding: .utf8) }

        // 4. Record object identifier and metadata in PostgreSQL (zero BLOB columns in DB!)
        let entity = StoredFileEntity(
            id: input.fileId,
            userId: payload.userId,
            category: category,
            fileName: input.fileName,
            contentType: input.contentType,
            byteSize: input.byteSize,
            sha256Checksum: input.sha256Checksum,
            storageBucket: targetBucket,
            storageKey: input.storageKey,
            encryption: encryptionMeta,
            vialId: input.vialId,
            biomarkerId: input.biomarkerId,
            doseLogId: input.doseLogId,
            protocolId: input.protocolId,
            symptomLogId: input.symptomLogId,
            metadataJson: metaJsonString
        )
        try await entity.save(on: req.db)

        // 5. Trigger non-blocking background worker processing if requested or if document is a lab PDF/image
        var processingJobDTO: DocumentProcessingJobDTO? = nil
        let shouldProcess = (input.triggerProcessing ?? true) && (category == .labPdf || category == .userDocument || category == .vialPhoto || category == .progressPhoto)
        if shouldProcess {
            let jobType: BackgroundJobType = (category == .labPdf || category == .userDocument) ? .pdfProcessing : .imageProcessing
            let jobPayload = PdfProcessingJobPayload(
                fileId: input.fileId,
                fileName: input.fileName,
                autoCreatePanel: true
            )
            let payloadData = try? JSONEncoder().encode(jobPayload)
            let payloadString = payloadData.flatMap { String(data: $0, encoding: .utf8) }

            let bgJob = try await req.application.backgroundJobQueue.enqueueJob(
                userId: payload.userId,
                type: jobType,
                payloadJson: payloadString
            )

            processingJobDTO = DocumentProcessingJobDTO(
                jobId: bgJob.id ?? UUID(),
                fileId: input.fileId,
                status: bgJob.status,
                extractedCandidatesCount: 0,
                resultSummary: "Background \(jobType.displayName) job queued. Worker will process document asynchronously without blocking.",
                createdAt: bgJob.createdAt ?? Date()
            )
        }

        let dto = makeDTO(from: entity, req: req)
        return UploadConfirmationResponseDTO(
            file: dto,
            processingJob: processingJobDTO,
            message: "Object identifier registered in database. Background processing job created."
        )
    }

    // MARK: - 9. Trigger Backend Worker Document Processing (Non-blocking)

    public func processDocumentFile(req: Request) async throws -> Response {
        let payload = try req.auth.require(UserPayload.self)
        guard let fileId = req.parameters.get("fileId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Missing fileId parameter.")
        }

        guard let fileEntity = try await StoredFileEntity.query(on: req.db)
            .filter(\.$id == fileId)
            .filter(\.$user.$id == payload.userId)
            .first() else {
            throw Abort(.notFound, reason: "Stored file not found.")
        }

        let jobType: BackgroundJobType = (fileEntity.category == .vialPhoto || fileEntity.category == .progressPhoto) ? .imageProcessing : .pdfProcessing
        let jobPayload = PdfProcessingJobPayload(
            fileId: fileId,
            fileName: fileEntity.fileName,
            autoCreatePanel: true
        )
        let payloadData = try? JSONEncoder().encode(jobPayload)
        let payloadString = payloadData.flatMap { String(data: $0, encoding: .utf8) }

        let bgJob = try await req.application.backgroundJobQueue.enqueueJob(
            userId: payload.userId,
            type: jobType,
            payloadJson: payloadString
        )

        let dto = BackgroundJobDTO(from: bgJob)
        let response = Response(status: .accepted)
        try response.content.encode(dto)
        return response
    }

    // MARK: - 10. Direct Storage Streaming Endpoint (Local / Dev FileSystem Backend)

    public func handleDirectStorageUpload(req: Request) async throws -> Response {
        guard let bucket = req.parameters.get("bucket") else {
            throw Abort(.badRequest, reason: "Missing bucket parameter")
        }
        let catchall = req.parameters.getCatchall()
        let key = catchall.joined(separator: "/")
        guard !key.isEmpty else {
            throw Abort(.badRequest, reason: "Missing object storage key")
        }

        guard let bodyBuffer = req.body.data else {
            throw Abort(.badRequest, reason: "Missing file stream body")
        }

        let contentType = req.headers.first(name: .contentType) ?? "application/octet-stream"
        let data = Data(buffer: bodyBuffer)

        // Write directly to Object Storage
        try await req.encryptedStorage.storageBackend.putObject(
            key: key,
            bucket: bucket,
            data: data,
            contentType: contentType
        )

        return Response(status: .ok, body: .init(string: "{\"status\":\"uploaded\",\"key\":\"\(key)\"}"))
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
