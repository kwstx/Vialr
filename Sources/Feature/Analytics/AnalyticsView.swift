import SwiftUI
import Charts
import Domain
import DesignSystem
import Analytics

public struct AnalyticsView: View {
    @Bindable public var viewModel: AnalyticsViewModel

    public init(viewModel: AnalyticsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

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
            .navigationBarHidden(true)
            .task {
                await viewModel.loadAnalytics()
            }
        }
    }

    // MARK: - Adherence Card
    private func adherenceSummaryCard(_ adh: AdherenceCalculator.AdherenceReport) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                Text("PROTOCOL ADHERENCE")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Spacer()
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
        .vialrCard()
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
                }
                Spacer()
                Text("BPC-157 (t½: 4h)")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            if !viewModel.clearanceData.isEmpty {
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

    // MARK: - Biomarkers Overview
    private var biomarkersOverviewSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("Latest Clinical Biomarkers")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)

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
            }
        }
    }

    // MARK: - Correlation Insights
    private var correlationInsightsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("Dose-to-Outcome Correlations")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)

            ForEach(viewModel.correlationInsights) { insight in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(VialrColors.accentTeal)
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
            }
        }
    }

    // MARK: - Spend Section
    private func spendAnalyticsSection(_ spend: CostAnalyticsEngine.SpendSummary) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("Financial & Protocol Cost")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)

            HStack(spacing: VialrSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TOTAL SPENT")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.textTertiary)
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
            .vialrCard()
        }
    }
}
