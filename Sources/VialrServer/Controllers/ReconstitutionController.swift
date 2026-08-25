import Vapor
import Fluent

public struct ReconstitutionController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let reconGroup = routes.grouped("reconstitution")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        reconGroup.get(use: listRecords)
        reconGroup.post(use: createRecord)
        reconGroup.get(":recordId", use: getRecord)
        reconGroup.post(":recordId", "revise", use: createSupersedingRevision)
    }

    public func listRecords(req: Request) async throws -> [ReconstitutionResponseDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let records = try await ReconstitutionRecordEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .with(\.$compound)
            .sort(\.$reconstitutedAt, .descending)
            .all()

        return records.map { r in
            ReconstitutionResponseDTO(
                id: r.id ?? UUID(),
                vialId: r.$vial.id,
                compoundId: r.$compound.id,
                compoundName: r.compound.name,
                dryMassMg: r.dryMassMg,
                diluentVolumeMl: r.diluentVolumeMl,
                diluentType: r.diluentType,
                diluentLotNumber: r.diluentLotNumber,
                diluentBrand: r.diluentBrand,
                reconstitutedAt: r.reconstitutedAt,
                concentrationMgMl: r.concentrationMgMl,
                concentrationMcgMl: r.concentrationMcgMl,
                totalLiquidVolumeMl: r.totalLiquidVolumeMl,
                storageCondition: r.storageCondition,
                expectedShelfLifeDays: r.expectedShelfLifeDays,
                expirationDate: r.expirationDate,
                isConfirmed: r.isConfirmed,
                version: r.version,
                isCurrentActiveRevision: r.isCurrentActiveRevision,
                previousRecordId: r.previousRecordId,
                supersededByRecordId: r.supersededByRecordId,
                revisionReason: r.revisionReason,
                solutionClarity: r.solutionClarity,
                notes: r.notes,
                createdAt: r.createdAt
            )
        }
    }

    public func createRecord(req: Request) async throws -> ReconstitutionResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(ReconstitutionRequestDTO.self)

        // 1. Zero-Trust Validation: Vial & Compound ownership
        guard let vial = try await VialEntity.query(on: req.db)
            .filter(\.$id == dto.vialId)
            .filter(\.$user.$id == payload.userId)
            .with(\.$compound)
            .first() else {
            throw Abort(.badRequest, reason: "Referenced vial \(dto.vialId.uuidString) does not exist or does not belong to the user.")
        }

        // 2. Mathematical Sanity Check
        let (concMgMl, concMcgMl) = try BackendValidationService.validateReconstitutionParams(
            dryMassMg: dto.dryMassMg,
            diluentVolumeMl: dto.diluentVolumeMl
        )

        let reconDate = dto.reconstitutedAt ?? Date()
        let shelfLife = dto.expectedShelfLifeDays ?? 30
        let expDate = Calendar.current.date(byAdding: .day, value: shelfLife, to: reconDate)

        let recordId = dto.id ?? UUID()
        let record = ReconstitutionRecordEntity(
            id: recordId,
            userId: payload.userId,
            vialId: dto.vialId,
            compoundId: vial.$compound.id,
            dryMassMg: dto.dryMassMg,
            diluentVolumeMl: dto.diluentVolumeMl,
            diluentType: dto.diluentType ?? "Bacteriostatic Water",
            diluentLotNumber: dto.diluentLotNumber,
            diluentBrand: dto.diluentBrand,
            reconstitutedAt: reconDate,
            concentrationMgMl: concMgMl,
            concentrationMcgMl: concMcgMl,
            totalLiquidVolumeMl: dto.diluentVolumeMl,
            storageCondition: dto.storageCondition ?? "Refrigerated (2–8°C)",
            expectedShelfLifeDays: shelfLife,
            expirationDate: expDate,
            isConfirmed: true,
            version: 1,
            isCurrentActiveRevision: true,
            previousRecordId: nil,
            supersededByRecordId: nil,
            revisionReason: nil,
            solutionClarity: dto.solutionClarity ?? "Clear & Colorless (Optimal)",
            notes: dto.notes
        )
        try await record.save(on: req.db)

        // 3. Atomically update the physical Vial state in database
        vial.dryMassMg = dto.dryMassMg
        vial.diluentVolumeMl = dto.diluentVolumeMl
        vial.concentrationMgMl = concMgMl
        vial.currentVolumeRemainingMl = dto.diluentVolumeMl
        vial.status = "reconstituted"
        vial.expirationDate = expDate
        try await vial.save(on: req.db)

        return ReconstitutionResponseDTO(
            id: recordId,
            vialId: dto.vialId,
            compoundId: vial.$compound.id,
            compoundName: vial.compound.name,
            dryMassMg: dto.dryMassMg,
            diluentVolumeMl: dto.diluentVolumeMl,
            diluentType: record.diluentType,
            diluentLotNumber: record.diluentLotNumber,
            diluentBrand: record.diluentBrand,
            reconstitutedAt: record.reconstitutedAt,
            concentrationMgMl: concMgMl,
            concentrationMcgMl: concMcgMl,
            totalLiquidVolumeMl: dto.diluentVolumeMl,
            storageCondition: record.storageCondition,
            expectedShelfLifeDays: shelfLife,
            expirationDate: expDate,
            isConfirmed: true,
            version: 1,
            isCurrentActiveRevision: true,
            previousRecordId: nil,
            supersededByRecordId: nil,
            revisionReason: nil,
            solutionClarity: record.solutionClarity,
            notes: record.notes,
            createdAt: record.createdAt
        )
    }

    public func getRecord(req: Request) async throws -> ReconstitutionResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let recordId = req.parameters.get("recordId", as: UUID.self),
              let r = try await ReconstitutionRecordEntity.query(on: req.db)
                .filter(\.$id == recordId)
                .filter(\.$user.$id == payload.userId)
                .with(\.$compound)
                .first() else {
            throw Abort(.notFound, reason: "Reconstitution record not found.")
        }

        return ReconstitutionResponseDTO(
            id: r.id ?? recordId,
            vialId: r.$vial.id,
            compoundId: r.$compound.id,
            compoundName: r.compound.name,
            dryMassMg: r.dryMassMg,
            diluentVolumeMl: r.diluentVolumeMl,
            diluentType: r.diluentType,
            diluentLotNumber: r.diluentLotNumber,
            diluentBrand: r.diluentBrand,
            reconstitutedAt: r.reconstitutedAt,
            concentrationMgMl: r.concentrationMgMl,
            concentrationMcgMl: r.concentrationMcgMl,
            totalLiquidVolumeMl: r.totalLiquidVolumeMl,
            storageCondition: r.storageCondition,
            expectedShelfLifeDays: r.expectedShelfLifeDays,
            expirationDate: r.expirationDate,
            isConfirmed: r.isConfirmed,
            version: r.version,
            isCurrentActiveRevision: r.isCurrentActiveRevision,
            previousRecordId: r.previousRecordId,
            supersededByRecordId: r.supersededByRecordId,
            revisionReason: r.revisionReason,
            solutionClarity: r.solutionClarity,
            notes: r.notes,
            createdAt: r.createdAt
        )
    }

    public func createSupersedingRevision(req: Request) async throws -> ReconstitutionResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let recordId = req.parameters.get("recordId", as: UUID.self),
              let currentRecord = try await ReconstitutionRecordEntity.query(on: req.db)
                .filter(\.$id == recordId)
                .filter(\.$user.$id == payload.userId)
                .with(\.$compound)
                .first() else {
            throw Abort(.notFound, reason: "Reconstitution record not found.")
        }

        let revisionReq = try req.content.decode(ReconstitutionRevisionRequestDTO.self)
        let dryMass = revisionReq.newDryMassMg ?? currentRecord.dryMassMg
        let (concMgMl, concMcgMl) = try BackendValidationService.validateReconstitutionParams(
            dryMassMg: dryMass,
            diluentVolumeMl: revisionReq.newDiluentVolumeMl
        )

        let newRecordId = UUID()
        let now = Date()

        // 1. Mark current record as superseded
        currentRecord.isCurrentActiveRevision = false
        currentRecord.supersededByRecordId = newRecordId
        try await currentRecord.save(on: req.db)

        // 2. Create the superseding child record
        let newRecord = ReconstitutionRecordEntity(
            id: newRecordId,
            userId: payload.userId,
            vialId: currentRecord.$vial.id,
            compoundId: currentRecord.$compound.id,
            dryMassMg: dryMass,
            diluentVolumeMl: revisionReq.newDiluentVolumeMl,
            diluentType: revisionReq.diluentType ?? currentRecord.diluentType,
            diluentLotNumber: currentRecord.diluentLotNumber,
            diluentBrand: currentRecord.diluentBrand,
            reconstitutedAt: currentRecord.reconstitutedAt,
            concentrationMgMl: concMgMl,
            concentrationMcgMl: concMcgMl,
            totalLiquidVolumeMl: revisionReq.newDiluentVolumeMl,
            storageCondition: currentRecord.storageCondition,
            expectedShelfLifeDays: currentRecord.expectedShelfLifeDays,
            expirationDate: currentRecord.expirationDate,
            isConfirmed: true,
            version: currentRecord.version + 1,
            isCurrentActiveRevision: true,
            previousRecordId: currentRecord.id,
            supersededByRecordId: nil,
            revisionReason: revisionReq.revisionReason,
            solutionClarity: currentRecord.solutionClarity,
            notes: "Revision \(currentRecord.version + 1): \(revisionReq.revisionReason)"
        )
        try await newRecord.save(on: req.db)

        // 3. Update the vial's current active parameters
        if let vial = try await VialEntity.find(currentRecord.$vial.id, on: req.db) {
            vial.dryMassMg = dryMass
            vial.diluentVolumeMl = revisionReq.newDiluentVolumeMl
            vial.concentrationMgMl = concMgMl
            vial.currentVolumeRemainingMl = revisionReq.newDiluentVolumeMl
            try await vial.save(on: req.db)
        }

        return ReconstitutionResponseDTO(
            id: newRecordId,
            vialId: currentRecord.$vial.id,
            compoundId: currentRecord.$compound.id,
            compoundName: currentRecord.compound.name,
            dryMassMg: dryMass,
            diluentVolumeMl: revisionReq.newDiluentVolumeMl,
            diluentType: newRecord.diluentType,
            diluentLotNumber: newRecord.diluentLotNumber,
            diluentBrand: newRecord.diluentBrand,
            reconstitutedAt: newRecord.reconstitutedAt,
            concentrationMgMl: concMgMl,
            concentrationMcgMl: concMcgMl,
            totalLiquidVolumeMl: revisionReq.newDiluentVolumeMl,
            storageCondition: newRecord.storageCondition,
            expectedShelfLifeDays: newRecord.expectedShelfLifeDays,
            expirationDate: newRecord.expirationDate,
            isConfirmed: true,
            version: newRecord.version,
            isCurrentActiveRevision: true,
            previousRecordId: currentRecord.id,
            supersededByRecordId: nil,
            revisionReason: revisionReq.revisionReason,
            solutionClarity: newRecord.solutionClarity,
            notes: newRecord.notes,
            createdAt: newRecord.createdAt
        )
    }
}
