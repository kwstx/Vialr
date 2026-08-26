import XCTest
import Domain
import Foundation
@testable import VialrServer
@testable import Data

final class ObservabilityTests: XCTestCase {

    // MARK: - 1. Structured Logging & JSON Serialization
    func testStructuredLogEntrySerialization() throws {
        let requestId = UUID().uuidString
        let userId = UUID().uuidString

        let errorDetails = StructuredErrorDetails(
            errorType: "PostgresError",
            errorMessage: "Connection pool exhausted",
            errorDomain: "VialrDatabase",
            errorCode: 503,
            stackTrace: ["DatabasePool.swift:42 acquire()"],
            isFatal: true
        )

        let entry = StructuredLogEntry(
            timestamp: "2026-08-26T14:30:00Z",
            level: "ERROR",
            service: "vialr-api",
            environment: "production",
            requestId: requestId,
            correlationId: requestId,
            userId: userId,
            method: "POST",
            path: "/api/v1/sync/outbox",
            statusCode: 503,
            latencyMs: 142.5,
            clientVersion: "1.0.0",
            platform: "iOS 17.5",
            message: "Database connection failed during sync outbox batch",
            metadata: ["operationCount": "5", "entityTypes": "doseEvent,protocol"],
            error: errorDetails
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(entry)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"service\":\"vialr-api\""))
        XCTAssertTrue(jsonString.contains("\"level\":\"ERROR\""))
        XCTAssertTrue(jsonString.contains("\"requestId\":\"\(requestId)\""))
        XCTAssertTrue(jsonString.contains("\"statusCode\":503"))
        XCTAssertTrue(jsonString.contains("\"latencyMs\":142.5"))
        XCTAssertTrue(jsonString.contains("\"errorType\":\"PostgresError\""))
        XCTAssertTrue(jsonString.contains("\"isFatal\":true"))

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StructuredLogEntry.self, from: data)
        XCTAssertEqual(decoded.requestId, requestId)
        XCTAssertEqual(decoded.statusCode, 503)
        XCTAssertEqual(decoded.error?.errorType, "PostgresError")
        XCTAssertEqual(decoded.metadata["operationCount"], "5")
    }

    // MARK: - 2. PHI / PII Sensitive Data Scrubber
    func testSensitiveDataScrubberHeaderAndMetadataSanitization() {
        // Headers test
        let rawHeaders = [
            ("Authorization", "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.test"),
            ("Content-Type", "application/json"),
            ("Cookie", "session_id=abcdef123456"),
            ("X-Request-ID", "req-12345"),
            ("X-Apple-ID-Token", "apple-token-secret-value")
        ]

        let sanitizedHeaders = SensitiveDataScrubber.sanitizeHeaders(rawHeaders)
        XCTAssertEqual(sanitizedHeaders["Authorization"], "[REDACTED_AUTH]")
        XCTAssertEqual(sanitizedHeaders["Cookie"], "[REDACTED_AUTH]")
        XCTAssertEqual(sanitizedHeaders["X-Apple-ID-Token"], "[REDACTED_AUTH]")
        XCTAssertEqual(sanitizedHeaders["Content-Type"], "application/json")
        XCTAssertEqual(sanitizedHeaders["X-Request-ID"], "req-12345")

        // Metadata test (Redacts sensitive health keys like doseAmount, biomarkerName, notes)
        let rawMetadata = [
            "userId": "user-uuid-123",
            "doseAmount": "250mg",
            "actualDoseAmount": "500mcg",
            "biomarkerName": "Total Testosterone",
            "clinicalNotes": "Patient experiencing fatigue",
            "password": "supersecretpassword123",
            "entityType": "doseEvent",
            "latencyMs": "45.2"
        ]

        let sanitizedMetadata = SensitiveDataScrubber.sanitizeMetadata(rawMetadata)
        XCTAssertEqual(sanitizedMetadata["userId"], "user-uuid-123")
        XCTAssertEqual(sanitizedMetadata["entityType"], "doseEvent")
        XCTAssertEqual(sanitizedMetadata["latencyMs"], "45.2")
        XCTAssertEqual(sanitizedMetadata["doseAmount"], "[REDACTED_PHI]")
        XCTAssertEqual(sanitizedMetadata["actualDoseAmount"], "[REDACTED_PHI]")
        XCTAssertEqual(sanitizedMetadata["biomarkerName"], "[REDACTED_PHI]")
        XCTAssertEqual(sanitizedMetadata["clinicalNotes"], "[REDACTED_PHI]")
        XCTAssertEqual(sanitizedMetadata["password"], "[REDACTED_AUTH]")

        // Freeform message sanitization test (strips bearer tokens and passwords)
        let rawMessage = "Failed authentication for Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.sig with password=mysecretpass"
        let sanitizedMessage = SensitiveDataScrubber.sanitizeStringContent(rawMessage)
        XCTAssertFalse(sanitizedMessage.contains("mysecretpass"))
        XCTAssertTrue(sanitizedMessage.contains("password=[REDACTED]"))
        XCTAssertTrue(sanitizedMessage.contains("Bearer [REDACTED_TOKEN]"))
    }

    func testSafeOperationSummaryExtraction() {
        let jsonPayload = """
        {
            "operations": [
                {"entityType": "doseEvent", "operationType": "create"},
                {"entityType": "doseEvent", "operationType": "create"},
                {"entityType": "protocol", "operationType": "update"}
            ]
        }
        """

        let summary = SensitiveDataScrubber.extractSafeOperationSummary(from: jsonPayload)
        XCTAssertEqual(summary["operationCount"], "3")
        XCTAssertTrue(summary["entityTypes"]?.contains("doseEvent") == true)
        XCTAssertTrue(summary["entityTypes"]?.contains("protocol") == true)
    }

    // MARK: - 3. Performance Monitoring Service
    func testPerformanceMonitoringServiceLatencyAndPercentiles() async {
        let monitor = PerformanceMonitoringService()

        // Simulate 10 requests with varying latencies
        let latencies = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 600.0]

        for (index, lat) in latencies.enumerated() {
            await monitor.requestStarted()
            let status = (index == 9) ? 500 : 200
            await monitor.requestCompleted(
                method: "POST",
                path: "/api/v1/sync/outbox",
                statusCode: status,
                latencyMs: lat
            )
        }

        let snapshot = await monitor.generateSnapshot()
        XCTAssertEqual(snapshot.totalRequests, 10)
        XCTAssertEqual(snapshot.status2xxCount, 9)
        XCTAssertEqual(snapshot.status5xxCount, 1)
        XCTAssertEqual(snapshot.slowRequestsCount, 1) // 600ms is > 500ms
        XCTAssertEqual(snapshot.globalLatency.count, 10)
        XCTAssertEqual(snapshot.globalLatency.minMs, 10.0)
        XCTAssertEqual(snapshot.globalLatency.maxMs, 600.0)
        XCTAssertEqual(snapshot.globalLatency.p50Ms, 50.0)
        XCTAssertEqual(snapshot.globalLatency.p90Ms, 90.0)
        XCTAssertEqual(snapshot.globalLatency.p99Ms, 600.0)

        // Verify Prometheus output
        let prometheusText = await monitor.formatPrometheus()
        XCTAssertTrue(prometheusText.contains("vialr_http_requests_total{status=\"2xx\"} 9"))
        XCTAssertTrue(prometheusText.contains("vialr_http_requests_total{status=\"5xx\"} 1"))
        XCTAssertTrue(prometheusText.contains("vialr_http_slow_requests_total 1"))
        XCTAssertTrue(prometheusText.contains("vialr_http_latency_ms{quantile=\"0.5\"} 50.00"))
        XCTAssertTrue(prometheusText.contains("vialr_http_latency_ms{quantile=\"0.9\"} 90.00"))
    }

    // MARK: - 4. Error Monitoring & Fingerprinting
    func testErrorMonitoringServiceFingerprintingAndAlertSpike() async {
        let monitor = ErrorMonitoringService()

        struct SampleCustomError: Error, LocalizedError {
            var errorDescription: String? { "Database lock timeout after 5000ms" }
        }

        let err = SampleCustomError()
        let userId = UUID()

        // Record 5 errors in rapid succession to trigger spike anomaly detection
        for _ in 1...5 {
            await monitor.recordError(
                error: err,
                route: "/api/v1/doses",
                method: "POST",
                statusCode: 500,
                userId: userId,
                requestId: UUID().uuidString,
                isFatal: false
            )
        }

        let fingerprints = await monitor.getAllFingerprints()
        XCTAssertEqual(fingerprints.count, 1) // Deduplicated under 1 fingerprint

        let fp = fingerprints[0]
        XCTAssertEqual(fp.occurrenceCount, 5)
        XCTAssertEqual(fp.errorType, "SampleCustomError")
        XCTAssertEqual(fp.route, "/api/v1/doses")
        XCTAssertTrue(fp.sampleMessage.contains("Database lock timeout"))

        // Verify that alert history caught the spike
        let alerts = await monitor.getRecentAlerts()
        XCTAssertFalse(alerts.isEmpty)
        let spikeAlert = alerts.first { $0.category == .errorSpike }
        XCTAssertNotNil(spikeAlert)
        XCTAssertEqual(spikeAlert?.severity, .error)

        // Test fatal error alert
        struct FatalCrashError: Error, LocalizedError {
            var errorDescription: String? { "Fatal memory exhaustion in OCR engine" }
        }
        await monitor.recordError(
            error: FatalCrashError(),
            route: "/api/v1/background-jobs",
            method: "POST",
            statusCode: 500,
            userId: userId,
            isFatal: true
        )

        let updatedAlerts = await monitor.getRecentAlerts()
        let fatalAlert = updatedAlerts.first { $0.category == .healthDegraded }
        XCTAssertNotNil(fatalAlert)
        XCTAssertEqual(fatalAlert?.severity, .critical)
    }

    // MARK: - 5. Sync Observability & Health Monitoring
    func testSyncObservabilityServiceRejectionTrackingAndDegradationAlert() async {
        let syncMonitor = SyncObservabilityService()
        let userId = UUID()

        // Record successful push batch
        await syncMonitor.recordPushBatch(userId: userId, operationsCount: 20)

        // 18 successful operations
        for _ in 1...18 {
            await syncMonitor.recordOperationSuccess(
                userId: userId,
                operationId: UUID(),
                entityType: "doseEvent",
                status: "applied"
            )
        }

        // 2 rejected operations with reasons
        await syncMonitor.recordOperationFailure(
            userId: userId,
            operationId: UUID(),
            entityType: "doseEvent",
            operationType: "create",
            rejectionCode: "NON_POSITIVE_DOSE",
            failureReason: "Dose amount must be positive"
        )
        await syncMonitor.recordOperationFailure(
            userId: userId,
            operationId: UUID(),
            entityType: "labPanel",
            operationType: "create",
            rejectionCode: "INVALID_PAYLOAD",
            failureReason: "Invalid lab panel date format"
        )

        let snapshot = await syncMonitor.generateSnapshot()
        XCTAssertEqual(snapshot.totalOperations, 20)
        XCTAssertEqual(snapshot.appliedOperations, 18)
        XCTAssertEqual(snapshot.rejectedOperations, 2)
        XCTAssertEqual(snapshot.syncSuccessRatePercentage, 90.0) // 18/20 = 90%
        XCTAssertEqual(snapshot.operationsByEntity["doseEvent"], 19)
        XCTAssertEqual(snapshot.operationsByEntity["labPanel"], 1)
        XCTAssertEqual(snapshot.rejectionsByReasonCode["NON_POSITIVE_DOSE"], 1)
        XCTAssertEqual(snapshot.rejectionsByReasonCode["INVALID_PAYLOAD"], 1)
        XCTAssertEqual(snapshot.recentFailures.count, 2)
        XCTAssertTrue(snapshot.isDegraded) // Below 95% threshold with >=10 ops
    }

    // MARK: - 6. Background Job Observability & Dead-Letter Alerts
    func testBackgroundJobObservabilityDeadLetterAlert() async {
        let jobMonitor = BackgroundJobObservabilityService()
        let jobId = UUID()
        let userId = UUID()

        // 1. Enqueue job
        await jobMonitor.recordJobEnqueued(jobId: jobId, userId: userId, type: "pdfProcessing")

        // 2. Start job with 2.5s queue lag
        await jobMonitor.recordJobStarted(jobId: jobId, queueDurationSeconds: 2.5)

        // 3. Transient retries (attempts 1 and 2)
        await jobMonitor.recordJobRetry(
            jobId: jobId,
            userId: userId,
            type: "pdfProcessing",
            retryCount: 1,
            maxRetries: 3,
            errorMessage: "Temporary S3 network timeout",
            step: "1/4 Decrypting document"
        )

        await jobMonitor.recordJobRetry(
            jobId: jobId,
            userId: userId,
            type: "pdfProcessing",
            retryCount: 2,
            maxRetries: 3,
            errorMessage: "Temporary S3 network timeout",
            step: "1/4 Decrypting document"
        )

        // 4. Permanent dead-letter failure (attempt 3 of 3 exhausted)
        await jobMonitor.recordJobDeadLetter(
            jobId: jobId,
            userId: userId,
            type: "pdfProcessing",
            totalAttempts: 3,
            maxRetries: 3,
            errorMessage: "Corrupted PDF byte stream: EOF encountered",
            step: "2/4 Parsing OCR tables"
        )

        let snapshot = await jobMonitor.generateSnapshot(activeWorkers: 1, maxWorkers: 4)
        XCTAssertEqual(snapshot.deadLetterJobsCount, 1)
        XCTAssertEqual(snapshot.failedJobsCount, 1)
        XCTAssertEqual(snapshot.retryCountTotal, 2)
        XCTAssertEqual(snapshot.recentFailedJobs.count, 3) // 2 retries + 1 dead-letter
        XCTAssertTrue(snapshot.isDegraded) // Dead letters trigger degraded status

        let deadLetterRecord = snapshot.recentFailedJobs.first { $0.isDeadLetter }
        XCTAssertNotNil(deadLetterRecord)
        XCTAssertEqual(deadLetterRecord?.jobId, jobId)
        XCTAssertEqual(deadLetterRecord?.retryCount, 3)
        XCTAssertTrue(deadLetterRecord?.errorMessage.contains("Corrupted PDF byte stream") == true)
    }

    // MARK: - 7. Client-Side Observability Service
    func testClientObservabilityService() async {
        let client = ClientObservabilityService()

        await client.recordNetworkRequest(endpoint: "/api/v1/protocols", latencyMs: 35.4, statusCode: 200)
        await client.recordNetworkRequest(endpoint: "/api/v1/sync/outbox", latencyMs: 120.8, statusCode: 200)
        await client.recordNetworkRequest(endpoint: "/api/v1/sync/outbox", latencyMs: 450.0, statusCode: 503)
        await client.recordSyncSuccess(batchCount: 15)
        await client.recordSyncRejection(operationId: UUID(), entityType: "doseEvent", reason: "Negative dose amount")

        let summary = await client.getDiagnosticSummary()
        XCTAssertEqual(summary["networkFailures"], "1")
        XCTAssertEqual(summary["syncRejections"], "1")
        XCTAssertNotEqual(summary["lastSuccessfulSync"], "never")

        let logs = await client.getRecentLogs()
        XCTAssertEqual(logs.count, 5)
        XCTAssertTrue(logs.contains { $0.contains("Sync batch completed successfully") })
        XCTAssertTrue(logs.contains { $0.contains("Sync rejected") })
    }
}
