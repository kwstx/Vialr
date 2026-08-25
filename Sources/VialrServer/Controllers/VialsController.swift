import Vapor
import Fluent

public struct VialsController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let vialsGroup = routes.grouped("vials")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        vialsGroup.get(use: listVials)
        vialsGroup.post(use: createVial)
        vialsGroup.put(":vialId", use: updateVial)
        vialsGroup.delete(":vialId", use: deleteVial)
    }

    public func listVials(req: Request) async throws -> [VialDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let vials = try await VialEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .with(\.$compound)
            .all()

        return vials.map { v in
            VialDTO(
                id: v.id,
                compoundId: v.$compound.id,
                lotNumber: v.lotNumber,
                dryMassMg: v.dryMassMg,
                diluentVolumeMl: v.diluentVolumeMl,
                concentrationMgMl: v.concentrationMgMl,
                currentVolumeRemainingMl: v.currentVolumeRemainingMl,
                expirationDate: v.expirationDate,
                costUsd: v.costUsd,
                status: v.status,
                notes: v.notes
            )
        }
    }

    public func createVial(req: Request) async throws -> VialDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(VialDTO.self)

        // Calculate concentration if diluent volume is supplied
        let concentration: Double?
        if let diluent = dto.diluentVolumeMl, diluent > 0 {
            concentration = dto.dryMassMg / diluent
        } else {
            concentration = dto.concentrationMgMl
        }

        let entity = VialEntity(
            id: dto.id ?? UUID(),
            userId: payload.userId,
            compoundId: dto.compoundId,
            lotNumber: dto.lotNumber,
            dryMassMg: dto.dryMassMg,
            diluentVolumeMl: dto.diluentVolumeMl,
            concentrationMgMl: concentration,
            currentVolumeRemainingMl: dto.currentVolumeRemainingMl ?? dto.diluentVolumeMl,
            expirationDate: dto.expirationDate,
            costUsd: dto.costUsd,
            status: dto.status ?? (dto.diluentVolumeMl != nil ? "reconstituted" : "unreconstituted"),
            notes: dto.notes
        )
        try await entity.save(on: req.db)

        return VialDTO(
            id: entity.id,
            compoundId: entity.$compound.id,
            lotNumber: entity.lotNumber,
            dryMassMg: entity.dryMassMg,
            diluentVolumeMl: entity.diluentVolumeMl,
            concentrationMgMl: entity.concentrationMgMl,
            currentVolumeRemainingMl: entity.currentVolumeRemainingMl,
            expirationDate: entity.expirationDate,
            costUsd: entity.costUsd,
            status: entity.status,
            notes: entity.notes
        )
    }

    public func updateVial(req: Request) async throws -> VialDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let vialId = req.parameters.get("vialId", as: UUID.self),
              let entity = try await VialEntity.query(on: req.db)
                .filter(\.$id == vialId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound)
        }

        let update = try req.content.decode(VialDTO.self)
        entity.lotNumber = update.lotNumber
        entity.dryMassMg = update.dryMassMg
        entity.diluentVolumeMl = update.diluentVolumeMl
        entity.concentrationMgMl = update.concentrationMgMl
        entity.currentVolumeRemainingMl = update.currentVolumeRemainingMl
        entity.expirationDate = update.expirationDate
        entity.costUsd = update.costUsd
        if let s = update.status { entity.status = s }
        entity.notes = update.notes

        try await entity.save(on: req.db)

        return VialDTO(
            id: entity.id,
            compoundId: entity.$compound.id,
            lotNumber: entity.lotNumber,
            dryMassMg: entity.dryMassMg,
            diluentVolumeMl: entity.diluentVolumeMl,
            concentrationMgMl: entity.concentrationMgMl,
            currentVolumeRemainingMl: entity.currentVolumeRemainingMl,
            expirationDate: entity.expirationDate,
            costUsd: entity.costUsd,
            status: entity.status,
            notes: entity.notes
        )
    }

    public func deleteVial(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let vialId = req.parameters.get("vialId", as: UUID.self),
              let entity = try await VialEntity.query(on: req.db)
                .filter(\.$id == vialId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound)
        }

        try await entity.delete(on: req.db)
        return .noContent
    }
}
