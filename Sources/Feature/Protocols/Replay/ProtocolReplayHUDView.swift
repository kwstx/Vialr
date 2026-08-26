import SwiftUI
import Domain
import DesignSystem

/// Live Ground-Truth Protocol State HUD.
/// Displays dynamic running cumulative metrics as the history replay unfolds.
public struct ProtocolReplayHUDView: View {
    public let state: ReplayCumulativeState?
    public let protocolModel: ProtocolModel

    public init(state: ReplayCumulativeState?, protocolModel: ProtocolModel) {
        self.state = state
        self.protocolModel = protocolModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(VialrColors.accentTeal)
                        .frame(width: 6, height: 6)

                    Text("LIVE PROTOCOL STATE")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                }

                Spacer()

                if let adh = state?.adherencePercentage {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(VialrColors.accentEmerald)
                        Text("\(Int(adh))% Adherence")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentEmerald)
                    }
                }
            }

            // Protocol Progress Bar
            if let st = state {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Day \(st.protocolDay)\(st.totalPlannedDays != nil ? " of \(st.totalPlannedDays!)" : "")")
                            .font(VialrTypography.footnoteBold)
                            .foregroundColor(VialrColors.textPrimary)

                        Spacer()

                        if let pct = st.progressPercentage {
                            Text("\(Int(pct))% Completed")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                        }
                    }

                    if let total = st.totalPlannedDays, total > 0 {
                        ProgressView(value: Double(min(st.elapsedDays, total)), total: Double(total))
                            .tint(VialrColors.accentTeal)
                    }
                }
            }

            Divider().background(VialrColors.glassBorder)

            // Cumulative Compound Doses Given
            VStack(alignment: .leading, spacing: 6) {
                Text("CUMULATIVE DOSES DELIVERED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(VialrColors.textTertiary)

                if let st = state, !st.cumulativeDosesByCompound.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(st.cumulativeDosesByCompound.keys.sorted()), id: \.self) { compoundName in
                                if let doseStr = st.formattedCumulativeDose(for: compoundName) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "cross.vial.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(VialrColors.accentCyan)

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(compoundName)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(VialrColors.textSecondary)

                                            Text(doseStr)
                                                .font(VialrTypography.monoDose)
                                                .foregroundColor(VialrColors.textPrimary)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(VialrColors.cardSurfaceElevated)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(VialrColors.glassBorder, lineWidth: 0.8)
                                    )
                                }
                            }
                        }
                    }
                } else {
                    Text("No doses administered yet")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                }
            }

            // Latest Metrics Snapshot (Vitals & Labs)
            if let st = state, (!st.latestMeasurements.isEmpty || !st.latestBiomarkers.isEmpty) {
                Divider().background(VialrColors.glassBorder)

                VStack(alignment: .leading, spacing: 6) {
                    Text("LATEST VITALS & BIOMARKERS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(VialrColors.textTertiary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // Measurements
                            ForEach(Array(st.latestMeasurements.values), id: \.id) { m in
                                metricChip(title: m.name, value: m.formattedValue, color: VialrColors.accentTeal)
                            }

                            // Lab Biomarkers
                            ForEach(Array(st.latestBiomarkers.values), id: \.id) { lab in
                                metricChip(title: lab.biomarkerName, value: lab.formattedValue, color: Color(hex: lab.flag.badgeColorHex))
                            }
                        }
                    }
                }
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func metricChip(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(VialrColors.textTertiary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(VialrColors.glassBorder, lineWidth: 0.8)
        )
    }
}
