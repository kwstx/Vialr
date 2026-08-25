import Fluent

public struct CreateRefreshTokenAndAppleAuthMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        // 1. Add apple_user_identifier to users schema if not already present
        let userSchema = database.schema("users")
        try await userSchema
            .field("apple_user_identifier", .string)
            .update()

        // 2. Create refresh_tokens table
        try await database.schema("refresh_tokens")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("token_hash", .string, .required)
            .field("family_id", .uuid, .required)
            .field("is_revoked", .bool, .required, .custom("DEFAULT FALSE"))
            .field("expires_at", .datetime, .required)
            .field("device_info", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "token_hash")
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("refresh_tokens").delete()
        try await database.schema("users")
            .deleteField("apple_user_identifier")
            .update()
    }
}
