import Vapor
import JWT

public struct RegisterRequest: Content, Sendable {
    public let email: String
    public let password: String
    public let displayName: String

    public init(email: String, password: String, displayName: String) {
        self.email = email
        self.password = password
        self.displayName = displayName
    }
}

public struct LoginRequest: Content, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct ChangePasswordRequest: Content, Sendable {
    public let currentPassword: String
    public let newPassword: String

    public init(currentPassword: String, newPassword: String) {
        self.currentPassword = currentPassword
        self.newPassword = newPassword
    }
}

public struct RefreshTokenRequest: Content, Sendable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

public struct AuthResponse: Content, Sendable {
    public let token: String
    public let userId: UUID
    public let email: String
    public let displayName: String
    public let expiresAt: Date

    public init(token: String, userId: UUID, email: String, displayName: String, expiresAt: Date = Date().addingTimeInterval(60 * 60 * 24 * 30)) {
        self.token = token
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.expiresAt = expiresAt
    }
}

public struct UserPayload: JWTPayload, Authenticatable, Sendable {
    public var expiration: ExpirationClaim
    public var userId: UUID
    public var email: String

    public init(userId: UUID, email: String) {
        self.userId = userId
        self.email = email
        // Token valid for 30 days
        self.expiration = ExpirationClaim(value: Date().addingTimeInterval(60 * 60 * 24 * 30))
    }

    public func verify(using algorithm: some JWTAlgorithm) throws {
        try self.expiration.verifyNotExpired()
    }
}
