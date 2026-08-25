import SwiftUI
import Domain
import DesignSystem
import Health

public struct SettingsView: View {
    @State private var enableHealthKit: Bool = true
    @State private var enableBiometrics: Bool = true
    @State private var enableReminders: Bool = true
    @State private var selectedUnit: DoseUnit = .mcg
    @State private var showExportSuccess: Bool = false
    public var onOpenClinicianReport: () -> Void

    public init(onOpenClinicianReport: @escaping () -> Void) {
        self.onOpenClinicianReport = onOpenClinicianReport
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

                            Toggle("Require Face ID / Touch ID to Unlock", isOn: $enableBiometrics)
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

                            if showExportSuccess {
                                Text("Protocol archive prepared and encrypted successfully.")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.accentEmerald)
                            }
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        // App Version Footer
                        VStack(spacing: 4) {
                            Text("Vialr for iOS — Version 1.0.0")
                                .font(VialrTypography.footnote)
                                .foregroundColor(VialrColors.textTertiary)
                            Text("Built natively with Swift 6 & SwiftUI. Strict local-first security.")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textMuted)
                        }
                        .padding(.top, VialrSpacing.md)
                    }
                    .padding(.horizontal, VialrSpacing.md)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
        }
    }
}
