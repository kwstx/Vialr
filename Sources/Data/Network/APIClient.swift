import Foundation
import Domain

public enum NetworkError: Error, LocalizedError, Sendable {
    case invalidURL
    case unauthorized
    case serverError(statusCode: Int, message: String)
    case decodingError(String)
    case transportError(String)
    case refreshFailed
    case unknown

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "The requested URL was invalid."
        case .unauthorized: return "Authentication session has expired or is invalid."
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg)"
        case .decodingError(let msg): return "Data decoding error: \(msg)"
        case .transportError(let msg): return "Network connection error: \(msg)"
        case .refreshFailed: return "Failed to refresh authentication session."
        case .unknown: return "An unknown error occurred."
        }
    }
}

public protocol APIClientProtocol: Sendable {
    func request<T: Decodable, B: Encodable>(endpoint: Endpoint, body: B?, responseType: T.Type) async throws -> T
    func request<T: Decodable>(endpoint: Endpoint, responseType: T.Type) async throws -> T
    func request(endpoint: Endpoint) async throws
    func setAuthTokens(access: String?, refresh: String?)
    func clearAuthTokens()
}

/// Thread-safe networking client managing short-lived access credentials,
/// automatic background token refresh via the iOS Keychain, and single-flight refresh coalescence.
///
/// NOTE: Access and Refresh tokens are NEVER persisted in UserDefaults.
public final class APIClient: APIClientProtocol, @unchecked Sendable {
    public static let shared = APIClient()

    private let session: URLSession
    private let baseURL: URL
    private let keychain: KeychainServiceProtocol
    private let lock = NSLock()
    private var refreshTask: Task<String, Error>?

    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init(
        baseURL: URL = URL(string: "http://localhost:8080")!,
        session: URLSession = .shared,
        keychain: KeychainServiceProtocol = KeychainService.shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.keychain = keychain
    }

    // MARK: - Token Management (Strictly Keychain-backed)
    public func setAuthTokens(access: String?, refresh: String?) {
        do {
            if let access = access {
                try keychain.saveString(access, forKey: KeychainService.Keys.accessToken, accessLevel: .afterFirstUnlockThisDeviceOnly)
            } else {
                try keychain.delete(forKey: KeychainService.Keys.accessToken)
            }

            if let refresh = refresh {
                try keychain.saveString(refresh, forKey: KeychainService.Keys.refreshToken, accessLevel: .afterFirstUnlockThisDeviceOnly)
            } else {
                try keychain.delete(forKey: KeychainService.Keys.refreshToken)
            }
        } catch {
            print("[APIClient] Error persisting tokens in Keychain: \(error)")
        }
    }

    public func getAccessToken() -> String? {
        try? keychain.getString(forKey: KeychainService.Keys.accessToken)
    }

    public func getRefreshToken() -> String? {
        try? keychain.getString(forKey: KeychainService.Keys.refreshToken)
    }

    public func clearAuthTokens() {
        try? keychain.clearAllAuthCredentials()
    }

    // MARK: - Public Request API
    public func request<T: Decodable, B: Encodable>(
        endpoint: Endpoint,
        body: B?,
        responseType: T.Type
    ) async throws -> T {
        do {
            return try await executeRequest(endpoint: endpoint, body: body, responseType: responseType)
        } catch NetworkError.unauthorized {
            // Avoid infinite loops when refresh endpoint itself returns 401
            guard endpoint != .refreshToken && endpoint != .login && endpoint != .register && endpoint != .appleSignIn else {
                throw NetworkError.unauthorized
            }

            // Attempt automatic token refresh
            let newAccessToken = try await performTokenRefresh()
            return try await executeRequest(endpoint: endpoint, body: body, responseType: responseType, overrideToken: newAccessToken)
        }
    }

    public func request<T: Decodable>(endpoint: Endpoint, responseType: T.Type) async throws -> T {
        let emptyBody: String? = nil
        return try await request(endpoint: endpoint, body: emptyBody, responseType: responseType)
    }

    public func request(endpoint: Endpoint) async throws {
        struct EmptyResponse: Decodable {}
        let emptyBody: String? = nil
        let _: EmptyResponse? = try? await request(endpoint: endpoint, body: emptyBody, responseType: EmptyResponse.self)
    }

    // MARK: - Internal Request Execution
    private func executeRequest<T: Decodable, B: Encodable>(
        endpoint: Endpoint,
        body: B?,
        responseType: T.Type,
        overrideToken: String? = nil
    ) async throws -> T {
        let urlRequest = try makeURLRequest(for: endpoint, body: body, overrideToken: overrideToken)
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw NetworkError.unauthorized
            }
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
        }

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }

    private func makeURLRequest<B: Encodable>(
        for endpoint: Endpoint,
        body: B?,
        overrideToken: String? = nil
    ) throws -> URLRequest {
        guard let fullURL = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: fullURL)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let tokenToUse = overrideToken ?? getAccessToken()
        if let token = tokenToUse {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try jsonEncoder.encode(body)
        }

        return request
    }

    // MARK: - Single-Flight Refresh Coalescence
    private func performTokenRefresh() async throws -> String {
        lock.lock()
        if let ongoingTask = refreshTask {
            lock.unlock()
            return try await ongoingTask.value
        }

        guard let currentRefreshToken = getRefreshToken() else {
            lock.unlock()
            clearAuthTokens()
            throw NetworkError.unauthorized
        }

        let task = Task<String, Error> {
            defer {
                self.lock.lock()
                self.refreshTask = nil
                self.lock.unlock()
            }

            struct RefreshBody: Encodable {
                let refreshToken: String
            }

            struct RefreshResponse: Decodable {
                let token: String // or accessToken
                let refreshToken: String?
            }

            let body = RefreshBody(refreshToken: currentRefreshToken)
            let urlRequest = try self.makeURLRequest(for: .refreshToken, body: body)

            let (data, response) = try await self.session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                self.clearAuthTokens()
                throw NetworkError.refreshFailed
            }

            let decoded = try self.jsonDecoder.decode(RefreshResponse.self, from: data)
            self.setAuthTokens(access: decoded.token, refresh: decoded.refreshToken ?? currentRefreshToken)
            return decoded.token
        }

        self.refreshTask = task
        lock.unlock()

        return try await task.value
    }
}
