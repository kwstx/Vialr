import SwiftUI
import Charts
import Domain
import DesignSystem

/// Dedicated Explainability Inspection Sheet that allows users to tap on any analytical card, badge,
/// or summary stat to inspect the underlying raw data points, mathematical formula, and step-by-step computation.
public struct ExplainabilityInspectionSheet: View {
    public let auditTrail: CalculationAuditTrail
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedTab: InspectionTab = .overview

    public enum InspectionTab: String, CaseIterable, Identifiable {
        case overview = "Formula & Trace"
        case underlyingData = "Raw Data Points"

        public var id: String { rawValue }
    }

    public init(auditTrail: CalculationAuditTrail) {
        self.auditTrail = auditTrail
    }

    public var filteredDataPoints: [UnderlyingDataPoint] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return auditTrail.underlyingDataPoints
        }
        let query = searchText.lowercased()
        return auditTrail.underlyingDataPoints.filter {
            $0.label.lowercased().contains(query) ||
            $0.notes.lowercased().contains(query) ||
            $0.source.lowercased().contains(query) ||
            $0.recordType.lowercased().contains(query)
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented Tab Picker
                    HStack(spacing: 6) {
                        ForEach(InspectionTab.allCases) { tab in
                            let isSel = selectedTab == tab
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedTab = tab
                                }
                            } label: {
                                Text(tab.rawValue)
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(isSel ? VialrColors.backgroundPrimary : VialrColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(isSel ? VialrColors.accentTeal : Color.clear)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(4)
                    .background(VialrColors.cardSurface)
                    .cornerRadius(10)
                    .padding(.horizontal, VialrSpacing.md)
                    .padding(.top, VialrSpacing.sm)
                    .padding(.bottom, VialrSpacing.sm)

                    // Tab Content
                    if selectedTab == .overview {
                        overviewTabContent
                    } else {
                        underlyingDataTabContent
                    }
                }
            }
            .navigationTitle("Analytics Trace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(position: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(VialrTypography.bodyBold)
                            .foregroundColor(VialrColors.accentTeal)
                    }
                }
            }
        }
    }

    // MARK: - Overview Tab: Formula, Steps, Explanation
    private var overviewTabContent: some View {
        ScrollView {
            VStack(spacing: VialrSpacing.md) {
                // Header Hero Card
                VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                    HStack {
                        Text(auditTrail.calculationName.uppercased())
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentTeal)
                        Spacer()
                        Text("\(auditTrail.sampleSize) Data Points")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }

                    if !auditTrail.humanReadableExplanation.isEmpty {
                        Text(auditTrail.humanReadableExplanation)
                            .font(VialrTypography.bodyMedium)
                            .foregroundColor(VialrColors.textPrimary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12))
                            .foregroundColor(VialrColors.textTertiary)
                        Text("Calculated: \(auditTrail.calculatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }
                }
                .padding(VialrSpacing.md)
                .vialrCard()

                // Mathematical Formula Card
                VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                    HStack {
                        Image(systemName: "function")
                            .foregroundColor(VialrColors.accentTeal)
                        Text("Mathematical Formula")
                            .font(VialrTypography.title3)
                            .foregroundColor(VialrColors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(auditTrail.formula.name)
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textTertiary)

                        Text(auditTrail.formula.expression)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(VialrColors.accentCyan)
                            .padding(VialrSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(VialrColors.backgroundTertiary)
                            .cornerRadius(8)
                    }

                    if !auditTrail.formula.variableDescriptions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Variables & Definitions:")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.textTertiary)

                            ForEach(Array(auditTrail.formula.variableDescriptions.keys.sorted()), id: \.self) { key in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("• \(key):")
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundColor(VialrColors.textSecondary)
                                    Text(auditTrail.formula.variableDescriptions[key] ?? "")
                                        .font(VialrTypography.caption)
                                        .foregroundColor(VialrColors.textTertiary)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }

                    if !auditTrail.formula.methodology.isEmpty {
                        Text(auditTrail.formula.methodology)
                            .font(VialrTypography.footnote)
                            .foregroundColor(VialrColors.textSecondary)
                            .padding(.top, 4)
                    }
                }
                .padding(VialrSpacing.md)
                .vialrCard()

                // Step-by-Step Calculation Trace
                if !auditTrail.steps.isEmpty {
                    VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                        HStack {
                            Image(systemName: "list.number")
                                .foregroundColor(VialrColors.accentEmerald)
                            Text("Step-by-Step Trace")
                                .font(VialrTypography.title3)
                                .foregroundColor(VialrColors.textPrimary)
                        }

                        ForEach(auditTrail.steps) { step in
                            HStack(alignment: .top, spacing: VialrSpacing.sm) {
                                ZStack {
                                    Circle()
                                        .fill(VialrColors.accentTeal.opacity(0.15))
                                        .frame(width: 24, height: 24)
                                    Text("\(step.stepNumber)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(VialrColors.accentTeal)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(step.title)
                                            .font(VialrTypography.bodyBold)
                                            .foregroundColor(VialrColors.textPrimary)
                                        Spacer()
                                        Text("\(String(format: "%.2f", step.outputValue)) \(step.unit ?? "")")
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundColor(VialrColors.accentEmerald)
                                    }

                                    Text(step.description)
                                        .font(VialrTypography.footnote)
                                        .foregroundColor(VialrColors.textSecondary)

                                    if !step.formulaApplied.isEmpty {
                                        Text(step.formulaApplied)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundColor(VialrColors.accentCyan)
                                            .padding(.top, 2)
                                    }
                                }
                            }
                            .padding(.vertical, 4)

                            if step.id != auditTrail.steps.last?.id {
                                Divider().background(VialrColors.divider)
                            }
                        }
                    }
                    .padding(VialrSpacing.md)
                    .vialrCard()
                }

                // Mini Chart of Included Points
                if auditTrail.underlyingDataPoints.count >= 2 {
                    VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                        HStack {
                            Image(systemName: "chart.xyaxis.line")
                                .foregroundColor(VialrColors.accentTeal)
                            Text("Data Points Included")
                                .font(VialrTypography.title3)
                                .foregroundColor(VialrColors.textPrimary)
                        }

                        Chart {
                            ForEach(auditTrail.underlyingDataPoints) { point in
                                LineMark(
                                    x: .value("Date", point.timestamp),
                                    y: .value("Value", point.value)
                                )
                                .foregroundStyle(VialrColors.accentTeal)
                                .lineStyle(StrokeStyle(lineWidth: 2))

                                PointMark(
                                    x: .value("Date", point.timestamp),
                                    y: .value("Value", point.value)
                                )
                                .foregroundStyle(VialrColors.accentEmerald)
                                .symbolSize(40)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) {
                                AxisGridLine().foregroundStyle(VialrColors.glassBorder)
                                AxisValueLabel().foregroundStyle(VialrColors.textTertiary)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 3)) {
                                AxisGridLine().foregroundStyle(VialrColors.glassBorder)
                                AxisValueLabel(format: .dateTime.month().day()).foregroundStyle(VialrColors.textTertiary)
                            }
                        }
                        .frame(height: 160)
                        .padding(.top, 4)
                    }
                    .padding(VialrSpacing.md)
                    .vialrCard()
                }
            }
            .padding(.horizontal, VialrSpacing.md)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Underlying Raw Data Points Tab
    private var underlyingDataTabContent: some View {
        VStack(spacing: VialrSpacing.sm) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(VialrColors.textTertiary)
                TextField("Search records, labels, notes...", text: $searchText)
                    .foregroundColor(VialrColors.textPrimary)
                    .font(VialrTypography.footnote)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(VialrColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VialrColors.cardSurface)
            .cornerRadius(10)
            .padding(.horizontal, VialrSpacing.md)

            // Records List
            if !filteredDataPoints.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredDataPoints) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(item.recordType.uppercased())
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(VialrColors.accentTeal.opacity(0.15))
                                            .foregroundColor(VialrColors.accentTeal)
                                            .cornerRadius(4)

                                        Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                                            .font(VialrTypography.caption)
                                            .foregroundColor(VialrColors.textTertiary)
                                    }

                                    if !item.label.isEmpty {
                                        Text(item.label)
                                            .font(VialrTypography.bodyMedium)
                                            .foregroundColor(VialrColors.textPrimary)
                                    }

                                    HStack(spacing: 6) {
                                        Text("Source: \(item.source)")
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
                                    Text("\(String(format: "%.1f", item.value)) \(item.unit)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(VialrColors.textPrimary)

                                    if let sec = item.secondaryValue {
                                        Text("Secondary: \(String(format: "%.1f", sec))")
                                            .font(VialrTypography.caption)
                                            .foregroundColor(VialrColors.textTertiary)
                                    }
                                }
                            }
                            .padding(VialrSpacing.sm)
                            .vialrCard()
                        }
                    }
                    .padding(.horizontal, VialrSpacing.md)
                    .padding(.bottom, 40)
                }
            } else {
                VialrEmptyStateView(
                    iconName: "magnifyingglass",
                    title: "No Matching Records",
                    message: "No raw data points match your search query."
                )
                .padding(.top, 40)
            }
        }
    }
}
