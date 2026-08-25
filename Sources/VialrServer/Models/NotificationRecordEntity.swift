import Fluent
import Vapor

public final class NotificationRecordEntity: Model, Content, @unchecked Sendable {
    public static let schema = "notification_records"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Field(key: "title")
    public var title: String

    @Field(key: "body")
    public var body: String

    @Field(key: "category")
    public var category: String

    @Field(key: "scheduled_date")
    public var scheduledDate: Date

    @Field(key: "is_read")
    public var isRead: Bool

    @Field(key: "deep_link_uri")
    public var deepLinkUri: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userId: UUID,
        title: String,
        body: String,
        category: String = "reminder",
        scheduledDate: Date = Date(),
        isRead: Bool = false,
        deepLinkUri: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.title = title
        self.body = body
        self.category = category
        self.scheduledDate = scheduledDate
        self.isRead = isRead
        self.deepLinkUri = deepLinkUri
    }
}

public final class DeviceTokenEntity: Model, Content, @unchecked Sendable {
    public static let schema = "device_tokens"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Field(key: "device_token")
    public var deviceToken: String

    @Field(key: "platform")
    public var platform: String

    @Field(key: "app_version")
    public var appVersion: String?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userId: UUID,
        deviceToken: String,
        platform: String = "iOS",
        appVersion: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.deviceToken = deviceToken
        self.platform = platform
        self.appVersion = appVersion
    }
}
