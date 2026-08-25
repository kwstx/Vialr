import Fluent
import Vapor

public final class InjectionSiteEventEntity: Model, Content, @unchecked Sendable {
    public static let schema = "injection_site_events"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @OptionalParent(key: "dose_log_id")
    public var doseLog: DoseLogEntity?

    @Field(key: "site_id")
    public var siteId: String

    @Field(key: "site_name")
    public var siteName: String

    @Field(key: "region")
    public var region: String

    @Field(key: "side")
    public var side: String

    @Field(key: "administered_at")
    public var administeredAt: Date

    @Field(key: "pain_score")
    public var painScore: Int?

    @Field(key: "notes")
    public var notes: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userId: UUID,
        doseLogId: UUID? = nil,
        siteId: String,
        siteName: String,
        region: String,
        side: String,
        administeredAt: Date = Date(),
        painScore: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.$doseLog.id = doseLogId
        self.siteId = siteId
        self.siteName = siteName
        self.region = region
        self.side = side
        self.administeredAt = administeredAt
        self.painScore = painScore
        self.notes = notes
    }
}
