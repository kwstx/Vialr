import Foundation

/// Represents a persistent asynchronous background processing task in the Vialr platform.
/// Designed so heavy operations (e.g. OCR table extraction on 20-page lab PDFs, report compilation,
/// data exports, large analytics calculations, notification scheduling, or background delta sync)
/// never block synchronous HTTP API requests.
public struct BackgroundJob: SyncableRecord, Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var userId: UUID?
    public var jobType: BackgroundJobType
    public var status: BackgroundJobStatus
    public var progress: Double // 0.0 to 1.0
    public var stepDescription: String
    public var payloadJson: String?
    public var resultJson: String?
    public var errorMessage: String?
    public var retryCount: Int
    public var maxRetries: Int
    public var createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var updatedAt: Date
    public var version: Int
    public var syncState: SyncState

    public init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        jobType: BackgroundJobType,
        status: BackgroundJobStatus = .queued,
        progress: Double = 0.0,
        stepDescription: String = "Queued for processing",
        payloadJson: String? = nil,
        resultJson: String? = nil,
        errorMessage: String? = nil,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date = Date(),
        version: Int = 1,
        syncState: SyncState = .synced
    ) {
        self.id = id
        self.userId = userId
        self.jobType = jobType
        self.status = status
        self.progress = min(max(progress, 0.0), 1.0)
        self.stepDescription = stepDescription
        self.payloadJson = payloadJson
        self.resultJson = resultJson
        self.errorMessage = errorMessage
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.version = version
        self.syncState = syncState
    }

    /// Helper checking whether the job is still actively running or in queue
    public var isActive: Bool {
        status == .queued || status == .processing
    }

    /// Helper checking if the job reached a terminal state
    public var isFinished: Bool {
        status == .completed || status == .failed || status == .cancelled
    }

    /// Percentage string (e.g. "75%")
    public var formattedProgress: String {
        "\(Int(progress * 100))%"
    }
}

// MARK: - Background Job Type
public enum BackgroundJobType: String, Codable, Sendable, CaseIterable, Identifiable {
    case pdfProcessing = "pdf_processing"
    case reportGeneration = "report_generation"
    case imageProcessing = "image_processing"
    case dataExport = "data_export"
    case notificationPreparation = "notification_preparation"
    case analyticsCalculation = "analytics_calculation"
    case synchronization = "synchronization"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pdfProcessing: return "PDF & Document OCR"
        case .reportGeneration: return "Clinician Report Generation"
        case .imageProcessing: return "Image Processing & Analysis"
        case .dataExport: return "Full Data Export"
        case .notificationPreparation: return "Notification Scheduling"
        case .analyticsCalculation: return "Analytics & Pharmacokinetics"
        case .synchronization: return "Background Cloud Sync"
        }
    }

    public var systemIcon: String {
        switch self {
        case .pdfProcessing: return "doc.text.viewfinder"
        case .reportGeneration: return "doc.richtext.fill"
        case .imageProcessing: return "photo.badge.checkmark"
        case .dataExport: return "arrow.down.doc.fill"
        case .notificationPreparation: return "bell.badge.fill"
        case .analyticsCalculation: return "chart.xyaxis.line"
        case .synchronization: return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Background Job Status
public enum BackgroundJobStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case queued = "queued"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .queued: return "Queued"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    public var badgeColorHex: String {
        switch self {
        case .queued: return "#6B7280"      // Gray
        case .processing: return "#F59E0B"  // Amber
        case .completed: return "#10B981"   // Emerald
        case .failed: return "#EF4444"      // Crimson
        case .cancelled: return "#9CA3AF"   // Slate
        }
    }
}

// MARK: - Strongly-Typed Payloads & Results

// 1. PDF Processing
public struct PdfProcessingJobPayload: Codable, Sendable {
    public let fileId: UUID
    public let fileName: String
    public let autoCreatePanel: Bool
    public let targetDate: Date?

    public init(fileId: UUID, fileName: String, autoCreatePanel: Bool = true, targetDate: Date? = nil) {
        self.fileId = fileId
        self.fileName = fileName
        self.autoCreatePanel = autoCreatePanel
        self.targetDate = targetDate
    }
}

public struct PdfProcessingJobResult: Codable, Sendable {
    public let fileId: UUID
    public let panelId: UUID?
    public let extractedCandidatesCount: Int
    public let labProvider: String
    public let detectedPanelName: String
    public let summary: String

    public init(
        fileId: UUID,
        panelId: UUID?,
        extractedCandidatesCount: Int,
        labProvider: String,
        detectedPanelName: String,
        summary: String
    ) {
        self.fileId = fileId
        self.panelId = panelId
        self.extractedCandidatesCount = extractedCandidatesCount
        self.labProvider = labProvider
        self.detectedPanelName = detectedPanelName
        self.summary = summary
    }
}

// 2. Report Generation
public struct ReportGenerationJobPayload: Codable, Sendable {
    public let dateRangeStart: Date?
    public let dateRangeEnd: Date?
    public let patientName: String
    public let includeProtocols: Bool
    public let includeDoses: Bool
    public let includeBiomarkers: Bool
    public let includeMeasurements: Bool
    public let includeSymptoms: Bool
    public let includeFullLedger: Bool

    public init(
        dateRangeStart: Date? = nil,
        dateRangeEnd: Date? = nil,
        patientName: String = "Patient / Self",
        includeProtocols: Bool = true,
        includeDoses: Bool = true,
        includeBiomarkers: Bool = true,
        includeMeasurements: Bool = true,
        includeSymptoms: Bool = true,
        includeFullLedger: Bool = true
    ) {
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.patientName = patientName
        self.includeProtocols = includeProtocols
        self.includeDoses = includeDoses
        self.includeBiomarkers = includeBiomarkers
        self.includeMeasurements = includeMeasurements
        self.includeSymptoms = includeSymptoms
        self.includeFullLedger = includeFullLedger
    }
}

public struct ReportGenerationJobResult: Codable, Sendable {
    public let reportId: UUID
    public let storedFileId: UUID?
    public let downloadUrl: String?
    public let pdfByteSize: Int64
    public let adherencePercentage: Double
    public let totalDoses: Int
    public let totalBiomarkers: Int
    public let summary: String

    public init(
        reportId: UUID,
        storedFileId: UUID?,
        downloadUrl: String?,
        pdfByteSize: Int64,
        adherencePercentage: Double,
        totalDoses: Int,
        totalBiomarkers: Int,
        summary: String
    ) {
        self.reportId = reportId
        self.storedFileId = storedFileId
        self.downloadUrl = downloadUrl
        self.pdfByteSize = pdfByteSize
        self.adherencePercentage = adherencePercentage
        self.totalDoses = totalDoses
        self.totalBiomarkers = totalBiomarkers
        self.summary = summary
    }
}

// 3. Image Processing
public struct ImageProcessingJobPayload: Codable, Sendable {
    public let fileId: UUID
    public let fileName: String
    public let generateThumbnail: Bool
    public let performOcr: Bool
    public let optimizeCompression: Bool

    public init(
        fileId: UUID,
        fileName: String,
        generateThumbnail: Bool = true,
        performOcr: Bool = true,
        optimizeCompression: Bool = true
    ) {
        self.fileId = fileId
        self.fileName = fileName
        self.generateThumbnail = generateThumbnail
        self.performOcr = performOcr
        self.optimizeCompression = optimizeCompression
    }
}

public struct ImageProcessingJobResult: Codable, Sendable {
    public let fileId: UUID
    public let thumbnailFileId: UUID?
    public let extractedLabelText: String?
    public let originalSize: Int64
    public let optimizedSize: Int64
    public let detectedOrientation: String?

    public init(
        fileId: UUID,
        thumbnailFileId: UUID?,
        extractedLabelText: String?,
        originalSize: Int64,
        optimizedSize: Int64,
        detectedOrientation: String?
    ) {
        self.fileId = fileId
        self.thumbnailFileId = thumbnailFileId
        self.extractedLabelText = extractedLabelText
        self.originalSize = originalSize
        self.optimizedSize = optimizedSize
        self.detectedOrientation = detectedOrientation
    }
}

// 4. Data Export
public struct DataExportJobPayload: Codable, Sendable {
    public let exportFormat: String // "json", "csv", "bundle_zip"
    public let includeAuditLogs: Bool
    public let encryptArchive: Bool

    public init(exportFormat: String = "bundle_zip", includeAuditLogs: Bool = true, encryptArchive: Bool = true) {
        self.exportFormat = exportFormat
        self.includeAuditLogs = includeAuditLogs
        self.encryptArchive = encryptArchive
    }
}

public struct DataExportJobResult: Codable, Sendable {
    public let storedFileId: UUID
    public let downloadUrl: String
    public let archiveByteSize: Int64
    public let recordsExportedCount: Int
    public let sha256Checksum: String
    public let expiresAt: Date

    public init(
        storedFileId: UUID,
        downloadUrl: String,
        archiveByteSize: Int64,
        recordsExportedCount: Int,
        sha256Checksum: String,
        expiresAt: Date
    ) {
        self.storedFileId = storedFileId
        self.downloadUrl = downloadUrl
        self.archiveByteSize = archiveByteSize
        self.recordsExportedCount = recordsExportedCount
        self.sha256Checksum = sha256Checksum
        self.expiresAt = expiresAt
    }
}

// 5. Notification Preparation
public struct NotificationPreparationJobPayload: Codable, Sendable {
    public let daysAhead: Int
    public let recalculateStockAlerts: Bool

    public init(daysAhead: Int = 30, recalculateStockAlerts: Bool = true) {
        self.daysAhead = daysAhead
        self.recalculateStockAlerts = recalculateStockAlerts
    }
}

public struct NotificationPreparationJobResult: Codable, Sendable {
    public let scheduledDoseRemindersCount: Int
    public let lowStockAlertsCount: Int
    public let expiringVialsCount: Int
    public let windowStartDate: Date
    public let windowEndDate: Date

    public init(
        scheduledDoseRemindersCount: Int,
        lowStockAlertsCount: Int,
        expiringVialsCount: Int,
        windowStartDate: Date,
        windowEndDate: Date
    ) {
        self.scheduledDoseRemindersCount = scheduledDoseRemindersCount
        self.lowStockAlertsCount = lowStockAlertsCount
        self.expiringVialsCount = expiringVialsCount
        self.windowStartDate = windowStartDate
        self.windowEndDate = windowEndDate
    }
}

// 6. Large Analytics Calculations
public struct AnalyticsCalculationJobPayload: Codable, Sendable {
    public let compoundIds: [UUID]?
    public let dateRangeStart: Date?
    public let dateRangeEnd: Date?
    public let computeHalfLifeDecayCurves: Bool
    public let computeAdherenceTimeline: Bool
    public let computeBiomarkerCorrelations: Bool

    public init(
        compoundIds: [UUID]? = nil,
        dateRangeStart: Date? = nil,
        dateRangeEnd: Date? = nil,
        computeHalfLifeDecayCurves: Bool = true,
        computeAdherenceTimeline: Bool = true,
        computeBiomarkerCorrelations: Bool = true
    ) {
        self.compoundIds = compoundIds
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.computeHalfLifeDecayCurves = computeHalfLifeDecayCurves
        self.computeAdherenceTimeline = computeAdherenceTimeline
        self.computeBiomarkerCorrelations = computeBiomarkerCorrelations
    }
}

public struct AnalyticsCalculationJobResult: Codable, Sendable {
    public let adherenceRate: Double
    public let calculatedDataPointsCount: Int
    public let halfLifeCurvesGeneratedCount: Int
    public let correlatedBiomarkersCount: Int
    public let computationTimeSeconds: Double
    public let summary: String

    public init(
        adherenceRate: Double,
        calculatedDataPointsCount: Int,
        halfLifeCurvesGeneratedCount: Int,
        correlatedBiomarkersCount: Int,
        computationTimeSeconds: Double,
        summary: String
    ) {
        self.adherenceRate = adherenceRate
        self.calculatedDataPointsCount = calculatedDataPointsCount
        self.halfLifeCurvesGeneratedCount = halfLifeCurvesGeneratedCount
        self.correlatedBiomarkersCount = correlatedBiomarkersCount
        self.computationTimeSeconds = computationTimeSeconds
        self.summary = summary
    }
}

// 7. Synchronization Job
public struct SyncJobPayload: Codable, Sendable {
    public let deviceId: String
    public let fullReconciliation: Bool
    public let forcePushUnsynced: Bool

    public init(deviceId: String = "iOS-Client", fullReconciliation: Bool = false, forcePushUnsynced: Bool = true) {
        self.deviceId = deviceId
        self.fullReconciliation = fullReconciliation
        self.forcePushUnsynced = forcePushUnsynced
    }
}

public struct SyncJobResult: Codable, Sendable {
    public let pushedRecordsCount: Int
    public let pulledRecordsCount: Int
    public let resolvedConflictsCount: Int
    public let latestServerRevision: Int
    public let summary: String

    public init(
        pushedRecordsCount: Int,
        pulledRecordsCount: Int,
        resolvedConflictsCount: Int,
        latestServerRevision: Int,
        summary: String
    ) {
        self.pushedRecordsCount = pushedRecordsCount
        self.pulledRecordsCount = pulledRecordsCount
        self.resolvedConflictsCount = resolvedConflictsCount
        self.latestServerRevision = latestServerRevision
        self.summary = summary
    }
}
