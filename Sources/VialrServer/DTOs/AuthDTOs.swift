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

public struct AppleSignInRequest: Content, Sendable {
    public let identityToken: String
    public let authorizationCode: String
    public let userIdentifier: String
    public let email: String?
    public let fullName: String?
    public let nonce: String?

    public init(
        identityToken: String,
        authorizationCode: String,
        userIdentifier: String,
        email: String? = nil,
        fullName: String? = nil,
        nonce: String? = nil
    ) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.userIdentifier = userIdentifier
        self.email = email
        self.fullName = fullName
        self.nonce = nonce
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

public struct LogoutRequest: Content, Sendable {
    public let refreshToken: String?

    public init(refreshToken: String? = nil) {
        self.refreshToken = refreshToken
    }
}

/// Unified authentication response delivering short-lived JWT access credentials and rotating refresh tokens.
public struct AuthResponse: Content, Sendable {
    public let token: String // Alias to accessToken for backwards compatibility
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let expiresIn: Int // 900 seconds (15 mins)
    public let userId: UUID
    public let email: String
    public let displayName: String
    public let role: String
    public let expiresAt: Date

    public init(
        accessToken: String,
        refreshToken: String,
        tokenType: String = "Bearer",
        expiresIn: Int = 900,
        userId: UUID,
        email: String,
        displayName: String,
        role: String = "user",
        expiresAt: Date? = nil
    ) {
        self.token = accessToken
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.role = role
        self.expiresAt = expiresAt ?? Date().addingTimeInterval(TimeInterval(expiresIn))
    }

    public init(token: String, userId: UUID, email: String, displayName: String, role: String = "user", expiresAt: Date = Date().addingTimeInterval(900)) {
        self.token = token
        self.accessToken = token
        self.refreshToken = UUID().uuidString
        self.tokenType = "Bearer"
        self.expiresIn = 900
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.role = role
        self.expiresAt = expiresAt
    }
}

/// Short-lived JWT Access Token payload (15-minute standard expiration).
public struct UserPayload: JWTPayload, Authenticatable, Sendable {
    public var expiration: ExpirationClaim
    public var issuer: IssuerClaim
    public var subject: SubjectClaim
    public var userId: UUID
    public var email: String
    public var role: String

    public init(
        userId: UUID,
        email: String,
        role: String = "user",
        expirationMinutes: Int = 15
    ) {
        self.userId = userId
        self.email = email
        self.role = role
        self.subject = SubjectClaim(value: userId.uuidString)
        self.issuer = IssuerClaim(value: "https://api.vialr.app")
        // Short-lived access token: 15 minutes
        self.expiration = ExpirationClaim(value: Date().addingTimeInterval(TimeInterval(expirationMinutes * 60)))
    }

    public func verify(using algorithm: some JWTAlgorithm) throws {
        try self.expiration.verifyNotExpired()
    }
}
