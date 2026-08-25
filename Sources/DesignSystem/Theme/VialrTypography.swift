import SwiftUI

public enum VialrTypography {
    // Hero & Displays
    public static let largeHero = Font.system(size: 34, weight: .bold, design: .rounded)
    public static let title1 = Font.system(size: 26, weight: .bold, design: .default)
    public static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
    public static let title3 = Font.system(size: 19, weight: .semibold, design: .default)
    
    // Body & Content
    public static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    public static let body = Font.system(size: 15, weight: .regular, design: .default)
    public static let bodyMedium = Font.system(size: 15, weight: .medium, design: .default)
    public static let subheadline = Font.system(size: 13, weight: .regular, design: .default)
    public static let footnote = Font.system(size: 12, weight: .medium, design: .default)
    public static let caption = Font.system(size: 11, weight: .regular, design: .default)
    public static let captionBold = Font.system(size: 11, weight: .bold, design: .default)
    
    // Numerical & Metrics
    public static let metricLarge = Font.system(size: 38, weight: .bold, design: .rounded)
    public static let metricMedium = Font.system(size: 26, weight: .bold, design: .rounded)
    public static let metricSmall = Font.system(size: 18, weight: .semibold, design: .rounded)
    public static let monoDose = Font.system(size: 16, weight: .semibold, design: .monospaced)
    public static let monoSub = Font.system(size: 12, weight: .regular, design: .monospaced)
}
