import Vapor
import Fluent

public struct SuppliesController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let suppliesGroup = routes.grouped("supplies")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        suppliesGroup.get(use: listSupplies)
        suppliesGroup.post(use: createSupply)
        suppliesGroup.get("low-stock", use: listLowStockSupplies)
        suppliesGroup.get(":supplyId", use: getSupply)
        suppliesGroup.put(":supplyId", use: updateSupply)
        suppliesGroup.delete(":supplyId", use: deleteSupply)
        suppliesGroup.post(":supplyId", "adjust", use: adjustQuantity)
    }

    public func listSupplies(req: Request) async throws -> [SupplyItemResponseDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let items = try await SupplyItemEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .sort(\.$name, .ascending)
            .all()

        return items.map { item in
            SupplyItemResponseDTO(
                id: item.id ?? UUID(),
                name: item.name,
                category: item.category,
                quantityRemaining: item.quantityRemaining,
                packageUnit: item.packageUnit,
                reorderThreshold: item.reorderThreshold,
                isLowStock: item.quantityRemaining <= item.reorderThreshold,
                costUsd: item.costUsd,
                notes: item.notes,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt
            )
        }
    }

    public func listLowStockSupplies(req: Request) async throws -> [SupplyItemResponseDTO] {
        let all = try await listSupplies(req: req)
        return all.filter { $0.isLowStock }
    }

    public func createSupply(req: Request) async throws -> SupplyItemResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(SupplyItemRequestDTO.self)

        guard !dto.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Supply item name cannot be empty.")
        }
        guard dto.quantityRemaining >= 0 else {
            throw Abort(.badRequest, reason: "Quantity cannot be negative.")
        }

        let entityId = dto.id ?? UUID()
        let entity = SupplyItemEntity(
            id: entityId,
            userId: payload.userId,
            name: dto.name,
            category: dto.category,
            quantityRemaining: dto.quantityRemaining,
            packageUnit: dto.packageUnit,
            reorderThreshold: dto.reorderThreshold,
            costUsd: dto.costUsd,
            notes: dto.notes
        )
        try await entity.save(on: req.db)

        return SupplyItemResponseDTO(
            id: entityId,
            name: entity.name,
            category: entity.category,
            quantityRemaining: entity.quantityRemaining,
            packageUnit: entity.packageUnit,
            reorderThreshold: entity.reorderThreshold,
            isLowStock: entity.quantityRemaining <= entity.reorderThreshold,
            costUsd: entity.costUsd,
            notes: entity.notes,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    public func getSupply(req: Request) async throws -> SupplyItemResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let supplyId = req.parameters.get("supplyId", as: UUID.self),
              let item = try await SupplyItemEntity.query(on: req.db)
                .filter(\.$id == supplyId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Supply item not found.")
        }

        return SupplyItemResponseDTO(
            id: item.id ?? supplyId,
            name: item.name,
            category: item.category,
            quantityRemaining: item.quantityRemaining,
            packageUnit: item.packageUnit,
            reorderThreshold: item.reorderThreshold,
            isLowStock: item.quantityRemaining <= item.reorderThreshold,
            costUsd: item.costUsd,
            notes: item.notes,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt
        )
    }

    public func updateSupply(req: Request) async throws -> SupplyItemResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let supplyId = req.parameters.get("supplyId", as: UUID.self),
              let item = try await SupplyItemEntity.query(on: req.db)
                .filter(\.$id == supplyId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Supply item not found.")
        }

        let dto = try req.content.decode(SupplyItemRequestDTO.self)
        if !dto.name.isEmpty { item.name = dto.name }
        if !dto.category.isEmpty { item.category = dto.category }
        if dto.quantityRemaining >= 0 { item.quantityRemaining = dto.quantityRemaining }
        if !dto.packageUnit.isEmpty { item.packageUnit = dto.packageUnit }
        if dto.reorderThreshold >= 0 { item.reorderThreshold = dto.reorderThreshold }
        item.costUsd = dto.costUsd
        item.notes = dto.notes

        try await item.save(on: req.db)

        return try await getSupply(req: req)
    }

    public func adjustQuantity(req: Request) async throws -> SupplyItemResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let supplyId = req.parameters.get("supplyId", as: UUID.self),
              let item = try await SupplyItemEntity.query(on: req.db)
                .filter(\.$id == supplyId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Supply item not found.")
        }

        let adjustReq = try req.content.decode(AdjustSupplyQuantityRequestDTO.self)
        let newQty = item.quantityRemaining + adjustReq.delta
        guard newQty >= 0 else {
            throw Abort(.badRequest, reason: "Cannot reduce supply quantity below zero (Current: \(item.quantityRemaining), Delta: \(adjustReq.delta)).")
        }

        item.quantityRemaining = newQty
        try await item.save(on: req.db)

        return try await getSupply(req: req)
    }

    public func deleteSupply(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let supplyId = req.parameters.get("supplyId", as: UUID.self),
              let item = try await SupplyItemEntity.query(on: req.db)
                .filter(\.$id == supplyId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Supply item not found.")
        }

        try await item.delete(on: req.db)
        return .noContent
    }
}
