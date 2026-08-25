import SwiftUI
import Domain
import DesignSystem

public struct SiteRotationView: View {
    @Bindable public var viewModel: SiteRotationViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: SiteRotationViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Anatomical Body Map Card
                        BodyMapSelectorView(
                            sites: viewModel.siteSelectionItems,
                            selectedSiteId: $viewModel.selectedSiteId
                        )

                        // Site Details Card
                        if let selectedId = viewModel.selectedSiteId,
                           let status = viewModel.siteStatuses.first(where: { $0.site.id == selectedId }) {
                            siteDetailCard(status)
                        }

                        // Rotation History Log
                        historySection
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("Site Rotation Map")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
            .task {
                await viewModel.loadSiteData()
            }
        }
    }

    private func siteDetailCard(_ status: SiteRotationEngine.SiteStatus) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text(status.site.name)
                    .font(VialrTypography.title3)
                    .foregroundColor(VialrColors.textPrimary)
                Spacer()
                if status.isRecommended {
                    MetricBadge(.success("Recommended Target"))
                }
            }

            HStack(spacing: VialrSpacing.md) {
                metricBox(
                    title: "REST TIME",
                    value: status.daysSinceLastUse != nil ? "\(status.daysSinceLastUse!) Days" : "Never Used",
                    color: VialrColors.accentEmerald
                )

                metricBox(
                    title: "TOTAL INJECTIONS",
                    value: "\(status.timesUsedTotal)",
                    color: VialrColors.accentTeal
                )

                metricBox(
                    title: "TISSUE RECOVERY",
                    value: "\(Int(status.restingScore))%",
                    color: status.restingScore >= 80 ? VialrColors.accentEmerald : VialrColors.accentAmber
                )
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func metricBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.textTertiary)
            Text(value)
                .font(VialrTypography.metricSmall)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("Previous Injection Locations")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)

            ForEach(viewModel.recentLogs.filter { $0.status == .taken }) { log in
                HStack {
                    Image(systemName: "cross.circle.fill")
                        .foregroundColor(VialrColors.accentTeal)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.injectionSiteName ?? "Injection Site")
                            .font(VialrTypography.bodyMedium)
                            .foregroundColor(VialrColors.textPrimary)
                        Text(log.compoundName)
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)
                    }

                    Spacer()

                    if let d = log.loggedDate ?? Optional(log.scheduledDate) {
                        Text(d.formatted(date: .abbreviated, time: .shortened))
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }
                }
                .padding(VialrSpacing.sm)
                .vialrCard()
            }
        }
    }
}
