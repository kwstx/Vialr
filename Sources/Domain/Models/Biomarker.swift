import Foundation

/// Represents a quantitative health measurement or clinical biomarker (bloodwork, vitals).
public struct Biomarker: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var category: BiomarkerCategory
    public var value: Double
    public var unit: String
    public var referenceRangeMin: Double?
    public var referenceRangeMax: Double?
    public var dateRecorded: Date
    public var source: MeasurementSource
    public var notes: String

    public init(
        id: UUID = UUID(),
        name: String,
        category: BiomarkerCategory,
        value: Double,
        unit: String,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        dateRecorded: Date = Date(),
        source: MeasurementSource = .manualEntry,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.value = value
        self.unit = unit
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.dateRecorded = dateRecorded
        self.source = source
        self.notes = notes
    }

    public var status: BiomarkerStatus {
        if let min = referenceRangeMin, value < min {
            return .low
        }
        if let max = referenceRangeMax, value > max {
            return .high
        }
        return .inRange
    }
}

public enum BiomarkerCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case bloodwork = "Bloodwork / Lab"
    case bodyComposition = "Body Composition"
    case cardiovascular = "Cardiovascular & Vitals"
    case metabolic = "Metabolic & Glucose"
    case sleepRecovery = "Sleep & Recovery"

    public var id: String { rawValue }
}

public enum MeasurementSource: String, Codable, Sendable, CaseIterable, Identifiable {
    case manualEntry = "Manual Entry"
    case appleHealth = "Apple Health"
    case labImport = "Lab PDF / OCR"
    case deviceSync = "Device Sync"

    public var id: String { rawValue }
}

public enum BiomarkerStatus: String, Codable, Sendable {
    case low = "Low"
    case inRange = "Optimal / Normal"
    case high = "High"

    public var colorHex: String {
        switch self {
        case .low: return "#F59E0B"
        case .inRange: return "#10B981"
        case .high: return "#EF4444"
        }
    }
}
