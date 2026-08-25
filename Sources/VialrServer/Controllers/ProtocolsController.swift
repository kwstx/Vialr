import Vapor
import Fluent

public struct ProtocolsController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let protocolsGroup = routes.grouped("protocols")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        protocolsGroup.get(use: listProtocols)
        protocolsGroup.post(use: createProtocol)
        protocolsGroup.get(":protocolId", use: getProtocol)
        protocolsGroup.put(":protocolId", use: updateProtocol)
        protocolsGroup.delete(":protocolId", use: deleteProtocol)

        // Compounds
        let compoundsGroup = routes.grouped("compounds")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())
        compoundsGroup.get(use: listCompounds)
        compoundsGroup.post(use: createCompound)
    }

    // MARK: - Protocols
    public func listProtocols(req: Request) async throws -> [ProtocolDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let protocols = try await ProtocolEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .with(\.$compound)
            .all()

        return protocols.map { p in
            ProtocolDTO(
                id: p.id,
                compoundId: p.$compound.id,
                name: p.name,
                scheduleFrequency: p.scheduleFrequency,
                doseAmount: p.doseAmount,
                doseUnit: p.doseUnit,
                cycleDurationWeeks: p.cycleDurationWeeks,
                startDate: p.startDate,
                endDate: p.endDate,
                notes: p.notes,
                status: p.status
            )
        }
    }

    public func createProtocol(req: Request) async throws -> ProtocolDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(ProtocolDTO.self)

        let entity = ProtocolEntity(
            id: dto.id ?? UUID(),
            userId: payload.userId,
            compoundId: dto.compoundId,
            name: dto.name,
            scheduleFrequency: dto.scheduleFrequency,
            doseAmount: dto.doseAmount,
            doseUnit: dto.doseUnit,
            cycleDurationWeeks: dto.cycleDurationWeeks,
            startDate: dto.startDate,
            endDate: dto.endDate,
            notes: dto.notes,
            status: dto.status ?? "active"
        )
        try await entity.save(on: req.db)

        return ProtocolDTO(
            id: entity.id,
            compoundId: entity.$compound.id,
            name: entity.name,
            scheduleFrequency: entity.scheduleFrequency,
            doseAmount: entity.doseAmount,
            doseUnit: entity.doseUnit,
            cycleDurationWeeks: entity.cycleDurationWeeks,
            startDate: entity.startDate,
            endDate: entity.endDate,
            notes: entity.notes,
            status: entity.status
        )
    }

    public func getProtocol(req: Request) async throws -> ProtocolDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let protoId = req.parameters.get("protocolId", as: UUID.self),
              let entity = try await ProtocolEntity.query(on: req.db)
                .filter(\.$id == protoId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound)
        }

        return ProtocolDTO(
            id: entity.id,
            compoundId: entity.$compound.id,
            name: entity.name,
            scheduleFrequency: entity.scheduleFrequency,
            doseAmount: entity.doseAmount,
            doseUnit: entity.doseUnit,
            cycleDurationWeeks: entity.cycleDurationWeeks,
            startDate: entity.startDate,
            endDate: entity.endDate,
            notes: entity.notes,
            status: entity.status
        )
    }

    public func updateProtocol(req: Request) async throws -> ProtocolDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let protoId = req.parameters.get("protocolId", as: UUID.self),
              let entity = try await ProtocolEntity.query(on: req.db)
                .filter(\.$id == protoId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound)
        }

        let update = try req.content.decode(ProtocolDTO.self)
        entity.name = update.name
        entity.scheduleFrequency = update.scheduleFrequency
        entity.doseAmount = update.doseAmount
        entity.doseUnit = update.doseUnit
        entity.cycleDurationWeeks = update.cycleDurationWeeks
        entity.startDate = update.startDate
        entity.endDate = update.endDate
        entity.notes = update.notes
        if let s = update.status { entity.status = s }

        try await entity.save(on: req.db)

        return ProtocolDTO(
            id: entity.id,
            compoundId: entity.$compound.id,
            name: entity.name,
            scheduleFrequency: entity.scheduleFrequency,
            doseAmount: entity.doseAmount,
            doseUnit: entity.doseUnit,
            cycleDurationWeeks: entity.cycleDurationWeeks,
            startDate: entity.startDate,
            endDate: entity.endDate,
            notes: entity.notes,
            status: entity.status
        )
    }

    public func deleteProtocol(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let protoId = req.parameters.get("protocolId", as: UUID.self),
              let entity = try await ProtocolEntity.query(on: req.db)
                .filter(\.$id == protoId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound)
        }

        try await entity.delete(on: req.db)
        return .noContent
    }

    // MARK: - Compounds
    public func listCompounds(req: Request) async throws -> [CompoundDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let compounds = try await CompoundEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .all()

        return compounds.map { c in
            CompoundDTO(
                id: c.id,
                name: c.name,
                category: c.category,
                defaultDose: c.defaultDose,
                defaultUnit: c.defaultUnit,
                halfLifeHours: c.halfLifeHours,
                notes: c.notes
            )
        }
    }

    public func createCompound(req: Request) async throws -> CompoundDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(CompoundDTO.self)

        let entity = CompoundEntity(
            id: dto.id ?? UUID(),
            userId: payload.userId,
            name: dto.name,
            category: dto.category,
            defaultDose: dto.defaultDose,
            defaultUnit: dto.defaultUnit,
            halfLifeHours: dto.halfLifeHours,
            notes: dto.notes
        )
        try await entity.save(on: req.db)

        return CompoundDTO(
            id: entity.id,
            name: entity.name,
            category: entity.category,
            defaultDose: entity.defaultDose,
            defaultUnit: entity.defaultUnit,
            halfLifeHours: entity.halfLifeHours,
            notes: entity.notes
        )
    }
}
