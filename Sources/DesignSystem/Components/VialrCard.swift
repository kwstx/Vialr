import SwiftUI

public enum CardStyleType: Sendable {
    case elevated   // Default Cal AI rounded card with subtle hairline stroke
    case surface    // Flat surface card
    case outlined   // Stark outline card (Uber style)
    case glass      // Subtle frosted backdrop
    case hero       // Dark luxury gradient card
    case interactive // Card with hover / press scaling
}

/// VialrCard: The signature surface primitive combining Cal AI rounded curves (`22pt`)
/// and Uber hairline borders (`white.opacity(0.08)`).
public struct VialrCard<Content: View>: View {
    public let style: CardStyleType
    public let padding: CGFloat
    public let cornerRadius: CGFloat
    public let onTap: (() -> Void)?
    public let content: () -> Content

    public init(
        style: CardStyleType = .elevated,
        padding: CGFloat = VialrSpacing.cardPadding,
        cornerRadius: CGFloat = VialrSpacing.radiusLg,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.onTap = onTap
        self.content = content
    }

    public var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: {
                    VialrHaptics.lightImpact()
                    onTap()
                }) {
                    cardBody
                }
                .buttonStyle(VialrCardPressStyle())
            } else {
                cardBody
            }
        }
    }

    private var cardBody: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: style == .elevated ? Color.black.opacity(0.25) : Color.clear,
                radius: 10,
                x: 0,
                y: 4
            )
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .elevated:
            VialrColors.cardSurface
        case .surface:
            VialrColors.cardSurfaceSubtle
        case .outlined:
            VialrColors.cardSurface
        case .glass:
            VialrColors.cardSurfaceElevated.opacity(0.8)
                .background(.ultraThinMaterial)
        case .hero:
            VialrColors.heroCardGradient
        case .interactive:
            VialrColors.cardSurface
        }
    }

    private var borderColor: Color {
        switch style {
        case .elevated, .surface:
            return VialrColors.glassBorder
        case .outlined:
            return VialrColors.subtleBorder
        case .glass:
            return VialrColors.glassBorder
        case .hero:
            return VialrColors.subtleBorder
        case .interactive:
            return VialrColors.glassBorder
        }
    }

    private var borderWidth: CGFloat {
        return 0.8
    }
}

// MARK: - Card Press Animation Style
public struct VialrCardPressStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
