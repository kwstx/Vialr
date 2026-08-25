import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// S3-compatible object storage provider (AWS S3, MinIO, Cloudflare R2, Ceph, DigitalOcean Spaces).
public struct S3CompatibleObjectStorageService: ObjectStorageProtocol {
    public let endpointURL: URL
    public let region: String
    public let accessKey: String
    public let secretKey: String
    public let forcePathStyle: Bool
    private let urlSession: URLSession

    public init(
        endpointURL: URL = URL(string: "https://s3.amazonaws.com")!,
        region: String = "us-east-1",
        accessKey: String,
        secretKey: String,
        forcePathStyle: Bool = true,
        urlSession: URLSession = .shared
    ) {
        self.endpointURL = endpointURL
        self.region = region
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.forcePathStyle = forcePathStyle
        self.urlSession = urlSession
    }

    private func objectEndpoint(for key: String, bucket: String) -> URL {
        if forcePathStyle {
            return endpointURL.appendingPathComponent(bucket).appendingPathComponent(key)
        } else {
            var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
            if let host = components?.host {
                components?.host = "\(bucket).\(host)"
            }
            return components?.url?.appendingPathComponent(key) ?? endpointURL.appendingPathComponent(bucket).appendingPathComponent(key)
        }
    }

    public func putObject(key: String, bucket: String, data: Data, contentType: String) async throws {
        let url = objectEndpoint(for: key, bucket: bucket)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        
        signRequest(&request, bodyData: data)

        let (respData, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 500
            let bodyText = String(data: respData, encoding: .utf8) ?? ""
            throw StorageError.writeFailed("S3 PUT failed with HTTP \(status): \(bodyText)")
        }
    }

    public func getObject(key: String, bucket: String) async throws -> Data {
        let url = objectEndpoint(for: key, bucket: bucket)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        signRequest(&request, bodyData: nil)

        let (respData, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageError.readFailed("Invalid HTTP response")
        }

        if httpResponse.statusCode == 404 {
            throw StorageError.objectNotFound(key: key, bucket: bucket)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyText = String(data: respData, encoding: .utf8) ?? ""
            throw StorageError.readFailed("S3 GET failed with HTTP \(httpResponse.statusCode): \(bodyText)")
        }

        return respData
    }

    public func deleteObject(key: String, bucket: String) async throws {
        let url = objectEndpoint(for: key, bucket: bucket)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        signRequest(&request, bodyData: nil)

        let (respData, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 404 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 500
            let bodyText = String(data: respData, encoding: .utf8) ?? ""
            throw StorageError.deleteFailed("S3 DELETE failed with HTTP \(status): \(bodyText)")
        }
    }

    public func objectExists(key: String, bucket: String) async throws -> Bool {
        let url = objectEndpoint(for: key, bucket: bucket)
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        signRequest(&request, bodyData: nil)

        guard let (_, response) = try? await urlSession.data(for: request),
              let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return (200...299).contains(httpResponse.statusCode)
    }

    public func generatePresignedDownloadURL(key: String, bucket: String, expiresInSeconds: Int) async throws -> URL {
        let endpoint = objectEndpoint(for: key, bucket: bucket)
        return try generateSigV4PresignedURL(endpoint: endpoint, method: "GET", expiresInSeconds: expiresInSeconds)
    }

    public func generatePresignedUploadURL(key: String, bucket: String, expiresInSeconds: Int, contentType: String) async throws -> URL {
        let endpoint = objectEndpoint(for: key, bucket: bucket)
        return try generateSigV4PresignedURL(endpoint: endpoint, method: "PUT", expiresInSeconds: expiresInSeconds, extraHeaders: ["content-type": contentType])
    }

    // MARK: - AWS SigV4 Request Signing

    private func signRequest(_ request: inout URLRequest, bodyData: Data?) {
        let date = Date()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withTimeZone]
        
        let amzDateFormatter = DateFormatter()
        amzDateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        amzDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let amzDate = amzDateFormatter.string(from: date)

        let dateStampFormatter = DateFormatter()
        dateStampFormatter.dateFormat = "yyyyMMdd"
        dateStampFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let dateStamp = dateStampFormatter.string(from: date)

        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        if let host = request.url?.host {
            request.setValue(host, forHTTPHeaderField: "Host")
        }

        let payloadHash: String
        if let body = bodyData {
            payloadHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        } else {
            payloadHash = SHA256.hash(data: Data()).map { String(format: "%02x", $0) }.joined()
        }
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")

        // Construct Canonical Request
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path.isEmpty == false ? (request.url?.path ?? "/") : "/"
        let canonicalURI = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let canonicalQuery = ""
        let signedHeaders = "host;x-amz-content-sha256;x-amz-date"
        let canonicalHeaders = "host:\(request.url?.host ?? "")\nx-amz-content-sha256:\(payloadHash)\nx-amz-date:\(amzDate)\n"

        let canonicalRequest = "\(method)\n\(canonicalURI)\n\(canonicalQuery)\n\(canonicalHeaders)\n\(signedHeaders)\n\(payloadHash)"
        let canonicalRequestHash = SHA256.hash(data: Data(canonicalRequest.utf8)).map { String(format: "%02x", $0) }.joined()

        let algorithm = "AWS4-HMAC-SHA256"
        let credentialScope = "\(dateStamp)/\(region)/s3/aws4_request"
        let stringToSign = "\(algorithm)\n\(amzDate)\n\(credentialScope)\n\(canonicalRequestHash)"

        // Derive Signing Key
        let kDate = hmac(key: Data("AWS4\(secretKey)".utf8), data: Data(dateStamp.utf8))
        let kRegion = hmac(key: kDate, data: Data(region.utf8))
        let kService = hmac(key: kRegion, data: Data("s3".utf8))
        let kSigning = hmac(key: kService, data: Data("aws4_request".utf8))

        let signature = hmac(key: kSigning, data: Data(stringToSign.utf8)).map { String(format: "%02x", $0) }.joined()
        let authHeader = "\(algorithm) Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
    }

    private func generateSigV4PresignedURL(
        endpoint: URL,
        method: String,
        expiresInSeconds: Int,
        extraHeaders: [String: String] = [:]
    ) throws -> URL {
        let date = Date()
        let amzDateFormatter = DateFormatter()
        amzDateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        amzDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let amzDate = amzDateFormatter.string(from: date)

        let dateStampFormatter = DateFormatter()
        dateStampFormatter.dateFormat = "yyyyMMdd"
        dateStampFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let dateStamp = dateStampFormatter.string(from: date)

        let credentialScope = "\(dateStamp)/\(region)/s3/aws4_request"
        let algorithm = "AWS4-HMAC-SHA256"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "X-Amz-Algorithm", value: algorithm),
            URLQueryItem(name: "X-Amz-Credential", value: "\(accessKey)/\(credentialScope)"),
            URLQueryItem(name: "X-Amz-Date", value: amzDate),
            URLQueryItem(name: "X-Amz-Expires", value: "\(expiresInSeconds)"),
            URLQueryItem(name: "X-Amz-SignedHeaders", value: "host")
        ]

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        let canonicalURI = endpoint.path.isEmpty ? "/" : endpoint.path
        let sortedQuery = queryItems
            .sorted { $0.name < $1.name }
            .map { "\($0.name)=\($0.value?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")

        let canonicalHeaders = "host:\(endpoint.host ?? "")\n"
        let canonicalRequest = "\(method)\n\(canonicalURI)\n\(sortedQuery)\n\(canonicalHeaders)\nhost\nUNSIGNED-PAYLOAD"
        let canonicalRequestHash = SHA256.hash(data: Data(canonicalRequest.utf8)).map { String(format: "%02x", $0) }.joined()

        let stringToSign = "\(algorithm)\n\(amzDate)\n\(credentialScope)\n\(canonicalRequestHash)"

        let kDate = hmac(key: Data("AWS4\(secretKey)".utf8), data: Data(dateStamp.utf8))
        let kRegion = hmac(key: kDate, data: Data(region.utf8))
        let kService = hmac(key: kRegion, data: Data("s3".utf8))
        let kSigning = hmac(key: kService, data: Data("aws4_request".utf8))

        let signature = hmac(key: kSigning, data: Data(stringToSign.utf8)).map { String(format: "%02x", $0) }.joined()

        queryItems.append(URLQueryItem(name: "X-Amz-Signature", value: signature))
        components.queryItems = queryItems

        guard let presignedURL = components.url else {
            throw StorageError.configurationError("Failed to build presigned URL")
        }

        return presignedURL
    }

    private func hmac(key: Data, data: Data) -> Data {
        let symKey = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: symKey)
        return Data(mac)
    }
}
