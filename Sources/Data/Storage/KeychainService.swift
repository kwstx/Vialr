import Foundation
import Domain
#if canImport(Security)
import Security
#endif

/// Protocol defining secure Keychain storage operations for authentication tokens and credentials.
public protocol KeychainServiceProtocol: Sendable {
    func saveString(_ value: String, forKey key: String, accessLevel: KeychainAccessLevel) throws
    func getString(forKey key: String) throws -> String?
    func save<T: Encodable>(_ item: T, forKey key: String, accessLevel: KeychainAccessLevel) throws
    func get<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T?
    func delete(forKey key: String) throws
    func clearAllAuthCredentials() throws
}

/// Production-grade iOS Keychain Service.
/// Strictly persists sensitive authentication material (access tokens, refresh tokens, auth sessions, master keys)
/// inside the encrypted iOS hardware Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` or `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
///
/// NOTE: Authentication tokens are NEVER stored in UserDefaults.
public final class KeychainService: KeychainServiceProtocol, @unchecked Sendable {
    public static let shared = KeychainService()

    private let serviceIdentifier: String
    private let accessGroup: String?
    private let lock = NSLock()
    
    // In-memory fallback dictionary for non-Darwin testing environments
    private var inMemoryStore: [String: Data] = [:]

    public struct Keys {
        public static let accessToken = "com.vialr.auth.accessToken"
        public static let refreshToken = "com.vialr.auth.refreshToken"
        public static let authSession = "com.vialr.auth.session"
        public static let appleUserIdentifier = "com.vialr.auth.appleUserId"
        public static let masterVaultKey = "com.vialr.vault.masterKey"
        public static let biometricLockPin = "com.vialr.security.localPin"
    }

    public init(
        serviceIdentifier: String = "com.vialr.ios.keychain",
        accessGroup: String? = nil
    ) {
        self.serviceIdentifier = serviceIdentifier
        self.accessGroup = accessGroup
    }

    // MARK: - String Operations
    public func saveString(_ value: String, forKey key: String, accessLevel: KeychainAccessLevel = .afterFirstUnlockThisDeviceOnly) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.unexpectedDataFormat
        }
        try saveData(data, forKey: key, accessLevel: accessLevel)
    }

    public func getString(forKey key: String) throws -> String? {
        guard let data = try getData(forKey: key) else {
            return nil
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedDataFormat
        }
        return string
    }

    // MARK: - Generic Codable Operations
    public func save<T: Encodable>(_ item: T, forKey key: String, accessLevel: KeychainAccessLevel = .afterFirstUnlockThisDeviceOnly) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)
        try saveData(data, forKey: key, accessLevel: accessLevel)
    }

    public func get<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = try getData(forKey: key) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    // MARK: - Core Data Operations
    public func saveData(_ data: Data, forKey key: String, accessLevel: KeychainAccessLevel = .afterFirstUnlockThisDeviceOnly) throws {
        lock.lock()
        defer { lock.unlock() }

        #if canImport(Security) && (os(iOS) || os(macOS) || os(watchOS) || os(tvOS) || os(visionOS))
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        // Check if item already exists
        let status = SecItemCopyMatching(query as CFDictionary, nil)

        if status == errSecSuccess {
            // Update existing item
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: accessibilityAttribute(for: accessLevel)
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: updateStatus)
            }
        } else if status == errSecItemNotFound {
            // Add new item
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = accessibilityAttribute(for: accessLevel)
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: addStatus)
            }
        } else {
            throw KeychainError.unhandledError(status: status)
        }
        #else
        inMemoryStore[key] = data
        #endif
    }

    public func getData(forKey key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }

        #if canImport(Security) && (os(iOS) || os(macOS) || os(watchOS) || os(tvOS) || os(visionOS))
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess {
            return item as? Data
        } else if status == errSecItemNotFound {
            return nil
        } else {
            throw KeychainError.unhandledError(status: status)
        }
        #else
        return inMemoryStore[key]
        #endif
    }

    public func delete(forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }

        #if canImport(Security) && (os(iOS) || os(macOS) || os(watchOS) || os(tvOS) || os(visionOS))
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unhandledError(status: status)
        }
        #else
        inMemoryStore.removeValue(forKey: key)
        #endif
    }

    /// Clears all authentication credentials upon sign-out.
    public func clearAllAuthCredentials() throws {
        try delete(forKey: Keys.accessToken)
        try delete(forKey: Keys.refreshToken)
        try delete(forKey: Keys.authSession)
        try delete(forKey: Keys.appleUserIdentifier)
    }

    #if canImport(Security) && (os(iOS) || os(macOS) || os(watchOS) || os(tvOS) || os(visionOS))
    private func accessibilityAttribute(for level: KeychainAccessLevel) -> CFString {
        switch level {
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .whenPasscodeSetThisDeviceOnly:
            return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        }
    }
    #endif
}
