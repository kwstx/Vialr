import SwiftUI
import Charts
import Domain
import DesignSystem
import Analytics

public struct ResultsTrackingView: View {
    @Bindable public var viewModel: ResultsTrackingViewModel

    public init(viewModel: ResultsTrackingViewModel) {
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
                        headerSection

                        // Horizontal Metric Selector Carousel
                        metricSelectorCarousel

                        if let summary = viewModel.analyticsSummary {
                            // Hero Summary Card
                            heroMetricCard(summary)

                            // Interactive Time Series & Moving Average Chart
                            interactiveChartSection(summary)

                            // Derived Analytics: Moving Averages & Velocity
                            movingAverageVelocitySection(summary)

                            // Derived Analytics: Standard Period Percentage Changes
                            percentageChangesSection(summary)

                            // Derived Analytics: Adherence Correlation
                            if let adh = summary.adherenceRelationship {
                                adherenceRelationshipSection(adh)
                            }

                            // Derived Analytics: Protocol-Period Comparisons
                            if !summary.protocolComparisons.isEmpty {
                                protocolComparisonsSection(summary.protocolComparisons)
                            }

                            // Raw Measurement Audit Ledger
                            rawMeasurementsLedgerSection(summary)
                        } else if viewModel.isLoading {
                            ProgressView()
                                .tint(VialrColors.accentTeal)
                                .padding(.top, 40)
                        } else {
                            VialrEmptyStateView(
                                iconName: "chart.xyaxis.line",
                                title: "No Measurements Logged",
                                message: "Start tracking generic time-series data for this metric to calculate moving averages and protocol outcomes.",
                                actionTitle: "Log First Measurement"
                            ) {
                                viewModel.isLogMeasurementSheetPresented = true
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, VialrSpacing.md)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $viewModel.isLogMeasurementSheetPresented) {
                if let metric = viewModel.selectedMetric {
                    LogMeasurementSheetView(metric: metric, protocols: viewModel.activeProtocols) { val, secVal, unit, dt, src, protoId, notes in
                        Task {
                            await viewModel.logMeasurement(
                                value: val,
                                secondaryValue: secVal,
                                unit: unit,
                                date: dt,
                                source: src,
                                protocolId: protoId,
                                notes: notes
                            )
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.isCreateCustomMetricSheetPresented) {
                CreateCustomMetricSheetView { name, cat, unit, minV, maxV, dir, icon, color, desc in
                    Task {
                        await viewModel.createCustomMetric(
                            name: name,
                            category: cat,
                            unit: unit,
                            referenceRangeMin: minV,
                            referenceRangeMax: maxV,
                            targetDirection: dir,
                            iconName: icon,
                            colorHex: color,
                            description: desc
                        )
                    }
                }
            }
            .sheet(isPresented: $viewModel.isExplainabilitySheetPresented) {
                if let audit = viewModel.selectedAuditTrail {
                    ExplainabilityInspectionSheet(auditTrail: audit)
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - 1. Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("LONGITUDINAL BIOMARKERS")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Text("Results Tracking")
                    .font(VialrTypography.largeHero)
                    .foregroundColor(VialrColors.textPrimary)
            }
            Spacer()

            HStack(spacing: VialrSpacing.sm) {
                Button {
                    viewModel.isCreateCustomMetricSheetPresented = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(VialrColors.textSecondary)
                }

                Button {
                    viewModel.isLogMeasurementSheetPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Log")
                    }
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.backgroundPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(VialrColors.accentTeal)
                    .cornerRadius(20)
                }
            }
        }
        .padding(.top, VialrSpacing.sm)
    }

    // MARK: - 2. Metric Selector Carousel
    private var metricSelectorCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VialrSpacing.sm) {
                ForEach(viewModel.metricDefinitions) { metric in
                    let isSelected = viewModel.selectedMetric?.id == metric.id
                    Button {
                        Task {
                            await viewModel.selectMetric(metric)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: metric.iconName)
                                .foregroundColor(isSelected ? VialrColors.backgroundPrimary : Color(hex: metric.colorHex))
                                .font(.system(size: 14, weight: .semibold))

                            Text(metric.name)
                                .font(VialrTypography.captionBold)
                                .foregroundColor(isSelected ? VialrColors.backgroundPrimary : VialrColors.textPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isSelected ? VialrColors.textPrimary : VialrColors.cardBackground)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isSelected ? Color.clear : VialrColors.glassBorder, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 3. Hero Metric Card
    private func heroMetricCard(_ summary: ComprehensiveMetricAnalytics) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.definition.category.rawValue.uppercased())
                        .font(VialrTypography.captionBold)
                        .foregroundColor(Color(hex: summary.definition.colorHex))
                    Text(summary.definition.name)
                        .font(VialrTypography.title2)
                        .foregroundColor(VialrColors.textPrimary)
                }
                Spacer()

                if let latest = summary.rawTimeSeries.latestPoint {
                    MetricBadge(.custom(
                        title: latest.status.rawValue,
                        color: Color(hex: latest.status.colorHex),
                        icon: nil
                    ))
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                if let latest = summary.rawTimeSeries.latestPoint {
                    Text(String(format: summary.definition.decimalPlaces == 0 ? "%.0f" : "%.1f", latest.value))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(VialrColors.textPrimary)

                    if let sec = latest.secondaryValue {
                        Text("/ \(Int(sec))")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundColor(VialrColors.textSecondary)
                    }

                    Text(summary.definition.defaultUnit)
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textSecondary)
                } else {
                    Text("—")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(VialrColors.textTertiary)
                }

                Spacer()

                if let base = summary.baselineResult {
                    Button {
                        if let audit = viewModel.masterReport?.baselineDifference?.auditTrail {
                            viewModel.presentAuditTrail(audit)
                        }
                    } label: {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("FROM BASELINE")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textTertiary)
                                Image(systemName: "info.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(VialrColors.accentTeal)
                            }

                            let sign = base.absoluteDifference > 0 ? "+" : ""
                            Text("\(sign)\(String(format: "%.1f", base.absoluteDifference)) \(summary.definition.defaultUnit) (\(sign)\(String(format: "%.1f", base.percentageDifference))%)")
                                .font(VialrTypography.bodyBold)
                                .foregroundColor(base.evaluationStatus == .onTrack || base.evaluationStatus == .targetReached ? VialrColors.accentEmerald : VialrColors.accentRose)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if let base = summary.baselineResult {
                Divider().background(VialrColors.glassBorder)

                HStack(spacing: VialrSpacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BASELINE START")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textTertiary)
                        Text("\(String(format: "%.1f", base.baselineValue)) \(summary.definition.defaultUnit)")
                            .font(VialrTypography.footnote)
                            .foregroundColor(VialrColors.textPrimary)
                    }

                    if let target = base.targetValue {
                        Spacer()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TARGET GOAL")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.textTertiary)
                            Text("\(String(format: "%.1f", target)) \(summary.definition.defaultUnit)")
                                .font(VialrTypography.footnote)
                                .foregroundColor(VialrColors.accentTeal)
                        }
                    }

                    if let vel = summary.rawTimeSeries.weeklyVelocity {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("WEEKLY VELOCITY")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.textTertiary)
                            let sign = vel > 0 ? "+" : ""
                            Text("\(sign)\(String(format: "%.1f", vel)) \(summary.definition.defaultUnit)/wk")
                                .font(VialrTypography.footnote)
                                .foregroundColor(VialrColors.accentCyan)
                        }
                    }
                }
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - 4. Interactive Time Series & Moving Average Chart
    private func interactiveChartSection(_ summary: ComprehensiveMetricAnalytics) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            // Chart Controls
            HStack {
                // Time Range Filter
                HStack(spacing: 4) {
                    ForEach(TimeRangeFilter.allCases) { r in
                        let isSel = viewModel.selectedTimeRange == r
                        Button {
                            viewModel.selectedTimeRange = r
                            Task { await viewModel.refreshSelectedMetricAnalytics() }
                        } label: {
                            Text(r.rawValue)
                                .font(VialrTypography.captionBold)
                                .foregroundColor(isSel ? VialrColors.backgroundPrimary : VialrColors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isSel ? VialrColors.accentTeal : Color.clear)
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(4)
                .background(VialrColors.surfacePrimary)
                .cornerRadius(8)

                Spacer()

                // Moving Average Selector
                Menu {
                    ForEach(MovingAverageOverlayOption.allCases) { opt in
                        Button(opt.rawValue) {
                            viewModel.selectedMovingAverage = opt
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path")
                        Text(viewModel.selectedMovingAverage.rawValue)
                    }
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(VialrColors.surfacePrimary)
                    .cornerRadius(8)
                }
            }

            // SwiftUI Chart
            if !summary.rawTimeSeries.isEmpty {
                Chart {
                    // 1. Reference Range Shaded Band
                    if viewModel.showReferenceRangeBand,
                       let minRef = summary.definition.referenceRangeMin,
                       let maxRef = summary.definition.referenceRangeMax,
                       let start = summary.rawTimeSeries.startDate,
                       let end = summary.rawTimeSeries.endDate {
                        RectangleMark(
                            xStart: .value("Start", start),
                            xEnd: .value("End", end),
                            yStart: .value("Min Target", minRef),
                            yEnd: .value("Max Target", maxRef)
                        )
                        .foregroundStyle(VialrColors.accentEmerald.opacity(0.08))
                    }

                    // 2. Baseline Reference Line
                    if viewModel.showBaselineRule, let base = summary.baselineResult {
                        RuleMark(y: .value("Baseline", base.baselineValue))
                            .foregroundStyle(VialrColors.textTertiary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .trailing) {
                                Text("Baseline")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(VialrColors.textTertiary)
                            }
                    }

                    // 3. Raw Measurement Data Points
                    if viewModel.showRawPointsOnChart {
                        ForEach(summary.rawTimeSeries.points) { point in
                            PointMark(
                                x: .value("Date", point.timestamp),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(Color(hex: summary.definition.colorHex).opacity(0.7))
                            .symbolSize(36)
                        }
                    }

                    // 4. Smoothed Moving Average Line
                    ForEach(viewModel.activeMovingAveragePoints) { maPoint in
                        LineMark(
                            x: .value("Date", maPoint.timestamp),
                            y: .value("Moving Average", maPoint.movingAverage)
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
                        AxisValueLabel(format: .dateTime.month().day()).foregroundStyle(VialrColors.textTertiary)
                    }
                }
                .frame(height: 220)
                .padding(.top, 4)

                // Chart Legend
                HStack(spacing: VialrSpacing.md) {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: summary.definition.colorHex)).frame(width: 8, height: 8)
                        Text("Raw Logs (\(summary.rawMeasurementsCount))")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }

                    if viewModel.selectedMovingAverage != .off {
                        HStack(spacing: 4) {
                            Rectangle().fill(VialrColors.accentTeal).frame(width: 14, height: 2.5)
                            Text(viewModel.selectedMovingAverage.rawValue)
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                        }
                    }

                    Spacer()
                }
            } else {
                Text("No data points available for this period.")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textTertiary)
                    .frame(height: 140)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - 5. Moving Average & Velocity Analysis
    private func movingAverageVelocitySection(_ summary: ComprehensiveMetricAnalytics) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("Moving Averages & Rate of Change")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)

            HStack(spacing: VialrSpacing.md) {
                // 7-Day SMA Card
                if let sma7 = summary.movingAverages.first(where: { $0.windowDays == 7 }),
                   let current = sma7.currentSmoothedValue {
                    Button {
                        if let audit = viewModel.masterReport?.rollingAverages.first(where: { $0.windowDays == 7 })?.auditTrail {
                            viewModel.presentAuditTrail(audit)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("7-DAY ROLLING AVERAGE")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textTertiary)
                                Spacer()
                                Image(systemName: "info.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(VialrColors.accentTeal)
                            }
                            Text("\(String(format: "%.1f", current)) \(summary.definition.defaultUnit)")
                                .font(VialrTypography.metricSmall)
                                .foregroundColor(VialrColors.accentTeal)

                            if let vel = sma7.weeklyVelocity {
                                let sign = vel > 0 ? "+" : ""
                                Text("\(sign)\(String(format: "%.1f", vel)) \(summary.definition.defaultUnit)/wk")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textSecondary)
                            }
                        }
                        .padding(VialrSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .vialrCard()
                    }
                    .buttonStyle(.plain)
                }

                // 30-Day SMA Card
                if let sma30 = summary.movingAverages.first(where: { $0.windowDays == 30 }),
                   let current30 = sma30.currentSmoothedValue {
                    Button {
                        if let audit = viewModel.masterReport?.rollingAverages.first(where: { $0.windowDays == 30 })?.auditTrail {
                            viewModel.presentAuditTrail(audit)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("30-DAY TRENDLINE")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textTertiary)
                                Spacer()
                                Image(systemName: "info.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(VialrColors.accentCyan)
                            }
                            Text("\(String(format: "%.1f", current30)) \(summary.definition.defaultUnit)")
                                .font(VialrTypography.metricSmall)
                                .foregroundColor(VialrColors.accentCyan)

                            if let vel30 = sma30.weeklyVelocity {
                                let sign = vel30 > 0 ? "+" : ""
                                Text("\(sign)\(String(format: "%.1f", vel30)) \(summary.definition.defaultUnit)/wk")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textSecondary)
                            }
                        }
                        .padding(VialrSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .vialrCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 6. Percentage Change Periods Grid
    private func percentageChangesSection(_ summary: ComprehensiveMetricAnalytics) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("Period-over-Period Performance")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VialrSpacing.sm) {
                ForEach(summary.percentageChanges) { change in
                    Button {
                        if let audit = viewModel.masterReport?.standardPeriodPercentageChanges.first(where: { $0.periodName == change.periodName })?.auditTrail {
                            viewModel.presentAuditTrail(audit)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(change.periodName.uppercased())
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textTertiary)
                                Spacer()
                                MetricBadge(.custom(
                                    title: change.trendDirection.rawValue,
                                    color: Color(hex: change.trendDirection.badgeColorHex),
                                    icon: nil
                                ))
                            }

                            Text(change.formattedPercentage)
                                .font(VialrTypography.metricSmall)
                                .foregroundColor(Color(hex: change.trendDirection.badgeColorHex))

                            Text("\(String(format: "%.1f", change.startValue)) → \(String(format: "%.1f", change.endValue)) \(summary.definition.defaultUnit)")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textSecondary)
                        }
                        .padding(VialrSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .vialrCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 7. Adherence Relationship Section
    private func adherenceRelationshipSection(_ adh: AdherenceRelationshipResult) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("Protocol Adherence Relationship")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)

            Button {
                if let audit = viewModel.masterReport?.adherence?.auditTrail {
                    viewModel.presentAuditTrail(audit)
                }
            } label: {
                VStack(alignment: .leading, spacing: VialrSpacing.md) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(VialrColors.accentTeal)
                        Text("\(Int(adh.overallAdherencePercentage))% Protocol Compliance")
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)
                        Spacer()
                        MetricBadge(.custom(title: adh.statisticalSignificance, color: VialrColors.accentEmerald, icon: nil))
                    }

                    if let hAvg = adh.highAdherenceAverageValue, let lAvg = adh.lowAdherenceAverageValue {
                        HStack(spacing: VialrSpacing.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("HIGH ADHERENCE (≥80%)")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textTertiary)
                                Text("\(String(format: "%.1f", hAvg)) \(viewModel.selectedMetric?.defaultUnit ?? "")")
                                    .font(VialrTypography.metricSmall)
                                    .foregroundColor(VialrColors.accentEmerald)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("LOWER ADHERENCE (<80%)")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textTertiary)
                                Text("\(String(format: "%.1f", lAvg)) \(viewModel.selectedMetric?.defaultUnit ?? "")")
                                    .font(VialrTypography.metricSmall)
                                    .foregroundColor(VialrColors.accentRose)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Text(adh.clinicalInsight)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .padding(VialrSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .vialrCard()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 8. Protocol-Period Comparisons Section
    private func protocolComparisonsSection(_ comparisons: [ProtocolPeriodComparison]) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("Protocol-to-Protocol Comparisons")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)

            ForEach(comparisons) { comp in
                Button {
                    if let audit = viewModel.masterReport?.periodComparisons.first(where: { $0.periodAName == comp.protocolAName })?.auditTrail {
                        viewModel.presentAuditTrail(audit)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: VialrSpacing.md) {
                        HStack {
                            Image(systemName: "arrow.left.arrow.right")
                                .foregroundColor(VialrColors.accentTeal)
                            Text("\(comp.protocolAName) vs \(comp.protocolBName)")
                                .font(VialrTypography.headline)
                                .foregroundColor(VialrColors.textPrimary)
                            Spacer()
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(VialrColors.accentTeal)
                        }

                        HStack(spacing: VialrSpacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(comp.protocolAName.uppercased())
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textTertiary)
                                Text("\(String(format: "%.1f", comp.periodAStats.meanValue)) \(comp.unit)")
                                    .font(VialrTypography.metricSmall)
                                    .foregroundColor(VialrColors.textPrimary)
                                Text("Δ: \(String(format: "%.1f", comp.periodAStats.netChange)) (\(String(format: "%.1f", comp.periodAStats.percentageChange))%)")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textSecondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(comp.protocolBName.uppercased())
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textTertiary)
                                Text("\(String(format: "%.1f", comp.periodBStats.meanValue)) \(comp.unit)")
                                    .font(VialrTypography.metricSmall)
                                    .foregroundColor(VialrColors.accentTeal)
                                Text("Δ: \(String(format: "%.1f", comp.periodBStats.netChange)) (\(String(format: "%.1f", comp.periodBStats.percentageChange))%)")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textSecondary)
                            }
                        }

                        if let cohenD = comp.cohensDEffectSize {
                            HStack {
                                Text("Cohen's d Effect Size: \(String(format: "%.2f", cohenD))")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.accentCyan)
                                Spacer()
                            }
                        }

                        Text(comp.summaryConclusion)
                            .font(VialrTypography.footnote)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                    .padding(VialrSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .vialrCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 9. Raw Measurement Audit Ledger
    private func rawMeasurementsLedgerSection(_ summary: ComprehensiveMetricAnalytics) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("Raw Measurement History")
                    .font(VialrTypography.title3)
                    .foregroundColor(VialrColors.textPrimary)
                Spacer()
                Text("\(summary.rawMeasurementsCount) Entries")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            ForEach(summary.rawTimeSeries.points.suffix(10).reversed()) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.dateRecorded, format: .dateTime.month().day().hour().minute())
                            .font(VialrTypography.bodyMedium)
                            .foregroundColor(VialrColors.textPrimary)

                        HStack(spacing: 6) {
                            Text(item.source.rawValue)
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)

                            if !item.notes.isEmpty {
                                Text("• \(item.notes)")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.formattedValue)
                            .font(VialrTypography.metricSmall)
                            .foregroundColor(Color(hex: item.status.colorHex))
                        MetricBadge(.custom(title: item.status.rawValue, color: Color(hex: item.status.colorHex), icon: nil))
                    }
                }
                .padding(VialrSpacing.sm)
                .vialrCard()
            }
        }
    }
}
