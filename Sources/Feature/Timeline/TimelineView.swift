import SwiftUI
import Domain
import DesignSystem
import CalculationEngine
import Data

/// Unified Longitudinal Health Timeline Screen.
/// Aggregates events across all domains (doses, laboratory diagnostics, biometric measurements,
/// protocol revisions, inventory movements, vial reconstitutions, symptoms, and documents),
/// sorted by timestamp and grouped into chronological calendar days.
public struct TimelineView: View {
    @Bindable public var viewModel: TimelineViewModel
    @Environment(\.dismiss) private var dismiss
    public var showCloseButton: Bool

    public init(
        viewModel: TimelineViewModel,
        showCloseButton: Bool = true
    ) {
        self.viewModel = viewModel
        self.showCloseButton = showCloseButton
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.dayGroups.isEmpty {
                    loadingView
                } else {
                    ScrollView {
                        VStack(spacing: VialrSpacing.md) {
                            // 1. Header & Time Range Controls
                            headerSection

                            // 2. Search & Category Filter Pills
                            filterSection

                            // 3. Longitudinal KPI Metric Summary Strip
                            summaryKpiSection

                            // 4. Chronological Day-Grouped Stream
                            if viewModel.dayGroups.isEmpty {
                                emptyStateView
                            } else {
                                dayGroupedStreamSection
                            }
                        }
                        .padding(.horizontal, VialrSpacing.screenHorizontal)
                        .padding(.top, VialrSpacing.xs)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("History Timeline")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if showCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(VialrColors.accentTeal)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.toggleHighlightedOnly()
                    } label: {
                        Image(systemName: viewModel.showHighlightedOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor(viewModel.showHighlightedOnly ? VialrColors.accentVitality : VialrColors.accentTeal)
                    }
                    .accessibilityLabel("Toggle Highlighted / Flagged Events Only")
                }
            }
            .task {
                await viewModel.loadTimelineData()
            }
            .sheet(item: $viewModel.selectedEvent) { event in
                TimelineEventDetailSheet(event: event)
            }
        }
    }

    // MARK: - 1. Header Section
    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("UNIFIED LONGITUDINAL STREAM")
                    .font(VialrTypography.eyebrow)
                    .foregroundColor(VialrColors.accentTeal)

                Text("All Activity")
                    .font(VialrTypography.largeHero)
                    .foregroundColor(VialrColors.textPrimary)
            }

            Spacer()

            // Time Range Selector
            HStack(spacing: 2) {
                ForEach(TimelineTimeRangeFilter.allCases) { range in
                    let isSel = viewModel.selectedTimeRange == range
                    Button {
                        viewModel.selectTimeRange(range)
                    } label: {
                        Text(range.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isSel ? VialrColors.backgroundPrimary : VialrColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(isSel ? VialrColors.accentTeal : Color.clear)
                            .cornerRadius(6)
                    }
                }
            }
            .padding(2)
            .background(VialrColors.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(VialrColors.glassBorder, lineWidth: 1)
            )
        }
        .padding(.top, VialrSpacing.xs)
    }

    // MARK: - 2. Filter & Search Section
    private var filterSection: some View {
        VStack(spacing: 10) {
            // Search Bar Input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(VialrColors.textTertiary)

                TextField("Search doses, biomarkers, notes...", text: $viewModel.searchQuery)
                    .font(VialrTypography.body)
                    .foregroundColor(VialrColors.textPrimary)
                    .submitLabel(.search)
                    .onSubmit {
                        viewModel.updateSearchQuery(viewModel.searchQuery)
                    }

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.updateSearchQuery("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(VialrColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VialrColors.cardSurfaceElevated)
            .cornerRadius(VialrSpacing.radiusSm)
            .overlay(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                    .stroke(VialrColors.glassBorder, lineWidth: 1)
            )

            // Category Filter Pills ScrollBar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "All" Pill
                    categoryPill(title: "All", category: nil, isSelected: viewModel.selectedCategory == nil)

                    // Individual Domain Categories
                    ForEach(TimelineCategory.allCases) { cat in
                        categoryPill(title: cat.shortName, category: cat, isSelected: viewModel.selectedCategory == cat)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func categoryPill(title: String, category: TimelineCategory?, isSelected: Bool) -> some View {
        Button {
            viewModel.selectCategory(category)
        } label: {
            HStack(spacing: 5) {
                if let cat = category {
                    Image(systemName: cat.iconName)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? VialrColors.backgroundPrimary : Color(hex: cat.badgeColorHex))
                }

                Text(title)
                    .font(VialrTypography.captionBold)
                    .foregroundColor(isSelected ? VialrColors.backgroundPrimary : VialrColors.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? VialrColors.accentTeal : VialrColors.cardBackground)
            .cornerRadius(VialrSpacing.radiusPill)
            .overlay(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusPill)
                    .stroke(isSelected ? Color.clear : VialrColors.glassBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - 3. Summary KPI Section
    private var summaryKpiSection: some View {
        HStack(spacing: VialrSpacing.sm) {
            kpiCard(
                title: "TOTAL EVENTS",
                value: "\(viewModel.statistics.totalEventsCount)",
                sub: "\(viewModel.dayGroups.count) Active Days",
                icon: "clock.arrow.circlepath",
                color: VialrColors.accentTeal
            )

            if viewModel.statistics.totalDosesCount > 0 {
                let adhStr = viewModel.statistics.adherenceScore.map { "\(Int($0))%" } ?? "—"
                kpiCard(
                    title: "DOSES LOGGED",
                    value: "\(viewModel.statistics.takenDosesCount)/\(viewModel.statistics.totalDosesCount)",
                    sub: "\(adhStr) Adherence",
                    icon: "syringe.fill",
                    color: VialrColors.accentEmerald
                )
            }

            if viewModel.statistics.totalLabPanelsCount > 0 {
                kpiCard(
                    title: "LAB PANELS",
                    value: "\(viewModel.statistics.totalLabPanelsCount)",
                    sub: viewModel.statistics.abnormalLabCount > 0 ? "\(viewModel.statistics.abnormalLabCount) Flagged" : "All Normal",
                    icon: "testtube.2",
                    color: VialrColors.accentRose
                )
            } else if viewModel.statistics.totalMeasurementsCount > 0 {
                kpiCard(
                    title: "MEASUREMENTS",
                    value: "\(viewModel.statistics.totalMeasurementsCount)",
                    sub: "Biometrics",
                    icon: "waveform.path.ecg",
                    color: VialrColors.accentCyan
                )
            }
        }
    }

    private func kpiCard(title: String, value: String, sub: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(VialrColors.textTertiary)
            }
            Text(value)
                .font(VialrTypography.subheadlineBold)
                .foregroundColor(VialrColors.textPrimary)
                .lineLimit(1)
            Text(sub)
                .font(.system(size: 9))
                .foregroundColor(VialrColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vialrCard()
    }

    // MARK: - 4. Day-Grouped Chronological Stream
    private var dayGroupedStreamSection: some View {
        LazyVStack(spacing: VialrSpacing.lg, pinnedViews: [.sectionHeaders]) {
            ForEach(viewModel.dayGroups) { dayGroup in
                Section {
                    VStack(spacing: 0) {
                        ForEach(Array(dayGroup.events.enumerated()), id: \.element.id) { index, event in
                            timelineEventRow(
                                event: event,
                                isFirst: index == 0,
                                isLast: index == dayGroup.events.count - 1
                            )
                        }
                    }
                } header: {
                    daySectionHeader(dayGroup)
                }
            }
        }
    }

    // MARK: - Day Section Header
    private func daySectionHeader(_ dayGroup: TimelineDayGroup) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(dayGroup.formattedDayTitle)
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)

                    if dayGroup.hasHighlightedEvents {
                        Circle()
                            .fill(VialrColors.accentAmber)
                            .frame(width: 6, height: 6)
                    }
                }

                Text(dayGroup.formattedDaySubtitle)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            Spacer()

            if !dayGroup.summaryText.isEmpty {
                Text(dayGroup.summaryText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(VialrColors.accentTeal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VialrColors.cardSurfaceElevated)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VialrColors.glassBorder, lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .background(VialrColors.backgroundPrimary)
    }

    // MARK: - Timeline Event Row with Vertical Track
    private func timelineEventRow(event: TimelineEvent, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Left Node & Vertical Connector Line
            VStack(spacing: 0) {
                // Top line segment
                Rectangle()
                    .fill(isFirst ? Color.clear : VialrColors.glassBorder)
                    .frame(width: 2, height: 10)

                // Category Indicator Circle Node
                ZStack {
                    Circle()
                        .fill(Color(hex: event.badgeColorHex).opacity(0.2))
                        .frame(width: 22, height: 22)

                    Circle()
                        .fill(Color(hex: event.badgeColorHex))
                        .frame(width: 10, height: 10)
                }

                // Bottom line segment
                Rectangle()
                    .fill(isLast ? Color.clear : VialrColors.glassBorder)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 22)

            // Right Event Content Card
            Button {
                viewModel.selectEvent(event)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    // Title, Category, and Timestamp Header
                    HStack(alignment: .top) {
                        HStack(spacing: 6) {
                            Image(systemName: event.iconName)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: event.badgeColorHex))

                            Text(event.title)
                                .font(VialrTypography.subheadlineBold)
                                .foregroundColor(VialrColors.textPrimary)
                        }

                        Spacer()

                        Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(VialrColors.textTertiary)
                    }

                    // Subtitle
                    Text(event.subtitle)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)

                    // Detail or Clinical Notes Snippet
                    if let detail = event.detailText, !detail.isEmpty {
                        Text(detail)
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }

                    // Status Badge Footer
                    if let badge = event.badgeText {
                        HStack {
                            MetricBadge(.custom(
                                title: badge,
                                color: Color(hex: event.badgeColorHex),
                                icon: nil
                            ))

                            Spacer()

                            if event.isHighlighted {
                                Text("Flagged")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(VialrColors.accentRose)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(12)
                .vialrCard()
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Loading & Empty States
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(VialrColors.accentTeal)
            Text("Aggregating Unified Health Timeline...")
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)
        }
    }

    private var emptyStateView: some View {
        VialrEmptyStateView(
            iconName: "clock.badge.exclamationmark",
            title: "No Matching Timeline Events",
            message: "No events were found matching the selected category and time filters."
        )
        .padding(.vertical, 40)
    }
}
