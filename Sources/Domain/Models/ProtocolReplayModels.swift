import Foundation

// MARK: - 1. Replay Event Category
public enum ReplayEventCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case dose = "Dose"
    case measurement = "Measurement"
    case labPanel = "Lab Bloodwork"
    case protocolRevision = "Protocol Change"
    case symptom = "Symptom Log"
    case milestone = "Milestone"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .dose: return "syringe.fill"
        case .measurement: return "waveform.path.ecg"
        case .labPanel: return "testtube.2"
        case .protocolRevision: return "arrow.triangle.swap"
        case .symptom: return "heart.text.square.fill"
        case .milestone: return "flag.fill"
        }
    }

    public var badgeColorHex: String {
        switch self {
        case .dose: return "#06B6D4" // Cyan
        case .measurement: return "#3B82F6" // Blue
        case .labPanel: return "#10B981" // Emerald
        case .protocolRevision: return "#F59E0B" // Amber
        case .symptom: return "#EC4899" // Pink
        case .milestone: return "#8B5CF6" // Violet
        }
    }
}

// MARK: - 2. Specific Event Payloads

/// Payload for a Dose Replay Event
public struct ReplayDosePayload: Codable, Sendable, Hashable {
    public var compoundId: UUID
    public var compoundName: String
    public var doseAmount: Double
    public var doseUnit: DoseUnit
    public var route: AdministrationRoute
    public var status: DoseEventStatus
    public var injectionSiteId: String?
    public var injectionSiteName: String?
    public var vialLotNumber: String?
    public var notes: String?
    public var isPRN: Bool

    public init(
        compoundId: UUID,
        compoundName: String,
        doseAmount: Double,
        doseUnit: DoseUnit = .mcg,
        route: AdministrationRoute = .subcutaneous,
        status: DoseEventStatus = .taken,
        injectionSiteId: String? = nil,
        injectionSiteName: String? = nil,
        vialLotNumber: String? = nil,
        notes: String? = nil,
        isPRN: Bool = false
    ) {
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.route = route
        self.status = status
        self.injectionSiteId = injectionSiteId
        self.injectionSiteName = injectionSiteName
        self.vialLotNumber = vialLotNumber
        self.notes = notes
        self.isPRN = isPRN
    }

    public var formattedDose: String {
        let valStr = doseAmount.truncatingRemainder(dividingBy: 1) == 0 ?
            String(format: "%.0f", doseAmount) : String(format: "%.1f", doseAmount)
        return "\(valStr) \(doseUnit.rawValue)"
    }
}

/// Payload for a Biometric or Physical Measurement Replay Event
public struct ReplayMeasurementPayload: Codable, Sendable, Hashable {
    public var measurementId: UUID
    public var name: String
    public var type: MeasurementType
    public var category: MeasurementCategory
    public var value: Double
    public var secondaryValue: Double?
    public var unit: String
    public var deltaFromBaseline: Double?
    public var deltaFromPrevious: Double?
    public var status: MeasurementStatus
    public var isBaseline: Bool
    public var notes: String?

    public init(
        measurementId: UUID,
        name: String,
        type: MeasurementType,
        category: MeasurementCategory = .bodyComposition,
        value: Double,
        secondaryValue: Double? = nil,
        unit: String,
        deltaFromBaseline: Double? = nil,
        deltaFromPrevious: Double? = nil,
        status: MeasurementStatus = .inRange,
        isBaseline: Bool = false,
        notes: String? = nil
    ) {
        self.measurementId = measurementId
        self.name = name
        self.type = type
        self.category = category
        self.value = value
        self.secondaryValue = secondaryValue
        self.unit = unit
        self.deltaFromBaseline = deltaFromBaseline
        self.deltaFromPrevious = deltaFromPrevious
        self.status = status
        self.isBaseline = isBaseline
        self.notes = notes
    }

    public var formattedValue: String {
        if type == .bloodPressure, let diastolic = secondaryValue {
            return "\(Int(value))/\(Int(diastolic)) \(unit)"
        }
        let valStr = value.truncatingRemainder(dividingBy: 1) == 0 ?
            String(format: "%.0f", value) : String(format: "%.1f", value)
        return "\(valStr) \(unit)"
    }
}

/// Highlighted biomarker analyte result in a lab panel
public struct ReplayBiomarkerAnalyte: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public var name: String
    public var value: Double
    public var unit: String
    public var flag: LabResultFlag
    public var referenceRangeText: String?
    public var deltaFromBaseline: Double?

    public init(
        id: UUID = UUID(),
        name: String,
        value: Double,
        unit: String,
        flag: LabResultFlag = .inRange,
        referenceRangeText: String? = nil,
        deltaFromBaseline: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.flag = flag
        self.referenceRangeText = referenceRangeText
        self.deltaFromBaseline = deltaFromBaseline
    }

    public var formattedValue: String {
        let valStr = value.truncatingRemainder(dividingBy: 1) == 0 ?
            String(format: "%.0f", value) : String(format: "%.1f", value)
        return "\(valStr) \(unit)"
    }
}

/// Payload for a Diagnostic Bloodwork Lab Panel Replay Event
public struct ReplayLabPayload: Codable, Sendable, Hashable {
    public var panelId: UUID
    public var panelName: String
    public var labName: String
    public var totalAnalytesCount: Int
    public var abnormalCount: Int
    public var highlightedAnalytes: [ReplayBiomarkerAnalyte]
    public var physicianNotes: String?
    public var isBaselineDraw: Bool

    public init(
        panelId: UUID,
        panelName: String,
        labName: String,
        totalAnalytesCount: Int,
        abnormalCount: Int,
        highlightedAnalytes: [ReplayBiomarkerAnalyte] = [],
        physicianNotes: String? = nil,
        isBaselineDraw: Bool = false
    ) {
        self.panelId = panelId
        self.panelName = panelName
        self.labName = labName
        self.totalAnalytesCount = totalAnalytesCount
        self.abnormalCount = abnormalCount
        self.highlightedAnalytes = highlightedAnalytes
        self.physicianNotes = physicianNotes
        self.isBaselineDraw = isBaselineDraw
    }
}

/// Dose adjustment item in a protocol revision
public struct ReplayDoseAdjustment: Codable, Sendable, Hashable {
    public var compoundName: String
    public var previousDose: Double
    public var newDose: Double
    public var doseUnit: DoseUnit
    public var previousSchedule: String?
    public var newSchedule: String?

    public init(
        compoundName: String,
        previousDose: Double,
        newDose: Double,
        doseUnit: DoseUnit,
        previousSchedule: String? = nil,
        newSchedule: String? = nil
    ) {
        self.compoundName = compoundName
        self.previousDose = previousDose
        self.newDose = newDose
        self.doseUnit = doseUnit
        self.previousSchedule = previousSchedule
        self.newSchedule = newSchedule
    }

    public var description: String {
        let prevStr = previousDose.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", previousDose) : String(format: "%.1f", previousDose)
        let newStr = newDose.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", newDose) : String(format: "%.1f", newDose)
        return "\(compoundName): \(prevStr) → \(newStr) \(doseUnit.rawValue)"
    }
}

/// Payload for a Protocol Modification / Titration Revision Replay Event
public struct ReplayRevisionPayload: Codable, Sendable, Hashable {
    public var revisionId: UUID
    public var revisionNumber: Int
    public var reasonForChange: String
    public var doseAdjustments: [ReplayDoseAdjustment]
    public var compoundsAdded: [String]
    public var compoundsRemoved: [String]
    public var effectiveDate: Date

    public init(
        revisionId: UUID,
        revisionNumber: Int,
        reasonForChange: String,
        doseAdjustments: [ReplayDoseAdjustment] = [],
        compoundsAdded: [String] = [],
        compoundsRemoved: [String] = [],
        effectiveDate: Date = Date()
    ) {
        self.revisionId = revisionId
        self.revisionNumber = revisionNumber
        self.reasonForChange = reasonForChange
        self.doseAdjustments = doseAdjustments
        self.compoundsAdded = compoundsAdded
        self.compoundsRemoved = compoundsRemoved
        self.effectiveDate = effectiveDate
    }
}

/// Payload for a Subjective Symptom & Well-Being Log Replay Event
public struct ReplaySymptomPayload: Codable, Sendable, Hashable {
    public var energyLevel: Int?
    public var sleepQuality: Int?
    public var recoveryScore: Int?
    public var moodScore: Int?
    public var painScore: Int?
    public var notes: String?

    public init(
        energyLevel: Int? = nil,
        sleepQuality: Int? = nil,
        recoveryScore: Int? = nil,
        moodScore: Int? = nil,
        painScore: Int? = nil,
        notes: String? = nil
    ) {
        self.energyLevel = energyLevel
        self.sleepQuality = sleepQuality
        self.recoveryScore = recoveryScore
        self.moodScore = moodScore
        self.painScore = painScore
        self.notes = notes
    }
}

/// Payload for a Protocol Milestone Replay Event
public struct ReplayMilestonePayload: Codable, Sendable, Hashable {
    public var title: String
    public var subtitle: String
    public var milestoneType: String

    public init(title: String, subtitle: String, milestoneType: String = "Phase") {
        self.title = title
        self.subtitle = subtitle
        self.milestoneType = milestoneType
    }
}

// MARK: - 3. Cumulative State Snapshot (Live Real-Time Context)

/// Represents the precise ground-truth state of the protocol at this exact timestamp in history.
public struct ReplayCumulativeState: Codable, Sendable, Hashable {
    public var protocolDay: Int
    public var elapsedDays: Int
    public var totalPlannedDays: Int?
    public var progressPercentage: Double?
    public var cumulativeDosesByCompound: [String: Double] // compoundName -> total amount
    public var cumulativeUnitsByCompound: [String: String] // compoundName -> unit string
    public var totalDosesAdministered: Int
    public var adherencePercentage: Double?
    public var latestMeasurements: [String: Measurement] // metric code/name -> latest measurement
    public var latestBiomarkers: [String: LabResult] // biomarker name -> latest lab result
    public var activeCompounds: [ProtocolCompound]

    public init(
        protocolDay: Int = 1,
        elapsedDays: Int = 0,
        totalPlannedDays: Int? = nil,
        progressPercentage: Double? = nil,
        cumulativeDosesByCompound: [String: Double] = [:],
        cumulativeUnitsByCompound: [String: String] = [:],
        totalDosesAdministered: Int = 0,
        adherencePercentage: Double? = nil,
        latestMeasurements: [String: Measurement] = [:],
        latestBiomarkers: [String: LabResult] = [:],
        activeCompounds: [ProtocolCompound] = []
    ) {
        self.protocolDay = protocolDay
        self.elapsedDays = elapsedDays
        self.totalPlannedDays = totalPlannedDays
        self.progressPercentage = progressPercentage
        self.cumulativeDosesByCompound = cumulativeDosesByCompound
        self.cumulativeUnitsByCompound = cumulativeUnitsByCompound
        self.totalDosesAdministered = totalDosesAdministered
        self.adherencePercentage = adherencePercentage
        self.latestMeasurements = latestMeasurements
        self.latestBiomarkers = latestBiomarkers
        self.activeCompounds = activeCompounds
    }

    /// Formatted summary of cumulative dose delivered for a compound.
    public func formattedCumulativeDose(for compoundName: String) -> String? {
        guard let amount = cumulativeDosesByCompound[compoundName] else { return nil }
        let unit = cumulativeUnitsByCompound[compoundName] ?? ""
        let valStr = amount.truncatingRemainder(dividingBy: 1) == 0 ?
            String(format: "%.0f", amount) : String(format: "%.1f", amount)
        return "\(valStr) \(unit)"
    }
}

// MARK: - 4. Unified Protocol Replay Event

/// Represents a single chronological event frame within the protocol history replay.
public struct ProtocolReplayEvent: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var timestamp: Date
    public var protocolDay: Int
    public var category: ReplayEventCategory
    public var title: String
    public var subtitle: String
    public var detailText: String?
    public var badgeText: String?
    public var badgeColorHex: String
    public var iconName: String
    public var isHighlighted: Bool

    // Specialized Payloads
    public var dosePayload: ReplayDosePayload?
    public var measurementPayload: ReplayMeasurementPayload?
    public var labPayload: ReplayLabPayload?
    public var revisionPayload: ReplayRevisionPayload?
    public var symptomPayload: ReplaySymptomPayload?
    public var milestonePayload: ReplayMilestonePayload?

    // Real-Time Cumulative State at this frame
    public var cumulativeState: ReplayCumulativeState?

    // Editorial narrative commentary for playback
    public var narrativeCommentary: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        protocolDay: Int = 1,
        category: ReplayEventCategory,
        title: String,
        subtitle: String,
        detailText: String? = nil,
        badgeText: String? = nil,
        badgeColorHex: String? = nil,
        iconName: String? = nil,
        isHighlighted: Bool = false,
        dosePayload: ReplayDosePayload? = nil,
        measurementPayload: ReplayMeasurementPayload? = nil,
        labPayload: ReplayLabPayload? = nil,
        revisionPayload: ReplayRevisionPayload? = nil,
        symptomPayload: ReplaySymptomPayload? = nil,
        milestonePayload: ReplayMilestonePayload? = nil,
        cumulativeState: ReplayCumulativeState? = nil,
        narrativeCommentary: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.protocolDay = protocolDay
        self.category = category
        self.title = title
        self.subtitle = subtitle
        self.detailText = detailText
        self.badgeText = badgeText ?? category.rawValue
        self.badgeColorHex = badgeColorHex ?? category.badgeColorHex
        self.iconName = iconName ?? category.iconName
        self.isHighlighted = isHighlighted
        self.dosePayload = dosePayload
        self.measurementPayload = measurementPayload
        self.labPayload = labPayload
        self.revisionPayload = revisionPayload
        self.symptomPayload = symptomPayload
        self.milestonePayload = milestonePayload
        self.cumulativeState = cumulativeState
        self.narrativeCommentary = narrativeCommentary
    }
}

// MARK: - 5. Replay Chapter Marker

/// Bookmarked milestone point in the replay sequence for rapid chapter navigation.
public struct ReplayChapter: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var eventIndex: Int
    public var title: String
    public var subtitle: String
    public var protocolDay: Int
    public var timestamp: Date
    public var iconName: String
    public var colorHex: String

    public init(
        id: UUID = UUID(),
        eventIndex: Int,
        title: String,
        subtitle: String,
        protocolDay: Int,
        timestamp: Date,
        iconName: String = "flag.fill",
        colorHex: String = "#10B981"
    ) {
        self.id = id
        self.eventIndex = eventIndex
        self.title = title
        self.subtitle = subtitle
        self.protocolDay = protocolDay
        self.timestamp = timestamp
        self.iconName = iconName
        self.colorHex = colorHex
    }
}

// MARK: - 6. Complete Protocol Replay Sequence

/// Encapsulates the entire sequentially rendered history of a protocol.
public struct ProtocolReplaySequence: Identifiable, Codable, Sendable {
    public let id: UUID
    public var protocolId: UUID
    public var protocolName: String
    public var startDate: Date
    public var endDate: Date?
    public var goalSummary: String
    public var colorHex: String
    public var events: [ProtocolReplayEvent]
    public var chapters: [ReplayChapter]
    public var totalDosesCount: Int
    public var totalMeasurementsCount: Int
    public var totalLabDrawsCount: Int
    public var totalRevisionsCount: Int
    public var overallAdherenceRate: Double?
    public var baselineMetricsSummary: [String: String]
    public var latestMetricsSummary: [String: String]

    public init(
        id: UUID = UUID(),
        protocolId: UUID,
        protocolName: String,
        startDate: Date,
        endDate: Date? = nil,
        goalSummary: String = "",
        colorHex: String = "#10B981",
        events: [ProtocolReplayEvent] = [],
        chapters: [ReplayChapter] = [],
        totalDosesCount: Int = 0,
        totalMeasurementsCount: Int = 0,
        totalLabDrawsCount: Int = 0,
        totalRevisionsCount: Int = 0,
        overallAdherenceRate: Double? = nil,
        baselineMetricsSummary: [String: String] = [:],
        latestMetricsSummary: [String: String] = [:]
    ) {
        self.id = id
        self.protocolId = protocolId
        self.protocolName = protocolName
        self.startDate = startDate
        self.endDate = endDate
        self.goalSummary = goalSummary
        self.colorHex = colorHex
        self.events = events
        self.chapters = chapters
        self.totalDosesCount = totalDosesCount
        self.totalMeasurementsCount = totalMeasurementsCount
        self.totalLabDrawsCount = totalLabDrawsCount
        self.totalRevisionsCount = totalRevisionsCount
        self.overallAdherenceRate = overallAdherenceRate
        self.baselineMetricsSummary = baselineMetricsSummary
        self.latestMetricsSummary = latestMetricsSummary
    }

    public var isEmpty: Bool {
        events.isEmpty
    }

    public var count: Int {
        events.count
    }
}

// MARK: - 7. Playback Speeds & Category Filters

public enum ReplayPlaybackSpeed: String, CaseIterable, Identifiable, Sendable {
    case slow = "0.5x"
    case normal = "1.0x"
    case fast = "2.0x"
    case hyper = "4.0x"

    public var id: String { rawValue }

    /// Interval in seconds between sequential event transitions
    public var stepIntervalSeconds: Double {
        switch self {
        case .slow: return 2.4
        case .normal: return 1.4
        case .fast: return 0.7
        case .hyper: return 0.35
        }
    }
}

public enum ReplayCategoryFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All Events"
    case doses = "Doses"
    case measurements = "Vitals & Weight"
    case labs = "Bloodwork"
    case revisions = "Protocol Changes"
    case symptoms = "Symptoms"

    public var id: String { rawValue }

    public var category: ReplayEventCategory? {
        switch self {
        case .all: return nil
        case .doses: return .dose
        case .measurements: return .measurement
        case .labs: return .labPanel
        case .revisions: return .protocolRevision
        case .symptoms: return .symptom
        }
    }
}
