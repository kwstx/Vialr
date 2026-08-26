import Foundation

/// Protocol defining asynchronous interactions with background jobs (submitting, querying, observing, canceling, and retrying).
public protocol BackgroundJobRepositoryProtocol: Sendable {
    /// Fetches all background jobs for the authenticated user, optionally filtered by status or type
    func fetchJobs(status: BackgroundJobStatus?, type: BackgroundJobType?) async throws -> [BackgroundJob]

    /// Fetches a single job by its ID
    func fetchJob(id: UUID) async throws -> BackgroundJob?

    /// Enqueues a new background job
    func submitJob(type: BackgroundJobType, payloadJson: String?) async throws -> BackgroundJob

    /// Cancels an in-flight or queued job
    func cancelJob(id: UUID) async throws -> BackgroundJob

    /// Retries a failed or cancelled job
    func retryJob(id: UUID) async throws -> BackgroundJob

    /// Subscribes to an async stream of job updates until the job reaches a terminal state (.completed, .failed, .cancelled)
    func observeJob(id: UUID, pollingInterval: TimeInterval) -> AsyncStream<BackgroundJob>
}
