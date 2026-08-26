import Vapor
import Fluent

public struct UsersController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let usersGroup = routes.grouped("users")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        usersGroup.get("me", use: getCurrentUser)
        usersGroup.put("profile", use: updateProfile)
        usersGroup.put("preferences", use: updatePreferences)
        usersGroup.put("units", use: updateUnits)
        usersGroup.put("notifications", use: updateNotificationPreferences)
        usersGroup.post("export", use: exportUserData)
        usersGroup.delete("account", use: deleteAccount)
    }

    public func getCurrentUser(req: Request) async throws -> UserProfileDTO {
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

    public func updateProfile(req: Request) async throws -> UserProfileDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await UserEntity.find(payload.userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        let updateReq = try req.content.decode(UpdateUserProfileRequestDTO.self)
        if let name = updateReq.displayName, !name.isEmpty {
            user.displayName = name
        }
        if let avatar = updateReq.avatarUrl {
            user.avatarUrl = avatar
        }
        if let phone = updateReq.phoneNumber {
            user.phoneNumber = phone
        }
        if let tz = updateReq.timezone, !tz.isEmpty {
            user.timezone = tz
        }

        try await user.save(on: req.db)
        return try await getCurrentUser(req: req)
    }

    public func updatePreferences(req: Request) async throws -> UserPreferencesDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await UserEntity.find(payload.userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        let prefs = try req.content.decode(UserPreferencesDTO.self)
        let data = try JSONEncoder().encode(prefs)
        user.preferencesJson = String(data: data, encoding: .utf8)
        try await user.save(on: req.db)

        return prefs
    }

    public func updateUnits(req: Request) async throws -> UnitPreferencesDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await UserEntity.find(payload.userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        let units = try req.content.decode(UnitPreferencesDTO.self)
        let data = try JSONEncoder().encode(units)
        user.unitsJson = String(data: data, encoding: .utf8)
        try await user.save(on: req.db)

        return units
    }

    public func updateNotificationPreferences(req: Request) async throws -> NotificationPreferencesDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await UserEntity.find(payload.userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        let notif = try req.content.decode(NotificationPreferencesDTO.self)
        let data = try JSONEncoder().encode(notif)
        user.notificationsJson = String(data: data, encoding: .utf8)
        try await user.save(on: req.db)

        return notif
    }

    /// Generates a structured JSON archive of all personal tracking records (GDPR data portability).
    public func exportUserData(req: Request) async throws -> UserDataExportDTO {
        let payload = try req.auth.require(UserPayload.self)
        let exportService = UserDataExportService()
        return try await exportService.exportUserData(userId: payload.userId, req: req)
    }

    /// Permanently wipes the user's account and cascades deletions across all database tables & object storage.
    public func deleteAccount(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        let erasureService = AccountErasureService()
        try await erasureService.eraseUserAccount(userId: payload.userId, req: req)
        return .noContent
    }
}
