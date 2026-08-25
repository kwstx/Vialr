import SwiftUI

public enum ButtonStyleType {
    case primary
    case secondary
    case destructive
    case ghost
    case outline
}

public struct VialrButton: View {
    public let title: String
    public let icon: String?
    public let style: ButtonStyleType
    public let isLoading: Bool
    public let isDisabled: Bool
    public let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyleType = .primary,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(action: {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            action()
        }) {
            HStack(spacing: VialrSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(textColor)
                        .scaleEffect(0.9)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(title)
                        .font(VialrTypography.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundColor(textColor)
            .background(backgroundView)
            .cornerRadius(VialrSpacing.radiusMd)
            .overlay(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                    .stroke(borderColor, lineWidth: style == .outline ? 1.5 : 0)
            )
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.45 : 1.0)
    }

    private var textColor: Color {
        switch style {
        case .primary: return Color.black
        case .secondary: return VialrColors.textPrimary
        case .destructive: return Color.white
        case .ghost: return VialrColors.accentTeal
        case .outline: return VialrColors.textPrimary
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            VialrColors.primaryGradient
        case .secondary:
            VialrColors.cardSurfaceElevated
        case .destructive:
            VialrColors.accentRose
        case .ghost:
            Color.clear
        case .outline:
            Color.clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .outline:
            return VialrColors.subtleBorder
        default:
            return Color.clear
        }
    }
}
