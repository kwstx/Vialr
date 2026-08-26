import Vapor
import Fluent
import Domain

/// Administrative Controller restricting management operations strictly to authenticated users with `admin` role.
/// Maintains comprehensive audit trails for every administrative query and mutation.
public struct AdminController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let adminGroup = routes.grouped("admin")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware(), AdminGuardMiddleware())

        // User Lifecycle & Role Management
        adminGroup.get("users", use: listUsers)
        adminGroup.put("users", ":userId", "role", use: updateUserRole)

        // Forensic Security Audit Trails
        adminGroup.get("audit-logs", use: listAuditLogs)

        // Security Diagnostics & Emergency Controls
        adminGroup.get("system-security", use: getSystemSecurityStatus)
        adminGroup.post("emergency-lockdown", use: triggerEmergencyLockdown)
    }

    // MARK: - 1. List Users (Admin Only)
    public func listUsers(req: Request) async throws -> [AdminUserListItemDTO] {
        let payload = try req.requireAdmin()
        await req.logSecurityEvent(.adminAccess, resourceType: "UserList", metadata: ["caller": payload.email])

        let users = try await UserEntity.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .range(0..<100)
            .all()

        return users.map { u in
            AdminUserListItemDTO(
                id: u.id ?? UUID(),
                email: u.email,
                displayName: u.displayName,
                role: u.role,
                tier: u.tier,
                status: u.status,
                createdAt: u.createdAt
            )
        }
    }

    // MARK: - 2. Update User RBAC Role
    public func updateUserRole(req: Request) async throws -> AdminUserListItemDTO {
        let adminPayload = try req.requireAdmin()
        guard let targetUserId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Valid target user ID is required.")
        }

        let input = try req.content.decode(UpdateUserRoleRequestDTO.self)
        guard let newRole = UserRole(rawValue: input.role) else {
            throw Abort(.badRequest, reason: "Invalid role. Supported: \(UserRole.allCases.map { $0.rawValue }.joined(separator: ", "))")
        }

        guard let targetUser = try await UserEntity.find(targetUserId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        let oldRole = targetUser.role
        targetUser.role = newRole.rawValue
        try await targetUser.save(on: req.db)

        // Record security audit trail
        await req.logSecurityEvent(
            .roleModified,
            resourceType: "User",
            resourceId: targetUserId.uuidString,
            metadata: [
                "adminId": adminPayload.userId.uuidString,
                "adminEmail": adminPayload.email,
                "targetEmail": targetUser.email,
                "previousRole": oldRole,
                "newRole": newRole.rawValue
            ]
        )

        return AdminUserListItemDTO(
            id: targetUser.id ?? targetUserId,
            email: targetUser.email,
            displayName: targetUser.displayName,
            role: targetUser.role,
            tier: targetUser.tier,
            status: targetUser.status,
            createdAt: targetUser.createdAt
        )
    }

    // MARK: - 3. Forensic Audit Log Queries
    public func listAuditLogs(req: Request) async throws -> [AuditLogDTO] {
        let payload = try req.requireAdmin()
        let queryFilter = try req.query.decode(AuditLogFilterQueryDTO.self)

        var query = AuditLogEntity.query(on: req.db)

        if let actorId = queryFilter.actorId {
            query = query.filter(\.$actor.$id == actorId)
        }
        if let action = queryFilter.action, !action.isEmpty {
            query = query.filter(\.$action == action)
        }
        if let resType = queryFilter.resourceType, !resType.isEmpty {
            query = query.filter(\.$resourceType == resType)
        }
        if let status = queryFilter.status, !status.isEmpty {
            query = query.filter(\.$status == status)
        }

        let limit = min(queryFilter.limit ?? 50, 200)
        let offset = queryFilter.offset ?? 0

        let entities = try await query
            .sort(\.$createdAt, .descending)
            .range(offset..<(offset + limit))
            .all()

        await req.logSecurityEvent(
            .adminAccess,
            resourceType: "AuditLogs",
            metadata: ["recordsReturned": "\(entities.count)", "adminEmail": payload.email]
        )

        return entities.map { AuditLogDTO(from: $0) }
    }

    // MARK: - 4. System Security Status
    public func getSystemSecurityStatus(req: Request) async throws -> SystemSecurityStatusDTO {
        let payload = try req.requireAdmin()
        let totalAudits = try await AuditLogEntity.query(on: req.db).count()

        await req.logSecurityEvent(.adminAccess, resourceType: "SystemSecurityStatus", metadata: ["adminEmail": payload.email])

        return SystemSecurityStatusDTO(
            securityStatus: "operational",
            totalAuditEventsCount: totalAudits,
            encryptionAtRestVersion: "AES-256-GCM (enc:v2)",
            encryptionInTransitEnforced: true,
            zeroTrustAuthenticationEnforced: true,
            timestamp: Date()
        )
    }

    // MARK: - 5. Emergency Lockdown
    public func triggerEmergencyLockdown(req: Request) async throws -> [String: String] {
        let adminPayload = try req.requireAdmin()

        // Invalidate all refresh tokens system-wide
        try await RefreshTokenEntity.query(on: req.db)
            .set(\.$isRevoked, to: true)
            .update()

        await req.logSecurityEvent(
            .emergencyLockdown,
            resourceType: "System",
            status: "success",
            metadata: [
                "initiatedBy": adminPayload.email,
                "reason": "Administrative emergency session revocation"
            ]
        )

        return [
            "status": "lockdown_complete",
            "message": "All active user refresh token sessions have been revoked. Users must re-authenticate.",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
    }
}
