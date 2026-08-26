import Fluent

/// Migration creating the PostgreSQL schema for asynchronous background processing jobs and workers.
public struct CreateBackgroundJobsMigration: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("background_jobs")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("job_type", .string, .required)
            .field("status", .string, .required)
            .field("progress", .double, .required)
            .field("step_description", .string, .required)
            .field("payload_json", .string)
            .field("result_json", .string)
            .field("error_message", .string)
            .field("retry_count", .int, .required)
            .field("max_retries", .int, .required)
            .field("created_at", .datetime)
            .field("started_at", .datetime)
            .field("completed_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // Create performance indexes for worker queue lookups and user state queries
        if let sqlDb = database as? SQLDatabase {
            _ = try? await sqlDb.raw("CREATE INDEX IF NOT EXISTS idx_bg_jobs_user_status ON background_jobs (user_id, status)").run()
            _ = try? await sqlDb.raw("CREATE INDEX IF NOT EXISTS idx_bg_jobs_status_type ON background_jobs (status, job_type)").run()
            _ = try? await sqlDb.raw("CREATE INDEX IF NOT EXISTS idx_bg_jobs_created ON background_jobs (created_at DESC)").run()
        }
    }

    public func revert(on database: Database) async throws {
        try await database.schema("background_jobs").delete()
    }
}
