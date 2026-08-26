import Foundation
import Domain
import CalculationEngine
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Notification client manager for the iOS application.
/// Manages UNUserNotificationCenterDelegate callbacks, notification action dispatching,
/// automatic timezone/DST change observer, and remote device token registration with backend.
public final class NotificationClientManager: NSObject, @unchecked Sendable {
    public static let shared = NotificationClientManager()

    private let scheduler: NotificationSchedulerProtocol
    private let apiClient: APIClientProtocol
    private let protocolRepository: ProtocolRepositoryProtocol

    // Action handlers / callbacks
    public var onDoseLogRequested: (@Sendable (ScheduledNotificationPayload) -> Void)?
    public var onDoseSkipped: (@Sendable (ScheduledNotificationPayload) -> Void)?
    public var onDeepLinkTriggered: (@Sendable (URL) -> Void)?

    public init(
        scheduler: NotificationSchedulerProtocol = NotificationScheduler(),
        apiClient: APIClientProtocol = APIClient.shared,
        protocolRepository: ProtocolRepositoryProtocol = LocalProtocolRepository()
    ) {
        self.scheduler = scheduler
        self.apiClient = apiClient
        self.protocolRepository = protocolRepository
        super.init()

        setupDelegateAndObservers()
    }

    private func setupDelegateAndObservers() {
        #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
        UNUserNotificationCenter.current().delegate = self
        #endif

        #if canImport(UIKit) && !os(Linux) && !os(Windows)
        // Listen to system timezone change and significant time / DST change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemTimeChange),
            name: UIApplication.significantTimeChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemTimeChange),
            name: NSSystemTimeZoneDidChangeNotification,
            object: nil
        )
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Timezone & Daylight-Saving Change Handler
    @objc private func handleSystemTimeChange() {
        Task {
            await synchronizeTimezoneChange()
        }
    }

    public func synchronizeTimezoneChange(timeZone: TimeZone = .current) async {
        do {
            let allProtocols = try await protocolRepository.fetchAll()
            _ = try await scheduler.handleTimezoneOrDSTChange(protocols: allProtocols, timeZone: timeZone)
        } catch {
            print("[NotificationClientManager] Failed to handle timezone shift: \(error)")
        }
    }

    // MARK: - Permission & Category Setup
    public func initialize() async {
        do {
            try await scheduler.registerNotificationCategories()
        } catch {
            print("[NotificationClientManager] Failed to register categories: \(error)")
        }
    }

    public func requestNotificationPermission() async -> Bool {
        do {
            return try await scheduler.requestAuthorization(options: .standard)
        } catch {
            print("[NotificationClientManager] Permission request error: \(error)")
            return false
        }
    }

    public func checkAuthorizationStatus() async -> NotificationAuthorizationStatus {
        return await scheduler.getAuthorizationStatus()
    }

    // MARK: - Device Token Registration with Backend
    public func registerRemoteDeviceToken(_ deviceTokenData: Data) async throws {
        let tokenString = deviceTokenData.map { String(format: "%02.2hhx", $0) }.joined()
        try await registerDeviceTokenString(tokenString)
    }

    public func registerDeviceTokenString(_ tokenString: String) async throws {
        _ = try await apiClient.request(
            .registerDeviceToken,
            body: [
                "deviceToken": tokenString,
                "platform": "iOS",
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            ],
            responseType: EmptyResponse.self
        )
    }

    // MARK: - Snooze Handler
    public func snoozeNotification(payload: ScheduledNotificationPayload, minutes: Int = 15) async throws {
        #if canImport(UserNotifications) && !os(Linux) && !os(Windows)
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Snoozed Reminder: \(payload.compoundName)"
        let amountStr = payload.doseAmount.truncatingRemainder(dividingBy: 1) == 0 ?
            String(format: "%.0f", payload.doseAmount) :
            String(format: "%.2f", payload.doseAmount)
        content.body = "Scheduled dose: \(amountStr) \(payload.doseUnit.rawValue). Tap to log now."
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryIdentifier.doseReminder.rawIdentifier
        content.threadIdentifier = payload.protocolId?.uuidString ?? payload.compoundId.uuidString
        content.userInfo = payload.userInfoDictionary

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(minutes * 60), repeats: false)
        let snoozeId = "snooze_\(payload.notificationIdentifier)_\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: snoozeId, content: content, trigger: trigger)

        try await center.add(request)
        #endif
    }
}

// MARK: - UNUserNotificationCenterDelegate
#if canImport(UserNotifications) && !os(Linux) && !os(Windows)
extension NotificationClientManager: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner, sound, and badge even when app is active in foreground
        completionHandler([.banner, .sound, .badge, .list])
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let userInfo = response.notification.request.content.userInfo
        let payload = ScheduledNotificationPayload.from(userInfo: userInfo)

        switch response.actionIdentifier {
        case NotificationActionIdentifier.logDose.rawIdentifier:
            if let p = payload {
                onDoseLogRequested?(p)
            }

        case NotificationActionIdentifier.snooze15.rawIdentifier:
            if let p = payload {
                Task {
                    try? await self.snoozeNotification(payload: p, minutes: 15)
                }
            }

        case NotificationActionIdentifier.snooze60.rawIdentifier:
            if let p = payload {
                Task {
                    try? await self.snoozeNotification(payload: p, minutes: 60)
                }
            }

        case NotificationActionIdentifier.skipDose.rawIdentifier:
            if let p = payload {
                onDoseSkipped?(p)
            }

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification banner itself
            if let p = payload {
                if let deepLink = p.deepLinkUri, let url = URL(string: deepLink) {
                    onDeepLinkTriggered?(url)
                } else {
                    onDoseLogRequested?(p)
                }
            } else if let deepLinkStr = userInfo["deepLinkUri"] as? String, let url = URL(string: deepLinkStr) {
                onDeepLinkTriggered?(url)
            }

        default:
            break
        }
    }
}
#endif
