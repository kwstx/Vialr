import Vapor
import JWT
import Fluent

/// Middleware enforcing mandatory JWT authentication across protected route collections.
/// Automatically rejects missing, expired, or tampered tokens with HTTP 401 Unauthorized.
public struct AuthenticationGuardMiddleware: AsyncMiddleware {
    public init() {}

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let payload = request.auth.get(UserPayload.self) else {
            throw Abort(.unauthorized, reason: "Authentication required. Please provide a valid Bearer token in the Authorization header.")
        }
        // Ensure expiration is verified
        try payload.expiration.verifyNotExpired()
        return try await next.respond(to: request)
    }
}

/// Type-safe Security Context accessor extensions on Vapor's `Request`.
public extension Request {
    /// Returns the verified UserPayload for the current request, or nil if unauthenticated.
    var securityContext: UserPayload? {
        self.auth.get(UserPayload.self)
    }

    /// Returns the authenticated User ID or throws HTTP 401 Unauthorized.
    var authenticatedUserId: UUID {
        get throws {
            guard let payload = self.auth.get(UserPayload.self) else {
                throw Abort(.unauthorized, reason: "Authentication credentials missing or invalid.")
            }
            return payload.userId
        }
    }

    /// Requires an authenticated UserPayload, throwing 401 Unauthorized if absent.
    func requireAuthenticatedUser() throws -> UserPayload {
        guard let payload = self.auth.get(UserPayload.self) else {
            throw Abort(.unauthorized, reason: "Authentication credentials missing or invalid.")
        }
        return payload
    }

    /// Requires that the authenticated user possesses administrative privileges (`admin`).
    func requireAdmin() throws -> UserPayload {
        let payload = try requireAuthenticatedUser()
        guard payload.role == UserRole.admin.rawValue || payload.role == "admin" else {
            throw Abort(.forbidden, reason: "Administrative privileges required to access this resource.")
        }
        return payload
    }

    /// Returns the user's role if authenticated.
    func currentUserRole() -> UserRole {
        guard let payload = self.securityContext else { return .user }
        return UserRole(rawValue: payload.role) ?? .user
    }
}
