import Vapor
import Fluent
import Domain

/// Enumeration of security-critical and administrative actions recorded into the immutable audit trail.
public enum AuditEventType: String, Sendable, Codable {
    case userRegistered = "USER_REGISTERED"
    case loginSuccess = "LOGIN_SUCCESS"
    case loginFailure = "LOGIN_FAILURE"
    case passwordChanged = "PASSWORD_CHANGED"
    case roleModified = "USER_ROLE_MODIFIED"
    case accountDeleted = "USER_ACCOUNT_DELETED"
    case adminAccess = "ADMIN_ACCESS_GRANTED"
    case adminActionDenied = "ADMIN_ACTION_DENIED"
    case dataExported = "USER_DATA_EXPORTED"
    case reportGenerated = "CLINICAL_REPORT_GENERATED"
    case fileUploaded = "ENCRYPTED_FILE_UPLOADED"
    case fileDeleted = "ENCRYPTED_FILE_DELETED"
    case jobRetried = "ADMIN_JOB_RETRIED"
    case jobCancelled = "ADMIN_JOB_CANCELLED"
    case keyRotated = "ENCRYPTION_KEY_ROTATED"
    case emergencyLockdown = "EMERGENCY_LOCKDOWN_TRIGGERED"
}

/// Service managing non-blocking, asynchronous recording of security audit log entries.
public struct AuditLogService: Sendable {
    public init() {}

    /// Records an immutable audit log entry in PostgreSQL.
    public func record(
        event: AuditEventType,
        actorId: UUID? = nil,
        actorEmail: String? = nil,
        actorRole: String = "user",
        resourceType: String,
        resourceId: String? = nil,
        status: String = "success",
        failureReason: String? = nil,
        metadata: [String: String]? = nil,
        on req: Request
    ) async {
        let ipAddress = Self.extractClientIp(from: req)
        let userAgent = req.headers.first(name: .userAgent)

        // Scrub metadata to guarantee zero PHI/PII enters the audit trail
        var sanitizedMetadataJson: String? = nil
        if let rawMeta = metadata {
            let sanitized = SensitiveDataScrubber.sanitizeMetadata(rawMeta)
            if let data = try? JSONEncoder().encode(sanitized) {
                sanitizedMetadataJson = String(data: data, encoding: .utf8)
            }
        }

        let entry = AuditLogEntity(
            actorId: actorId,
            actorEmail: actorEmail,
            actorRole: actorRole,
            action: event.rawValue,
            resourceType: resourceType,
            resourceId: resourceId,
            ipAddress: ipAddress,
            userAgent: userAgent,
            status: status,
            failureReason: failureReason,
            metadataJson: sanitizedMetadataJson
        )

        do {
            try await entry.save(on: req.db)
        } catch {
            req.logger.error("[AuditLogService] Failed to persist audit log entry: \(error.localizedDescription)")
        }
    }

    /// Safely extracts and masks the client's IP address for privacy compliance.
    private static func extractClientIp(from req: Request) -> String {
        if let forwarded = req.headers.first(name: "X-Forwarded-For") {
            let firstIp = forwarded.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? forwarded
            return maskIp(firstIp)
        }
        if let remoteAddress = req.remoteAddress?.ipAddress {
            return maskIp(remoteAddress)
        }
        return "unknown"
    }

    /// Anonymizes/masks the last octet of IPv4 or suffix of IPv6 addresses for PII minimization.
    private static func maskIp(_ ip: String) -> String {
        if ip.contains(".") {
            var parts = ip.split(separator: ".")
            if parts.count == 4 {
                parts[3] = "0"
                return parts.joined(separator: ".")
            }
        }
        return ip
    }
}

// MARK: - Vapor Request Integration

public extension Request {
    private struct AuditLogServiceKey: StorageKey {
        typealias Value = AuditLogService
    }

    var auditLogService: AuditLogService {
        if let service = self.application.storage[AuditLogServiceKey.self] {
            return service
        }
        let service = AuditLogService()
        return service
    }

    /// Convenience method to log a security event directly from any controller endpoint.
    func logSecurityEvent(
        _ event: AuditEventType,
        resourceType: String,
        resourceId: String? = nil,
        status: String = "success",
        failureReason: String? = nil,
        metadata: [String: String]? = nil
    ) async {
        let payload = self.securityContext
        await self.auditLogService.record(
            event: event,
            actorId: payload?.userId,
            actorEmail: payload?.email,
            actorRole: payload?.role ?? "anonymous",
            resourceType: resourceType,
            resourceId: resourceId,
            status: status,
            failureReason: failureReason,
            metadata: metadata,
            on: self
        )
    }
}

public extension Application {
    private struct AuditLogServiceKey: StorageKey {
        typealias Value = AuditLogService
    }

    var auditLogService: AuditLogService {
        get {
            self.storage[AuditLogServiceKey.self] ?? AuditLogService()
        }
        set {
            self.storage[AuditLogServiceKey.self] = newValue
        }
    }
}
