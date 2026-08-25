import Foundation
import Domain
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

public protocol AppleSignInManagerProtocol: Sendable {
    func prepareNonce() -> String
    func handleAppleCredential(credential: Any) throws -> AppleAuthPayload
    func checkCredentialState(userId: String) async -> ASAuthorizationAppleIDProvider.CredentialState
}

/// Coordinates Sign in with Apple authentication requests, cryptographic nonces for replay prevention,
/// credential parsing, and credential state checking.
public final class AppleSignInManager: NSObject, AppleSignInManagerProtocol, @unchecked Sendable {
    public static let shared = AppleSignInManager()

    private var currentNonce: String?
    private let lock = NSLock()

    public override init() {
        super.init()
    }

    /// Generates a random cryptographic nonce and stores the SHA-256 hashed string for the Apple request.
    public func prepareNonce() -> String {
        lock.lock()
        defer { lock.unlock() }

        let rawNonce = generateRandomString(length: 32)
        self.currentNonce = rawNonce
        return sha256(rawNonce)
    }

    /// Retrieves and clears the active raw nonce.
    public func retrieveRawNonce() -> String? {
        lock.lock()
        defer { lock.unlock() }
        let nonce = currentNonce
        self.currentNonce = nil
        return nonce
    }

    /// Parses an `ASAuthorizationAppleIDCredential` into a structured `AppleAuthPayload`.
    public func handleAppleCredential(credential: Any) throws -> AppleAuthPayload {
        #if canImport(AuthenticationServices)
        guard let appleCredential = credential as? ASAuthorizationAppleIDCredential else {
            throw KeychainError.unexpectedDataFormat
        }

        guard let identityTokenData = appleCredential.identityToken,
              let identityTokenString = String(data: identityTokenData, encoding: .utf8) else {
            throw KeychainError.unexpectedDataFormat
        }

        guard let authorizationCodeData = appleCredential.authorizationCode,
              let authorizationCodeString = String(data: authorizationCodeData, encoding: .utf8) else {
            throw KeychainError.unexpectedDataFormat
        }

        let userIdentifier = appleCredential.user
        let email = appleCredential.email

        var fullNameString: String? = nil
        if let fullName = appleCredential.fullName {
            let formatter = PersonNameComponentsFormatter()
            fullNameString = formatter.string(from: fullName)
            if fullNameString?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                fullNameString = nil
            }
        }

        let nonce = retrieveRawNonce() ?? ""

        return AppleAuthPayload(
            identityToken: identityTokenString,
            authorizationCode: authorizationCodeString,
            userIdentifier: userIdentifier,
            email: email,
            fullName: fullNameString,
            nonce: nonce
        )
        #else
        throw KeychainError.unexpectedDataFormat
        #endif
    }

    /// Checks whether the user's Apple ID credential is still valid or revoked in iOS Settings.
    public func checkCredentialState(userId: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        #if canImport(AuthenticationServices)
        let provider = ASAuthorizationAppleIDProvider()
        return await withCheckedContinuation { continuation in
            provider.getCredentialState(forUserID: userId) { state, _ in
                continuation.resume(returning: state)
            }
        }
        #else
        return .authorized
        #endif
    }

    // MARK: - Cryptographic Helper Functions
    private func generateRandomString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)
        if status == errSecSuccess {
            return Data(randomBytes).base64EncodedString()
        }
        return UUID().uuidString
    }

    private func sha256(_ input: String) -> String {
        #if canImport(CryptoKit)
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
        #else
        return input
        #endif
    }
}
