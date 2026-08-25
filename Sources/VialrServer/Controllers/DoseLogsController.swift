import Vapor
import Fluent

public struct DoseLogsController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let dosesGroup = routes.grouped("doses")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        dosesGroup.get(use: listDoses)
        dosesGroup.post(use: logDose)
        dosesGroup.put(":doseId", use: updateDose)
        dosesGroup.delete(":doseId", use: deleteDose)
    }

    public func listDoses(req: Request) async throws -> [DoseLogDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let doses = try await DoseLogEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .sort(\.$scheduledDate, .descending)
            .all()

        return doses.map { d in
            DoseLogDTO(
                id: d.id,
                protocolId: d.$protocolModel.id,
                compoundId: d.$compound.id,
                scheduledDate: d.scheduledDate,
                administeredDate: d.administeredDate,
                doseAmount: d.doseAmount,
                doseUnit: d.doseUnit,
                injectionSite: d.injectionSite,
                status: d.status,
                notes: d.notes,
                painScore: d.painScore
            )
        }
    }

    public func logDose(req: Request) async throws -> DoseLogDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(DoseLogDTO.self)

        let entity = DoseLogEntity(
            id: dto.id ?? UUID(),
            userId: payload.userId,
            protocolId: dto.protocolId,
            compoundId: dto.compoundId,
            scheduledDate: dto.scheduledDate,
            administeredDate: dto.administeredDate ?? (dto.status == "taken" ? Date() : nil),
            doseAmount: dto.doseAmount,
            doseUnit: dto.doseUnit,
            injectionSite: dto.injectionSite,
            status: dto.status,
            notes: dto.notes,
            painScore: dto.painScore
        )
        try await entity.save(on: req.db)

        return DoseLogDTO(
            id: entity.id,
            protocolId: entity.$protocolModel.id,
            compoundId: entity.$compound.id,
            scheduledDate: entity.scheduledDate,
            administeredDate: entity.administeredDate,
            doseAmount: entity.doseAmount,
            doseUnit: entity.doseUnit,
            injectionSite: entity.injectionSite,
            status: entity.status,
            notes: entity.notes,
            painScore: entity.painScore
        )
    }

    public func updateDose(req: Request) async throws -> DoseLogDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let doseId = req.parameters.get("doseId", as: UUID.self),
              let entity = try await DoseLogEntity.query(on: req.db)
                .filter(\.$id == doseId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound)
        }

        let update = try req.content.decode(DoseLogDTO.self)
        entity.scheduledDate = update.scheduledDate
        entity.administeredDate = update.administeredDate
        entity.doseAmount = update.doseAmount
        entity.doseUnit = update.doseUnit
        entity.injectionSite = update.injectionSite
        entity.status = update.status
        entity.notes = update.notes
        entity.painScore = update.painScore

        try await entity.save(on: req.db)

        return DoseLogDTO(
            id: entity.id,
            protocolId: entity.$protocolModel.id,
            compoundId: entity.$compound.id,
            scheduledDate: entity.scheduledDate,
            administeredDate: entity.administeredDate,
            doseAmount: entity.doseAmount,
            doseUnit: entity.doseUnit,
            injectionSite: entity.injectionSite,
            status: entity.status,
            notes: entity.notes,
            painScore: entity.painScore
        )
    }

    public func deleteDose(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let doseId = req.parameters.get("doseId", as: UUID.self),
              let entity = try await DoseLogEntity.query(on: req.db)
                .filter(\.$id == doseId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound)
        }

        try await entity.delete(on: req.db)
        return .noContent
    }
}
