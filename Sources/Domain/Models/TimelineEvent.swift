import Foundation

/// Represents a unified chronological event in the user's longitudinal health stream.
/// Aggregates dose events, measurements, lab diagnostics, vial preparations, protocol milestones/revisions,
/// inventory movements, symptoms, and document uploads into a single cohesive timeline.
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
                "unit": doseEvent.doseUnit.rawValue,
                "status": doseEvent.status.rawValue,
                "route": doseEvent.actualRoute.rawValue,
                "isTaken": "\(isTaken)"
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
                "unit": measurement.unit,
                "status": measurement.status.rawValue
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
                "abnormalCount": "\(abnormalCount)",
                "status": labPanel.status.rawValue
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

    /// Builds a timeline event from an immutable `ProtocolRevision` change.
    public init(from revision: ProtocolRevision) {
        let compoundsSummary = revision.compounds.map { c in
            let amtStr = String(format: c.dosageAmount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", c.dosageAmount)
            return "\(c.compoundName) \(amtStr)\(c.unit.rawValue)"
        }.joined(separator: " • ")

        self.init(
            id: UUID(),
            timestamp: revision.effectiveDate,
            category: .protocolChange,
            title: "Protocol Change (v\(revision.revisionNumber)): \(revision.name)",
            subtitle: revision.reasonForChange,
            detailText: compoundsSummary.isEmpty ? nil : compoundsSummary,
            badgeText: "Revision v\(revision.revisionNumber)",
            badgeColorHex: "#8B5CF6",
            iconName: "slider.horizontal.3",
            associatedEntityId: revision.id,
            associatedEntityType: .protocolRevision,
            isHighlighted: true,
            metadata: [
                "protocolId": revision.protocolId.uuidString,
                "revisionNumber": "\(revision.revisionNumber)",
                "reason": revision.reasonForChange
            ]
        )
    }

    /// Builds a timeline event from a `ProtocolModel` milestone.
    public init(from protocolModel: ProtocolModel, milestoneTitle: String? = nil, timestamp: Date? = nil) {
        let eventTime = timestamp ?? protocolModel.startDate
        let titleText = milestoneTitle ?? "Protocol: \(protocolModel.name)"
        let compoundsSummary = protocolModel.compounds.map { c in
            let amtStr = String(format: c.dosageAmount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", c.dosageAmount)
            return "\(c.compoundName) \(amtStr)\(c.unit.rawValue)"
        }.joined(separator: " • ")

        self.init(
            id: UUID(),
            timestamp: eventTime,
            category: .protocolChange,
            title: titleText,
            subtitle: compoundsSummary.isEmpty ? "\(protocolModel.name) (\(protocolModel.status.rawValue))" : compoundsSummary,
            detailText: protocolModel.notes.isEmpty ? nil : protocolModel.notes,
            badgeText: protocolModel.status.rawValue,
            badgeColorHex: protocolModel.status.badgeColorHex,
            iconName: "flag.fill",
            associatedEntityId: protocolModel.id,
            associatedEntityType: .protocolModel,
            isHighlighted: protocolModel.status == .active,
            metadata: [
                "protocolName": protocolModel.name,
                "status": protocolModel.status.rawValue
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
            badgeColorHex: "#06B6D4",
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

    /// Builds a timeline event from a `SymptomLog`.
    public init(from symptomLog: SymptomLog) {
        let sub = symptomLog.symptomNames.joined(separator: ", ")
        self.init(
            id: UUID(),
            timestamp: symptomLog.timestamp,
            category: .symptom,
            title: "Subjective Log (\(symptomLog.severity.rawValue))",
            subtitle: sub.isEmpty ? "Energy: \(symptomLog.energyLevel)/10 • Mood: \(symptomLog.moodScore)/10" : sub,
            detailText: symptomLog.notes.isEmpty ? nil : symptomLog.notes,
            badgeText: symptomLog.severity.rawValue,
            badgeColorHex: symptomLog.severity.badgeColorHex,
            iconName: "waveform.path.ecg",
            associatedEntityId: symptomLog.id,
            associatedEntityType: .symptomLog,
            isHighlighted: symptomLog.severity == .severe || symptomLog.severity == .moderate,
            metadata: [
                "severity": symptomLog.severity.rawValue,
                "energy": "\(symptomLog.energyLevel)",
                "mood": "\(symptomLog.moodScore)"
            ]
        )
    }
}

// MARK: - Timeline Day Group (Grouping by Day)
/// Represents a cluster of timeline events belonging to a single calendar day.
public struct TimelineDayGroup: Identifiable, Codable, Sendable, Hashable {
    public let id: String // Unique day key formatted as "yyyy-MM-dd"
    public var date: Date // Normalized start-of-day timestamp
    public var formattedDayTitle: String // "Today", "Yesterday", "Wednesday, Aug 26"
    public var formattedDaySubtitle: String // "August 26, 2026"
    public var events: [TimelineEvent]
    public var countsByCategory: [TimelineCategory: Int]
    public var totalEventsCount: Int
    public var hasHighlightedEvents: Bool
    public var summaryText: String

    public init(
        id: String,
        date: Date,
        formattedDayTitle: String,
        formattedDaySubtitle: String,
        events: [TimelineEvent],
        countsByCategory: [TimelineCategory: Int] = [:],
        summaryText: String = ""
    ) {
        self.id = id
        self.date = date
        self.formattedDayTitle = formattedDayTitle
        self.formattedDaySubtitle = formattedDaySubtitle
        self.events = events
        self.countsByCategory = countsByCategory
        self.totalEventsCount = events.count
        self.hasHighlightedEvents = events.contains(where: { $0.isHighlighted })
        self.summaryText = summaryText
    }
}

// MARK: - Timeline Filter Specification
public struct TimelineFilter: Sendable, Hashable {
    public var categories: Set<TimelineCategory>?
    public var entityTypes: Set<TimelineEntityType>?
    public var startDate: Date?
    public var endDate: Date?
    public var searchQuery: String?
    public var highlightedOnly: Bool

    public init(
        categories: Set<TimelineCategory>? = nil,
        entityTypes: Set<TimelineEntityType>? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        searchQuery: String? = nil,
        highlightedOnly: Bool = false
    ) {
        self.categories = categories
        self.entityTypes = entityTypes
        self.startDate = startDate
        self.endDate = endDate
        self.searchQuery = searchQuery
        self.highlightedOnly = highlightedOnly
    }
}

// MARK: - Timeline Statistics
public struct TimelineStatistics: Codable, Sendable, Hashable {
    public var totalEventsCount: Int
    public var totalDosesCount: Int
    public var takenDosesCount: Int
    public var missedDosesCount: Int
    public var totalLabPanelsCount: Int
    public var abnormalLabCount: Int
    public var totalMeasurementsCount: Int
    public var totalProtocolChangesCount: Int
    public var totalInventoryEventsCount: Int
    public var adherenceScore: Double?

    public init(
        totalEventsCount: Int = 0,
        totalDosesCount: Int = 0,
        takenDosesCount: Int = 0,
        missedDosesCount: Int = 0,
        totalLabPanelsCount: Int = 0,
        abnormalLabCount: Int = 0,
        totalMeasurementsCount: Int = 0,
        totalProtocolChangesCount: Int = 0,
        totalInventoryEventsCount: Int = 0,
        adherenceScore: Double? = nil
    ) {
        self.totalEventsCount = totalEventsCount
        self.totalDosesCount = totalDosesCount
        self.takenDosesCount = takenDosesCount
        self.missedDosesCount = missedDosesCount
        self.totalLabPanelsCount = totalLabPanelsCount
        self.abnormalLabCount = abnormalLabCount
        self.totalMeasurementsCount = totalMeasurementsCount
        self.totalProtocolChangesCount = totalProtocolChangesCount
        self.totalInventoryEventsCount = totalInventoryEventsCount
        self.adherenceScore = adherenceScore
    }
}

// MARK: - Timeline Query Result
public struct TimelineResult: Sendable {
    public var dayGroups: [TimelineDayGroup]
    public var allEvents: [TimelineEvent]
    public var statistics: TimelineStatistics
    public var dateInterval: DateInterval?

    public init(
        dayGroups: [TimelineDayGroup] = [],
        allEvents: [TimelineEvent] = [],
        statistics: TimelineStatistics = TimelineStatistics(),
        dateInterval: DateInterval? = nil
    ) {
        self.dayGroups = dayGroups
        self.allEvents = allEvents
        self.statistics = statistics
        self.dateInterval = dateInterval
    }
}

// MARK: - Timeline Aggregator Utility
public extension TimelineEvent {
    /// Combines multiple domain entity collections into a unified, reverse-chronologically sorted timeline stream.
    static func unifiedFeed(
        doses: [DoseEvent] = [],
        doseLogs: [DoseLog] = [],
        measurements: [Measurement] = [],
        labPanels: [LabPanel] = [],
        reconstitutions: [ReconstitutionRecord] = [],
        documents: [Document] = [],
        protocols: [ProtocolModel] = [],
        protocolRevisions: [ProtocolRevision] = [],
        inventoryEvents: [InventoryEvent] = [],
        symptoms: [SymptomLog] = []
    ) -> [TimelineEvent] {
        var events: [TimelineEvent] = []

        for dose in doses {
            events.append(TimelineEvent(from: dose))
        }
        for log in doseLogs {
            // Avoid duplicate if doseEvent ID matches
            if !doses.contains(where: { $0.id == log.id }) {
                events.append(TimelineEvent(from: log))
            }
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
            events.append(TimelineEvent(from: proto, milestoneTitle: "Protocol Start: \(proto.name)", timestamp: proto.startDate))
            if let end = proto.endDate {
                events.append(TimelineEvent(from: proto, milestoneTitle: "Protocol End: \(proto.name)", timestamp: end))
            }
        }
        for rev in protocolRevisions {
            events.append(TimelineEvent(from: rev))
        }
        for inv in inventoryEvents {
            events.append(TimelineEvent(from: inv))
        }
        for symptom in symptoms {
            events.append(TimelineEvent(from: symptom))
        }

        return events.sorted(by: { $0.timestamp > $1.timestamp })
    }
}

// MARK: - Timeline Category
public enum TimelineCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case dose = "Dose Event"
    case measurement = "Health Measurement"
    case labPanel = "Laboratory Diagnostic"
    case protocolChange = "Protocol Change"
    case protocolMilestone = "Protocol Milestone"
    case inventory = "Inventory & Supplies"
    case reconstitution = "Vial Reconstitution"
    case document = "Uploaded Document"
    case symptom = "Symptom & Subjective"
    case custom = "General Event"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .dose: return "Doses"
        case .measurement: return "Metrics"
        case .labPanel: return "Bloodwork"
        case .protocolChange, .protocolMilestone: return "Protocols"
        case .inventory: return "Inventory"
        case .reconstitution: return "Reconstitution"
        case .document: return "Documents"
        case .symptom: return "Symptoms"
        case .custom: return "Custom"
        }
    }

    public var iconName: String {
        switch self {
        case .dose: return "syringe.fill"
        case .measurement: return "waveform.path.ecg.rectangle.fill"
        case .labPanel: return "testtube.2"
        case .protocolChange, .protocolMilestone: return "slider.horizontal.3"
        case .inventory: return "cylinder.split.1x2.fill"
        case .reconstitution: return "cross.vial.fill"
        case .document: return "doc.text.fill"
        case .symptom: return "waveform.path.ecg"
        case .custom: return "circle.fill"
        }
    }

    public var badgeColorHex: String {
        switch self {
        case .dose: return "#10B981"
        case .measurement: return "#3B82F6"
        case .labPanel: return "#EC4899"
        case .protocolChange, .protocolMilestone: return "#8B5CF6"
        case .inventory: return "#F59E0B"
        case .reconstitution: return "#06B6D4"
        case .document: return "#6B7280"
        case .symptom: return "#F97316"
        case .custom: return "#9CA3AF"
        }
    }
}

// MARK: - Timeline Entity Type
public enum TimelineEntityType: String, Codable, Sendable, CaseIterable, Identifiable {
    case doseEvent = "DoseEvent"
    case measurement = "Measurement"
    case labPanel = "LabPanel"
    case reconstitutionRecord = "ReconstitutionRecord"
    case protocolModel = "ProtocolModel"
    case protocolRevision = "ProtocolRevision"
    case vial = "Vial"
    case inventoryEvent = "InventoryEvent"
    case document = "Document"
    case symptomLog = "SymptomLog"
    case custom = "Custom"

    public var id: String { rawValue }
}
