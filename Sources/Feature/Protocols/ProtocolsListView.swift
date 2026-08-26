import SwiftUI
import Domain
import DesignSystem

public struct ProtocolsListView: View {
    @Bindable public var viewModel: ProtocolsViewModel
    public var onSelectProtocol: (ProtocolModel) -> Void
    public var onCreateProtocol: () -> Void
    public var onCompareProtocols: () -> Void
    public var onReplayProtocol: ((ProtocolModel) -> Void)?

    public init(
        viewModel: ProtocolsViewModel,
        onSelectProtocol: @escaping (ProtocolModel) -> Void,
        onCreateProtocol: @escaping () -> Void,
        onCompareProtocols: @escaping () -> Void,
        onReplayProtocol: ((ProtocolModel) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onSelectProtocol = onSelectProtocol
        self.onCreateProtocol = onCreateProtocol
        self.onCompareProtocols = onCompareProtocols
        self.onReplayProtocol = onReplayProtocol
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: VialrSpacing.lg) {
                        // Top Bar Actions
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PROTOCOLS")
                                    .vialrEyebrow()
                                Text("Protocols & Stacks")
                                    .font(VialrTypography.largeHero)
                                    .foregroundColor(VialrColors.textPrimary)
                                    .tracking(-0.5)
                            }

                            Spacer()

                            Button {
                                VialrHaptics.lightImpact()
                                onCompareProtocols()
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(VialrColors.textPrimary)
                                    .frame(width: 40, height: 40)
                                    .background(VialrColors.cardSurfaceElevated)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(VialrColors.glassBorder, lineWidth: 1))
                            }
                            .accessibilityLabel("Compare Protocols")

                            Button {
                                VialrHaptics.mediumImpact()
                                onCreateProtocol()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Color.black)
                                    .frame(width: 40, height: 40)
                                    .background(VialrColors.accentVitality)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Create New Protocol")
                        }
                        .padding(.top, VialrSpacing.xs)

                        // Filter Segmented Pill
                        VialrSegmentedControl(items: ProtocolFilter.allCases, selection: $viewModel.selectedFilter)

                        // Protocol List
                        if viewModel.filteredProtocols.isEmpty {
                            emptyProtocolsView
                        } else {
                            VStack(spacing: VialrSpacing.sm) {
                                ForEach(viewModel.filteredProtocols) { proto in
                                    protocolCard(proto)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, VialrSpacing.screenHorizontal)
                    .padding(.bottom, 110)
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadProtocols()
            }
        }
    }

    private func protocolCard(_ proto: ProtocolModel) -> some View {
        Button {
            VialrHaptics.lightImpact()
            onSelectProtocol(proto)
        } label: {
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(proto.name)
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)

                        if !proto.goalSummary.isEmpty {
                            Text(proto.goalSummary)
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    MetricBadge(proto.status == .active ? .success("Active") : .neutral(proto.status.rawValue))
                }

                // Compound schedule items
                VStack(spacing: 6) {
                    ForEach(proto.items) { item in
                        HStack {
                            Circle()
                                .fill(VialrColors.accentVitality)
                                .frame(width: 6, height: 6)

                            Text(item.compoundName)
                                .font(VialrTypography.footnote)
                                .foregroundColor(VialrColors.textPrimary)

                            Spacer()

                            Text("\(String(format: "%.0f", item.doseAmount)) \(item.doseUnit.rawValue)")
                                .font(VialrTypography.monoDose)
                                .foregroundColor(VialrColors.accentVitality)

                            Text("• \(item.scheduleRule.description)")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                        }
                        .padding(.vertical, 3)
                    }
                }
                .padding(VialrSpacing.sm)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusSm)

                // Footer metadata
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(VialrColors.textTertiary)
                    Text("Started \(proto.startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(VialrColors.textTertiary)
                }
            }
            .padding(VialrSpacing.cardPadding)
            .vialrCard()
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onReplay = onReplayProtocol {
                Button {
                    onReplay(proto)
                } label: {
                    Label("Watch Protocol Replay", systemImage: "play.circle.fill")
                }
            }

            Button {
                onSelectProtocol(proto)
            } label: {
                Label("View Protocol Details", systemImage: "info.circle")
            }
        }
    }

    private var emptyProtocolsView: some View {
        VStack(spacing: VialrSpacing.md) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 36))
                .foregroundColor(VialrColors.textTertiary)
            Text("No Protocols in this category")
                .font(VialrTypography.headline)
                .foregroundColor(VialrColors.textPrimary)
            Text("Create a new protocol or switch filters to view saved stacks.")
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)
                .multilineTextAlignment(.center)

            VialrButton("Create New Protocol", icon: "plus", style: .vitality, size: .compact) {
                onCreateProtocol()
            }
            .frame(maxWidth: 220)
        }
        .padding(VialrSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}
