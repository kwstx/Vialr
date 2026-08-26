import XCTest
import Domain
import Foundation

final class BackgroundProcessingTests: XCTestCase {

    // MARK: - 1. Job State Transitions & Progress
    func testBackgroundJobLifecycleAndStateProperties() {
        let jobId = UUID()
        let userId = UUID()

        // 1. Queued state
        var job = BackgroundJob(
            id: jobId,
            userId: userId,
            jobType: .pdfProcessing,
            status: .queued,
            progress: 0.0,
            stepDescription: "Queued in worker pool"
        )

        XCTAssertTrue(job.isActive)
        XCTAssertFalse(job.isFinished)
        XCTAssertEqual(job.formattedProgress, "0%")
        XCTAssertEqual(job.status, .queued)

        // 2. Processing state
        job.status = .processing
        job.progress = 0.45
        job.stepDescription = "2/4 Running OCR & table extraction..."

        XCTAssertTrue(job.isActive)
        XCTAssertFalse(job.isFinished)
        XCTAssertEqual(job.formattedProgress, "45%")
        XCTAssertEqual(job.status, .processing)

        // 3. Completed state
        job.status = .completed
        job.progress = 1.0
        job.stepDescription = "4/4 Analytes extracted and ready."
        job.completedAt = Date()

        XCTAssertFalse(job.isActive)
        XCTAssertTrue(job.isFinished)
        XCTAssertEqual(job.formattedProgress, "100%")
        XCTAssertEqual(job.status, .completed)
    }

    // MARK: - 2. PDF Processing Job Payload & Result
    func testPdfProcessingJobPayloadAndResultRoundTrip() throws {
        let fileId = UUID()
        let panelId = UUID()
        let payload = PdfProcessingJobPayload(
            fileId: fileId,
            fileName: "Quest_Metabolic_2026.pdf",
            autoCreatePanel: true
        )

        let encodedPayload = try JSONEncoder().encode(payload)
        let decodedPayload = try JSONDecoder().decode(PdfProcessingJobPayload.self, from: encodedPayload)
        XCTAssertEqual(decodedPayload.fileId, fileId)
        XCTAssertEqual(decodedPayload.fileName, "Quest_Metabolic_2026.pdf")
        XCTAssertTrue(decodedPayload.autoCreatePanel)

        let result = PdfProcessingJobResult(
            fileId: fileId,
            panelId: panelId,
            extractedCandidatesCount: 14,
            labProvider: "Quest Diagnostics",
            detectedPanelName: "Comprehensive Metabolic Panel",
            summary: "Extracted 14 clinical analytes from 'Quest_Metabolic_2026.pdf'."
        )

        let encodedResult = try JSONEncoder().encode(result)
        let decodedResult = try JSONDecoder().decode(PdfProcessingJobResult.self, from: encodedResult)
        XCTAssertEqual(decodedResult.fileId, fileId)
        XCTAssertEqual(decodedResult.panelId, panelId)
        XCTAssertEqual(decodedResult.extractedCandidatesCount, 14)
        XCTAssertEqual(decodedResult.labProvider, "Quest Diagnostics")
    }

    // MARK: - 3. Report Generation Job Payload & Result
    func testReportGenerationJobPayloadAndResultRoundTrip() throws {
        let reportId = UUID()
        let storedFileId = UUID()
        let startDate = Date().addingTimeInterval(-86400 * 90)
        let endDate = Date()

        let payload = ReportGenerationJobPayload(
            dateRangeStart: startDate,
            dateRangeEnd: endDate,
            patientName: "Alex Sterling",
            includeProtocols: true,
            includeDoses: true,
            includeBiomarkers: true
        )

        let encodedPayload = try JSONEncoder().encode(payload)
        let decodedPayload = try JSONDecoder().decode(ReportGenerationJobPayload.self, from: encodedPayload)
        XCTAssertEqual(decodedPayload.patientName, "Alex Sterling")
        XCTAssertTrue(decodedPayload.includeProtocols)

        let result = ReportGenerationJobResult(
            reportId: reportId,
            storedFileId: storedFileId,
            downloadUrl: "/api/v1/files/\(storedFileId.uuidString)/download",
            pdfByteSize: 245000,
            adherencePercentage: 94.5,
            totalDoses: 60,
            totalBiomarkers: 18,
            summary: "Report generated for Alex Sterling"
        )

        let encodedResult = try JSONEncoder().encode(result)
        let decodedResult = try JSONDecoder().decode(ReportGenerationJobResult.self, from: encodedResult)
        XCTAssertEqual(decodedResult.reportId, reportId)
        XCTAssertEqual(decodedResult.adherencePercentage, 94.5)
        XCTAssertEqual(decodedResult.totalDoses, 60)
    }

    // MARK: - 4. Image Processing Job Payload & Result
    func testImageProcessingJobPayloadAndResultRoundTrip() throws {
        let fileId = UUID()
        let thumbId = UUID()

        let payload = ImageProcessingJobPayload(
            fileId: fileId,
            fileName: "bpc_157_vial_label.jpg",
            generateThumbnail: true,
            performOcr: true,
            optimizeCompression: true
        )

        let encodedPayload = try JSONEncoder().encode(payload)
        let decodedPayload = try JSONDecoder().decode(ImageProcessingJobPayload.self, from: encodedPayload)
        XCTAssertEqual(decodedPayload.fileId, fileId)
        XCTAssertTrue(decodedPayload.generateThumbnail)

        let result = ImageProcessingJobResult(
            fileId: fileId,
            thumbnailFileId: thumbId,
            extractedLabelText: "BPC-157 10mg",
            originalSize: 4_500_000,
            optimizedSize: 950_000,
            detectedOrientation: "Upright"
        )

        let encodedResult = try JSONEncoder().encode(result)
        let decodedResult = try JSONDecoder().decode(ImageProcessingJobResult.self, from: encodedResult)
        XCTAssertEqual(decodedResult.fileId, fileId)
        XCTAssertEqual(decodedResult.extractedLabelText, "BPC-157 10mg")
        XCTAssertEqual(decodedResult.optimizedSize, 950_000)
    }

    // MARK: - 5. Data Export Job Payload & Result
    func testDataExportJobPayloadAndResultRoundTrip() throws {
        let exportFileId = UUID()
        let payload = DataExportJobPayload(
            exportFormat: "bundle_zip",
            includeAuditLogs: true,
            encryptArchive: true
        )

        let encodedPayload = try JSONEncoder().encode(payload)
        let decodedPayload = try JSONDecoder().decode(DataExportJobPayload.self, from: encodedPayload)
        XCTAssertEqual(decodedPayload.exportFormat, "bundle_zip")
        XCTAssertTrue(decodedPayload.encryptArchive)

        let result = DataExportJobResult(
            storedFileId: exportFileId,
            downloadUrl: "/api/v1/files/\(exportFileId.uuidString)/download",
            archiveByteSize: 1_200_000,
            recordsExportedCount: 340,
            sha256Checksum: "checksum-data-export-hash",
            expiresAt: Date().addingTimeInterval(86400 * 7)
        )

        let encodedResult = try JSONEncoder().encode(result)
        let decodedResult = try JSONDecoder().decode(DataExportJobResult.self, from: encodedResult)
        XCTAssertEqual(decodedResult.storedFileId, exportFileId)
        XCTAssertEqual(decodedResult.recordsExportedCount, 340)
    }

    // MARK: - 6. Notification Preparation Job Payload & Result
    func testNotificationPreparationJobPayloadAndResultRoundTrip() throws {
        let payload = NotificationPreparationJobPayload(
            daysAhead: 45,
            recalculateStockAlerts: true
        )

        let encodedPayload = try JSONEncoder().encode(payload)
        let decodedPayload = try JSONDecoder().decode(NotificationPreparationJobPayload.self, from: encodedPayload)
        XCTAssertEqual(decodedPayload.daysAhead, 45)
        XCTAssertTrue(decodedPayload.recalculateStockAlerts)

        let result = NotificationPreparationJobResult(
            scheduledDoseRemindersCount: 42,
            lowStockAlertsCount: 2,
            expiringVialsCount: 1,
            windowStartDate: Date(),
            windowEndDate: Date().addingTimeInterval(86400 * 45)
        )

        let encodedResult = try JSONEncoder().encode(result)
        let decodedResult = try JSONDecoder().decode(NotificationPreparationJobResult.self, from: encodedResult)
        XCTAssertEqual(decodedResult.scheduledDoseRemindersCount, 42)
        XCTAssertEqual(decodedResult.lowStockAlertsCount, 2)
    }

    // MARK: - 7. Analytics Calculation Job Payload & Result
    func testAnalyticsCalculationJobPayloadAndResultRoundTrip() throws {
        let payload = AnalyticsCalculationJobPayload(
            computeHalfLifeDecayCurves: true,
            computeAdherenceTimeline: true,
            computeBiomarkerCorrelations: true
        )

        let encodedPayload = try JSONEncoder().encode(payload)
        let decodedPayload = try JSONDecoder().decode(AnalyticsCalculationJobPayload.self, from: encodedPayload)
        XCTAssertTrue(decodedPayload.computeHalfLifeDecayCurves)

        let result = AnalyticsCalculationJobResult(
            adherenceRate: 97.2,
            calculatedDataPointsCount: 480,
            halfLifeCurvesGeneratedCount: 3,
            correlatedBiomarkersCount: 12,
            computationTimeSeconds: 0.85,
            summary: "Calculated longitudinal metrics in 0.85s."
        )

        let encodedResult = try JSONEncoder().encode(result)
        let decodedResult = try JSONDecoder().decode(AnalyticsCalculationJobResult.self, from: encodedResult)
        XCTAssertEqual(decodedResult.adherenceRate, 97.2)
        XCTAssertEqual(decodedResult.halfLifeCurvesGeneratedCount, 3)
    }

    // MARK: - 8. Synchronization Job Payload & Result
    func testSyncJobPayloadAndResultRoundTrip() throws {
        let payload = SyncJobPayload(
            deviceId: "iPhone-15-Pro",
            fullReconciliation: true,
            forcePushUnsynced: true
        )

        let encodedPayload = try JSONEncoder().encode(payload)
        let decodedPayload = try JSONDecoder().decode(SyncJobPayload.self, from: encodedPayload)
        XCTAssertEqual(decodedPayload.deviceId, "iPhone-15-Pro")
        XCTAssertTrue(decodedPayload.fullReconciliation)

        let result = SyncJobResult(
            pushedRecordsCount: 15,
            pulledRecordsCount: 20,
            resolvedConflictsCount: 2,
            latestServerRevision: 42,
            summary: "Synchronized 35 records."
        )

        let encodedResult = try JSONEncoder().encode(result)
        let decodedResult = try JSONDecoder().decode(SyncJobResult.self, from: encodedResult)
        XCTAssertEqual(decodedResult.pushedRecordsCount, 15)
        XCTAssertEqual(decodedResult.latestServerRevision, 42)
    }

    // MARK: - 9. All 7 Background Job Types Verification
    func testAllSevenBackgroundJobTypesSupported() {
        let allTypes = BackgroundJobType.allCases
        XCTAssertEqual(allTypes.count, 7)

        let expectedIdentifiers: Set<String> = [
            "pdf_processing",
            "report_generation",
            "image_processing",
            "data_export",
            "notification_preparation",
            "analytics_calculation",
            "synchronization"
        ]

        let actualIdentifiers = Set(allTypes.map { $0.rawValue })
        XCTAssertEqual(expectedIdentifiers, actualIdentifiers)

        for type in allTypes {
            XCTAssertFalse(type.displayName.isEmpty)
            XCTAssertFalse(type.systemIcon.isEmpty)
        }
    }
}
