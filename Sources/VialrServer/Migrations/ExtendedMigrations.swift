import Fluent

// MARK: - 1. Reconstitution Records Migration
public struct CreateReconstitutionRecordsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("reconstitution_records")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("vial_id", .uuid, .required, .references("vials", "id", onDelete: .cascade))
            .field("compound_id", .uuid, .required, .references("compounds", "id", onDelete: .cascade))
            .field("dry_mass_mg", .double, .required)
            .field("diluent_volume_ml", .double, .required)
            .field("diluent_type", .string, .required)
            .field("diluent_lot_number", .string)
            .field("diluent_brand", .string)
            .field("reconstituted_at", .datetime, .required)
            .field("concentration_mg_ml", .double, .required)
            .field("concentration_mcg_ml", .double, .required)
            .field("total_liquid_volume_ml", .double, .required)
            .field("storage_condition", .string, .required)
            .field("expected_shelf_life_days", .int, .required)
            .field("expiration_date", .datetime)
            .field("is_confirmed", .bool, .required)
            .field("version", .int, .required)
            .field("is_current_active_revision", .bool, .required)
            .field("previous_record_id", .uuid)
            .field("superseded_by_record_id", .uuid)
            .field("revision_reason", .string)
            .field("solution_clarity", .string, .required)
            .field("notes", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("reconstitution_records").delete()
    }
}

// MARK: - 2. Supply Items Migration
public struct CreateSupplyItemsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("supply_items")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("category", .string, .required)
            .field("quantity_remaining", .int, .required)
            .field("package_unit", .string, .required)
            .field("reorder_threshold", .int, .required)
            .field("cost_usd", .double)
            .field("notes", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("supply_items").delete()
    }
}

// MARK: - 3. Injection Site Events Migration
public struct CreateInjectionSiteEventsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("injection_site_events")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("dose_log_id", .uuid, .references("dose_logs", "id", onDelete: .setNull))
            .field("site_id", .string, .required)
            .field("site_name", .string, .required)
            .field("region", .string, .required)
            .field("side", .string, .required)
            .field("administered_at", .datetime, .required)
            .field("pain_score", .int)
            .field("notes", .string)
            .field("created_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("injection_site_events").delete()
    }
}

// MARK: - 4. Measurements Migration
public struct CreateMeasurementsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("measurements")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("protocol_id", .uuid, .references("protocols", "id", onDelete: .setNull))
            .field("name", .string, .required)
            .field("type", .string, .required)
            .field("category", .string, .required)
            .field("value", .double, .required)
            .field("secondary_value", .double)
            .field("unit", .string, .required)
            .field("date_recorded", .datetime, .required)
            .field("source", .string, .required)
            .field("reference_range_min", .double)
            .field("reference_range_max", .double)
            .field("status", .string, .required)
            .field("notes", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("measurements").delete()
    }
}

// MARK: - 5. Notifications & Device Tokens Migration
public struct CreateNotificationsAndTokensMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("notification_records")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("title", .string, .required)
            .field("body", .string, .required)
            .field("category", .string, .required)
            .field("scheduled_date", .datetime, .required)
            .field("is_read", .bool, .required)
            .field("deep_link_uri", .string)
            .field("created_at", .datetime)
            .create()

        try await database.schema("device_tokens")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("device_token", .string, .required)
            .field("platform", .string, .required)
            .field("app_version", .string)
            .field("updated_at", .datetime)
            .field("created_at", .datetime)
            .unique(on: "user_id", "device_token")
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("device_tokens").delete()
        try await database.schema("notification_records").delete()
    }
}
