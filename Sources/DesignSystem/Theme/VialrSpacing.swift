import SwiftUI

public enum VialrSpacing {
    public static let xxxs: CGFloat = 2
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48
    
    // Corner Radii
    public static let radiusSm: CGFloat = 8
    public static let radiusMd: CGFloat = 14
    public static let radiusLg: CGFloat = 20
    public static let radiusXl: CGFloat = 28
    public static let radiusPill: CGFloat = 999
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
                    .stroke(isSelected ? VialrColors.accentTeal.opacity(0.8) : VialrColors.glassBorder, lineWidth: isSelected ? 1.5 : 1)
            )
    }
}

public extension View {
    func vialrCard(isElevated: Bool = false, isSelected: Bool = false, cornerRadius: CGFloat = VialrSpacing.radiusLg) -> some View {
        self.modifier(VialrCardStyle(isElevated: isElevated, isSelected: isSelected, cornerRadius: cornerRadius))
    }
}
