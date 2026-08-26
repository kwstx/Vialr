import Foundation

// MARK: - 1. Protocol Phase Type

/// Classification of distinct longitudinal protocol phases along the user's health journey.
public enum ProtocolPhaseType: String, Codable, Sendable, CaseIterable, Identifiable {
    case baseline = "Baseline (Pre-Protocol)"
    case activeProtocol = "Active Protocol"
    case titration = "Dose Change / Titration"
    case washout = "Washout / Rest Period"
    case followUp = "Follow-Up (Post-Protocol)"
    case unassigned = "General / Unassigned"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .baseline: return "Baseline"
        case .activeProtocol: return "Protocol"
        case .titration: return "Dose Change"
        case .washout: return "Washout"
        case .followUp: return "Follow-Up"
        case .unassigned: return "General"
        }
    }

    public var badgeColorHex: String {
        switch self {
        case .baseline: return "#6366F1" // Indigo
        case .activeProtocol: return "#10B981" // Emerald
        case .titration: return "#F59E0B" // Amber
        case .washout: return "#8B5CF6" // Violet
        case .followUp: return "#06B6D4" // Cyan
        case .unassigned: return "#6B7280" // Slate
        }
    }

    public var iconName: String {
        switch self {
        case .baseline: return "circle.dashed"
        case .activeProtocol: return "pills.fill"
        case .titration: return "arrow.triangle.swap"
        case .washout: return "pause.circle.fill"
        case .followUp: return "checkmark.shield.fill"
        case .unassigned: return "clock.fill"
        }
    }
}

// MARK: - 2. Laboratory Time Series Point

/// Represents a single biomarker analyte result modeled as an immutable time-series data point.
/// Conforms to `TimeSeriesDataPoint` allowing statistical aggregation and mathematical interpolation.
public struct LabTimeSeriesPoint: TimeSeriesDataPoint, Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var timestamp: Date // Specimen collection date
    public var value: Double
    public var secondaryValue: Double?
    public var unit: String
    public var source: MeasurementSource
    public var notes: String
    public var associatedProtocolId: UUID?

    // Analyte & Diagnostic Specifics
    public var biomarkerName: String
    public var category: LabCategory
    public var referenceRangeMin: Double?
    public var referenceRangeMax: Double?
    public var referenceRangeText: String?
    public var flag: LabResultFlag
    public var panelId: UUID
    public var panelName: String
    public var labName: String

    // Longitudinal Protocol Alignment Attributes
    public var protocolName: String?
    public var protocolPhase: ProtocolPhaseType
    public var daysOnProtocolAtDraw: Int?
    public var cumulativeDosePriorToDraw: Double?
    public var cumulativeDoseUnit: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        value: Double,
        secondaryValue: Double? = nil,
        unit: String,
        source: MeasurementSource = .labImport,
        notes: String = "",
        associatedProtocolId: UUID? = nil,
        biomarkerName: String,
        category: LabCategory = .metabolic,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        referenceRangeText: String? = nil,
        flag: LabResultFlag = .inRange,
        panelId: UUID = UUID(),
        panelName: String = "Laboratory Panel",
        labName: String = "Quest Diagnostics",
        protocolName: String? = nil,
        protocolPhase: ProtocolPhaseType = .unassigned,
        daysOnProtocolAtDraw: Int? = nil,
        cumulativeDosePriorToDraw: Double? = nil,
        cumulativeDoseUnit: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
        self.secondaryValue = secondaryValue
        self.unit = unit
        self.source = source
        self.notes = notes
        self.associatedProtocolId = associatedProtocolId
        self.biomarkerName = biomarkerName
        self.category = category
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.referenceRangeText = referenceRangeText
        self.flag = flag
        self.panelId = panelId
        self.panelName = panelName
        self.labName = labName
        self.protocolName = protocolName
        self.protocolPhase = protocolPhase
        self.daysOnProtocolAtDraw = daysOnProtocolAtDraw
        self.cumulativeDosePriorToDraw = cumulativeDosePriorToDraw
        self.cumulativeDoseUnit = cumulativeDoseUnit
    }

    /// Formatted value with unit (e.g., "845 ng/dL").
    public var formattedValue: String {
        let valStr = value.truncatingRemainder(dividingBy: 1) == 0 ?
            String(format: "%.0f", value) : String(format: "%.1f", value)
        return "\(valStr) \(unit)"
    }

    /// Reference range summary string (e.g. "300 – 1,000 ng/dL").
    public var formattedReferenceRange: String? {
        if let text = referenceRangeText, !text.isEmpty {
            return text
        }
        if let min = referenceRangeMin, let max = referenceRangeMax {
            let minStr = min.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", min) : String(format: "%.1f", min)
            let maxStr = max.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", max) : String(format: "%.1f", max)
            return "\(minStr) – \(maxStr) \(unit)"
        }
        return nil
    }

    /// Whether this point is within normal laboratory clinical reference limits.
    public var isNormal: Bool {
        flag == .inRange
    }
}

// MARK: - 3. Protocol Period Overlay

/// Represents an overlaid protocol period on the chronological axis for multi-phase comparison.
public struct ProtocolPeriodOverlay: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var protocolId: UUID?
    public var name: String
    public var phaseType: ProtocolPhaseType
    public var startDate: Date
    public var endDate: Date? // nil means active/ongoing
    public var colorHex: String
    public var compoundsSummary: String
    public var totalDosesAdministered: Int
    public var adherencePercentage: Double?
    public var notes: String
    public var isOngoing: Bool

    public init(
        id: UUID = UUID(),
        protocolId: UUID? = nil,
        name: String,
        phaseType: ProtocolPhaseType = .activeProtocol,
        startDate: Date,
        endDate: Date? = nil,
        colorHex: String = "#10B981",
        compoundsSummary: String = "",
        totalDosesAdministered: Int = 0,
        adherencePercentage: Double? = nil,
        notes: String = "",
        isOngoing: Bool = false
    ) {
        self.id = id
        self.protocolId = protocolId
        self.name = name
        self.phaseType = phaseType
        self.startDate = startDate
        self.endDate = endDate
        self.colorHex = colorHex
        self.compoundsSummary = compoundsSummary
        self.totalDosesAdministered = totalDosesAdministered
        self.adherencePercentage = adherencePercentage
        self.notes = notes
        self.isOngoing = isOngoing
    }

    /// Number of elapsed days in this protocol period.
    public var durationDays: Int {
        let end = endDate ?? Date()
        let diff = Calendar.current.dateComponents([.day], from: startDate, to: end).day ?? 0
        return max(1, diff)
    }

    /// Whether a target date falls inside this protocol period window.
    public func contains(date: Date) -> Bool {
        if date < startDate { return false }
        if let end = endDate, date > end { return false }
        return true
    }
}

// MARK: - 4. Aligned Event Type & Unified Item

/// Strongly-typed classification of all events aligned on the chronological axis.
public enum AlignedEventType: String, Codable, Sendable, CaseIterable, Identifiable {
    case baselineDraw = "Baseline Blood Draw"
    case protocolStart = "Protocol Initiated"
    case doseAdministered = "Dose Administered"
    case doseMissed = "Dose Missed"
    case doseChange = "Dose / Compound Change"
    case measurement = "Health Measurement"
    case labResult = "Laboratory Diagnostic"
    case symptomLog = "Symptom Log"
    case protocolEnd = "Protocol Completed"
    case followUpLab = "Follow-Up Blood Draw"

    public var id: String { rawValue }

    public var badgeColorHex: String {
        switch self {
        case .baselineDraw: return "#6366F1"
        case .protocolStart: return "#10B981"
        case .doseAdministered: return "#06B6D4"
        case .doseMissed: return "#EF4444"
        case .doseChange: return "#F59E0B"
        case .measurement: return "#3B82F6"
        case .labResult: return "#14B8A6"
        case .symptomLog: return "#EC4899"
        case .protocolEnd: return "#8B5CF6"
        case .followUpLab: return "#059669"
        }
    }

    public var iconName: String {
        switch self {
        case .baselineDraw: return "testtube.2"
        case .protocolStart: return "play.circle.fill"
        case .doseAdministered: return "syringe.fill"
        case .doseMissed: return "xmark.circle.fill"
        case .doseChange: return "arrow.triangle.swap"
        case .measurement: return "ruler.fill"
        case .labResult: return "cross.vial.fill"
        case .symptomLog: return "heart.text.square.fill"
        case .protocolEnd: return "flag.checkered"
        case .followUpLab: return "sparkles"
        }
    }
}

/// A unified chronological item on the single time axis aligning doses, changes, measurements, and lab results.
public struct AlignedTimelineItem: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var timestamp: Date
    public var type: AlignedEventType
    public var title: String
    public var subtitle: String
    public var detail: String?
    public var valueString: String?
    public var badgeText: String?
    public var badgeColorHex: String
    public var associatedEntityId: UUID?
    public var associatedProtocolId: UUID?
    public var protocolName: String?
    public var phaseType: ProtocolPhaseType
    public var isHighlighted: Bool
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: AlignedEventType,
        title: String,
        subtitle: String,
        detail: String? = nil,
        valueString: String? = nil,
        badgeText: String? = nil,
        badgeColorHex: String = "#06B6D4",
        associatedEntityId: UUID? = nil,
        associatedProtocolId: UUID? = nil,
        protocolName: String? = nil,
        phaseType: ProtocolPhaseType = .unassigned,
        isHighlighted: Bool = false,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.valueString = valueString
        self.badgeText = badgeText ?? type.rawValue
        self.badgeColorHex = badgeColorHex
        self.associatedEntityId = associatedEntityId
        self.associatedProtocolId = associatedProtocolId
        self.protocolName = protocolName
        self.phaseType = phaseType
        self.isHighlighted = isHighlighted
        self.metadata = metadata
    }
}

// MARK: - 5. Phase Transition Milestone

/// Represents an anchor milestone in the user's sequential journey:
/// e.g. Baseline → Protocol A → Dose Change → Protocol B → Follow-up Lab
public struct PhaseTransitionMilestone: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var phaseName: String
    public var phaseType: ProtocolPhaseType
    public var date: Date
    public var durationDays: Int?
    public var analyteValue: Double?
    public var analyteUnit: String?
    public var analyteFlag: LabResultFlag?
    public var deltaFromPrevious: Double?
    public var percentageDeltaFromPrevious: Double?
    public var deltaFromBaseline: Double?
    public var percentageDeltaFromBaseline: Double?
    public var protocolName: String?
    public var notes: String?

    public init(
        id: UUID = UUID(),
        phaseName: String,
        phaseType: ProtocolPhaseType,
        date: Date,
        durationDays: Int? = nil,
        analyteValue: Double? = nil,
        analyteUnit: String? = nil,
        analyteFlag: LabResultFlag? = nil,
        deltaFromPrevious: Double? = nil,
        percentageDeltaFromPrevious: Double? = nil,
        deltaFromBaseline: Double? = nil,
        percentageDeltaFromBaseline: Double? = nil,
        protocolName: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.phaseName = phaseName
        self.phaseType = phaseType
        self.date = date
        self.durationDays = durationDays
        self.analyteValue = analyteValue
        self.analyteUnit = analyteUnit
        self.analyteFlag = analyteFlag
        self.deltaFromPrevious = deltaFromPrevious
        self.percentageDeltaFromPrevious = percentageDeltaFromPrevious
        self.deltaFromBaseline = deltaFromBaseline
        self.percentageDeltaFromBaseline = percentageDeltaFromBaseline
        self.protocolName = protocolName
        self.notes = notes
    }

    /// Formatted value string.
    public var formattedValue: String? {
        guard let val = analyteValue, let unit = analyteUnit else { return nil }
        let valStr = val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(format: "%.1f", val)
        return "\(valStr) \(unit)"
    }
}

// MARK: - 6. Biomarker Phase Delta

/// Quantitative differential of a biomarker across two distinct protocol periods.
public struct BiomarkerPhaseDelta: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var biomarkerName: String
    public var unit: String
    public var fromPhaseName: String
    public var toPhaseName: String
    public var fromValue: Double
    public var toValue: Double
    public var fromDate: Date
    public var toDate: Date
    public var absoluteDelta: Double
    public var percentageChange: Double
    public var ratePerWeek: Double?
    public var isImprovement: Bool?
    public var clinicalInterpretation: String

    public init(
        id: UUID = UUID(),
        biomarkerName: String,
        unit: String,
        fromPhaseName: String,
        toPhaseName: String,
        fromValue: Double,
        toValue: Double,
        fromDate: Date,
        toDate: Date,
        absoluteDelta: Double,
        percentageChange: Double,
        ratePerWeek: Double? = nil,
        isImprovement: Bool? = nil,
        clinicalInterpretation: String = ""
    ) {
        self.id = id
        self.biomarkerName = biomarkerName
        self.unit = unit
        self.fromPhaseName = fromPhaseName
        self.toPhaseName = toPhaseName
        self.fromValue = fromValue
        self.toValue = toValue
        self.fromDate = fromDate
        self.toDate = toDate
        self.absoluteDelta = absoluteDelta
        self.percentageChange = percentageChange
        self.ratePerWeek = ratePerWeek
        self.isImprovement = isImprovement
        self.clinicalInterpretation = clinicalInterpretation
    }
}

// MARK: - 7. Complete Laboratory Timeline Analysis

/// Aggregated output container for the entire laboratory timeline and event alignment engine.
public struct LaboratoryTimelineAnalysis: Codable, Sendable {
    public var selectedBiomarkerName: String?
    public var biomarkerTimeSeries: [String: [LabTimeSeriesPoint]] // Keyed by biomarker name
    public var availableBiomarkers: [String]
    public var alignedEvents: [AlignedTimelineItem]
    public var protocolOverlays: [ProtocolPeriodOverlay]
    public var phaseMilestones: [PhaseTransitionMilestone]
    public var phaseDeltas: [BiomarkerPhaseDelta]
    public var startDate: Date?
    public var endDate: Date?
    public var totalLabDraws: Int
    public var totalDosesAligned: Int
    public var totalProtocolChanges: Int
    public var overallSummaryText: String

    public init(
        selectedBiomarkerName: String? = nil,
        biomarkerTimeSeries: [String: [LabTimeSeriesPoint]] = [:],
        availableBiomarkers: [String] = [],
        alignedEvents: [AlignedTimelineItem] = [],
        protocolOverlays: [ProtocolPeriodOverlay] = [],
        phaseMilestones: [PhaseTransitionMilestone] = [],
        phaseDeltas: [BiomarkerPhaseDelta] = [],
        startDate: Date? = nil,
        endDate: Date? = nil,
        totalLabDraws: Int = 0,
        totalDosesAligned: Int = 0,
        totalProtocolChanges: Int = 0,
        overallSummaryText: String = ""
    ) {
        self.selectedBiomarkerName = selectedBiomarkerName
        self.biomarkerTimeSeries = biomarkerTimeSeries
        self.availableBiomarkers = availableBiomarkers
        self.alignedEvents = alignedEvents
        self.protocolOverlays = protocolOverlays
        self.phaseMilestones = phaseMilestones
        self.phaseDeltas = phaseDeltas
        self.startDate = startDate
        self.endDate = endDate
        self.totalLabDraws = totalLabDraws
        self.totalDosesAligned = totalDosesAligned
        self.totalProtocolChanges = totalProtocolChanges
        self.overallSummaryText = overallSummaryText
    }

    /// Points for the currently selected biomarker, sorted chronologically.
    public var activePoints: [LabTimeSeriesPoint] {
        guard let name = selectedBiomarkerName, let pts = biomarkerTimeSeries[name] else {
            return []
        }
        return pts.sorted(by: { $0.timestamp < $1.timestamp })
    }
}
