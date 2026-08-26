import XCTest
import SwiftUI
@testable import Feature
@testable import Domain
@testable import Data

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

@MainActor
final class AuthenticationUITests: XCTestCase {

    func testAppleSignInNonceGenerationAndAntiReplay() {
        let manager = AppleSignInManager()
        let sha256HashedNonce = manager.prepareNonce()
        let rawNonce = manager.retrieveRawNonce()

        XCTAssertNotNil(rawNonce)
        XCTAssertFalse(sha256HashedNonce.isEmpty)

        // Verify SHA-256 relationship
        let computedHash = SHA256.hash(data: Data(rawNonce!.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(sha256HashedNonce, computedHash)

        // Anti-replay: Raw nonce must be purged after single read
        XCTAssertNil(manager.retrieveRawNonce())
    }

    func testAppSecurityManagerLifecycleAndPrivacyMask() {
        let security = AppSecurityManager.shared
        security.isBiometricsEnabled = true
        security.lockTimeoutSeconds = 60

        // Unlock
        security.unlockApp()
        XCTAssertFalse(security.isAppLocked)
        XCTAssertFalse(security.isPrivacyMaskActive)

        // 1. Moving to inactive phase activates privacy mask to protect health data from multitasking screenshotting
        security.handleScenePhaseChange(to: .inactive)
        XCTAssertTrue(security.isPrivacyMaskActive)

        // 2. Returning to active phase without timeout keeps app unlocked and removes privacy mask
        security.handleScenePhaseChange(to: .active)
        XCTAssertFalse(security.isPrivacyMaskActive)
        XCTAssertFalse(security.isAppLocked)

        // 3. Explicit app lock
        security.lockApp()
        // If session was locked, unlock resets state
        security.unlockApp()
        XCTAssertFalse(security.isAppLocked)
    }

    func testZeroUserDefaultsTokenStoragePolicy() throws {
        let keychain = KeychainService(serviceIdentifier: "com.vialr.tests.auth.\(UUID().uuidString)")
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"

        try keychain.saveString(token, forKey: KeychainService.Keys.accessToken)

        // Verify token is in Keychain
        let retrieved = try keychain.getString(forKey: KeychainService.Keys.accessToken)
        XCTAssertEqual(retrieved, token)

        // Strictly verify zero UserDefaults leakage of sensitive auth tokens
        XCTAssertNil(UserDefaults.standard.string(forKey: KeychainService.Keys.accessToken))
        XCTAssertNil(UserDefaults.standard.string(forKey: KeychainService.Keys.refreshToken))
        XCTAssertNil(UserDefaults.standard.string(forKey: "auth_token"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "jwt"))

        try keychain.clearAllAuthCredentials()
        XCTAssertNil(try keychain.getString(forKey: KeychainService.Keys.accessToken))
    }
}
