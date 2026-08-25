import SwiftUI

public enum CardStyleType: Sendable {
    case elevated
    case outlined
    case glass
    case hero
}

public struct VialrCard<Content: View>: View {
    public let style: CardStyleType
    public let padding: CGFloat
    public let cornerRadius: CGFloat
    public let content: () -> Content

    public init(
        style: CardStyleType = .elevated,
        padding: CGFloat = VialrSpacing.cardPadding,
        cornerRadius: CGFloat = VialrSpacing.radiusLg,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: style == .elevated ? Color.black.opacity(0.35) : Color.clear,
                radius: 12,
                x: 0,
                y: 6
            )
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .elevated:
            VialrColors.cardSurfaceElevated
        case .outlined:
            VialrColors.cardSurface
        case .glass:
            VialrColors.cardSurface.opacity(0.7)
                .background(.ultraThinMaterial)
        case .hero:
            VialrColors.heroCardGradient
        }
    }

    private var borderColor: Color {
        switch style {
        case .elevated:
            return VialrColors.subtleBorder
        case .outlined:
            return VialrColors.glassBorder
        case .glass:
            return VialrColors.subtleBorder
        case .hero:
            return VialrColors.accentTeal.opacity(0.25)
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .elevated, .glass:
            return 1.0
        case .outlined:
            return 1.0
        case .hero:
            return 1.5
        }
    }
}
