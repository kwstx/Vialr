import SwiftUI
import Domain
import DesignSystem
import CalculationEngine

/// High-velocity Logging Hub: Provides instant 1-tap dose entry, scheduled protocol execution,
/// quick compound presets, site rotation recommendations, and recent dosing history.
public struct LoggingHubView: View {
    @Bindable public var viewModel: LoggingViewModel
    public var onOpenDoseConfirmation: ((DoseLog?) -> Void)?
    public var onOpenSiteRotation: (() -> Void)?
    public var onOpenSymptomLog: (() -> Void)?
    public var onOpenBiomarkerLog: (() -> Void)?
    public var onOpenReconstitution: (() -> Void)?

    @State private var showCustomDoseSheet: Bool = false
    @State private var doseToDelete: DoseLog?
    @State private var showDeleteConfirm: Bool = false

    public init(
        viewModel: LoggingViewModel,
        onOpenDoseConfirmation: ((DoseLog?) -> Void)? = nil,
        onOpenSiteRotation: (() -> Void)? = nil,
        onOpenSymptomLog: (() -> Void)? = nil,
        onOpenBiomarkerLog: (() -> Void)? = nil,
        onOpenReconstitution: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onOpenDoseConfirmation = onOpenDoseConfirmation
        self.onOpenSiteRotation = onOpenSiteRotation
        self.onOpenSymptomLog = onOpenSymptomLog
        self.onOpenBiomarkerLog = onOpenBiomarkerLog
        self.onOpenReconstitution = onOpenReconstitution
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: VialrSpacing.lg) {
                        // 1. Header Bar
                        headerSection

                        // 2. Next Scheduled Dose (Primary 1-Tap Hero CTA)
                        if let scheduled = viewModel.nextUpcomingDose {
                            heroScheduledDoseCard(scheduled)
                        } else {
                            noScheduledDoseHeroCard
                        }

                        // 3. 1-Tap Fast Presets (Frequent Compounds)
                        fastPresetsSection

                        // 4. Multi-Track Quick Action Grid (Symptoms, Labs, Site Map, Reconstitution)
                        quickActionGrid

                        // 5. Adherence & Consistency Pill
                        adherenceStatsCard

                        // 6. Recent Dose History & 1-Tap Repeat
                        recentDoseHistorySection
                    }
                    .padding(.horizontal, VialrSpacing.screenHorizontal)
                    .padding(.bottom, 110) // Space for floating tab bar
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadLoggingData()
            }
            .refreshable {
                await viewModel.loadLoggingData()
            }
            .alert("Delete Dose Record?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let dose = doseToDelete {
                        Task {
                            await viewModel.deleteDose(id: dose.id)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove this dose from your longitudinal timeline and restore vial liquid volume.")
            }
        }
    }

    // MARK: - 1. Header Section
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RAPID DOSE ENTRY")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentVitality)
                    .tracking(1.2)

                Text("Log & Dosing")
                    .font(VialrTypography.largeHero)
                    .foregroundColor(VialrColors.textPrimary)
                    .tracking(-0.5)
            }

            Spacer()

            HStack(spacing: 8) {
                // Quick Site Map Button
                Button {
                    VialrHaptics.lightImpact()
                    onOpenSiteRotation?()
                } label: {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(VialrColors.accentVitality)
                        .frame(width: 42, height: 42)
                        .background(VialrColors.cardSurfaceElevated)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(VialrColors.glassBorder, lineWidth: 1))
                }
                .accessibilityLabel("Open Site Rotation Map")

                // Quick Custom Dose Button
                Button {
                    VialrHaptics.lightImpact()
                    if let openConf = onOpenDoseConfirmation {
                        openConf(nil)
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(VialrColors.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(VialrColors.cardSurfaceElevated)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(VialrColors.glassBorder, lineWidth: 1))
                }
                .accessibilityLabel("Custom Dose Form")
            }
        }
        .padding(.top, VialrSpacing.sm)
    }

    // MARK: - 2. Hero Scheduled Dose Card (Sub-Second Logging)
    private func heroScheduledDoseCard(_ dose: DoseLog) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            // Eyebrow Status
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(VialrColors.accentVitality)
                        .frame(width: 8, height: 8)
                    Text("UPCOMING PROTOCOL DOSE")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentVitality)
                        .tracking(1.0)
                }

                Spacer()

                Text("Due Today")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(VialrColors.cardSurfaceSubtle)
                    .cornerRadius(VialrSpacing.radiusPill)
            }

            // Compound Title & Amount
            VStack(alignment: .leading, spacing: 4) {
                Text(dose.compoundName)
                    .font(VialrTypography.largeHero)
                    .foregroundColor(VialrColors.textPrimary)

                HStack(spacing: 8) {
                    Text("\(formatDoseAmount(dose.doseAmount)) \(dose.doseUnit.rawValue)")
                        .font(VialrTypography.metricMedium)
                        .foregroundColor(VialrColors.accentVitality)

                    Text("•")
                        .foregroundColor(VialrColors.textTertiary)

                    Text(dose.actualRoute.displayName)
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

            // Recommended Injection Site
            if let site = viewModel.recommendedSite {
                Button {
                    VialrHaptics.lightImpact()
                    onOpenSiteRotation?()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cross.circle.fill")
                            .foregroundColor(VialrColors.accentVitality)
                            .font(.system(size: 14))

                        Text("Recommended Site:")
                            .font(VialrTypography.footnote)
                            .foregroundColor(VialrColors.textSecondary)

                        Text(site.name)
                            .font(VialrTypography.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(VialrColors.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(VialrColors.textTertiary)
                    }
                    .padding(.horizontal, VialrSpacing.sm)
                    .padding(.vertical, 8)
                    .background(VialrColors.cardSurfaceSubtle)
                    .cornerRadius(VialrSpacing.radiusSm)
                }
                .buttonStyle(.plain)
            }

            Divider()
                .background(VialrColors.glassBorder)

            // Primary 1-Tap CTA
            HStack(spacing: VialrSpacing.sm) {
                Button {
                    Task {
                        _ = await viewModel.quickLogScheduledDose()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(Color.black)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 17, weight: .bold))
                            Text("1-Tap Log Dose")
                                .font(VialrTypography.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(VialrColors.primaryGradient)
                    .cornerRadius(VialrSpacing.radiusMd)
                    .shadow(color: VialrColors.accentVitality.opacity(0.35), radius: 12, x: 0, y: 4)
                }
                .disabled(viewModel.isSubmitting)

                // Advanced Details Button
                Button {
                    VialrHaptics.lightImpact()
                    if let openConf = onOpenDoseConfirmation {
                        openConf(dose)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(VialrColors.textPrimary)
                        .frame(width: 52, height: 52)
                        .background(VialrColors.cardSurfaceElevated)
                        .cornerRadius(VialrSpacing.radiusMd)
                        .overlay(
                            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                                .stroke(VialrColors.glassBorder, lineWidth: 1)
                        )
                }
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard(isElevated: true)
    }

    private var noScheduledDoseHeroCard: some View {
        VStack(spacing: VialrSpacing.md) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 40))
                .foregroundColor(VialrColors.accentVitality)

            VStack(spacing: 4) {
                Text("All Scheduled Doses Complete")
                    .font(VialrTypography.title2)
                    .foregroundColor(VialrColors.textPrimary)

                Text("Select a quick preset below or tap Quick Log for PRN doses.")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                VialrHaptics.lightImpact()
                if let openConf = onOpenDoseConfirmation {
                    openConf(nil)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Log Custom / PRN Dose")
                        .font(VialrTypography.subheadlineBold)
                }
                .foregroundColor(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(VialrColors.accentVitality)
                .cornerRadius(VialrSpacing.radiusMd)
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    // MARK: - 3. 1-Tap Fast Presets Section
    private var fastPresetsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("1-TAP COMPOUND PRESETS")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textTertiary)
                    .tracking(1.0)

                Spacer()

                Text("Instant Record")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.accentVitality)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VialrSpacing.sm) {
                    ForEach(viewModel.presets) { preset in
                        Button {
                            Task {
                                _ = await viewModel.quickLogPreset(preset)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(preset.category.uppercased())
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Color(hex: preset.colorHex))
                                    Spacer()
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: preset.colorHex))
                                }

                                Text(preset.compoundName)
                                    .font(VialrTypography.headline)
                                    .foregroundColor(VialrColors.textPrimary)
                                    .lineLimit(1)

                                Text("\(formatDoseAmount(preset.defaultAmount)) \(preset.doseUnit.rawValue)")
                                    .font(VialrTypography.metricSmall)
                                    .foregroundColor(VialrColors.accentVitality)
                            }
                            .padding(VialrSpacing.md)
                            .frame(width: 155, height: 104, alignment: .leading)
                            .background(VialrColors.cardSurface)
                            .cornerRadius(VialrSpacing.radiusMd)
                            .overlay(
                                RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                                    .stroke(VialrColors.glassBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 4. Quick Action Grid
    private var quickActionGrid: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("QUICK TRACKING ACTIONS")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.textTertiary)
                .tracking(1.0)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: VialrSpacing.sm), GridItem(.flexible(), spacing: VialrSpacing.sm)], spacing: VialrSpacing.sm) {
                quickActionTile(
                    title: "Log Symptoms",
                    subtitle: "Record side effects & mood",
                    icon: "heart.text.square.fill",
                    color: VialrColors.accentRose
                ) {
                    onOpenSymptomLog?()
                }

                quickActionTile(
                    title: "Log Biomarker",
                    subtitle: "Glucose, BP, Weight",
                    icon: "waveform.path.ecg",
                    color: VialrColors.accentCyan
                ) {
                    onOpenBiomarkerLog?()
                }

                quickActionTile(
                    title: "Site Rotation",
                    subtitle: "Interactive body map",
                    icon: "figure.stand",
                    color: VialrColors.accentVitality
                ) {
                    onOpenSiteRotation?()
                }

                quickActionTile(
                    title: "Reconstitute",
                    subtitle: "Mix & calculate vial",
                    icon: "plus.forwardslash.minus",
                    color: VialrColors.accentViolet
                ) {
                    onOpenReconstitution?()
                }
            }
        }
    }

    private func quickActionTile(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            VialrHaptics.lightImpact()
            action()
        } label: {
            HStack(spacing: VialrSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.12))
                    .cornerRadius(VialrSpacing.radiusSm)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VialrTypography.subheadlineBold)
                        .foregroundColor(VialrColors.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(VialrColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(VialrSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VialrColors.cardSurface)
            .cornerRadius(VialrSpacing.radiusMd)
            .overlay(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                    .stroke(VialrColors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. Adherence Stats Card
    private var adherenceStatsCard: some View {
        HStack(spacing: VialrSpacing.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text("7-DAY ADHERENCE")
                    .font(VialrTypography.eyebrow)
                    .foregroundColor(VialrColors.textTertiary)
                    .tracking(1.0)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(Int(viewModel.weeklyAdherencePercentage))%")
                        .font(VialrTypography.largeHero)
                        .foregroundColor(VialrColors.accentVitality)

                    Text("on track")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("ACTIVE STREAK")
                    .font(VialrTypography.eyebrow)
                    .foregroundColor(VialrColors.textTertiary)
                    .tracking(1.0)

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(VialrColors.accentAmber)
                    Text("\(viewModel.currentStreakDays) Days")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                }
            }
        }
        .padding(VialrSpacing.cardPaddingCompact)
        .vialrCard()
    }

    // MARK: - 6. Recent Dose History & 1-Tap Repeat
    private var recentDoseHistorySection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                Text("RECENT DOSES")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textTertiary)
                    .tracking(1.0)

                Spacer()

                Text("\(viewModel.filteredRecentDoses.count) recorded")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            if viewModel.filteredRecentDoses.isEmpty {
                VStack(spacing: VialrSpacing.sm) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 28))
                        .foregroundColor(VialrColors.textMuted)
                    Text("No doses recorded yet")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, VialrSpacing.xl)
                .vialrCard()
            } else {
                VStack(spacing: VialrSpacing.sm) {
                    ForEach(viewModel.filteredRecentDoses.prefix(15)) { dose in
                        doseHistoryRow(dose)
                    }
                }
            }
        }
    }

    private func doseHistoryRow(_ dose: DoseLog) -> some View {
        HStack(spacing: VialrSpacing.md) {
            // Route Icon
            ZStack {
                Circle()
                    .fill(dose.status == .taken ? VialrColors.accentVitality.opacity(0.12) : VialrColors.accentAmber.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: dose.status == .taken ? "checkmark" : "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(dose.status == .taken ? VialrColors.accentVitality : VialrColors.accentAmber)
            }

            // Compound & Meta
            VStack(alignment: .leading, spacing: 2) {
                Text(dose.compoundName)
                    .font(VialrTypography.headline)
                    .foregroundColor(VialrColors.textPrimary)

                HStack(spacing: 6) {
                    Text("\(formatDoseAmount(dose.doseAmount)) \(dose.doseUnit.rawValue)")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.accentVitality)

                    if let siteName = dose.injectionSiteName {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(VialrColors.textTertiary)
                        Text(siteName)
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                }
            }

            Spacer()

            // 1-Tap Repeat Button
            Button {
                Task {
                    _ = await viewModel.repeatPastDose(dose)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                    Text("Repeat")
                        .font(VialrTypography.captionBold)
                }
                .foregroundColor(VialrColors.accentVitality)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(VialrColors.accentVitality.opacity(0.12))
                .cornerRadius(VialrSpacing.radiusPill)
            }

            // Context Menu for Deletion
            Menu {
                Button(role: .destructive) {
                    doseToDelete = dose
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Dose", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundColor(VialrColors.textTertiary)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(VialrSpacing.sm)
        .background(VialrColors.cardSurface)
        .cornerRadius(VialrSpacing.radiusSm)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                .stroke(VialrColors.glassBorder, lineWidth: 1)
        )
    }

    private func formatDoseAmount(_ amount: Double) -> String {
        amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", amount) : String(format: "%.1f", amount)
    }
}
