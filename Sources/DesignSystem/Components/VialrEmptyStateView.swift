import SwiftUI

/// VialrEmptyStateView: Cal AI spacious empty state with large typography and clean primary action.
/// Accessible with heading traits, scalable typography, and clear action button labels.
public struct VialrEmptyStateView: View {
    public let iconName: String
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
        self.iconName = icon.rawValue
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public init(
        iconName: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.iconName = iconName
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: VialrSpacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(VialrColors.accentVitality)
                .frame(width: 52, height: 52)
                .background(VialrColors.accentVitality.opacity(0.12))
                .clipShape(Circle())
                .padding(.bottom, VialrSpacing.xs)
                .accessibilityHidden(true)

            Text(title)
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(VialrTypography.body)
                .foregroundColor(VialrColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VialrSpacing.xl)

            if let actionTitle = actionTitle, let action = action {
                VialrButton(
                    actionTitle,
                    style: .primary,
                    size: .standard,
                    isFullWidth: false,
                    accessibilityLabel: actionTitle,
                    accessibilityHint: "Double tap to \(actionTitle.lowercased())",
                    action: action
                )
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
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    VialrHaptics.lightImpact()
                    action()
                }) {
                    Text(actionTitle)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.accentVitality)
                        .frame(minHeight: VialrSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(actionTitle)
                .accessibilityHint("Double tap to \(actionTitle.lowercased())")
            }
        }
        .padding(.horizontal, VialrSpacing.screenHorizontal)
    }
}
