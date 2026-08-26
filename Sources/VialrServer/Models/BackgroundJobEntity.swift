import Vapor
import Fluent
import Domain
import Foundation

/// Fluent entity representing a persistent background processing job in PostgreSQL.
/// Ensures heavy tasks (PDF OCR, Report generation, Data exports, Analytics calculations, Sync)
/// are queued, tracked, retried, and monitored asynchronously without blocking synchronous HTTP API requests.
public final class BackgroundJobEntity: Model, @unchecked Sendable {
    public static let schema = "background_jobs"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Field(key: "job_type")
    public var jobType: String // maps to BackgroundJobType

    @Field(key: "status")
    public var status: String // maps to BackgroundJobStatus

    @Field(key: "progress")
    public var progress: Double // 0.0 to 1.0

    @Field(key: "step_description")
    public var stepDescription: String

    @Field(key: "payload_json")
    public var payloadJson: String?

    @Field(key: "result_json")
    public var resultJson: String?

    @Field(key: "error_message")
    public var errorMessage: String?

    @Field(key: "retry_count")
    public var retryCount: Int

    @Field(key: "max_retries")
    public var maxRetries: Int

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Field(key: "started_at")
    public var startedAt: Date?

    @Field(key: "completed_at")
    public var completedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID = UUID(),
        userId: UUID,
        jobType: BackgroundJobType,
        status: BackgroundJobStatus = .queued,
        progress: Double = 0.0,
        stepDescription: String = "Queued in background processing pool",
        payloadJson: String? = nil,
        resultJson: String? = nil,
        errorMessage: String? = nil,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.jobType = jobType.rawValue
        self.status = status.rawValue
        self.progress = progress
        self.stepDescription = stepDescription
        self.payloadJson = payloadJson
        self.resultJson = resultJson
        self.errorMessage = errorMessage
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    /// Converts database entity to clean domain model
    public func toDomainModel() -> BackgroundJob {
        BackgroundJob(
            id: id ?? UUID(),
            userId: $user.id,
            jobType: BackgroundJobType(rawValue: jobType) ?? .pdfProcessing,
            status: BackgroundJobStatus(rawValue: status) ?? .queued,
            progress: progress,
            stepDescription: stepDescription,
            payloadJson: payloadJson,
            resultJson: resultJson,
            errorMessage: errorMessage,
            retryCount: retryCount,
            maxRetries: maxRetries,
            createdAt: createdAt ?? Date(),
            startedAt: startedAt,
            completedAt: completedAt,
            updatedAt: updatedAt ?? Date(),
            version: 1,
            syncState: .synced
        )
    }
}
