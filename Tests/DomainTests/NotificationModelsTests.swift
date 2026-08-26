import XCTest
@testable import Domain

final class NotificationModelsTests: XCTestCase {

    // MARK: - 1. Category and Action Identifiers
    func testNotificationCategoriesAndActions() {
        XCTAssertEqual(NotificationCategoryIdentifier.doseReminder.rawIdentifier, "vialr.category.doseReminder")
        XCTAssertEqual(NotificationCategoryIdentifier.restockAlert.rawIdentifier, "vialr.category.restockAlert")
        XCTAssertEqual(NotificationCategoryIdentifier.labReminder.rawIdentifier, "vialr.category.labReminder")
        XCTAssertEqual(NotificationCategoryIdentifier.systemAlert.rawIdentifier, "vialr.category.systemAlert")
        XCTAssertEqual(NotificationCategoryIdentifier.conflictAlert.rawIdentifier, "vialr.category.conflictAlert")

        XCTAssertEqual(NotificationActionIdentifier.logDose.rawIdentifier, "vialr.action.logDose")
        XCTAssertEqual(NotificationActionIdentifier.snooze15.rawIdentifier, "vialr.action.snooze15")
        XCTAssertEqual(NotificationActionIdentifier.snooze60.rawIdentifier, "vialr.action.snooze60")
        XCTAssertEqual(NotificationActionIdentifier.skipDose.rawIdentifier, "vialr.action.skipDose")
    }

    // MARK: - 2. Scheduled Dose Payload Dictionary Serialization
    func testScheduledNotificationPayloadRoundTrip() {
        let protocolId = UUID()
        let compoundId = UUID()
        let scheduledDate = Date(timeIntervalSince1970: 1787832000)
        let triggerDate = Date(timeIntervalSince1970: 1787831100)

        let payload = ScheduledNotificationPayload(
            notificationIdentifier: "test_id_123",
            protocolId: protocolId,
            protocolName: "GH Secretagogue",
            compoundId: compoundId,
            compoundName: "CJC-1295",
            doseAmount: 100,
            doseUnit: .mcg,
            route: .subcutaneous,
            scheduledTimestamp: scheduledDate,
            triggerTimestamp: triggerDate,
            occurrenceId: UUID(),
            attachedVialId: UUID(),
            foodRequirement: .fasted,
            deepLinkUri: "vialr://dose/log?compoundId=\(compoundId.uuidString)"
        )

        let dict = payload.userInfoDictionary
        let decoded = ScheduledNotificationPayload.from(userInfo: dict)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.notificationIdentifier, "test_id_123")
        XCTAssertEqual(decoded?.protocolId, protocolId)
        XCTAssertEqual(decoded?.compoundId, compoundId)
        XCTAssertEqual(decoded?.compoundName, "CJC-1295")
        XCTAssertEqual(decoded?.doseAmount, 100)
        XCTAssertEqual(decoded?.doseUnit, .mcg)
        XCTAssertEqual(decoded?.route, .subcutaneous)
        XCTAssertEqual(decoded?.foodRequirement, .fasted)
    }

    // MARK: - 3. Remote Push Notification APNs Serialization
    func testRemotePushPayloadEncoding() throws {
        let payload = RemotePushNotificationPayload(
            aps: RemotePushNotificationPayload.APSPayload(
                alert: RemotePushNotificationPayload.APSPayload.AlertPayload(
                    title: "Low Inventory: BPC-157",
                    body: "Vial #1 has 2 doses remaining. Tap to reorder."
                ),
                badge: 1,
                sound: "default",
                category: NotificationCategoryIdentifier.restockAlert.rawIdentifier
            ),
            eventType: .restockWarning,
            recordId: UUID(),
            entityId: "vial-123",
            deepLinkUri: "vialr://inventory",
            customData: ["compoundName": "BPC-157", "dosesRemaining": "2"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("Low Inventory: BPC-157"))
        XCTAssertTrue(jsonString.contains("restock_warning"))
        XCTAssertTrue(jsonString.contains("vialr.category.restockAlert"))
        XCTAssertTrue(jsonString.contains("vialr://inventory"))
    }
}
