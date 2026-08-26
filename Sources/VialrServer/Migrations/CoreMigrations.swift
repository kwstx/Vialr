import Fluent

public struct CreateUsersMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("email", .string, .required)
            .field("password_hash", .string, .required)
            .field("apple_user_identifier", .string)
            .field("display_name", .string, .required)
            .field("avatar_url", .string)
            .field("phone_number", .string)
            .field("tier", .string, .sql(.default("free")))
            .field("role", .string, .sql(.default("user")))
            .field("status", .string, .sql(.default("active")))
            .field("timezone", .string, .sql(.default("UTC")))
            .field("preferences_json", .string)
            .field("units_json", .string)
            .field("notifications_json", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "email")
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}

public struct CreateCompoundsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("compounds")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("category", .string, .required)
            .field("default_dose", .double, .required)
            .field("default_unit", .string, .required)
            .field("half_life_hours", .double, .required)
            .field("notes", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("compounds").delete()
    }
}

public struct CreateProtocolsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("protocols")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("compound_id", .uuid, .required, .references("compounds", "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("schedule_frequency", .string, .required)
            .field("dose_amount", .double, .required)
            .field("dose_unit", .string, .required)
            .field("cycle_duration_weeks", .int, .required)
            .field("start_date", .datetime, .required)
            .field("end_date", .datetime)
            .field("notes", .string)
            .field("status", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("protocols").delete()
    }
}
