import SwiftUI

/// VialrMetricCard: The signature Cal AI metric stat card.
/// Combines an uppercase micro-eyebrow, massive numerical focus, precision unit,
/// and an optional contextual status badge or minimal progress indicator.
public struct VialrMetricCard: View {
    public let eyebrow: String
    public let value: String
    public let unit: String?
    public let subtitle: String?
    public let badge: MetricBadge?
    public let progress: Double? // 0.0 to 1.0
    public let progressColor: Color
    public let style: CardStyleType
    public let onTap: (() -> Void)?

    public init(
        eyebrow: String,
        value: String,
        unit: String? = nil,
        subtitle: String? = nil,
        badge: MetricBadge? = nil,
        progress: Double? = nil,
        progressColor: Color = VialrColors.accentVitality,
        style: CardStyleType = .elevated,
        onTap: (() -> Void)? = nil
    ) {
        self.eyebrow = eyebrow
        self.value = value
        self.unit = unit
        self.subtitle = subtitle
        self.badge = badge
        self.progress = progress
        self.progressColor = progressColor
        self.style = style
        self.onTap = onTap
    }

    public var body: some View {
        VialrCard(style: style, padding: VialrSpacing.cardPadding, onTap: onTap) {
            VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                // Header: Eyebrow + Optional Badge
                HStack(alignment: .center) {
                    Text(eyebrow)
                        .vialrEyebrow()
                    Spacer()
                    if let badge = badge {
                        badge
                    }
                }

                // Metric Hero Value + Unit
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(VialrTypography.metricLarge)
                        .foregroundColor(VialrColors.textPrimary)
                        .tracking(-0.5)

                    if let unit = unit {
                        Text(unit)
                            .font(VialrTypography.title3)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                }
                .padding(.vertical, 2)

                // Optional Progress Bar
                if let progress = progress {
                    VialrProgressBar(value: progress, tintColor: progressColor)
                        .padding(.top, 2)
                }

                // Optional Subtitle
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }
        }
    }
}
