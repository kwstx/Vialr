import Foundation
import Vapor
import Domain

/// Core request-tracing and observability middleware.
/// Injects request identifiers, measures execution latency with sub-millisecond precision,
/// emits structured access logs with user-safe metadata, detects slow requests,
/// and forwards performance and error metrics to monitoring engines.
public struct ObservabilityMiddleware: AsyncMiddleware {
    private let serviceName: String
    private let environment: String

    public init(
        serviceName: String = "vialr-api",
        environment: String = "production"
    ) {
        self.serviceName = serviceName
        self.environment = environment
    }

    public func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let startTime = DispatchTime.now()

        // 1. Resolve or generate Request ID and Correlation ID
        let requestId = req.headers.first(name: "X-Request-ID") ?? UUID().uuidString
        let correlationId = req.headers.first(name: "X-Correlation-ID") ?? requestId

        // 2. Attach tracing identifiers to request logger
        req.logger[metadataKey: "requestId"] = "\(requestId)"
        req.logger[metadataKey: "correlationId"] = "\(correlationId)"
        req.logger[metadataKey: "service"] = "\(serviceName)"
        req.logger[metadataKey: "method"] = "\(req.method.rawValue)"
        req.logger[metadataKey: "path"] = "\(req.url.path)"

        // Client device and version metadata
        if let clientVersion = req.headers.first(name: "X-Client-Version") {
            req.logger[metadataKey: "clientVersion"] = "\(clientVersion)"
        }
        if let platform = req.headers.first(name: "X-Platform") {
            req.logger[metadataKey: "platform"] = "\(platform)"
        }

        // Notify performance monitor of in-flight request
        await req.application.performanceMonitor.requestStarted()

        do {
            let response = try await next.respond(to: req)

            // Calculate elapsed time in milliseconds
            let endTime = DispatchTime.now()
            let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
            let latencyMs = Double(nanoTime) / 1_000_000.0

            // 3. Inject tracing headers into HTTP response
            response.headers.replaceOrAdd(name: "X-Request-ID", value: requestId)
            response.headers.replaceOrAdd(name: "X-Correlation-ID", value: correlationId)
            response.headers.replaceOrAdd(name: "X-Response-Time-Ms", value: String(format: "%.2f", latencyMs))

            let statusCode = Int(response.status.code)

            // 4. Update performance metrics
            await req.application.performanceMonitor.requestCompleted(
                method: req.method.rawValue,
                path: req.url.path,
                statusCode: statusCode,
                latencyMs: latencyMs
            )

            // Extract authenticated user ID if present
            var safeMetadata: [String: String] = [
                "statusCode": "\(statusCode)",
                "latencyMs": String(format: "%.2f", latencyMs)
            ]
            if let userPayload = req.auth.get(UserPayload.self) {
                safeMetadata["userId"] = userPayload.userId.uuidString
            }

            // 5. Emit structured access log
            let message = "HTTP \(req.method.rawValue) \(req.url.path) -> \(statusCode) (\(String(format: "%.1f", latencyMs))ms)"
            if latencyMs > 2000.0 {
                // Slow request alert (> 2 seconds)
                req.logger.warning("\(message) [CRITICAL_SLOW_REQUEST]", metadata: safeMetadata.mapValues { .string($0) })
                let alert = ObservabilityAlert(
                    severity: .warning,
                    category: .slowRequestSpike,
                    title: "Extreme Latency Detected: \(req.method.rawValue) \(req.url.path)",
                    details: "Request took \(String(format: "%.2f", latencyMs))ms to complete.",
                    metadata: safeMetadata
                )
                await req.application.errorMonitor.fireAlert(alert)
            } else if latencyMs > 500.0 {
                // Slow request warning (> 500ms)
                req.logger.notice("\(message) [SLOW_REQUEST]", metadata: safeMetadata.mapValues { .string($0) })
            } else {
                req.logger.info("\(message)", metadata: safeMetadata.mapValues { .string($0) })
            }

            return response
        } catch {
            let endTime = DispatchTime.now()
            let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
            let latencyMs = Double(nanoTime) / 1_000_000.0

            let statusCode: Int
            if let abort = error as? AbortError {
                statusCode = Int(abort.status.code)
            } else {
                statusCode = 500
            }

            // Record to performance monitor
            await req.application.performanceMonitor.requestCompleted(
                method: req.method.rawValue,
                path: req.url.path,
                statusCode: statusCode,
                latencyMs: latencyMs
            )

            // Record to proactive error monitor
            let userId = req.auth.get(UserPayload.self)?.userId
            await req.application.errorMonitor.recordError(
                error: error,
                route: req.url.path,
                method: req.method.rawValue,
                statusCode: statusCode,
                userId: userId,
                requestId: requestId,
                isFatal: statusCode >= 500
            )

            var errorMetadata: [String: String] = [
                "statusCode": "\(statusCode)",
                "latencyMs": String(format: "%.2f", latencyMs),
                "errorType": String(describing: type(of: error)),
                "errorMessage": SensitiveDataScrubber.sanitizeStringContent(error.localizedDescription)
            ]
            if let uid = userId {
                errorMetadata["userId"] = uid.uuidString
            }

            req.logger.error("HTTP \(req.method.rawValue) \(req.url.path) FAILED -> \(statusCode): \(error.localizedDescription)", metadata: errorMetadata.mapValues { .string($0) })

            throw error
        }
    }
}
