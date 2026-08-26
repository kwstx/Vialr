import SwiftUI
import Charts

// MARK: - 1. Minimum Touch Target Enforcement (Apple HIG >= 44x44pt)

/// Modifier that expands the interactive hit testing area of a view to meet or exceed
/// Apple's Human Interface Guidelines minimum touch target of 44x44pt,
/// without altering the view's visual appearance or geometry.
public struct MinTouchTargetModifier: ViewModifier {
    public let minWidth: CGFloat
    public let minHeight: CGFloat

    public init(minWidth: CGFloat = VialrSpacing.minTouchTarget, minHeight: CGFloat = VialrSpacing.minTouchTarget) {
        self.minWidth = minWidth
        self.minHeight = minHeight
    }

    public func body(content: Content) -> some View {
        content
            .frame(minWidth: minWidth, minHeight: minHeight)
            .contentShape(Rectangle())
    }
}

public extension View {
    /// Ensures this interactive element satisfies Apple's 44x44pt minimum touch target.
    func minTouchTarget(minWidth: CGFloat = VialrSpacing.minTouchTarget, minHeight: CGFloat = VialrSpacing.minTouchTarget) -> some View {
        self.modifier(MinTouchTargetModifier(minWidth: minWidth, minHeight: minHeight))
    }

    /// Enforces the standard 44x44pt accessible touch target.
    func accessibleTouchTarget() -> some View {
        self.modifier(MinTouchTargetModifier())
    }
}

// MARK: - 2. Dynamic Type Adaptive Layout Helper

/// Adaptive stack that automatically switches from an HStack to a VStack
/// when the user's Dynamic Type size exceeds a specified threshold (default: .accessibility1),
/// preventing text clipping or truncated labels on large text accessibility sizes.
public struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    public let horizontalAlignment: HorizontalAlignment
    public let verticalAlignment: VerticalAlignment
    public let spacing: CGFloat?
    public let threshold: DynamicTypeSize
    public let content: () -> Content

    public init(
        horizontalAlignment: HorizontalAlignment = .leading,
        verticalAlignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        threshold: DynamicTypeSize = .accessibility1,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.threshold = threshold
        self.content = content
    }

    public var body: some View {
        if dynamicTypeSize >= threshold {
            VStack(alignment: horizontalAlignment, spacing: spacing) {
                content()
            }
        } else {
            HStack(alignment: verticalAlignment, spacing: spacing) {
                content()
            }
        }
    }
}

// MARK: - 3. Non-Color-Reliant Status Shapes & Indicators

/// Standard accessibility status indicators combining geometric shapes, distinct icons,
/// and high-contrast color tints to guarantee information is never encoded purely through color.
public enum AccessibilityStatusType: Sendable {
    case success
    case warning
    case critical
    case info
    case neutral

    public var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        case .neutral: return "circle.fill"
        }
    }

    public var shapeDescription: String {
        switch self {
        case .success: return "Checkmark circle"
        case .warning: return "Warning triangle"
        case .critical: return "Octagon alert"
        case .info: return "Information dot"
        case .neutral: return "Neutral point"
        }
    }

    public var localizedText: String {
        switch self {
        case .success: return "Optimal / Completed"
        case .warning: return "Attention Needed"
        case .critical: return "Critical / Out of Range"
        case .info: return "Informational"
        case .neutral: return "Normal"
        }
    }
}

/// A compact, multi-modal status indicator that pairs geometry, icon, and color.
public struct AccessibleStatusIndicator: View {
    public let status: AccessibilityStatusType
    public let color: Color
    public let size: CGFloat
    public let showIcon: Bool

    public init(
        _ status: AccessibilityStatusType,
        color: Color = VialrColors.accentVitality,
        size: CGFloat = 14,
        showIcon: Bool = true
    ) {
        self.status = status
        self.color = color
        self.size = size
        self.showIcon = showIcon
    }

    public var body: some View {
        Group {
            if showIcon {
                Image(systemName: status.iconName)
                    .font(.system(size: size, weight: .bold))
                    .foregroundColor(color)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.localizedText)
    }
}

// MARK: - 4. VoiceOver Accessibility Announcement Utilities

public enum VialrAccessibilityNotifier {
    /// Posts a high-priority VoiceOver announcement to ensure assistive tech users are notified of events.
    @MainActor
    public static func announce(_ message: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }

    /// Notifies VoiceOver that screen layout or major focal elements have updated.
    @MainActor
    public static func screenChanged(focusElement: Any? = nil) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .screenChanged, argument: focusElement)
        #endif
    }
}

// MARK: - 5. Accessible Chart Framework & Textual Summaries

/// Data model representing an accessible, textual chart summary
/// enabling complete chart inspection for screen readers and tabular display.
public struct ChartDataSummary: Sendable, Equatable {
    public let title: String
    public let metricUnit: String
    public let totalDataPoints: Int
    public let minimumValue: Double?
    public let maximumValue: Double?
    public let averageValue: Double?
    public let currentValue: Double?
    public let baselineValue: Double?
    public let trendDirectionDescription: String
    public let keyObservations: [String]

    public init(
        title: String,
        metricUnit: String,
        totalDataPoints: Int,
        minimumValue: Double? = nil,
        maximumValue: Double? = nil,
        averageValue: Double? = nil,
        currentValue: Double? = nil,
        baselineValue: Double? = nil,
        trendDirectionDescription: String = "Stable",
        keyObservations: [String] = []
    ) {
        self.title = title
        self.metricUnit = metricUnit
        self.totalDataPoints = totalDataPoints
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.averageValue = averageValue
        self.currentValue = currentValue
        self.baselineValue = baselineValue
        self.trendDirectionDescription = trendDirectionDescription
        self.keyObservations = keyObservations
    }

    /// Full textual description for VoiceOver readouts.
    public var accessibilityFullSummary: String {
        var summary = "\(title) chart summary with \(totalDataPoints) data points."
        if let cur = currentValue {
            summary += " Current reading is \(String(format: "%.1f", cur)) \(metricUnit)."
        }
        if let min = minimumValue, let max = maximumValue {
            summary += " Minimum observed value is \(String(format: "%.1f", min)) \(metricUnit), maximum is \(String(format: "%.1f", max)) \(metricUnit)."
        }
        if let avg = averageValue {
            summary += " Average value is \(String(format: "%.1f", avg)) \(metricUnit)."
        }
        summary += " Overall trajectory trend is \(trendDirectionDescription)."
        if !keyObservations.isEmpty {
            summary += " Key observations: " + keyObservations.joined(separator: ". ") + "."
        }
        return summary
    }
}

/// Accessible Chart Wrapper that displays a visual SwiftUI chart alongside
/// an accessible VoiceOver descriptor and an expandable Textual Data Summary.
public struct AccessibleChartContainer<ChartContent: View>: View {
    public let summary: ChartDataSummary
    public let chartContent: () -> ChartContent
    @State private var isSummaryExpanded: Bool = false

    public init(
        summary: ChartDataSummary,
        @ViewBuilder chartContent: @escaping () -> ChartContent
    ) {
        self.summary = summary
        self.chartContent = chartContent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            // Visual Chart
            chartContent()
                .accessibilityElement(children: .contain)
                .accessibilityLabel(summary.title)
                .accessibilityValue(summary.accessibilityFullSummary)

            // Textual Summary Disclosure for VoiceOver & Tabular Users
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSummaryExpanded.toggle()
                    }
                    VialrHaptics.lightImpact()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSummaryExpanded ? "chart.bar.doc.horizontal.fill" : "chart.bar.doc.horizontal")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(VialrColors.accentTeal)

                        Text(isSummaryExpanded ? "Hide Textual Chart Summary" : "View Textual Chart Summary")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentTeal)

                        Spacer()

                        Image(systemName: isSummaryExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(VialrColors.textTertiary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .accessibleTouchTarget()
                .accessibilityLabel(isSummaryExpanded ? "Hide textual summary for \(summary.title)" : "View textual summary for \(summary.title)")
                .accessibilityHint("Double tap to toggle detailed data table and statistical summary")

                if isSummaryExpanded {
                    chartSummaryDetailsCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.top, 4)
        }
    }

    private var chartSummaryDetailsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TEXTUAL DATA BREAKDOWN")
                    .font(VialrTypography.eyebrowMono)
                    .foregroundColor(VialrColors.accentTeal)
                Spacer()
                Text("\(summary.totalDataPoints) Points")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            Divider().background(VialrColors.glassBorder)

            // Statistical Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                if let cur = summary.currentValue {
                    summaryStatCell(label: "CURRENT", value: "\(String(format: "%.1f", cur)) \(summary.metricUnit)", color: VialrColors.textPrimary)
                }
                if let avg = summary.averageValue {
                    summaryStatCell(label: "AVERAGE (μ)", value: "\(String(format: "%.1f", avg)) \(summary.metricUnit)", color: VialrColors.accentCyan)
                }
                if let min = summary.minimumValue {
                    summaryStatCell(label: "MINIMUM", value: "\(String(format: "%.1f", min)) \(summary.metricUnit)", color: VialrColors.textSecondary)
                }
                if let max = summary.maximumValue {
                    summaryStatCell(label: "MAXIMUM", value: "\(String(format: "%.1f", max)) \(summary.metricUnit)", color: VialrColors.accentVitality)
                }
            }

            HStack {
                Text("TRAJECTORY:")
                    .font(VialrTypography.eyebrowMono)
                    .foregroundColor(VialrColors.textTertiary)
                Text(summary.trendDirectionDescription)
                    .font(VialrTypography.footnoteBold)
                    .foregroundColor(VialrColors.accentEmerald)
            }
            .padding(.top, 2)

            if !summary.keyObservations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KEY OBSERVATIONS")
                        .font(VialrTypography.eyebrowMono)
                        .foregroundColor(VialrColors.textTertiary)
                    ForEach(summary.keyObservations, id: \.self) { obs in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundColor(VialrColors.accentTeal)
                            Text(obs)
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textSecondary)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(VialrSpacing.sm)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusSm)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                .stroke(VialrColors.glassBorder, lineWidth: 1)
        )
    }

    private func summaryStatCell(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(VialrTypography.eyebrowMono)
                .foregroundColor(VialrColors.textTertiary)
            Text(value)
                .font(VialrTypography.monoDose)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
