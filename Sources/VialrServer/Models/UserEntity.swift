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

    @Field(key: "display_name")
    public var displayName: String

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


    public init() {}

    public init(id: UUID? = nil, email: String, passwordHash: String, displayName: String) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.displayName = displayName
    }
}
