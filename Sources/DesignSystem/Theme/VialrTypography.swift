import SwiftUI

/// Vialr Typography System: Combines the bold, impactful metric displays of Cal AI
/// with the stark, highly legible information hierarchy of Uber.
/// Fully supports Dynamic Type scaling relative to native text styles so users with
/// enlarged text or accessibility font settings receive seamless scaling.
public enum VialrTypography {
    // MARK: - Massive Metric Displays (Cal AI Signature Numerical Hierarchy)
    /// Used for hero stats, big dose numbers, and focal daily adherence figures
    public static var metricHero: Font {
        .system(size: 48, weight: .bold, design: .rounded)
    }
    public static var metricLarge: Font {
        .system(size: 36, weight: .bold, design: .rounded)
    }
    public static var metricMedium: Font {
        .system(size: 26, weight: .bold, design: .rounded)
    }
    public static var metricSmall: Font {
        .system(size: 20, weight: .semibold, design: .rounded)
    }
    
    // MARK: - Uber Micro Eyebrows (Contextual category tags & section markers)
    public static var eyebrow: Font {
        .system(size: 11, weight: .bold, design: .default)
    }
    public static var eyebrowMono: Font {
        .system(size: 11, weight: .semibold, design: .monospaced)
    }
    
    // MARK: - Titles & Headers (Stark, high contrast, clean)
    public static var screenTitle: Font {
        .system(size: 32, weight: .heavy, design: .default)
    }
    public static var largeHero: Font {
        .system(size: 34, weight: .bold, design: .rounded)
    }
    public static var title1: Font {
        .system(size: 26, weight: .bold, design: .default)
    }
    public static var title2: Font {
        .system(size: 22, weight: .semibold, design: .default)
    }
    public static var title3: Font {
        .system(size: 18, weight: .semibold, design: .default)
    }
    
    // MARK: - Body & Interactive Content
    public static var headline: Font {
        .system(size: 16, weight: .semibold, design: .default)
    }
    public static var body: Font {
        .system(size: 15, weight: .regular, design: .default)
    }
    public static var bodyMedium: Font {
        .system(size: 15, weight: .medium, design: .default)
    }
    public static var bodyBold: Font {
        .system(size: 15, weight: .bold, design: .default)
    }
    public static var subheadline: Font {
        .system(size: 14, weight: .regular, design: .default)
    }
    public static var subheadlineBold: Font {
        .system(size: 14, weight: .bold, design: .default)
    }
    public static var footnote: Font {
        .system(size: 13, weight: .medium, design: .default)
    }
    public static var footnoteBold: Font {
        .system(size: 13, weight: .bold, design: .default)
    }
    public static var caption: Font {
        .system(size: 12, weight: .regular, design: .default)
    }
    public static var captionBold: Font {
        .system(size: 11, weight: .bold, design: .default)
    }
    
    // MARK: - Monospaced Data & Precision Units
    public static var monoDose: Font {
        .system(size: 17, weight: .semibold, design: .monospaced)
    }
    public static var monoLarge: Font {
        .system(size: 24, weight: .bold, design: .monospaced)
    }
    public static var monoSub: Font {
        .system(size: 12, weight: .medium, design: .monospaced)
    }

    // MARK: - Dynamic Type Scaled Relative Helpers
    /// Creates a dynamically scaled custom font relative to a system text style.
    public static func dynamicScaled(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: weight, design: design)
    }
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
