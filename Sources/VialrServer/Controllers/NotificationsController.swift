import Vapor
import Fluent

public struct NotificationsController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let notifGroup = routes.grouped("notifications")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        notifGroup.get(use: listNotifications)
        notifGroup.post("devices", use: registerDeviceToken)
        notifGroup.post("test", use: sendTestNotification)
        notifGroup.patch(":notificationId", "read", use: markAsRead)
        notifGroup.delete(":notificationId", use: deleteNotification)
    }

    public func listNotifications(req: Request) async throws -> [NotificationRecordDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let notifications = try await NotificationRecordEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .sort(\.$scheduledDate, .descending)
            .all()

        return notifications.map { n in
            NotificationRecordDTO(
                id: n.id ?? UUID(),
                title: n.title,
                body: n.body,
                category: n.category,
                scheduledDate: n.scheduledDate,
                isRead: n.isRead,
                deepLinkUri: n.deepLinkUri,
                createdAt: n.createdAt
            )
        }
    }

    public func registerDeviceToken(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(DeviceTokenRegistrationDTO.self)

        guard !dto.deviceToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Device token cannot be empty.")
        }

        // Check if token already exists for user
        if let existing = try await DeviceTokenEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .filter(\.$deviceToken == dto.deviceToken)
            .first() {
            existing.platform = dto.platform
            existing.appVersion = dto.appVersion
            try await existing.save(on: req.db)
        } else {
            let newToken = DeviceTokenEntity(
                userId: payload.userId,
                deviceToken: dto.deviceToken,
                platform: dto.platform,
                appVersion: dto.appVersion
            )
            try await newToken.save(on: req.db)
        }

        return .ok
    }

    public func sendTestNotification(req: Request) async throws -> NotificationRecordDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(TestNotificationRequestDTO.self)

        let recordId = UUID()
        let notif = NotificationRecordEntity(
            id: recordId,
            userId: payload.userId,
            title: dto.title,
            body: dto.body,
            category: dto.category ?? "reminder",
            scheduledDate: Date(),
            isRead: false,
            deepLinkUri: "vialr://notifications/\(recordId.uuidString)"
        )
        try await notif.save(on: req.db)

        return NotificationRecordDTO(
            id: recordId,
            title: notif.title,
            body: notif.body,
            category: notif.category,
            scheduledDate: notif.scheduledDate,
            isRead: notif.isRead,
            deepLinkUri: notif.deepLinkUri,
            createdAt: notif.createdAt
        )
    }

    public func markAsRead(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let notifId = req.parameters.get("notificationId", as: UUID.self),
              let notif = try await NotificationRecordEntity.query(on: req.db)
                .filter(\.$id == notifId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Notification not found.")
        }

        notif.isRead = true
        try await notif.save(on: req.db)
        return .ok
    }

    public func deleteNotification(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let notifId = req.parameters.get("notificationId", as: UUID.self),
              let notif = try await NotificationRecordEntity.query(on: req.db)
                .filter(\.$id == notifId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Notification not found.")
        }

        try await notif.delete(on: req.db)
        return .noContent
    }
}
