import Foundation

/// Defines a structured, chronological medical report exportable for physicians, endocrinologists, or wellness clinicians.
public struct ClinicianReport: Identifiable, Codable, Sendable {
    public let id: UUID
    public var patientIdentifier: String
    public var patientDateOfBirth: String?
    public var clinicianName: String
    public var practiceOrClinic: String
    public var generatedDate: Date
    public var dateRangeStart: Date
    public var dateRangeEnd: Date
    public var activeProtocols: [ProtocolModel]
    public var historicalProtocols: [ProtocolModel]
    public var doseSummary: [CompoundDoseSummary]
    public var adherencePercentage: Double
    public var totalDosesScheduled: Int
    public var totalDosesAdministered: Int
    public var totalDosesMissed: Int
    public var totalDosesSkipped: Int
    public var latestBiomarkers: [Biomarker]
    public var labPanels: [BiomarkerPanelSummary]
    public var measurementSummaries: [MeasurementMetricSummary]
    public var symptomSummary: SymptomQualitySummary?
    public var chronologicalLedger: [ClinicianLedgerItem]
    public var subjectiveTrendsSummary: String
    public var clinicalNotes: String
    public var patientObservations: String

    public init(
        id: UUID = UUID(),
        patientIdentifier: String = "Patient / Self",
        patientDateOfBirth: String? = nil,
        clinicianName: String = "Attending Physician",
        practiceOrClinic: String = "Medical Practice / Clinic",
        generatedDate: Date = Date(),
        dateRangeStart: Date,
        dateRangeEnd: Date,
        activeProtocols: [ProtocolModel] = [],
        historicalProtocols: [ProtocolModel] = [],
        doseSummary: [CompoundDoseSummary] = [],
        adherencePercentage: Double = 0.0,
        totalDosesScheduled: Int = 0,
        totalDosesAdministered: Int = 0,
        totalDosesMissed: Int = 0,
        totalDosesSkipped: Int = 0,
        latestBiomarkers: [Biomarker] = [],
        labPanels: [BiomarkerPanelSummary] = [],
        measurementSummaries: [MeasurementMetricSummary] = [],
        symptomSummary: SymptomQualitySummary? = nil,
        chronologicalLedger: [ClinicianLedgerItem] = [],
        subjectiveTrendsSummary: String = "",
        clinicalNotes: String = "",
        patientObservations: String = ""
    ) {
        self.id = id
        self.patientIdentifier = patientIdentifier
        self.patientDateOfBirth = patientDateOfBirth
        self.clinicianName = clinicianName
        self.practiceOrClinic = practiceOrClinic
        self.generatedDate = generatedDate
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.activeProtocols = activeProtocols
        self.historicalProtocols = historicalProtocols
        self.doseSummary = doseSummary
        self.adherencePercentage = adherencePercentage
        self.totalDosesScheduled = totalDosesScheduled
        self.totalDosesAdministered = totalDosesAdministered
        self.totalDosesMissed = totalDosesMissed
        self.totalDosesSkipped = totalDosesSkipped
        self.latestBiomarkers = latestBiomarkers
        self.labPanels = labPanels
        self.measurementSummaries = measurementSummaries
        self.symptomSummary = symptomSummary
        self.chronologicalLedger = chronologicalLedger
        self.subjectiveTrendsSummary = subjectiveTrendsSummary
        self.clinicalNotes = clinicalNotes
        self.patientObservations = patientObservations
    }

    /// Total count of all recorded events across the date range.
    public var totalLedgerCount: Int {
        chronologicalLedger.count
    }

    /// Count of abnormal lab findings in the report.
    public var abnormalBiomarkersCount: Int {
        labPanels.flatMap(\.results).filter(\.isAbnormal).count
    }
}

// MARK: - Compound Dosing Summary
public struct CompoundDoseSummary: Identifiable, Codable, Sendable {
    public var id: UUID
    public var compoundName: String
    public var totalDoseDelivered: Double
    public var unit: DoseUnit
    public var averageDose: Double
    public var numberOfInjections: Int
    public var mostFrequentSite: String
    public var route: String
    public var compliancePercentage: Double

    public init(
        id: UUID = UUID(),
        compoundName: String,
        totalDoseDelivered: Double,
        unit: DoseUnit,
        averageDose: Double,
        numberOfInjections: Int,
        mostFrequentSite: String = "SubQ (Abdomen)",
        route: String = "Subcutaneous (SubQ)",
        compliancePercentage: Double = 100.0
    ) {
        self.id = id
        self.compoundName = compoundName
        self.totalDoseDelivered = totalDoseDelivered
        self.unit = unit
        self.averageDose = averageDose
        self.numberOfInjections = numberOfInjections
        self.mostFrequentSite = mostFrequentSite
        self.route = route
        self.compliancePercentage = compliancePercentage
    }
}

// MARK: - Chronological Clinical Ledger Item
public struct ClinicianLedgerItem: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var timestamp: Date
    public var category: ClinicianLedgerCategory
    public var title: String
    public var subtitle: String
    public var detail: String?
    public var metricsSummary: String?
    public var statusOrFlag: String?
    public var statusColorHex: String?
    public var associatedProtocolName: String?
    public var isHighlighted: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        category: ClinicianLedgerCategory,
        title: String,
        subtitle: String,
        detail: String? = nil,
        metricsSummary: String? = nil,
        statusOrFlag: String? = nil,
        statusColorHex: String? = nil,
        associatedProtocolName: String? = nil,
        isHighlighted: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.metricsSummary = metricsSummary
        self.statusOrFlag = statusOrFlag
        self.statusColorHex = statusColorHex
        self.associatedProtocolName = associatedProtocolName
        self.isHighlighted = isHighlighted
    }
}

public enum ClinicianLedgerCategory: String, Codable, Sendable, CaseIterable {
    case doseAdministered = "Dose Administered"
    case doseMissed = "Dose Missed"
    case doseSkipped = "Dose Skipped"
    case protocolStart = "Protocol Initiated"
    case protocolEnd = "Protocol Concluded"
    case protocolTitration = "Protocol Titration"
    case labDiagnostic = "Laboratory Bloodwork"
    case vitalMeasurement = "Vitals / Physical Metric"
    case symptomLog = "Symptom & Well-Being"
    case clinicalNote = "Clinical Observation"

    public var iconName: String {
        switch self {
        case .doseAdministered: return "syringe.fill"
        case .doseMissed: return "exclamationmark.circle.fill"
        case .doseSkipped: return "arrow.uturn.right.circle.fill"
        case .protocolStart: return "play.circle.fill"
        case .protocolEnd: return "stop.circle.fill"
        case .protocolTitration: return "arrow.triangle.2.circlepath.circle.fill"
        case .labDiagnostic: return "testtube.2"
        case .vitalMeasurement: return "heart.text.square.fill"
        case .symptomLog: return "waveform.path.ecg"
        case .clinicalNote: return "note.text"
        }
    }

    public var defaultColorHex: String {
        switch self {
        case .doseAdministered: return "#10B981"
        case .doseMissed: return "#EF4444"
        case .doseSkipped: return "#F59E0B"
        case .protocolStart: return "#06B6D4"
        case .protocolEnd: return "#64748B"
        case .protocolTitration: return "#8B5CF6"
        case .labDiagnostic: return "#3B82F6"
        case .vitalMeasurement: return "#14B8A6"
        case .symptomLog: return "#EC4899"
        case .clinicalNote: return "#A855F7"
        }
    }
}

// MARK: - Laboratory Panel & Biomarker Summary
public struct BiomarkerPanelSummary: Identifiable, Codable, Sendable {
    public let panelId: UUID
    public var panelName: String
    public var labName: String
    public var collectionDate: Date
    public var notes: String
    public var results: [BiomarkerResultSummary]

    public var id: UUID { panelId }

    public init(
        panelId: UUID = UUID(),
        panelName: String,
        labName: String = "Quest Diagnostics / Labcorp",
        collectionDate: Date = Date(),
        notes: String = "",
        results: [BiomarkerResultSummary] = []
    ) {
        self.panelId = panelId
        self.panelName = panelName
        self.labName = labName
        self.collectionDate = collectionDate
        self.notes = notes
        self.results = results
    }
}

public struct BiomarkerResultSummary: Identifiable, Codable, Sendable {
    public let id: UUID
    public var biomarkerName: String
    public var category: String
    public var value: Double
    public var textValue: String?
    public var unit: String
    public var referenceRangeMin: Double?
    public var referenceRangeMax: Double?
    public var referenceRangeText: String?
    public var flag: String // "Normal", "Low", "High", "Critical"
    public var isAbnormal: Bool

    public init(
        id: UUID = UUID(),
        biomarkerName: String,
        category: String = "Hormones",
        value: Double,
        textValue: String? = nil,
        unit: String,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        referenceRangeText: String? = nil,
        flag: String = "Normal",
        isAbnormal: Bool = false
    ) {
        self.id = id
        self.biomarkerName = biomarkerName
        self.category = category
        self.value = value
        self.textValue = textValue
        self.unit = unit
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.referenceRangeText = referenceRangeText
        self.flag = flag
        self.isAbnormal = isAbnormal
    }

    public var formattedValue: String {
        if let t = textValue, !t.isEmpty {
            return "\(t) \(unit)"
        }
        let valStr = String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", value)
        return "\(valStr) \(unit)"
    }

    public var referenceRangeDisplay: String {
        if let t = referenceRangeText, !t.isEmpty {
            return t
        }
        if let min = referenceRangeMin, let max = referenceRangeMax {
            return "\(String(format: "%.1f", min)) – \(String(format: "%.1f", max)) \(unit)"
        }
        if let min = referenceRangeMin {
            return "≥ \(String(format: "%.1f", min)) \(unit)"
        }
        if let max = referenceRangeMax {
            return "≤ \(String(format: "%.1f", max)) \(unit)"
        }
        return "Not established"
    }
}

// MARK: - Measurement Metric Summary
public struct MeasurementMetricSummary: Identifiable, Codable, Sendable {
    public var id: String { metricName }
    public var category: String
    public var metricName: String
    public var latestValue: Double
    public var formattedValue: String
    public var unit: String
    public var status: String
    public var dateRecorded: Date
    public var entryCount: Int
    public var minValue: Double?
    public var maxValue: Double?
    public var averageValue: Double?
    public var referenceRangeText: String?

    public init(
        category: String,
        metricName: String,
        latestValue: Double,
        formattedValue: String,
        unit: String,
        status: String = "Normal",
        dateRecorded: Date = Date(),
        entryCount: Int = 1,
        minValue: Double? = nil,
        maxValue: Double? = nil,
        averageValue: Double? = nil,
        referenceRangeText: String? = nil
    ) {
        self.category = category
        self.metricName = metricName
        self.latestValue = latestValue
        self.formattedValue = formattedValue
        self.unit = unit
        self.status = status
        self.dateRecorded = dateRecorded
        self.entryCount = entryCount
        self.minValue = minValue
        self.maxValue = maxValue
        self.averageValue = averageValue
        self.referenceRangeText = referenceRangeText
    }
}

// MARK: - Symptom Quality Summary
public struct SymptomQualitySummary: Codable, Sendable {
    public var averageEnergy: Double
    public var averageSleepQuality: Double
    public var averageRecovery: Double
    public var averageMood: Double
    public var averagePain: Double?
    public var averageWellbeingScore: Double
    public var totalLogsCount: Int
    public var reportedSideEffects: [String]
    public var frequentNotes: [String]

    public init(
        averageEnergy: Double = 7.0,
        averageSleepQuality: Double = 7.0,
        averageRecovery: Double = 7.0,
        averageMood: Double = 7.0,
        averagePain: Double? = nil,
        averageWellbeingScore: Double = 70.0,
        totalLogsCount: Int = 0,
        reportedSideEffects: [String] = [],
        frequentNotes: [String] = []
    ) {
        self.averageEnergy = averageEnergy
        self.averageSleepQuality = averageSleepQuality
        self.averageRecovery = averageRecovery
        self.averageMood = averageMood
        self.averagePain = averagePain
        self.averageWellbeingScore = averageWellbeingScore
        self.totalLogsCount = totalLogsCount
        self.reportedSideEffects = reportedSideEffects
        self.frequentNotes = frequentNotes
    }
}

// MARK: - Report Configuration Options
public struct ClinicianReportConfiguration: Codable, Sendable {
    public var preset: DateRangePreset
    public var customStartDate: Date
    public var customEndDate: Date
    public var patientName: String
    public var patientDateOfBirth: String
    public var clinicianName: String
    public var practiceOrClinic: String
    public var patientNotes: String
    public var includeProtocols: Bool
    public var includeDoses: Bool
    public var includeLabs: Bool
    public var includeMeasurements: Bool
    public var includeSymptoms: Bool
    public var includeNotes: Bool

    public init(
        preset: DateRangePreset = .last30Days,
        customStartDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
        customEndDate: Date = Date(),
        patientName: String = "Patient / Self",
        patientDateOfBirth: String = "",
        clinicianName: String = "Attending Physician",
        practiceOrClinic: String = "Endocrinology & Longevity Medicine",
        patientNotes: String = "",
        includeProtocols: Bool = true,
        includeDoses: Bool = true,
        includeLabs: Bool = true,
        includeMeasurements: Bool = true,
        includeSymptoms: Bool = true,
        includeNotes: Bool = true
    ) {
        self.preset = preset
        self.customStartDate = customStartDate
        self.customEndDate = customEndDate
        self.patientName = patientName
        self.patientDateOfBirth = patientDateOfBirth
        self.clinicianName = clinicianName
        self.practiceOrClinic = practiceOrClinic
        self.patientNotes = patientNotes
        self.includeProtocols = includeProtocols
        self.includeDoses = includeDoses
        self.includeLabs = includeLabs
        self.includeMeasurements = includeMeasurements
        self.includeSymptoms = includeSymptoms
        self.includeNotes = includeNotes
    }

    public var effectiveDateInterval: DateInterval {
        let now = Date()
        let cal = Calendar.current
        switch preset {
        case .last7Days:
            let start = cal.date(byAdding: .day, value: -7, to: now) ?? now
            return DateInterval(start: start, end: now)
        case .last30Days:
            let start = cal.date(byAdding: .day, value: -30, to: now) ?? now
            return DateInterval(start: start, end: now)
        case .last90Days:
            let start = cal.date(byAdding: .day, value: -90, to: now) ?? now
            return DateInterval(start: start, end: now)
        case .last6Months:
            let start = cal.date(byAdding: .month, value: -6, to: now) ?? now
            return DateInterval(start: start, end: now)
        case .lastYear:
            let start = cal.date(byAdding: .year, value: -1, to: now) ?? now
            return DateInterval(start: start, end: now)
        case .allTime:
            let start = cal.date(byAdding: .year, value: -5, to: now) ?? now
            return DateInterval(start: start, end: now)
        case .custom:
            return DateInterval(start: min(customStartDate, customEndDate), end: max(customStartDate, customEndDate))
        }
    }
}

public enum DateRangePreset: String, Codable, Sendable, CaseIterable, Identifiable {
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case last90Days = "Last 90 Days"
    case last6Months = "Last 6 Months"
    case lastYear = "1 Year"
    case allTime = "All Time"
    case custom = "Custom Range"

    public var id: String { rawValue }
}
