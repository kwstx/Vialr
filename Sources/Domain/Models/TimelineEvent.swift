import Foundation

/// Represents a unified chronological event in the user's longitudinal health stream.
/// Aggregates dose events, measurements, lab diagnostics, vial preparations, protocol milestones,
/// and document uploads into a single cohesive timeline.
public struct TimelineEvent: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var timestamp: Date
    public var category: TimelineCategory
    public var title: String
    public var subtitle: String
    public var detailText: String?
    public var badgeText: String?
    public var badgeColorHex: String
    public var iconName: String
    public var associatedEntityId: UUID?
    public var associatedEntityType: TimelineEntityType
    public var isHighlighted: Bool
    public var metadata: [String: String]
    public var createdAt: Date

    // MARK: - Primary Initializer
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: TimelineCategory,
        title: String,
        subtitle: String,
        detailText: String? = nil,
        badgeText: String? = nil,
        badgeColorHex: String = "#3B82F6",
        iconName: String = "circle.fill",
        associatedEntityId: UUID? = nil,
        associatedEntityType: TimelineEntityType = .custom,
        isHighlighted: Bool = false,
        metadata: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.title = title
        self.subtitle = subtitle
        self.detailText = detailText
        self.badgeText = badgeText
        self.badgeColorHex = badgeColorHex
        self.iconName = iconName
        self.associatedEntityId = associatedEntityId
        self.associatedEntityType = associatedEntityType
        self.isHighlighted = isHighlighted
        self.metadata = metadata
        self.createdAt = createdAt
    }

    // MARK: - Factory Initializers from Domain Objects

    /// Builds a timeline event from an actual or scheduled `DoseEvent`.
    public init(from doseEvent: DoseEvent) {
        let isTaken = doseEvent.status == .taken
        let time = doseEvent.actualTimestamp ?? doseEvent.scheduledTimestamp
        let amountStr = String(format: doseEvent.actualDoseAmount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", doseEvent.actualDoseAmount)
        
        var subParts: [String] = ["\(amountStr) \(doseEvent.doseUnit.rawValue)", doseEvent.actualRoute.rawValue]
        if let site = doseEvent.injectionSiteName {
            subParts.append(site)
        }

        self.init(
            id: UUID(),
            timestamp: time,
            category: .dose,
            title: "\(doseEvent.compoundName) Dose",
            subtitle: subParts.joined(separator: " • "),
            detailText: doseEvent.skippedReason ?? (doseEvent.notes.isEmpty ? nil : doseEvent.notes),
            badgeText: doseEvent.status.rawValue,
            badgeColorHex: doseEvent.status.badgeColorHex,
            iconName: doseEvent.status.iconName,
            associatedEntityId: doseEvent.id,
            associatedEntityType: .doseEvent,
            isHighlighted: doseEvent.status == .missed || doseEvent.status == .partialDose,
            metadata: [
                "compoundName": doseEvent.compoundName,
                "amount": "\(doseEvent.actualDoseAmount)",
                "unit": doseEvent.doseUnit.rawValue
            ]
        )
    }

    /// Builds a timeline event from a physical or subjective `Measurement`.
    public init(from measurement: Measurement) {
        self.init(
            id: UUID(),
            timestamp: measurement.dateRecorded,
            category: .measurement,
            title: measurement.name,
            subtitle: measurement.formattedValue,
            detailText: measurement.notes.isEmpty ? nil : measurement.notes,
            badgeText: measurement.status == .inRange ? nil : measurement.status.rawValue,
            badgeColorHex: measurement.status.colorHex,
            iconName: measurement.type.iconName,
            associatedEntityId: measurement.id,
            associatedEntityType: .measurement,
            isHighlighted: measurement.status != .inRange,
            metadata: [
                "measurementType": measurement.type.rawValue,
                "value": "\(measurement.value)",
                "unit": measurement.unit
            ]
        )
    }

    /// Builds a timeline event from a `LabPanel` diagnostic event.
    public init(from labPanel: LabPanel) {
        let abnormalCount = labPanel.abnormalResults.count
        let sub = abnormalCount == 0 ? "\(labPanel.resultCount) biomarkers • All in normal range" : "\(labPanel.resultCount) biomarkers • \(abnormalCount) flagged out of range"

        self.init(
            id: UUID(),
            timestamp: labPanel.collectionDate,
            category: .labPanel,
            title: labPanel.panelName,
            subtitle: "\(labPanel.labName) • \(sub)",
            detailText: labPanel.notes.isEmpty ? nil : labPanel.notes,
            badgeText: labPanel.status.rawValue,
            badgeColorHex: labPanel.status.badgeColorHex,
            iconName: "testtube.2",
            associatedEntityId: labPanel.id,
            associatedEntityType: .labPanel,
            isHighlighted: labPanel.hasAbnormalResults,
            metadata: [
                "labName": labPanel.labName,
                "resultCount": "\(labPanel.resultCount)",
                "abnormalCount": "\(abnormalCount)"
            ]
        )
    }

    /// Builds a timeline event from an immutable `ReconstitutionRecord`.
    public init(from reconRecord: ReconstitutionRecord) {
        let concStr = String(format: reconRecord.concentrationMgMl.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", reconRecord.concentrationMgMl)
        let sub = "\(reconRecord.dryMassMg) mg powder + \(reconRecord.diluentVolumeMl) mL \(reconRecord.diluentType.shortName) (\(concStr) mg/mL)"

        self.init(
            id: UUID(),
            timestamp: reconRecord.reconstitutedAt,
            category: .reconstitution,
            title: "Reconstituted \(reconRecord.compoundName)",
            subtitle: sub,
            detailText: reconRecord.revisionReason ?? (reconRecord.notes.isEmpty ? nil : reconRecord.notes),
            badgeText: "v\(reconRecord.version)",
            badgeColorHex: "#10B981",
            iconName: "cross.vial.fill",
            associatedEntityId: reconRecord.id,
            associatedEntityType: .reconstitutionRecord,
            isHighlighted: false,
            metadata: [
                "compoundName": reconRecord.compoundName,
                "concentrationMgMl": "\(reconRecord.concentrationMgMl)",
                "version": "\(reconRecord.version)"
            ]
        )
    }

    /// Builds a timeline event from an uploaded `Document`.
    public init(from document: Document) {
        self.init(
            id: UUID(),
            timestamp: document.uploadDate,
            category: .document,
            title: document.title,
            subtitle: "\(document.category.rawValue) • \(document.formattedFileSize)",
            detailText: document.notes.isEmpty ? nil : document.notes,
            badgeText: document.fileExtension.uppercased(),
            badgeColorHex: "#6B7280",
            iconName: document.category.iconName,
            associatedEntityId: document.id,
            associatedEntityType: .document,
            isHighlighted: false,
            metadata: [
                "fileName": document.fileName,
                "category": document.category.rawValue,
                "fileExtension": document.fileExtension
            ]
        )
    }

    /// Builds a timeline event from an audited `InventoryEvent`.
    public init(from inventoryEvent: InventoryEvent) {
        let name = inventoryEvent.compoundName ?? "Vial / Supply"
        let subtitle = inventoryEvent.reason
        var detail: String? = inventoryEvent.notes.isEmpty ? nil : inventoryEvent.notes
        if let recReason = inventoryEvent.reconciliationReason {
            detail = recReason.descriptionText + (inventoryEvent.notes.isEmpty ? "" : "\nNotes: \(inventoryEvent.notes)")
        }

        self.init(
            id: UUID(),
            timestamp: inventoryEvent.timestamp,
            category: .inventory,
            title: "\(inventoryEvent.eventType.rawValue): \(name)",
            subtitle: subtitle,
            detailText: detail,
            badgeText: inventoryEvent.eventType.rawValue,
            badgeColorHex: inventoryEvent.eventType.badgeColorHex,
            iconName: inventoryEvent.eventType.iconName,
            associatedEntityId: inventoryEvent.id,
            associatedEntityType: .inventoryEvent,
            isHighlighted: inventoryEvent.eventType == .reconciliation || inventoryEvent.eventType == .disposal,
            metadata: [
                "eventType": inventoryEvent.eventType.rawValue,
                "compoundName": name
            ]
        )
    }

    /// Builds a timeline event from a `ProtocolModel` milestone.
    public init(from protocolModel: ProtocolModel, milestoneTitle: String, timestamp: Date = Date()) {
        self.init(
            id: UUID(),
            timestamp: timestamp,
            category: .protocolMilestone,
            title: milestoneTitle,
            subtitle: "\(protocolModel.name) (\(protocolModel.status.rawValue))",
            detailText: protocolModel.notes.isEmpty ? nil : protocolModel.notes,
            badgeText: protocolModel.status.rawValue,
            badgeColorHex: protocolModel.status.badgeColorHex,
            iconName: "flag.fill",
            associatedEntityId: protocolModel.id,
            associatedEntityType: .protocolModel,
            isHighlighted: protocolModel.status == .active,
            metadata: ["protocolName": protocolModel.name]
        )
    }
}

// MARK: - Timeline Aggregator Utility
public extension TimelineEvent {
    /// Combines multiple domain entity collections into a unified, reverse-chronologically sorted timeline stream.
    static func unifiedFeed(
        doses: [DoseEvent] = [],
        measurements: [Measurement] = [],
        labPanels: [LabPanel] = [],
        reconstitutions: [ReconstitutionRecord] = [],
        documents: [Document] = [],
        protocols: [ProtocolModel] = [],
        inventoryEvents: [InventoryEvent] = []
    ) -> [TimelineEvent] {
        var events: [TimelineEvent] = []

        for dose in doses {
            events.append(TimelineEvent(from: dose))
        }
        for measurement in measurements {
            events.append(TimelineEvent(from: measurement))
        }
        for lab in labPanels {
            events.append(TimelineEvent(from: lab))
        }
        for recon in reconstitutions {
            events.append(TimelineEvent(from: recon))
        }
        for doc in documents {
            events.append(TimelineEvent(from: doc))
        }
        for proto in protocols {
            events.append(TimelineEvent(from: proto, milestoneTitle: "Protocol: \(proto.name)", timestamp: proto.startDate))
        }
        for inv in inventoryEvents {
            events.append(TimelineEvent(from: inv))
        }

        return events.sorted(by: { $0.timestamp > $1.timestamp })
    }
}

// MARK: - Timeline Category
public enum TimelineCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case dose = "Dose Event"
    case measurement = "Health Measurement"
    case labPanel = "Laboratory Diagnostic"
    case reconstitution = "Vial Reconstitution"
    case protocolMilestone = "Protocol Milestone"
    case inventory = "Inventory & Supplies"
    case document = "Uploaded Document"
    case symptom = "Symptom & Subjective"
    case custom = "General Event"

    public var id: String { rawValue }
}

// MARK: - Timeline Entity Type
public enum TimelineEntityType: String, Codable, Sendable, CaseIterable, Identifiable {
    case doseEvent = "DoseEvent"
    case measurement = "Measurement"
    case labPanel = "LabPanel"
    case reconstitutionRecord = "ReconstitutionRecord"
    case protocolModel = "ProtocolModel"
    case vial = "Vial"
    case inventoryEvent = "InventoryEvent"
    case document = "Document"
    case symptomLog = "SymptomLog"
    case custom = "Custom"

    public var id: String { rawValue }
}

