import Fluent
import Vapor

public final class SyncConflictEntity: Model, Content, @unchecked Sendable {
    public static let schema = "sync_conflicts"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Field(key: "entity_type")
    public var entityType: String

    @Field(key: "entity_id")
    public var entityId: UUID

    @Field(key: "client_version")
    public var clientVersion: Int

    @Field(key: "server_version")
    public var serverVersion: Int

    @Field(key: "resolution_strategy")
    public var resolutionStrategy: String

    @Field(key: "client_payload_json")
    public var clientPayloadJson: String?

    @Field(key: "server_payload_json")
    public var serverPayloadJson: String?

    @Field(key: "preserved_secondary_id")
    public var preservedSecondaryId: UUID?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userId: UUID,
        entityType: String,
        entityId: UUID,
        clientVersion: Int,
        serverVersion: Int,
        resolutionStrategy: String,
        clientPayloadJson: String? = nil,
        serverPayloadJson: String? = nil,
        preservedSecondaryId: UUID? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.entityType = entityType
        self.entityId = entityId
        self.clientVersion = clientVersion
        self.serverVersion = serverVersion
        self.resolutionStrategy = resolutionStrategy
        self.clientPayloadJson = clientPayloadJson
        self.serverPayloadJson = serverPayloadJson
        self.preservedSecondaryId = preservedSecondaryId
    }
}
