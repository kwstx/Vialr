import Fluent
import Vapor

public final class ProtocolRevisionEntity: Model, Content, @unchecked Sendable {
    public static let schema = "protocol_revisions"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Field(key: "protocol_id")
    public var protocolId: UUID

    @Field(key: "revision_number")
    public var revisionNumber: Int

    @Field(key: "previous_revision_id")
    public var previousRevisionId: UUID?

    @Field(key: "name")
    public var name: String

    @Field(key: "compounds_json")
    public var compoundsJson: String

    @Field(key: "reason_for_change")
    public var reasonForChange: String

    @Field(key: "effective_date")
    public var effectiveDate: Date

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userId: UUID,
        protocolId: UUID,
        revisionNumber: Int,
        previousRevisionId: UUID? = nil,
        name: String,
        compoundsJson: String,
        reasonForChange: String = "Protocol modified",
        effectiveDate: Date = Date()
    ) {
        self.id = id
        self.$user.id = userId
        self.protocolId = protocolId
        self.revisionNumber = revisionNumber
        self.previousRevisionId = previousRevisionId
        self.name = name
        self.compoundsJson = compoundsJson
        self.reasonForChange = reasonForChange
        self.effectiveDate = effectiveDate
    }
}
