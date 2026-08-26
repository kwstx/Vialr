import Vapor
import Fluent
import Domain

/// Controller managing asynchronous background processing jobs and worker state.
/// Provides non-blocking job submission, real-time status queries, progress polling, cancellation, and retry.
public struct BackgroundJobsController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let jobsGroup = routes.grouped("jobs")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        // Core Job Endpoints
        jobsGroup.get(use: listJobs)
        jobsGroup.post(use: enqueueJob)
        jobsGroup.get(":jobId", use: getJobStatus)
        jobsGroup.post(":jobId", "cancel", use: cancelJob)
        jobsGroup.post(":jobId", "retry", use: retryJob)

        // Specialized Async Job Triggers (Never blocking HTTP requests)
        jobsGroup.post("reports", "generate-async", use: triggerReportGenerationAsync)
        jobsGroup.post("export-async", use: triggerDataExportAsync)
        jobsGroup.post("analytics", "calculate-async", use: triggerAnalyticsCalculationAsync)
        jobsGroup.post("notifications", "prepare-async", use: triggerNotificationPreparationAsync)
        jobsGroup.post("sync", "run-async", use: triggerSyncJobAsync)
    }

    // MARK: - 1. List Jobs
    public func listJobs(req: Request) async throws -> [BackgroundJobDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let filter = try req.query.decode(BackgroundJobListFilterQueryDTO.self)

        var query = BackgroundJobEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)

        if let status = filter.status {
            query = query.filter(\.$status == status)
        }
        if let type = filter.jobType {
            query = query.filter(\.$jobType == type)
        }

        let limit = filter.limit ?? 50
        let entities = try await query
            .sort(\.$createdAt, .descending)
            .range(0..<limit)
            .all()

        return entities.map { BackgroundJobDTO(from: $0) }
    }

    // MARK: - 2. Generic Enqueue Job (Non-blocking)
    public func enqueueJob(req: Request) async throws -> Response {
        let payload = try req.auth.require(UserPayload.self)
        let input = try req.content.decode(CreateBackgroundJobRequestDTO.self)

        guard let jobType = BackgroundJobType(rawValue: input.jobType) else {
            throw Abort(.badRequest, reason: "Invalid job type. Supported: \(BackgroundJobType.allCases.map { $0.rawValue }.joined(separator: ", "))")
        }

        let job = try await req.application.backgroundJobQueue.enqueueJob(
            userId: payload.userId,
            type: jobType,
            payloadJson: input.payloadJson,
            maxRetries: input.maxRetries ?? 3
        )

        let dto = BackgroundJobDTO(from: job)
        let response = Response(status: .accepted)
        try response.content.encode(dto)
        return response
    }

    // MARK: - 3. Get Job Status & Progress
    public func getJobStatus(req: Request) async throws -> BackgroundJobDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let jobId = req.parameters.get("jobId", as: UUID.self),
              let job = try await BackgroundJobEntity.query(on: req.db)
                .filter(\.$id == jobId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Background job not found.")
        }

        return BackgroundJobDTO(from: job)
    }

    // MARK: - 4. Cancel Job
    public func cancelJob(req: Request) async throws -> BackgroundJobActionResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let jobId = req.parameters.get("jobId", as: UUID.self),
              let job = try await BackgroundJobEntity.query(on: req.db)
                .filter(\.$id == jobId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Background job not found.")
        }

        guard job.status == BackgroundJobStatus.queued.rawValue || job.status == BackgroundJobStatus.processing.rawValue else {
            throw Abort(.badRequest, reason: "Cannot cancel a job with status '\(job.status)'")
        }

        job.status = BackgroundJobStatus.cancelled.rawValue
        job.stepDescription = "Job cancelled by user request."
        job.completedAt = Date()
        try await job.save(on: req.db)

        return BackgroundJobActionResponseDTO(job: BackgroundJobDTO(from: job), message: "Job cancelled successfully.")
    }

    // MARK: - 5. Retry Job
    public func retryJob(req: Request) async throws -> Response {
        let payload = try req.auth.require(UserPayload.self)
        guard let jobId = req.parameters.get("jobId", as: UUID.self),
              let job = try await BackgroundJobEntity.query(on: req.db)
                .filter(\.$id == jobId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Background job not found.")
        }

        job.status = BackgroundJobStatus.queued.rawValue
        job.progress = 0.0
        job.stepDescription = "Queued for retry."
        job.errorMessage = nil
        job.startedAt = nil
        job.completedAt = nil
        try await job.save(on: req.db)

        // Wake up worker
        Task.detached(priority: .userInitiated) { [app = req.application] in
            await app.backgroundJobQueue.processJob(jobId: jobId)
        }

        let dto = BackgroundJobDTO(from: job)
        let response = Response(status: .accepted)
        try response.content.encode(dto)
        return response
    }

    // MARK: - 6. Trigger Report Generation Async
    public func triggerReportGenerationAsync(req: Request) async throws -> Response {
        let payload = try req.auth.require(UserPayload.self)
        let input = try req.content.decode(ClinicianReportRequestDTO.self)

        let jobPayload = ReportGenerationJobPayload(
            dateRangeStart: input.dateRangeStart,
            dateRangeEnd: input.dateRangeEnd,
            patientName: input.patientName,
            includeProtocols: input.includeProtocols ?? true,
            includeDoses: input.includeDoses ?? true,
            includeBiomarkers: input.includeBiomarkers ?? true,
            includeMeasurements: input.includeMeasurements ?? true,
            includeSymptoms: input.includeSymptoms ?? true,
            includeFullLedger: input.includeFullLedger ?? true
        )
        let payloadData = try JSONEncoder().encode(jobPayload)
        let payloadString = String(data: payloadData, encoding: .utf8)

        let job = try await req.application.backgroundJobQueue.enqueueJob(
            userId: payload.userId,
            type: .reportGeneration,
            payloadJson: payloadString
        )

        let dto = BackgroundJobDTO(from: job)
        let response = Response(status: .accepted)
        try response.content.encode(dto)
        return response
    }

    // MARK: - 7. Trigger Data Export Async
    public func triggerDataExportAsync(req: Request) async throws -> Response {
        let payload = try req.auth.require(UserPayload.self)
        let jobPayload = DataExportJobPayload(exportFormat: "bundle_zip", includeAuditLogs: true, encryptArchive: true)
        let payloadData = try JSONEncoder().encode(jobPayload)
        let payloadString = String(data: payloadData, encoding: .utf8)

        let job = try await req.application.backgroundJobQueue.enqueueJob(
            userId: payload.userId,
            type: .dataExport,
            payloadJson: payloadString
        )

        let dto = BackgroundJobDTO(from: job)
        let response = Response(status: .accepted)
        try response.content.encode(dto)
        return response
    }

    // MARK: - 8. Trigger Analytics Calculation Async
    public func triggerAnalyticsCalculationAsync(req: Request) async throws -> Response {
        let payload = try req.auth.require(UserPayload.self)
        let jobPayload = AnalyticsCalculationJobPayload(
            computeHalfLifeDecayCurves: true,
            computeAdherenceTimeline: true,
            computeBiomarkerCorrelations: true
        )
        let payloadData = try JSONEncoder().encode(jobPayload)
        let payloadString = String(data: payloadData, encoding: .utf8)

        let job = try await req.application.backgroundJobQueue.enqueueJob(
            userId: payload.userId,
            type: .analyticsCalculation,
            payloadJson: payloadString
        )

        let dto = BackgroundJobDTO(from: job)
        let response = Response(status: .accepted)
        try response.content.encode(dto)
        return response
    }

    // MARK: - 9. Trigger Notification Preparation Async
    public func triggerNotificationPreparationAsync(req: Request) async throws -> Response {
        let payload = try req.auth.require(UserPayload.self)
        let jobPayload = NotificationPreparationJobPayload(daysAhead: 30, recalculateStockAlerts: true)
        let payloadData = try JSONEncoder().encode(jobPayload)
        let payloadString = String(data: payloadData, encoding: .utf8)

        let job = try await req.application.backgroundJobQueue.enqueueJob(
            userId: payload.userId,
            type: .notificationPreparation,
            payloadJson: payloadString
        )

        let dto = BackgroundJobDTO(from: job)
        let response = Response(status: .accepted)
        try response.content.encode(dto)
        return response
    }

    // MARK: - 10. Trigger Sync Job Async
    public func triggerSyncJobAsync(req: Request) async throws -> Response {
        let payload = try req.auth.require(UserPayload.self)
        let jobPayload = SyncJobPayload(deviceId: "iOS-Client", fullReconciliation: true, forcePushUnsynced: true)
        let payloadData = try JSONEncoder().encode(jobPayload)
        let payloadString = String(data: payloadData, encoding: .utf8)

        let job = try await req.application.backgroundJobQueue.enqueueJob(
            userId: payload.userId,
            type: .synchronization,
            payloadJson: payloadString
        )

        let dto = BackgroundJobDTO(from: job)
        let response = Response(status: .accepted)
        try response.content.encode(dto)
        return response
    }
}
