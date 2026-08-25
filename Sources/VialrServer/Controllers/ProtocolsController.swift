import Vapor
import Fluent
import Domain
import CalculationEngine

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
        protocolsGroup.get(":protocolId", "occurrences", use: getProtocolOccurrences)
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

    public func getProtocolOccurrences(req: Request) async throws -> [ExpectedDoseOccurrenceDTO] {
        let payload = try req.auth.require(UserPayload.self)
        guard let protoId = req.parameters.get("protocolId", as: UUID.self),
              let entity = try await ProtocolEntity.query(on: req.db)
                .filter(\.$id == protoId)
                .filter(\.$user.$id == payload.userId)
                .with(\.$compound)
                .first() else {
            throw Abort(.notFound, reason: "Protocol not found.")
        }

        let days = (try? req.query.get(Int.self, at: "days")) ?? 30
        let startDate = (try? req.query.get(Date.self, at: "startDate")) ?? entity.startDate
        let endDate = (try? req.query.get(Date.self, at: "endDate")) ?? Calendar.current.date(byAdding: .day, value: max(1, days), to: startDate) ?? startDate

        // Parse schedule rule
        let scheduleRule: ScheduleRule
        let freq = entity.scheduleFrequency.lowercased()
        if freq.contains("eod") || freq.contains("other") {
            scheduleRule = .everyOtherDay
        } else if freq.contains("5/2") || freq.contains("cycle") {
            scheduleRule = .cycle(daysOn: 5, daysOff: 2)
        } else if freq.contains("weekly") || freq.contains("7") {
            scheduleRule = .everyNDays(7)
        } else if freq.contains("prn") || freq.contains("needed") {
            scheduleRule = .asNeeded
        } else {
            scheduleRule = .everyDay
        }

        let domainCompound = ProtocolCompound(
            id: UUID(),
            protocolId: entity.id,
            compoundId: entity.$compound.id,
            compoundName: entity.compound.name,
            doseAmount: entity.doseAmount,
            doseUnit: DoseUnit(rawValue: entity.doseUnit) ?? .mcg,
            route: .subcutaneous,
            scheduleRule: scheduleRule
        )

        let domainProtocol = ProtocolModel(
            id: entity.id ?? protoId,
            name: entity.name,
            status: ProtocolStatus(rawValue: entity.status) ?? .active,
            startDate: entity.startDate,
            endDate: entity.endDate,
            notes: entity.notes ?? "",
            compounds: [domainCompound]
        )

        let engine = ProtocolSchedulingEngine()
        let occurrences = engine.generateOccurrences(for: domainProtocol, in: startDate...endDate)

        return occurrences.map { occ in
            ExpectedDoseOccurrenceDTO(
                id: occ.id,
                protocolId: occ.protocolId,
                protocolName: occ.protocolName,
                compoundId: occ.compoundId,
                compoundName: occ.compoundName,
                scheduledTimestamp: occ.scheduledTimestamp,
                plannedDoseAmount: occ.plannedDoseAmount,
                doseUnit: occ.doseUnit.rawValue,
                route: occ.route.rawValue,
                status: occ.status.rawValue,
                notes: occ.notes
            )
        }
    }
}
