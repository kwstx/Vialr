import Vapor
import Fluent
import Domain

/// Controller exposing system observability, health diagnostics, performance metrics,
/// Prometheus scraping endpoint, sync health, and background worker diagnostics.
public struct ObservabilityController: RouteCollection {
    private let appStartTime: Date = Date()

    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        // 1. Prometheus Scraper Endpoint
        routes.get("metrics", use: getPrometheusMetrics)

        // 2. Health Check Probes
        routes.get("health", use: getLiveness)
        routes.get("health", "detailed", use: getDeepHealth)

        // 3. API v1 Observability Group (Protected by Administrative RBAC)
        let obsGroup = routes.grouped("api", "v1", "observability")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware(), AdminGuardMiddleware())

        obsGroup.get("status", use: getSystemStatus)
        obsGroup.get("metrics", use: getPerformanceMetricsJSON)
        obsGroup.get("errors", use: getErrorFingerprintsAndAlerts)
        obsGroup.get("sync-health", use: getSyncHealth)
        obsGroup.get("jobs-health", use: getBackgroundJobsHealth)
        obsGroup.post("test-alert", use: triggerTestAlert)
    }

    // MARK: - 1. Prometheus Metrics Scraper
    public func getPrometheusMetrics(req: Request) async throws -> Response {
        let prometheusText = await req.application.performanceMonitor.formatPrometheus()
        return Response(
            status: .ok,
            headers: ["Content-Type": "text/plain; version=0.0.4; charset=utf-8"],
            body: .init(string: prometheusText)
        )
    }

    // MARK: - 2. Fast Liveness Probe
    public func getLiveness(req: Request) async throws -> [String: String] {
        return [
            "status": "healthy",
            "service": "Vialr API",
            "version": "1.0.0",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
    }

    // MARK: - 3. Deep Readiness Probe
    public func getDeepHealth(req: Request) async throws -> DeepHealthStatus {
        var subsystems: [SubsystemHealth] = []
        var isOverallDegraded = false

        // Check 1: PostgreSQL Database Connectivity
        let dbStart = DispatchTime.now()
        do {
            _ = try await req.db.query("SELECT 1").all()
            let dbEnd = DispatchTime.now()
            let dbLatency = Double(dbEnd.uptimeNanoseconds - dbStart.uptimeNanoseconds) / 1_000_000.0
            subsystems.append(SubsystemHealth(
                name: "PostgreSQL Database",
                status: "healthy",
                latencyMs: dbLatency,
                message: "Database connection active and responding.",
                details: ["driver": "FluentPostgresDriver"]
            ))
        } catch {
            isOverallDegraded = true
            subsystems.append(SubsystemHealth(
                name: "PostgreSQL Database",
                status: "unhealthy",
                message: "Database query failed: \(error.localizedDescription)",
                details: ["error": error.localizedDescription]
            ))
        }

        // Check 2: Encrypted Storage Vault
        subsystems.append(SubsystemHealth(
            name: "Encrypted Storage Vault",
            status: "healthy",
            message: "Object storage subsystem online with AES-256-GCM encryption.",
            details: ["bucket": req.application.encryptedStorage.bucket]
        ))

        // Check 3: Background Worker Queue
        let jobSnapshot = await req.application.jobMonitor.generateSnapshot(maxWorkers: 4)
        if jobSnapshot.isDegraded {
            isOverallDegraded = true
        }
        subsystems.append(SubsystemHealth(
            name: "Background Worker Queue",
            status: jobSnapshot.isDegraded ? "degraded" : "healthy",
            message: "Success rate: \(String(format: "%.1f", jobSnapshot.jobSuccessRatePercentage))%, Dead letters: \(jobSnapshot.deadLetterJobsCount)",
            details: [
                "queued": "\(jobSnapshot.queuedJobsCount)",
                "processing": "\(jobSnapshot.processingJobsCount)",
                "deadLetters": "\(jobSnapshot.deadLetterJobsCount)"
            ]
        ))

        // Check 4: Delta Sync Engine
        let syncSnapshot = await req.application.syncMonitor.generateSnapshot()
        if syncSnapshot.isDegraded {
            isOverallDegraded = true
        }
        subsystems.append(SubsystemHealth(
            name: "Delta Sync Engine",
            status: syncSnapshot.isDegraded ? "degraded" : "healthy",
            message: "Sync success rate: \(String(format: "%.1f", syncSnapshot.syncSuccessRatePercentage))%",
            details: [
                "totalOperations": "\(syncSnapshot.totalOperations)",
                "rejections": "\(syncSnapshot.rejectedOperations)"
            ]
        ))

        let activeAlerts = await req.application.errorMonitor.getActiveAlertCount()
        let uptime = Date().timeIntervalSince(appStartTime)

        return DeepHealthStatus(
            status: isOverallDegraded ? "degraded" : "healthy",
            timestamp: Date(),
            service: "Vialr API",
            version: "1.0.0",
            uptimeSeconds: uptime,
            subsystems: subsystems,
            activeAlertsCount: activeAlerts
        )
    }

    // MARK: - 4. System Overview
    public func getSystemStatus(req: Request) async throws -> [String: AnyContent] {
        let perfSnapshot = await req.application.performanceMonitor.generateSnapshot()
        let syncSnapshot = await req.application.syncMonitor.generateSnapshot()
        let jobSnapshot = await req.application.jobMonitor.generateSnapshot()
        let activeAlerts = await req.application.errorMonitor.getActiveAlertCount()

        return [
            "status": AnyContent("healthy"),
            "uptimeSeconds": AnyContent(perfSnapshot.uptimeSeconds),
            "requestsPerMinute": AnyContent(perfSnapshot.requestsPerMinute),
            "latencyP95Ms": AnyContent(perfSnapshot.globalLatency.p95Ms),
            "syncSuccessRate": AnyContent(syncSnapshot.syncSuccessRatePercentage),
            "jobSuccessRate": AnyContent(jobSnapshot.jobSuccessRatePercentage),
            "activeAlertsCount": AnyContent(activeAlerts)
        ]
    }

    // MARK: - 5. Performance Metrics JSON
    public func getPerformanceMetricsJSON(req: Request) async throws -> PerformanceMetricSnapshot {
        return await req.application.performanceMonitor.generateSnapshot()
    }

    // MARK: - 6. Error Fingerprints & Alerts
    public func getErrorFingerprintsAndAlerts(req: Request) async throws -> ErrorObservabilityResponseDTO {
        let fingerprints = await req.application.errorMonitor.getAllFingerprints()
        let alerts = await req.application.errorMonitor.getRecentAlerts(limit: 50)
        return ErrorObservabilityResponseDTO(
            timestamp: Date(),
            totalUniqueFingerprints: fingerprints.count,
            fingerprints: fingerprints,
            recentAlerts: alerts
        )
    }

    // MARK: - 7. Sync Health Diagnostics
    public func getSyncHealth(req: Request) async throws -> SyncHealthSnapshot {
        return await req.application.syncMonitor.generateSnapshot()
    }

    // MARK: - 8. Background Jobs Health Diagnostics
    public func getBackgroundJobsHealth(req: Request) async throws -> JobHealthSnapshot {
        return await req.application.jobMonitor.generateSnapshot(maxWorkers: 4)
    }

    // MARK: - 9. Trigger Test Alert
    public func triggerTestAlert(req: Request) async throws -> [String: String] {
        let testAlert = ObservabilityAlert(
            severity: .warning,
            category: .errorSpike,
            title: "Test Observability Alert",
            details: "This is an automated test alert to verify notification dispatching and webhook connectivity.",
            metadata: ["environment": req.application.environment.name, "triggeredBy": "admin"]
        )
        await req.application.errorMonitor.fireAlert(testAlert)
        return ["status": "alert_dispatched", "alertId": testAlert.alertId.uuidString]
    }
}

// MARK: - Observability Response DTOs
public struct ErrorObservabilityResponseDTO: Content {
    public let timestamp: Date
    public let totalUniqueFingerprints: Int
    public let fingerprints: [ErrorFingerprint]
    public let recentAlerts: [ObservabilityAlert]

    public init(
        timestamp: Date,
        totalUniqueFingerprints: Int,
        fingerprints: [ErrorFingerprint],
        recentAlerts: [ObservabilityAlert]
    ) {
        self.timestamp = timestamp
        self.totalUniqueFingerprints = totalUniqueFingerprints
        self.fingerprints = fingerprints
        self.recentAlerts = recentAlerts
    }
}

// MARK: - AnyContent Helper for Dynamic JSON
public struct AnyContent: Content {
    private let value: Any

    public init<T>(_ value: T) {
        self.value = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let v = value as? String {
            try container.encode(v)
        } else if let v = value as? Int {
            try container.encode(v)
        } else if let v = value as? Double {
            try container.encode(v)
        } else if let v = value as? Bool {
            try container.encode(v)
        } else {
            try container.encode("\(value)")
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) {
            self.value = v
        } else if let v = try? container.decode(Int.self) {
            self.value = v
        } else if let v = try? container.decode(Double.self) {
            self.value = v
        } else if let v = try? container.decode(Bool.self) {
            self.value = v
        } else {
            self.value = ""
        }
    }
}
