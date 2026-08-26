import Foundation

/// Confidence level indicating OCR / extraction certainty for clinical candidate values.
public enum ExtractionConfidenceLevel: String, Codable, Sendable, CaseIterable, Identifiable {
    case high = "High Confidence"
    case medium = "Review Recommended"
    case low = "Low Confidence"

    public var id: String { rawValue }

    public var badgeColorHex: String {
        switch self {
        case .high: return "#10B981"
        case .medium: return "#F59E0B"
        case .low: return "#EF4444"
        }
    }

    public var iconName: String {
        switch self {
        case .high: return "checkmark.shield.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "questionmark.circle.fill"
        }
    }
}

/// Represents an individual candidate biomarker extracted from an uploaded medical laboratory document
/// by the document processing / OCR engine prior to explicit user confirmation.
public struct ExtractedLabCandidate: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var rawAnalyteName: String
    public var matchedCatalogId: String?
    public var resolvedName: String
    public var category: LabCategory
    public var extractedValue: Double
    public var extractedTextValue: String?
    public var extractedUnit: String
    public var referenceRangeMin: Double?
    public var referenceRangeMax: Double?
    public var referenceRangeText: String?
    public var detectedFlag: LabResultFlag
    public var confidenceScore: Double // 0.0 to 1.0
    public var rawSnippet: String
    public var isSelected: Bool
    public var isEdited: Bool
    public var notes: String

    public init(
        id: UUID = UUID(),
        rawAnalyteName: String,
        matchedCatalogId: String? = nil,
        resolvedName: String? = nil,
        category: LabCategory = .metabolic,
        extractedValue: Double,
        extractedTextValue: String? = nil,
        extractedUnit: String,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        referenceRangeText: String? = nil,
        detectedFlag: LabResultFlag? = nil,
        confidenceScore: Double = 0.95,
        rawSnippet: String = "",
        isSelected: Bool = true,
        isEdited: Bool = false,
        notes: String = ""
    ) {
        self.id = id
        self.rawAnalyteName = rawAnalyteName
        self.matchedCatalogId = matchedCatalogId
        self.resolvedName = resolvedName ?? rawAnalyteName
        self.category = category
        self.extractedValue = extractedValue
        self.extractedTextValue = extractedTextValue
        self.extractedUnit = extractedUnit
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.referenceRangeText = referenceRangeText
        
        if let flag = detectedFlag {
            self.detectedFlag = flag
        } else {
            if let min = referenceRangeMin, extractedValue < min {
                self.detectedFlag = .low
            } else if let max = referenceRangeMax, extractedValue > max {
                self.detectedFlag = .high
            } else {
                self.detectedFlag = .inRange
            }
        }

        self.confidenceScore = max(0.0, min(1.0, confidenceScore))
        self.rawSnippet = rawSnippet
        self.isSelected = isSelected
        self.isEdited = isEdited
        self.notes = notes
    }

    public var confidenceLevel: ExtractionConfidenceLevel {
        if confidenceScore >= 0.85 { return .high }
        if confidenceScore >= 0.60 { return .medium }
        return .low
    }

    public var formattedValue: String {
        if let text = extractedTextValue, !text.isEmpty {
            return "\(text) \(extractedUnit)"
        }
        let valStr = String(format: extractedValue.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", extractedValue)
        return "\(valStr) \(extractedUnit)"
    }

    /// Converts this candidate into an official structured `LabResult` once confirmed.
    public func toStructuredLabResult(panelId: UUID) -> LabResult {
        LabResult(
            id: UUID(),
            panelId: panelId,
            biomarkerName: resolvedName,
            category: category,
            value: extractedValue,
            textValue: extractedTextValue,
            unit: extractedUnit,
            referenceRangeMin: referenceRangeMin,
            referenceRangeMax: referenceRangeMax,
            referenceRangeText: referenceRangeText,
            flag: detectedFlag,
            notes: notes.isEmpty ? "Extracted from lab PDF (verified)" : notes
        )
    }

    /// Converts this candidate into a longitudinal `Biomarker` entry.
    public func toBiomarker(testDate: Date, labName: String) -> Biomarker {
        let cat: BiomarkerCategory
        switch category {
        case .hormones, .cbcHematology, .thyroid, .inflammatory, .custom:
            cat = .bloodwork
        case .metabolic, .vitaminsElectrolytes:
            cat = .metabolic
        case .lipids:
            cat = .cardiovascular
        case .liverHepatic, .kidneyRenal:
            cat = .bloodwork
        }

        return Biomarker(
            name: resolvedName,
            category: cat,
            value: extractedValue,
            unit: extractedUnit,
            referenceRangeMin: referenceRangeMin,
            referenceRangeMax: referenceRangeMax,
            dateRecorded: testDate,
            source: .labImport,
            notes: "Imported from \(labName)"
        )
    }
}

/// Represents the overall candidate extraction payload from a processed laboratory document.
/// Encapsulates metadata, detected clinical lab provider, collection dates, and candidate analyte rows.
public struct ExtractedLabReportCandidate: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var documentId: UUID?
    public var fileName: String
    public var detectedLabName: String
    public var detectedPanelName: String
    public var detectedCollectionDate: Date
    public var detectedResultDate: Date?
    public var detectedFastingStatus: LabFastingStatus
    public var detectedOrderingPhysician: String?
    public var overallConfidence: Double
    public var candidates: [ExtractedLabCandidate]
    public var rawExtractedText: String
    public var processingWarnings: [String]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        documentId: UUID? = nil,
        fileName: String,
        detectedLabName: String = "Quest Diagnostics",
        detectedPanelName: String = "Comprehensive Metabolic & Hormone Panel",
        detectedCollectionDate: Date = Date(),
        detectedResultDate: Date? = nil,
        detectedFastingStatus: LabFastingStatus = .fasted,
        detectedOrderingPhysician: String? = nil,
        overallConfidence: Double = 0.92,
        candidates: [ExtractedLabCandidate] = [],
        rawExtractedText: String = "",
        processingWarnings: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.documentId = documentId
        self.fileName = fileName
        self.detectedLabName = detectedLabName
        self.detectedPanelName = detectedPanelName
        self.detectedCollectionDate = detectedCollectionDate
        self.detectedResultDate = detectedResultDate ?? detectedCollectionDate
        self.detectedFastingStatus = detectedFastingStatus
        self.detectedOrderingPhysician = detectedOrderingPhysician
        self.overallConfidence = overallConfidence
        self.candidates = candidates
        self.rawExtractedText = rawExtractedText
        self.processingWarnings = processingWarnings
        self.createdAt = createdAt
    }

    /// Number of candidate analytes currently marked for inclusion.
    public var selectedCandidatesCount: Int {
        candidates.filter { $0.isSelected }.count
    }

    /// Converts confirmed candidates into a structured `LabPanel` and `[LabResult]` collection.
    public func createConfirmedLabPanel(
        panelName: String? = nil,
        labName: String? = nil,
        collectionDate: Date? = nil,
        fastingStatus: LabFastingStatus? = nil,
        orderingPhysician: String? = nil,
        notes: String? = nil
    ) -> LabPanel {
        let panelId = UUID()
        let finalPanelName = panelName ?? detectedPanelName
        let finalLabName = labName ?? detectedLabName
        let finalDate = collectionDate ?? detectedCollectionDate
        let finalFasting = fastingStatus ?? detectedFastingStatus

        let confirmedResults = candidates
            .filter { $0.isSelected }
            .map { $0.toStructuredLabResult(panelId: panelId) }

        return LabPanel(
            id: panelId,
            panelName: finalPanelName,
            labName: finalLabName,
            collectionDate: finalDate,
            resultDate: detectedResultDate ?? finalDate,
            status: .completed,
            results: confirmedResults,
            orderingPhysician: orderingPhysician ?? detectedOrderingPhysician,
            documentFileId: documentId,
            fastingStatus: finalFasting,
            notes: notes ?? "Extracted from \(fileName) and confirmed by user."
        )
    }
}
