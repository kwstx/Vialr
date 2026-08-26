import Foundation
import Domain

/// Protocol defining a privacy-first telemetry and analytics gateway.
/// Guaranteed to keep all analytics events free of Protected Health Information (PHI),
/// compound names, raw lab values, and personal identifiers.
public protocol PrivacyPreservingAnalyticsProtocol: Sendable {
    func trackEvent(name: String, properties: [String: Any]) async
    func trackScreen(screenName: String) async
    func trackDoseAction(hasVial: Bool, isOnTime: Bool, routeType: String) async
    func trackLabImport(candidateCount: Int, sourceType: String, durationMs: Double) async
    func trackSyncStatus(batchCount: Int, isSuccess: Bool, durationMs: Double) async
    func getAuditTrail() async -> [[String: Any]]
}

/// Production privacy-preserving analytics engine.
/// Intercepts and scrubs all telemetry events, preventing any accidental transmission of raw medical,
/// protocol, compound, or biomarker data to generic third-party analytics platforms.
public actor PrivacyPreservingAnalyticsEngine: PrivacyPreservingAnalyticsProtocol {
    public static let shared = PrivacyPreservingAnalyticsEngine()

    private var opaqueSubjectId: OpaqueSubjectIdentifier?
    private var isTelemetryEnabled: Bool = false
    private var eventAuditLog: [[String: Any]] = []
    private let maxAuditEntries: Int = 100

    public init(
        opaqueSubjectId: OpaqueSubjectIdentifier? = nil,
        isTelemetryEnabled: Bool = false
    ) {
        self.opaqueSubjectId = opaqueSubjectId
        self.isTelemetryEnabled = isTelemetryEnabled
    }

    // MARK: - Configuration
    public func setTelemetryEnabled(_ enabled: Bool) {
        self.isTelemetryEnabled = enabled
    }

    public func setOpaqueSubjectId(_ opaqueId: OpaqueSubjectIdentifier?) {
        self.opaqueSubjectId = opaqueId
    }

    // MARK: - Event Tracking with Zero-Health-Leakage Scrubber
    public func trackEvent(name: String, properties: [String: Any]) {
        guard isTelemetryEnabled else { return }

        // 1. Enforce whitelisted event name
        let cleanEventName = AnalyticsEventPrivacyScrubber.allowedEventNames.contains(name) ? name : "generic_interaction"

        // 2. Sanitize properties through privacy scrubber (strips all PHI, raw lab values, compound names, dosages)
        let sanitizedProperties = AnalyticsEventPrivacyScrubber.sanitizeEvent(
            name: cleanEventName,
            properties: properties,
            opaqueSubjectId: opaqueSubjectId
        )

        // 3. Mathematical zero-health-leakage validation assertion
        assert(
            AnalyticsEventPrivacyScrubber.verifyZeroHealthLeakage(sanitizedProperties),
            "[PrivacyArchitecture] CRITICAL ERROR: Health or protocol data detected in sanitized telemetry event!"
        )

        // 4. Record to local privacy audit trail
        var auditEntry = sanitizedProperties
        auditEntry["event_name"] = cleanEventName
        if eventAuditLog.count >= maxAuditEntries {
            eventAuditLog.removeFirst()
        }
        eventAuditLog.append(auditEntry)
    }

    // MARK: - Dedicated Privacy-Safe Trackers

    public func trackScreen(screenName: String) {
        trackEvent(
            name: "screen_viewed",
            properties: [
                "screen_name": screenName
            ]
        )
    }

    public func trackDoseAction(hasVial: Bool, isOnTime: Bool, routeType: String) {
        // Only emit structural, operational flags — NEVER the compound name or dose amount!
        trackEvent(
            name: "dose_log_created",
            properties: [
                "has_vial_attached": hasVial,
                "is_on_time": isOnTime,
                "action_source": "client_ui"
            ]
        )
    }

    public func trackLabImport(candidateCount: Int, sourceType: String, durationMs: Double) {
        // Only emit metadata counts — NEVER biomarker names or raw numeric lab readings!
        trackEvent(
            name: "lab_panel_imported",
            properties: [
                "candidate_count": candidateCount,
                "source_type": sourceType,
                "latency_ms": durationMs
            ]
        )
    }

    public func trackSyncStatus(batchCount: Int, isSuccess: Bool, durationMs: Double) {
        trackEvent(
            name: isSuccess ? "sync_push_completed" : "sync_conflict_detected",
            properties: [
                "item_count": batchCount,
                "latency_ms": durationMs,
                "status_code": isSuccess ? 200 : 500
            ]
        )
    }

    // MARK: - Audit Inspection
    public func getAuditTrail() -> [[String: Any]] {
        return eventAuditLog
    }

    public func clearAuditTrail() {
        eventAuditLog.removeAll()
    }
}
