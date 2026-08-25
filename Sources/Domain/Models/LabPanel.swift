import Foundation

/// Represents a collection of laboratory results from a single diagnostic event (blood draw, urinalysis, salivary panel).
/// Groups individual `LabResult` objects together with specimen dates, laboratory provider details, and clinical ranges.
public struct LabPanel: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var userId: UUID?
    public var panelName: String
    public var labName: String
    public var collectionDate: Date
    public var resultDate: Date?
    public var status: LabPanelStatus
    public var results: [LabResult]
    public var orderingPhysician: String?
    public var associatedProtocolId: UUID?
    public var documentFileId: UUID? // Reference to original PDF / scan in encrypted object storage
    public var fastingStatus: LabFastingStatus
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        panelName: String,
        labName: String = "Quest Diagnostics",
        collectionDate: Date = Date(),
        resultDate: Date? = nil,
        status: LabPanelStatus = .completed,
        results: [LabResult] = [],
        orderingPhysician: String? = nil,
        associatedProtocolId: UUID? = nil,
        documentFileId: UUID? = nil,
        fastingStatus: LabFastingStatus = .fasted,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.panelName = panelName
        self.labName = labName
        self.collectionDate = collectionDate
        self.resultDate = resultDate ?? collectionDate
        self.status = status
        self.results = results
        self.orderingPhysician = orderingPhysician
        self.associatedProtocolId = associatedProtocolId
        self.documentFileId = documentFileId
        self.fastingStatus = fastingStatus
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Clinical Analytics Helpers
    /// Returns all results that fall outside the standard reference range.
    public var abnormalResults: [LabResult] {
        results.filter { $0.flag != .inRange }
    }

    /// Returns results flagged as critical (critical high or critical low).
    public var criticalResults: [LabResult] {
        results.filter { $0.flag == .criticalHigh || $0.flag == .criticalLow }
    }

    /// Whether any analyte in this panel is out of range.
    public var hasAbnormalResults: Bool {
        !abnormalResults.isEmpty
    }

    /// Number of total biomarker analytes in this panel.
    public var resultCount: Int {
        results.count
    }

    /// Looks up a specific biomarker result by name (case-insensitive).
    public func result(forBiomarker name: String) -> LabResult? {
        results.first { $0.biomarkerName.localizedCaseInsensitiveContains(name) }
    }
}

// MARK: - Individual Lab Result Analyte
/// Represents a single quantitative or qualitative laboratory biomarker outcome belonging to a `LabPanel`.
public struct LabResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var panelId: UUID?
    public var biomarkerName: String
    public var category: LabCategory
    public var value: Double
    public var textValue: String?
    public var unit: String
    public var referenceRangeMin: Double?
    public var referenceRangeMax: Double?
    public var referenceRangeText: String?
    public var flag: LabResultFlag
    public var notes: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        panelId: UUID? = nil,
        biomarkerName: String,
        category: LabCategory = .metabolic,
        value: Double,
        textValue: String? = nil,
        unit: String,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        referenceRangeText: String? = nil,
        flag: LabResultFlag? = nil,
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.panelId = panelId
        self.biomarkerName = biomarkerName
        self.category = category
        self.value = value
        self.textValue = textValue
        self.unit = unit
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.referenceRangeText = referenceRangeText
        
        // Auto-calculate flag if not explicitly provided
        if let explicitFlag = flag {
            self.flag = explicitFlag
        } else {
            if let min = referenceRangeMin, value < min {
                self.flag = .low
            } else if let max = referenceRangeMax, value > max {
                self.flag = .high
            } else {
                self.flag = .inRange
            }
        }
        
        self.notes = notes
        self.createdAt = createdAt
    }

    /// Nicely formatted result string (e.g., "245 ng/mL")
    public var formattedValue: String {
        if let text = textValue, !text.isEmpty {
            return "\(text) \(unit)"
        }
        let valStr = String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", value)
        return "\(valStr) \(unit)"
    }

    /// Whether this specific analyte is within normal reference bounds.
    public var isNormal: Bool {
        flag == .inRange
    }
}

// MARK: - Supporting Enums

public enum LabPanelStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case ordered = "Ordered"
    case collected = "Specimen Collected"
    case processing = "In Lab Processing"
    case completed = "Completed & Final"
    case cancelled = "Cancelled"

    public var id: String { rawValue }

    public var badgeColorHex: String {
        switch self {
        case .ordered: return "#3B82F6"
        case .collected: return "#8B5CF6"
        case .processing: return "#F59E0B"
        case .completed: return "#10B981"
        case .cancelled: return "#6B7280"
        }
    }
}

public enum LabCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case hormones = "Hormones & Endocrine"
    case metabolic = "Metabolic & Glucose"
    case lipids = "Lipid Panel & Cardiovascular"
    case cbcHematology = "Complete Blood Count (CBC)"
    case liverHepatic = "Liver & Hepatic Function"
    case kidneyRenal = "Kidney & Renal Function"
    case inflammatory = "Inflammatory & Immune Markers"
    case thyroid = "Thyroid Panel"
    case vitaminsElectrolytes = "Vitamins & Electrolytes"
    case custom = "Other / Custom Panel"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .hormones: return "waveform.path.ecg"
        case .metabolic: return "flame.fill"
        case .lipids: return "heart.fill"
        case .cbcHematology: return "drop.fill"
        case .liverHepatic: return "cross.vial.fill"
        case .kidneyRenal: return "circle.grid.2x1.fill"
        case .inflammatory: return "shield.lefthalf.filled"
        case .thyroid: return "bolt.shield.fill"
        case .vitaminsElectrolytes: return "pills.fill"
        case .custom: return "testtube.2"
        }
    }
}

public enum LabResultFlag: String, Codable, Sendable, CaseIterable, Identifiable {
    case inRange = "Normal / In Range"
    case low = "Low"
    case high = "High"
    case criticalLow = "Critical Low"
    case criticalHigh = "Critical High"
    case abnormal = "Abnormal"

    public var id: String { rawValue }

    public var badgeColorHex: String {
        switch self {
        case .inRange: return "#10B981"
        case .low, .high: return "#F59E0B"
        case .criticalLow, .criticalHigh, .abnormal: return "#EF4444"
        }
    }
}

public enum LabFastingStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case fasted = "Fasting (8–12 hrs)"
    case nonFasting = "Non-Fasting"
    case unspecified = "Unspecified"

    public var id: String { rawValue }
}
