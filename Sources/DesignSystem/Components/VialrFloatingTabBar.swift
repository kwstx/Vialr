import SwiftUI
import Domain

/// Modern, sleek floating island Tab Bar with high-contrast OLED black canvas,
/// frosted elevated surface, subtle hairline glass border, and a prominent elevated center Log action.
public struct VialrFloatingTabBar: View {
    @Binding public var selectedTab: AppTab
    public var onSelectTab: (AppTab) -> Void
    public var onProminentAction: () -> Void

    @Namespace private var tabNamespace

    public init(
        selectedTab: Binding<AppTab>,
        onSelectTab: @escaping (AppTab) -> Void,
        onProminentAction: @escaping () -> Void
    ) {
        self._selectedTab = selectedTab
        self.onSelectTab = onSelectTab
        self.onProminentAction = onProminentAction
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                if tab == .log {
                    // MARK: - Prominent Elevated Center Log Action
                    prominentCenterLogButton
                } else {
                    // MARK: - Standard Tab Button
                    standardTabButton(for: tab)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusPill, style: .continuous)
                .fill(VialrColors.cardSurfaceElevated.opacity(0.96))
                .shadow(color: Color.black.opacity(0.55), radius: 28, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusPill, style: .continuous)
                .stroke(VialrColors.glassBorder, lineWidth: 1)
        )
        .padding(.horizontal, VialrSpacing.md)
        .padding(.bottom, 6)
    }

    // MARK: - Standard Tab Button
    private func standardTabButton(for tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            VialrHaptics.selection()
            onSelectTab(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? tab.selectedIconName : tab.iconName)
                    .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? VialrColors.accentVitality : VialrColors.textTertiary)
                    .frame(height: 22)

                Text(tab.rawValue)
                    .font(VialrTypography.caption)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? VialrColors.textPrimary : VialrColors.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }

    // MARK: - Prominent Elevated Center Log Action
    private var prominentCenterLogButton: some View {
        let isSelected = selectedTab == .log

        return Button {
            VialrHaptics.mediumImpact()
            if isSelected {
                onProminentAction()
            } else {
                onSelectTab(.log)
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(VialrColors.vitalityGlowGradient)
                        .frame(width: 44, height: 44)
                        .shadow(color: VialrColors.accentVitality.opacity(0.4), radius: 10, x: 0, y: 3)

                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(Color.black)
                }
                .offset(y: -8) // Subtle elevation above the pill bar

                Text("Log")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(isSelected ? VialrColors.accentVitality : VialrColors.textPrimary)
                    .offset(y: -6)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log Dose - Instant Entry Action")
        .accessibilityHint("Double tap to quickly log a dose or view logging history")
    }
}
