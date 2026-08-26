import SwiftUI
import Charts
import Domain
import DesignSystem
import Analytics

public enum AnalyticsSubTab: String, CaseIterable, Identifiable {
    case results = "Results Tracking"
    case intelligence = "Intelligence & PK"

    public var id: String { rawValue }
}

public struct AnalyticsView: View {
    @Bindable public var viewModel: AnalyticsViewModel
    @State private var selectedSubTab: AnalyticsSubTab = .results
    @State private var resultsViewModel = ResultsTrackingViewModel()
    @State private var isLabTimelinePresented: Bool = false

    public init(viewModel: AnalyticsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented Sub-Tab Switcher
                    HStack(spacing: 6) {
                        ForEach(AnalyticsSubTab.allCases) { tab in
                            let isSel = selectedSubTab == tab
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedSubTab = tab
                                }
                            } label: {
                                Text(tab.rawValue)
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(isSel ? VialrColors.backgroundPrimary : VialrColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .frame(minHeight: VialrSpacing.minTouchTarget)
                                    .background(isSel ? VialrColors.accentTeal : Color.clear)
                                    .cornerRadius(8)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel(tab.rawValue)
                            .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : .isButton)
                            .accessibilityHint("Double tap to switch to \(tab.rawValue)")
                        }
                    }
                    .padding(4)
                    .background(VialrColors.cardSurface)
                    .cornerRadius(10)
                    .padding(.horizontal, VialrSpacing.md)
                    .padding(.top, VialrSpacing.xs)
                    .padding(.bottom, VialrSpacing.sm)

                    if selectedSubTab == .results {
                        ResultsTrackingView(viewModel: resultsViewModel)
                    } else {
                        ScrollView {
                            VStack(spacing: VialrSpacing.lg) {
                                // Header
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("INTELLIGENCE & TRENDS")
                                            .font(VialrTypography.captionBold)
                                            .foregroundColor(VialrColors.accentTeal)
                                        Text("Analytics & Insights")
                                            .font(VialrTypography.largeHero)
                                            .foregroundColor(VialrColors.textPrimary)
                                            .accessibilityAddTraits(.isHeader)
                                    }
                                    Spacer()
                                }
                                .padding(.top, VialrSpacing.sm)

                                // Adherence Summary Card
                                if let adh = viewModel.adherenceReport {
                                    adherenceSummaryCard(adh)
                                }

                                // Pharmacokinetic Serum Half-Life Clearance Chart
                                serumClearanceChartSection

                                // Biomarkers Chart
                                biomarkersOverviewSection

                                // AI Correlation Insights
                                if !viewModel.correlationInsights.isEmpty {
                                    correlationInsightsSection
                                }

                                // Financial Cost Burn Rate
                                if let spend = viewModel.spendSummary {
                                    spendAnalyticsSection(spend)
                                }
                            }
                            .padding(.horizontal, VialrSpacing.md)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadAnalytics()
            }
            .sheet(isPresented: $isLabTimelinePresented) {
                LaboratoryTimelineView()
            }
            .sheet(isPresented: $viewModel.isExplainabilitySheetPresented) {
                if let audit = viewModel.selectedAuditTrail {
                    ExplainabilityInspectionSheet(auditTrail: audit)
                }
            }
        }
    }

    // MARK: - Adherence Card
    private func adherenceSummaryCard(_ adh: AdherenceCalculator.AdherenceReport) -> some View {
        Button {
            if let audit = viewModel.explainableAdherence?.auditTrail {
                viewModel.presentAuditTrail(audit)
            }
        } label: {
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                HStack {
                    Text("PROTOCOL ADHERENCE")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Spacer()
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(VialrColors.accentTeal)
                    MetricBadge(.success("\(Int(adh.overallPercentage))% Compliance"))
                }

                HStack(spacing: VialrSpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACTIVE STREAK")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textTertiary)
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(VialrColors.accentEmerald)
                            Text("\(adh.currentStreakDays) Days")
                                .font(VialrTypography.metricMedium)
                                .foregroundColor(VialrColors.textPrimary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("TAKEN / SCHEDULED")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textTertiary)
                        Text("\(adh.totalTaken) of \(adh.totalScheduled)")
                            .font(VialrTypography.metricSmall)
                            .foregroundColor(VialrColors.accentCyan)
                    }
                }
            }
            .padding(VialrSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .vialrCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Protocol Adherence: \(Int(adh.overallPercentage)) percent compliance")
        .accessibilityValue("Active streak: \(adh.currentStreakDays) days. \(adh.totalTaken) of \(adh.totalScheduled) doses taken.")
        .accessibilityHint("Double tap to inspect step-by-step mathematical audit trace")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Serum Clearance Chart
    private var serumClearanceChartSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PHARMACOKINETICS")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text("Active Serum Concentration")
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer()
                Text("BPC-157 (t½: 4h)")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            if !viewModel.clearanceData.isEmpty {
                AccessibleChartContainer(summary: clearanceChartSummary) {
                    Chart {
                        ForEach(viewModel.clearanceData) { point in
                            AreaMark(
                                x: .value("Time", point.date),
                                y: .value("Serum Level (mg)", point.activeLevelMg)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [VialrColors.accentTeal.opacity(0.4), VialrColors.accentTeal.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("Serum Level (mg)", point.activeLevelMg)
                            )
                            .foregroundStyle(VialrColors.accentTeal)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .accessibilityLabel("Time: \(point.date.formatted(date: .abbreviated, time: .shortened))")
                            .accessibilityValue("Serum level: \(String(format: "%.3f", point.activeLevelMg)) mg")
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine().foregroundStyle(VialrColors.glassBorder)
                            AxisValueLabel().foregroundStyle(VialrColors.textTertiary)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisGridLine().foregroundStyle(VialrColors.glassBorder)
                            AxisValueLabel(format: .dateTime.day().month()).foregroundStyle(VialrColors.textTertiary)
                        }
                    }
                    .frame(height: 180)
                    .padding(.top, 8)
                }
            } else {
                Text("No dose history available to plot clearance curve.")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textTertiary)
                    .frame(height: 120)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private var clearanceChartSummary: ChartDataSummary {
        let points = viewModel.clearanceData
        let values = points.map(\.activeLevelMg)
        let minV = values.min()
        let maxV = values.max()
        let avgV = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        let curV = values.last

        return ChartDataSummary(
            title: "Serum Clearance & Pharmacokinetics Curve",
            metricUnit: "mg",
            totalDataPoints: points.count,
            minimumValue: minV,
            maximumValue: maxV,
            averageValue: avgV,
            currentValue: curV,
            trendDirectionDescription: (curV ?? 0) > (avgV ?? 0) ? "Active clearance phase with elevated serum level" : "Clearance nearing baseline elimination",
            keyObservations: [
                "Compound modeled: BPC-157 with 4-hour half-life elimination kinetics",
                "Peak serum level observed: \(String(format: "%.2f", maxV ?? 0)) mg",
                "Current circulating concentration: \(String(format: "%.2f", curV ?? 0)) mg"
            ]
        )
    }

    // MARK: - Biomarkers Overview
    private var biomarkersOverviewSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("Latest Clinical Biomarkers")
                    .font(VialrTypography.title3)
                    .foregroundColor(VialrColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    isLabTimelinePresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                        Text("Timeline")
                    }
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                    .frame(minHeight: VialrSpacing.minTouchTarget)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Open Laboratory Timeline View")
                .accessibilityHint("Double tap to inspect aligned longitudinal biomarker trends")
            }

            ForEach(viewModel.biomarkers) { marker in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(marker.name)
                            .font(VialrTypography.bodyMedium)
                            .foregroundColor(VialrColors.textPrimary)

                        if let min = marker.referenceRangeMin, let max = marker.referenceRangeMax {
                            Text("Ref: \(String(format: "%.0f", min))–\(String(format: "%.0f", max)) \(marker.unit)")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("\(String(format: "%.1f", marker.value))")
                                .font(VialrTypography.metricSmall)
                                .foregroundColor(Color(hex: marker.status.colorHex))
                            Text(marker.unit)
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textSecondary)
                        }
                        MetricBadge(.custom(title: marker.status.rawValue, color: Color(hex: marker.status.colorHex), icon: nil))
                    }
                }
                .padding(VialrSpacing.sm)
                .vialrCard()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Biomarker: \(marker.name)")
                .accessibilityValue("Value: \(String(format: "%.1f", marker.value)) \(marker.unit). Status: \(marker.status.rawValue). \(marker.referenceRangeMin != nil ? "Reference range: \(String(format: "%.0f", marker.referenceRangeMin!)) to \(String(format: "%.0f", marker.referenceRangeMax!)) \(marker.unit)" : "")")
            }
        }
    }

    // MARK: - Correlation Insights
    private var correlationInsightsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("Dose-to-Outcome Correlations")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            ForEach(viewModel.correlationInsights) { insight in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(VialrColors.accentTeal)
                            .accessibilityHidden(true)
                        Text(insight.title)
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)
                        Spacer()
                        Text("\(Int(insight.confidenceScore * 100))% Match")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentEmerald)
                    }

                    Text(insight.summary)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .padding(VialrSpacing.md)
                .vialrCard()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Insight: \(insight.title)")
                .accessibilityValue("\(insight.summary). Confidence score: \(Int(insight.confidenceScore * 100)) percent.")
            }
        }
    }

    // MARK: - Spend Section
    private func spendAnalyticsSection(_ spend: CostAnalyticsEngine.SpendSummary) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("Financial & Protocol Cost")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Button {
                if let audit = viewModel.explainableSpend?.auditTrail {
                    viewModel.presentAuditTrail(audit)
                }
            } label: {
                HStack(spacing: VialrSpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("TOTAL SPENT")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.textTertiary)
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundColor(VialrColors.accentTeal)
                        }
                        Text("$\(String(format: "%.0f", spend.totalSpentUsd))")
                            .font(VialrTypography.metricMedium)
                            .foregroundColor(VialrColors.accentEmerald)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("DAILY PROTOCOL BURN")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textTertiary)
                        Text("$\(String(format: "%.2f", spend.costPerDayUsd))/day")
                            .font(VialrTypography.metricSmall)
                            .foregroundColor(VialrColors.textPrimary)
                    }
                }
                .padding(VialrSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .vialrCard()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Financial Cost: Total spent $\(String(format: "%.0f", spend.totalSpentUsd))")
            .accessibilityValue("Daily protocol burn rate: $\(String(format: "%.2f", spend.costPerDayUsd)) per day")
            .accessibilityHint("Double tap to inspect financial cost derivation audit")
            .accessibilityAddTraits(.isButton)
        }
    }
}
