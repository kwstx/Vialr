import SwiftUI

public enum BadgeVariant {
    case success(String)
    case warning(String)
    case error(String)
    case info(String)
    case neutral(String)
    case custom(title: String, color: Color, icon: String?)
}

public struct MetricBadge: View {
    public let variant: BadgeVariant

    public init(_ variant: BadgeVariant) {
        self.variant = variant
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon = iconName {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(title)
                .font(VialrTypography.captionBold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(badgeColor)
        .background(badgeColor.opacity(0.14))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(badgeColor.opacity(0.28), lineWidth: 0.8)
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
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .neutral: return nil
        case .custom(_, _, let icon): return icon
        }
    }

    private var badgeColor: Color {
        switch variant {
        case .success: return VialrColors.accentEmerald
        case .warning: return VialrColors.accentAmber
        case .error: return VialrColors.accentRose
        case .info: return VialrColors.accentCyan
        case .neutral: return VialrColors.textSecondary
        case .custom(_, let color, _): return color
        }
    }
}
