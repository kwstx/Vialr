import SwiftUI

/// Vialr Color Design System: A restrained, high-contrast palette inspired by Uber and Cal AI.
/// Eliminates cluttered "medical app" blue gradients in favor of deep pitch blacks,
/// rich onyx surfaces, hairline borders, and an energetic Electric Emerald vitality accent.
public enum VialrColors {
    // MARK: - Core Foundations (Uber Monochrome & Deep Canvas)
    public static let backgroundPrimary = Color(hex: "000000") // True pitch black for OLED depth
    public static let backgroundSecondary = Color(hex: "090B0E") // Subtle elevated canvas
    public static let backgroundTertiary = Color(hex: "11141A")  // Inset grouped canvas
    
    // MARK: - Surfaces & Cards (Cal AI Frosted & Rounded Surfaces)
    public static let cardSurface = Color(hex: "13171F")         // Primary card background
    public static let cardSurfaceElevated = Color(hex: "1A202C") // Hovered / modal card surface
    public static let cardSurfaceSelected = Color(hex: "222A38") // Active selection surface
    public static let cardSurfaceSubtle = Color(hex: "0D1015")   // Inset row / container surface
    
    // MARK: - Hairline Borders (Subtle, sleek contrast)
    public static let glassBorder = Color.white.opacity(0.07)    // Standard hairline card border
    public static let subtleBorder = Color.white.opacity(0.12)   // Stronger outline border
    public static let activeBorder = Color.white.opacity(0.24)   // Focused or active border
    public static let divider = Color.white.opacity(0.06)        // Clean list dividers
    
    // MARK: - Primary Vitality Accent (Cal AI Signature Electric Emerald)
    public static let accentVitality = Color(hex: "10E79D")      // Cal AI Electric Emerald (Primary Vitality)
    public static let accentEmerald = Color(hex: "10E79D")       // Safe, completed, active adherence
    public static let accentTeal = Color(hex: "10E79D")          // Backwards compatibility alias for vitality
    
    // MARK: - Functional & Semantic Signals (Restrained)
    public static let accentAmber = Color(hex: "FF9F0A")         // Warning, low inventory, upcoming dose
    public static let accentRose = Color(hex: "FF453A")          // Critical alert, missed dose, error
    public static let accentCyan = Color(hex: "38BDF8")          // Water / reconstitution volume indicator
    public static let accentViolet = Color(hex: "A855F7")        // Longevity / cognitive marker
    public static let accentSlate = Color(hex: "64748B")         // Neutral / completed state
    
    // MARK: - Typography Hierarchy (Stark White to Zinc Slate)
    public static let textPrimary = Color(hex: "FFFFFF")         // Stark high-contrast header & body
    public static let textSecondary = Color(hex: "94A3B8")       // Clear secondary descriptions
    public static let textTertiary = Color(hex: "64748B")        // Muted helper labels & metadata
    public static let textMuted = Color(hex: "334155")           // Disabled text & subtle placeholders
    
    // MARK: - Sleek Subtle Gradients (Non-medical, dark luxury)
    public static let heroCardGradient = LinearGradient(
        colors: [Color(hex: "1A2230"), Color(hex: "111620")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let vitalityGlowGradient = LinearGradient(
        colors: [Color(hex: "10E79D"), Color(hex: "059669")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let primaryGradient = LinearGradient(
        colors: [Color(hex: "10E79D"), Color(hex: "10B981")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    public static let syringeFluidGradient = LinearGradient(
        colors: [Color(hex: "10E79D").opacity(0.85), Color(hex: "059669").opacity(0.95)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    public static let glassSurfaceGradient = LinearGradient(
        colors: [Color.white.opacity(0.04), Color.white.opacity(0.01)],
        startPoint: .top,
        endPoint: .bottom
    )
}

public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
