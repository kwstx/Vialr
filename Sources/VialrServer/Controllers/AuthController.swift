import Vapor
import Fluent
import JWT
import Domain

public struct AuthController: RouteCollection {
    private let tokenService = TokenManagementService(accessTokenLifetimeMinutes: 15, refreshTokenLifetimeDays: 60)
    private let appleAuthService = AppleAuthService()

    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let authGroup = routes.grouped("auth")
        authGroup.post("register", use: register)
        authGroup.post("login", use: login)
        authGroup.post("apple", use: appleSignIn)
        authGroup.post("refresh", use: refreshToken)
        authGroup.post("logout", use: logout)

        let protected = authGroup.grouped(UserAuthenticator(), UserPayload.guardMiddleware())
        protected.get("profile", use: profile)
        protected.post("password", use: changePassword)
    }

    // MARK: - Sign in with Apple (Primary Native Authentication)
    public func appleSignIn(req: Request) async throws -> AuthResponse {
        let body = try req.content.decode(AppleSignInRequest.self)

        // 1. Verify Apple Identity Token JWT & Nonce
        let verified = try appleAuthService.verifyAppleIdentityToken(
            token: body.identityToken,
            expectedUserIdentifier: body.userIdentifier,
            expectedNonce: body.nonce,
            req: req
        )

        // 2. Query user by Apple User Identifier or verified email
        var user = try await UserEntity.query(on: req.db)
            .filter(\.$appleUserIdentifier == verified.userIdentifier)
            .first()

        if user == nil, let verifiedEmail = verified.email ?? body.email {
            user = try await UserEntity.query(on: req.db)
                .filter(\.$email == verifiedEmail.lowercased())
                .first()
            if let existing = user {
                existing.appleUserIdentifier = verified.userIdentifier
                try await existing.save(on: req.db)
            }
        }

        // 3. Create user if new
        if user == nil {
            let email = verified.email ?? body.email ?? "\(verified.userIdentifier)@privaterelay.appleid.com"
            let displayName = body.fullName ?? "Apple Health Member"
            let randomSecret = try req.password.hash(UUID().uuidString)

            let newUser = UserEntity(
                email: email.lowercased(),
                passwordHash: randomSecret,
                appleUserIdentifier: verified.userIdentifier,
                displayName: displayName
            )
            try await newUser.save(on: req.db)
            user = newUser
        }

        guard let authenticatedUser = user else {
            throw Abort(.internalServerError, reason: "Failed to persist or load user account.")
        }

        let userAgent = req.headers.first(name: .userAgent)
        return try await tokenService.issueTokenPair(for: authenticatedUser, deviceInfo: userAgent, req: req)
    }

    // MARK: - Email Register
    public func register(req: Request) async throws -> AuthResponse {
        try RegisterRequest.validate(content: req)
        let body = try req.content.decode(RegisterRequest.self)

        // Check if user already exists
        if let _ = try await UserEntity.query(on: req.db)
            .filter(\.$email == body.email.lowercased())
            .first() {
            throw Abort(.conflict, reason: "An account with this email already exists.")
        }

        let passwordHash = try req.password.hash(body.password)
        let user = UserEntity(
            email: body.email.lowercased(),
            passwordHash: passwordHash,
            displayName: body.displayName
        )
        try await user.save(on: req.db)

        let userAgent = req.headers.first(name: .userAgent)
        return try await tokenService.issueTokenPair(for: user, deviceInfo: userAgent, req: req)
    }

    // MARK: - Email Login
    public func login(req: Request) async throws -> AuthResponse {
        let body = try req.content.decode(LoginRequest.self)

        guard let user = try await UserEntity.query(on: req.db)
            .filter(\.$email == body.email.lowercased())
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid email or password.")
        }

        let isPasswordValid = try req.password.verify(body.password, created: user.passwordHash)
        guard isPasswordValid else {
            throw Abort(.unauthorized, reason: "Invalid email or password.")
        }

        let userAgent = req.headers.first(name: .userAgent)
        return try await tokenService.issueTokenPair(for: user, deviceInfo: userAgent, req: req)
    }

    // MARK: - Rotating Refresh Token
    public func refreshToken(req: Request) async throws -> AuthResponse {
        let refreshReq = try req.content.decode(RefreshTokenRequest.self)
        let userAgent = req.headers.first(name: .userAgent)
        return try await tokenService.rotateRefreshToken(rawRefreshToken: refreshReq.refreshToken, deviceInfo: userAgent, req: req)
    }

    // MARK: - Logout & Revocation
    public func logout(req: Request) async throws -> HTTPStatus {
        if let body = try? req.content.decode(LogoutRequest.self), let refreshToken = body.refreshToken {
            try await tokenService.revokeRefreshToken(rawRefreshToken: refreshToken, req: req)
        }
        return .ok
    }

    // MARK: - Password Management
    public func changePassword(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        let body = try req.content.decode(ChangePasswordRequest.self)

        guard let user = try await UserEntity.find(payload.userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        let isCurrentValid = try req.password.verify(body.currentPassword, created: user.passwordHash)
        guard isCurrentValid else {
            throw Abort(.badRequest, reason: "Current password does not match.")
        }

        guard body.newPassword.count >= 6 else {
            throw Abort(.badRequest, reason: "New password must be at least 6 characters.")
        }

        user.passwordHash = try req.password.hash(body.newPassword)
        try await user.save(on: req.db)

        // Revoke all refresh tokens on password change
        try await tokenService.revokeAllUserTokens(userId: payload.userId, req: req)

        return .ok
    }

    // MARK: - User Profile
    public func profile(req: Request) async throws -> UserProfileDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await UserEntity.find(payload.userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        var prefsDTO: UserPreferencesDTO? = nil
        if let json = user.preferencesJson, let data = json.data(using: .utf8) {
            prefsDTO = try? JSONDecoder().decode(UserPreferencesDTO.self, from: data)
        }

        var unitsDTO: UnitPreferencesDTO? = nil
        if let json = user.unitsJson, let data = json.data(using: .utf8) {
            unitsDTO = try? JSONDecoder().decode(UnitPreferencesDTO.self, from: data)
        }

        var notifDTO: NotificationPreferencesDTO? = nil
        if let json = user.notificationsJson, let data = json.data(using: .utf8) {
            notifDTO = try? JSONDecoder().decode(NotificationPreferencesDTO.self, from: data)
        }

        return UserProfileDTO(
            id: user.id ?? payload.userId,
            email: user.email,
            displayName: user.displayName,
            avatarUrl: user.avatarUrl,
            phoneNumber: user.phoneNumber,
            tier: user.tier,
            status: user.status,
            timezone: user.timezone,
            preferences: prefsDTO,
            notificationPreferences: notifDTO,
            unitPreferences: unitsDTO,
            createdAt: user.createdAt
        )
    }
}

extension RegisterRequest: Validatable {
    public static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(6...))
        validations.add("displayName", as: String.self, is: !.empty)
    }
}
