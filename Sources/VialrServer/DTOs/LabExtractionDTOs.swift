import Vapor
import Foundation
import Domain

// MARK: - Document Extraction & Candidate Verification DTOs

/// Request payload to extract candidate biomarker data from a stored document or raw text.
public struct ExtractLabDocumentRequestDTO: Content, Sendable {
    public let documentId: UUID?
    public let rawText: String?
    public let fileName: String?

    public init(documentId: UUID? = nil, rawText: String? = nil, fileName: String? = nil) {
        self.documentId = documentId
        self.rawText = rawText
        self.fileName = fileName
    }
}

/// DTO representing an extracted candidate biomarker returned to the client for verification.
public struct ExtractedCandidateItemDTO: Content, Sendable {
    public let id: UUID
    public let rawAnalyteName: String
    public let matchedCatalogId: String?
    public let resolvedName: String
    public let category: String
    public let extractedValue: Double
    public let extractedTextValue: String?
    public let extractedUnit: String
    public let referenceRangeMin: Double?
    public let referenceRangeMax: Double?
    public let referenceRangeText: String?
    public let detectedFlag: String
    public let confidenceScore: Double
    public let confidenceLevel: String
    public let rawSnippet: String
    public let isSelected: Bool

    public init(
        id: UUID,
        rawAnalyteName: String,
        matchedCatalogId: String?,
        resolvedName: String,
        category: String,
        extractedValue: Double,
        extractedTextValue: String?,
        extractedUnit: String,
        referenceRangeMin: Double?,
        referenceRangeMax: Double?,
        referenceRangeText: String?,
        detectedFlag: String,
        confidenceScore: Double,
        confidenceLevel: String,
        rawSnippet: String,
        isSelected: Bool
    ) {
        self.id = id
        self.rawAnalyteName = rawAnalyteName
        self.matchedCatalogId = matchedCatalogId
        self.resolvedName = resolvedName
        self.category = category
        self.extractedValue = extractedValue
        self.extractedTextValue = extractedTextValue
        self.extractedUnit = extractedUnit
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.referenceRangeText = referenceRangeText
        self.detectedFlag = detectedFlag
        self.confidenceScore = confidenceScore
        self.confidenceLevel = confidenceLevel
        self.rawSnippet = rawSnippet
        self.isSelected = isSelected
    }
}

/// Response payload containing candidate extraction data prior to confirmation.
public struct ExtractLabDocumentResponseDTO: Content, Sendable {
    public let id: UUID
    public let documentId: UUID?
    public let fileName: String
    public let detectedLabName: String
    public let detectedPanelName: String
    public let detectedCollectionDate: Date
    public let detectedFastingStatus: String
    public let detectedOrderingPhysician: String?
    public let overallConfidence: Double
    public let candidates: [ExtractedCandidateItemDTO]
    public let processingWarnings: [String]

    public init(
        id: UUID,
        documentId: UUID?,
        fileName: String,
        detectedLabName: String,
        detectedPanelName: String,
        detectedCollectionDate: Date,
        detectedFastingStatus: String,
        detectedOrderingPhysician: String?,
        overallConfidence: Double,
        candidates: [ExtractedCandidateItemDTO],
        processingWarnings: [String]
    ) {
        self.id = id
        self.documentId = documentId
        self.fileName = fileName
        self.detectedLabName = detectedLabName
        self.detectedPanelName = detectedPanelName
        self.detectedCollectionDate = detectedCollectionDate
        self.detectedFastingStatus = detectedFastingStatus
        self.detectedOrderingPhysician = detectedOrderingPhysician
        self.overallConfidence = overallConfidence
        self.candidates = candidates
        self.processingWarnings = processingWarnings
    }
}

/// Request to confirm and persist candidate laboratory data as official structured records.
public struct ConfirmLabCandidatesRequestDTO: Content, Sendable {
    public let documentId: UUID?
    public let panelName: String
    public let labName: String
    public let collectionDate: Date
    public let resultDate: Date?
    public let fastingStatus: String?
    public let orderingPhysician: String?
    public let associatedProtocolId: UUID?
    public let notes: String?
    public let confirmedCandidates: [ConfirmedCandidateItemInputDTO]

    public init(
        documentId: UUID? = nil,
        panelName: String,
        labName: String,
        collectionDate: Date,
        resultDate: Date? = nil,
        fastingStatus: String? = nil,
        orderingPhysician: String? = nil,
        associatedProtocolId: UUID? = nil,
        notes: String? = nil,
        confirmedCandidates: [ConfirmedCandidateItemInputDTO]
    ) {
        self.documentId = documentId
        self.panelName = panelName
        self.labName = labName
        self.collectionDate = collectionDate
        self.resultDate = resultDate
        self.fastingStatus = fastingStatus
        self.orderingPhysician = orderingPhysician
        self.associatedProtocolId = associatedProtocolId
        self.notes = notes
        self.confirmedCandidates = confirmedCandidates
    }
}

public struct ConfirmedCandidateItemInputDTO: Content, Sendable {
    public let biomarkerName: String
    public let category: String
    public let value: Double
    public let textValue: String?
    public let unit: String
    public let referenceRangeMin: Double?
    public let referenceRangeMax: Double?
    public let referenceRangeText: String?
    public let flag: String?
    public let notes: String?

    public init(
        biomarkerName: String,
        category: String,
        value: Double,
        textValue: String? = nil,
        unit: String,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        referenceRangeText: String? = nil,
        flag: String? = nil,
        notes: String? = nil
    ) {
        self.biomarkerName = biomarkerName
        self.category = category
        self.value = value
        self.textValue = textValue
        self.unit = unit
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.referenceRangeText = referenceRangeText
        self.flag = flag
        self.notes = notes
    }
}
