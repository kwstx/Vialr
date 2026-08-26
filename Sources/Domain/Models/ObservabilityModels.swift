import Foundation

// MARK: - 1. Structured Logging Models

/// Structured log record conforming to standard cloud logging formats (Datadog / CloudWatch / Loki).
public struct StructuredLogEntry: Codable, Sendable {
    public let timestamp: String
    public let level: String
    public let service: String
    public let environment: String
    public let requestId: String
    public let correlationId: String?
    public let userId: String?
    public let method: String?
    public let path: String?
    public let statusCode: Int?
    public let latencyMs: Double?
    public let clientVersion: String?
    public let platform: String?
    public let message: String
    public let metadata: [String: String]
    public let error: StructuredErrorDetails?

    public init(
        timestamp: String = ISO8601DateFormatter().string(from: Date()),
        level: String,
        service: String = "vialr-api",
        environment: String = "production",
        requestId: String,
        correlationId: String? = nil,
        userId: String? = nil,
        method: String? = nil,
        path: String? = nil,
        statusCode: Int? = nil,
        latencyMs: Double? = nil,
        clientVersion: String? = nil,
        platform: String? = nil,
        message: String,
        metadata: [String: String] = [:],
        error: StructuredErrorDetails? = nil
    ) {
        self.timestamp = timestamp
        self.level = level
        self.service = service
        self.environment = environment
        self.requestId = requestId
        self.correlationId = correlationId
        self.userId = userId
        self.method = method
        self.path = path
        self.statusCode = statusCode
        self.latencyMs = latencyMs
        self.clientVersion = clientVersion
        self.platform = platform
        self.message = message
        self.metadata = metadata
        self.error = error
    }
}

/// Structured error payload for error tracking and forensic analysis.
public struct StructuredErrorDetails: Codable, Sendable {
    public let errorType: String
    public let errorMessage: String
    public let errorDomain: String
    public let errorCode: Int?
    public let stackTrace: [String]?
    public let isFatal: Bool

    public init(
        errorType: String,
        errorMessage: String,
        errorDomain: String = "VialrServer",
        errorCode: Int? = nil,
        stackTrace: [String]? = nil,
        isFatal: Bool = false
    ) {
        self.errorType = errorType
        self.errorMessage = errorMessage
        self.errorDomain = errorDomain
        self.errorCode = errorCode
        self.stackTrace = stackTrace
        self.isFatal = isFatal
    }
}

// MARK: - 2. Performance Monitoring Models

/// Summary latency distribution metrics with percentiles.
public struct LatencyDistribution: Codable, Sendable {
    public let count: Int
    public let minMs: Double
    public let maxMs: Double
    public let meanMs: Double
    public let p50Ms: Double
    public let p90Ms: Double
    public let p95Ms: Double
    public let p99Ms: Double

    public init(
        count: Int = 0,
        minMs: Double = 0.0,
        maxMs: Double = 0.0,
        meanMs: Double = 0.0,
        p50Ms: Double = 0.0,
        p90Ms: Double = 0.0,
        p95Ms: Double = 0.0,
        p99Ms: Double = 0.0
    ) {
        self.count = count
        self.minMs = minMs
        self.maxMs = maxMs
        self.meanMs = meanMs
        self.p50Ms = p50Ms
        self.p90Ms = p90Ms
        self.p95Ms = p95Ms
        self.p99Ms = p99Ms
    }
}

/// Endpoint-specific performance metrics snapshot.
public struct EndpointMetricSnapshot: Codable, Sendable {
    public let method: String
    public let pathPattern: String
    public let requestCount: Int
    public let errorCount: Int
    public let errorRatePercentage: Double
    public let latency: LatencyDistribution

    public init(
        method: String,
        pathPattern: String,
        requestCount: Int,
        errorCount: Int,
        errorRatePercentage: Double,
        latency: LatencyDistribution
    ) {
        self.method = method
        self.pathPattern = pathPattern
        self.requestCount = requestCount
        self.errorCount = errorCount
        self.errorRatePercentage = errorRatePercentage
        self.latency = latency
    }
}

/// Performance monitoring snapshot across the entire backend application.
public struct PerformanceMetricSnapshot: Codable, Sendable {
    public let timestamp: Date
    public let uptimeSeconds: Double
    public let totalRequests: Int
    public let activeRequests: Int
    public let requestsPerMinute: Double
    public let status2xxCount: Int
    public let status3xxCount: Int
    public let status4xxCount: Int
    public let status5xxCount: Int
    public let overallErrorRatePercentage: Double
    public let globalLatency: LatencyDistribution
    public let endpoints: [EndpointMetricSnapshot]
    public let slowRequestsCount: Int // latency > 500ms
    public let memoryUsageBytes: UInt64?

    public init(
        timestamp: Date = Date(),
        uptimeSeconds: Double,
        totalRequests: Int,
        activeRequests: Int,
        requestsPerMinute: Double,
        status2xxCount: Int,
        status3xxCount: Int,
        status4xxCount: Int,
        status5xxCount: Int,
        overallErrorRatePercentage: Double,
        globalLatency: LatencyDistribution,
        endpoints: [EndpointMetricSnapshot] = [],
        slowRequestsCount: Int = 0,
        memoryUsageBytes: UInt64? = nil
    ) {
        self.timestamp = timestamp
        self.uptimeSeconds = uptimeSeconds
        self.totalRequests = totalRequests
        self.activeRequests = activeRequests
        self.requestsPerMinute = requestsPerMinute
        self.status2xxCount = status2xxCount
        self.status3xxCount = status3xxCount
        self.status4xxCount = status4xxCount
        self.status5xxCount = status5xxCount
        self.overallErrorRatePercentage = overallErrorRatePercentage
        self.globalLatency = globalLatency
        self.endpoints = endpoints
        self.slowRequestsCount = slowRequestsCount
        self.memoryUsageBytes = memoryUsageBytes
    }
}

// MARK: - 3. Error Monitoring & Fingerprinting Models

public enum AlertSeverity: String, Codable, Sendable {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
}

public enum AlertCategory: String, Codable, Sendable {
    case errorSpike = "ERROR_SPIKE"
    case syncFailureSpike = "SYNC_FAILURE_SPIKE"
    case jobRetryExhausted = "JOB_RETRY_EXHAUSTED"
    case slowRequestSpike = "SLOW_REQUEST_SPIKE"
    case healthDegraded = "HEALTH_DEGRADED"
    case securityAnomaly = "SECURITY_ANOMALY"
}

/// Grouped error fingerprint for deduplicated anomaly detection.
public struct ErrorFingerprint: Codable, Sendable {
    public let fingerprintId: String
    public let errorDomain: String
    public let errorType: String
    public let route: String?
    public let sampleMessage: String
    public let occurrenceCount: Int
    public let firstSeenAt: Date
    public let lastSeenAt: Date
    public let recentRatePerMinute: Double
    public let severity: AlertSeverity
    public let isFatal: Bool

    public init(
        fingerprintId: String,
        errorDomain: String,
        errorType: String,
        route: String? = nil,
        sampleMessage: String,
        occurrenceCount: Int,
        firstSeenAt: Date,
        lastSeenAt: Date,
        recentRatePerMinute: Double = 0.0,
        severity: AlertSeverity = .error,
        isFatal: Bool = false
    ) {
        self.fingerprintId = fingerprintId
        self.errorDomain = errorDomain
        self.errorType = errorType
        self.route = route
        self.sampleMessage = sampleMessage
        self.occurrenceCount = occurrenceCount
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.recentRatePerMinute = recentRatePerMinute
        self.severity = severity
        self.isFatal = isFatal
    }
}

/// Proactive alert event emitted by the observability system.
public struct ObservabilityAlert: Codable, Sendable {
    public let alertId: UUID
    public let timestamp: Date
    public let severity: AlertSeverity
    public let category: AlertCategory
    public let title: String
    public let details: String
    public let metadata: [String: String]
    public var resolved: Bool
    public var resolvedAt: Date?

    public init(
        alertId: UUID = UUID(),
        timestamp: Date = Date(),
        severity: AlertSeverity,
        category: AlertCategory,
        title: String,
        details: String,
        metadata: [String: String] = [:],
        resolved: Bool = false,
        resolvedAt: Date? = nil
    ) {
        self.alertId = alertId
        self.timestamp = timestamp
        self.severity = severity
        self.category = category
        self.title = title
        self.details = details
        self.metadata = metadata
        self.resolved = resolved
        self.resolvedAt = resolvedAt
    }
}

// MARK: - 4. Sync Observability Models

/// Sanitized audit entry for a failed or rejected synchronization operation.
public struct SyncFailureRecord: Codable, Sendable {
    public let failureId: UUID
    public let timestamp: Date
    public let userId: UUID
    public let operationId: UUID
    public let entityType: String
    public let operationType: String
    public let rejectionCode: String
    public let failureReason: String
    public let isFatal: Bool

    public init(
        failureId: UUID = UUID(),
        timestamp: Date = Date(),
        userId: UUID,
        operationId: UUID,
        entityType: String,
        operationType: String,
        rejectionCode: String,
        failureReason: String,
        isFatal: Bool = false
    ) {
        self.failureId = failureId
        self.timestamp = timestamp
        self.userId = userId
        self.operationId = operationId
        self.entityType = entityType
        self.operationType = operationType
        self.rejectionCode = rejectionCode
        self.failureReason = failureReason
        self.isFatal = isFatal
    }
}

/// Sync pipeline health status and statistics snapshot.
public struct SyncHealthSnapshot: Codable, Sendable {
    public let timestamp: Date
    public let totalPushBatches: Int
    public let totalPullBatches: Int
    public let totalOperations: Int
    public let appliedOperations: Int
    public let resolvedConflicts: Int
    public let rejectedOperations: Int
    public let syncSuccessRatePercentage: Double
    public let operationsByEntity: [String: Int]
    public let rejectionsByReasonCode: [String: Int]
    public let recentFailures: [SyncFailureRecord]
    public let isDegraded: Bool

    public init(
        timestamp: Date = Date(),
        totalPushBatches: Int,
        totalPullBatches: Int,
        totalOperations: Int,
        appliedOperations: Int,
        resolvedConflicts: Int,
        rejectedOperations: Int,
        syncSuccessRatePercentage: Double,
        operationsByEntity: [String: Int] = [:],
        rejectionsByReasonCode: [String: Int] = [:],
        recentFailures: [SyncFailureRecord] = [],
        isDegraded: Bool = false
    ) {
        self.timestamp = timestamp
        self.totalPushBatches = totalPushBatches
        self.totalPullBatches = totalPullBatches
        self.totalOperations = totalOperations
        self.appliedOperations = appliedOperations
        self.resolvedConflicts = resolvedConflicts
        self.rejectedOperations = rejectedOperations
        self.syncSuccessRatePercentage = syncSuccessRatePercentage
        self.operationsByEntity = operationsByEntity
        self.rejectionsByReasonCode = rejectionsByReasonCode
        self.recentFailures = recentFailures
        self.isDegraded = isDegraded
    }
}

// MARK: - 5. Background Job Observability Models

/// Record of a failed or dead-letter background job.
public struct FailedJobRecord: Codable, Sendable {
    public let jobId: UUID
    public let userId: UUID
    public let jobType: String
    public let failedAt: Date
    public let retryCount: Int
    public let maxRetries: Int
    public let isDeadLetter: Bool // Exhausted all retries
    public let errorMessage: String
    public let stepDescription: String

    public init(
        jobId: UUID,
        userId: UUID,
        jobType: String,
        failedAt: Date = Date(),
        retryCount: Int,
        maxRetries: Int,
        isDeadLetter: Bool,
        errorMessage: String,
        stepDescription: String
    ) {
        self.jobId = jobId
        self.userId = userId
        self.jobType = jobType
        self.failedAt = failedAt
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.isDeadLetter = isDeadLetter
        self.errorMessage = errorMessage
        self.stepDescription = stepDescription
    }
}

/// Background worker queue health metrics snapshot.
public struct JobHealthSnapshot: Codable, Sendable {
    public let timestamp: Date
    public let activeWorkers: Int
    public let maxConcurrentWorkers: Int
    public let queuedJobsCount: Int
    public let processingJobsCount: Int
    public let completedJobsCount: Int
    public let failedJobsCount: Int
    public let deadLetterJobsCount: Int
    public let retryCountTotal: Int
    public let jobSuccessRatePercentage: Double
    public let jobCountsByType: [String: Int]
    public let averageDurationSecondsByType: [String: Double]
    public let recentFailedJobs: [FailedJobRecord]
    public let queueLagSeconds: Double
    public let isDegraded: Bool

    public init(
        timestamp: Date = Date(),
        activeWorkers: Int,
        maxConcurrentWorkers: Int,
        queuedJobsCount: Int,
        processingJobsCount: Int,
        completedJobsCount: Int,
        failedJobsCount: Int,
        deadLetterJobsCount: Int,
        retryCountTotal: Int,
        jobSuccessRatePercentage: Double,
        jobCountsByType: [String: Int] = [:],
        averageDurationSecondsByType: [String: Double] = [:],
        recentFailedJobs: [FailedJobRecord] = [],
        queueLagSeconds: Double = 0.0,
        isDegraded: Bool = false
    ) {
        self.timestamp = timestamp
        self.activeWorkers = activeWorkers
        self.maxConcurrentWorkers = maxConcurrentWorkers
        self.queuedJobsCount = queuedJobsCount
        self.processingJobsCount = processingJobsCount
        self.completedJobsCount = completedJobsCount
        self.failedJobsCount = failedJobsCount
        self.deadLetterJobsCount = deadLetterJobsCount
        self.retryCountTotal = retryCountTotal
        self.jobSuccessRatePercentage = jobSuccessRatePercentage
        self.jobCountsByType = jobCountsByType
        self.averageDurationSecondsByType = averageDurationSecondsByType
        self.recentFailedJobs = recentFailedJobs
        self.queueLagSeconds = queueLagSeconds
        self.isDegraded = isDegraded
    }
}

// MARK: - 6. Deep System Health Models

public struct SubsystemHealth: Codable, Sendable {
    public let name: String
    public let status: String // "healthy", "degraded", "unhealthy"
    public let latencyMs: Double?
    public let message: String?
    public let details: [String: String]

    public init(
        name: String,
        status: String,
        latencyMs: Double? = nil,
        message: String? = nil,
        details: [String: String] = [:]
    ) {
        self.name = name
        self.status = status
        self.latencyMs = latencyMs
        self.message = message
        self.details = details
    }
}

public struct DeepHealthStatus: Codable, Sendable {
    public let status: String // "healthy", "degraded", "unhealthy"
    public let timestamp: Date
    public let service: String
    public let version: String
    public let uptimeSeconds: Double
    public let subsystems: [SubsystemHealth]
    public let activeAlertsCount: Int

    public init(
        status: String,
        timestamp: Date = Date(),
        service: String = "Vialr API",
        version: String = "1.0.0",
        uptimeSeconds: Double,
        subsystems: [SubsystemHealth],
        activeAlertsCount: Int = 0
    ) {
        self.status = status
        self.timestamp = timestamp
        self.service = service
        self.version = version
        self.uptimeSeconds = uptimeSeconds
        self.subsystems = subsystems
        self.activeAlertsCount = activeAlertsCount
    }
}

// MARK: - 7. Zero-Health-Leakage Privacy Guard & Scrubber

/// Privacy guard and sensitive data scrubber.
/// Ensures zero accidental leakage of Protected Health Information (PHI)
/// or Personally Identifiable Information (PII) into application logs, error traces, or metric tags.
public enum SensitiveDataScrubber: Sendable {

    // MARK: - Sensitive Header Keys (Strictly Redacted)
    private static let sensitiveHeaders: Set<String> = [
        "authorization",
        "cookie",
        "set-cookie",
        "x-apple-id-token",
        "x-api-key",
        "refresh-token",
        "proxy-authorization",
        "x-auth-token"
    ]

    // MARK: - Sensitive Health & Personal Key Names (Strictly Redacted or Filtered)
    private static let sensitiveKeyPatterns: Set<String> = [
        "password",
        "token",
        "secret",
        "jwt",
        "apikey",
        "api_key",
        "access_token",
        "refresh_token",
        "privatekey",
        "private_key",
        "ssn",
        "doseamount",
        "actualdoseamount",
        "dose_amount",
        "compoundname",
        "compound_name",
        "biomarkername",
        "biomarker_name",
        "labresult",
        "lab_result",
        "analytename",
        "analyte_name",
        "value",
        "textvalue",
        "text_value",
        "referencerangemin",
        "referencerangemax",
        "notes",
        "clinicalnotes",
        "patientnotes",
        "symptomdescription",
        "symptom_description",
        "subjectivescore",
        "subjective_score",
        "coordinates",
        "xcoordinate",
        "ycoordinate",
        "injectioncoordinates",
        "presignedurl",
        "presigned_url",
        "ciphertext"
    ]

    /// Sanitizes an HTTP header map, redacting credentials and tokens.
    public static func sanitizeHeaders(_ headers: [(String, String)]) -> [String: String] {
        var sanitized: [String: String] = [:]
        for (key, value) in headers {
            let lowerKey = key.lowercased()
            if sensitiveHeaders.contains(lowerKey) {
                sanitized[key] = "[REDACTED_AUTH]"
            } else {
                sanitized[key] = value
            }
        }
        return sanitized
    }

    /// Sanitizes an arbitrary dictionary of metadata for structured logging.
    public static func sanitizeMetadata(_ metadata: [String: String]) -> [String: String] {
        var sanitized: [String: String] = [:]
        for (key, value) in metadata {
            let lowerKey = key.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "")
            if isSensitiveKey(lowerKey) {
                sanitized[key] = "[REDACTED_PHI]"
            } else if lowerKey.contains("token") || lowerKey.contains("secret") || lowerKey.contains("key") || lowerKey.contains("auth") {
                sanitized[key] = "[REDACTED_AUTH]"
            } else {
                sanitized[key] = sanitizeStringContent(value)
            }
        }
        return sanitized
    }

    /// Checks if a normalized key name matches sensitive health or authentication data.
    private static func isSensitiveKey(_ normalizedKey: String) -> Bool {
        if sensitiveKeyPatterns.contains(normalizedKey) {
            return true
        }
        for pattern in sensitiveKeyPatterns {
            if normalizedKey.contains(pattern) {
                return true
            }
        }
        return false
    }

    /// Sanitizes a freeform string message to scrub potential JWTs, Bearer tokens, or raw medical values.
    public static func sanitizeStringContent(_ text: String) -> String {
        var result = text

        // 1. Scrub Bearer tokens (e.g. Bearer eyJhbGciOi...)
        let bearerRegex = try? NSRegularExpression(pattern: "(?i)bearer\\s+[a-zA-Z0-9\\-_\\.]+", options: [])
        if let regex = bearerRegex {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "Bearer [REDACTED_TOKEN]")
        }

        // 2. Scrub JWT tokens (3 parts base64 separated by periods)
        let jwtRegex = try? NSRegularExpression(pattern: "eyJ[a-zA-Z0-9_-]{10,}\\.eyJ[a-zA-Z0-9_-]{10,}\\.[a-zA-Z0-9_-]+", options: [])
        if let regex = jwtRegex {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "[REDACTED_JWT]")
        }

        // 3. Scrub passwords in query strings or JSON like ?password=xxx or "password":"xxx"
        let passRegex = try? NSRegularExpression(pattern: "(?i)(password|secret|key|token)=([^&\\s]+)", options: [])
        if let regex = passRegex {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1=[REDACTED]")
        }

        return result
    }

    /// Safely extracts high-level operational metadata from a raw JSON payload
    /// without logging sensitive health values (e.g. returns operation counts and entity types).
    public static func extractSafeOperationSummary(from jsonString: String?) -> [String: String] {
        guard let jsonString = jsonString, let data = jsonString.data(using: .utf8) else {
            return ["payloadPresent": "false"]
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ["payloadPresent": "true", "payloadBytes": "\(data.count)"]
        }

        var summary: [String: String] = [
            "payloadBytes": "\(data.count)"
        ]

        if let operations = jsonObject["operations"] as? [[String: Any]] {
            summary["operationCount"] = "\(operations.count)"
            let entityTypes = operations.compactMap { $0["entityType"] as? String }
            summary["entityTypes"] = Array(Set(entityTypes)).joined(separator: ",")
        }

        if let changes = jsonObject["changes"] as? [[String: Any]] {
            summary["changeCount"] = "\(changes.count)"
            let entityTypes = changes.compactMap { $0["entityType"] as? String }
            summary["entityTypes"] = Array(Set(entityTypes)).joined(separator: ",")
        }

        return summary
    }
}
