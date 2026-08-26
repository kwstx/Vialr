import Foundation
import Domain

/// Client-side observability and diagnostic telemetry engine.
/// Tracks network roundtrip latency, sync push/pull failures, offline outbox depth,
/// and formats sanitized diagnostic logs for troubleshooting without leaking sensitive health details.
public actor ClientObservabilityService {
    public static let shared = ClientObservabilityService()

    private var recentLatencies: [Double] = []
    private var networkFailureCount: Int = 0
    private var syncRejectionCount: Int = 0
    private var lastSuccessfulSyncAt: Date?
    private var diagnosticLogs: [String] = []
    private let maxLogEntries: Int = 100

    public init() {}

    // MARK: - Request Tracing
    public func recordNetworkRequest(endpoint: String, latencyMs: Double, statusCode: Int) {
        if recentLatencies.count >= 200 {
            recentLatencies.removeFirst()
        }
        recentLatencies.append(latencyMs)

        if statusCode >= 400 {
            networkFailureCount += 1
            appendLog("⚠️ HTTP \(statusCode) on [\(endpoint)] (\(String(format: "%.1f", latencyMs))ms)")
        } else {
            appendLog("✅ HTTP \(statusCode) on [\(endpoint)] (\(String(format: "%.1f", latencyMs))ms)")
        }
    }

    public func recordSyncSuccess(batchCount: Int) {
        lastSuccessfulSyncAt = Date()
        appendLog("🔄 Sync batch completed successfully (\(batchCount) operations)")
    }

    public func recordSyncRejection(operationId: UUID, entityType: String, reason: String) {
        syncRejectionCount += 1
        appendLog("❌ Sync rejected: [\(entityType)] OpID: \(operationId.uuidString.prefix(8)) Reason: \(reason)")
    }

    // MARK: - Client Health Summary
    public func getDiagnosticSummary() -> [String: String] {
        let avgLatency = recentLatencies.isEmpty ? 0.0 : recentLatencies.reduce(0.0, +) / Double(recentLatencies.count)
        return [
            "averageLatencyMs": String(format: "%.1f", avgLatency),
            "networkFailures": "\(networkFailureCount)",
            "syncRejections": "\(syncRejectionCount)",
            "lastSuccessfulSync": lastSuccessfulSyncAt.map { ISO8601DateFormatter().string(from: $0) } ?? "never"
        ]
    }

    public func getRecentLogs() -> [String] {
        return diagnosticLogs
    }

    private func appendLog(_ entry: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let formatted = "[\(timestamp)] \(entry)"
        if diagnosticLogs.count >= maxLogEntries {
            diagnosticLogs.removeFirst()
        }
        diagnosticLogs.append(formatted)
    }
}
