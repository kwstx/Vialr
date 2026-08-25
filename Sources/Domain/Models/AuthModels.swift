import Foundation

// MARK: - Authentication Token Credentials
/// Encapsulates short-lived JWT access tokens and long-lived rotating refresh tokens.
public struct AuthTokens: Codable, Sendable, Hashable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let expiresIn: Int // Lifetime in seconds (e.g. 900 for 15 mins)
    public let issuedAt: Date

    public init(
        accessToken: String,
        refreshToken: String,
        tokenType: String = "Bearer",
        expiresIn: Int = 900,
        issuedAt: Date = Date()
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.issuedAt = issuedAt
    }

    /// Determines if the access token has expired (with a 30-second clock skew buffer).
    public var isExpired: Bool {
        let expirationDate = issuedAt.addingTimeInterval(TimeInterval(expiresIn - 30))
        return Date() >= expirationDate
    }
}

// MARK: - Authenticated User Session
public struct AuthSession: Codable, Sendable, Hashable {
    public let userId: UUID
    public let email: String
    public let displayName: String
    public let tokens: AuthTokens
    public let lastAuthenticatedAt: Date

    public init(
        userId: UUID,
        email: String,
        displayName: String,
        tokens: AuthTokens,
        lastAuthenticatedAt: Date = Date()
    ) {
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.tokens = tokens
        self.lastAuthenticatedAt = lastAuthenticatedAt
    }
}

// MARK: - Sign in with Apple Payloads
public struct AppleAuthPayload: Codable, Sendable {
    public let identityToken: String
    public let authorizationCode: String
    public let userIdentifier: String
    public let email: String?
    public let fullName: String?
    public let nonce: String

    public init(
        identityToken: String,
        authorizationCode: String,
        userIdentifier: String,
        email: String? = nil,
        fullName: String? = nil,
        nonce: String
    ) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.userIdentifier = userIdentifier
        self.email = email
        self.fullName = fullName
        self.nonce = nonce
    }
}

// MARK: - Biometric Security Types
public enum BiometricType: String, Codable, Sendable, CaseIterable {
    case none = "None"
    case touchID = "Touch ID"
    case faceID = "Face ID"
    case opticID = "Optic ID"

    public var iconName: String {
        switch self {
        case .none: return "lock.fill"
        case .touchID: return "touchid"
        case .faceID: return "faceid"
        case .opticID: return "opticid"
        }
    }
}

public enum BiometricUnlockStatus: Sendable, Equatable {
    case unlocked
    case locked
    case notEnrolled
    case failed(String)
}

// MARK: - Keychain Security Access Levels
public enum KeychainAccessLevel: Sendable {
    /// Item is accessible only after the device has been unlocked once after booting. (Recommended for background sync tokens)
    case afterFirstUnlockThisDeviceOnly
    /// Item is accessible only while the device is actively unlocked by the user.
    case whenUnlockedThisDeviceOnly
    /// Item is accessible only when device passcode / biometrics are active.
    case whenPasscodeSetThisDeviceOnly
}

// MARK: - Keychain Errors
public enum KeychainError: Error, LocalizedError, Sendable {
    case itemNotFound
    case duplicateItem
    case unexpectedDataFormat
    case unhandledError(status: Int32)

    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in iOS Keychain."
        case .duplicateItem:
            return "Item already exists in iOS Keychain."
        case .unexpectedDataFormat:
            return "Encountered unexpected data format in iOS Keychain."
        case .unhandledError(let status):
            return "iOS Keychain operation failed with OSStatus code: \(status)."
        }
    }
}
