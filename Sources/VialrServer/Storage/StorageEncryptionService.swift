import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Domain

/// Cryptographic service providing authenticated envelope encryption (AES-256-GCM)
/// and SHA-256 integrity verification for binary objects stored at rest.
public struct StorageEncryptionService: Sendable {
    public let keyId: String
    private let symmetricKey: SymmetricKey

    /// Initializes with a 256-bit symmetric key derived from a secret string or raw 32 bytes.
    public init(keyId: String = "vialr-vault-primary", secretKeyString: String) {
        self.keyId = keyId
        
        // Derive a consistent 256-bit (32-byte) key using SHA-256 hash of the master secret
        if let keyData = secretKeyString.data(using: .utf8) {
            let hash = SHA256.hash(data: keyData)
            self.symmetricKey = SymmetricKey(data: hash)
        } else {
            self.symmetricKey = SymmetricKey(size: .bits256)
        }
    }

    /// Initializes with a pre-configured SymmetricKey.
    public init(keyId: String = "vialr-vault-primary", key: SymmetricKey) {
        self.keyId = keyId
        self.symmetricKey = key
    }

    /// Encrypts raw binary plaintext using AES-256-GCM.
    /// Returns ciphertext Data along with initialization vector (nonce), authentication tag, and plaintext SHA-256 hash.
    public func encrypt(
        plaintext: Data
    ) throws -> (ciphertext: Data, metadata: StorageEncryptionMetadata, sha256: String) {
        do {
            // 1. Generate unique 96-bit (12-byte) cryptographically secure nonce
            let nonce = AES.GCM.Nonce()
            
            // 2. Encrypt plaintext and calculate authenticated tag
            let sealedBox = try AES.GCM.seal(plaintext, using: symmetricKey, nonce: nonce)
            
            // 3. Compute SHA-256 digest of original plaintext for integrity comparison
            let sha256Digest = SHA256.hash(data: plaintext)
            let sha256Hex = sha256Digest.map { String(format: "%02x", $0) }.joined()

            let metadata = StorageEncryptionMetadata(
                algorithm: "AES-256-GCM",
                keyId: keyId,
                initializationVector: Data(nonce).base64EncodedString(),
                authenticationTag: sealedBox.tag.base64EncodedString(),
                isEncrypted: true
            )

            return (
                ciphertext: sealedBox.ciphertext,
                metadata: metadata,
                sha256: sha256Hex
            )
        } catch {
            throw StorageError.encryptionFailed(error.localizedDescription)
        }
    }

    /// Decrypts AES-256-GCM ciphertext verifying authentication tag against tampering.
    public func decrypt(
        ciphertext: Data,
        metadata: StorageEncryptionMetadata
    ) throws -> Data {
        guard metadata.isEncrypted else {
            return ciphertext
        }

        guard let ivData = Data(base64Encoded: metadata.initializationVector),
              let tagData = Data(base64Encoded: metadata.authenticationTag) else {
            throw StorageError.decryptionFailed("Invalid Base64 IV or Auth Tag in metadata.")
        }

        do {
            let nonce = try AES.GCM.Nonce(data: ivData)
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: ciphertext,
                tag: tagData
            )

            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            return decryptedData
        } catch {
            throw StorageError.authenticationTagMismatch
        }
    }

    /// Computes the hex SHA-256 checksum of any data block.
    public static func computeChecksum(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
