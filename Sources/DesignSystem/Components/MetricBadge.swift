import SwiftUI

public enum BadgeVariant: Sendable {
    case success(String)
    case warning(String)
    case error(String)
    case info(String)
    case neutral(String)
    case custom(title: String, color: Color, icon: String?)
}

/// MetricBadge: Minimalist Cal AI / Uber pill badge with restrained tint and hairline border.
public struct MetricBadge: View {
    public let variant: BadgeVariant
    public let showDot: Bool

    public init(_ variant: BadgeVariant, showDot: Bool = true) {
        self.variant = variant
        self.showDot = showDot
    }

    public var body: some View {
        HStack(spacing: 5) {
            if showDot {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 5, height: 5)
            } else if let icon = iconName {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(title)
                .font(VialrTypography.captionBold)
                .tracking(0.3)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundColor(badgeColor)
        .background(badgeColor.opacity(0.12))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(badgeColor.opacity(0.22), lineWidth: 0.8)
        )
    }

    private var title: String {
        switch variant {
        case .success(let t): return t
        case .warning(let t): return t
        case .error(let t): return t
        case .info(let t): return t
        case .neutral(let t): return t
        case .custom(let t, _, _): return t
        }
    }

    private var iconName: String? {
        switch variant {
        case .success: return "checkmark"
        case .warning: return "exclamationmark"
        case .error: return "xmark"
        case .info: return "info"
        case .neutral: return nil
        case .custom(_, _, let icon): return icon
        }
    }

    private var badgeColor: Color {
        switch variant {
        case .success: return VialrColors.accentVitality
        case .warning: return VialrColors.accentAmber
        case .error: return VialrColors.accentRose
        case .info: return VialrColors.textSecondary
        case .neutral: return VialrColors.textSecondary
        case .custom(_, let color, _): return color
        }
    }
}
