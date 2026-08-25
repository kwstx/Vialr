import SwiftUI

public struct SiteSelectionItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let shortLabel: String
    public let daysSinceLastUse: Int?
    public let isRecommended: Bool

    public init(id: String, name: String, shortLabel: String, daysSinceLastUse: Int? = nil, isRecommended: Bool = false) {
        self.id = id
        self.name = name
        self.shortLabel = shortLabel
        self.daysSinceLastUse = daysSinceLastUse
        self.isRecommended = isRecommended
    }
}

/// BodyMapSelectorView: Anatomical injection site rotation with clear rested status signals.
public struct BodyMapSelectorView: View {
    public let sites: [SiteSelectionItem]
    @Binding public var selectedSiteId: String?
    public var onSelect: ((SiteSelectionItem) -> Void)?

    public init(
        sites: [SiteSelectionItem],
        selectedSiteId: Binding<String?>,
        onSelect: ((SiteSelectionItem) -> Void)? = nil
    ) {
        self.sites = sites
        self._selectedSiteId = selectedSiteId
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: VialrSpacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("INJECTION SITE ROTATION")
                        .vialrEyebrow()
                    Text("Select Target Site")
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                }
                Spacer()
                
                // Rotation Status Legend
                HStack(spacing: 8) {
                    Circle()
                        .fill(VialrColors.accentVitality)
                        .frame(width: 6, height: 6)
                    Text("Rested")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)

                    Circle()
                        .fill(VialrColors.accentAmber)
                        .frame(width: 6, height: 6)
                    Text("Recent")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

            // Anatomical Grid
            VStack(spacing: VialrSpacing.sm) {
                // Deltoids (Upper Body)
                HStack(spacing: VialrSpacing.sm) {
                    siteButton(for: "delt_l", defaultTitle: "Left Deltoid")
                    siteButton(for: "delt_r", defaultTitle: "Right Deltoid")
                }

                // Abdomen Quadrants (Center SubQ Core)
                VStack(spacing: 6) {
                    Text("Abdomen (SubQ Core)")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)

                    HStack(spacing: 6) {
                        siteButton(for: "ab_l_uo", defaultTitle: "Upper Left")
                        siteButton(for: "ab_r_uo", defaultTitle: "Upper Right")
                    }
                    HStack(spacing: 6) {
                        siteButton(for: "ab_l_lo", defaultTitle: "Lower Left")
                        siteButton(for: "ab_r_lo", defaultTitle: "Lower Right")
                    }
                }
                .padding(8)
                .background(VialrColors.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous))

                // Thighs / Glutes (Lower Body)
                HStack(spacing: VialrSpacing.sm) {
                    siteButton(for: "thigh_l_outer", defaultTitle: "Left Thigh")
                    siteButton(for: "thigh_r_outer", defaultTitle: "Right Thigh")
                }
                HStack(spacing: VialrSpacing.sm) {
                    siteButton(for: "glute_l", defaultTitle: "Left Glute")
                    siteButton(for: "glute_r", defaultTitle: "Right Glute")
                }
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    @ViewBuilder
    private func siteButton(for siteId: String, defaultTitle: String) -> some View {
        let item = sites.first(where: { $0.id == siteId }) ?? SiteSelectionItem(id: siteId, name: defaultTitle, shortLabel: defaultTitle)
        let isSelected = selectedSiteId == siteId

        Button {
            selectedSiteId = siteId
            onSelect?(item)
            VialrHaptics.lightImpact()
        } label: {
            HStack(spacing: 8) {
                // Status indicator
                Circle()
                    .fill(statusColor(for: item))
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(item.shortLabel)
                            .font(VialrTypography.bodyMedium)
                            .foregroundColor(isSelected ? VialrColors.textPrimary : VialrColors.textSecondary)

                        if item.isRecommended {
                            Text("BEST")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(VialrColors.accentVitality.opacity(0.2))
                                .foregroundColor(VialrColors.accentVitality)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    if let days = item.daysSinceLastUse {
                        Text(days == 0 ? "Used today" : "\(days)d rested")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    } else {
                        Text("Never used")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.accentVitality)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(VialrColors.accentVitality)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? VialrColors.cardSurfaceSelected : VialrColors.cardSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous)
                    .stroke(isSelected ? VialrColors.accentVitality : VialrColors.glassBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func statusColor(for item: SiteSelectionItem) -> Color {
        guard let days = item.daysSinceLastUse else {
            return VialrColors.accentVitality
        }
        if days >= 5 {
            return VialrColors.accentVitality
        } else if days >= 2 {
            return VialrColors.accentAmber
        } else {
            return VialrColors.accentRose
        }
    }
}
