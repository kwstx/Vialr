import Foundation
import Combine
import Domain

/// Central client-side observable manager for tracking and observing background jobs in the iOS application.
/// Provides real-time reactive updates for UI components, banners, and modal flows.
@MainActor
public final class BackgroundJobManager: ObservableObject {
    public static let shared = BackgroundJobManager()

    @Published public private(set) var activeJobs: [BackgroundJob] = []
    @Published public private(set) var recentCompletedJobs: [BackgroundJob] = []
    @Published public private(set) var currentHighlightJob: BackgroundJob?

    private let repository: BackgroundJobRepositoryProtocol
    private var observationTasks: [UUID: Task<Void, Never>] = [:]

    public init(repository: BackgroundJobRepositoryProtocol = RemoteBackgroundJobRepository()) {
        self.repository = repository
    }

    /// Fetches all jobs for the user and starts observing active ones
    public func refreshJobs() async {
        do {
            let jobs = try await repository.fetchJobs(status: nil, type: nil)
            let active = jobs.filter { $0.isActive }
            let completed = jobs.filter { $0.isFinished }

            self.activeJobs = active
            self.recentCompletedJobs = Array(completed.prefix(10))

            // Start observing any active jobs not yet tracked
            for job in active {
                trackJob(jobId: job.id)
            }
        } catch {
            // Non-critical network error
        }
    }

    /// Begins real-time async stream observation for a given background job
    public func trackJob(jobId: UUID) {
        guard observationTasks[jobId] == nil else { return }

        let task = Task { [weak self] in
            guard let self = self else { return }
            let stream = self.repository.observeJob(id: jobId, pollingInterval: 0.5)

            for await updatedJob in stream {
                await self.updateJobState(updatedJob)
            }
            await self.cleanupObservation(jobId: jobId)
        }

        observationTasks[jobId] = task
    }

    /// Updates internal state for a job and manages active/completed lists
    private func updateJobState(_ job: BackgroundJob) {
        if let idx = activeJobs.firstIndex(where: { $0.id == job.id }) {
            if job.isFinished {
                activeJobs.remove(at: idx)
                recentCompletedJobs.insert(job, at: 0)
                if recentCompletedJobs.count > 15 {
                    recentCompletedJobs.removeLast()
                }
            } else {
                activeJobs[idx] = job
            }
        } else if job.isActive {
            activeJobs.insert(job, at: 0)
        }

        // Update highlight job if it matches
        if currentHighlightJob?.id == job.id || currentHighlightJob == nil && job.isActive {
            currentHighlightJob = job
        }
    }

    private func cleanupObservation(jobId: UUID) {
        observationTasks[jobId]?.cancel()
        observationTasks.removeValue(forKey: jobId)
    }

    /// Dismisses a completed highlight job from the banner
    public func dismissHighlightJob() {
        currentHighlightJob = nil
    }

    /// Cancels an active job
    public func cancelJob(id: UUID) async {
        do {
            let cancelled = try await repository.cancelJob(id: id)
            updateJobState(cancelled)
            cleanupObservation(jobId: id)
        } catch {
            // Handle error
        }
    }

    /// Retries a failed job
    public func retryJob(id: UUID) async {
        do {
            let retried = try await repository.retryJob(id: id)
            updateJobState(retried)
            trackJob(jobId: retried.id)
        } catch {
            // Handle error
        }
    }
}
