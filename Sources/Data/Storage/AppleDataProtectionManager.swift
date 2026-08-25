import Foundation

/// Service ensuring that all local application data, SQLite databases, document attachments,
/// and caches are secured using Apple's hardware-backed Data Protection (`NSFileProtectionComplete`).
///
/// Under `NSFileProtectionComplete`, files are encrypted with a key derived from the user's passcode
/// and hardware Secure Enclave. When the device is locked, the key is removed from memory,
/// rendering sensitive health and protocol data completely inaccessible to unauthorized parties.
public struct AppleDataProtectionManager: Sendable {
    public static let shared = AppleDataProtectionManager()

    public init() {}

    /// Applies `NSFileProtectionComplete` to a specific file or directory.
    @discardableResult
    public func applyDataProtection(
        to url: URL,
        protectionType: FileProtectionType = .complete
    ) -> Bool {
        let fileManager = FileManager.default
        let path = url.path

        guard fileManager.fileExists(atPath: path) else {
            return false
        }

        do {
            let attributes: [FileAttributeKey: Any] = [
                .protectionKey: protectionType
            ]
            try fileManager.setAttributes(attributes, ofItemAtPath: path)

            // If it's a directory, recursively protect all children
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                let children = try fileManager.contentsOfDirectory(atPath: path)
                for child in children {
                    let childURL = url.appendingPathComponent(child)
                    applyDataProtection(to: childURL, protectionType: protectionType)
                }
            }
            return true
        } catch {
            print("[AppleDataProtection] Warning: Failed to set Data Protection on \(path): \(error)")
            return false
        }
    }

    /// Secures the standard local database directory and all associated SQLite files (including .wal and .shm).
    public func protectDatabaseContainer(dbURL: URL) {
        let fileManager = FileManager.default
        let parentDir = dbURL.deletingLastPathComponent()

        // 1. Protect parent directory
        applyDataProtection(to: parentDir, protectionType: .complete)

        // 2. Protect primary DB file
        applyDataProtection(to: dbURL, protectionType: .complete)

        // 3. Protect write-ahead log (WAL) and shared memory (SHM) files
        let walURL = dbURL.appendingPathExtension("wal")
        if fileManager.fileExists(atPath: walURL.path) {
            applyDataProtection(to: walURL, protectionType: .complete)
        }

        let shmURL = dbURL.appendingPathExtension("shm")
        if fileManager.fileExists(atPath: shmURL.path) {
            applyDataProtection(to: shmURL, protectionType: .complete)
        }
    }

    /// Secures the user documents directory.
    public func protectDocumentsStorage() {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        applyDataProtection(to: docsURL, protectionType: .complete)
    }

    /// Verifies whether a given file has `NSFileProtectionComplete` enabled.
    public func isProtected(at url: URL) -> Bool {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let protection = attributes[.protectionKey] as? FileProtectionType {
                return protection == .complete || protection == .completeUnlessOpen
            }
            return false
        } catch {
            return false
        }
    }
}
