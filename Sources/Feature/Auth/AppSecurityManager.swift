import SwiftUI
import Observation
import Domain
import Data

/// Observable security manager controlling local biometric application locking,
/// inactivity timeouts, privacy masking during multitasking app-switching, and session protection.
@Observable
public final class AppSecurityManager: @unchecked Sendable {
    public static let shared = AppSecurityManager()

    // MARK: - State Properties
    public var isAppLocked: Bool = false
    public var isPrivacyMaskActive: Bool = false
    public var isBiometricsEnabled: Bool = true
    public var lockTimeoutSeconds: Int = 60
    public var supportedBiometry: BiometricType = .none
    public var unlockStatus: BiometricUnlockStatus = .unlocked
    public var lastErrorMessage: String?

    private var lastBackgroundedAt: Date?
    private let biometricService: BiometricAuthServiceProtocol
    private let keychainService: KeychainServiceProtocol

    public init(
        biometricService: BiometricAuthServiceProtocol = BiometricAuthService.shared,
        keychainService: KeychainServiceProtocol = KeychainService.shared
    ) {
        self.biometricService = biometricService
        self.keychainService = keychainService
        self.supportedBiometry = biometricService.supportedBiometricType()
    }

    /// Configures the security preferences from the user's domain settings.
    public func configure(with preferences: PrivacyPreferences) {
        self.isBiometricsEnabled = preferences.requireBiometricUnlock
        self.lockTimeoutSeconds = preferences.biometricLockTimeoutSeconds
        self.supportedBiometry = biometricService.supportedBiometricType()
        
        // If biometrics are enabled and app was locked, prepare state
        if isBiometricsEnabled && hasActiveSession() {
            // Keep current lock status
        } else {
            self.isAppLocked = false
        }
    }

    /// Returns true if a valid authentication session or access token is stored in the Keychain.
    public func hasActiveSession() -> Bool {
        if let token = try? keychainService.getString(forKey: KeychainService.Keys.accessToken), !token.isEmpty {
            return true
        }
        return false
    }

    /// Manually locks the application interface.
    public func lockApp() {
        guard isBiometricsEnabled && hasActiveSession() else { return }
        self.isAppLocked = true
        self.unlockStatus = .locked
    }

    /// Manually unlocks the application interface after successful verification.
    public func unlockApp() {
        self.isAppLocked = false
        self.isPrivacyMaskActive = false
        self.unlockStatus = .unlocked
        self.lastErrorMessage = nil
        self.lastBackgroundedAt = nil
    }

    /// Prompts the system Face ID / Touch ID evaluation sheet.
    @MainActor
    public func requestBiometricUnlock(reason: String? = nil) async {
        guard isBiometricsEnabled else {
            unlockApp()
            return
        }

        let unlockReason = reason ?? "Unlock Vialr to access your protocol and health data"
        let result = await biometricService.authenticateUser(reason: unlockReason)

        switch result {
        case .success:
            unlockApp()
        case .failure(let error):
            self.unlockStatus = .failed(error.localizedDescription)
            self.lastErrorMessage = error.localizedDescription
        }
    }

    /// Handles scene phase transitions to enforce privacy blur in app switcher and timeout locks upon resume.
    public func handleScenePhaseChange(to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App entered foreground
            self.isPrivacyMaskActive = false
            if let backgroundedDate = lastBackgroundedAt, isBiometricsEnabled && hasActiveSession() {
                let elapsed = Date().timeIntervalSince(backgroundedDate)
                if elapsed >= Double(lockTimeoutSeconds) {
                    self.isAppLocked = true
                    self.unlockStatus = .locked
                    Task { @MainActor in
                        await self.requestBiometricUnlock()
                    }
                }
            }
            self.lastBackgroundedAt = nil

        case .inactive:
            // App is transitioning (e.g. App Switcher or incoming call) -> mask sensitive data
            if isBiometricsEnabled && hasActiveSession() {
                self.isPrivacyMaskActive = true
            }

        case .background:
            // App entered background -> record timestamp and apply privacy mask
            self.lastBackgroundedAt = Date()
            if isBiometricsEnabled && hasActiveSession() {
                self.isPrivacyMaskActive = true
                if lockTimeoutSeconds == 0 {
                    self.isAppLocked = true
                    self.unlockStatus = .locked
                }
            }

        @unknown default:
            break
        }
    }
}
