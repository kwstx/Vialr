import Vapor
import Fluent

public struct BiomarkersController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let biomarkersGroup = routes.grouped("biomarkers")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        biomarkersGroup.get(use: listBiomarkers)
        biomarkersGroup.post(use: logBiomarker)
        biomarkersGroup.get(":name", "history", use: getBiomarkerHistory)
        biomarkersGroup.delete(":biomarkerId", use: deleteBiomarker)
    }

    public func listBiomarkers(req: Request) async throws -> [BiomarkerDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let biomarkers = try await BiomarkerEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .sort(\.$testDate, .descending)
            .all()

        return biomarkers.map { b in
            BiomarkerDTO(
                id: b.id,
                name: b.name,
                value: b.value,
                unit: b.unit,
                referenceRangeMin: b.referenceRangeMin,
                referenceRangeMax: b.referenceRangeMax,
                testDate: b.testDate,
                labName: b.labName,
                notes: b.notes
            )
        }
    }

    public func logBiomarker(req: Request) async throws -> BiomarkerDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(BiomarkerDTO.self)

        guard dto.value.isFinite && !dto.value.isNaN else {
            throw Abort(.badRequest, reason: "Biomarker value must be a valid number.")
        }
        guard !dto.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Biomarker name cannot be empty.")
        }

        let entity = BiomarkerEntity(
            id: dto.id ?? UUID(),
            userId: payload.userId,
            name: dto.name.trimmingCharacters(in: .whitespacesAndNewlines),
            value: dto.value,
            unit: dto.unit,
            referenceRangeMin: dto.referenceRangeMin,
            referenceRangeMax: dto.referenceRangeMax,
            testDate: dto.testDate,
            labName: dto.labName,
            notes: dto.notes
        )
        try await entity.save(on: req.db)

        return BiomarkerDTO(
            id: entity.id,
            name: entity.name,
            value: entity.value,
            unit: entity.unit,
            referenceRangeMin: entity.referenceRangeMin,
            referenceRangeMax: entity.referenceRangeMax,
            testDate: entity.testDate,
            labName: entity.labName,
            notes: entity.notes
        )
    }

    public func getBiomarkerHistory(req: Request) async throws -> BiomarkerHistoryTrendDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let rawName = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Biomarker name parameter is required.")
        }
        let biomarkerName = rawName.removingPercentEncoding ?? rawName

        let markers = try await BiomarkerEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .filter(\.$name == biomarkerName)
            .sort(\.$testDate, .ascending)
            .all()

        let dtos = markers.map { b in
            BiomarkerDTO(
                id: b.id,
                name: b.name,
                value: b.value,
                unit: b.unit,
                referenceRangeMin: b.referenceRangeMin,
                referenceRangeMax: b.referenceRangeMax,
                testDate: b.testDate,
                labName: b.labName,
                notes: b.notes
            )
        }

        return BiomarkerHistoryTrendDTO(
            biomarkerName: biomarkerName,
            unit: markers.first?.unit ?? "",
            referenceRangeMin: markers.first?.referenceRangeMin,
            referenceRangeMax: markers.first?.referenceRangeMax,
            dataPoints: dtos
        )
    }

    public func deleteBiomarker(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let biomarkerId = req.parameters.get("biomarkerId", as: UUID.self),
              let entity = try await BiomarkerEntity.query(on: req.db)
                .filter(\.$id == biomarkerId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound)
        }

        try await entity.delete(on: req.db)
        return .noContent
    }
}
