import Fluent

/// Migration creating PostgreSQL `stored_files` metadata and relational schema.
public struct CreateStoredFilesMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("stored_files")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("category", .string, .required)
            .field("file_name", .string, .required)
            .field("content_type", .string, .required)
            .field("byte_size", .int64, .required)
            .field("sha256_checksum", .string, .required)
            .field("storage_bucket", .string, .required)
            .field("storage_key", .string, .required)
            .field("encryption_algorithm", .string, .required)
            .field("encryption_key_id", .string, .required)
            .field("encryption_iv", .string, .required)
            .field("encryption_tag", .string, .required)
            .field("is_encrypted", .bool, .required)
            // Relational foreign keys in PostgreSQL
            .field("vial_id", .uuid, .references("vials", "id", onDelete: .setNull))
            .field("biomarker_id", .uuid, .references("biomarkers", "id", onDelete: .setNull))
            .field("dose_log_id", .uuid, .references("dose_logs", "id", onDelete: .setNull))
            .field("protocol_id", .uuid, .references("protocols", "id", onDelete: .setNull))
            .field("symptom_log_id", .uuid, .references("symptom_logs", "id", onDelete: .setNull))
            .field("metadata_json", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "storage_key")
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("stored_files").delete()
    }
}
