import Fluent

public struct CreateProtocolRevisionsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("protocol_revisions")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("protocol_id", .uuid, .required)
            .field("revision_number", .int, .required)
            .field("previous_revision_id", .uuid)
            .field("name", .string, .required)
            .field("compounds_json", .string, .required)
            .field("reason_for_change", .string, .required)
            .field("effective_date", .datetime, .required)
            .field("created_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("protocol_revisions").delete()
    }
}

public struct CreateLabPanelsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("lab_panels")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("panel_name", .string, .required)
            .field("lab_name", .string, .required)
            .field("collection_date", .datetime, .required)
            .field("result_date", .datetime)
            .field("status", .string, .required)
            .field("notes", .string, .required)
            .field("version", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        try await database.schema("lab_results")
            .id()
            .field("panel_id", .uuid, .required, .references("lab_panels", "id", onDelete: .cascade))
            .field("biomarker_name", .string, .required)
            .field("category", .string, .required)
            .field("value", .double, .required)
            .field("text_value", .string)
            .field("unit", .string, .required)
            .field("reference_range_min", .double)
            .field("reference_range_max", .double)
            .field("flag", .string, .required)
            .field("notes", .string, .required)
            .field("created_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("lab_results").delete()
        try await database.schema("lab_panels").delete()
    }
}

public struct CreateSyncConflictsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("sync_conflicts")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("entity_type", .string, .required)
            .field("entity_id", .uuid, .required)
            .field("client_version", .int, .required)
            .field("server_version", .int, .required)
            .field("resolution_strategy", .string, .required)
            .field("client_payload_json", .string)
            .field("server_payload_json", .string)
            .field("preserved_secondary_id", .uuid)
            .field("created_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("sync_conflicts").delete()
    }
}
