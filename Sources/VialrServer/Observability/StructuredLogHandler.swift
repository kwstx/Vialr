import Foundation
import Logging
import Domain

/// High-performance, JSON-formatted structured log handler conforming to Swift `LogHandler`.
/// Ensures all log lines emitted by the server are structured JSON objects containing
/// request identifiers, user-safe metadata, latency, errors, and service names,
/// with automatic PHI/PII scrubbing.
public struct StructuredLogHandler: LogHandler, Sendable {
    public var metadata: Logger.Metadata = [:]
    public var logLevel: Logger.Level
    private let label: String
    private let service: String
    private let environment: String

    public init(
        label: String,
        logLevel: Logger.Level = .info,
        service: String = "vialr-api",
        environment: String = "production"
    ) {
        self.label = label
        self.logLevel = logLevel
        self.service = service
        self.environment = environment
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        guard level >= self.logLevel else { return }

        var mergedMetadata: [String: String] = [:]
        
        // Merge handler metadata
        for (k, v) in self.metadata {
            mergedMetadata[k] = "\(v)"
        }
        // Merge call-site metadata
        if let metadata = metadata {
            for (k, v) in metadata {
                mergedMetadata[k] = "\(v)"
            }
        }

        // Sanitize all metadata to prevent PHI/PII leaks
        let sanitizedMetadata = SensitiveDataScrubber.sanitizeMetadata(mergedMetadata)

        // Extract key contextual fields if present
        let requestId = sanitizedMetadata["requestId"] ?? sanitizedMetadata["request-id"] ?? UUID().uuidString
        let correlationId = sanitizedMetadata["correlationId"] ?? sanitizedMetadata["correlation-id"]
        let userId = sanitizedMetadata["userId"] ?? sanitizedMetadata["user-id"]
        let method = sanitizedMetadata["method"] ?? sanitizedMetadata["httpMethod"]
        let path = sanitizedMetadata["path"] ?? sanitizedMetadata["endpoint"]
        let statusCode = sanitizedMetadata["statusCode"].flatMap(Int.init)
        let latencyMs = sanitizedMetadata["latencyMs"].flatMap(Double.init)
        let clientVersion = sanitizedMetadata["clientVersion"]
        let platform = sanitizedMetadata["platform"]

        // Extract structured error details if present
        var errorDetails: StructuredErrorDetails? = nil
        if let errorType = sanitizedMetadata["errorType"] {
            let errorMsg = sanitizedMetadata["errorMessage"] ?? sanitizedMetadata["error"] ?? ""
            let errorDomain = sanitizedMetadata["errorDomain"] ?? "VialrServer"
            let errorCode = sanitizedMetadata["errorCode"].flatMap(Int.init)
            let isFatal = sanitizedMetadata["isFatal"].flatMap(Bool.init) ?? (level == .critical)
            errorDetails = StructuredErrorDetails(
                errorType: errorType,
                errorMessage: SensitiveDataScrubber.sanitizeStringContent(errorMsg),
                errorDomain: errorDomain,
                errorCode: errorCode,
                stackTrace: ["\(file):\(line) \(function)"],
                isFatal: isFatal
            )
        }

        // Sanitize message content
        let sanitizedMessage = SensitiveDataScrubber.sanitizeStringContent(message.description)

        // Filter out extracted top-level keys from residual metadata dictionary
        var residualMetadata = sanitizedMetadata
        let topLevelKeys = [
            "requestId", "request-id", "correlationId", "correlation-id",
            "userId", "user-id", "method", "httpMethod", "path", "endpoint",
            "statusCode", "latencyMs", "clientVersion", "platform",
            "errorType", "errorMessage", "error", "errorDomain", "errorCode", "isFatal"
        ]
        for key in topLevelKeys {
            residualMetadata.removeValue(forKey: key)
        }

        let entry = StructuredLogEntry(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            level: level.rawValue.uppercased(),
            service: self.service,
            environment: self.environment,
            requestId: requestId,
            correlationId: correlationId,
            userId: userId,
            method: method,
            path: path,
            statusCode: statusCode,
            latencyMs: latencyMs,
            clientVersion: clientVersion,
            platform: platform,
            message: sanitizedMessage,
            metadata: residualMetadata,
            error: errorDetails
        )

        // Output single-line JSON log entry
        if let jsonData = try? JSONEncoder().encode(entry),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        } else {
            print("{\"timestamp\":\"\(entry.timestamp)\",\"level\":\"\(entry.level)\",\"service\":\"\(entry.service)\",\"requestId\":\"\(requestId)\",\"message\":\"\(sanitizedMessage)\"}")
        }
    }
}
