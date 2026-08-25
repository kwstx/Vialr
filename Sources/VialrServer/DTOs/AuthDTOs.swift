import Vapor
import JWT

public struct RegisterRequest: Content {
    public let email: String
    public let password: String
    public let displayName: String
}

public struct LoginRequest: Content {
    public let email: String
    public let password: String
}

public struct AuthResponse: Content {
    public let token: String
    public let userId: UUID
    public let email: String
    public let displayName: String
}

public struct UserProfileDTO: Content {
    public let id: UUID
    public let email: String
    public let displayName: String
    public let createdAt: Date?
}

public struct UserPayload: JWTPayload, Authenticatable {
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
