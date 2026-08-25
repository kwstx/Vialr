import Vapor
import Fluent

public struct BiomarkersController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let biomarkersGroup = routes.grouped("biomarkers")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        biomarkersGroup.get(use: listBiomarkers)
        biomarkersGroup.post(use: logBiomarker)
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

        let entity = BiomarkerEntity(
            id: dto.id ?? UUID(),
            userId: payload.userId,
            name: dto.name,
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
