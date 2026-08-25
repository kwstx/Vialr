import SwiftUI
import Domain
import DesignSystem

/// Full-screen biometric lock gatekeeper displayed when local privacy lock is active.
/// Prompts Face ID, Touch ID, or Optic ID to regain interface access.
public struct BiometricLockView: View {
    @Bindable public var securityManager: AppSecurityManager
    @State private var isAuthenticating: Bool = false

    public init(securityManager: AppSecurityManager = .shared) {
        self.securityManager = securityManager
    }

    public var body: some View {
        ZStack {
            // Blurred Privacy Backdrop
            VialrColors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: VialrSpacing.xl) {
                Spacer()

                // Biometric Icon & Vault Shield
                VStack(spacing: VialrSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(VialrColors.cardSurfaceElevated)
                            .frame(width: 110, height: 110)
                            .shadow(color: VialrColors.accentTeal.opacity(0.15), radius: 20, x: 0, y: 10)

                        Image(systemName: securityManager.supportedBiometry.iconName)
                            .font(.system(size: 48, weight: .regular))
                            .foregroundColor(VialrColors.accentTeal)
                    }

                    Text("Vialr is Locked")
                        .font(VialrTypography.largeHero)
                        .foregroundColor(VialrColors.textPrimary)

                    Text("Unlock with \(securityManager.supportedBiometry.rawValue) to access your protocol schedule, inventory, and health biomarkers.")
                        .font(VialrTypography.subheadline)
                        .foregroundColor(VialrColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VialrSpacing.xl)
                }

                if let error = securityManager.lastErrorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(VialrColors.accentRose)
                        Text(error)
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.accentRose)
                    }
                    .padding(.horizontal, VialrSpacing.lg)
                    .transition(.opacity)
                }

                Spacer()

                // Unlock Button
                VStack(spacing: VialrSpacing.sm) {
                    VialrButton(
                        "Unlock with \(securityManager.supportedBiometry.rawValue)",
                        icon: securityManager.supportedBiometry.iconName,
                        isLoading: isAuthenticating,
                        style: .primary
                    ) {
                        triggerUnlock()
                    }

                    Text("Protected with Apple Secure Enclave & Face ID")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                }
                .padding(.horizontal, VialrSpacing.xl)
                .padding(.bottom, VialrSpacing.xxl)
            }
        }
        .onAppear {
            triggerUnlock()
        }
    }

    private func triggerUnlock() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task { @MainActor in
            await securityManager.requestBiometricUnlock()
            isAuthenticating = false
        }
    }
}
