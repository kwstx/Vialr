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
        keyIdentifier: String = "vialr-db-at-rest-v2",
        secretKeyString: String = ProcessInfo.processInfo.environment["VAULT_SECRET_KEY"] ?? "vialr-master-vault-encryption-secret-key-32b"
    ) {
        self.keyIdentifier = keyIdentifier
        let hash = SHA256.hash(data: Data(secretKeyString.utf8))
        self.masterKey = SymmetricKey(data: hash)
    }

    public init(keyIdentifier: String, customKey: SymmetricKey) {
        self.keyIdentifier = keyIdentifier
        self.masterKey = customKey
    }

    /// Encrypts a plaintext string into a self-contained Base64 envelope: `enc:v2:<keyId>:<iv>:<tag>:<ciphertext>`
    public func encryptField(_ plaintext: String) throws -> String {
        guard !plaintext.isEmpty else { return plaintext }
        let plaintextData = Data(plaintext.utf8)

        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plaintextData, using: masterKey, nonce: nonce)

        let ivBase64 = Data(nonce).base64EncodedString()
        let tagBase64 = sealed.tag.base64EncodedString()
        let cipherBase64 = sealed.ciphertext.base64EncodedString()

        return "enc:v2:\(keyIdentifier):\(ivBase64):\(tagBase64):\(cipherBase64)"
    }

    /// Decrypts a Base64 encrypted envelope back into plaintext UTF-8 string.
    /// Backward compatible with `enc:v1:` and modern `enc:v2:` envelopes.
    public func decryptField(_ encryptedEnvelope: String) throws -> String {
        guard encryptedEnvelope.starts(with: "enc:") else {
            // Not encrypted or legacy plaintext
            return encryptedEnvelope
        }

        let parts = encryptedEnvelope.split(separator: ":")
        
        // Format v2: enc:v2:<keyId>:<iv>:<tag>:<ciphertext> (6 parts)
        if encryptedEnvelope.starts(with: "enc:v2:") && parts.count == 6 {
            let ivStr = String(parts[3])
            let tagStr = String(parts[4])
            let cipherStr = String(parts[5])

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

        // Format v1: enc:v1:<iv>:<tag>:<ciphertext> (5 parts)
        if encryptedEnvelope.starts(with: "enc:v1:") && parts.count == 5 {
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

        return encryptedEnvelope
    }

    /// Encrypts an arbitrary Codable object into an encrypted JSON string envelope.
    public func encryptCodable<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(value)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw DomainError.decryptionFailed
        }
        return try encryptField(jsonString)
    }

    /// Decrypts an encrypted JSON string envelope back into the specified Decodable type.
    public func decryptCodable<T: Decodable>(_ envelope: String, as type: T.Type) throws -> T {
        let decryptedJson = try decryptField(envelope)
        guard let data = decryptedJson.data(using: .utf8) else {
            throw DomainError.decryptionFailed
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    /// Checks if a given field string is currently encrypted with AES-256-GCM.
    public func isEncrypted(_ field: String) -> Bool {
        return field.starts(with: "enc:v1:") || field.starts(with: "enc:v2:")
    }
}
