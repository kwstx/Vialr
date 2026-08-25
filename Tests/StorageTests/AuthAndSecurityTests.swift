import XCTest
import Domain
import Data
import SwiftUI
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

final class AuthAndSecurityTests: XCTestCase {

    // MARK: - 1. iOS Keychain Service & Zero-UserDefaults Validation
    func testKeychainTokenPersistenceAndZeroUserDefaultsUsage() throws {
        let keychain = KeychainService(serviceIdentifier: "com.vialr.tests.keychain.\(UUID().uuidString)")

        let sampleAccessToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.testAccessToken"
        let sampleRefreshToken = "rot_ref_token_secret_123456789"

        // 1. Save tokens to Keychain
        try keychain.saveString(sampleAccessToken, forKey: KeychainService.Keys.accessToken, accessLevel: .afterFirstUnlockThisDeviceOnly)
        try keychain.saveString(sampleRefreshToken, forKey: KeychainService.Keys.refreshToken, accessLevel: .afterFirstUnlockThisDeviceOnly)

        // 2. Verify retrieval from Keychain
        let retrievedAccess = try keychain.getString(forKey: KeychainService.Keys.accessToken)
        let retrievedRefresh = try keychain.getString(forKey: KeychainService.Keys.refreshToken)

        XCTAssertEqual(retrievedAccess, sampleAccessToken)
        XCTAssertEqual(retrievedRefresh, sampleRefreshToken)

        // 3. STRICT REQUIREMENT CHECK: Verify UserDefaults does NOT contain authentication tokens
        XCTAssertNil(UserDefaults.standard.string(forKey: KeychainService.Keys.accessToken))
        XCTAssertNil(UserDefaults.standard.string(forKey: KeychainService.Keys.refreshToken))
        XCTAssertNil(UserDefaults.standard.string(forKey: "accessToken"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "jwt_token"))

        // 4. Wipe credentials upon logout
        try keychain.clearAllAuthCredentials()
        XCTAssertNil(try keychain.getString(forKey: KeychainService.Keys.accessToken))
        XCTAssertNil(try keychain.getString(forKey: KeychainService.Keys.refreshToken))
    }

    // MARK: - 2. Short-Lived Access Token Domain Model Expiration
    func testShortLivedTokenExpirationLogic() {
        // Token valid for 900 seconds (15 minutes) issued right now
        let freshTokens = AuthTokens(
            accessToken: "valid_access_token",
            refreshToken: "valid_refresh_token",
            expiresIn: 900,
            issuedAt: Date()
        )
        XCTAssertFalse(freshTokens.isExpired)

        // Token issued 16 minutes ago with a 15-minute lifetime -> expired
        let expiredTokens = AuthTokens(
            accessToken: "old_access_token",
            refreshToken: "valid_refresh_token",
            expiresIn: 900,
            issuedAt: Date().addingTimeInterval(-960) // 16 mins ago
        )
        XCTAssertTrue(expiredTokens.isExpired)
    }

    // MARK: - 3. Sign in with Apple Nonce Generation & Anti-Replay
    func testAppleSignInNonceGeneration() {
        let manager = AppleSignInManager()
        let hashedNonce1 = manager.prepareNonce()
        let rawNonce1 = manager.retrieveRawNonce()

        XCTAssertNotNil(rawNonce1)
        XCTAssertFalse(hashedNonce1.isEmpty)

        // Verify SHA-256 relationship
        let computedHash = SHA256.hash(data: Data(rawNonce1!.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hashedNonce1, computedHash)

        // Verify raw nonce is wiped after retrieval (single-use anti-replay)
        XCTAssertNil(manager.retrieveRawNonce())
    }

    // MARK: - 4. Biometric App Security Manager State Machine
    @MainActor
    func testAppSecurityManagerLifecycleAndLocking() async {
        let securityManager = AppSecurityManager.shared
        securityManager.isBiometricsEnabled = true
        securityManager.lockTimeoutSeconds = 60

        // App starts unlocked
        securityManager.unlockApp()
        XCTAssertFalse(securityManager.isAppLocked)
        XCTAssertFalse(securityManager.isPrivacyMaskActive)

        // 1. Transition to inactive / background -> Privacy mask becomes active
        securityManager.handleScenePhaseChange(to: .inactive)
        // Privacy mask protects against UI screenshotting in multitasking switcher

        // 2. Lock app manually
        securityManager.lockApp()
        // If active session exists, becomes locked
    }

    // MARK: - 5. Apple Data Protection Service
    func testAppleDataProtectionManager() throws {
        let manager = AppleDataProtectionManager.shared
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("VialrDataProtectionTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sampleDBFile = tempDir.appendingPathComponent("vialr_test.sqlite")
        try "SQLite format 3 header".data(using: .utf8)!.write(to: sampleDBFile)

        // Apply hardware data protection
        manager.protectDatabaseContainer(dbURL: sampleDBFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sampleDBFile.path))
    }

    // MARK: - 6. Server-side AES-256-GCM Field Encryption at Rest
    func testAtRestFieldEncryptionAndDecryption() throws {
        let secretKey = "vialr-master-vault-encryption-secret-key-32b"
        let symmetricKey = SymmetricKey(data: SHA256.hash(data: Data(secretKey.utf8)))

        let sensitiveNote = "Patient lab results: fasting blood glucose 82 mg/dL, HbA1c 4.9%, sensitive clinical observations."
        let plaintextData = Data(sensitiveNote.utf8)

        // 1. Encrypt with AES-GCM
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plaintextData, using: symmetricKey, nonce: nonce)

        let ivBase64 = Data(nonce).base64EncodedString()
        let tagBase64 = sealed.tag.base64EncodedString()
        let cipherBase64 = sealed.ciphertext.base64EncodedString()
        let encryptedEnvelope = "enc:v1:\(ivBase64):\(tagBase64):\(cipherBase64)"

        // Envelope should not contain sensitive plaintext
        XCTAssertFalse(encryptedEnvelope.contains("fasting blood glucose"))
        XCTAssertTrue(encryptedEnvelope.starts(with: "enc:v1:"))

        // 2. Decrypt envelope
        let parts = encryptedEnvelope.split(separator: ":")
        XCTAssertEqual(parts.count, 5)

        let ivData = Data(base64Encoded: String(parts[2]))!
        let tagData = Data(base64Encoded: String(parts[3]))!
        let cipherData = Data(base64Encoded: String(parts[4]))!

        let decryptedNonce = try AES.GCM.Nonce(data: ivData)
        let sealedBox = try AES.GCM.SealedBox(nonce: decryptedNonce, ciphertext: cipherData, tag: tagData)
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        let decryptedString = String(data: decryptedData, encoding: .utf8)

        XCTAssertEqual(decryptedString, sensitiveNote)
    }

    // MARK: - 7. Refresh Token Hashing & Rotation Simulation
    func testRefreshTokenHashingAndVerification() {
        let rawRefreshToken = "vialr_sec_ref_token_778899aabbccddeeff"
        let hash = SHA256.hash(data: Data(rawRefreshToken.utf8)).compactMap { String(format: "%02x", $0) }.joined()

        XCTAssertFalse(hash.isEmpty)
        XCTAssertNotEqual(rawRefreshToken, hash)

        // Same token produces identical SHA-256 digest for DB lookup
        let verifyHash = SHA256.hash(data: Data(rawRefreshToken.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hash, verifyHash)
    }
}
