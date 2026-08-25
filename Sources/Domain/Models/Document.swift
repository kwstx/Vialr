import Foundation

/// Represents an uploaded digital file or asset (such as a laboratory bloodwork PDF,
/// Certificate of Analysis, clinical prescription, medical note, or vial photograph).
/// Encapsulates storage location, cryptographic checksums, OCR extraction state, and domain links.
public struct Document: SyncableRecord, Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var userId: UUID?
    public var title: String
    public var fileName: String
    public var fileExtension: String
    public var mimeType: String
    public var byteSize: Int64
    public var category: DocumentCategory
    
    // MARK: - Storage & Cryptography
    public var storageBucket: String
    public var storageKey: String
    public var sha256Checksum: String
    public var encryption: StorageEncryptionMetadata
    
    // MARK: - Relational Foreign Keys
    public var labPanelId: UUID?
    public var protocolId: UUID?
    public var vialId: UUID?
    public var compoundId: UUID?
    public var measurementId: UUID?
    
    // MARK: - OCR & Document Content
    public var processingStatus: DocumentProcessingStatus
    public var extractedText: String?
    public var pageCount: Int?
    public var documentDate: Date? // Date printed on the document (e.g. lab draw date)
    public var notes: String
    public var uploadDate: Date
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var syncState: SyncState

    // MARK: - Primary Initializer
    public init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        title: String,
        fileName: String,
        fileExtension: String = "pdf",
        mimeType: String = "application/pdf",
        byteSize: Int64,
        category: DocumentCategory = .labReport,
        storageBucket: String = "vialr-secure-vault",
        storageKey: String = "",
        sha256Checksum: String = "",
        encryption: StorageEncryptionMetadata = StorageEncryptionMetadata(),
        labPanelId: UUID? = nil,
        protocolId: UUID? = nil,
        vialId: UUID? = nil,
        compoundId: UUID? = nil,
        measurementId: UUID? = nil,
        processingStatus: DocumentProcessingStatus = .parsed,
        extractedText: String? = nil,
        pageCount: Int? = 1,
        documentDate: Date? = nil,
        notes: String = "",
        uploadDate: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        syncState: SyncState = .synced
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.fileName = fileName
        self.fileExtension = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        self.mimeType = mimeType
        self.byteSize = byteSize
        self.category = category
        self.storageBucket = storageBucket
        self.storageKey = storageKey.isEmpty ? "vault/users/\(userId?.uuidString ?? "shared")/docs/\(id.uuidString).enc" : storageKey
        self.sha256Checksum = sha256Checksum
        self.encryption = encryption
        self.labPanelId = labPanelId
        self.protocolId = protocolId
        self.vialId = vialId
        self.compoundId = compoundId
        self.measurementId = measurementId
        self.processingStatus = processingStatus
        self.extractedText = extractedText
        self.pageCount = pageCount
        self.documentDate = documentDate
        self.notes = notes
        self.uploadDate = uploadDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.syncState = syncState
    }

    // MARK: - Convenience Static Factories
    /// Lab PDF document factory
    public static func labReport(
        title: String,
        fileName: String,
        byteSize: Int64,
        sha256Checksum: String = "",
        labPanelId: UUID? = nil,
        protocolId: UUID? = nil,
        documentDate: Date? = nil,
        pageCount: Int? = 1,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Document {
        Document(
            title: title,
            fileName: fileName,
            fileExtension: "pdf",
            mimeType: "application/pdf",
            byteSize: byteSize,
            category: .labReport,
            sha256Checksum: sha256Checksum,
            labPanelId: labPanelId,
            protocolId: protocolId,
            pageCount: pageCount,
            documentDate: documentDate,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    /// Certificate of Analysis (CoA) document factory
    public static func certificateOfAnalysis(
        title: String,
        fileName: String,
        byteSize: Int64,
        vialId: UUID? = nil,
        compoundId: UUID? = nil,
        notes: String = "",
        version: Int = 1,
        syncState: SyncState = .synced
    ) -> Document {
        Document(
            title: title,
            fileName: fileName,
            fileExtension: (fileName as NSString).pathExtension.lowercased(),
            mimeType: (fileName.lowercased().hasSuffix(".pdf")) ? "application/pdf" : "image/jpeg",
            byteSize: byteSize,
            category: .certificateOfAnalysis,
            vialId: vialId,
            compoundId: compoundId,
            notes: notes,
            version: version,
            syncState: syncState
        )
    }

    // MARK: - Display Helpers
    /// Formats file size in human readable units (e.g. "2.4 MB", "840 KB")
    public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: byteSize)
    }

    /// Whether this file is a PDF document
    public var isPDF: Bool {
        fileExtension == "pdf" || mimeType == "application/pdf"
    }

    /// Whether this file is an image
    public var isImage: Bool {
        ["jpg", "jpeg", "png", "heic", "webp"].contains(fileExtension) || mimeType.hasPrefix("image/")
    }
}

// MARK: - Document Category
public enum DocumentCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case labReport = "Laboratory / Bloodwork Report"
    case certificateOfAnalysis = "Certificate of Analysis (CoA)"
    case prescription = "Prescription / Clinical Rx"
    case clinicalSummary = "Clinical Summary / Doctor's Note"
    case imagingScan = "Medical Imaging / Scan"
    case researchPaper = "Medical Research Paper"
    case receiptOrInvoice = "Receipt / Purchase Invoice"
    case vialOrPackagingPhoto = "Vial / Packaging Photo"
    case progressPhoto = "Progress Photo"
    case other = "Other Document"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .labReport: return "doc.text.fill"
        case .certificateOfAnalysis: return "checkmark.seal.fill"
        case .prescription: return "cross.case.fill"
        case .clinicalSummary: return "stethoscope"
        case .imagingScan: return "waveform.path.ecg.rectangle"
        case .researchPaper: return "book.closed.fill"
        case .receiptOrInvoice: return "creditcard.fill"
        case .vialOrPackagingPhoto: return "cross.vial.fill"
        case .progressPhoto: return "photo.fill"
        case .other: return "doc.fill"
        }
    }
}

// MARK: - Document Processing Status
public enum DocumentProcessingStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case uploaded = "Uploaded"
    case processingOCR = "Extracting Data / OCR"
    case parsed = "Parsed & Indexed"
    case parsingFailed = "Extraction Failed"
    case verified = "Clinically Verified"

    public var id: String { rawValue }

    public var badgeColorHex: String {
        switch self {
        case .uploaded: return "#3B82F6"
        case .processingOCR: return "#F59E0B"
        case .parsed: return "#10B981"
        case .parsingFailed: return "#EF4444"
        case .verified: return "#8B5CF6"
        }
    }
}
