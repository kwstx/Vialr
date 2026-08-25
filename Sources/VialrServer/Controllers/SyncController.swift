import Vapor
import Fluent

public struct SyncController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let syncGroup = routes.grouped("sync")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        syncGroup.post("push", use: pushChanges)
        syncGroup.get("pull", use: pullChanges)
    }

    public func pushChanges(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        let pushReq = try req.content.decode(SyncPushRequestDTO.self)

        for change in pushReq.changes {
            let entity = SyncChangeEntity(
                id: change.id,
                userId: payload.userId,
                entityType: change.entityType,
                entityId: change.entityId,
                operation: change.operation,
                payloadJson: change.payloadJson,
                timestamp: change.timestamp
            )
            try await entity.save(on: req.db)
        }

        return .ok
    }

    public func pullChanges(req: Request) async throws -> SyncPullResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        
        let changes = try await SyncChangeEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .sort(\.$timestamp, .ascending)
            .all()

        let dtoArray = changes.compactMap { c -> SyncDeltaItemDTO? in
            guard let id = c.id else { return nil }
            return SyncDeltaItemDTO(
                id: id,
                entityType: c.entityType,
                entityId: c.entityId,
                operation: c.operation,
                payloadJson: c.payloadJson,
                timestamp: c.timestamp
            )
        }

        return SyncPullResponseDTO(
            serverTimestamp: Date(),
            changes: dtoArray
        )
    }
}
