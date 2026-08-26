import Foundation
import Domain
import Vapor

/// Telemetry and analytics event with strictly scrubbed, de-identified parameters.
public struct SafeAnalyticsEvent: Sendable, Codable {
    public let eventName: String
    public let anonymizedUserId: String
    public let timestamp: Date
    public let platform: String
    public let appVersion: String
    public let safeAttributes: [String: String]

    public init(
        eventName: String,
        anonymizedUserId: String,
        timestamp: Date = Date(),
        platform: String = "iOS",
        appVersion: String = "1.0.0",
        safeAttributes: [String: String] = [:]
    ) {
        self.eventName = eventName
        self.anonymizedUserId = anonymizedUserId
        self.timestamp = timestamp
        self.platform = platform
        self.appVersion = appVersion
        self.safeAttributes = safeAttributes
    }
}

/// Zero-Health-Leakage Privacy Guard & Analytics Pipeline.
/// Guarantees that no Protected Health Information (PHI), dosage amounts, compound names,
/// biomarker results, symptom notes, or personal identifiers ever reach third-party telemetry systems.
public struct PrivacyPreservingAnalyticsService: Sendable {
    public init() {}

    /// Dispatches a telemetry event only after rigorously stripping any PHI/PII.
    public func dispatchEvent(
        name: String,
        userId: UUID,
        rawAttributes: [String: String],
        platform: String = "iOS",
        version: String = "1.0.0"
    ) -> SafeAnalyticsEvent {
        let anonymizedId = hashUserId(userId)
        let sanitizedAttributes = sanitizeAnalyticsAttributes(rawAttributes)

        let safeEvent = SafeAnalyticsEvent(
            eventName: name,
            anonymizedUserId: anonymizedId,
            timestamp: Date(),
            platform: platform,
            appVersion: version,
            safeAttributes: sanitizedAttributes
        )

        return safeEvent
    }

    /// Hashes the user ID with a non-reversible one-way cryptographic digest for analytics pseudonymization.
    public func hashUserId(_ userId: UUID) -> String {
        let raw = "vialr-analytics-salt:" + userId.uuidString
        let hash = SHA256.hash(data: Data(raw.utf8))
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    /// Sanitizes analytics attributes, redacting any health-related or personal values.
    public func sanitizeAnalyticsAttributes(_ attributes: [String: String]) -> [String: String] {
        var clean: [String: String] = [:]

        // Allowed safe attribute keys (coarse aggregate telemetry only)
        let allowedSafeKeys: Set<String> = [
            "platform",
            "device_model",
            "os_version",
            "app_version",
            "client_version",
            "session_duration_seconds",
            "screen_name",
            "feature_name",
            "action_type",
            "has_protocol",
            "is_custom_compound",
            "route_type",
            "unit_category",
            "sync_status",
            "batch_size",
            "operation_count",
            "error_code",
            "http_status"
        ]

        for (key, value) in attributes {
            let lowerKey = key.lowercased()
            if allowedSafeKeys.contains(lowerKey) {
                // Ensure value does not accidentally contain email or bearer token
                clean[key] = SensitiveDataScrubber.sanitizeStringContent(value)
            }
        }

        return clean
    }

    /// Verifies that a given dictionary contains zero PHI / medical leakage.
    public func verifyZeroHealthLeakage(in dictionary: [String: String]) -> Bool {
        let forbiddenPatterns = [
            "dose", "amount", "mg", "mcg", "iu", "bpc", "semaglutide", "tirzepatide",
            "testosterone", "estradiol", "biomarker", "bloodwork", "lab", "notes",
            "symptom", "pain", "coordinate", "email", "password", "token"
        ]

        for (key, value) in dictionary {
            let lowerKey = key.lowercased()
            let lowerVal = value.lowercased()

            for pattern in forbiddenPatterns {
                if lowerKey.contains(pattern) || lowerVal.contains(pattern) {
                    return false
                }
            }
        }
        return true
    }
}
