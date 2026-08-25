import SwiftUI

/// Vialr Typography System: Combines the bold, impactful metric displays of Cal AI
/// with the stark, highly legible information hierarchy of Uber.
public enum VialrTypography {
    // MARK: - Massive Metric Displays (Cal AI Signature Numerical Hierarchy)
    /// Used for hero stats, big dose numbers, and focal daily adherence figures
    public static let metricHero = Font.system(size: 48, weight: .bold, design: .rounded)
    public static let metricLarge = Font.system(size: 36, weight: .bold, design: .rounded)
    public static let metricMedium = Font.system(size: 26, weight: .bold, design: .rounded)
    public static let metricSmall = Font.system(size: 20, weight: .semibold, design: .rounded)
    
    // MARK: - Uber Micro Eyebrows (Contextual category tags & section markers)
    public static let eyebrow = Font.system(size: 11, weight: .bold, design: .default)
    public static let eyebrowMono = Font.system(size: 11, weight: .semibold, design: .monospaced)
    
    // MARK: - Titles & Headers (Stark, high contrast, clean)
    public static let screenTitle = Font.system(size: 32, weight: .heavy, design: .default)
    public static let largeHero = Font.system(size: 34, weight: .bold, design: .rounded)
    public static let title1 = Font.system(size: 26, weight: .bold, design: .default)
    public static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
    public static let title3 = Font.system(size: 18, weight: .semibold, design: .default)
    
    // MARK: - Body & Interactive Content
    public static let headline = Font.system(size: 16, weight: .semibold, design: .default)
    public static let body = Font.system(size: 15, weight: .regular, design: .default)
    public static let bodyMedium = Font.system(size: 15, weight: .medium, design: .default)
    public static let subheadline = Font.system(size: 14, weight: .regular, design: .default)
    public static let footnote = Font.system(size: 13, weight: .medium, design: .default)
    public static let caption = Font.system(size: 12, weight: .regular, design: .default)
    public static let captionBold = Font.system(size: 11, weight: .bold, design: .default)
    
    // MARK: - Monospaced Data & Precision Units
    public static let monoDose = Font.system(size: 17, weight: .semibold, design: .monospaced)
    public static let monoLarge = Font.system(size: 24, weight: .bold, design: .monospaced)
    public static let monoSub = Font.system(size: 12, weight: .medium, design: .monospaced)
}

// MARK: - Text Modifiers for Consistent Uber & Cal AI Styling
public struct EyebrowModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(VialrTypography.eyebrow)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundColor(VialrColors.textTertiary)
    }
}

public extension View {
    func vialrEyebrow() -> some View {
        self.modifier(EyebrowModifier())
    }
}
