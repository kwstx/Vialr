import SwiftUI
import Domain
import DesignSystem

/// Main hub for managing clinical bloodwork, initiating manual entry,
/// uploading PDF reports, and tracking longitudinal biomarker trends.
public struct BloodworkHubView: View {
    @Bindable public var viewModel: BloodworkViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: BloodworkViewModel = BloodworkViewModel()) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Header Action Bar
                        headerActionSection

                        // Interactive Laboratory Timeline Banner
                        timelineBannerCard

                        // Summary KPI Metrics
                        overviewKpiCard

                        // Key Biomarker Trends Carousel
                        if !viewModel.keyBiomarkerCards.isEmpty {
                            keyBiomarkersCarousel
                        }

                        // Historical Lab Panels Section
                        panelsListSection
                    }
                    .padding(.horizontal, VialrSpacing.md)
                    .padding(.top, VialrSpacing.sm)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Bloodwork & Labs")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(VialrColors.accentTeal)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.isTimelineSheetPresented = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform.path.ecg")
                            Text("Timeline")
                        }
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    }
                }
            }
            .task {
                await viewModel.loadPanels()
            }
            .sheet(isPresented: $viewModel.isTimelineSheetPresented) {
                LaboratoryTimelineView()
            }
            .sheet(isPresented: $viewModel.isManualEntrySheetPresented) {
                ManualLabEntryView { newPanel in
                    Task {
                        await viewModel.saveConfirmedPanel(newPanel)
                    }
                }
            }
            .sheet(isPresented: $viewModel.isUploadSheetPresented) {
                LabDocumentUploadView { candidate in
                    viewModel.handleExtractedCandidate(candidate)
                }
            }
            .sheet(isPresented: $viewModel.isCandidateConfirmationPresented) {
                if let cand = viewModel.candidateReportToVerify {
                    LabCandidateConfirmationView(candidateReport: cand) { confirmedPanel in
                        Task {
                            await viewModel.saveConfirmedPanel(confirmedPanel)
                        }
                    }
                }
            }
            .sheet(item: $viewModel.selectedPanelForDetail) { panel in
                LabPanelDetailView(panel: panel) {
                    Task {
                        await viewModel.deletePanel(id: panel.id)
                    }
                }
            }
        }
    }

    // MARK: - Header Action Section
    private var headerActionSection: some View {
        HStack(spacing: 12) {
            // Manual Entry Action Button
            Button {
                viewModel.isManualEntrySheetPresented = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .bold))
                    Text("Manual Entry")
                        .font(VialrTypography.subheadlineBold)
                }
                .foregroundColor(VialrColors.backgroundPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(VialrColors.accentTeal)
                .cornerRadius(VialrSpacing.radiusMd)
            }
            .buttonStyle(.plain)

            // Upload PDF Report Action Button
            Button {
                viewModel.isUploadSheetPresented = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Upload PDF")
                        .font(VialrTypography.subheadlineBold)
                }
                .foregroundColor(VialrColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusMd)
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                        .stroke(VialrColors.accentTeal.opacity(0.6), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Interactive Laboratory Timeline Banner
    private var timelineBannerCard: some View {
        Button {
            viewModel.isTimelineSheetPresented = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [VialrColors.accentTeal, VialrColors.accentCyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(VialrColors.backgroundPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Interactive Laboratory Timeline")
                            .font(VialrTypography.subheadlineBold)
                            .foregroundColor(VialrColors.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(VialrColors.accentTeal)
                    }

                    Text("Align doses, protocol changes, and bloodwork on one chronological axis.")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(VialrSpacing.md)
            .background(
                LinearGradient(
                    colors: [VialrColors.cardSurfaceElevated, VialrColors.cardBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(VialrSpacing.radiusMd)
            .overlay(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                    .stroke(VialrColors.accentTeal.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overview KPI Card
    private var overviewKpiCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("LONGITUDINAL DIAGNOSTIC OVERVIEW")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            let totalAbnormal = viewModel.panels.reduce(0) { $0 + $1.abnormalResults.count }
            let latestDate = viewModel.panels.first?.collectionDate

            HStack(spacing: 12) {
                kpiBox(
                    title: "Diagnostic Panels",
                    value: "\(viewModel.panels.count)",
                    subtitle: "Tracked over time",
                    color: VialrColors.textPrimary
                )

                kpiBox(
                    title: "Last Blood Draw",
                    value: latestDate != nil ? formatShortDate(latestDate!) : "None",
                    subtitle: latestDate != nil ? formatDaysAgo(latestDate!) : "Ready to log",
                    color: VialrColors.accentTeal
                )

                kpiBox(
                    title: "Out of Bounds",
                    value: "\(totalAbnormal)",
                    subtitle: totalAbnormal == 0 ? "All Optimal" : "Attention needed",
                    color: totalAbnormal == 0 ? VialrColors.accentEmerald : VialrColors.accentRose
                )
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func kpiBox(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(VialrColors.textTertiary)
                .lineLimit(1)

            Text(value)
                .font(VialrTypography.title3)
                .foregroundColor(color)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(VialrColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusSm)
    }

    // MARK: - Key Biomarkers Carousel
    private var keyBiomarkersCarousel: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("KEY BIOMARKER SNAPSHOTS")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Spacer()
                Text("Latest vs Previous")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.keyBiomarkerCards) { card in
                        biomarkerSnapshotCard(card)
                    }
                }
            }
        }
    }

    private func biomarkerSnapshotCard(_ card: KeyBiomarkerSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: card.category.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(VialrColors.accentTeal)

                Text(card.name)
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(card.flag.rawValue)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(hex: card.flag.badgeColorHex))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(hex: card.flag.badgeColorHex).opacity(0.15))
                    .cornerRadius(3)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                let valStr = card.latestValue.truncatingRemainder(dividingBy: 1) == 0 ?
                    String(format: "%.0f", card.latestValue) : String(format: "%.1f", card.latestValue)

                Text(valStr)
                    .font(VialrTypography.monoDose)
                    .foregroundColor(Color(hex: card.flag.badgeColorHex))

                Text(card.unit)
                    .font(.system(size: 11))
                    .foregroundColor(VialrColors.textSecondary)

                Spacer()

                if let delta = card.deltaPercent {
                    HStack(spacing: 2) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9))
                        Text(String(format: "%.1f%%", abs(delta)))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(delta >= 0 ? VialrColors.accentTeal : VialrColors.accentViolet)
                }
            }

            if let min = card.referenceMin, let max = card.referenceMax {
                Text("Ref: \(formatNum(min)) – \(formatNum(max))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(VialrColors.textTertiary)
            }
        }
        .frame(width: 190)
        .padding(VialrSpacing.md)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                .stroke(VialrColors.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Panels List Section
    private var panelsListSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LABORATORY PANELS & DRAWS")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text("\(viewModel.panels.count) structured records")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                }
                Spacer()
            }

            if viewModel.panels.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(VialrColors.textTertiary)
                    Text("No Bloodwork Logged Yet")
                        .font(VialrTypography.subheadlineBold)
                        .foregroundColor(VialrColors.textSecondary)
                    Text("Use \"Manual Entry\" or \"Upload PDF\" to import and structure your laboratory reports.")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(VialrColors.cardSurfaceElevated.opacity(0.5))
                .cornerRadius(VialrSpacing.radiusMd)
            } else {
                ForEach(viewModel.panels) { panel in
                    Button {
                        viewModel.selectedPanelForDetail = panel
                    } label: {
                        panelCard(panel)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Panel Card
    private func panelCard(_ panel: LabPanel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(panel.labName.uppercased())
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.accentTeal)

                    Text(panel.panelName)
                        .font(VialrTypography.subheadlineBold)
                        .foregroundColor(VialrColors.textPrimary)
                }

                Spacer()

                // Draw Date Badge
                Text(formatShortDate(panel.collectionDate))
                    .font(VialrTypography.monoDose)
                    .foregroundColor(VialrColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VialrColors.cardBackground)
                    .cornerRadius(6)
            }

            // Preview Analytes Chips
            FlowLayout(spacing: 6) {
                ForEach(panel.results.prefix(4)) { res in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: res.flag.badgeColorHex))
                            .frame(width: 6, height: 6)
                        Text("\(res.biomarkerName): \(res.formattedValue)")
                            .font(.system(size: 10))
                            .foregroundColor(VialrColors.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VialrColors.cardBackground)
                    .cornerRadius(4)
                }

                if panel.results.count > 4 {
                    Text("+\(panel.results.count - 4) more")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(VialrColors.accentTeal)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(VialrColors.accentTeal.opacity(0.12))
                        .cornerRadius(4)
                }
            }

            Divider().background(VialrColors.glassBorder)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(VialrColors.accentEmerald)
                    Text("\(panel.results.count - panel.abnormalResults.count) Normal")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }

                if panel.hasAbnormalResults {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(VialrColors.accentRose)
                        Text("\(panel.abnormalResults.count) Out of Bounds")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.accentRose)
                    }
                    .padding(.leading, 8)
                }

                Spacer()

                HStack(spacing: 2) {
                    Text("View Analysis")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
        }
        .padding(VialrSpacing.md)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                .stroke(VialrColors.glassBorder, lineWidth: 1)
        )
    }

    private func formatShortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    private func formatDaysAgo(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }

    private func formatNum(_ val: Double) -> String {
        val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(format: "%.1f", val)
    }
}
