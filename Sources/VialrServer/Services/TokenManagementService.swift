import Vapor
import Fluent
import JWT
import Domain
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// Comprehensive token management service issuing short-lived access tokens,
/// managing rotating refresh tokens, and enforcing single-use refresh token rotation with replay detection.
public struct TokenManagementService: Sendable {
    public let accessTokenLifetimeMinutes: Int
    public let refreshTokenLifetimeDays: Int

    public init(
        accessTokenLifetimeMinutes: Int = 15,
        refreshTokenLifetimeDays: Int = 60
    ) {
        self.accessTokenLifetimeMinutes = accessTokenLifetimeMinutes
        self.refreshTokenLifetimeDays = refreshTokenLifetimeDays
    }

    /// Issues a new authentication credential pair (short-lived access token + new refresh token family).
    public func issueTokenPair(
        for user: UserEntity,
        deviceInfo: String? = nil,
        req: Request
    ) async throws -> AuthResponse {
        guard let userId = user.id else {
            throw Abort(.internalServerError, reason: "User ID missing for token generation.")
        }

        // 1. Generate short-lived JWT access token (15 minutes)
        let payload = UserPayload(userId: userId, email: user.email, expirationMinutes: accessTokenLifetimeMinutes)
        let accessToken = try req.jwt.sign(payload)

        // 2. Generate cryptographically secure random refresh token string
        let rawRefreshToken = generateSecureToken()
        let tokenHash = hashToken(rawRefreshToken)

        // 3. Persist hashed refresh token record with a new family ID
        let familyId = UUID()
        let expiresAt = Date().addingTimeInterval(TimeInterval(refreshTokenLifetimeDays * 24 * 60 * 60))
        let refreshTokenEntity = RefreshTokenEntity(
            userId: userId,
            tokenHash: tokenHash,
            familyId: familyId,
            isRevoked: false,
            expiresAt: expiresAt,
            deviceInfo: deviceInfo
        )
        try await refreshTokenEntity.save(on: req.db)

        return AuthResponse(
            accessToken: accessToken,
            refreshToken: rawRefreshToken,
            tokenType: "Bearer",
            expiresIn: accessTokenLifetimeMinutes * 60,
            userId: userId,
            email: user.email,
            displayName: user.displayName,
            expiresAt: payload.expiration.value
        )
    }

    /// Rotates a refresh token: invalidates the old token, issues a new short-lived access token + new refresh token in the same family.
    /// If an already revoked token is used (Replay Attack / Token Theft), immediately revokes all tokens in the entire family.
    public func rotateRefreshToken(
        rawRefreshToken: String,
        deviceInfo: String? = nil,
        req: Request
    ) async throws -> AuthResponse {
        let tokenHash = hashToken(rawRefreshToken)

        // Find refresh token entity
        guard let tokenRecord = try await RefreshTokenEntity.query(on: req.db)
            .filter(\.$tokenHash == tokenHash)
            .with(\.$user)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid refresh token.")
        }

        let familyId = tokenRecord.familyId
        let userId = tokenRecord.$user.id

        // REPLAY ATTACK DETECTION:
        // If the token is already revoked, an attacker or compromised client is attempting to reuse an expired token.
        if tokenRecord.isRevoked {
            // Revoke all tokens in this family immediately!
            try await RefreshTokenEntity.query(on: req.db)
                .filter(\.$familyId == familyId)
                .set(\.$isRevoked, to: true)
                .update()

            req.logger.warning("[TokenManagement] Replay attack detected for user \(userId), family \(familyId). Revoked entire token family.")
            throw Abort(.unauthorized, reason: "Invalid authentication session. Please sign in again.")
        }

        // Check if token has expired
        guard tokenRecord.expiresAt > Date() else {
            tokenRecord.isRevoked = true
            try await tokenRecord.save(on: req.db)
            throw Abort(.unauthorized, reason: "Refresh token has expired. Please sign in again.")
        }

        // Invalidate current refresh token
        tokenRecord.isRevoked = true
        try await tokenRecord.save(on: req.db)

        // Generate new short-lived access token
        let user = tokenRecord.user
        let payload = UserPayload(userId: userId, email: user.email, expirationMinutes: accessTokenLifetimeMinutes)
        let newAccessToken = try req.jwt.sign(payload)

        // Generate and persist new rotating refresh token in the same family
        let newRawRefreshToken = generateSecureToken()
        let newTokenHash = hashToken(newRawRefreshToken)
        let expiresAt = Date().addingTimeInterval(TimeInterval(refreshTokenLifetimeDays * 24 * 60 * 60))

        let newRecord = RefreshTokenEntity(
            userId: userId,
            tokenHash: newTokenHash,
            familyId: familyId,
            isRevoked: false,
            expiresAt: expiresAt,
            deviceInfo: deviceInfo ?? tokenRecord.deviceInfo
        )
        try await newRecord.save(on: req.db)

        return AuthResponse(
            accessToken: newAccessToken,
            refreshToken: newRawRefreshToken,
            tokenType: "Bearer",
            expiresIn: accessTokenLifetimeMinutes * 60,
            userId: userId,
            email: user.email,
            displayName: user.displayName,
            expiresAt: payload.expiration.value
        )
    }

    /// Revokes a specific refresh token upon logout.
    public func revokeRefreshToken(rawRefreshToken: String, req: Request) async throws {
        let tokenHash = hashToken(rawRefreshToken)
        if let record = try await RefreshTokenEntity.query(on: req.db)
            .filter(\.$tokenHash == tokenHash)
            .first() {
            record.isRevoked = true
            try await record.save(on: req.db)
        }
    }

    /// Revokes all active refresh tokens for a user (e.g. password change, account security reset).
    public func revokeAllUserTokens(userId: UUID, req: Request) async throws {
        try await RefreshTokenEntity.query(on: req.db)
            .filter(\.$user.$id == userId)
            .set(\.$isRevoked, to: true)
            .update()
    }

    // MARK: - Cryptographic Helpers
    public func generateSecureToken(byteLength: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: byteLength)
        #if canImport(CryptoKit)
        let _ = SecRandomCopyBytes(kSecRandomDefault, byteLength, &bytes)
        #endif
        // If empty or random failed, use UUID fallback + random
        let rawData = Data(bytes)
        let base64 = rawData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64.isEmpty ? UUID().uuidString : base64
    }

    public func hashToken(_ token: String) -> String {
        let data = Data(token.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
