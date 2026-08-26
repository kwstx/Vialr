import Foundation

// MARK: - Notification Category Identifiers
public enum NotificationCategoryIdentifier: String, CaseIterable, Sendable {
    case doseReminder = "vialr.category.doseReminder"
    case restockAlert = "vialr.category.restockAlert"
    case labReminder = "vialr.category.labReminder"
    case systemAlert = "vialr.category.systemAlert"
    case conflictAlert = "vialr.category.conflictAlert"

    public var rawIdentifier: String { rawValue }
}

// MARK: - Notification Action Identifiers
public enum NotificationActionIdentifier: String, CaseIterable, Sendable {
    case logDose = "vialr.action.logDose"
    case snooze15 = "vialr.action.snooze15"
    case snooze60 = "vialr.action.snooze60"
    case skipDose = "vialr.action.skipDose"
    case viewVial = "vialr.action.viewVial"
    case viewLab = "vialr.action.viewLab"
    case dismiss = "vialr.action.dismiss"

    public var rawIdentifier: String { rawValue }
}

// MARK: - Notification Authorization Status
public enum NotificationAuthorizationStatus: String, Codable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    public var isAuthorized: Bool {
        self == .authorized || self == .provisional || self == .ephemeral
    }
}

// MARK: - Notification Authorization Options
public struct NotificationAuthorizationOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let badge = NotificationAuthorizationOptions(rawValue: 1 << 0)
    public static let sound = NotificationAuthorizationOptions(rawValue: 1 << 1)
    public static let alert = NotificationAuthorizationOptions(rawValue: 1 << 2)
    public static let provisional = NotificationAuthorizationOptions(rawValue: 1 << 3)
    public static let criticalAlert = NotificationAuthorizationOptions(rawValue: 1 << 4)

    public static let standard: NotificationAuthorizationOptions = [.alert, .sound, .badge]
}

// MARK: - Scheduled Dose Notification Payload
public struct ScheduledNotificationPayload: Codable, Sendable, Hashable {
    public let notificationIdentifier: String
    public let protocolId: UUID?
    public let protocolName: String?
    public let compoundId: UUID
    public let compoundName: String
    public let doseAmount: Double
    public let doseUnit: DoseUnit
    public let route: AdministrationRoute
    public let scheduledTimestamp: Date
    public let triggerTimestamp: Date
    public let occurrenceId: UUID?
    public let attachedVialId: UUID?
    public let foodRequirement: FoodRequirement?
    public let deepLinkUri: String?

    public init(
        notificationIdentifier: String,
        protocolId: UUID?,
        protocolName: String? = nil,
        compoundId: UUID,
        compoundName: String,
        doseAmount: Double,
        doseUnit: DoseUnit,
        route: AdministrationRoute,
        scheduledTimestamp: Date,
        triggerTimestamp: Date,
        occurrenceId: UUID? = nil,
        attachedVialId: UUID? = nil,
        foodRequirement: FoodRequirement? = nil,
        deepLinkUri: String? = nil
    ) {
        self.notificationIdentifier = notificationIdentifier
        self.protocolId = protocolId
        self.protocolName = protocolName
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.route = route
        self.scheduledTimestamp = scheduledTimestamp
        self.triggerTimestamp = triggerTimestamp
        self.occurrenceId = occurrenceId
        self.attachedVialId = attachedVialId
        self.foodRequirement = foodRequirement
        self.deepLinkUri = deepLinkUri ?? "vialr://dose/log?compoundId=\(compoundId.uuidString)&protocolId=\(protocolId?.uuidString ?? "")"
    }

    public var userInfoDictionary: [String: Any] {
        var dict: [String: Any] = [
            "notificationIdentifier": notificationIdentifier,
            "compoundId": compoundId.uuidString,
            "compoundName": compoundName,
            "doseAmount": doseAmount,
            "doseUnit": doseUnit.rawValue,
            "route": route.rawValue,
            "scheduledTimestamp": scheduledTimestamp.timeIntervalSince1970,
            "triggerTimestamp": triggerTimestamp.timeIntervalSince1970,
            "deepLinkUri": deepLinkUri ?? ""
        ]
        if let pid = protocolId {
            dict["protocolId"] = pid.uuidString
        }
        if let pname = protocolName {
            dict["protocolName"] = pname
        }
        if let occId = occurrenceId {
            dict["occurrenceId"] = occId.uuidString
        }
        if let vialId = attachedVialId {
            dict["attachedVialId"] = vialId.uuidString
        }
        if let food = foodRequirement {
            dict["foodRequirement"] = food.rawValue
        }
        return dict
    }

    public static func from(userInfo: [AnyHashable: Any]) -> ScheduledNotificationPayload? {
        guard let id = userInfo["notificationIdentifier"] as? String,
              let compoundIdStr = userInfo["compoundId"] as? String,
              let compoundId = UUID(uuidString: compoundIdStr),
              let compoundName = userInfo["compoundName"] as? String,
              let doseAmount = userInfo["doseAmount"] as? Double,
              let doseUnitStr = userInfo["doseUnit"] as? String,
              let doseUnit = DoseUnit(rawValue: doseUnitStr),
              let routeStr = userInfo["route"] as? String,
              let route = AdministrationRoute(rawValue: routeStr),
              let schedEpoch = userInfo["scheduledTimestamp"] as? Double,
              let trigEpoch = userInfo["triggerTimestamp"] as? Double else {
            return nil
        }

        let protocolId = (userInfo["protocolId"] as? String).flatMap { UUID(uuidString: $0) }
        let protocolName = userInfo["protocolName"] as? String
        let occurrenceId = (userInfo["occurrenceId"] as? String).flatMap { UUID(uuidString: $0) }
        let attachedVialId = (userInfo["attachedVialId"] as? String).flatMap { UUID(uuidString: $0) }
        let foodRequirement = (userInfo["foodRequirement"] as? String).flatMap { FoodRequirement(rawValue: $0) }
        let deepLinkUri = userInfo["deepLinkUri"] as? String

        return ScheduledNotificationPayload(
            notificationIdentifier: id,
            protocolId: protocolId,
            protocolName: protocolName,
            compoundId: compoundId,
            compoundName: compoundName,
            doseAmount: doseAmount,
            doseUnit: doseUnit,
            route: route,
            scheduledTimestamp: Date(timeIntervalSince1970: schedEpoch),
            triggerTimestamp: Date(timeIntervalSince1970: trigEpoch),
            occurrenceId: occurrenceId,
            attachedVialId: attachedVialId,
            foodRequirement: foodRequirement,
            deepLinkUri: deepLinkUri
        )
    }
}

// MARK: - Remote Push Notification Models (APNs & Backend)
public enum PushNotificationEventType: String, Codable, Sendable {
    case doseReminder = "dose_reminder"
    case restockWarning = "restock_warning"
    case labReportReady = "lab_report_ready"
    case protocolConflict = "protocol_conflict"
    case clinicianReportReady = "clinician_report_ready"
    case systemBroadcast = "system_broadcast"
}

public struct RemotePushNotificationPayload: Codable, Sendable {
    public struct APSPayload: Codable, Sendable {
        public struct AlertPayload: Codable, Sendable {
            public let title: String
            public let body: String
            public let subtitle: String?

            public init(title: String, body: String, subtitle: String? = nil) {
                self.title = title
                self.body = body
                self.subtitle = subtitle
            }
        }

        public let alert: AlertPayload
        public let badge: Int?
        public let sound: String?
        public let category: String?
        public let threadId: String?
        public let contentAvailable: Int?
        public let mutableContent: Int?

        enum CodingKeys: String, CodingKey {
            case alert
            case badge
            case sound
            case category
            case threadId = "thread-id"
            case contentAvailable = "content-available"
            case mutableContent = "mutable-content"
        }

        public init(
            alert: AlertPayload,
            badge: Int? = nil,
            sound: String? = "default",
            category: String? = nil,
            threadId: String? = nil,
            contentAvailable: Int? = nil,
            mutableContent: Int? = 1
        ) {
            self.alert = alert
            self.badge = badge
            self.sound = sound
            self.category = category
            self.threadId = threadId
            self.contentAvailable = contentAvailable
            self.mutableContent = mutableContent
        }
    }

    public let aps: APSPayload
    public let eventType: PushNotificationEventType
    public let recordId: UUID
    public let entityId: String?
    public let deepLinkUri: String?
    public let customData: [String: String]?

    public init(
        aps: APSPayload,
        eventType: PushNotificationEventType,
        recordId: UUID = UUID(),
        entityId: String? = nil,
        deepLinkUri: String? = nil,
        customData: [String: String]? = nil
    ) {
        self.aps = aps
        self.eventType = eventType
        self.recordId = recordId
        self.entityId = entityId
        self.deepLinkUri = deepLinkUri
        self.customData = customData
    }
}
