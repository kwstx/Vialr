import Fluent

/// Database migration creating the immutable audit_logs table for forensic traceability of sensitive and administrative operations.
public struct CreateAuditLogsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("audit_logs")
            .id()
            .field("actor_id", .uuid, .references("users", "id", onDelete: .setNull))
            .field("actor_email", .string)
            .field("actor_role", .string, .required)
            .field("action", .string, .required)
            .field("resource_type", .string, .required)
            .field("resource_id", .string)
            .field("ip_address", .string)
            .field("user_agent", .string)
            .field("status", .string, .required)
            .field("failure_reason", .string)
            .field("metadata_json", .string)
            .field("created_at", .datetime, .required)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("audit_logs").delete()
    }
}
