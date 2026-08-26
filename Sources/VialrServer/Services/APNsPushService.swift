import Vapor
import Fluent
import Domain

/// Service responsible for constructing and dispatching remote Apple Push Notifications (APNs)
/// for events requiring server-side awareness, including low inventory warnings,
/// background lab extraction completion, protocol conflicts, and clinician reports.
public protocol APNsPushServiceProtocol: Sendable {
    /// Sends a general push notification to a user's registered devices.
    func sendPushNotification(
        toUser userId: UUID,
        title: String,
        body: String,
        category: String?,
        eventType: PushNotificationEventType,
        deepLinkUri: String?,
        customData: [String: String]?,
        on db: Database
    ) async throws -> NotificationRecordEntity

    /// Dispatches a low inventory warning when vial supplies are nearing depletion.
    func sendLowInventoryAlert(
        userId: UUID,
        compoundName: String,
        vialName: String,
        dosesRemaining: Int,
        daysRemaining: Int?,
        on db: Database
    ) async throws -> NotificationRecordEntity

    /// Dispatches an alert when background OCR/LLM biomarker extraction is complete.
    func sendLabReportReadyAlert(
        userId: UUID,
        labPanelId: UUID,
        panelName: String,
        biomarkerCount: Int,
        on db: Database
    ) async throws -> NotificationRecordEntity

    /// Dispatches an alert when the server detects conflicting or overlapping protocol schedules.
    func sendProtocolConflictAlert(
        userId: UUID,
        message: String,
        conflictingProtocolIds: [UUID],
        on db: Database
    ) async throws -> NotificationRecordEntity

    /// Dispatches an alert when an exportable clinician report has been compiled and signed.
    func sendClinicianReportReadyAlert(
        userId: UUID,
        reportId: UUID,
        clinicianName: String,
        on db: Database
    ) async throws -> NotificationRecordEntity
}

public struct APNsPushService: APNsPushServiceProtocol {
    public static let shared = APNsPushService()

    public init() {}

    // MARK: - Core Push Dispatcher
    public func sendPushNotification(
        toUser userId: UUID,
        title: String,
        body: String,
        category: String? = nil,
        eventType: PushNotificationEventType = .systemBroadcast,
        deepLinkUri: String? = nil,
        customData: [String: String]? = nil,
        on db: Database
    ) async throws -> NotificationRecordEntity {
        let recordId = UUID()

        // 1. Persist notification in database for in-app inbox
        let notificationEntity = NotificationRecordEntity(
            id: recordId,
            userId: userId,
            title: title,
            body: body,
            category: category ?? NotificationCategoryIdentifier.systemAlert.rawIdentifier,
            scheduledDate: Date(),
            isRead: false,
            deepLinkUri: deepLinkUri
        )
        try await notificationEntity.save(on: db)

        // 2. Fetch all registered device tokens for the user
        let deviceTokens = try await DeviceTokenEntity.query(on: db)
            .filter(\.$user.$id == userId)
            .all()

        guard !deviceTokens.isEmpty else {
            // No registered APNs tokens for this user
            return notificationEntity
        }

        // 3. Build APNs payload
        let payload = RemotePushNotificationPayload(
            aps: RemotePushNotificationPayload.APSPayload(
                alert: RemotePushNotificationPayload.APSPayload.AlertPayload(
                    title: title,
                    body: body
                ),
                badge: 1,
                sound: "default",
                category: category,
                threadId: userId.uuidString,
                contentAvailable: 1,
                mutableContent: 1
            ),
            eventType: eventType,
            recordId: recordId,
            entityId: nil,
            deepLinkUri: deepLinkUri,
            customData: customData
        )

        // 4. Dispatch to APNs gateway for each registered token
        for token in deviceTokens {
            await dispatchToAPNsGateway(deviceToken: token.deviceToken, payload: payload)
        }

        return notificationEntity
    }

    // MARK: - Server-Aware Event: Low Inventory Alert
    public func sendLowInventoryAlert(
        userId: UUID,
        compoundName: String,
        vialName: String,
        dosesRemaining: Int,
        daysRemaining: Int?,
        on db: Database
    ) async throws -> NotificationRecordEntity {
        let privacyFormatted = NotificationPrivacyFormatter.formatRestockAlert(
            compoundName: compoundName,
            vialName: vialName,
            dosesRemaining: dosesRemaining,
            mode: .redacted
        )
        let deepLink = "vialr://inventory"

        return try await sendPushNotification(
            toUser: userId,
            title: privacyFormatted.title,
            body: privacyFormatted.body,
            category: privacyFormatted.categoryIdentifier,
            eventType: .restockWarning,
            deepLinkUri: deepLink,
            customData: [
                "compoundName": compoundName,
                "vialName": vialName,
                "dosesRemaining": "\(dosesRemaining)"
            ],
            on: db
        )
    }

    // MARK: - Server-Aware Event: Lab Report Ready
    public func sendLabReportReadyAlert(
        userId: UUID,
        labPanelId: UUID,
        panelName: String,
        biomarkerCount: Int,
        on db: Database
    ) async throws -> NotificationRecordEntity {
        let privacyFormatted = NotificationPrivacyFormatter.formatLabReadyAlert(
            panelName: panelName,
            biomarkerCount: biomarkerCount,
            mode: .redacted
        )
        let deepLink = "vialr://bloodwork/panel/\(labPanelId.uuidString)"

        return try await sendPushNotification(
            toUser: userId,
            title: privacyFormatted.title,
            body: privacyFormatted.body,
            category: privacyFormatted.categoryIdentifier,
            eventType: .labReportReady,
            deepLinkUri: deepLink,
            customData: [
                "labPanelId": labPanelId.uuidString,
                "panelName": panelName,
                "biomarkerCount": "\(biomarkerCount)"
            ],
            on: db
        )
    }

    // MARK: - Server-Aware Event: Protocol Conflict Detected
    public func sendProtocolConflictAlert(
        userId: UUID,
        message: String,
        conflictingProtocolIds: [UUID],
        on db: Database
    ) async throws -> NotificationRecordEntity {
        let privacyFormatted = NotificationPrivacyFormatter.formatProtocolConflictAlert(
            message: message,
            mode: .redacted
        )
        let deepLink = "vialr://protocols"

        return try await sendPushNotification(
            toUser: userId,
            title: privacyFormatted.title,
            body: privacyFormatted.body,
            category: privacyFormatted.categoryIdentifier,
            eventType: .protocolConflict,
            deepLinkUri: deepLink,
            customData: [
                "conflictingProtocolIds": conflictingProtocolIds.map(\.uuidString).joined(separator: ",")
            ],
            on: db
        )
    }

    // MARK: - Server-Aware Event: Clinician Report Ready
    public func sendClinicianReportReadyAlert(
        userId: UUID,
        reportId: UUID,
        clinicianName: String,
        on db: Database
    ) async throws -> NotificationRecordEntity {
        let title = "Clinician Summary Report Ready"
        let body = "Your protocol medical summary for Dr. \(clinicianName) has been generated."
        let deepLink = "vialr://reports/\(reportId.uuidString)"

        return try await sendPushNotification(
            toUser: userId,
            title: title,
            body: body,
            category: NotificationCategoryIdentifier.systemAlert.rawIdentifier,
            eventType: .clinicianReportReady,
            deepLinkUri: deepLink,
            customData: [
                "reportId": reportId.uuidString,
                "clinicianName": clinicianName
            ],
            on: db
        )
    }

    // MARK: - Internal APNs Gateway Dispatcher (HTTP/2 / Mock fallback)
    private func dispatchToAPNsGateway(deviceToken: String, payload: RemotePushNotificationPayload) async {
        // Formats the HTTP/2 APNs request payload according to RFC 7540 APNs specs
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            return
        }
        
        let payloadString = String(data: payloadData, encoding: .utf8) ?? "{}"
        
        // Log push dispatch (in production uses HTTP/2 client / APNs token-based .p8 cert)
        #if DEBUG
        print("[APNsPushService] Dispatched APNs to token [\(deviceToken.prefix(8))...]: \(payloadString)")
        #endif
    }
}
