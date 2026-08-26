import Foundation
import Vapor
import Domain

/// Dedicated synchronization observability engine.
/// Tracks outbox batch throughput, individual entity mutations, conflict resolutions,
/// rejection reason codes, and raises proactive alerts when sync failure rates spike.
public actor SyncObservabilityService {
    private let app: Application?
    private var totalPushBatches: Int = 0
    private var totalPullBatches: Int = 0
    private var totalOperations: Int = 0
    private var appliedOperations: Int = 0
    private var resolvedConflicts: Int = 0
    private var rejectedOperations: Int = 0

    private var operationsByEntity: [String: Int] = [:]
    private var rejectionsByReasonCode: [String: Int] = [:]
    private var failureAuditLog: [SyncFailureRecord] = []
    private let maxFailureLogSize: Int = 200

    // Sliding window of recent operations for rate calculation (5 minutes)
    private struct OperationEvent {
        let timestamp: Date
        let isFailure: Bool
    }
    private var recentOperations: [OperationEvent] = []
    private var consecutiveFailedBatches: Int = 0
    private var lastSyncAlertAt: Date?

    public init(app: Application? = nil) {
        self.app = app
    }

    // MARK: - Batch Lifecycle Recording
    public func recordPushBatch(userId: UUID, operationsCount: Int) {
        totalPushBatches += 1
    }

    public func recordPullBatch(userId: UUID, deltasCount: Int) {
        totalPullBatches += 1
    }

    // MARK: - Operation Success Recording
    public func recordOperationSuccess(
        userId: UUID,
        operationId: UUID,
        entityType: String,
        status: String
    ) {
        totalOperations += 1
        operationsByEntity[entityType, default: 0] += 1

        let now = Date()
        recentOperations.append(OperationEvent(timestamp: now, isFailure: false))
        pruneRecentOperations(now: now)

        if status == "applied" || status == "appended" {
            appliedOperations += 1
        } else if status == "resolvedLWW" || status == "preservedBoth" {
            resolvedConflicts += 1
        }
    }

    // MARK: - Operation Failure & Rejection Recording
    public func recordOperationFailure(
        userId: UUID,
        operationId: UUID,
        entityType: String,
        operationType: String,
        rejectionCode: String,
        failureReason: String,
        isFatal: Bool = false
    ) async {
        totalOperations += 1
        rejectedOperations += 1
        operationsByEntity[entityType, default: 0] += 1
        rejectionsByReasonCode[rejectionCode, default: 0] += 1

        let now = Date()
        recentOperations.append(OperationEvent(timestamp: now, isFailure: true))
        pruneRecentOperations(now: now)

        let sanitizedReason = SensitiveDataScrubber.sanitizeStringContent(failureReason)

        let record = SyncFailureRecord(
            failureId: UUID(),
            timestamp: now,
            userId: userId,
            operationId: operationId,
            entityType: entityType,
            operationType: operationType,
            rejectionCode: rejectionCode,
            failureReason: sanitizedReason,
            isFatal: isFatal
        )

        if failureAuditLog.count >= maxFailureLogSize {
            failureAuditLog.removeFirst()
        }
        failureAuditLog.append(record)

        // Log structured sync failure
        if let app = self.app {
            app.logger.warning("SyncObservability: Operation [\(operationId)] rejected. Entity: '\(entityType)', ReasonCode: '\(rejectionCode)' - \(sanitizedReason)")
        }

        // Check for sync failure rate spike alert
        await evaluateSyncHealthAlert(now: now)
    }

    // MARK: - Proactive Sync Health Alerting
    private func evaluateSyncHealthAlert(now: Date) async {
        guard let app = self.app else { return }
        pruneRecentOperations(now: now)

        let windowCount = recentOperations.count
        guard windowCount >= 10 else { return } // Minimum sample threshold

        let failedCount = recentOperations.filter { $0.isFailure }.count
        let failureRate = (Double(failedCount) / Double(windowCount)) * 100.0

        // If failure rate exceeds 5% in the last 5 minutes
        if failureRate > 5.0 {
            let shouldAlert: Bool
            if let last = lastSyncAlertAt {
                shouldAlert = now.timeIntervalSince(last) > 180.0 // Rate-limit to once every 3 min
            } else {
                shouldAlert = true
            }

            if shouldAlert {
                lastSyncAlertAt = now
                let alert = ObservabilityAlert(
                    severity: failureRate > 20.0 ? .critical : .error,
                    category: .syncFailureSpike,
                    title: "High Sync Rejection Rate Detected",
                    details: "Synchronization failure rate is \(String(format: "%.1f", failureRate))% (\(failedCount)/\(windowCount) operations rejected in 5m window). Top rejection code: \(topRejectionCode())",
                    metadata: [
                        "failureRate": String(format: "%.2f", failureRate),
                        "windowOperations": "\(windowCount)",
                        "failedOperations": "\(failedCount)",
                        "topRejectionCode": topRejectionCode()
                    ]
                )
                await app.errorMonitor.fireAlert(alert)
            }
        }
    }

    private func topRejectionCode() -> String {
        return rejectionsByReasonCode.max(by: { $0.value < $1.value })?.key ?? "UNKNOWN"
    }

    private func pruneRecentOperations(now: Date) {
        let cutoff = now.addingTimeInterval(-300.0) // 5 minutes
        recentOperations = recentOperations.filter { $0.timestamp > cutoff }
    }

    // MARK: - Snapshot Generation
    public func generateSnapshot() -> SyncHealthSnapshot {
        let total = totalOperations
        let successful = appliedOperations + resolvedConflicts
        let successRate = total > 0 ? (Double(successful) / Double(total)) * 100.0 : 100.0
        let isDegraded = successRate < 95.0 && total >= 10

        return SyncHealthSnapshot(
            timestamp: Date(),
            totalPushBatches: totalPushBatches,
            totalPullBatches: totalPullBatches,
            totalOperations: totalOperations,
            appliedOperations: appliedOperations,
            resolvedConflicts: resolvedConflicts,
            rejectedOperations: rejectedOperations,
            syncSuccessRatePercentage: successRate,
            operationsByEntity: operationsByEntity,
            rejectionsByReasonCode: rejectionsByReasonCode,
            recentFailures: Array(failureAuditLog.suffix(30)).reversed(),
            isDegraded: isDegraded
        )
    }
}

// MARK: - Vapor Application Storage Extension
public struct SyncObservabilityKey: StorageKey {
    public typealias Value = SyncObservabilityService
}

extension Application {
    public var syncMonitor: SyncObservabilityService {
        get {
            if let existing = self.storage[SyncObservabilityKey.self] {
                return existing
            }
            let service = SyncObservabilityService(app: self)
            self.storage[SyncObservabilityKey.self] = service
            return service
        }
        set {
            self.storage[SyncObservabilityKey.self] = newValue
        }
    }
}
