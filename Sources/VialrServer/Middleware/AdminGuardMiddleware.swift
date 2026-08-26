import Vapor
import Fluent

/// Middleware restricting route access strictly to users possessing the `admin` role.
/// Rejects unauthorized or non-admin requests with HTTP 403 Forbidden.
public struct AdminGuardMiddleware: AsyncMiddleware {
    public init() {}

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let payload = request.auth.get(UserPayload.self) else {
            throw Abort(.unauthorized, reason: "Authentication credentials missing or invalid.")
        }

        let userRole = UserRole(rawValue: payload.role) ?? .user
        guard userRole.isAdministrative else {
            // Log security denial event
            request.logger.warning("[Security] Unauthorized administrative access attempt by user: \(payload.userId), email: \(payload.email), role: \(payload.role), path: \(request.url.path)")
            throw Abort(.forbidden, reason: "Access denied: Administrative privileges required.")
        }

        return try await next.respond(to: request)
    }
}

/// Generic role authorization guard for multi-role routes.
public struct RoleGuardMiddleware: AsyncMiddleware {
    private let allowedRoles: Set<UserRole>

    public init(allowedRoles: [UserRole]) {
        self.allowedRoles = Set(allowedRoles)
    }

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let payload = request.auth.get(UserPayload.self) else {
            throw Abort(.unauthorized, reason: "Authentication credentials missing or invalid.")
        }

        let userRole = UserRole(rawValue: payload.role) ?? .user
        guard allowedRoles.contains(userRole) else {
            request.logger.warning("[Security] Access denied for user: \(payload.userId), role: \(payload.role). Required one of: \(self.allowedRoles.map { $0.rawValue })")
            throw Abort(.forbidden, reason: "Access denied: Insufficient permissions for this action.")
        }

        return try await next.respond(to: request)
    }
}
