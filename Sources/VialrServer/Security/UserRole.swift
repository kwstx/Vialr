import Foundation

/// Role-Based Access Control (RBAC) user roles supported across the Vialr backend.
public enum UserRole: String, Codable, Sendable, CaseIterable {
    /// Standard mobile app user with access to their own data.
    case user = "user"
    /// Verified medical clinician with clinical review capabilities.
    case clinician = "clinician"
    /// System administrator with access to diagnostics, queue management, and system metrics.
    case admin = "admin"
    /// Security auditor with read-only access to audit logs and forensic events.
    case systemAuditor = "system_auditor"

    public var isAdministrative: Bool {
        switch self {
        case .admin:
            return true
        default:
            return false
        }
    }

    public var canAccessAuditLogs: Bool {
        switch self {
        case .admin, .systemAuditor:
            return true
        default:
            return false
        }
    }

    public var canAccessSystemObservability: Bool {
        switch self {
        case .admin, .systemAuditor:
            return true
        default:
            return false
        }
    }

    public var canManageUserRoles: Bool {
        switch self {
        case .admin:
            return true
        default:
            return false
        }
    }
}
