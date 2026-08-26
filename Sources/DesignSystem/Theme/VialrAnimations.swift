import SwiftUI

/// Vialr subtle animation system: Restrained, physical spring animations that make interactions
/// feel fluid, fast, and tactile without flashy distractions or prolonged waiting periods.
public enum VialrAnimations {
    /// Standard snappy spring for interactive controls (toggles, tabs, buttons, chips)
    public static var snappy: Animation {
        .spring(response: 0.26, dampingFraction: 0.82)
    }

    /// Subtle smooth spring for card expansions, sheet transitions, and layout reflows
    public static var subtle: Animation {
        .spring(response: 0.36, dampingFraction: 0.86)
    }

    /// Gentle hero spring for high-impact metric counters and status badge shifts
    public static var hero: Animation {
        .spring(response: 0.45, dampingFraction: 0.88)
    }

    /// Ultra-fast feedback animation for dosage stepper increments and instant logging
    public static var instant: Animation {
        .spring(response: 0.18, dampingFraction: 0.75)
    }

    // MARK: - Transitions
    /// Clean scale + opacity transition for modal bottom sheets and contextual callouts
    public static var modalTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.97).combined(with: .opacity),
            removal: .scale(scale: 0.98).combined(with: .opacity)
        )
    }

    /// Bottom sheet slide + fade
    public static var sheetTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }
}

// MARK: - Subtle Pulse Modifier for Action-Required Cards
public struct ActionRequiredPulseModifier: ViewModifier {
    @State private var isPulsing: Bool = false

    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusLg, style: .continuous)
                    .stroke(VialrColors.accentVitality.opacity(isPulsing ? 0.45 : 0.15), lineWidth: 1.5)
                    .scaleEffect(isPulsing ? 1.006 : 1.0)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: isPulsing)
            )
            .onAppear {
                isPulsing = true
            }
    }
}

public extension View {
    func actionRequiredPulse() -> some View {
        self.modifier(ActionRequiredPulseModifier())
    }
}
