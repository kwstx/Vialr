import SwiftUI

/// Vialr Spacing & Layout System: Generous whitespace inspired by Cal AI & Uber.
/// Expands card paddings, screen margins, and corner radii to provide high-end breathing room.
public enum VialrSpacing {
    // MARK: - Spacing Scale
    public static let xxxs: CGFloat = 2
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48
    public static let huge: CGFloat = 64
    
    // MARK: - Generous Screen & Container Tokens
    public static let screenHorizontal: CGFloat = 20  // Generous outer screen margin
    public static let cardPadding: CGFloat = 20       // Cal AI signature roomy card padding
    public static let cardPaddingCompact: CGFloat = 14 // Dense widgets / list tiles
    public static let sectionSpacing: CGFloat = 28     // Space between distinct content blocks
    public static let interItemSpacing: CGFloat = 14   // Space between adjacent cards
    public static let buttonHeight: CGFloat = 54       // Uber standard tall touch target
    public static let buttonHeightSm: CGFloat = 42     // Secondary compact touch target
    public static let minTouchTarget: CGFloat = 44     // Apple HIG accessible minimum hit target
    
    // MARK: - Signature Rounded Corner Radii (Cal AI Curves)
    public static let radiusXs: CGFloat = 6
    public static let radiusSm: CGFloat = 10
    public static let radiusMd: CGFloat = 16
    public static let radiusLg: CGFloat = 22           // Cal AI signature rounded card curve
    public static let radiusXl: CGFloat = 28
    public static let radiusPill: CGFloat = 999        // Uber / Cal AI pill shape
}

public struct VialrCardStyle: ViewModifier {
    var isElevated: Bool = false
    var isSelected: Bool = false
    var cornerRadius: CGFloat = VialrSpacing.radiusLg

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isSelected ? VialrColors.cardSurfaceSelected : (isElevated ? VialrColors.cardSurfaceElevated : VialrColors.cardSurface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isSelected ? VialrColors.accentVitality.opacity(0.8) : VialrColors.glassBorder, lineWidth: isSelected ? 1.5 : 1)
            )
    }
}

public extension View {
    func vialrCard(isElevated: Bool = false, isSelected: Bool = false, cornerRadius: CGFloat = VialrSpacing.radiusLg) -> some View {
        self.modifier(VialrCardStyle(isElevated: isElevated, isSelected: isSelected, cornerRadius: cornerRadius))
    }
}
