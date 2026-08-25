import SwiftUI

/// VialrRow: An Uber-style high-clarity list row / action cell.
public struct VialrRow: View {
    public let title: String
    public let subtitle: String?
    public let leadingIcon: String?
    public let leadingIconColor: Color
    public let trailingText: String?
    public let trailingBadge: MetricBadge?
    public let showChevron: Bool
    public let action: (() -> Void)?

    public init(
        title: String,
        subtitle: String? = nil,
        leadingIcon: String? = nil,
        leadingIconColor: Color = VialrColors.accentVitality,
        trailingText: String? = nil,
        trailingBadge: MetricBadge? = nil,
        showChevron: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = leadingIcon
        self.leadingIconColor = leadingIconColor
        self.trailingText = trailingText
        self.trailingBadge = trailingBadge
        self.showChevron = showChevron
        self.action = action
    }

    public var body: some View {
        Group {
            if let action = action {
                Button(action: {
                    VialrHaptics.lightImpact()
                    action()
                }) {
                    rowContent
                }
                .buttonStyle(VialrCardPressStyle())
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: VialrSpacing.md) {
            // Optional Leading Icon Container
            if let icon = leadingIcon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(leadingIconColor)
                    .frame(width: 38, height: 38)
                    .background(leadingIconColor.opacity(0.12))
                    .clipShape(Circle())
            }

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(VialrTypography.headline)
                    .foregroundColor(VialrColors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

            Spacer()

            // Trailing Accessories
            if let badge = trailingBadge {
                badge
            } else if let trailingText = trailingText {
                Text(trailingText)
                    .font(VialrTypography.bodyMedium)
                    .foregroundColor(VialrColors.textSecondary)
            }

            if showChevron && action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(VialrColors.textMuted)
                    .padding(.leading, 2)
            }
        }
        .padding(.horizontal, VialrSpacing.md)
        .padding(.vertical, VialrSpacing.sm + 2)
        .background(VialrColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous)
                .stroke(VialrColors.glassBorder, lineWidth: 0.8)
        )
    }
}
