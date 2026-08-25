import SwiftUI

public enum ButtonStyleType {
    case primary      // Uber High-Contrast (Stark White fill + Black text)
    case vitality     // Cal AI High-Energy (Electric Emerald fill + Black text)
    case secondary    // Inset Card fill + White text
    case outline      // Subtle Border + White text
    case ghost        // Clean Text + Vitality Emerald
    case destructive  // Solid Alert Rose
    case destructiveOutline // Bordered Alert Rose
}

public enum ButtonSize {
    case standard // 54pt height (Uber standard large tap area)
    case compact  // 42pt height (In-card actions)
    case pill     // Rounded pill mini-button
}

/// VialrButton: Tactile, high-contrast action button modeled after Uber and Cal AI.
public struct VialrButton: View {
    public let title: String
    public let icon: String?
    public let style: ButtonStyleType
    public let size: ButtonSize
    public let isFullWidth: Bool
    public let isLoading: Bool
    public let isDisabled: Bool
    public let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyleType = .primary,
        size: ButtonSize = .standard,
        isFullWidth: Bool = true,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isFullWidth = isFullWidth
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(action: {
            VialrHaptics.mediumImpact()
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
                            .font(.system(size: iconSize, weight: .bold))
                    }
                    Text(title)
                        .font(titleFont)
                        .tracking(0.2)
                }
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: height)
            .padding(.horizontal, isFullWidth ? 0 : 20)
            .foregroundColor(textColor)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(VialrButtonPressStyle())
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.4 : 1.0)
    }

    private var height: CGFloat {
        switch size {
        case .standard: return VialrSpacing.buttonHeight
        case .compact: return VialrSpacing.buttonHeightSm
        case .pill: return 36
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .standard: return VialrSpacing.radiusMd
        case .compact: return VialrSpacing.radiusSm
        case .pill: return VialrSpacing.radiusPill
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .standard: return 16
        case .compact: return 14
        case .pill: return 12
        }
    }

    private var titleFont: Font {
        switch size {
        case .standard: return VialrTypography.headline
        case .compact: return VialrTypography.footnote
        case .pill: return VialrTypography.captionBold
        }
    }

    private var textColor: Color {
        switch style {
        case .primary:
            return Color.black
        case .vitality:
            return Color.black
        case .secondary:
            return VialrColors.textPrimary
        case .outline:
            return VialrColors.textPrimary
        case .ghost:
            return VialrColors.accentVitality
        case .destructive:
            return Color.white
        case .destructiveOutline:
            return VialrColors.accentRose
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Color.white
        case .vitality:
            VialrColors.accentVitality
        case .secondary:
            VialrColors.cardSurfaceElevated
        case .outline, .ghost:
            Color.clear
        case .destructive:
            VialrColors.accentRose
        case .destructiveOutline:
            VialrColors.accentRose.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch style {
        case .outline:
            return VialrColors.subtleBorder
        case .secondary:
            return VialrColors.glassBorder
        case .destructiveOutline:
            return VialrColors.accentRose.opacity(0.4)
        default:
            return Color.clear
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .outline, .secondary, .destructiveOutline:
            return 1.0
        default:
            return 0.0
        }
    }
}

// MARK: - Button Press Spring Animation
public struct VialrButtonPressStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
