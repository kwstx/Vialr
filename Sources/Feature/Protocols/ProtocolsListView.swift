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

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Top Bar Actions
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PROTOCOLS")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.accentTeal)
                                Text("Protocols & Stacks")
                                    .font(VialrTypography.largeHero)
                                    .foregroundColor(VialrColors.textPrimary)
                            }

                            Spacer()

                            Button {
                                onCompareProtocols()
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(VialrColors.textPrimary)
                                    .frame(width: 44, height: 44)
                                    .background(VialrColors.cardSurfaceElevated)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(VialrColors.glassBorder, lineWidth: 1))
                            }

                            Button {
                                onCreateProtocol()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color.black)
                                    .frame(width: 44, height: 44)
                                    .background(VialrColors.accentTeal)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.top, VialrSpacing.sm)

                        // Filter Segmented Pill
                        VialrSegmentedControl(items: ProtocolFilter.allCases, selection: $viewModel.selectedFilter)

                        // Protocol List
                        if viewModel.filteredProtocols.isEmpty {
                            emptyProtocolsView
                        } else {
                            ForEach(viewModel.filteredProtocols) { proto in
                                protocolCard(proto)
                            }
                        }
                    }
                    .padding(.horizontal, VialrSpacing.md)
                    .padding(.bottom, 100)
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
            onSelectProtocol(proto)
        } label: {
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(proto.name)
                            .font(VialrTypography.title3)
                            .foregroundColor(VialrColors.textPrimary)

                        if !proto.goalSummary.isEmpty {
                            Text(proto.goalSummary)
                                .font(VialrTypography.subheadline)
                                .foregroundColor(VialrColors.textSecondary)
                        }
                    }

                    Spacer()

                    MetricBadge(proto.status == .active ? .success("Active") : .neutral(proto.status.rawValue))
                }

                // Compound schedule items
                VStack(spacing: 6) {
                    ForEach(proto.items) { item in
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(VialrColors.accentTeal)

                            Text(item.compoundName)
                                .font(VialrTypography.bodyMedium)
                                .foregroundColor(VialrColors.textPrimary)

                            Spacer()

                            Text("\(String(format: "%.0f", item.doseAmount)) \(item.doseUnit.rawValue)")
                                .font(VialrTypography.monoDose)
                                .foregroundColor(VialrColors.accentEmerald)

                            Text("• \(item.scheduleRule.description)")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(VialrSpacing.sm)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusSm)

                // Footer metadata
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(VialrColors.textTertiary)
                    Text("Started \(proto.startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(VialrColors.textTertiary)
                }
            }
            .padding(VialrSpacing.md)
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
                .font(.system(size: 44))
                .foregroundColor(VialrColors.textTertiary)
            Text("No Protocols in this category")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)
            Text("Create a new protocol or switch filters to view saved stacks.")
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)
                .multilineTextAlignment(.center)

            VialrButton("Create New Protocol", icon: "plus", style: .primary) {
                onCreateProtocol()
            }
            .frame(maxWidth: 240)
        }
        .padding(VialrSpacing.xxl)
        .frame(maxWidth: .infinity)
    }
}
