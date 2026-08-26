import Foundation
import Vapor
import Domain

/// Dedicated background job observability engine.
/// Monitors asynchronous worker queues, execution latency by job type, retry attempts,
/// queue lag, and automatically raises critical alerts when dead-letter poison pills occur.
public actor BackgroundJobObservabilityService {
    private let app: Application?
    private var queuedJobsCount: Int = 0
    private var processingJobsCount: Int = 0
    private var completedJobsCount: Int = 0
    private var failedJobsCount: Int = 0
    private var deadLetterJobsCount: Int = 0
    private var retryCountTotal: Int = 0

    private var jobCountsByType: [String: Int] = [:]
    private var durationsByType: [String: [Double]] = [:]
    private var queueLagSamples: [Double] = []
    private var failedJobAuditLog: [FailedJobRecord] = []
    private let maxAuditLogSize: Int = 200

    public init(app: Application? = nil) {
        self.app = app
    }

    // MARK: - Job Lifecycle Tracking
    public func recordJobEnqueued(jobId: UUID, userId: UUID, type: String) {
        queuedJobsCount += 1
        jobCountsByType[type, default: 0] += 1
    }

    public func recordJobStarted(jobId: UUID, queueDurationSeconds: Double) {
        if queuedJobsCount > 0 {
            queuedJobsCount -= 1
        }
        processingJobsCount += 1

        if queueLagSamples.count >= 200 {
            queueLagSamples.removeFirst()
        }
        queueLagSamples.append(queueDurationSeconds)
    }

    public func recordJobCompleted(jobId: UUID, type: String, durationSeconds: Double) {
        if processingJobsCount > 0 {
            processingJobsCount -= 1
        }
        completedJobsCount += 1

        var durations = durationsByType[type] ?? []
        if durations.count >= 500 {
            durations.removeFirst()
        }
        durations.append(durationSeconds)
        durationsByType[type] = durations
    }

    public func recordJobRetry(
        jobId: UUID,
        userId: UUID,
        type: String,
        retryCount: Int,
        maxRetries: Int,
        errorMessage: String,
        step: String
    ) {
        if processingJobsCount > 0 {
            processingJobsCount -= 1
        }
        queuedJobsCount += 1 // Back in queue for retry
        retryCountTotal += 1

        let sanitizedError = SensitiveDataScrubber.sanitizeStringContent(errorMessage)
        let record = FailedJobRecord(
            jobId: jobId,
            userId: userId,
            jobType: type,
            failedAt: Date(),
            retryCount: retryCount,
            maxRetries: maxRetries,
            isDeadLetter: false,
            errorMessage: sanitizedError,
            stepDescription: step
        )

        if failedJobAuditLog.count >= maxAuditLogSize {
            failedJobAuditLog.removeFirst()
        }
        failedJobAuditLog.append(record)

        if let app = self.app {
            app.logger.warning("BackgroundJobObservability: Job [\(jobId)] type '\(type)' failed attempt \(retryCount)/\(maxRetries): \(sanitizedError)")
        }
    }

    public func recordJobDeadLetter(
        jobId: UUID,
        userId: UUID,
        type: String,
        totalAttempts: Int,
        maxRetries: Int,
        errorMessage: String,
        step: String
    ) async {
        if processingJobsCount > 0 {
            processingJobsCount -= 1
        }
        failedJobsCount += 1
        deadLetterJobsCount += 1

        let sanitizedError = SensitiveDataScrubber.sanitizeStringContent(errorMessage)
        let record = FailedJobRecord(
            jobId: jobId,
            userId: userId,
            jobType: type,
            failedAt: Date(),
            retryCount: totalAttempts,
            maxRetries: maxRetries,
            isDeadLetter: true,
            errorMessage: sanitizedError,
            stepDescription: step
        )

        if failedJobAuditLog.count >= maxAuditLogSize {
            failedJobAuditLog.removeFirst()
        }
        failedJobAuditLog.append(record)

        if let app = self.app {
            app.logger.critical("🚨 BackgroundJobObservability: DEAD-LETTER POISON PILL! Job [\(jobId)] permanently failed after \(totalAttempts) attempts: \(sanitizedError)")

            // Fire critical alert immediately
            let alert = ObservabilityAlert(
                severity: .critical,
                category: .jobRetryExhausted,
                title: "Background Job Dead-Letter Failure",
                details: "Job [\(jobId.uuidString)] of type '\(type)' exhausted all \(maxRetries) retry attempts. Root cause: \(sanitizedError)",
                metadata: [
                    "jobId": jobId.uuidString,
                    "userId": userId.uuidString,
                    "jobType": type,
                    "retryAttempts": "\(totalAttempts)",
                    "lastStep": step
                ]
            )
            await app.errorMonitor.fireAlert(alert)
        }
    }

    // MARK: - Snapshot Generation
    public func generateSnapshot(activeWorkers: Int = 0, maxWorkers: Int = 4) -> JobHealthSnapshot {
        let totalFinished = completedJobsCount + failedJobsCount
        let successRate = totalFinished > 0 ? (Double(completedJobsCount) / Double(totalFinished)) * 100.0 : 100.0

        var avgDurations: [String: Double] = [:]
        for (type, durations) in durationsByType {
            if !durations.isEmpty {
                avgDurations[type] = durations.reduce(0.0, +) / Double(durations.count)
            }
        }

        let avgQueueLag = queueLagSamples.isEmpty ? 0.0 : queueLagSamples.reduce(0.0, +) / Double(queueLagSamples.count)
        let isDegraded = deadLetterJobsCount > 0 || (successRate < 90.0 && totalFinished >= 5) || avgQueueLag > 60.0

        return JobHealthSnapshot(
            timestamp: Date(),
            activeWorkers: activeWorkers,
            maxConcurrentWorkers: maxWorkers,
            queuedJobsCount: queuedJobsCount,
            processingJobsCount: processingJobsCount,
            completedJobsCount: completedJobsCount,
            failedJobsCount: failedJobsCount,
            deadLetterJobsCount: deadLetterJobsCount,
            retryCountTotal: retryCountTotal,
            jobSuccessRatePercentage: successRate,
            jobCountsByType: jobCountsByType,
            averageDurationSecondsByType: avgDurations,
            recentFailedJobs: Array(failedJobAuditLog.suffix(30)).reversed(),
            queueLagSeconds: avgQueueLag,
            isDegraded: isDegraded
        )
    }
}

// MARK: - Vapor Application Storage Extension
public struct BackgroundJobObservabilityKey: StorageKey {
    public typealias Value = BackgroundJobObservabilityService
}

extension Application {
    public var jobMonitor: BackgroundJobObservabilityService {
        get {
            if let existing = self.storage[BackgroundJobObservabilityKey.self] {
                return existing
            }
            let service = BackgroundJobObservabilityService(app: self)
            self.storage[BackgroundJobObservabilityKey.self] = service
            return service
        }
        set {
            self.storage[BackgroundJobObservabilityKey.self] = newValue
        }
    }
}
