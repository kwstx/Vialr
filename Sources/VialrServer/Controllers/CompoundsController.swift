import Vapor
import Fluent

public struct CompoundsController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let compoundsGroup = routes.grouped("compounds")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        compoundsGroup.get(use: listCompounds)
        compoundsGroup.post(use: createCompound)
        compoundsGroup.get(":compoundId", use: getCompound)
        compoundsGroup.put(":compoundId", use: updateCompound)
        compoundsGroup.delete(":compoundId", use: deleteCompound)
    }

    public func listCompounds(req: Request) async throws -> [CompoundResponseDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let compounds = try await CompoundEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .sort(\.$name, .ascending)
            .all()

        return compounds.map { c in
            CompoundResponseDTO(
                id: c.id ?? UUID(),
                name: c.name,
                shortCode: c.name.prefix(4).uppercased(),
                category: c.category,
                defaultDose: c.defaultDose,
                defaultUnit: c.defaultUnit,
                halfLifeHours: c.halfLifeHours,
                notes: c.notes,
                isCustom: true,
                createdAt: c.createdAt,
                updatedAt: c.updatedAt
            )
        }
    }

    public func createCompound(req: Request) async throws -> CompoundResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(CompoundRequestDTO.self)

        guard !dto.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Compound name cannot be empty.")
        }
        guard dto.defaultDose > 0 else {
            throw Abort(.badRequest, reason: "Default dose must be greater than 0.")
        }
        guard dto.halfLifeHours > 0 else {
            throw Abort(.badRequest, reason: "Half-life must be greater than 0 hours.")
        }

        let entity = CompoundEntity(
            id: UUID(),
            userId: payload.userId,
            name: dto.name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: dto.category,
            defaultDose: dto.defaultDose,
            defaultUnit: dto.defaultUnit,
            halfLifeHours: dto.halfLifeHours,
            notes: dto.notes
        )
        try await entity.save(on: req.db)

        return CompoundResponseDTO(
            id: entity.id ?? UUID(),
            name: entity.name,
            shortCode: dto.shortCode ?? String(entity.name.prefix(4)).uppercased(),
            category: entity.category,
            customCategoryName: dto.customCategoryName,
            defaultDose: entity.defaultDose,
            defaultUnit: entity.defaultUnit,
            halfLifeHours: entity.halfLifeHours,
            administrationRoute: dto.administrationRoute ?? "Subcutaneous (SubQ)",
            storageCondition: dto.storageCondition ?? "Refrigerated (2–8°C)",
            requiresReconstitution: dto.requiresReconstitution ?? false,
            description: dto.description,
            instructions: dto.instructions,
            notes: entity.notes,
            isCustom: true,
            tags: dto.tags ?? [],
            aliases: dto.aliases ?? [],
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    public func getCompound(req: Request) async throws -> CompoundResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let compoundId = req.parameters.get("compoundId", as: UUID.self),
              let c = try await CompoundEntity.query(on: req.db)
                .filter(\.$id == compoundId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Compound not found.")
        }

        return CompoundResponseDTO(
            id: c.id ?? compoundId,
            name: c.name,
            shortCode: String(c.name.prefix(4)).uppercased(),
            category: c.category,
            defaultDose: c.defaultDose,
            defaultUnit: c.defaultUnit,
            halfLifeHours: c.halfLifeHours,
            notes: c.notes,
            isCustom: true,
            createdAt: c.createdAt,
            updatedAt: c.updatedAt
        )
    }

    public func updateCompound(req: Request) async throws -> CompoundResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let compoundId = req.parameters.get("compoundId", as: UUID.self),
              let c = try await CompoundEntity.query(on: req.db)
                .filter(\.$id == compoundId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Compound not found.")
        }

        let dto = try req.content.decode(CompoundRequestDTO.self)
        if !dto.name.isEmpty { c.name = dto.name }
        if !dto.category.isEmpty { c.category = dto.category }
        if dto.defaultDose > 0 { c.defaultDose = dto.defaultDose }
        if !dto.defaultUnit.isEmpty { c.defaultUnit = dto.defaultUnit }
        if dto.halfLifeHours > 0 { c.halfLifeHours = dto.halfLifeHours }
        c.notes = dto.notes

        try await c.save(on: req.db)

        return CompoundResponseDTO(
            id: c.id ?? compoundId,
            name: c.name,
            shortCode: dto.shortCode ?? String(c.name.prefix(4)).uppercased(),
            category: c.category,
            customCategoryName: dto.customCategoryName,
            defaultDose: c.defaultDose,
            defaultUnit: c.defaultUnit,
            halfLifeHours: c.halfLifeHours,
            notes: c.notes,
            isCustom: true,
            createdAt: c.createdAt,
            updatedAt: c.updatedAt
        )
    }

    public func deleteCompound(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let compoundId = req.parameters.get("compoundId", as: UUID.self),
              let c = try await CompoundEntity.query(on: req.db)
                .filter(\.$id == compoundId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Compound not found.")
        }

        try await c.delete(on: req.db)
        return .noContent
    }
}
