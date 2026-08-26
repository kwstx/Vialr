import Fluent
import Vapor

/// Database entity persisting immutable security audit log entries for forensic traceability.
public final class AuditLogEntity: Model, Content, @unchecked Sendable {
    public static let schema = "audit_logs"

    @ID(key: .id)
    public var id: UUID?

    @OptionalParent(key: "actor_id")
    public var actor: UserEntity?

    @Field(key: "actor_email")
    public var actorEmail: String?

    @Field(key: "actor_role")
    public var actorRole: String

    @Field(key: "action")
    public var action: String

    @Field(key: "resource_type")
    public var resourceType: String

    @Field(key: "resource_id")
    public var resourceId: String?

    @Field(key: "ip_address")
    public var ipAddress: String?

    @Field(key: "user_agent")
    public var userAgent: String?

    @Field(key: "status")
    public var status: String

    @Field(key: "failure_reason")
    public var failureReason: String?

    @Field(key: "metadata_json")
    public var metadataJson: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        actorId: UUID? = nil,
        actorEmail: String? = nil,
        actorRole: String = "user",
        action: String,
        resourceType: String,
        resourceId: String? = nil,
        ipAddress: String? = nil,
        userAgent: String? = nil,
        status: String = "success",
        failureReason: String? = nil,
        metadataJson: String? = nil
    ) {
        self.id = id
        if let actorId = actorId {
            self.$actor.id = actorId
        }
        self.actorEmail = actorEmail
        self.actorRole = actorRole
        self.action = action
        self.resourceType = resourceType
        self.resourceId = resourceId
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.status = status
        self.failureReason = failureReason
        self.metadataJson = metadataJson
    }
}
