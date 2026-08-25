import SwiftUI

public enum VialrColors {
    // Backgrounds
    public static let backgroundPrimary = Color(hex: "0A0D12")
    public static let backgroundSecondary = Color(hex: "12161F")
    public static let backgroundTertiary = Color(hex: "1A202C")
    
    // Surfaces & Cards
    public static let cardSurface = Color(hex: "151A24")
    public static let cardSurfaceElevated = Color(hex: "1E2432")
    public static let cardSurfaceSelected = Color(hex: "242C3D")
    public static let glassBorder = Color.white.opacity(0.08)
    public static let subtleBorder = Color.white.opacity(0.12)
    
    // Accents & Vibrant Signals
    public static let accentEmerald = Color(hex: "10B981") // Vitality, safe, completed
    public static let accentTeal = Color(hex: "14B8A6")    // Active protocol, primary branding
    public static let accentCyan = Color(hex: "06B6D4")    // Reconstitution, water
    public static let accentAmber = Color(hex: "F59E0B")   // Low stock, warning, scheduled
    public static let accentRose = Color(hex: "F43F5E")    // Missed dose, critical alert
    public static let accentViolet = Color(hex: "8B5CF6")  // Nootropic / Longevity
    public static let accentIndigo = Color(hex: "6366F1")  // Bloodwork / Analytics
    
    // Text & Content
    public static let textPrimary = Color.white
    public static let textSecondary = Color(hex: "94A3B8")
    public static let textTertiary = Color(hex: "64748B")
    public static let textMuted = Color(hex: "475569")
    
    // Gradients
    public static let primaryGradient = LinearGradient(
        colors: [Color(hex: "10B981"), Color(hex: "06B6D4")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let heroCardGradient = LinearGradient(
        colors: [Color(hex: "1E293B"), Color(hex: "0F172A")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let syringeFluidGradient = LinearGradient(
        colors: [Color(hex: "06B6D4").opacity(0.8), Color(hex: "10B981").opacity(0.9)],
        startPoint: .leading,
        endPoint: .trailing
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
