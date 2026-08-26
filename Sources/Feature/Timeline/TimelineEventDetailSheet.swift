import SwiftUI
import Domain
import DesignSystem

/// Detail sheet for inspecting full clinical metadata, associated entity links,
/// and audit notes for any generic timeline event.
public struct TimelineEventDetailSheet: View {
    public let event: TimelineEvent
    @Environment(\.dismiss) private var dismiss

    public init(event: TimelineEvent) {
        self.event = event
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.md) {
                        // 1. Header Card
                        headerCard

                        // 2. Primary Details & Notes Card
                        if let details = event.detailText, !details.isEmpty {
                            detailsCard(details)
                        }

                        // 3. Metadata Key-Value Table
                        if !event.metadata.isEmpty {
                            metadataCard
                        }

                        // 4. Audit & Entity Reference Card
                        auditCard
                    }
                    .padding(.horizontal, VialrSpacing.screenHorizontal)
                    .padding(.top, VialrSpacing.sm)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Event Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(VialrColors.accentTeal)
                }
            }
        }
    }

    // MARK: - 1. Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack(alignment: .top) {
                // Category Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: event.badgeColorHex).opacity(0.18))
                        .frame(width: 44, height: 44)

                    Image(systemName: event.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: event.badgeColorHex))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.category.rawValue.uppercased())
                        .font(VialrTypography.eyebrow)
                        .foregroundColor(Color(hex: event.badgeColorHex))

                    Text(event.title)
                        .font(VialrTypography.title2)
                        .foregroundColor(VialrColors.textPrimary)
                }

                Spacer()

                if let badge = event.badgeText {
                    MetricBadge(.custom(
                        title: badge,
                        color: Color(hex: event.badgeColorHex),
                        icon: nil
                    ))
                }
            }

            Text(event.subtitle)
                .font(VialrTypography.bodyMedium)
                .foregroundColor(VialrColors.textSecondary)

            Divider().background(VialrColors.glassBorder)

            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(VialrColors.textTertiary)

                Text(event.timestamp.formatted(date: .complete, time: .shortened))
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textSecondary)

                Spacer()

                if event.isHighlighted {
                    MetricBadge(.warning("Flagged"))
                }
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard(isElevated: true)
    }

    // MARK: - 2. Details & Notes Card
    private func detailsCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
            Text("NOTES & CLINICAL OBSERVATIONS")
                .vialrEyebrow()

            Text(text)
                .font(VialrTypography.body)
                .foregroundColor(VialrColors.textPrimary)
                .padding(VialrSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .vialrCard()
        }
    }

    // MARK: - 3. Metadata Key-Value Table
    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
            Text("EVENT METADATA")
                .vialrEyebrow()

            VStack(spacing: 0) {
                let sortedKeys = event.metadata.keys.sorted()
                ForEach(Array(sortedKeys.enumerated()), id: \.element) { idx, key in
                    let value = event.metadata[key] ?? ""
                    HStack {
                        Text(formatKeyName(key))
                            .font(VialrTypography.footnote)
                            .foregroundColor(VialrColors.textSecondary)

                        Spacer()

                        Text(value)
                            .font(VialrTypography.footnoteBold)
                            .foregroundColor(VialrColors.textPrimary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, VialrSpacing.md)

                    if idx + 1 < sortedKeys.count {
                        Divider().background(VialrColors.glassBorder)
                    }
                }
            }
            .vialrCard()
        }
    }

    // MARK: - 4. Audit & Entity Reference Card
    private var auditCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
            Text("AUDIT RECORD")
                .vialrEyebrow()

            VStack(spacing: 8) {
                HStack {
                    Text("Entity Type")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                    Spacer()
                    Text(event.associatedEntityType.rawValue)
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.textSecondary)
                }

                if let entityId = event.associatedEntityId {
                    HStack {
                        Text("Record ID")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                        Spacer()
                        Text(entityId.uuidString)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(VialrColors.textTertiary)
                            .lineLimit(1)
                    }
                }

                HStack {
                    Text("Recorded At")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                    Spacer()
                    Text(event.createdAt.formatted(date: .abbreviated, time: .standard))
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                }
            }
            .padding(VialrSpacing.md)
            .vialrCard()
        }
    }

    private func formatKeyName(_ raw: String) -> String {
        // Convert camelCase or snake_case to Title Case
        var result = ""
        for char in raw {
            if char.isUppercase && !result.isEmpty {
                result += " \(char)"
            } else if char == "_" {
                result += " "
            } else {
                result += String(char)
            }
        }
        return result.capitalized
    }
}
