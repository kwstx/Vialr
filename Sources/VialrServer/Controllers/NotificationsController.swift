import Vapor
import Fluent
import Domain

public struct NotificationsController: RouteCollection {
    private let pushService: APNsPushServiceProtocol

    public init(pushService: APNsPushServiceProtocol = APNsPushService.shared) {
        self.pushService = pushService
    }

    public func boot(routes: RoutesBuilder) throws {
        let notifGroup = routes.grouped("notifications")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        notifGroup.get(use: listNotifications)
        notifGroup.post("devices", use: registerDeviceToken)
        notifGroup.post("test", use: sendTestNotification)
        notifGroup.patch(":notificationId", "read", use: markAsRead)
        notifGroup.post("read-all", use: markAllAsRead)
        notifGroup.delete(":notificationId", use: deleteNotification)

        // Server-Side Event Trigger Endpoints
        let eventsGroup = notifGroup.grouped("events")
        eventsGroup.post("restock", use: triggerRestockAlert)
        eventsGroup.post("lab-ready", use: triggerLabReadyAlert)
        eventsGroup.post("conflict", use: triggerConflictAlert)
    }

    // MARK: - List User Notifications Inbox
    public func listNotifications(req: Request) async throws -> [NotificationRecordDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let unreadOnly = req.query[Bool.self, at: "unreadOnly"] ?? false

        var query = NotificationRecordEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)

        if unreadOnly {
            query = query.filter(\.$isRead == false)
        }

        let notifications = try await query
            .sort(\.$scheduledDate, .descending)
            .limit(100)
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

    // MARK: - Device Token Registration
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

    // MARK: - Send Test Push Notification
    public func sendTestNotification(req: Request) async throws -> NotificationRecordDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(TestNotificationRequestDTO.self)

        let notif = try await pushService.sendPushNotification(
            toUser: payload.userId,
            title: dto.title,
            body: dto.body,
            category: dto.category ?? NotificationCategoryIdentifier.systemAlert.rawIdentifier,
            eventType: .systemBroadcast,
            deepLinkUri: "vialr://notifications",
            customData: ["source": "test_endpoint"],
            on: req.db
        )

        return NotificationRecordDTO(
            id: notif.id ?? UUID(),
            title: notif.title,
            body: notif.body,
            category: notif.category,
            scheduledDate: notif.scheduledDate,
            isRead: notif.isRead,
            deepLinkUri: notif.deepLinkUri,
            createdAt: notif.createdAt
        )
    }

    // MARK: - Trigger Server-Aware Restock Alert
    public func triggerRestockAlert(req: Request) async throws -> NotificationRecordDTO {
        let payload = try req.auth.require(UserPayload.self)
        struct RestockTriggerDTO: Content {
            let compoundName: String
            let vialName: String
            let dosesRemaining: Int
            let daysRemaining: Int?
        }
        let dto = try req.content.decode(RestockTriggerDTO.self)

        let notif = try await pushService.sendLowInventoryAlert(
            userId: payload.userId,
            compoundName: dto.compoundName,
            vialName: dto.vialName,
            dosesRemaining: dto.dosesRemaining,
            daysRemaining: dto.daysRemaining,
            on: req.db
        )

        return NotificationRecordDTO(
            id: notif.id ?? UUID(),
            title: notif.title,
            body: notif.body,
            category: notif.category,
            scheduledDate: notif.scheduledDate,
            isRead: notif.isRead,
            deepLinkUri: notif.deepLinkUri,
            createdAt: notif.createdAt
        )
    }

    // MARK: - Trigger Server-Aware Lab Ready Alert
    public func triggerLabReadyAlert(req: Request) async throws -> NotificationRecordDTO {
        let payload = try req.auth.require(UserPayload.self)
        struct LabReadyTriggerDTO: Content {
            let labPanelId: UUID
            let panelName: String
            let biomarkerCount: Int
        }
        let dto = try req.content.decode(LabReadyTriggerDTO.self)

        let notif = try await pushService.sendLabReportReadyAlert(
            userId: payload.userId,
            labPanelId: dto.labPanelId,
            panelName: dto.panelName,
            biomarkerCount: dto.biomarkerCount,
            on: req.db
        )

        return NotificationRecordDTO(
            id: notif.id ?? UUID(),
            title: notif.title,
            body: notif.body,
            category: notif.category,
            scheduledDate: notif.scheduledDate,
            isRead: notif.isRead,
            deepLinkUri: notif.deepLinkUri,
            createdAt: notif.createdAt
        )
    }

    // MARK: - Trigger Server-Aware Conflict Alert
    public func triggerConflictAlert(req: Request) async throws -> NotificationRecordDTO {
        let payload = try req.auth.require(UserPayload.self)
        struct ConflictTriggerDTO: Content {
            let message: String
            let conflictingProtocolIds: [UUID]
        }
        let dto = try req.content.decode(ConflictTriggerDTO.self)

        let notif = try await pushService.sendProtocolConflictAlert(
            userId: payload.userId,
            message: dto.message,
            conflictingProtocolIds: dto.conflictingProtocolIds,
            on: req.db
        )

        return NotificationRecordDTO(
            id: notif.id ?? UUID(),
            title: notif.title,
            body: notif.body,
            category: notif.category,
            scheduledDate: notif.scheduledDate,
            isRead: notif.isRead,
            deepLinkUri: notif.deepLinkUri,
            createdAt: notif.createdAt
        )
    }

    // MARK: - Mark Notification Read
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

    // MARK: - Mark All Read
    public func markAllAsRead(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        let unread = try await NotificationRecordEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .filter(\.$isRead == false)
            .all()

        for notif in unread {
            notif.isRead = true
            try await notif.save(on: req.db)
        }
        return .ok
    }

    // MARK: - Delete Notification
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
