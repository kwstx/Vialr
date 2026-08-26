import SwiftUI
import DesignSystem

/// Reusable hero visual component for onboarding slides with modern glows, badges, and illustrations.
public struct OnboardingHeroVisual: View {
    public let item: OnboardingPageItem

    public init(item: OnboardingPageItem) {
        self.item = item
    }

    public var body: some View {
        ZStack {
            // Ambient Radial Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            VialrColors.accentVitality.opacity(0.22),
                            VialrColors.accentVitality.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .blur(radius: 20)

            // Main Glass Hero Card
            VStack(spacing: VialrSpacing.md) {
                // Top floating badge
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(VialrColors.accentVitality)
                            .frame(width: 6, height: 6)
                        Text(item.heroBadgeText.uppercased())
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textPrimary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(VialrColors.cardSurfaceElevated.opacity(0.8))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(VialrColors.glassBorder, lineWidth: 1)
                    )

                    Spacer()

                    if let secondary = item.secondaryBadgeText {
                        Text(secondary)
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.04))
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                // Center Topic Illustration
                centerGraphicView
                    .frame(height: 110)

                Spacer()

                // Bottom Metric Tag / Highlight
                if let val = item.keyMetricValue, let lbl = item.keyMetricLabel {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(val)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(VialrColors.accentVitality)
                        Text(lbl)
                            .font(VialrTypography.footnote)
                            .foregroundColor(VialrColors.textSecondary)
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(VialrColors.accentVitality.opacity(0.8))
                    }
                    .padding(.horizontal, VialrSpacing.sm)
                    .padding(.vertical, 8)
                    .background(VialrColors.cardSurfaceSubtle.opacity(0.9))
                    .cornerRadius(VialrSpacing.radiusSm)
                }
            }
            .padding(VialrSpacing.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .background(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusLg, style: .continuous)
                    .fill(VialrColors.heroCardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusLg, style: .continuous)
                    .stroke(VialrColors.glassBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
        }
        .padding(.horizontal, VialrSpacing.xs)
    }

    @ViewBuilder
    private var centerGraphicView: some View {
        switch item.visualType {
        case .compounds:
            HStack(spacing: VialrSpacing.lg) {
                iconBubble(name: "cross.case.fill", label: "Peptides", color: VialrColors.accentVitality)
                iconBubble(name: "flame.fill", label: "GLP-1", color: VialrColors.accentAmber)
                iconBubble(name: "bolt.shield.fill", label: "TRT", color: VialrColors.accentViolet)
            }

        case .scheduling:
            HStack(spacing: 8) {
                ForEach(["Mon", "Wed", "Fri", "Sun"], id: \.self) { day in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(day == "Mon" || day == "Fri" ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: day == "Mon" || day == "Fri" ? "checkmark" : "circle")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(day == "Mon" || day == "Fri" ? Color.black : VialrColors.textTertiary)
                            )
                        Text(day)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(VialrColors.textSecondary)
                    }
                }
            }

        case .reconstitution:
            HStack(spacing: VialrSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("5 mg Vial + 2.0 mL BAC")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentCyan)
                    Text("= 250 mcg per 10 Units")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textPrimary)
                }
                Spacer()
                Image(systemName: "syringe.fill")
                    .font(.system(size: 38))
                    .foregroundColor(VialrColors.accentVitality)
                    .rotationEffect(.degrees(45))
            }
            .padding(.horizontal, VialrSpacing.md)

        case .siteRotation:
            HStack(spacing: VialrSpacing.md) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 42))
                    .foregroundColor(VialrColors.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next: Right Lower Abdomen")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                    Text("Rotated 4 days ago from Left Thigh")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                }
            }

        case .quickLogging:
            HStack(spacing: VialrSpacing.md) {
                ZStack {
                    Circle()
                        .fill(VialrColors.accentVitality)
                        .frame(width: 48, height: 48)
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(Color.black)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dose Logged in 1.8s")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                    Text("Inventory auto-deducted 0.1mL")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                }
            }

        case .inventoryDepletion:
            HStack(spacing: VialrSpacing.md) {
                Image(systemName: "cylinder.split.1x2.fill")
                    .font(.system(size: 36))
                    .foregroundColor(VialrColors.accentAmber)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vial Volume: 82% Remaining")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                    ProgressView(value: 0.82)
                        .tint(VialrColors.accentVitality)
                }
            }

        case .bloodwork:
            HStack(spacing: VialrSpacing.md) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 36))
                    .foregroundColor(VialrColors.accentRose)
                VStack(alignment: .leading, spacing: 2) {
                    Text("IGF-1: +28% Baseline")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.accentVitality)
                    Text("Hs-CRP: 0.4 mg/L (Optimal)")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

        case .healthSync:
            HStack(spacing: VialrSpacing.md) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 38))
                    .foregroundColor(VialrColors.accentRose)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Resting HR: 54 bpm")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                    Text("HRV: 78 ms • Weight: Synced")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

        case .protocolReplay:
            HStack(spacing: VialrSpacing.md) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 38))
                    .foregroundColor(VialrColors.accentVitality)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day 42 of 60 Completed")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                    Text("Adherence: 98.4% On Schedule")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

        case .clinicianExport:
            HStack(spacing: VialrSpacing.md) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 36))
                    .foregroundColor(VialrColors.textPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Physician Longitudinal Report")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                    Text("Encrypted PDF ready to share")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

        case .privacyVault:
            HStack(spacing: VialrSpacing.md) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(VialrColors.accentVitality)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hardware Secure Enclave")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                    Text("Biometric Face ID / Touch ID")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

        case .personalizedPlan:
            HStack(spacing: VialrSpacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(VialrColors.accentVitality)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Setup Your Private Vault")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                    Text("Takes less than 30 seconds")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }
        }
    }

    private func iconBubble(name: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(VialrColors.textSecondary)
        }
    }
}
