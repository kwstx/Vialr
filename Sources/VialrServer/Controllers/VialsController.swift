import Vapor
import Fluent

public struct VialsController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let vialsGroup = routes.grouped("vials")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        vialsGroup.get(use: listVials)
        vialsGroup.post(use: createVial)
        vialsGroup.get(":vialId", use: getVial)
        vialsGroup.put(":vialId", use: updateVial)
        vialsGroup.delete(":vialId", use: deleteVial)
        vialsGroup.post(":vialId", "deplete", use: depleteVial)
        vialsGroup.post(":vialId", "discard", use: discardVial)
    }

    public func listVials(req: Request) async throws -> [VialResponseDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let vials = try await VialEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .with(\.$compound)
            .sort(\.$createdAt, .descending)
            .all()

        return vials.map { v in
            let isExpired = v.expirationDate.map { Date() > $0 } ?? false
            let remainingPct: Double?
            if let rem = v.currentVolumeRemainingMl, let tot = v.diluentVolumeMl, tot > 0 {
                remainingPct = max(0.0, min(100.0, (rem / tot) * 100.0))
            } else {
                remainingPct = nil
            }

            return VialResponseDTO(
                id: v.id ?? UUID(),
                compoundId: v.$compound.id,
                compoundName: v.compound.name,
                lotNumber: v.lotNumber,
                dryMassMg: v.dryMassMg,
                diluentVolumeMl: v.diluentVolumeMl,
                concentrationMgMl: v.concentrationMgMl,
                concentrationMcgMl: v.concentrationMgMl.map { $0 * 1000.0 },
                currentVolumeRemainingMl: v.currentVolumeRemainingMl,
                remainingPercentage: remainingPct,
                isReconstituted: v.diluentVolumeMl != nil && (v.diluentVolumeMl ?? 0) > 0,
                expirationDate: v.expirationDate,
                costUsd: v.costUsd,
                status: v.status,
                isExpired: isExpired,
                notes: v.notes,
                createdAt: v.createdAt,
                updatedAt: v.updatedAt
            )
        }
    }

    public func createVial(req: Request) async throws -> VialResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(VialRequestDTO.self)

        // Zero-Trust Validation
        let compound = try await BackendValidationService.validateCompound(
            id: dto.compoundId,
            userId: payload.userId,
            on: req.db
        )

        guard dto.dryMassMg > 0 else {
            throw Abort(.badRequest, reason: "Vial dry mass must be greater than 0 mg.")
        }
        if let diluent = dto.diluentVolumeMl {
            guard diluent > 0 else {
                throw Abort(.badRequest, reason: "Diluent volume must be greater than 0 mL.")
            }
        }
        if let cost = dto.costUsd {
            guard cost >= 0 else {
                throw Abort(.badRequest, reason: "Vial cost cannot be negative.")
            }
        }

        // Calculate concentration if diluent volume is supplied
        let concentration: Double?
        let initialRemaining: Double?
        let initialStatus: String

        if let diluent = dto.diluentVolumeMl, diluent > 0 {
            concentration = dto.dryMassMg / diluent
            initialRemaining = dto.currentVolumeRemainingMl ?? diluent
            initialStatus = dto.status ?? "reconstituted"
        } else {
            concentration = nil
            initialRemaining = nil
            initialStatus = dto.status ?? "unopened"
        }

        let entityId = dto.id ?? UUID()
        let entity = VialEntity(
            id: entityId,
            userId: payload.userId,
            compoundId: dto.compoundId,
            lotNumber: dto.lotNumber,
            dryMassMg: dto.dryMassMg,
            diluentVolumeMl: dto.diluentVolumeMl,
            concentrationMgMl: concentration,
            currentVolumeRemainingMl: initialRemaining,
            expirationDate: dto.expirationDate,
            costUsd: dto.costUsd,
            status: initialStatus,
            notes: dto.notes
        )
        try await entity.save(on: req.db)

        return VialResponseDTO(
            id: entityId,
            compoundId: entity.$compound.id,
            compoundName: compound.name,
            lotNumber: entity.lotNumber,
            dryMassMg: entity.dryMassMg,
            diluentVolumeMl: entity.diluentVolumeMl,
            concentrationMgMl: entity.concentrationMgMl,
            concentrationMcgMl: entity.concentrationMgMl.map { $0 * 1000.0 },
            currentVolumeRemainingMl: entity.currentVolumeRemainingMl,
            remainingPercentage: entity.diluentVolumeMl.map { _ in 100.0 },
            isReconstituted: entity.diluentVolumeMl != nil,
            expirationDate: entity.expirationDate,
            costUsd: entity.costUsd,
            status: entity.status,
            isExpired: entity.expirationDate.map { Date() > $0 } ?? false,
            notes: entity.notes,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    public func getVial(req: Request) async throws -> VialResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let vialId = req.parameters.get("vialId", as: UUID.self),
              let v = try await VialEntity.query(on: req.db)
                .filter(\.$id == vialId)
                .filter(\.$user.$id == payload.userId)
                .with(\.$compound)
                .first() else {
            throw Abort(.notFound, reason: "Vial not found.")
        }

        let isExpired = v.expirationDate.map { Date() > $0 } ?? false
        let remainingPct: Double?
        if let rem = v.currentVolumeRemainingMl, let tot = v.diluentVolumeMl, tot > 0 {
            remainingPct = max(0.0, min(100.0, (rem / tot) * 100.0))
        } else {
            remainingPct = nil
        }

        return VialResponseDTO(
            id: v.id ?? vialId,
            compoundId: v.$compound.id,
            compoundName: v.compound.name,
            lotNumber: v.lotNumber,
            dryMassMg: v.dryMassMg,
            diluentVolumeMl: v.diluentVolumeMl,
            concentrationMgMl: v.concentrationMgMl,
            concentrationMcgMl: v.concentrationMgMl.map { $0 * 1000.0 },
            currentVolumeRemainingMl: v.currentVolumeRemainingMl,
            remainingPercentage: remainingPct,
            isReconstituted: v.diluentVolumeMl != nil,
            expirationDate: v.expirationDate,
            costUsd: v.costUsd,
            status: v.status,
            isExpired: isExpired,
            notes: v.notes,
            createdAt: v.createdAt,
            updatedAt: v.updatedAt
        )
    }

    public func updateVial(req: Request) async throws -> VialResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let vialId = req.parameters.get("vialId", as: UUID.self),
              let entity = try await VialEntity.query(on: req.db)
                .filter(\.$id == vialId)
                .filter(\.$user.$id == payload.userId)
                .with(\.$compound)
                .first() else {
            throw Abort(.notFound, reason: "Vial not found.")
        }

        let update = try req.content.decode(VialRequestDTO.self)

        // Zero-Trust validation on remaining volume
        if let newRem = update.currentVolumeRemainingMl {
            if let maxVol = entity.diluentVolumeMl, newRem > (maxVol + 0.001) {
                throw Abort(.badRequest, reason: "Remaining volume (\(newRem) mL) cannot exceed total diluent volume (\(maxVol) mL).")
            }
            entity.currentVolumeRemainingMl = newRem
        }

        entity.lotNumber = update.lotNumber
        if update.dryMassMg > 0 { entity.dryMassMg = update.dryMassMg }
        if let diluent = update.diluentVolumeMl, diluent > 0 {
            entity.diluentVolumeMl = diluent
            entity.concentrationMgMl = entity.dryMassMg / diluent
        }
        entity.expirationDate = update.expirationDate
        entity.costUsd = update.costUsd
        if let s = update.status { entity.status = s }
        entity.notes = update.notes

        try await entity.save(on: req.db)

        return try await getVial(req: req)
    }

    public func depleteVial(req: Request) async throws -> VialResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let vialId = req.parameters.get("vialId", as: UUID.self),
              let entity = try await VialEntity.query(on: req.db)
                .filter(\.$id == vialId)
                .filter(\.$user.$id == payload.userId)
                .with(\.$compound)
                .first() else {
            throw Abort(.notFound, reason: "Vial not found.")
        }

        entity.currentVolumeRemainingMl = 0.0
        entity.status = "depleted"
        try await entity.save(on: req.db)

        return try await getVial(req: req)
    }

    public func discardVial(req: Request) async throws -> VialResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let vialId = req.parameters.get("vialId", as: UUID.self),
              let entity = try await VialEntity.query(on: req.db)
                .filter(\.$id == vialId)
                .filter(\.$user.$id == payload.userId)
                .with(\.$compound)
                .first() else {
            throw Abort(.notFound, reason: "Vial not found.")
        }

        entity.status = "discarded"
        try await entity.save(on: req.db)

        return try await getVial(req: req)
    }

    public func deleteVial(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let vialId = req.parameters.get("vialId", as: UUID.self),
              let entity = try await VialEntity.query(on: req.db)
                .filter(\.$id == vialId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Vial not found.")
        }

        try await entity.delete(on: req.db)
        return .noContent
    }
}
