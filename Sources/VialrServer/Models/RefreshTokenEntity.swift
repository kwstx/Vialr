import Fluent
import Vapor

public final class RefreshTokenEntity: Model, Content, @unchecked Sendable {
    public static let schema = "refresh_tokens"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Field(key: "token_hash")
    public var tokenHash: String

    @Field(key: "family_id")
    public var familyId: UUID

    @Field(key: "is_revoked")
    public var isRevoked: Bool

    @Field(key: "expires_at")
    public var expiresAt: Date

    @Field(key: "device_info")
    public var deviceInfo: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userId: UUID,
        tokenHash: String,
        familyId: UUID = UUID(),
        isRevoked: Bool = false,
        expiresAt: Date = Date().addingTimeInterval(60 * 60 * 24 * 60), // 60 days
        deviceInfo: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.tokenHash = tokenHash
        self.familyId = familyId
        self.isRevoked = isRevoked
        self.expiresAt = expiresAt
        self.deviceInfo = deviceInfo
    }
}
