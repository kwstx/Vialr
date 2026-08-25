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
        protocolsGroup.get(":protocolId", "revisions", use: listProtocolRevisions)
    }

    public func listProtocols(req: Request) async throws -> [ProtocolResponseDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let protocols = try await ProtocolEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .with(\.$compound)
            .sort(\.$startDate, .descending)
            .all()

        return protocols.map { p in
            ProtocolResponseDTO(
                id: p.id ?? UUID(),
                compoundId: p.$compound.id,
                compoundName: p.compound.name,
                name: p.name,
                scheduleFrequency: p.scheduleFrequency,
                doseAmount: p.doseAmount,
                doseUnit: p.doseUnit,
                cycleDurationWeeks: p.cycleDurationWeeks,
                startDate: p.startDate,
                endDate: p.endDate,
                notes: p.notes,
                status: p.status,
                createdAt: p.createdAt,
                updatedAt: p.updatedAt
            )
        }
    }

    public func createProtocol(req: Request) async throws -> ProtocolResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(ProtocolRequestDTO.self)

        // Zero-Trust Validation: Ensure compound exists and belongs to user
        let compound = try await BackendValidationService.validateCompound(
            id: dto.compoundId,
            userId: payload.userId,
            on: req.db
        )

        guard dto.doseAmount > 0 else {
            throw Abort(.badRequest, reason: "Protocol target dose amount must be greater than 0.")
        }
        guard dto.cycleDurationWeeks >= 1 else {
            throw Abort(.badRequest, reason: "Cycle duration must be at least 1 week.")
        }

        let entityId = dto.id ?? UUID()
        let entity = ProtocolEntity(
            id: entityId,
            userId: payload.userId,
            compoundId: dto.compoundId,
            name: dto.name.trimmingCharacters(in: .whitespacesAndNewlines),
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

        // Create initial Revision snapshot
        let revision = ProtocolRevisionEntity(
            userId: payload.userId,
            protocolId: entityId,
            revisionNumber: 1,
            name: entity.name,
            compoundsJson: "[{\"compoundId\":\"\(compound.id?.uuidString ?? "")\",\"targetDoseAmount\":\(dto.doseAmount),\"doseUnit\":\"\(dto.doseUnit)\"}]",
            reasonForChange: "Initial protocol creation",
            effectiveDate: dto.startDate
        )
        try? await revision.save(on: req.db)

        return ProtocolResponseDTO(
            id: entityId,
            compoundId: entity.$compound.id,
            compoundName: compound.name,
            name: entity.name,
            scheduleFrequency: entity.scheduleFrequency,
            doseAmount: entity.doseAmount,
            doseUnit: entity.doseUnit,
            cycleDurationWeeks: entity.cycleDurationWeeks,
            startDate: entity.startDate,
            endDate: entity.endDate,
            notes: entity.notes,
            status: entity.status,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    public func getProtocol(req: Request) async throws -> ProtocolResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let protoId = req.parameters.get("protocolId", as: UUID.self),
              let entity = try await ProtocolEntity.query(on: req.db)
                .filter(\.$id == protoId)
                .filter(\.$user.$id == payload.userId)
                .with(\.$compound)
                .first() else {
            throw Abort(.notFound, reason: "Protocol not found.")
        }

        return ProtocolResponseDTO(
            id: entity.id ?? protoId,
            compoundId: entity.$compound.id,
            compoundName: entity.compound.name,
            name: entity.name,
            scheduleFrequency: entity.scheduleFrequency,
            doseAmount: entity.doseAmount,
            doseUnit: entity.doseUnit,
            cycleDurationWeeks: entity.cycleDurationWeeks,
            startDate: entity.startDate,
            endDate: entity.endDate,
            notes: entity.notes,
            status: entity.status,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    public func updateProtocol(req: Request) async throws -> ProtocolResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let protoId = req.parameters.get("protocolId", as: UUID.self),
              let entity = try await ProtocolEntity.query(on: req.db)
                .filter(\.$id == protoId)
                .filter(\.$user.$id == payload.userId)
                .with(\.$compound)
                .first() else {
            throw Abort(.notFound, reason: "Protocol not found.")
        }

        let update = try req.content.decode(ProtocolRequestDTO.self)
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

        // Snapshot revision
        let count = try await ProtocolRevisionEntity.query(on: req.db)
            .filter(\.$protocolId == protoId)
            .count()

        let revision = ProtocolRevisionEntity(
            userId: payload.userId,
            protocolId: protoId,
            revisionNumber: count + 1,
            name: entity.name,
            compoundsJson: "[{\"compoundId\":\"\(entity.$compound.id)\",\"targetDoseAmount\":\(entity.doseAmount),\"doseUnit\":\"\(entity.doseUnit)\"}]",
            reasonForChange: "Protocol updated via API",
            effectiveDate: Date()
        )
        try? await revision.save(on: req.db)

        return ProtocolResponseDTO(
            id: entity.id ?? protoId,
            compoundId: entity.$compound.id,
            compoundName: entity.compound.name,
            name: entity.name,
            scheduleFrequency: entity.scheduleFrequency,
            doseAmount: entity.doseAmount,
            doseUnit: entity.doseUnit,
            cycleDurationWeeks: entity.cycleDurationWeeks,
            startDate: entity.startDate,
            endDate: entity.endDate,
            notes: entity.notes,
            status: entity.status,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    public func deleteProtocol(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let protoId = req.parameters.get("protocolId", as: UUID.self),
              let entity = try await ProtocolEntity.query(on: req.db)
                .filter(\.$id == protoId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Protocol not found.")
        }

        try await entity.delete(on: req.db)
        return .noContent
    }

    public func listProtocolRevisions(req: Request) async throws -> [ProtocolRevisionDTO] {
        let payload = try req.auth.require(UserPayload.self)
        guard let protoId = req.parameters.get("protocolId", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        let revisions = try await ProtocolRevisionEntity.query(on: req.db)
            .filter(\.$protocolId == protoId)
            .filter(\.$user.$id == payload.userId)
            .sort(\.$revisionNumber, .descending)
            .all()

        return revisions.map { r in
            ProtocolRevisionDTO(
                id: r.id ?? UUID(),
                protocolId: r.protocolId,
                revisionNumber: r.revisionNumber,
                previousRevisionId: r.previousRevisionId,
                name: r.name,
                compoundsJson: r.compoundsJson,
                reasonForChange: r.reasonForChange,
                effectiveDate: r.effectiveDate,
                createdAt: r.createdAt
            )
        }
    }
}
