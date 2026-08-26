import Vapor

/// DTO representing an immutable security audit log entry.
public struct AuditLogDTO: Content, Sendable {
    public let id: UUID?
    public let actorId: UUID?
    public let actorEmail: String?
    public let actorRole: String
    public let action: String
    public let resourceType: String
    public let resourceId: String?
    public let ipAddress: String?
    public let userAgent: String?
    public let status: String
    public let failureReason: String?
    public let metadata: [String: String]?
    public let createdAt: Date?

    public init(
        id: UUID?,
        actorId: UUID?,
        actorEmail: String?,
        actorRole: String,
        action: String,
        resourceType: String,
        resourceId: String?,
        ipAddress: String?,
        userAgent: String?,
        status: String,
        failureReason: String?,
        metadata: [String: String]?,
        createdAt: Date?
    ) {
        self.id = id
        self.actorId = actorId
        self.actorEmail = actorEmail
        self.actorRole = actorRole
        self.action = action
        self.resourceType = resourceType
        self.resourceId = resourceId
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.status = status
        self.failureReason = failureReason
        self.metadata = metadata
        self.createdAt = createdAt
    }

    public init(from entity: AuditLogEntity) {
        var meta: [String: String]? = nil
        if let json = entity.metadataJson, let data = json.data(using: .utf8) {
            meta = try? JSONDecoder().decode([String: String].self, from: data)
        }
        self.init(
            id: entity.id,
            actorId: entity.$actor.id,
            actorEmail: entity.actorEmail,
            actorRole: entity.actorRole,
            action: entity.action,
            resourceType: entity.resourceType,
            resourceId: entity.resourceId,
            ipAddress: entity.ipAddress,
            userAgent: entity.userAgent,
            status: entity.status,
            failureReason: entity.failureReason,
            metadata: meta,
            createdAt: entity.createdAt
        )
    }
}

/// Query parameters for forensic audit log filtering.
public struct AuditLogFilterQueryDTO: Content, Sendable {
    public let actorId: UUID?
    public let action: String?
    public let resourceType: String?
    public let status: String?
    public let limit: Int?
    public let offset: Int?

    public init(
        actorId: UUID? = nil,
        action: String? = nil,
        resourceType: String? = nil,
        status: String? = nil,
        limit: Int? = 50,
        offset: Int? = 0
    ) {
        self.actorId = actorId
        self.action = action
        self.resourceType = resourceType
        self.status = status
        self.limit = limit
        self.offset = offset
    }
}

/// Admin view of a registered user.
public struct AdminUserListItemDTO: Content, Sendable {
    public let id: UUID
    public let email: String
    public let displayName: String
    public let role: String
    public let tier: String
    public let status: String
    public let createdAt: Date?

    public init(id: UUID, email: String, displayName: String, role: String, tier: String, status: String, createdAt: Date?) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.role = role
        self.tier = tier
        self.status = status
        self.createdAt = createdAt
    }
}

/// Request to alter a user's RBAC role.
public struct UpdateUserRoleRequestDTO: Content, Sendable {
    public let role: String

    public init(role: String) {
        self.role = role
    }
}

/// Summary report of security subsystem health and metrics.
public struct SystemSecurityStatusDTO: Content, Sendable {
    public let securityStatus: String
    public let totalAuditEventsCount: Int
    public let encryptionAtRestVersion: String
    public let encryptionInTransitEnforced: Bool
    public let zeroTrustAuthenticationEnforced: Bool
    public let timestamp: Date

    public init(
        securityStatus: String = "operational",
        totalAuditEventsCount: Int,
        encryptionAtRestVersion: String = "AES-256-GCM (enc:v2)",
        encryptionInTransitEnforced: Bool = true,
        zeroTrustAuthenticationEnforced: Bool = true,
        timestamp: Date = Date()
    ) {
        self.securityStatus = securityStatus
        self.totalAuditEventsCount = totalAuditEventsCount
        self.encryptionAtRestVersion = encryptionAtRestVersion
        self.encryptionInTransitEnforced = encryptionInTransitEnforced
        self.zeroTrustAuthenticationEnforced = zeroTrustAuthenticationEnforced
        self.timestamp = timestamp
    }
}
