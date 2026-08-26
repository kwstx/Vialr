import SwiftUI

/// DesignSystemCatalogView: An interactive visual showcase displaying all design tokens,
/// typography scales, buttons, Cal AI metric cards, and domain components.
/// Includes a dedicated showcase of Accessibility foundation components.
public struct DesignSystemCatalogView: View {
    @State private var selectedTab: Int = 0
    @State private var sampleInputValue: String = "BPC-157"
    @State private var sampleDoseValue: Double = 250.0
    @State private var selectedSegment: String = "Active"
    @State private var selectedSiteId: String? = "delt_l"
    @State private var showToast: Bool = false

    private let sampleSites = [
        SiteSelectionItem(id: "delt_l", name: "Left Deltoid", shortLabel: "Left Delt", daysSinceLastUse: 6, isRecommended: true),
        SiteSelectionItem(id: "delt_r", name: "Right Deltoid", shortLabel: "Right Delt", daysSinceLastUse: 2),
        SiteSelectionItem(id: "ab_l_uo", name: "Upper Left Abdomen", shortLabel: "Upper Left", daysSinceLastUse: 0),
        SiteSelectionItem(id: "ab_r_uo", name: "Upper Right Abdomen", shortLabel: "Upper Right", daysSinceLastUse: 8),
        SiteSelectionItem(id: "ab_l_lo", name: "Lower Left Abdomen", shortLabel: "Lower Left", daysSinceLastUse: 4),
        SiteSelectionItem(id: "ab_r_lo", name: "Lower Right Abdomen", shortLabel: "Lower Right", daysSinceLastUse: nil),
        SiteSelectionItem(id: "thigh_l_outer", name: "Left Outer Thigh", shortLabel: "Left Thigh", daysSinceLastUse: 12),
        SiteSelectionItem(id: "thigh_r_outer", name: "Right Outer Thigh", shortLabel: "Right Thigh", daysSinceLastUse: 1)
    ]

    private let sampleChartSummary = ChartDataSummary(
        title: "IGF-1 Longitudinal Trajectory",
        metricUnit: "ng/mL",
        totalDataPoints: 8,
        minimumValue: 142.0,
        maximumValue: 286.0,
        averageValue: 215.4,
        currentValue: 278.0,
        baselineValue: 142.0,
        trendDirectionDescription: "Shifted +136.0 ng/mL (+95.8%) from baseline",
        keyObservations: [
            "Clinical reference zone: 115 to 307 ng/mL",
            "Optimal range reached at Day 42 following Protocol B initiation"
        ]
    )

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VialrSpacing.sectionSpacing) {
                // Header Banner
                catalogHeader

                // 1. Color Palette Tokens
                colorPaletteSection

                // 2. Typography Scale
                typographySection

                // 3. Accessibility Foundations (Rule 33)
                accessibilitySection

                // 4. Cal AI Metric Cards
                metricCardsSection

                // 5. Buttons & Actions (Uber & Cal AI Styles)
                buttonsSection

                // 6. Interactive Form Controls & Steppers
                formControlsSection

                // 7. Uber-Style Action Rows
                actionRowsSection

                // 8. Domain Visuals (Syringe & Vial)
                domainVisualsSection

                // 9. Body Map Rotation
                bodyMapSection
            }
            .padding(.horizontal, VialrSpacing.screenHorizontal)
            .padding(.bottom, VialrSpacing.huge)
        }
        .background(VialrColors.backgroundPrimary.ignoresSafeArea())
        .overlay(alignment: .top) {
            if showToast {
                ToastBannerView(
                    toast: ToastMessage(
                        title: "Dose Logged Successfully",
                        message: "250 mcg BPC-157 recorded to active protocol",
                        type: .success
                    ),
                    onDismiss: { showToast = false }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header
    private var catalogHeader: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
            Text("VIALR DESIGN SYSTEM")
                .vialrEyebrow()

            Text("Uber Clarity + Cal AI Polish")
                .font(VialrTypography.screenTitle)
                .foregroundColor(VialrColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("High-contrast monochrome foundation, electric vitality emerald, generous whitespace, massive metrics, and accessible from the start.")
                .font(VialrTypography.body)
                .foregroundColor(VialrColors.textSecondary)
                .padding(.top, 2)
        }
        .padding(.top, VialrSpacing.lg)
    }

    // MARK: - 1. Color Palette
    private var colorPaletteSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("Color Foundations")
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VialrSpacing.sm) {
                colorSwatch(name: "Pitch Black", color: VialrColors.backgroundPrimary, hex: "#000000")
                colorSwatch(name: "Card Surface", color: VialrColors.cardSurface, hex: "#13171F")
                colorSwatch(name: "Elevated Surface", color: VialrColors.cardSurfaceElevated, hex: "#1A202C")
                colorSwatch(name: "Electric Vitality", color: VialrColors.accentVitality, hex: "#10E79D")
                colorSwatch(name: "Amber Caution", color: VialrColors.accentAmber, hex: "#FF9F0A")
                colorSwatch(name: "Coral Rose", color: VialrColors.accentRose, hex: "#FF453A")
            }
        }
    }

    private func colorSwatch(name: String, color: Color, hex: String) -> some View {
        HStack(spacing: VialrSpacing.sm) {
            RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                .fill(color)
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                        .stroke(VialrColors.glassBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textPrimary)
                Text(hex)
                    .font(VialrTypography.monoSub)
                    .foregroundColor(VialrColors.textTertiary)
            }
            Spacer()
        }
        .padding(10)
        .background(VialrColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                .stroke(VialrColors.glassBorder, lineWidth: 0.8)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Color token: \(name), Hex code: \(hex)")
    }

    // MARK: - 2. Typography
    private var typographySection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("Typography Hierarchy (Dynamic Type)")
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            VialrCard {
                VStack(alignment: .leading, spacing: VialrSpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MICRO EYEBROW (11PT UPPERCASE)")
                            .vialrEyebrow()
                        Text("Section context tag")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }

                    Divider().background(VialrColors.divider)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Screen Title 32pt Heavy")
                            .font(VialrTypography.screenTitle)
                            .foregroundColor(VialrColors.textPrimary)
                    }

                    Divider().background(VialrColors.divider)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("500 mcg")
                            .font(VialrTypography.metricHero)
                            .foregroundColor(VialrColors.textPrimary)
                        Text("Hero Metric Display (48pt Rounded)")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }

                    Divider().background(VialrColors.divider)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monospaced Dose: 0.15 mL / 15.0 IU")
                            .font(VialrTypography.monoDose)
                            .foregroundColor(VialrColors.accentVitality)
                    }
                }
            }
        }
    }

    // MARK: - 3. Accessibility Foundations (Rule 33)
    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("Accessibility Foundations (Rule 33)")
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: VialrSpacing.sm) {
                // Non-Color-Reliant Status Indicators
                VStack(alignment: .leading, spacing: 8) {
                    Text("NON-COLOR-RELIANT STATUS SYMBOLS")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)

                    HStack(spacing: 12) {
                        AccessibleStatusIndicator(.success, color: VialrColors.accentVitality)
                        AccessibleStatusIndicator(.warning, color: VialrColors.accentAmber)
                        AccessibleStatusIndicator(.critical, color: VialrColors.accentRose)
                        AccessibleStatusIndicator(.info, color: VialrColors.accentCyan)
                        AccessibleStatusIndicator(.neutral, color: VialrColors.textSecondary)
                    }
                }
                .padding(VialrSpacing.md)
                .vialrCard()

                // Accessible Chart Container with Expandable Textual Breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACCESSIBLE CHART WITH TEXTUAL SUMMARY")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)

                    AccessibleChartContainer(summary: sampleChartSummary) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VialrColors.cardSurfaceElevated)
                            .frame(height: 120)
                            .overlay(
                                Text("Visual Trajectory Chart Canvas")
                                    .font(VialrTypography.footnote)
                                    .foregroundColor(VialrColors.textTertiary)
                            )
                    }
                }
                .padding(VialrSpacing.md)
                .vialrCard()
            }
        }
    }

    // MARK: - 4. Cal AI Metric Cards
    private var metricCardsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("Cal AI Metric Cards")
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VialrSpacing.interItemSpacing) {
                VialrMetricCard(
                    eyebrow: "Daily Protocol",
                    value: "96%",
                    unit: nil,
                    subtitle: "14-day streak",
                    badge: MetricBadge(.success("On Track")),
                    progress: 0.96
                )

                VialrMetricCard(
                    eyebrow: "Active Compound",
                    value: "250",
                    unit: "mcg",
                    subtitle: "BPC-157 SubQ",
                    badge: MetricBadge(.neutral("AM Dose"))
                )

                VialrMetricCard(
                    eyebrow: "Vial Remaining",
                    value: "3.2",
                    unit: "mL",
                    subtitle: "18 doses left",
                    progress: 0.64,
                    progressColor: VialrColors.accentVitality
                )

                VialrMetricCard(
                    eyebrow: "Cost / Day",
                    value: "$2.14",
                    unit: nil,
                    subtitle: "3 active peptides",
                    badge: MetricBadge(.info("Estimated"))
                )
            }
        }
    }

    // MARK: - 5. Buttons
    private var buttonsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("Action Buttons (≥44pt Touch Targets)")
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: VialrSpacing.sm) {
                // Uber Stark White Primary
                VialrButton("Log Protocol Dose (Uber Stark)", icon: "plus", style: .primary) {
                    withAnimation { showToast = true }
                }

                // Cal AI Vitality Emerald
                VialrButton("Start Reconstitution (Cal AI Vitality)", icon: "drop.fill", style: .vitality) {
                    withAnimation { showToast = true }
                }

                // Secondary & Outline Inset
                HStack(spacing: VialrSpacing.sm) {
                    VialrButton("Secondary Card", style: .secondary, size: .standard) {}
                    VialrButton("Subtle Outline", style: .outline, size: .standard) {}
                }

                // Pill Mini Buttons
                HStack(spacing: VialrSpacing.sm) {
                    VialrButton("Fast Log", icon: "bolt.fill", style: .vitality, size: .pill, isFullWidth: false) {}
                    VialrButton("Cancel", style: .outline, size: .pill, isFullWidth: false) {}
                    VialrButton("Delete", style: .destructiveOutline, size: .pill, isFullWidth: false) {}
                    Spacer()
                }
            }
        }
    }

    // MARK: - 6. Form Controls & Steppers
    private var formControlsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("Controls & Steppers")
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: VialrSpacing.md) {
                VialrSegmentedControl(
                    items: ["Active", "Scheduled", "Completed", "Archived"],
                    selection: $selectedSegment
                )

                VialrInputField(
                    "Compound Name",
                    placeholder: "e.g. Semaglutide, Tirzepatide",
                    value: $sampleInputValue,
                    unit: "5mg",
                    icon: "pills.fill"
                )

                VialrStepper(
                    title: "Adjust Dose Target",
                    value: $sampleDoseValue,
                    step: 50.0,
                    range: 50...2000,
                    unit: "mcg"
                )
            }
        }
    }

    // MARK: - 7. Action Rows
    private var actionRowsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("Uber Action Rows")
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: VialrSpacing.xs) {
                VialrRow(
                    title: "BPC-157 Daily Healing",
                    subtitle: "250 mcg • SubQ Morning • Week 3",
                    leadingIcon: "syringe.fill",
                    leadingIconColor: VialrColors.accentVitality,
                    trailingBadge: MetricBadge(.success("Active")),
                    action: {}
                )

                VialrRow(
                    title: "TB-500 Recovery Protocol",
                    subtitle: "2.5 mg • Twice Weekly • Due in 2 days",
                    leadingIcon: "cross.vial.fill",
                    leadingIconColor: VialrColors.accentCyan,
                    trailingText: "2.5 mg",
                    action: {}
                )

                VialrRow(
                    title: "Comprehensive Metabolic Panel",
                    subtitle: "Uploaded 4 days ago • 14 biomarkers",
                    leadingIcon: "doc.text.fill",
                    leadingIconColor: VialrColors.accentAmber,
                    trailingBadge: MetricBadge(.warning("Review")),
                    action: {}
                )
            }
        }
    }

    // MARK: - 8. Domain Visuals
    private var domainVisualsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("Domain Visualizations")
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            InteractiveSyringeView(
                units: 12.5,
                syringeSize: .point5ml,
                doseDescription: "250 mcg (0.25 mg)",
                volumeMl: 0.125,
                concentrationMgMl: 2.0,
                compoundName: "BPC-157",
                presentationStyle: .full,
                showUnderlyingNumbers: true,
                showTargetCallout: true,
                showScaleNumbers: true
            )

            InteractiveSyringeView(
                units: 25.0,
                syringeSize: .oneMl,
                doseDescription: "500 mcg Tirzepatide",
                volumeMl: 0.25,
                presentationStyle: .compact
            )

            VialGraphicView(
                compoundName: "BPC-157 Reconstituted",
                concentrationText: "2.0 mg / mL (10mg in 5mL BAC)",
                fillPercentage: 0.72,
                isReconstituted: true,
                badgeColor: VialrColors.accentVitality
            )
        }
    }

    // MARK: - 9. Body Map
    private var bodyMapSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("Injection Site Rotation")
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            BodyMapSelectorView(
                sites: sampleSites,
                selectedSiteId: $selectedSiteId
            )
        }
    }
}
