import XCTest
@testable import Domain

final class PrivacyArchitectureTests: XCTestCase {

    // MARK: - 1. Data Classification & Tiers
    func testDataClassificationTiers() {
        XCTAssertEqual(DataClassification.identity.rawValue, "identity")
        XCTAssertEqual(DataClassification.healthProtocol.rawValue, "health_protocol")
        XCTAssertEqual(DataClassification.telemetryObservability.rawValue, "telemetry_observability")
        XCTAssertEqual(DataClassification.ephemeralSecurity.rawValue, "ephemeral_security")
    }

    // MARK: - 2. Opaque Subject Identifiers & Pseudonymization
    func testOpaqueSubjectIdentifierDerivation() {
        let userId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let salt1 = "vialr-salt-primary"
        let salt2 = "vialr-salt-secondary"

        let opaque1 = OpaqueSubjectIdentifier.derive(from: userId, salt: salt1)
        let opaque2 = OpaqueSubjectIdentifier.derive(from: userId, salt: salt1)
        let opaque3 = OpaqueSubjectIdentifier.derive(from: userId, salt: salt2)

        // Deterministic derivation for same user + salt
        XCTAssertEqual(opaque1.opaqueToken, opaque2.opaqueToken)
        XCTAssertEqual(opaque1.classification, .healthProtocol)
        XCTAssertFalse(opaque1.opaqueToken.contains("11111111-2222"))

        // Blinding: Different salt generates distinct pseudonym
        XCTAssertNotEqual(opaque1.opaqueToken, opaque3.opaqueToken)

        // Ephemeral token generation
        let ephem = OpaqueSubjectIdentifier.generateEphemeralToken()
        XCTAssertTrue(ephem.opaqueToken.hasPrefix("ephem_"))
        XCTAssertEqual(ephem.classification, .ephemeralSecurity)
    }

    // MARK: - 3. Notification Privacy Redaction
    func testNotificationPrivacyFormatterRedactedDose() {
        let formatted = NotificationPrivacyFormatter.formatDoseReminder(
            compoundName: "Testosterone Cypionate",
            doseAmount: 250,
            doseUnit: .milligrams,
            route: .intramuscular,
            mode: .redacted
        )

        // Redacted mode MUST NOT leak compound name, dosage, or route into alert banner
        XCTAssertEqual(formatted.title, "Scheduled Dose Reminder")
        XCTAssertEqual(formatted.body, "Time for your scheduled protocol dose. Tap to view and log.")
        XCTAssertFalse(formatted.title.contains("Testosterone"))
        XCTAssertFalse(formatted.body.contains("250"))
        XCTAssertFalse(formatted.body.contains("mg"))
        XCTAssertFalse(formatted.body.contains("Intramuscular"))
    }

    func testNotificationPrivacyFormatterDetailedDose() {
        let formatted = NotificationPrivacyFormatter.formatDoseReminder(
            compoundName: "BPC-157",
            doseAmount: 500,
            doseUnit: .mcg,
            route: .subcutaneous,
            mode: .detailed
        )

        XCTAssertEqual(formatted.title, "Dose Reminder: BPC-157")
        XCTAssertTrue(formatted.body.contains("500"))
        XCTAssertTrue(formatted.body.contains("mcg"))
    }

    func testNotificationPrivacyFormatterRestockAlertRedaction() {
        let redacted = NotificationPrivacyFormatter.formatRestockAlert(
            compoundName: "Semaglutide",
            vialName: "Vial #2 (5mg)",
            dosesRemaining: 2,
            mode: .redacted
        )

        XCTAssertEqual(redacted.title, "Supply Inventory Alert")
        XCTAssertEqual(redacted.body, "An item in your protocol supplies is running low. Tap to review inventory.")
        XCTAssertFalse(redacted.body.contains("Semaglutide"))
        XCTAssertFalse(redacted.body.contains("Vial #2"))

        let detailed = NotificationPrivacyFormatter.formatRestockAlert(
            compoundName: "Semaglutide",
            vialName: "Vial #2 (5mg)",
            dosesRemaining: 2,
            mode: .detailed
        )
        XCTAssertTrue(detailed.title.contains("Semaglutide"))
        XCTAssertTrue(detailed.body.contains("2 doses remaining"))
    }

    func testNotificationPrivacyFormatterLabReadyRedaction() {
        let redacted = NotificationPrivacyFormatter.formatLabReadyAlert(
            panelName: "Comprehensive Hormone Panel",
            biomarkerCount: 14,
            mode: .redacted
        )

        XCTAssertEqual(redacted.title, "Laboratory Analysis Ready")
        XCTAssertEqual(redacted.body, "Your recent diagnostic results are ready for review.")
        XCTAssertFalse(redacted.title.contains("Hormone"))

        let detailed = NotificationPrivacyFormatter.formatLabReadyAlert(
            panelName: "Comprehensive Hormone Panel",
            biomarkerCount: 14,
            mode: .detailed
        )
        XCTAssertTrue(detailed.title.contains("Comprehensive Hormone Panel"))
        XCTAssertTrue(detailed.body.contains("14 biomarkers"))
    }

    func testNotificationPrivacyFormatterConflictAlertRedaction() {
        let redacted = NotificationPrivacyFormatter.formatProtocolConflictAlert(
            message: "Overlapping cycle detected between Protocol Alpha and Beta",
            mode: .redacted
        )

        XCTAssertEqual(redacted.title, "Protocol Schedule Notice")
        XCTAssertEqual(redacted.body, "Please open Vialr to review an update regarding your protocol schedule.")
        XCTAssertFalse(redacted.body.contains("Protocol Alpha"))
    }

    // MARK: - 4. Analytics & Telemetry Zero-Health Scrubber
    func testAnalyticsPrivacyScrubberStripsSensitiveHealthData() {
        let rawProperties: [String: Any] = [
            "screen_name": "DoseLogView",
            "compound_name": "Nandrolone",
            "dose_amount": 100.0,
            "dose_unit": "mg",
            "lab_value": 980.5,
            "biomarker_name": "Total Testosterone",
            "injection_site": "Ventrogluteal Left",
            "notes": "Felt slight pinch",
            "item_count": 1,
            "latency_ms": 42.5
        ]

        let opaque = OpaqueSubjectIdentifier.derive(from: UUID(), salt: "salt-test")
        let sanitized = AnalyticsEventPrivacyScrubber.sanitizeEvent(
            name: "dose_log_created",
            properties: rawProperties,
            opaqueSubjectId: opaque
        )

        // 1. Whitelisted keys must be preserved
        XCTAssertEqual(sanitized["screen_name"] as? String, "DoseLogView")
        XCTAssertEqual(sanitized["item_count"] as? Int, 1)
        XCTAssertEqual(sanitized["latency_ms"] as? Double, 42.5)
        XCTAssertEqual(sanitized["opaque_subject_id"] as? String, opaque.opaqueToken)

        // 2. Sensitive health fields MUST BE COMPLETELY DROPPED
        XCTAssertNil(sanitized["compound_name"])
        XCTAssertNil(sanitized["dose_amount"])
        XCTAssertNil(sanitized["dose_unit"])
        XCTAssertNil(sanitized["lab_value"])
        XCTAssertNil(sanitized["biomarker_name"])
        XCTAssertNil(sanitized["injection_site"])
        XCTAssertNil(sanitized["notes"])

        // 3. Zero-health verification assertion
        XCTAssertTrue(AnalyticsEventPrivacyScrubber.verifyZeroHealthLeakage(sanitized))
    }

    func testVerifyZeroHealthLeakageCatchesUnsanitizedPayload() {
        let leakyPayload: [String: Any] = [
            "action": "view_labs",
            "lab_value": 450.0
        ]
        XCTAssertFalse(AnalyticsEventPrivacyScrubber.verifyZeroHealthLeakage(leakyPayload))

        let cleanPayload: [String: Any] = [
            "action": "view_labs",
            "item_count": 5
        ]
        XCTAssertTrue(AnalyticsEventPrivacyScrubber.verifyZeroHealthLeakage(cleanPayload))
    }

    // MARK: - 5. User Data Portability Export Bundle
    func testUserDataExportBundleRoundTrip() throws {
        let manifest = UserDataExportBundle.ExportManifest(
            exportId: UUID(),
            exportedAt: Date(),
            schemaVersion: "vialr.export.v1",
            opaqueSubjectToken: "opaque_test_subject",
            totalRecordCount: 3,
            recordCountsByEntity: ["compounds": 1, "protocols": 1, "doses": 1],
            sha256Checksum: "abc123checksum"
        )

        let bundle = UserDataExportBundle(
            manifest: manifest,
            accountProfile: UserAccountInfo(email: "user@example.com", displayName: "Alex"),
            userPreferences: UserPreferences(),
            notificationPreferences: NotificationPreferences(),
            privacyPreferences: PrivacyPreferences(),
            unitPreferences: UnitPreferences(),
            compounds: [],
            protocols: [],
            protocolRevisions: [],
            doseLogs: [],
            vials: [],
            supplies: [],
            injectionSiteEvents: [],
            reconstitutionRecords: [],
            measurements: [],
            metricDefinitions: [],
            labPanels: [],
            biomarkers: [],
            symptomLogs: [],
            costRecords: [],
            documents: []
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(UserDataExportBundle.self, from: data)

        XCTAssertEqual(decoded.manifest.schemaVersion, "vialr.export.v1")
        XCTAssertEqual(decoded.manifest.opaqueSubjectToken, "opaque_test_subject")
        XCTAssertEqual(decoded.manifest.sha256Checksum, "abc123checksum")
        XCTAssertEqual(decoded.accountProfile.email, "user@example.com")
    }

    // MARK: - 6. Data Erasure Manifest
    func testDataErasureManifestProperties() {
        let erasure = DataErasureManifest(
            erasureId: UUID(),
            requestedAt: Date(),
            completedAt: Date(),
            erasedOpaqueSubject: "subject_token_xyz",
            localStoreWiped: true,
            swiftDataPurged: true,
            keychainCredentialsCleared: true,
            localDocumentsPurged: true,
            localNotificationsCancelled: true,
            remoteRecordsPurged: true,
            objectVaultFilesPurged: 4
        )

        XCTAssertTrue(erasure.localStoreWiped)
        XCTAssertTrue(erasure.keychainCredentialsCleared)
        XCTAssertTrue(erasure.remoteRecordsPurged)
        XCTAssertEqual(erasure.objectVaultFilesPurged, 4)
    }
}
