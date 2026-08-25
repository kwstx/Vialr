import Foundation
import Domain
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// Service providing field-level authenticated envelope encryption (AES-256-GCM)
/// for sensitive health data, clinical reports, and personal notes stored at rest in PostgreSQL.
public struct AtRestDataEncryptionService: Sendable {
    public let keyIdentifier: String
    private let masterKey: SymmetricKey

    public init(
        keyIdentifier: String = "vialr-db-at-rest-v1",
        secretKeyString: String = Environment.get("VAULT_SECRET_KEY") ?? "vialr-master-vault-encryption-secret-key-32b"
    ) {
        self.keyIdentifier = keyIdentifier
        let hash = SHA256.hash(data: Data(secretKeyString.utf8))
        self.masterKey = SymmetricKey(data: hash)
    }

    /// Encrypts a plaintext string into a self-contained Base64 envelope: `v1.<iv>.<tag>.<ciphertext>`
    public func encryptField(_ plaintext: String) throws -> String {
        guard !plaintext.isEmpty else { return plaintext }
        let plaintextData = Data(plaintext.utf8)
        
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plaintextData, using: masterKey, nonce: nonce)

        let ivBase64 = Data(nonce).base64EncodedString()
        let tagBase64 = sealed.tag.base64EncodedString()
        let cipherBase64 = sealed.ciphertext.base64EncodedString()

        return "enc:v1:\(ivBase64):\(tagBase64):\(cipherBase64)"
    }

    /// Decrypts a Base64 encrypted envelope back into plaintext UTF-8 string.
    public func decryptField(_ encryptedEnvelope: String) throws -> String {
        guard encryptedEnvelope.starts(with: "enc:v1:") else {
            // Not encrypted or legacy plaintext
            return encryptedEnvelope
        }

        let parts = encryptedEnvelope.split(separator: ":")
        guard parts.count == 5 else {
            return encryptedEnvelope
        }

        let ivStr = String(parts[2])
        let tagStr = String(parts[3])
        let cipherStr = String(parts[4])

        guard let ivData = Data(base64Encoded: ivStr),
              let tagData = Data(base64Encoded: tagStr),
              let cipherData = Data(base64Encoded: cipherStr) else {
            return encryptedEnvelope
        }

        let nonce = try AES.GCM.Nonce(data: ivData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: cipherData, tag: tagData)
        let decryptedData = try AES.GCM.open(sealedBox, using: masterKey)

        guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
            throw DomainError.decryptionFailed
        }

        return plaintext
    }
}

public enum DomainError: Error, LocalizedError, Sendable {
    case decryptionFailed
    case invalidCredentials

    public var errorDescription: String? {
        switch self {
        case .decryptionFailed: return "Failed to decrypt at-rest field."
        case .invalidCredentials: return "Invalid authentication credentials."
        }
    }
}
