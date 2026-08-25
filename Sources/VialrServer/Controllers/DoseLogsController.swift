import Vapor
import Fluent

public struct DoseLogsController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let dosesGroup = routes.grouped("doses")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        dosesGroup.get(use: listDoses)
        dosesGroup.post(use: logDose)
        dosesGroup.post("batch", use: batchLogDoses)
        dosesGroup.get(":doseId", use: getDose)
        dosesGroup.put(":doseId", use: updateDose)
        dosesGroup.delete(":doseId", use: deleteDose)
    }

    public func listDoses(req: Request) async throws -> [DoseLogResponseDTO] {
        let payload = try req.auth.require(UserPayload.self)

        let doses = try await DoseLogEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .with(\.$compound)
            .with(\.$protocolModel)
            .with(\.$vial)
            .sort(\.$scheduledDate, .descending)
            .all()

        return doses.map { d in
            DoseLogResponseDTO(
                id: d.id ?? UUID(),
                protocolId: d.$protocolModel.id,
                protocolName: d.protocolModel?.name,
                compoundId: d.$compound.id,
                compoundName: d.compound.name,
                vialId: d.$vial.id,
                scheduledDate: d.scheduledDate,
                administeredDate: d.administeredDate,
                doseAmount: d.doseAmount,
                doseUnit: d.doseUnit,
                injectionSite: d.injectionSite,
                injectionSiteId: d.injectionSiteId,
                administrationRoute: d.administrationRoute,
                status: d.status,
                skippedReason: d.skippedReason,
                notes: d.notes,
                painScore: d.painScore,
                vialRemainingVolumeMl: d.vial?.currentVolumeRemainingMl,
                createdAt: d.createdAt,
                updatedAt: d.updatedAt
            )
        }
    }

    public func logDose(req: Request) async throws -> DoseLogResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(DoseLogRequestDTO.self)

        guard dto.doseAmount > 0 else {
            throw Abort(.badRequest, reason: "Dose amount must be greater than 0 (received: \(dto.doseAmount)).")
        }

        // 1. Zero-Trust Relational Validation: Compound
        let compound = try await BackendValidationService.validateCompound(
            id: dto.compoundId,
            userId: payload.userId,
            on: req.db
        )

        // 2. Zero-Trust Relational Validation: Protocol (if supplied)
        let proto = try await BackendValidationService.validateProtocol(
            id: dto.protocolId,
            userId: payload.userId,
            on: req.db
        )

        // 3. Zero-Trust Relational Validation & Atomic Volume Deduction: Vial (if supplied)
        let (vial, remainingVolume) = try await BackendValidationService.validateVialAndDeductDose(
            vialId: dto.vialId,
            compoundId: dto.compoundId,
            userId: payload.userId,
            doseAmount: dto.doseAmount,
            doseUnit: dto.doseUnit,
            status: dto.status,
            on: req.db
        )

        let doseId = dto.id ?? UUID()
        let administeredDate = dto.administeredDate ?? (dto.status.lowercased() == "taken" ? Date() : nil)

        let entity = DoseLogEntity(
            id: doseId,
            userId: payload.userId,
            protocolId: proto?.id,
            compoundId: compound.id ?? dto.compoundId,
            vialId: vial?.id,
            scheduledDate: dto.scheduledDate,
            administeredDate: administeredDate,
            doseAmount: dto.doseAmount,
            doseUnit: dto.doseUnit,
            injectionSite: dto.injectionSite,
            injectionSiteId: dto.injectionSiteId,
            administrationRoute: dto.administrationRoute ?? "Subcutaneous (SubQ)",
            status: dto.status,
            skippedReason: dto.skippedReason,
            notes: dto.notes,
            painScore: dto.painScore
        )
        try await entity.save(on: req.db)

        // 4. Record injection site rotation event if site was used
        if let siteId = dto.injectionSiteId, dto.status.lowercased() == "taken" {
            let siteEvent = InjectionSiteEventEntity(
                userId: payload.userId,
                doseLogId: doseId,
                siteId: siteId,
                siteName: dto.injectionSite ?? siteId,
                region: siteId.components(separatedBy: "_").first?.capitalized ?? "Abdomen",
                side: siteId.contains("_l") ? "Left" : (siteId.contains("_r") ? "Right" : "Center"),
                administeredAt: administeredDate ?? Date(),
                painScore: dto.painScore,
                notes: dto.notes
            )
            try? await siteEvent.save(on: req.db)
        }

        return DoseLogResponseDTO(
            id: doseId,
            protocolId: proto?.id,
            protocolName: proto?.name,
            compoundId: compound.id ?? dto.compoundId,
            compoundName: compound.name,
            vialId: vial?.id,
            scheduledDate: entity.scheduledDate,
            administeredDate: entity.administeredDate,
            doseAmount: entity.doseAmount,
            doseUnit: entity.doseUnit,
            injectionSite: entity.injectionSite,
            injectionSiteId: entity.injectionSiteId,
            administrationRoute: entity.administrationRoute,
            status: entity.status,
            skippedReason: entity.skippedReason,
            notes: entity.notes,
            painScore: entity.painScore,
            vialRemainingVolumeMl: remainingVolume,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    public func batchLogDoses(req: Request) async throws -> BatchDoseLogResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let batchReq = try req.content.decode(BatchDoseLogRequestDTO.self)

        var results: [DoseLogResponseDTO] = []
        for dto in batchReq.doses {
            let compound = try await BackendValidationService.validateCompound(
                id: dto.compoundId,
                userId: payload.userId,
                on: req.db
            )
            let proto = try await BackendValidationService.validateProtocol(
                id: dto.protocolId,
                userId: payload.userId,
                on: req.db
            )
            let (vial, remainingVolume) = try await BackendValidationService.validateVialAndDeductDose(
                vialId: dto.vialId,
                compoundId: dto.compoundId,
                userId: payload.userId,
                doseAmount: dto.doseAmount,
                doseUnit: dto.doseUnit,
                status: dto.status,
                on: req.db
            )

            let doseId = dto.id ?? UUID()
            let administeredDate = dto.administeredDate ?? (dto.status.lowercased() == "taken" ? Date() : nil)

            let entity = DoseLogEntity(
                id: doseId,
                userId: payload.userId,
                protocolId: proto?.id,
                compoundId: compound.id ?? dto.compoundId,
                vialId: vial?.id,
                scheduledDate: dto.scheduledDate,
                administeredDate: administeredDate,
                doseAmount: dto.doseAmount,
                doseUnit: dto.doseUnit,
                injectionSite: dto.injectionSite,
                injectionSiteId: dto.injectionSiteId,
                administrationRoute: dto.administrationRoute ?? "Subcutaneous (SubQ)",
                status: dto.status,
                skippedReason: dto.skippedReason,
                notes: dto.notes,
                painScore: dto.painScore
            )
            try await entity.save(on: req.db)

            results.append(DoseLogResponseDTO(
                id: doseId,
                protocolId: proto?.id,
                protocolName: proto?.name,
                compoundId: compound.id ?? dto.compoundId,
                compoundName: compound.name,
                vialId: vial?.id,
                scheduledDate: entity.scheduledDate,
                administeredDate: entity.administeredDate,
                doseAmount: entity.doseAmount,
                doseUnit: entity.doseUnit,
                injectionSite: entity.injectionSite,
                injectionSiteId: entity.injectionSiteId,
                administrationRoute: entity.administrationRoute,
                status: entity.status,
                skippedReason: entity.skippedReason,
                notes: entity.notes,
                painScore: entity.painScore,
                vialRemainingVolumeMl: remainingVolume,
                createdAt: entity.createdAt,
                updatedAt: entity.updatedAt
            ))
        }

        return BatchDoseLogResponseDTO(processedCount: results.count, results: results)
    }

    public func getDose(req: Request) async throws -> DoseLogResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let doseId = req.parameters.get("doseId", as: UUID.self),
              let d = try await DoseLogEntity.query(on: req.db)
                .filter(\.$id == doseId)
                .filter(\.$user.$id == payload.userId)
                .with(\.$compound)
                .with(\.$protocolModel)
                .with(\.$vial)
                .first() else {
            throw Abort(.notFound, reason: "Dose log not found.")
        }

        return DoseLogResponseDTO(
            id: d.id ?? doseId,
            protocolId: d.$protocolModel.id,
            protocolName: d.protocolModel?.name,
            compoundId: d.$compound.id,
            compoundName: d.compound.name,
            vialId: d.$vial.id,
            scheduledDate: d.scheduledDate,
            administeredDate: d.administeredDate,
            doseAmount: d.doseAmount,
            doseUnit: d.doseUnit,
            injectionSite: d.injectionSite,
            injectionSiteId: d.injectionSiteId,
            administrationRoute: d.administrationRoute,
            status: d.status,
            skippedReason: d.skippedReason,
            notes: d.notes,
            painScore: d.painScore,
            vialRemainingVolumeMl: d.vial?.currentVolumeRemainingMl,
            createdAt: d.createdAt,
            updatedAt: d.updatedAt
        )
    }

    public func updateDose(req: Request) async throws -> DoseLogResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let doseId = req.parameters.get("doseId", as: UUID.self),
              let entity = try await DoseLogEntity.query(on: req.db)
                .filter(\.$id == doseId)
                .filter(\.$user.$id == payload.userId)
                .with(\.$compound)
                .with(\.$protocolModel)
                .with(\.$vial)
                .first() else {
            throw Abort(.notFound, reason: "Dose log not found.")
        }

        let update = try req.content.decode(DoseLogRequestDTO.self)
        entity.scheduledDate = update.scheduledDate
        entity.administeredDate = update.administeredDate
        entity.doseAmount = update.doseAmount
        entity.doseUnit = update.doseUnit
        entity.injectionSite = update.injectionSite
        entity.injectionSiteId = update.injectionSiteId
        entity.status = update.status
        entity.skippedReason = update.skippedReason
        entity.notes = update.notes
        entity.painScore = update.painScore

        try await entity.save(on: req.db)

        return DoseLogResponseDTO(
            id: entity.id ?? doseId,
            protocolId: entity.$protocolModel.id,
            protocolName: entity.protocolModel?.name,
            compoundId: entity.$compound.id,
            compoundName: entity.compound.name,
            vialId: entity.$vial.id,
            scheduledDate: entity.scheduledDate,
            administeredDate: entity.administeredDate,
            doseAmount: entity.doseAmount,
            doseUnit: entity.doseUnit,
            injectionSite: entity.injectionSite,
            injectionSiteId: entity.injectionSiteId,
            administrationRoute: entity.administrationRoute,
            status: entity.status,
            skippedReason: entity.skippedReason,
            notes: entity.notes,
            painScore: entity.painScore,
            vialRemainingVolumeMl: entity.vial?.currentVolumeRemainingMl,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    public func deleteDose(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let doseId = req.parameters.get("doseId", as: UUID.self),
              let entity = try await DoseLogEntity.query(on: req.db)
                .filter(\.$id == doseId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Dose log not found.")
        }

        try await entity.delete(on: req.db)
        return .noContent
    }
}
