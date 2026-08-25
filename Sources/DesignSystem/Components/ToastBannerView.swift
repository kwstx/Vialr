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
        case .success: return VialrColors.accentEmerald
        case .error: return VialrColors.accentRose
        case .warning: return VialrColors.accentAmber
        case .info: return VialrColors.accentCyan
        }
    }
}

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
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(toast.type.color)

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
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(VialrColors.textTertiary)
                    .padding(6)
            }
        }
        .padding(.horizontal, VialrSpacing.md)
        .padding(.vertical, VialrSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous)
                .fill(VialrColors.cardSurfaceElevated)
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous)
                .stroke(toast.type.color.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, VialrSpacing.md)
    }
}
