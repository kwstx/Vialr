import Foundation
import Vapor
import Domain

/// Proactive error monitoring and anomaly detection engine.
/// Groups errors into fingerprints, calculates error velocities, detects anomaly spikes,
/// and dispatches alerts before users report issues.
public actor ErrorMonitoringService {
    private let app: Application?
    private var fingerprints: [String: ErrorFingerprint] = [:]
    private var recentErrorTimestamps: [Date] = []
    private var alertHistory: [ObservabilityAlert] = []
    private let maxAlertHistory: Int = 200
    private var lastSpikeAlertAt: Date?
    private let webhookURL: String?

    public init(app: Application? = nil) {
        self.app = app
        self.webhookURL = Environment.get("ALERT_WEBHOOK_URL")
    }

    // MARK: - Error Recording & Fingerprinting
    public func recordError(
        error: Error,
        route: String? = nil,
        method: String? = nil,
        statusCode: Int? = nil,
        userId: UUID? = nil,
        requestId: String? = nil,
        isFatal: Bool = false
    ) async {
        let now = Date()
        recentErrorTimestamps.append(now)
        pruneRecentErrors(now: now)

        let errorType = String(describing: type(of: error))
        let rawMessage = error.localizedDescription
        let sanitizedMessage = SensitiveDataScrubber.sanitizeStringContent(rawMessage)
        let errorDomain = (error as? AbortError)?.reason != nil ? "VaporAbort" : "VialrInternal"
        let errorCode = (error as? AbortError)?.status.code.flatMap(Int.init) ?? statusCode

        // Compute deterministic fingerprint ID
        let normalizedRoute = route ?? "unknown"
        let rawFingerprintSource = "\(errorDomain):\(errorType):\(errorCode ?? 0):\(normalizedRoute):\(sanitizedMessage.prefix(60))"
        let fingerprintId = generateFingerprintHash(rawFingerprintSource)

        let severity: AlertSeverity = isFatal ? .critical : ((statusCode ?? 500) >= 500 ? .error : .warning)

        var existing = fingerprints[fingerprintId]
        if var fp = existing {
            let count = fp.occurrenceCount + 1
            let rate = calculateRecentRate(for: fingerprintId, now: now)
            fp = ErrorFingerprint(
                fingerprintId: fingerprintId,
                errorDomain: errorDomain,
                errorType: errorType,
                route: normalizedRoute,
                sampleMessage: sanitizedMessage,
                occurrenceCount: count,
                firstSeenAt: fp.firstSeenAt,
                lastSeenAt: now,
                recentRatePerMinute: rate,
                severity: severity,
                isFatal: isFatal || fp.isFatal
            )
            fingerprints[fingerprintId] = fp
        } else {
            let fp = ErrorFingerprint(
                fingerprintId: fingerprintId,
                errorDomain: errorDomain,
                errorType: errorType,
                route: normalizedRoute,
                sampleMessage: sanitizedMessage,
                occurrenceCount: 1,
                firstSeenAt: now,
                lastSeenAt: now,
                recentRatePerMinute: 1.0,
                severity: severity,
                isFatal: isFatal
            )
            fingerprints[fingerprintId] = fp
        }

        // 1. Check for immediate fatal alert
        if isFatal {
            let alert = ObservabilityAlert(
                severity: .critical,
                category: .healthDegraded,
                title: "CRITICAL: Fatal Backend Error Detected",
                details: "Fatal exception in route [\(normalizedRoute)]: \(sanitizedMessage)",
                metadata: [
                    "errorType": errorType,
                    "route": normalizedRoute,
                    "requestId": requestId ?? "unknown",
                    "userId": userId?.uuidString ?? "anonymous"
                ]
            )
            await fireAlert(alert)
        }

        // 2. Check for error velocity spike (> 5 errors within 60 seconds)
        if recentErrorTimestamps.count >= 5 {
            let shouldAlert: Bool
            if let lastAlert = lastSpikeAlertAt {
                // Rate limit spike alerts to once every 2 minutes
                shouldAlert = now.timeIntervalSince(lastAlert) > 120.0
            } else {
                shouldAlert = true
            }

            if shouldAlert {
                lastSpikeAlertAt = now
                let alert = ObservabilityAlert(
                    severity: .error,
                    category: .errorSpike,
                    title: "Error Rate Spike Detected",
                    details: "Backend encountered \(recentErrorTimestamps.count) errors in the last 60 seconds. Highest velocity error: [\(errorType)] \(sanitizedMessage)",
                    metadata: [
                        "recentErrorCount": "\(recentErrorTimestamps.count)",
                        "triggeringRoute": normalizedRoute,
                        "fingerprintId": fingerprintId
                    ]
                )
                await fireAlert(alert)
            }
        }
    }

    // MARK: - Alert Dispatcher
    public func fireAlert(_ alert: ObservabilityAlert) async {
        // Record in history ring buffer
        if alertHistory.count >= maxAlertHistory {
            alertHistory.removeFirst()
        }
        alertHistory.append(alert)

        if let app = self.app {
            app.logger.critical("🚨 Observability Alert [\(alert.severity.rawValue)] [\(alert.category.rawValue)]: \(alert.title) - \(alert.details)")
        }

        // Dispatch to external webhook if configured
        if let webhookURLString = self.webhookURL, let url = URL(string: webhookURLString) {
            await dispatchWebhook(url: url, alert: alert)
        }
    }

    private func dispatchWebhook(url: URL, alert: ObservabilityAlert) async {
        guard let app = self.app else { return }
        do {
            let payload: [String: Any] = [
                "text": "🚨 *[Vialr Alert - \(alert.severity.rawValue)]* \(alert.title)\n>\(alert.details)",
                "severity": alert.severity.rawValue,
                "category": alert.category.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: alert.timestamp),
                "metadata": alert.metadata
            ]
            let data = try JSONSerialization.data(withJSONObject: payload)
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            let response = try await app.client.post(URI(string: url.absoluteString), headers: headers) { req in
                req.body = .init(data: data)
            }
            if response.status != .ok && response.status != .accepted && response.status != .noContent {
                app.logger.warning("ErrorMonitoringService: Alert webhook returned status \(response.status)")
            }
        } catch {
            app.logger.warning("ErrorMonitoringService: Failed to dispatch alert webhook: \(error.localizedDescription)")
        }
    }

    // MARK: - Query APIs
    public func getAllFingerprints() -> [ErrorFingerprint] {
        return Array(fingerprints.values).sorted { $0.lastSeenAt > $1.lastSeenAt }
    }

    public func getRecentAlerts(limit: Int = 50) -> [ObservabilityAlert] {
        return Array(alertHistory.suffix(limit)).reversed()
    }

    public func getActiveAlertCount() -> Int {
        return alertHistory.filter { !$0.resolved }.count
    }

    public func resolveAlert(alertId: UUID) -> Bool {
        if let index = alertHistory.firstIndex(where: { $0.alertId == alertId }) {
            var alert = alertHistory[index]
            alert.resolved = true
            alert.resolvedAt = Date()
            alertHistory[index] = alert
            return true
        }
        return false
    }

    // MARK: - Helpers
    private func pruneRecentErrors(now: Date) {
        let cutoff = now.addingTimeInterval(-60.0)
        recentErrorTimestamps = recentErrorTimestamps.filter { $0 > cutoff }
    }

    private func calculateRecentRate(for fingerprintId: String, now: Date) -> Double {
        pruneRecentErrors(now: now)
        return Double(recentErrorTimestamps.count)
    }

    private func generateFingerprintHash(_ source: String) -> String {
        var hash = 5381
        for byte in source.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return String(format: "%016llx", UInt64(bitPattern: Int64(hash)))
    }
}

// MARK: - Vapor Application Storage Extension
public struct ErrorMonitoringKey: StorageKey {
    public typealias Value = ErrorMonitoringService
}

extension Application {
    public var errorMonitor: ErrorMonitoringService {
        get {
            if let existing = self.storage[ErrorMonitoringKey.self] {
                return existing
            }
            let service = ErrorMonitoringService(app: self)
            self.storage[ErrorMonitoringKey.self] = service
            return service
        }
        set {
            self.storage[ErrorMonitoringKey.self] = newValue
        }
    }
}
