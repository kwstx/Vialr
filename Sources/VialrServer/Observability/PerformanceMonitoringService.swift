import Foundation
import Vapor
import Domain

/// High-performance, thread-safe performance monitoring engine.
/// Continuously tracks API latency distributions, request rates, status codes,
/// endpoint-level metrics, and slow requests.
public actor PerformanceMonitoringService {
    private let startTime: Date = Date()
    private var totalRequests: Int = 0
    private var activeRequests: Int = 0
    private var status2xxCount: Int = 0
    private var status3xxCount: Int = 0
    private var status4xxCount: Int = 0
    private var status5xxCount: Int = 0
    private var slowRequestsCount: Int = 0 // Latency > 500ms

    // Global latency circular buffer (capped at 5,000 samples for high efficiency)
    private var globalLatencies: [Double] = []
    private let maxLatencySamples: Int = 5000

    // Recent requests timestamps for accurate RPM calculation (within last 60 seconds)
    private var recentRequestTimestamps: [Date] = []

    // Per-endpoint metrics
    private struct EndpointRecord {
        var count: Int = 0
        var errorCount: Int = 0
        var latencies: [Double] = []
    }
    private var endpointMetrics: [String: EndpointRecord] = [:]

    public init() {}

    // MARK: - Request Lifecycle Tracking
    public func requestStarted() {
        totalRequests += 1
        activeRequests += 1
        let now = Date()
        recentRequestTimestamps.append(now)
        pruneRecentTimestamps(now: now)
    }

    public func requestCompleted(
        method: String,
        path: String,
        statusCode: Int,
        latencyMs: Double
    ) {
        if activeRequests > 0 {
            activeRequests -= 1
        }

        // Status code categorization
        switch statusCode {
        case 200..<300: status2xxCount += 1
        case 300..<400: status3xxCount += 1
        case 400..<500: status4xxCount += 1
        default: status5xxCount += 1
        }

        if latencyMs > 500.0 {
            slowRequestsCount += 1
        }

        // Add to global latencies circular buffer
        if globalLatencies.count >= maxLatencySamples {
            globalLatencies.removeFirst()
        }
        globalLatencies.append(latencyMs)

        // Normalize path pattern (e.g. /api/v1/users/UUID -> /api/v1/users/:id)
        let normalizedPath = normalizePathPattern(path)
        let endpointKey = "\(method.uppercased()) \(normalizedPath)"

        var record = endpointMetrics[endpointKey] ?? EndpointRecord()
        record.count += 1
        if statusCode >= 400 {
            record.errorCount += 1
        }
        if record.latencies.count >= 500 {
            record.latencies.removeFirst()
        }
        record.latencies.append(latencyMs)
        endpointMetrics[endpointKey] = record
    }

    // MARK: - Snapshot Generation
    public func generateSnapshot() -> PerformanceMetricSnapshot {
        let now = Date()
        let uptime = now.timeIntervalSince(startTime)
        let rpm = calculateRPM(now: now)
        let globalDist = calculateDistribution(latencies: globalLatencies)

        var endpointSnapshots: [EndpointMetricSnapshot] = []
        for (key, record) in endpointMetrics {
            let parts = key.split(separator: " ", maxSplits: 1)
            let method = parts.first.map(String.init) ?? "GET"
            let pattern = parts.count > 1 ? String(parts[1]) : "/"
            let dist = calculateDistribution(latencies: record.latencies)
            let errorRate = record.count > 0 ? (Double(record.errorCount) / Double(record.count)) * 100.0 : 0.0

            endpointSnapshots.append(
                EndpointMetricSnapshot(
                    method: method,
                    pathPattern: pattern,
                    requestCount: record.count,
                    errorCount: record.errorCount,
                    errorRatePercentage: errorRate,
                    latency: dist
                )
            )
        }

        let totalErrors = status4xxCount + status5xxCount
        let overallErrorRate = totalRequests > 0 ? (Double(totalErrors) / Double(totalRequests)) * 100.0 : 0.0

        return PerformanceMetricSnapshot(
            timestamp: now,
            uptimeSeconds: uptime,
            totalRequests: totalRequests,
            activeRequests: activeRequests,
            requestsPerMinute: rpm,
            status2xxCount: status2xxCount,
            status3xxCount: status3xxCount,
            status4xxCount: status4xxCount,
            status5xxCount: status5xxCount,
            overallErrorRatePercentage: overallErrorRate,
            globalLatency: globalDist,
            endpoints: endpointSnapshots.sorted { $0.requestCount > $1.requestCount },
            slowRequestsCount: slowRequestsCount,
            memoryUsageBytes: getSystemMemoryUsage()
        )
    }

    // MARK: - Prometheus Export Formatter
    public func formatPrometheus() -> String {
        let snapshot = generateSnapshot()
        var lines: [String] = []

        lines.append("# HELP vialr_uptime_seconds Total seconds since application launch")
        lines.append("# TYPE vialr_uptime_seconds gauge")
        lines.append("vialr_uptime_seconds \(String(format: "%.1f", snapshot.uptimeSeconds))")

        lines.append("# HELP vialr_http_requests_total Total HTTP requests received")
        lines.append("# TYPE vialr_http_requests_total counter")
        lines.append("vialr_http_requests_total{status=\"2xx\"} \(snapshot.status2xxCount)")
        lines.append("vialr_http_requests_total{status=\"3xx\"} \(snapshot.status3xxCount)")
        lines.append("vialr_http_requests_total{status=\"4xx\"} \(snapshot.status4xxCount)")
        lines.append("vialr_http_requests_total{status=\"5xx\"} \(snapshot.status5xxCount)")

        lines.append("# HELP vialr_http_requests_active Current active in-flight requests")
        lines.append("# TYPE vialr_http_requests_active gauge")
        lines.append("vialr_http_requests_active \(snapshot.activeRequests)")

        lines.append("# HELP vialr_http_requests_per_minute Request rate per minute")
        lines.append("# TYPE vialr_http_requests_per_minute gauge")
        lines.append("vialr_http_requests_per_minute \(String(format: "%.2f", snapshot.requestsPerMinute))")

        lines.append("# HELP vialr_http_slow_requests_total Total requests exceeding 500ms latency")
        lines.append("# TYPE vialr_http_slow_requests_total counter")
        lines.append("vialr_http_slow_requests_total \(snapshot.slowRequestsCount)")

        lines.append("# HELP vialr_http_latency_ms HTTP latency in milliseconds")
        lines.append("# TYPE vialr_http_latency_ms summary")
        lines.append("vialr_http_latency_ms{quantile=\"0.5\"} \(String(format: "%.2f", snapshot.globalLatency.p50Ms))")
        lines.append("vialr_http_latency_ms{quantile=\"0.9\"} \(String(format: "%.2f", snapshot.globalLatency.p90Ms))")
        lines.append("vialr_http_latency_ms{quantile=\"0.95\"} \(String(format: "%.2f", snapshot.globalLatency.p95Ms))")
        lines.append("vialr_http_latency_ms{quantile=\"0.99\"} \(String(format: "%.2f", snapshot.globalLatency.p99Ms))")
        lines.append("vialr_http_latency_ms_sum \(String(format: "%.2f", snapshot.globalLatency.meanMs * Double(snapshot.globalLatency.count)))")
        lines.append("vialr_http_latency_ms_count \(snapshot.globalLatency.count)")

        // Per endpoint metrics
        for ep in snapshot.endpoints.prefix(15) {
            let sanitizedPath = ep.pathPattern.replacingOccurrences(of: "\"", with: "")
            lines.append("vialr_endpoint_requests_total{method=\"\(ep.method)\",path=\"\(sanitizedPath)\"} \(ep.requestCount)")
            lines.append("vialr_endpoint_latency_p95_ms{method=\"\(ep.method)\",path=\"\(sanitizedPath)\"} \(String(format: "%.2f", ep.latency.p95Ms))")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Mathematical Helpers
    private func calculateDistribution(latencies: [Double]) -> LatencyDistribution {
        guard !latencies.isEmpty else {
            return LatencyDistribution()
        }

        let sorted = latencies.sorted()
        let count = sorted.count
        let minVal = sorted.first ?? 0.0
        let maxVal = sorted.last ?? 0.0
        let sum = sorted.reduce(0.0, +)
        let meanVal = sum / Double(count)

        let p50 = percentile(sorted: sorted, p: 0.50)
        let p90 = percentile(sorted: sorted, p: 0.90)
        let p95 = percentile(sorted: sorted, p: 0.95)
        let p99 = percentile(sorted: sorted, p: 0.99)

        return LatencyDistribution(
            count: count,
            minMs: minVal,
            maxMs: maxVal,
            meanMs: meanVal,
            p50Ms: p50,
            p90Ms: p90,
            p95Ms: p95,
            p99Ms: p99
        )
    }

    private func percentile(sorted: [Double], p: Double) -> Double {
        guard !sorted.isEmpty else { return 0.0 }
        let index = Int(Double(sorted.count - 1) * p)
        return sorted[max(0, min(index, sorted.count - 1))]
    }

    private func calculateRPM(now: Date) -> Double {
        pruneRecentTimestamps(now: now)
        return Double(recentRequestTimestamps.count)
    }

    private func pruneRecentTimestamps(now: Date) {
        let cutoff = now.addingTimeInterval(-60.0)
        recentRequestTimestamps = recentRequestTimestamps.filter { $0 > cutoff }
    }

    private func normalizePathPattern(_ path: String) -> String {
        let uuidRegex = try? NSRegularExpression(pattern: "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", options: [])
        var normalized = path
        if let regex = uuidRegex {
            let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
            normalized = regex.stringByReplacingMatches(in: normalized, options: [], range: range, withTemplate: ":id")
        }
        return normalized
    }

    private func getSystemMemoryUsage() -> UInt64? {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return UInt64(info.resident_size)
        }
        #endif
        return nil
    }
}

// MARK: - Vapor Application Storage Extension
public struct PerformanceMonitoringKey: StorageKey {
    public typealias Value = PerformanceMonitoringService
}

extension Application {
    public var performanceMonitor: PerformanceMonitoringService {
        get {
            if let existing = self.storage[PerformanceMonitoringKey.self] {
                return existing
            }
            let service = PerformanceMonitoringService()
            self.storage[PerformanceMonitoringKey.self] = service
            return service
        }
        set {
            self.storage[PerformanceMonitoringKey.self] = newValue
        }
    }
}
