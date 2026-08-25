import Foundation
import Domain

public enum NetworkError: Error, LocalizedError, Sendable {
    case invalidURL
    case unauthorized
    case serverError(statusCode: Int, message: String)
    case decodingError(String)
    case transportError(String)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "The requested URL was invalid."
        case .unauthorized: return "Authentication session has expired or is invalid."
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg)"
        case .decodingError(let msg): return "Data decoding error: \(msg)"
        case .transportError(let msg): return "Network connection error: \(msg)"
        case .unknown: return "An unknown error occurred."
        }
    }
}

public protocol APIClientProtocol: Sendable {
    func request<T: Decodable, B: Encodable>(endpoint: Endpoint, body: B?, responseType: T.Type) async throws -> T
    func request<T: Decodable>(endpoint: Endpoint, responseType: T.Type) async throws -> T
    func request(endpoint: Endpoint) async throws
    func setAuthToken(_ token: String?)
}

public final class APIClient: APIClientProtocol, @unchecked Sendable {
    public static let shared = APIClient()

    private let session: URLSession
    private let baseURL: URL
    private var authToken: String?
    private let lock = NSLock()

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
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    public func setAuthToken(_ token: String?) {
        lock.lock()
        defer { lock.unlock() }
        self.authToken = token
    }

    public func getAuthToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return authToken
    }

    public func request<T: Decodable, B: Encodable>(
        endpoint: Endpoint,
        body: B?,
        responseType: T.Type
    ) async throws -> T {
        let urlRequest = try makeURLRequest(for: endpoint, body: body)
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

    public func request<T: Decodable>(endpoint: Endpoint, responseType: T.Type) async throws -> T {
        let emptyBody: String? = nil
        return try await request(endpoint: endpoint, body: emptyBody, responseType: responseType)
    }

    public func request(endpoint: Endpoint) async throws {
        let emptyBody: String? = nil
        let urlRequest = try makeURLRequest(for: endpoint, body: emptyBody)
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
    }

    private func makeURLRequest<B: Encodable>(for endpoint: Endpoint, body: B?) throws -> URLRequest {
        guard let fullURL = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: fullURL)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try jsonEncoder.encode(body)
        }

        return request
    }
}
