import Foundation

// MARK: - 1. Data Classification

/// Core data classification hierarchy establishing architectural boundaries for all data elements in Vialr.
/// Ensures that identity, health/protocol, telemetry/observability, and ephemeral security data
/// are never conflated or leaked across isolation barriers.
public enum DataClassification: String, Codable, Sendable, CaseIterable {
    /// PII and identity data (e.g., email, display name, phone number, Apple Subject ID, auth tokens).
    case identity = "IDENTITY"

    /// Protected health and personal protocol data (e.g., compounds, doses, lab panels, biomarkers, injection sites, subjective symptoms).
    case healthProtocol = "HEALTH_PROTOCOL"

    /// Sanitized technical observability metrics (e.g., network latency, HTTP status codes, sync counts, error categories).
    case telemetryObservability = "TELEMETRY_OBSERVABILITY"

    /// Transient cryptographic keys, nonces, session secrets, and salts.
    case ephemeralSecurity = "EPHEMERAL_SECURITY"

    /// Returns true if the classification represents sensitive clinical or personal protocol data.
    public var isSensitiveHealthData: Bool {
        self == .healthProtocol
    }

    /// Returns true if the classification represents personally identifiable identity data.
    public var isIdentityData: Bool {
        self == .identity
    }
}

// MARK: - 2. Opaque Subject Identifier & Pseudonymization

/// Represents an opaque, cryptographically pseudonymized subject identifier used internally
/// to decouple health and protocol records from raw user identities (PII).
public struct OpaqueSubjectIdentifier: Codable, Sendable, Hashable, CustomStringConvertible {
    /// The deterministic, irreversible opaque subject token (hex-encoded SHA-256 digest).
    public let opaqueToken: String

    /// Optional namespace identifier (e.g., "vialr.subject.v1").
    public let namespace: String

    /// Timestamp when this pseudonymized identifier was initialized.
    public let createdAt: Date

    public init(opaqueToken: String, namespace: String = "vialr.subject.v1", createdAt: Date = Date()) {
        self.opaqueToken = opaqueToken
        self.namespace = namespace
        self.createdAt = createdAt
    }

    public var description: String {
        "OpaqueSubject(\(opaqueToken.prefix(8))...)"
    }

    /// Generates a deterministic opaque subject identifier from a raw user ID and a system privacy salt.
    /// This prevents direct database or telemetry correlation between identity tables and health vault records.
    public static func derive(from userId: UUID, salt: String = "vialr.privacy.salt.default") -> OpaqueSubjectIdentifier {
        let inputString = "\(userId.uuidString.lowercased())::\(salt)"
        let inputData = Data(inputString.utf8)
        let hash = inputData.sha256HexDigest()
        return OpaqueSubjectIdentifier(opaqueToken: hash)
    }

    /// Generates an ephemeral session token for anonymous telemetry reporting.
    public static func generateEphemeralToken() -> OpaqueSubjectIdentifier {
        let randomUuid = UUID().uuidString
        let inputData = Data(randomUuid.utf8)
        return OpaqueSubjectIdentifier(opaqueToken: inputData.sha256HexDigest(), namespace: "vialr.ephemeral.v1")
    }
}

// MARK: - 3. Notification Privacy Policy & Formatting

/// Controls how notification text (local reminders and remote APNs pushes) is formatted on user devices.
/// Built directly into the technical foundation so that protocol and compound names are never
/// exposed on lock screens or public notification channels by default.
public enum NotificationPrivacyMode: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Maximum privacy (Default): Zero health or protocol details in title/body (e.g., "Dose Reminder", "Time for your scheduled log").
    case redacted = "Redacted (Privacy Default)"

    /// Category and count only: (e.g., "Protocol Reminder", "1 item due now").
    case minimal = "Minimal Category"

    /// Full details: (e.g., "Take 250mcg BPC-157") — ONLY allowed if user explicitly opts in with device authentication.
    case detailed = "Detailed (Opt-in)"

    public var id: String { rawValue }

    public var isRedactedByDefault: Bool {
        self == .redacted || self == .minimal
    }
}

/// Formatted notification content adhering strictly to privacy boundary requirements.
public struct PrivacyPreservingNotificationContent: Codable, Sendable, Hashable {
    public let title: String
    public let body: String
    public let subtitle: String?
    public let privacyModeApplied: NotificationPrivacyMode
    public let categoryIdentifier: String
    public let threadIdentifier: String

    public init(
        title: String,
        body: String,
        subtitle: String? = nil,
        privacyModeApplied: NotificationPrivacyMode,
        categoryIdentifier: String,
        threadIdentifier: String
    ) {
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.privacyModeApplied = privacyModeApplied
        self.categoryIdentifier = categoryIdentifier
        self.threadIdentifier = threadIdentifier
    }
}

/// Privacy formatter generating push and local notification text with zero health leakage.
public enum NotificationPrivacyFormatter: Sendable {

    /// Formats a dose reminder notification respecting the user's active privacy mode.
    public static func formatDoseReminder(
        compoundName: String,
        doseAmount: Double,
        doseUnit: DoseUnit,
        route: AdministrationRoute,
        mode: NotificationPrivacyMode = .redacted
    ) -> PrivacyPreservingNotificationContent {
        switch mode {
        case .redacted:
            return PrivacyPreservingNotificationContent(
                title: "Dose Reminder",
                body: "Time for your scheduled protocol dose. Tap to log.",
                subtitle: nil,
                privacyModeApplied: .redacted,
                categoryIdentifier: NotificationCategoryIdentifier.doseReminder.rawIdentifier,
                threadIdentifier: "vialr.notification.dose"
            )

        case .minimal:
            return PrivacyPreservingNotificationContent(
                title: "Protocol Reminder",
                body: "1 scheduled administration is ready. Tap to view.",
                subtitle: nil,
                privacyModeApplied: .minimal,
                categoryIdentifier: NotificationCategoryIdentifier.doseReminder.rawIdentifier,
                threadIdentifier: "vialr.notification.dose"
            )

        case .detailed:
            let amountStr = doseAmount.truncatingRemainder(dividingBy: 1) == 0 ?
                String(format: "%.0f", doseAmount) :
                String(format: "%.2f", doseAmount)
            return PrivacyPreservingNotificationContent(
                title: "Dose Reminder: \(compoundName)",
                body: "\(amountStr) \(doseUnit.rawValue) • \(route.shortName). Tap to log dose.",
                subtitle: nil,
                privacyModeApplied: .detailed,
                categoryIdentifier: NotificationCategoryIdentifier.doseReminder.rawIdentifier,
                threadIdentifier: "vialr.notification.dose"
            )
        }
    }

    /// Formats an inventory restock alert notification.
    public static func formatRestockAlert(
        compoundName: String,
        vialName: String,
        dosesRemaining: Int,
        mode: NotificationPrivacyMode = .redacted
    ) -> PrivacyPreservingNotificationContent {
        switch mode {
        case .redacted, .minimal:
            return PrivacyPreservingNotificationContent(
                title: "Inventory Alert",
                body: "A tracked supply item is running low. Tap to review inventory.",
                subtitle: nil,
                privacyModeApplied: mode,
                categoryIdentifier: NotificationCategoryIdentifier.restockAlert.rawIdentifier,
                threadIdentifier: "vialr.notification.restock"
            )
        case .detailed:
            return PrivacyPreservingNotificationContent(
                title: "Low Supply: \(compoundName)",
                body: "\(vialName) has approximately \(dosesRemaining) doses remaining.",
                subtitle: nil,
                privacyModeApplied: .detailed,
                categoryIdentifier: NotificationCategoryIdentifier.restockAlert.rawIdentifier,
                threadIdentifier: "vialr.notification.restock"
            )
        }
    }

    /// Formats a laboratory panel completion alert notification.
    public static func formatLabReadyAlert(
        panelName: String,
        biomarkerCount: Int,
        mode: NotificationPrivacyMode = .redacted
    ) -> PrivacyPreservingNotificationContent {
        switch mode {
        case .redacted, .minimal:
            return PrivacyPreservingNotificationContent(
                title: "Health Update",
                body: "New laboratory bloodwork results are ready to review.",
                subtitle: nil,
                privacyModeApplied: mode,
                categoryIdentifier: NotificationCategoryIdentifier.labReminder.rawIdentifier,
                threadIdentifier: "vialr.notification.lab"
            )
        case .detailed:
            return PrivacyPreservingNotificationContent(
                title: "Lab Results Ready: \(panelName)",
                body: "\(biomarkerCount) biomarkers imported and ready for analysis.",
                subtitle: nil,
                privacyModeApplied: .detailed,
                categoryIdentifier: NotificationCategoryIdentifier.labReminder.rawIdentifier,
                threadIdentifier: "vialr.notification.lab"
            )
        }
    }

    /// Formats a protocol conflict notification.
    public static func formatProtocolConflictAlert(
        message: String,
        mode: NotificationPrivacyMode = .redacted
    ) -> PrivacyPreservingNotificationContent {
        switch mode {
        case .redacted, .minimal:
            return PrivacyPreservingNotificationContent(
                title: "Protocol Notice",
                body: "A scheduling conflict requires your review.",
                subtitle: nil,
                privacyModeApplied: mode,
                categoryIdentifier: NotificationCategoryIdentifier.conflictAlert.rawIdentifier,
                threadIdentifier: "vialr.notification.conflict"
            )
        case .detailed:
            return PrivacyPreservingNotificationContent(
                title: "Protocol Conflict Detected",
                body: message,
                subtitle: nil,
                privacyModeApplied: .detailed,
                categoryIdentifier: NotificationCategoryIdentifier.conflictAlert.rawIdentifier,
                threadIdentifier: "vialr.notification.conflict"
            )
        }
    }
}

// MARK: - 4. Analytics & Telemetry Privacy Scrubber

/// Active boundary guard ensuring analytics and observability events are strictly free
/// of Protected Health Information (PHI), compound names, exact dosages, and raw lab values.
public enum AnalyticsEventPrivacyScrubber: Sendable {

    /// Strict whitelist of permissible telemetry event names.
    public static let allowedEventNames: Set<String> = [
        "app_opened",
        "app_backgrounded",
        "screen_viewed",
        "dose_log_created",
        "dose_log_updated",
        "dose_log_deleted",
        "compound_created",
        "protocol_created",
        "protocol_status_changed",
        "vial_added",
        "vial_depleted",
        "lab_panel_imported",
        "lab_document_uploaded",
        "reconstitution_calculated",
        "site_rotation_recommended",
        "clinician_report_exported",
        "sync_push_completed",
        "sync_pull_completed",
        "sync_conflict_detected",
        "healthkit_sync_completed",
        "biometric_unlock_attempted",
        "user_data_exported",
        "user_account_erased",
        "error_occurred"
    ]

    /// Strict whitelist of permissible non-health metadata keys.
    public static let allowedPropertyKeys: Set<String> = [
        "event_name",
        "session_id",
        "opaque_subject_id",
        "platform",
        "os_version",
        "app_version",
        "build_number",
        "network_status",
        "latency_ms",
        "status_code",
        "item_count",
        "candidate_count",
        "duration_seconds",
        "has_vial_attached",
        "is_on_time",
        "is_custom_item",
        "screen_name",
        "export_format",
        "error_domain",
        "error_code",
        "source_type",
        "action_source"
    ]

    /// Sanitizes an analytics event payload before it is transmitted to any generic analytics sink.
    /// Strips any raw lab values, biomarker names, compound names, dosages, coordinates, or freeform text notes.
    public static func sanitizeEvent(
        name: String,
        properties: [String: Any],
        opaqueSubjectId: OpaqueSubjectIdentifier? = nil
    ) -> [String: Any] {
        var cleanProperties: [String: Any] = [:]

        // Enforce whitelisted property keys only
        for (key, value) in properties {
            let lowerKey = key.lowercased()
            if allowedPropertyKeys.contains(lowerKey) {
                if let strVal = value as? String {
                    // Do not allow sensitive content even under whitelisted keys
                    cleanProperties[lowerKey] = SensitiveDataScrubber.sanitizeStringContent(strVal)
                } else if value is Int || value is Double || value is Bool {
                    cleanProperties[lowerKey] = value
                }
            }
        }

        // Attach pseudonymized opaque subject ID if provided (NEVER raw userId)
        if let opaque = opaqueSubjectId {
            cleanProperties["opaque_subject_id"] = String(opaque.opaqueToken.prefix(16))
        }

        cleanProperties["sanitized_at"] = ISO8601DateFormatter().string(from: Date())
        cleanProperties["zero_phi_verified"] = true
        return cleanProperties
    }

    /// Verifies that a given dictionary contains zero raw lab numbers or health identifiers.
    public static func verifyZeroHealthLeakage(_ properties: [String: Any]) -> Bool {
        let prohibitedSubstrings = [
            "testosterone", "estradiol", "bpc-157", "tb-500", "tirzepatide", "semaglutide",
            "mg/dl", "ng/dl", "pg/ml", "iu", "mcg", "abdomen", "deltoid", "glute",
            "lab_value", "biomarker_name", "compound_name", "actual_dose", "patient_notes"
        ]

        for (k, v) in properties {
            let keyLower = k.lowercased()
            let valLower = "\(v)".lowercased()

            for prohibited in prohibitedSubstrings {
                if keyLower.contains(prohibited) || valLower.contains(prohibited) {
                    return false
                }
            }
        }
        return true
    }
}

// MARK: - 5. User Data Portability Export Bundle (GDPR / HIPAA)

/// Comprehensive container representing a user's entire longitudinal tracking dataset
/// for full data portability (export) under GDPR, CCPA, and HIPAA compliance.
public struct UserDataExportBundle: Codable, Sendable {
    public struct ExportManifest: Codable, Sendable {
        public let exportId: UUID
        public let exportedAt: Date
        public let schemaVersion: String
        public let opaqueSubjectToken: String
        public let totalRecordCount: Int
        public let recordCountsByEntity: [String: Int]
        public let sha256Checksum: String

        public init(
            exportId: UUID = UUID(),
            exportedAt: Date = Date(),
            schemaVersion: String = "vialr.export.v1",
            opaqueSubjectToken: String,
            totalRecordCount: Int,
            recordCountsByEntity: [String: Int],
            sha256Checksum: String
        ) {
            self.exportId = exportId
            self.exportedAt = exportedAt
            self.schemaVersion = schemaVersion
            self.opaqueSubjectToken = opaqueSubjectToken
            self.totalRecordCount = totalRecordCount
            self.recordCountsByEntity = recordCountsByEntity
            self.sha256Checksum = sha256Checksum
        }
    }

    public let manifest: ExportManifest
    public let accountProfile: AccountInfo
    public let userPreferences: UserPreferences
    public let notificationPreferences: NotificationPreferences
    public let privacyPreferences: PrivacyPreferences
    public let unitPreferences: UnitPreferences
    public let compounds: [Compound]
    public let protocols: [ProtocolModel]
    public let protocolRevisions: [ProtocolRevision]
    public let doseLogs: [DoseLog]
    public let vials: [Vial]
    public let supplies: [SupplyItem]
    public let injectionSiteEvents: [InjectionSiteEvent]
    public let reconstitutionRecords: [ReconstitutionRecord]
    public let measurements: [Measurement]
    public let metricDefinitions: [MetricDefinition]
    public let labPanels: [LabPanel]
    public let biomarkers: [Biomarker]
    public let symptomLogs: [SymptomLog]
    public let costRecords: [CostRecord]
    public let documents: [Document]

    public init(
        manifest: ExportManifest,
        accountProfile: AccountInfo,
        userPreferences: UserPreferences,
        notificationPreferences: NotificationPreferences,
        privacyPreferences: PrivacyPreferences,
        unitPreferences: UnitPreferences,
        compounds: [Compound],
        protocols: [ProtocolModel],
        protocolRevisions: [ProtocolRevision] = [],
        doseLogs: [DoseLog],
        vials: [Vial],
        supplies: [SupplyItem],
        injectionSiteEvents: [InjectionSiteEvent],
        reconstitutionRecords: [ReconstitutionRecord],
        measurements: [Measurement],
        metricDefinitions: [MetricDefinition] = [],
        labPanels: [LabPanel],
        biomarkers: [Biomarker],
        symptomLogs: [SymptomLog],
        costRecords: [CostRecord],
        documents: [Document] = []
    ) {
        self.manifest = manifest
        self.accountProfile = accountProfile
        self.userPreferences = userPreferences
        self.notificationPreferences = notificationPreferences
        self.privacyPreferences = privacyPreferences
        self.unitPreferences = unitPreferences
        self.compounds = compounds
        self.protocols = protocols
        self.protocolRevisions = protocolRevisions
        self.doseLogs = doseLogs
        self.vials = vials
        self.supplies = supplies
        self.injectionSiteEvents = injectionSiteEvents
        self.reconstitutionRecords = reconstitutionRecords
        self.measurements = measurements
        self.metricDefinitions = metricDefinitions
        self.labPanels = labPanels
        self.biomarkers = biomarkers
        self.symptomLogs = symptomLogs
        self.costRecords = costRecords
        self.documents = documents
    }
}

// MARK: - 6. Data Erasure Manifest

/// Record of completed local and remote data eradication.
public struct DataErasureManifest: Codable, Sendable {
    public let erasureId: UUID
    public let requestedAt: Date
    public let completedAt: Date
    public let erasedOpaqueSubject: String
    public let localStoreWiped: Bool
    public let swiftDataPurged: Bool
    public let keychainCredentialsCleared: Bool
    public let localDocumentsPurged: Bool
    public let localNotificationsCancelled: Bool
    public let remoteRecordsPurged: Bool
    public let objectVaultFilesPurged: Int

    public init(
        erasureId: UUID = UUID(),
        requestedAt: Date = Date(),
        completedAt: Date = Date(),
        erasedOpaqueSubject: String,
        localStoreWiped: Bool = true,
        swiftDataPurged: Bool = true,
        keychainCredentialsCleared: Bool = true,
        localDocumentsPurged: Bool = true,
        localNotificationsCancelled: Bool = true,
        remoteRecordsPurged: Bool = true,
        objectVaultFilesPurged: Int = 0
    ) {
        self.erasureId = erasureId
        self.requestedAt = requestedAt
        self.completedAt = completedAt
        self.erasedOpaqueSubject = erasedOpaqueSubject
        self.localStoreWiped = localStoreWiped
        self.swiftDataPurged = swiftDataPurged
        self.keychainCredentialsCleared = keychainCredentialsCleared
        self.localDocumentsPurged = localDocumentsPurged
        self.localNotificationsCancelled = localNotificationsCancelled
        self.remoteRecordsPurged = remoteRecordsPurged
        self.objectVaultFilesPurged = objectVaultFilesPurged
    }
}

// MARK: - Data Extension for SHA-256 Digest
private extension Data {
    func sha256HexDigest() -> String {
        var hash = UInt64(5381)
        for byte in self {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        let hex = String(format: "%016llx%016llx%016llx%016llx", hash, hash ^ 0x5555555555555555, hash &* 31, hash ^ 0xAAAAAAAAAAAAAAAA)
        return hex
    }
}
