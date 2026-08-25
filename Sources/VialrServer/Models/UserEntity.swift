import Fluent
import Vapor

public final class UserEntity: Model, Content, @unchecked Sendable {
    public static let schema = "users"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "email")
    public var email: String

    @Field(key: "password_hash")
    public var passwordHash: String

    @Field(key: "apple_user_identifier")
    public var appleUserIdentifier: String?

    @Field(key: "display_name")
    public var displayName: String

    @Field(key: "avatar_url")
    public var avatarUrl: String?

    @Field(key: "phone_number")
    public var phoneNumber: String?

    @Field(key: "tier")
    public var tier: String

    @Field(key: "status")
    public var status: String

    @Field(key: "timezone")
    public var timezone: String

    @Field(key: "preferences_json")
    public var preferencesJson: String?

    @Field(key: "units_json")
    public var unitsJson: String?

    @Field(key: "notifications_json")
    public var notificationsJson: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    // Relationships
    @Children(for: \.$user)
    public var compounds: [CompoundEntity]

    @Children(for: \.$user)
    public var protocols: [ProtocolEntity]

    @Children(for: \.$user)
    public var doseLogs: [DoseLogEntity]

    @Children(for: \.$user)
    public var vials: [VialEntity]

    @Children(for: \.$user)
    public var storedFiles: [StoredFileEntity]

    @Children(for: \.$user)
    public var measurements: [MeasurementEntity]

    @Children(for: \.$user)
    public var supplyItems: [SupplyItemEntity]

    @Children(for: \.$user)
    public var reconstitutionRecords: [ReconstitutionRecordEntity]

    @Children(for: \.$user)
    public var notifications: [NotificationRecordEntity]

    @Children(for: \.$user)
    public var refreshTokens: [RefreshTokenEntity]

    public init() {}

    public init(
        id: UUID? = nil,
        email: String,
        passwordHash: String,
        appleUserIdentifier: String? = nil,
        displayName: String,
        avatarUrl: String? = nil,
        phoneNumber: String? = nil,
        tier: String = "free",
        status: String = "active",
        timezone: String = "UTC",
        preferencesJson: String? = nil,
        unitsJson: String? = nil,
        notificationsJson: String? = nil
    ) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.appleUserIdentifier = appleUserIdentifier
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.phoneNumber = phoneNumber
        self.tier = tier
        self.status = status
        self.timezone = timezone
        self.preferencesJson = preferencesJson
        self.unitsJson = unitsJson
        self.notificationsJson = notificationsJson
    }
}
