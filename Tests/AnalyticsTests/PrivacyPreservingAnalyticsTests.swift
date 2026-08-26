import XCTest
@testable import Analytics
@testable import Domain

final class PrivacyPreservingAnalyticsTests: XCTestCase {

    func testPrivacyPreservingAnalyticsEngineStripsHealthData() async {
        let engine = PrivacyPreservingAnalyticsEngine(
            opaqueSubjectId: OpaqueSubjectIdentifier.derive(from: UUID(), salt: "unit-test"),
            isTelemetryEnabled: true
        )

        // Attempt to pass sensitive health properties into general trackEvent
        await engine.trackEvent(
            name: "dose_log_created",
            properties: [
                "compound_name": "Tirzepatide",
                "dose_amount": 7.5,
                "lab_value": 5.4,
                "is_on_time": true,
                "latency_ms": 12.0
            ]
        )

        let trail = await engine.getAuditTrail()
        XCTAssertEqual(trail.count, 1)
        let event = trail[0]

        // 1. Operational keys allowed
        XCTAssertEqual(event["is_on_time"] as? Bool, true)
        XCTAssertEqual(event["latency_ms"] as? Double, 12.0)
        XCTAssertNotNil(event["opaque_subject_id"])

        // 2. Sensitive health info stripped
        XCTAssertNil(event["compound_name"])
        XCTAssertNil(event["dose_amount"])
        XCTAssertNil(event["lab_value"])
    }

    func testPrivacySafeTrackersEmitOnlyStructuralData() async {
        let engine = PrivacyPreservingAnalyticsEngine(isTelemetryEnabled: true)

        // Dose action tracker
        await engine.trackDoseAction(hasVial: true, isOnTime: true, routeType: "SubQ")

        // Lab import tracker
        await engine.trackLabImport(candidateCount: 12, sourceType: "pdf_ocr", durationMs: 450.0)

        // Sync status tracker
        await engine.trackSyncStatus(batchCount: 3, isSuccess: true, durationMs: 120.0)

        let trail = await engine.getAuditTrail()
        XCTAssertEqual(trail.count, 3)

        // Event 1: Dose log created
        let doseEvent = trail[0]
        XCTAssertEqual(doseEvent["event_name"] as? String, "dose_log_created")
        XCTAssertEqual(doseEvent["has_vial_attached"] as? Bool, true)
        XCTAssertEqual(doseEvent["is_on_time"] as? Bool, true)
        XCTAssertNil(doseEvent["compound_name"])
        XCTAssertNil(doseEvent["dose_amount"])

        // Event 2: Lab panel imported
        let labEvent = trail[1]
        XCTAssertEqual(labEvent["event_name"] as? String, "lab_panel_imported")
        XCTAssertEqual(labEvent["candidate_count"] as? Int, 12)
        XCTAssertEqual(labEvent["source_type"] as? String, "pdf_ocr")
        XCTAssertNil(labEvent["biomarker_name"])
        XCTAssertNil(labEvent["lab_value"])

        // Event 3: Sync push
        let syncEvent = trail[2]
        XCTAssertEqual(syncEvent["event_name"] as? String, "sync_push_completed")
        XCTAssertEqual(syncEvent["item_count"] as? Int, 3)
        XCTAssertEqual(syncEvent["status_code"] as? Int, 200)
    }

    func testDisabledTelemetryEmitsNothing() async {
        let engine = PrivacyPreservingAnalyticsEngine(isTelemetryEnabled: false)

        await engine.trackScreen(screenName: "Dashboard")
        await engine.trackDoseAction(hasVial: false, isOnTime: true, routeType: "IM")

        let trail = await engine.getAuditTrail()
        XCTAssertTrue(trail.isEmpty)
    }
}
