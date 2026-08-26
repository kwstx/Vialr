import Foundation
import Domain

/// Remote repository communicating with the Vialr API for background processing jobs.
/// Supports polling, async streaming, non-blocking job creation, cancellation, and retry.
public final class RemoteBackgroundJobRepository: BackgroundJobRepositoryProtocol, @unchecked Sendable {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    public func fetchJobs(status: BackgroundJobStatus? = nil, type: BackgroundJobType? = nil) async throws -> [BackgroundJob] {
        let endpoint = Endpoint.listBackgroundJobs(status: status?.rawValue, type: type?.rawValue)
        let dtos = try await apiClient.request(endpoint: endpoint, responseType: [BackgroundJobRemoteDTO].self)
        return dtos.map { $0.toDomainModel() }
    }

    public func fetchJob(id: UUID) async throws -> BackgroundJob? {
        let endpoint = Endpoint.getBackgroundJob(id: id)
        let dto = try await apiClient.request(endpoint: endpoint, responseType: BackgroundJobRemoteDTO.self)
        return dto.toDomainModel()
    }

    public func submitJob(type: BackgroundJobType, payloadJson: String? = nil) async throws -> BackgroundJob {
        let endpoint = Endpoint.submitBackgroundJob
        let body = [
            "jobType": type.rawValue,
            "payloadJson": payloadJson
        ]
        let dto = try await apiClient.request(endpoint: endpoint, body: body, responseType: BackgroundJobRemoteDTO.self)
        return dto.toDomainModel()
    }

    public func cancelJob(id: UUID) async throws -> BackgroundJob {
        let endpoint = Endpoint.cancelBackgroundJob(id: id)
        let emptyBody: [String: String]? = nil
        let actionResp = try await apiClient.request(endpoint: endpoint, body: emptyBody, responseType: BackgroundJobActionRemoteDTO.self)
        return actionResp.job.toDomainModel()
    }

    public func retryJob(id: UUID) async throws -> BackgroundJob {
        let endpoint = Endpoint.retryBackgroundJob(id: id)
        let emptyBody: [String: String]? = nil
        let dto = try await apiClient.request(endpoint: endpoint, body: emptyBody, responseType: BackgroundJobRemoteDTO.self)
        return dto.toDomainModel()
    }

    /// Creates a continuous observation stream that yields live updates as the worker makes progress
    /// until the job finishes (.completed, .failed, or .cancelled).
    public func observeJob(id: UUID, pollingInterval: TimeInterval = 0.5) -> AsyncStream<BackgroundJob> {
        AsyncStream { continuation in
            let task = Task {
                var lastStatus: BackgroundJobStatus? = nil
                var lastProgress: Double = -1.0

                while !Task.isCancelled {
                    do {
                        if let job = try await self.fetchJob(id: id) {
                            // Yield update if progress or status changed
                            if job.status != lastStatus || abs(job.progress - lastProgress) > 0.01 || job.isFinished {
                                continuation.yield(job)
                                lastStatus = job.status
                                lastProgress = job.progress
                            }

                            if job.isFinished {
                                continuation.finish()
                                break
                            }
                        }
                    } catch {
                        // In case of transient network error, continue polling unless cancelled
                    }

                    let sleepNanos = UInt64(pollingInterval * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: sleepNanos)
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Remote DTOs
public struct BackgroundJobRemoteDTO: Codable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let jobType: String
    public let status: String
    public let progress: Double
    public let stepDescription: String
    public let payloadJson: String?
    public let resultJson: String?
    public let errorMessage: String?
    public let retryCount: Int
    public let maxRetries: Int
    public let createdAt: Date?
    public let startedAt: Date?
    public let completedAt: Date?
    public let updatedAt: Date?

    public func toDomainModel() -> BackgroundJob {
        BackgroundJob(
            id: id,
            userId: userId,
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

public struct BackgroundJobActionRemoteDTO: Codable, Sendable {
    public let job: BackgroundJobRemoteDTO
    public let message: String
}
