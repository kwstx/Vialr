import Fluent

public struct CreateDoseLogsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("dose_logs")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("protocol_id", .uuid, .references("protocols", "id", onDelete: .setNull))
            .field("compound_id", .uuid, .required, .references("compounds", "id", onDelete: .cascade))
            .field("scheduled_date", .datetime, .required)
            .field("administered_date", .datetime)
            .field("dose_amount", .double, .required)
            .field("dose_unit", .string, .required)
            .field("injection_site", .string)
            .field("status", .string, .required)
            .field("notes", .string)
            .field("pain_score", .int)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("dose_logs").delete()
    }
}

public struct CreateVialsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("vials")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("compound_id", .uuid, .required, .references("compounds", "id", onDelete: .cascade))
            .field("lot_number", .string)
            .field("dry_mass_mg", .double, .required)
            .field("diluent_volume_ml", .double)
            .field("concentration_mg_ml", .double)
            .field("current_volume_remaining_ml", .double)
            .field("expiration_date", .datetime)
            .field("cost_usd", .double)
            .field("status", .string, .required)
            .field("notes", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("vials").delete()
    }
}

public struct CreateBiomarkersMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("biomarkers")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("value", .double, .required)
            .field("unit", .string, .required)
            .field("reference_range_min", .double)
            .field("reference_range_max", .double)
            .field("test_date", .datetime, .required)
            .field("lab_name", .string)
            .field("notes", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("biomarkers").delete()
    }
}

public struct CreateSymptomLogsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("symptom_logs")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("logged_at", .datetime, .required)
            .field("symptom_type", .string, .required)
            .field("severity", .int, .required)
            .field("notes", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("symptom_logs").delete()
    }
}

public struct CreateSyncChangesMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("sync_changes")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("entity_type", .string, .required)
            .field("entity_id", .uuid, .required)
            .field("operation", .string, .required)
            .field("payload_json", .string)
            .field("timestamp", .datetime, .required)
            .field("created_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("sync_changes").delete()
    }
}
