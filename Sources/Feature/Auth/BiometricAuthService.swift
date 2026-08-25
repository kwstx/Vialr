import Foundation
import Domain
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

public protocol BiometricAuthServiceProtocol: Sendable {
    func supportedBiometricType() -> BiometricType
    func canEvaluateBiometrics() -> Bool
    func authenticateUser(reason: String) async -> Result<Bool, Error>
}

public enum BiometricError: Error, LocalizedError, Sendable {
    case biometricsNotAvailable
    case biometricsNotEnrolled
    case userCancelled
    case authenticationFailed(String)
    case passcodeNotSet
    case unknown

    public var errorDescription: String? {
        switch self {
        case .biometricsNotAvailable:
            return "Face ID / Touch ID is not supported on this device."
        case .biometricsNotEnrolled:
            return "No Face ID or Touch ID identities are enrolled in iOS Settings."
        case .userCancelled:
            return "Authentication was cancelled by the user."
        case .authenticationFailed(let msg):
            return "Biometric authentication failed: \(msg)"
        case .passcodeNotSet:
            return "A device passcode is not configured on this device."
        case .unknown:
            return "An unexpected biometric authentication error occurred."
        }
    }
}

/// Native iOS Biometric Authentication Service.
/// Evaluates Face ID, Touch ID, or Optic ID to protect local application access.
///
/// NOTE: The biometric layer strictly protects local UI access and Keychain unlocking,
/// rather than replacing or substituting server-side cryptographic authentication.
public final class BiometricAuthService: BiometricAuthServiceProtocol, @unchecked Sendable {
    public static let shared = BiometricAuthService()

    public init() {}

    /// Detects the hardware biometric authentication capability available on the current device.
    public func supportedBiometricType() -> BiometricType {
        #if canImport(LocalAuthentication) && (os(iOS) || os(macOS) || os(visionOS))
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        guard canEvaluate || error?.code != LAError.biometryNotAvailable.rawValue else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
        #else
        return .none
        #endif
    }

    /// Checks if the device is currently capable of evaluating biometrics.
    public func canEvaluateBiometrics() -> Bool {
        #if canImport(LocalAuthentication) && (os(iOS) || os(macOS) || os(visionOS))
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        #else
        return false
        #endif
    }

    /// Evaluates biometric authentication prompt using Face ID / Touch ID with a localized reason.
    public func authenticateUser(
        reason: String = "Unlock Vialr to access your secure protocol data"
    ) async -> Result<Bool, Error> {
        #if canImport(LocalAuthentication) && (os(iOS) || os(macOS) || os(visionOS))
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"
        context.localizedCancelTitle = "Cancel"

        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
            if let err = authError {
                if err.code == LAError.biometryNotEnrolled.rawValue {
                    return .failure(BiometricError.biometricsNotEnrolled)
                } else if err.code == LAError.passcodeNotSet.rawValue {
                    return .failure(BiometricError.passcodeNotSet)
                }
            }
            // If biometrics not available, attempt device passcode fallback
            return await authenticateWithDevicePasscode(context: context, reason: reason)
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, evaluationError in
                if success {
                    continuation.resume(returning: .success(true))
                } else if let error = evaluationError as? LAError {
                    switch error.code {
                    case .userCancel, .appCancel:
                        continuation.resume(returning: .failure(BiometricError.userCancelled))
                    case .userFallback:
                        // User tapped "Enter Passcode" fallback
                        Task {
                            let passcodeResult = await self.authenticateWithDevicePasscode(reason: reason)
                            continuation.resume(returning: passcodeResult)
                        }
                    default:
                        continuation.resume(returning: .failure(BiometricError.authenticationFailed(error.localizedDescription)))
                    }
                } else {
                    continuation.resume(returning: .failure(BiometricError.unknown))
                }
            }
        }
        #else
        return .success(true)
        #endif
    }

    /// Device passcode fallback evaluation
    private func authenticateWithDevicePasscode(
        context: LAContext = LAContext(),
        reason: String
    ) async -> Result<Bool, Error> {
        #if canImport(LocalAuthentication) && (os(iOS) || os(macOS) || os(visionOS))
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) { success, error in
                if success {
                    continuation.resume(returning: .success(true))
                } else {
                    continuation.resume(returning: .failure(BiometricError.authenticationFailed(error?.localizedDescription ?? "Passcode verification failed")))
                }
            }
        }
        #else
        return .success(true)
        #endif
    }
}
