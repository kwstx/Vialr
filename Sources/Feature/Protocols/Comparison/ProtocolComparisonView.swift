import SwiftUI
import Charts
import Domain
import DesignSystem
import Analytics

public struct ProtocolComparisonView: View {
    @Bindable public var viewModel: ProtocolComparisonViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: ProtocolComparisonViewModel) {
        self.viewModel = viewModel
    }

    public init(protocols: [ProtocolModel]) {
        self.viewModel = ProtocolComparisonViewModel(initialProtocols: protocols)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Selector Controls
                    comparisonHeaderControls
                        .padding(.horizontal, VialrSpacing.md)
                        .padding(.top, VialrSpacing.xs)
                        .padding(.bottom, VialrSpacing.xs)

                    // Domain Filter Pills
                    domainFilterPills
                        .padding(.vertical, VialrSpacing.xs)

                    Divider().background(VialrColors.glassBorder)

                    // Content Body
                    ScrollView {
                        VStack(spacing: VialrSpacing.lg) {
                            if viewModel.isLoading {
                                ProgressView("Computing Time-Series Statistics...")
                                    .padding(.vertical, 40)
                                    .foregroundColor(VialrColors.textSecondary)
                            } else if let report = viewModel.comparisonReport {
                                // Non-Causal Scientific Advisory Banner
                                nonCausalityAdvisoryBanner(report.nonCausalityAdvisory)

                                // Selected Domain Content
                                switch viewModel.selectedDomain {
                                case .overview:
                                    overviewSection(report)
                                case .weight:
                                    if let w = report.weightComparison {
                                        metricComparisonCard(w, title: "Body Weight & Composition")
                                    } else {
                                        emptyDomainView("No weight measurements recorded during these periods.")
                                    }
                                case .vitals:
                                    if !report.measurementComparisons.isEmpty {
                                        ForEach(report.measurementComparisons) { comp in
                                            metricComparisonCard(comp, title: comp.metricDefinition.name)
                                        }
                                    } else {
                                        emptyDomainView("No vital or physical measurements logged in these intervals.")
                                    }
                                case .adherence:
                                    if let adh = report.adherenceComparison {
                                        adherenceComparisonSection(adh, periodA: report.periodA, periodB: report.periodB)
                                    } else {
                                        emptyDomainView("No dose logs available for adherence comparison.")
                                    }
                                case .symptoms:
                                    if let sym = report.symptomComparison {
                                        symptomsComparisonSection(sym, periodA: report.periodA, periodB: report.periodB)
                                    } else {
                                        emptyDomainView("No symptom logs recorded during these periods.")
                                    }
                                case .biomarkers:
                                    if !report.biomarkerComparisons.isEmpty {
                                        ForEach(report.biomarkerComparisons) { bio in
                                            biomarkerComparisonCard(bio, periodA: report.periodA, periodB: report.periodB)
                                        }
                                    } else {
                                        emptyDomainView("No bloodwork panels found for these observation windows.")
                                    }
                                case .cost:
                                    if let cost = report.costComparison {
                                        costComparisonSection(cost, periodA: report.periodA, periodB: report.periodB)
                                    } else {
                                        emptyDomainView("No financial expense records allocated to these periods.")
                                    }
                                }

                                // Confounders Disclosure Card
                                confoundersCard(report.identifiedConfounders)
                            } else {
                                emptySelectionState
                            }
                        }
                        .padding(.horizontal, VialrSpacing.md)
                        .padding(.vertical, VialrSpacing.md)
                        .padding(.bottom, 60)
                    }
                }
            }
            .navigationTitle("Protocol Comparison")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(VialrTypography.bodyBold)
                    .foregroundColor(VialrColors.accentTeal)
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Header Controls

    private var comparisonHeaderControls: some View {
        VStack(spacing: VialrSpacing.xs) {
            // Mode Switcher
            HStack {
                Text("MODE")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textTertiary)
                Spacer()
                Picker("Comparison Mode", selection: $viewModel.mode) {
                    ForEach(ComparisonMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                .onChange(of: viewModel.mode) { _, _ in
                    Task { await viewModel.computeComparison() }
                }
            }

            // Protocol Selectors or Date Pickers
            if viewModel.mode == .protocols {
                HStack(spacing: VialrSpacing.sm) {
                    // Protocol A
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PERIOD A")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentTeal)
                        Picker("Protocol A", selection: $viewModel.selectedProtocolA) {
                            ForEach(viewModel.availableProtocols) { p in
                                Text(p.name).tag(Optional(p))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(VialrColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(VialrColors.cardSurfaceElevated)
                    .cornerRadius(8)

                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(VialrColors.textTertiary)

                    // Protocol B
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PERIOD B")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentEmerald)
                        Picker("Protocol B", selection: $viewModel.selectedProtocolB) {
                            ForEach(viewModel.availableProtocols) { p in
                                Text(p.name).tag(Optional(p))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(VialrColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(VialrColors.cardSurfaceElevated)
                    .cornerRadius(8)
                }
                .onChange(of: viewModel.selectedProtocolA) { _, _ in Task { await viewModel.computeComparison() } }
                .onChange(of: viewModel.selectedProtocolB) { _, _ in Task { await viewModel.computeComparison() } }
            } else {
                VStack(spacing: 6) {
                    HStack {
                        Text("Period A:")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentTeal)
                        DatePicker("", selection: $viewModel.dateRangeAStart, displayedComponents: .date)
                            .labelsHidden()
                        Text("to")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                        DatePicker("", selection: $viewModel.dateRangeAEnd, displayedComponents: .date)
                            .labelsHidden()
                    }
                    HStack {
                        Text("Period B:")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentEmerald)
                        DatePicker("", selection: $viewModel.dateRangeBStart, displayedComponents: .date)
                            .labelsHidden()
                        Text("to")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                        DatePicker("", selection: $viewModel.dateRangeBEnd, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
                .padding(8)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(8)
                .onChange(of: viewModel.dateRangeAStart) { _, _ in Task { await viewModel.computeComparison() } }
                .onChange(of: viewModel.dateRangeAEnd) { _, _ in Task { await viewModel.computeComparison() } }
                .onChange(of: viewModel.dateRangeBStart) { _, _ in Task { await viewModel.computeComparison() } }
                .onChange(of: viewModel.dateRangeBEnd) { _, _ in Task { await viewModel.computeComparison() } }
            }
        }
    }

    // MARK: - Domain Filter Pills

    private var domainFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ComparisonDomainTab.allCases) { tab in
                    let isSel = viewModel.selectedDomain == tab
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.selectedDomain = tab
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 11, weight: .bold))
                            Text(tab.rawValue)
                                .font(VialrTypography.captionBold)
                        }
                        .foregroundColor(isSel ? VialrColors.backgroundPrimary : VialrColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSel ? VialrColors.accentTeal : VialrColors.cardSurfaceElevated)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isSel ? Color.clear : VialrColors.glassBorder, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, VialrSpacing.md)
        }
    }

    // MARK: - Non-Causality Advisory Banner

    private func nonCausalityAdvisoryBanner(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(VialrColors.accentCyan)
                Text("OBSERVATIONAL DATA NOTICE (NON-CAUSAL)")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentCyan)
                Spacer()
                MetricBadge(.neutral("Correlation ≠ Causation"))
            }

            Text(text)
                .font(VialrTypography.caption)
                .foregroundColor(VialrColors.textSecondary)
                .lineSpacing(2)
        }
        .padding(VialrSpacing.md)
        .background(VialrColors.accentCyan.opacity(0.08))
        .cornerRadius(VialrSpacing.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                .stroke(VialrColors.accentCyan.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Overview Section

    private func overviewSection(_ report: ProtocolComparisonReport) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            // Executive Summary Card
            VStack(alignment: .leading, spacing: 8) {
                Text("EXECUTIVE SYNTHESIS")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Text(report.executiveSummary)
                    .font(VialrTypography.bodyMedium)
                    .foregroundColor(VialrColors.textPrimary)
                    .lineSpacing(3)
            }
            .padding(VialrSpacing.md)
            .vialrCard()

            // Key Differences Quick Grid
            HStack(spacing: VialrSpacing.sm) {
                summaryStatCard(
                    title: "PERIOD A DURATION",
                    value: "\(report.periodA.durationDays) Days",
                    color: VialrColors.accentTeal
                )
                summaryStatCard(
                    title: "PERIOD B DURATION",
                    value: "\(report.periodB.durationDays) Days",
                    color: VialrColors.accentEmerald
                )
            }

            // Weight Primary Metric Summary
            if let w = report.weightComparison {
                metricComparisonCard(w, title: "Primary Metric: Body Weight")
            }

            // Adherence Snippet
            if let adh = report.adherenceComparison {
                adherenceQuickCard(adh, periodA: report.periodA, periodB: report.periodB)
            }
        }
    }

    // MARK: - Standard Metric Comparison Card (Observed vs Interpretation)

    private func metricComparisonCard(_ comp: MetricComparisonResult, title: String) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            // Card Title & Trajectory Badge
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text(comp.metricDefinition.name)
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                }
                Spacer()
                MetricBadge(.custom(
                    title: comp.interpretation.trajectoryAssessment.rawValue,
                    color: Color(hex: comp.interpretation.trajectoryAssessment.badgeColorHex),
                    icon: nil
                ))
            }

            Divider().background(VialrColors.glassBorder)

            // SECTION 1: OBSERVED EMPIRICAL CHANGES
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(VialrColors.accentCyan)
                    Text("1. OBSERVED CHANGE (MATHEMATICAL FACTS)")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentCyan)
                }

                // Side by Side Numbers Table
                VStack(spacing: 6) {
                    HStack {
                        Text("Metric Dimension")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Period A")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentTeal)
                            .frame(width: 80, alignment: .trailing)
                        Text("Period B")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentEmerald)
                            .frame(width: 80, alignment: .trailing)
                        Text("Delta (B - A)")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textPrimary)
                            .frame(width: 90, alignment: .trailing)
                    }
                    .padding(.bottom, 2)

                    statRow(label: "Sample Count (N)", a: "\(comp.observedChange.periodAStats.sampleCount)", b: "\(comp.observedChange.periodBStats.sampleCount)", delta: "\(comp.observedChange.periodBStats.sampleCount - comp.observedChange.periodAStats.sampleCount)")
                    statRow(label: "Start Value", a: formatVal(comp.observedChange.periodAStats.firstValue, comp.metricDefinition.defaultUnit), b: formatVal(comp.observedChange.periodBStats.firstValue, comp.metricDefinition.defaultUnit), delta: "-")
                    statRow(label: "End Value", a: formatVal(comp.observedChange.periodAStats.lastValue, comp.metricDefinition.defaultUnit), b: formatVal(comp.observedChange.periodBStats.lastValue, comp.metricDefinition.defaultUnit), delta: formatDelta(comp.observedChange.periodBStats.lastValue - comp.observedChange.periodAStats.lastValue, comp.metricDefinition.defaultUnit))
                    statRow(label: "Mean (μ)", a: formatVal(comp.observedChange.periodAStats.meanValue, comp.metricDefinition.defaultUnit), b: formatVal(comp.observedChange.periodBStats.meanValue, comp.metricDefinition.defaultUnit), delta: formatDelta(comp.observedChange.meanDifference, comp.metricDefinition.defaultUnit))
                    statRow(label: "Std Dev (σ)", a: String(format: "%.2f", comp.observedChange.periodAStats.standardDeviation), b: String(format: "%.2f", comp.observedChange.periodBStats.standardDeviation), delta: "-")
                    statRow(label: "Net Change (Δ)", a: formatDelta(comp.observedChange.periodAStats.netChange, comp.metricDefinition.defaultUnit), b: formatDelta(comp.observedChange.periodBStats.netChange, comp.metricDefinition.defaultUnit), delta: formatDelta(comp.observedChange.netChangeDifference, comp.metricDefinition.defaultUnit))
                    statRow(label: "Weekly Velocity", a: "\(formatDelta(comp.observedChange.periodAStats.weeklyVelocity, comp.metricDefinition.defaultUnit))/wk", b: "\(formatDelta(comp.observedChange.periodBStats.weeklyVelocity, comp.metricDefinition.defaultUnit))/wk", delta: "\(formatDelta(comp.observedChange.velocityDifferencePerWeek, comp.metricDefinition.defaultUnit))/wk")
                }
                .padding(10)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(8)

                // Statistical Effect Size Pill
                if let d = comp.observedChange.cohensDEffectSize {
                    HStack(spacing: 8) {
                        Image(systemName: "function")
                            .foregroundColor(VialrColors.accentVitality)
                        Text("Cohen's d Effect Size: \(String(format: "%.2f", d))")
                            .font(VialrTypography.footnote)
                            .foregroundColor(VialrColors.textPrimary)
                        Spacer()
                        Text(d >= 0.8 ? "Large Differential" : (d >= 0.5 ? "Moderate Differential" : "Small Differential"))
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(VialrColors.accentVitality.opacity(0.1))
                    .cornerRadius(6)
                }
            }

            Divider().background(VialrColors.glassBorder)

            // SECTION 2: QUALITATIVE INTERPRETATION
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(VialrColors.accentTeal)
                    Text("2. INTERPRETATION & CLINICAL CONTEXT")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Spacer()
                    MetricBadge(.custom(
                        title: comp.interpretation.confidenceLevel.rawValue,
                        color: Color(hex: comp.interpretation.confidenceLevel.badgeColorHex),
                        icon: nil
                    ))
                }

                Text(comp.interpretation.narrativeSummary)
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textPrimary)
                    .lineSpacing(2)

                if !comp.interpretation.recommendedFollowUp.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Actionable Recommendations:")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textTertiary)
                        ForEach(comp.interpretation.recommendedFollowUp, id: \.self) { rec in
                            HStack(alignment: .top, spacing: 4) {
                                Text("•")
                                    .foregroundColor(VialrColors.accentTeal)
                                Text(rec)
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textSecondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Adherence Comparison Section

    private func adherenceComparisonSection(_ adh: AdherenceComparisonResult, periodA: ProtocolComparisonPeriod, periodB: ProtocolComparisonPeriod) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PROTOCOL COMPLIANCE")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text("Dose Adherence Comparison")
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                }
                Spacer()
                MetricBadge(adh.observedChange.adherenceRateDifference >= 0 ? .success("+\(String(format: "%.1f", adh.observedChange.adherenceRateDifference))% Rate") : .warning("\(String(format: "%.1f", adh.observedChange.adherenceRateDifference))% Rate"))
            }

            // Observed Table
            VStack(spacing: 6) {
                statRow(label: "Adherence Rate", a: "\(Int(adh.observedChange.periodAStats.adherencePercentage))%", b: "\(Int(adh.observedChange.periodBStats.adherencePercentage))%", delta: "\(adh.observedChange.adherenceRateDifference >= 0 ? "+" : "")\(String(format: "%.1f", adh.observedChange.adherenceRateDifference))%")
                statRow(label: "Doses Taken", a: "\(adh.observedChange.periodAStats.takenDoses)", b: "\(adh.observedChange.periodBStats.takenDoses)", delta: "\(adh.observedChange.periodBStats.takenDoses - adh.observedChange.periodAStats.takenDoses)")
                statRow(label: "Doses Missed", a: "\(adh.observedChange.periodAStats.missedDoses)", b: "\(adh.observedChange.periodBStats.missedDoses)", delta: "\(adh.observedChange.missedDoseDifference)")
                statRow(label: "Max Streak", a: "\(adh.observedChange.periodAStats.activeStreakDays) Days", b: "\(adh.observedChange.periodBStats.activeStreakDays) Days", delta: "\(adh.observedChange.streakDifferenceDays) Days")
            }
            .padding(10)
            .background(VialrColors.cardSurfaceElevated)
            .cornerRadius(8)

            // Interpretation
            VStack(alignment: .leading, spacing: 6) {
                Text("Interpretation & Impact:")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textTertiary)
                Text(adh.interpretation.narrativeSummary)
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textPrimary)
                Text(adh.interpretation.complianceImpactAssessment)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textSecondary)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func adherenceQuickCard(_ adh: AdherenceComparisonResult, periodA: ProtocolComparisonPeriod, periodB: ProtocolComparisonPeriod) -> some View {
        HStack(spacing: VialrSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ADHERENCE RATE (A vs B)")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textTertiary)
                Text("\(Int(adh.observedChange.periodAStats.adherencePercentage))% → \(Int(adh.observedChange.periodBStats.adherencePercentage))%")
                    .font(VialrTypography.metricSmall)
                    .foregroundColor(VialrColors.accentCyan)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("MISSED DOSES")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textTertiary)
                Text("\(adh.observedChange.periodAStats.missedDoses) in A / \(adh.observedChange.periodBStats.missedDoses) in B")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textPrimary)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Symptoms Comparison Section

    private func symptomsComparisonSection(_ sym: SymptomComparisonResult, periodA: ProtocolComparisonPeriod, periodB: ProtocolComparisonPeriod) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SUBJECTIVE WELL-BEING")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text("Symptom & Recovery Scores")
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                }
                Spacer()
                MetricBadge(.custom(
                    title: sym.interpretation.wellbeingTrajectory.rawValue,
                    color: Color(hex: sym.interpretation.wellbeingTrajectory.badgeColorHex),
                    icon: nil
                ))
            }

            // Domain Stats Grid
            VStack(spacing: 6) {
                ForEach(["Energy", "Sleep Quality", "Recovery", "Mood", "Composite Well-Being"], id: \.self) { domain in
                    let statA = sym.observedChange.domainStatsA[domain]?.meanValue ?? 0
                    let statB = sym.observedChange.domainStatsB[domain]?.meanValue ?? 0
                    let delta = statB - statA
                    let unit = domain.contains("Composite") ? "/100" : "/10"
                    statRow(
                        label: domain,
                        a: "\(String(format: "%.1f", statA))\(unit)",
                        b: "\(String(format: "%.1f", statB))\(unit)",
                        delta: "\(delta >= 0 ? "+" : "")\(String(format: "%.1f", delta))"
                    )
                }
            }
            .padding(10)
            .background(VialrColors.cardSurfaceElevated)
            .cornerRadius(8)

            // Narrative
            Text(sym.interpretation.narrativeSummary)
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textPrimary)
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Biomarker Comparison Card

    private func biomarkerComparisonCard(_ bio: BiomarkerComparisonResult, periodA: ProtocolComparisonPeriod, periodB: ProtocolComparisonPeriod) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BIOMARKER SHIFT")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text(bio.observedChange.biomarkerName)
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                }
                Spacer()
                MetricBadge(.custom(
                    title: bio.observedChange.statusTransitionDescription,
                    color: Color(hex: bio.observedChange.statusB.colorHex),
                    icon: nil
                ))
            }

            VStack(spacing: 6) {
                statRow(label: "Endpoint Value", a: "\(String(format: "%.1f", bio.observedChange.periodAStats.lastValue)) \(bio.observedChange.unit)", b: "\(String(format: "%.1f", bio.observedChange.periodBStats.lastValue)) \(bio.observedChange.unit)", delta: "\(bio.observedChange.absoluteShift >= 0 ? "+" : "")\(String(format: "%.1f", bio.observedChange.absoluteShift)) \(bio.observedChange.unit)")
                statRow(label: "Mean Value", a: "\(String(format: "%.1f", bio.observedChange.periodAStats.meanValue)) \(bio.observedChange.unit)", b: "\(String(format: "%.1f", bio.observedChange.periodBStats.meanValue)) \(bio.observedChange.unit)", delta: "\(bio.observedChange.percentageShift >= 0 ? "+" : "")\(String(format: "%.1f", bio.observedChange.percentageShift))%")
            }
            .padding(10)
            .background(VialrColors.cardSurfaceElevated)
            .cornerRadius(8)

            Text(bio.interpretation.clinicalContext)
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textPrimary)
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Cost Comparison Section

    private func costComparisonSection(_ cost: CostComparisonResult, periodA: ProtocolComparisonPeriod, periodB: ProtocolComparisonPeriod) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FINANCIAL EFFICIENCY")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text("Cost & Expenditure Comparison")
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                }
                Spacer()
                Text(cost.observedChange.costDeltaTotal <= 0 ? "Favorable Spend" : "+ Spend")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(cost.observedChange.costDeltaTotal <= 0 ? VialrColors.accentEmerald : VialrColors.accentAmber)
            }

            VStack(spacing: 6) {
                statRow(label: "Total Period Spend", a: "$\(String(format: "%.2f", cost.observedChange.totalCostA))", b: "$\(String(format: "%.2f", cost.observedChange.totalCostB))", delta: "$\(String(format: "%.2f", cost.observedChange.costDeltaTotal))")
                statRow(label: "Daily Spend Rate", a: "$\(String(format: "%.2f", cost.observedChange.costPerDayA))/day", b: "$\(String(format: "%.2f", cost.observedChange.costPerDayB))/day", delta: "$\(String(format: "%.2f", cost.observedChange.costDeltaPerDay))/day")
                statRow(label: "Cost Per Dose", a: "$\(String(format: "%.2f", cost.observedChange.costPerDoseA))", b: "$\(String(format: "%.2f", cost.observedChange.costPerDoseB))", delta: "-")
            }
            .padding(10)
            .background(VialrColors.cardSurfaceElevated)
            .cornerRadius(8)

            Text(cost.interpretation.financialEfficiencySummary)
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textPrimary)

            Text(cost.interpretation.budgetaryProjection)
                .font(VialrTypography.caption)
                .foregroundColor(VialrColors.textSecondary)
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Confounders Card

    private func confoundersCard(_ confounders: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(VialrColors.accentAmber)
                Text("POTENTIAL CONFOUNDING VARIABLES")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentAmber)
            }

            ForEach(confounders, id: \.self) { c in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .foregroundColor(VialrColors.accentAmber)
                    Text(c)
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                        .lineSpacing(2)
                }
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - UI Helpers & Formatters

    private func statRow(label: String, a: String, b: String, delta: String) -> some View {
        HStack {
            Text(label)
                .font(VialrTypography.caption)
                .foregroundColor(VialrColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(a)
                .font(VialrTypography.monoDose)
                .foregroundColor(VialrColors.accentTeal)
                .frame(width: 80, alignment: .trailing)
            Text(b)
                .font(VialrTypography.monoDose)
                .foregroundColor(VialrColors.accentEmerald)
                .frame(width: 80, alignment: .trailing)
            Text(delta)
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.textPrimary)
                .frame(width: 90, alignment: .trailing)
        }
    }

    private func summaryStatCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.textTertiary)
            Text(value)
                .font(VialrTypography.metricSmall)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func emptyDomainView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(VialrColors.textTertiary)
            Text(message)
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    private var emptySelectionState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 44))
                .foregroundColor(VialrColors.accentTeal)
            Text("Select Protocols or Ranges to Compare")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)
            Text("Choose two protocols or date ranges above to generate side-by-side descriptive statistics and non-causal trajectory analyses.")
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func formatVal(_ val: Double, _ unit: String) -> String {
        "\(String(format: "%.1f", val)) \(unit)"
    }

    private func formatDelta(_ val: Double, _ unit: String) -> String {
        let sign = val > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", val)) \(unit)"
    }
}
