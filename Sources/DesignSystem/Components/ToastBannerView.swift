import SwiftUI

public struct ToastMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let message: String?
    public let type: ToastType
    public let duration: Double

    public init(
        id: UUID = UUID(),
        title: String,
        message: String? = nil,
        type: ToastType = .success,
        duration: Double = 3.0
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.type = type
        self.duration = duration
    }
}

public enum ToastType: Sendable {
    case success
    case error
    case warning
    case info

    public var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .success: return VialrColors.accentVitality
        case .error: return VialrColors.accentRose
        case .warning: return VialrColors.accentAmber
        case .info: return VialrColors.textSecondary
        }
    }
}

/// ToastBannerView: Floating dark pill toast with hairline border and haptic feedback.
/// Fully accessible with automatic screen reader announcements and 44pt touch targets.
public struct ToastBannerView: View {
    public let toast: ToastMessage
    public let onDismiss: () -> Void

    public init(toast: ToastMessage, onDismiss: @escaping () -> Void) {
        self.toast = toast
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: VialrSpacing.sm) {
            Image(systemName: toast.type.iconName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(toast.type.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(VialrTypography.headline)
                    .foregroundColor(VialrColors.textPrimary)

                if let msg = toast.message, !msg.isEmpty {
                    Text(msg)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

            Spacer()

            Button {
                VialrHaptics.lightImpact()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(VialrColors.textTertiary)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .minTouchTarget(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Dismiss notification")
            .accessibilityHint("Double tap to close banner")
        }
        .padding(.horizontal, VialrSpacing.md)
        .padding(.vertical, VialrSpacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusLg, style: .continuous)
                .fill(VialrColors.cardSurfaceElevated)
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusLg, style: .continuous)
                .stroke(VialrColors.subtleBorder, lineWidth: 0.8)
        )
        .padding(.horizontal, VialrSpacing.screenHorizontal)
        .onAppear {
            VialrAccessibilityNotifier.announce("\(toast.title). \(toast.message ?? "")")
        }
    }
}
