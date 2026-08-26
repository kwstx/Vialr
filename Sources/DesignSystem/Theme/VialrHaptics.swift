import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Vialr Haptics: Tactile feedback system that mimics the crisp, premium response of Uber & Cal AI.
/// Provides immediate, distinct physical confirmation for dose logging, adjustments, warnings, and errors.
public enum VialrHaptics {
    /// Crisp selection click for tab switching, segmented control changes, and chip selection
    public static func selection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }

    /// Subtle light tap for dosage steppers, fine increments, and date selections
    public static func lightImpact() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    /// Medium tactile thud for primary button taps, modal opens, and bottom sheet presentation
    public static func mediumImpact() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    /// Solid heavy impact for critical state changes or destructive actions
    public static func heavyImpact() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    /// Primary success feedback: Fired immediately on successful dose logging, completed setup flows, and saved items
    public static func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }

    /// Warning feedback for skipped doses, low stock alerts, or missed schedules
    public static func warning() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }

    /// Error feedback for validation failures, calculation errors, or network issues
    public static func error() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
        #endif
    }

    /// Dose confirmed haptic feedback (double pulse: medium impact followed by success)
    public static func doseConfirmed() {
        #if os(iOS)
        mediumImpact()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            success()
        }
        #endif
    }
}
