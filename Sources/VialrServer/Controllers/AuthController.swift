import Vapor
import Fluent
import JWT

public struct AuthController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let authGroup = routes.grouped("auth")
        authGroup.post("register", use: register)
        authGroup.post("login", use: login)
        authGroup.post("refresh", use: refreshToken)

        let protected = authGroup.grouped(UserAuthenticator(), UserPayload.guardMiddleware())
        protected.get("profile", use: profile)
        protected.post("password", use: changePassword)
    }

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

        guard let userId = user.id else {
            throw Abort(.internalServerError, reason: "Failed to persist user.")
        }

        let payload = UserPayload(userId: userId, email: user.email)
        let token = try req.jwt.sign(payload)

        return AuthResponse(
            token: token,
            userId: userId,
            email: user.email,
            displayName: user.displayName
        )
    }

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

        guard let userId = user.id else {
            throw Abort(.internalServerError)
        }

        let payload = UserPayload(userId: userId, email: user.email)
        let token = try req.jwt.sign(payload)

        return AuthResponse(
            token: token,
            userId: userId,
            email: user.email,
            displayName: user.displayName
        )
    }

    public func refreshToken(req: Request) async throws -> AuthResponse {
        let refreshReq = try req.content.decode(RefreshTokenRequest.self)
        let payload = try req.jwt.verify(refreshReq.refreshToken, as: UserPayload.self)

        guard let user = try await UserEntity.find(payload.userId, on: req.db) else {
            throw Abort(.unauthorized, reason: "User associated with token no longer exists.")
        }

        let newPayload = UserPayload(userId: payload.userId, email: user.email)
        let newToken = try req.jwt.sign(newPayload)

        return AuthResponse(
            token: newToken,
            userId: payload.userId,
            email: user.email,
            displayName: user.displayName
        )
    }

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

        return .ok
    }

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
