import Fluent
import Vapor

public final class SymptomLogEntity: Model, Content, @unchecked Sendable {
    public static let schema = "symptom_logs"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Field(key: "logged_at")
    public var loggedAt: Date

    @Field(key: "symptom_type")
    public var symptomType: String

    @Field(key: "severity")
    public var severity: Int

    @Field(key: "notes")
    public var notes: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userId: UUID,
        loggedAt: Date,
        symptomType: String,
        severity: Int,
        notes: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.loggedAt = loggedAt
        self.symptomType = symptomType
        self.severity = severity
        self.notes = notes
    }
}

public final class SyncChangeEntity: Model, Content, @unchecked Sendable {
    public static let schema = "sync_changes"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Field(key: "entity_type")
    public var entityType: String

    @Field(key: "entity_id")
    public var entityId: UUID

    @Field(key: "operation")
    public var operation: String

    @Field(key: "payload_json")
    public var payloadJson: String?

    @Field(key: "timestamp")
    public var timestamp: Date

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userId: UUID,
        entityType: String,
        entityId: UUID,
        operation: String,
        payloadJson: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.$user.id = userId
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.payloadJson = payloadJson
        self.timestamp = timestamp
    }
}
