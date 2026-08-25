import SwiftUI

/// VialrEmptyStateView: Cal AI spacious empty state with large typography and clean primary action.
public struct VialrEmptyStateView: View {
    public let icon: VialrIconType
    public let title: String
    public let message: String
    public let actionTitle: String?
    public let action: (() -> Void)?

    public init(
        icon: VialrIconType,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: VialrSpacing.md) {
            VialrIcon(
                icon,
                tintColor: VialrColors.accentVitality,
                backgroundColor: VialrColors.accentVitality.opacity(0.12),
                size: 26
            )
            .padding(.bottom, VialrSpacing.xs)

            Text(title)
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(VialrTypography.body)
                .foregroundColor(VialrColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VialrSpacing.xl)

            if let actionTitle = actionTitle, let action = action {
                VialrButton(actionTitle, style: .primary, size: .standard, isFullWidth: false, action: action)
                    .padding(.top, VialrSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VialrSpacing.xxxl)
    }
}

/// VialrSectionHeader: Uber-style section title with optional micro action button.
public struct VialrSectionHeader: View {
    public let title: String
    public let actionTitle: String?
    public let action: (() -> Void)?

    public init(
        _ title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)
            Spacer()
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    VialrHaptics.lightImpact()
                    action()
                }) {
                    Text(actionTitle)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.accentVitality)
                }
            }
        }
        .padding(.horizontal, VialrSpacing.screenHorizontal)
    }
}
