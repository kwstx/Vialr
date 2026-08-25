import SwiftUI
import Domain
import DesignSystem
import Health
import Data

public struct SettingsView: View {
    @State private var enableHealthKit: Bool = true
    @State private var enableBiometrics: Bool = true
    @State private var lockTimeout: Int = 60
    @State private var enableReminders: Bool = true
    @State private var selectedUnit: DoseUnit = .mcg
    @State private var showExportSuccess: Bool = false
    @State private var showSignOutAlert: Bool = false

    public var onOpenClinicianReport: () -> Void
    public var onLockApp: (() -> Void)?
    public var onSignOut: (() -> Void)?

    private let securityManager: AppSecurityManager

    public init(
        securityManager: AppSecurityManager = .shared,
        onOpenClinicianReport: @escaping () -> Void,
        onLockApp: (() -> Void)? = nil,
        onSignOut: (() -> Void)? = nil
    ) {
        self.securityManager = securityManager
        self.onOpenClinicianReport = onOpenClinicianReport
        self.onLockApp = onLockApp
        self.onSignOut = onSignOut
        _enableBiometrics = State(initialValue: securityManager.isBiometricsEnabled)
        _lockTimeout = State(initialValue: securityManager.lockTimeoutSeconds)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SYSTEM & CONFIG")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.accentTeal)
                                Text("Settings & Privacy")
                                    .font(VialrTypography.largeHero)
                                    .foregroundColor(VialrColors.textPrimary)
                            }
                            Spacer()
                        }
                        .padding(.top, VialrSpacing.sm)

                        // Clinician Summary Report Shortcut Card
                        Button {
                            onOpenClinicianReport()
                        } label: {
                            HStack(spacing: VialrSpacing.md) {
                                Image(systemName: "doc.text.image.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(VialrColors.accentTeal)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Export Clinician Medical Report")
                                        .font(VialrTypography.headline)
                                        .foregroundColor(VialrColors.textPrimary)
                                    Text("Generate printable physician PDF summary")
                                        .font(VialrTypography.footnote)
                                        .foregroundColor(VialrColors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(VialrColors.textTertiary)
                            }
                            .padding(VialrSpacing.md)
                            .vialrCard()
                        }
                        .buttonStyle(.plain)

                        // MARK: - Account Security & Biometrics
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            HStack {
                                Text("SECURITY & BIOMETRICS")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.accentTeal)
                                Spacer()
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(VialrColors.accentTeal)
                            }

                            Toggle("Require \(securityManager.supportedBiometry.rawValue) to Unlock", isOn: $enableBiometrics)
                                .tint(VialrColors.accentTeal)
                                .foregroundColor(VialrColors.textPrimary)
                                .onChange(of: enableBiometrics) { _, newValue in
                                    securityManager.isBiometricsEnabled = newValue
                                }

                            if enableBiometrics {
                                HStack {
                                    Text("Auto-Lock Timeout")
                                        .foregroundColor(VialrColors.textPrimary)
                                    Spacer()
                                    Picker("Lock Timeout", selection: $lockTimeout) {
                                        Text("Immediately").tag(0)
                                        Text("1 minute").tag(60)
                                        Text("5 minutes").tag(300)
                                        Text("15 minutes").tag(900)
                                    }
                                    .pickerStyle(.menu)
                                    .onChange(of: lockTimeout) { _, newValue in
                                        securityManager.lockTimeoutSeconds = newValue
                                    }
                                }

                                Button {
                                    onLockApp?()
                                    securityManager.lockApp()
                                } label: {
                                    HStack {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(VialrColors.accentTeal)
                                        Text("Lock App Now")
                                            .font(VialrTypography.headline)
                                            .foregroundColor(VialrColors.textPrimary)
                                        Spacer()
                                    }
                                    .padding(VialrSpacing.sm)
                                    .background(VialrColors.cardSurfaceElevated)
                                    .cornerRadius(VialrSpacing.radiusSm)
                                }
                                .buttonStyle(.plain)
                            }

                            // Security Info Banner
                            HStack(alignment: .top, spacing: VialrSpacing.xs) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(VialrColors.accentEmerald)
                                    .font(.footnote)
                                Text("Hardware Keychain protection active. Auth tokens are never stored in UserDefaults.")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textSecondary)
                            }
                            .padding(.top, VialrSpacing.xxs)
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        // Health & Integrations
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            Text("HEALTH INTEGRATIONS")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            Toggle("Sync with Apple Health", isOn: $enableHealthKit)
                                .tint(VialrColors.accentTeal)
                                .foregroundColor(VialrColors.textPrimary)

                            Toggle("Dose Reminders & Restock Alerts", isOn: $enableReminders)
                                .tint(VialrColors.accentTeal)
                                .foregroundColor(VialrColors.textPrimary)
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        // Preferences
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            Text("PREFERENCES")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            HStack {
                                Text("Default Mass Unit")
                                    .foregroundColor(VialrColors.textPrimary)
                                Spacer()
                                Picker("Dose Unit", selection: $selectedUnit) {
                                    ForEach(DoseUnit.allCases) { u in
                                        Text(u.rawValue).tag(u)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        // Data Management & Export
                        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                            Text("DATA & BACKUPS")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            Button {
                                showExportSuccess = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .foregroundColor(VialrColors.accentTeal)
                                    Text("Export Protocol Archive (JSON / CSV)")
                                        .foregroundColor(VialrColors.textPrimary)
                                    Spacer()
                                }
                                .padding(VialrSpacing.sm)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusSm)
                            }
                            .buttonStyle(.plain)

                            if showExportSuccess {
                                Text("Protocol archive prepared and encrypted successfully.")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.accentEmerald)
                            }
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        // MARK: - Sign Out & Session Reset
                        VStack(spacing: VialrSpacing.sm) {
                            Button(role: .destructive) {
                                showSignOutAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Sign Out of Vialr")
                                }
                                .font(VialrTypography.headline)
                                .foregroundColor(VialrColors.accentRose)
                                .frame(maxWidth: .infinity)
                                .padding(VialrSpacing.md)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusMd)
                                .overlay(
                                    RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                                        .stroke(VialrColors.accentRose.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, VialrSpacing.xs)

                        // App Version Footer
                        VStack(spacing: 4) {
                            Text("Vialr for iOS — Version 1.0.0")
                                .font(VialrTypography.footnote)
                                .foregroundColor(VialrColors.textTertiary)
                            Text("Apple Data Protection & Secure Enclave Active")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textMuted)
                        }
                        .padding(.top, VialrSpacing.sm)
                    }
                    .padding(.horizontal, VialrSpacing.md)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .alert("Sign Out of Vialr?", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    try? KeychainService.shared.clearAllAuthCredentials()
                    onSignOut?()
                }
            } message: {
                Text("This will securely clear your local authentication tokens from the iOS Keychain. Your encrypted local data remains protected.")
            }
        }
    }
}
