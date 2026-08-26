import Foundation
import Vapor
import Domain

/// Server-side log sanitization helpers integrating Vapor HTTP requests with the Domain `SensitiveDataScrubber`.
public extension SensitiveDataScrubber {
    /// Extracts and sanitizes headers directly from a Vapor Request.
    static func sanitizeRequestHeaders(_ req: Request) -> [String: String] {
        let rawHeaders = req.headers.map { ($0.name, $0.value) }
        return sanitizeHeaders(rawHeaders)
    }

    /// Safely extracts query parameters from a Vapor Request, scrubbing any sensitive values.
    static func sanitizeQueryParams(_ req: Request) -> [String: String] {
        guard let query = req.url.query else { return [:] }
        var result: [String: String] = [:]
        let pairs = query.split(separator: "&")
        for pair in pairs {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if let key = kv.first.map(String.init) {
                let val = kv.count > 1 ? String(kv[1]) : ""
                let lowerKey = key.lowercased()
                if lowerKey.contains("token") || lowerKey.contains("secret") || lowerKey.contains("password") || lowerKey.contains("key") {
                    result[key] = "[REDACTED_AUTH]"
                } else if lowerKey.contains("dose") || lowerKey.contains("biomarker") || lowerKey.contains("notes") {
                    result[key] = "[REDACTED_PHI]"
                } else {
                    result[key] = val
                }
            }
        }
        return result
    }
}
