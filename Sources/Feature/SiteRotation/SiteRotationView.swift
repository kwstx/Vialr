import SwiftUI
import Domain
import DesignSystem
import CalculationEngine

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
                        // 1. Hero Last / Next Site Pair Card
                        lastAndNextHeroCard

                        // 2. Rotation Strategy Selector Card
                        strategySelectorCard

                        // 3. Anatomical Body Map Card
                        BodyMapSelectorView(
                            sites: viewModel.siteSelectionItems,
                            selectedSiteId: $viewModel.selectedSiteId,
                            lastSiteId: viewModel.lastSite?.id,
                            nextSiteId: viewModel.nextSite?.id
                        )

                        // 4. Selected Site Details & Tissue Health
                        if let selectedStatus = viewModel.selectedSiteStatus {
                            siteDetailCard(selectedStatus)
                        }

                        // 5. Protocol-Independent Injection History Log
                        longitudinalHistorySection
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

    // MARK: - 1. Hero Last & Next Pair Card

    private var lastAndNextHeroCard: some View {
        VStack(spacing: VialrSpacing.md) {
            HStack(spacing: VialrSpacing.md) {
                // Last Injected Site
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(VialrColors.accentAmber)
                            .frame(width: 6, height: 6)
                        Text("LAST")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentAmber)
                    }

                    Text(viewModel.lastSite?.conciseDescription ?? "No History")
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    if let lastDate = viewModel.lastEvent?.timestamp {
                        Text(lastDate.formatted(date: .abbreviated, time: .omitted))
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    } else {
                        Text("Ready for first dose")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(VialrSpacing.sm)
                .background(VialrColors.cardSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous))

                // Next Target Site
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(VialrColors.accentVitality)
                            .frame(width: 6, height: 6)
                        Text("NEXT")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentVitality)
                    }

                    Text(viewModel.nextSite?.conciseDescription ?? "Right abdomen")
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.accentVitality)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text("Enforcing pattern")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(VialrSpacing.sm)
                .background(VialrColors.cardSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous)
                        .stroke(VialrColors.accentVitality.opacity(0.4), lineWidth: 1.5)
                )
            }

            if !viewModel.strategyReason.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(VialrColors.accentTeal)
                    Text(viewModel.strategyReason)
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    // MARK: - 2. Strategy Selector Card

    private var strategySelectorCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROTATION STRATEGY")
                        .vialrEyebrow()
                    Text("Enforced Pattern")
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                }
                Spacer()

                Menu {
                    ForEach(SiteRotationStrategy.allCases) { strategy in
                        Button {
                            viewModel.setStrategy(strategy)
                            VialrHaptics.selectionChanged()
                        } label: {
                            HStack {
                                Text(strategy.displayName)
                                if viewModel.selectedStrategy == strategy {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.selectedStrategy.systemImageName)
                        Text(viewModel.selectedStrategy.displayName)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                    }
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(VialrColors.accentTeal.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            Text(viewModel.selectedStrategy.descriptionText)
                .font(VialrTypography.caption)
                .foregroundColor(VialrColors.textTertiary)
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    // MARK: - 3. Site Detail Card

    private func siteDetailCard(_ status: SiteRotationStatus) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.site.name)
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                    Text("\(status.site.region.rawValue) • \(status.site.route.rawValue)")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                }

                Spacer()

                if status.isRecommended {
                    MetricBadge(.success("Target Candidate"))
                } else if status.isLastUsed {
                    MetricBadge(.neutral("Last Administered"))
                }
            }

            HStack(spacing: VialrSpacing.md) {
                metricBox(
                    title: "REST PERIOD",
                    value: status.daysSinceLastUse != nil ? "\(status.daysSinceLastUse!) Days" : "Never Used",
                    color: status.isFullyRested ? VialrColors.accentEmerald : VialrColors.accentAmber
                )

                metricBox(
                    title: "TOTAL DOSES",
                    value: "\(status.timesUsedTotal)",
                    color: VialrColors.accentTeal
                )

                metricBox(
                    title: "TISSUE HEALTH",
                    value: "\(Int(status.restingScore))%",
                    color: status.restingScore >= 80 ? VialrColors.accentEmerald : VialrColors.accentAmber
                )
            }

            if let reaction = status.activeReaction, reaction != .none {
                HStack(spacing: 6) {
                    Image(systemName: reaction.iconName)
                        .foregroundColor(VialrColors.accentRose)
                    Text("Last Recorded Reaction: \(reaction.rawValue)")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.accentRose)
                }
                .padding(8)
                .background(VialrColors.accentRose.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: VialrSpacing.radiusSm, style: .continuous))
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

    // MARK: - 4. Protocol-Independent Longitudinal History

    private var longitudinalHistorySection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LONGITUDINAL SITE HISTORY")
                        .vialrEyebrow()
                    Text("Preserved Across All Protocols")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                }
                Spacer()
            }

            if viewModel.siteEvents.isEmpty && viewModel.recentLogs.filter({ $0.status == .taken }).isEmpty {
                VialrEmptyStateView(
                    icon: "cross.circle",
                    title: "No Injections Recorded",
                    message: "Injection site history will be preserved longitudinally across all protocols once doses are logged."
                )
            } else if !viewModel.siteEvents.isEmpty {
                ForEach(viewModel.siteEvents.prefix(15)) { event in
                    HStack(spacing: VialrSpacing.sm) {
                        Image(systemName: "cross.circle.fill")
                            .foregroundColor(VialrColors.accentTeal)
                            .font(.system(size: 16))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.siteName)
                                .font(VialrTypography.bodyMedium)
                                .foregroundColor(VialrColors.textPrimary)
                            Text("\(event.compoundName) • \(String(format: "%.0f", event.doseAmount)) \(event.doseUnit.rawValue)")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)

                            let days = event.daysSinceAdministration
                            Text(days == 0 ? "Today" : "\(days)d ago")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(days >= 7 ? VialrColors.accentEmerald : VialrColors.accentAmber)
                        }
                    }
                    .padding(VialrSpacing.sm)
                    .vialrCard()
                }
            } else {
                ForEach(viewModel.recentLogs.filter { $0.status == .taken }.prefix(15)) { log in
                    HStack(spacing: VialrSpacing.sm) {
                        Image(systemName: "cross.circle.fill")
                            .foregroundColor(VialrColors.accentTeal)
                            .font(.system(size: 16))

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
}

