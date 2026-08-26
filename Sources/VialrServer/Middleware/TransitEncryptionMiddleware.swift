import Vapor

/// Middleware enforcing End-to-End Encryption in Transit (TLS/HTTPS), Strict Transport Security (HSTS),
/// zero-trust HTTP security headers, and anti-caching controls for Protected Health Information (PHI).
public struct TransitEncryptionMiddleware: AsyncMiddleware {
    private let enforceHttps: Bool
    private let hstsMaxAgeSeconds: Int
    private let includeSubdomains: Bool
    private let preload: Bool

    public init(
        enforceHttps: Bool = true,
        hstsMaxAgeSeconds: Int = 63072000, // 2 years (standard HSTS preload recommendation)
        includeSubdomains: Bool = true,
        preload: Bool = true
    ) {
        self.enforceHttps = enforceHttps
        self.hstsMaxAgeSeconds = hstsMaxAgeSeconds
        self.includeSubdomains = includeSubdomains
        self.preload = preload
    }

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // 1. Enforce HTTPS in production environments
        if enforceHttps && request.application.environment == .production {
            let forwardedProto = request.headers.first(name: "X-Forwarded-Proto")?.lowercased()
            let isPlainHttp = (forwardedProto == "http") || (request.url.scheme?.lowercased() == "http")
            if isPlainHttp {
                // If a non-TLS request arrives at reverse proxy/gateway, redirect or reject
                guard let host = request.headers.first(name: .host) else {
                    throw Abort(.forbidden, reason: "Insecure transport rejected. TLS encryption is mandatory.")
                }
                let secureURI = "https://\(host)\(request.url.path)" + (request.url.query.map { "?\($0)" } ?? "")
                return request.redirect(to: secureURI, type: .permanent)
            }
        }

        // 2. Process downstream request
        let response = try await next.respond(to: request)

        // 3. Inject Strict Transport Security (HSTS)
        var hstsValue = "max-age=\(hstsMaxAgeSeconds)"
        if includeSubdomains {
            hstsValue += "; includeSubDomains"
        }
        if preload {
            hstsValue += "; preload"
        }
        response.headers.replaceOrAdd(name: "Strict-Transport-Security", value: hstsValue)

        // 4. Zero-Trust Security & Content Isolation Headers
        response.headers.replaceOrAdd(name: "X-Content-Type-Options", value: "nosniff")
        response.headers.replaceOrAdd(name: "X-Frame-Options", value: "DENY")
        response.headers.replaceOrAdd(name: "X-XSS-Protection", value: "1; mode=block")
        response.headers.replaceOrAdd(name: "Referrer-Policy", value: "strict-origin-when-cross-origin")
        response.headers.replaceOrAdd(name: "Permissions-Policy", value: "geolocation=(), camera=(), microphone=(), payment=(), usb=(), display-capture=()")
        response.headers.replaceOrAdd(
            name: "Content-Security-Policy",
            value: "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
        )

        // 5. Anti-Caching Headers for Health & Personal Data Endpoints
        // Ensures intermediate proxies, CDN caches, and local client caches never store sensitive health records
        if request.url.path.starts(with: "/api/") {
            response.headers.replaceOrAdd(name: "Cache-Control", value: "no-store, no-cache, must-revalidate, max-age=0, private")
            response.headers.replaceOrAdd(name: "Pragma", value: "no-cache")
            response.headers.replaceOrAdd(name: "Expires", value: "0")
        }

        return response
    }
}
