import Foundation
import Domain

/// Protocol defining internal opaque identifier management and pseudonymization.
public protocol OpaqueIdentifierServiceProtocol: Sendable {
    func getOrCreateOpaqueSubjectId(for userId: UUID) throws -> OpaqueSubjectIdentifier
    func getOpaqueSubjectId() -> OpaqueSubjectIdentifier?
    func rotatePrivacySalt() throws -> String
}

/// Service managing cryptographic pseudonymization and opaque subject identifiers.
/// Decouples identity data (PII) from health and protocol tracking data within the client architecture.
public final class OpaqueIdentifierService: OpaqueIdentifierServiceProtocol, @unchecked Sendable {
    public static let shared = OpaqueIdentifierService()

    private let keychainService: KeychainServiceProtocol
    private let saltKey = "com.vialr.privacy.subjectSalt"
    private let lock = NSLock()
    private var cachedSubjectId: OpaqueSubjectIdentifier?

    public init(keychainService: KeychainServiceProtocol = KeychainService.shared) {
        self.keychainService = keychainService
    }

    /// Returns the deterministic opaque subject identifier for a given user ID.
    public func getOrCreateOpaqueSubjectId(for userId: UUID) throws -> OpaqueSubjectIdentifier {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedSubjectId {
            return cached
        }

        let salt = try getOrCreateSalt()
        let opaque = OpaqueSubjectIdentifier.derive(from: userId, salt: salt)
        self.cachedSubjectId = opaque
        return opaque
    }

    /// Returns the active opaque subject identifier if already initialized.
    public func getOpaqueSubjectId() -> OpaqueSubjectIdentifier? {
        lock.lock()
        defer { lock.unlock() }
        return cachedSubjectId
    }

    /// Rotates the internal privacy salt, generating fresh pseudonymous identifiers.
    public func rotatePrivacySalt() throws -> String {
        lock.lock()
        defer { lock.unlock() }

        let newSalt = UUID().uuidString + "_" + String(Date().timeIntervalSince1970)
        try keychainService.saveString(newSalt, forKey: saltKey, accessLevel: .afterFirstUnlockThisDeviceOnly)
        cachedSubjectId = nil
        return newSalt
    }

    // MARK: - Private Helpers
    private func getOrCreateSalt() throws -> String {
        if let existing = try keychainService.getString(forKey: saltKey) {
            return existing
        }
        let freshSalt = UUID().uuidString + "-vialr-privacy-salt-" + String(Date().timeIntervalSince1970)
        try keychainService.saveString(freshSalt, forKey: saltKey, accessLevel: .afterFirstUnlockThisDeviceOnly)
        return freshSalt
    }
}
