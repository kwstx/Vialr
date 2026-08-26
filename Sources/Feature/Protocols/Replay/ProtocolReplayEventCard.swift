import SwiftUI
import Domain
import DesignSystem

/// Spotlight Card rendering the active Protocol Replay event frame.
/// Supports smooth visual transitions across doses, measurements, lab panels, revisions, and symptoms.
public struct ProtocolReplayEventCard: View {
    public let event: ProtocolReplayEvent

    public init(event: ProtocolReplayEvent) {
        self.event = event
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            // Header Bar: Category, Day Pill, and Exact Timestamp
            headerBar

            Divider().background(VialrColors.glassBorder)

            // Dynamic Main Content Area based on Category
            mainContentStage

            // Narrative Commentary Callout
            if let narrative = event.narrativeCommentary, !narrative.isEmpty {
                narrativeCommentaryBanner(narrative)
            }
        }
        .padding(VialrSpacing.lg)
        .vialrCard()
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusLg)
                .stroke(Color(hex: event.badgeColorHex).opacity(0.35), lineWidth: 1.2)
        )
        .shadow(color: Color(hex: event.badgeColorHex).opacity(0.12), radius: 16, x: 0, y: 6)
    }

    // MARK: - 1. Header Bar
    private var headerBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: event.badgeColorHex).opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: event.iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: event.badgeColorHex))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.category.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundColor(Color(hex: event.badgeColorHex))

                    Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                }
            }

            Spacer()

            // Protocol Day Badge (e.g., "DAY 14")
            HStack(spacing: 4) {
                Text(event.protocolDay > 0 ? "DAY \(event.protocolDay)" : "BASELINE")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(VialrColors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VialrColors.cardSurfaceElevated)
                    .cornerRadius(VialrSpacing.radiusSm)
                    .overlay(
                        RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                            .stroke(VialrColors.glassBorder, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - 2. Dynamic Content Stage Router
    @ViewBuilder
    private var mainContentStage: some View {
        switch event.category {
        case .dose:
            if let dose = event.dosePayload {
                doseContent(dose)
            } else {
                genericContent
            }

        case .measurement:
            if let m = event.measurementPayload {
                measurementContent(m)
            } else {
                genericContent
            }

        case .labPanel:
            if let lab = event.labPayload {
                labPanelContent(lab)
            } else {
                genericContent
            }

        case .protocolRevision:
            if let rev = event.revisionPayload {
                revisionContent(rev)
            } else {
                genericContent
            }

        case .symptom:
            if let s = event.symptomPayload {
                symptomContent(s)
            } else {
                genericContent
            }

        case .milestone:
            milestoneContent
        }
    }

    // MARK: - 3. Dose Content
    private func doseContent(_ dose: ReplayDosePayload) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dose.compoundName)
                        .font(VialrTypography.title1)
                        .foregroundColor(VialrColors.textPrimary)

                    Text("Route: \(dose.route.rawValue)")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(dose.formattedDose)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(VialrColors.accentCyan)

                    MetricBadge(dose.status == .taken ? .success("Administered") : .neutral(dose.status.rawValue))
                }
            }

            // Route & Site metadata tags
            HStack(spacing: 8) {
                if let site = dose.injectionSiteName {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(VialrColors.accentCyan)
                        Text(site)
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textPrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(VialrColors.cardSurfaceElevated)
                    .cornerRadius(6)
                }

                HStack(spacing: 5) {
                    Image(systemName: "cross.vial.fill")
                        .font(.system(size: 11))
                        .foregroundColor(VialrColors.textTertiary)
                    Text("SubQ Syringe")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(6)

                Spacer()
            }

            if let notes = dose.notes, !notes.isEmpty {
                Text(notes)
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textSecondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VialrColors.cardSurfaceElevated.opacity(0.6))
                    .cornerRadius(6)
            }
        }
    }

    // MARK: - 4. Measurement Content
    private func measurementContent(_ m: ReplayMeasurementPayload) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.name)
                        .font(VialrTypography.title1)
                        .foregroundColor(VialrColors.textPrimary)

                    Text(m.category.rawValue)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(m.formattedValue)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(VialrColors.textPrimary)

                    if m.isBaseline {
                        MetricBadge(.info("Day 1 Baseline"))
                    } else if m.status != .inRange {
                        MetricBadge(.warning(m.status.rawValue))
                    } else {
                        MetricBadge(.success("Optimal Range"))
                    }
                }
            }

            // Delta from baseline banner
            if let delta = m.deltaFromBaseline {
                let sign = delta > 0 ? "+" : ""
                let deltaStr = String(format: delta.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", delta)
                let isFavorable = (m.type == .weight || m.type == .bloodGlucose || m.type == .pain) ? delta <= 0 : delta >= 0

                HStack(spacing: 8) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isFavorable ? VialrColors.accentEmerald : VialrColors.accentRose)

                    Text("\(sign)\(deltaStr) \(m.unit) from Protocol Baseline")
                        .font(VialrTypography.footnoteBold)
                        .foregroundColor(isFavorable ? VialrColors.accentEmerald : VialrColors.accentRose)

                    Spacer()
                }
                .padding(8)
                .background((isFavorable ? VialrColors.accentEmerald : VialrColors.accentRose).opacity(0.08))
                .cornerRadius(6)
            }

            if let notes = m.notes, !notes.isEmpty {
                Text(notes)
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textSecondary)
            }
        }
    }

    // MARK: - 5. Lab Panel Content
    private func labPanelContent(_ lab: ReplayLabPayload) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lab.panelName)
                        .font(VialrTypography.title2)
                        .foregroundColor(VialrColors.textPrimary)
                    Text(lab.labName)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }

                Spacer()

                if lab.isBaselineDraw {
                    MetricBadge(.info("Baseline Panel"))
                } else if lab.abnormalCount == 0 {
                    MetricBadge(.success("All Normal"))
                } else {
                    MetricBadge(.warning("\(lab.abnormalCount) Flagged"))
                }
            }

            // Highlighted Biomarkers Grid
            if !lab.highlightedAnalytes.isEmpty {
                VStack(spacing: 6) {
                    ForEach(lab.highlightedAnalytes) { analyte in
                        HStack {
                            Circle()
                                .fill(Color(hex: analyte.flag.badgeColorHex))
                                .frame(width: 7, height: 7)

                            Text(analyte.name)
                                .font(VialrTypography.bodyMedium)
                                .foregroundColor(VialrColors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text(analyte.formattedValue)
                                .font(VialrTypography.monoDose)
                                .foregroundColor(Color(hex: analyte.flag.badgeColorHex))

                            if let delta = analyte.deltaFromBaseline {
                                let sign = delta > 0 ? "+" : ""
                                let dStr = String(format: delta.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", delta)
                                Text("(\(sign)\(dStr))")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(VialrColors.textTertiary)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(VialrColors.cardSurfaceElevated)
                        .cornerRadius(6)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - 6. Protocol Revision Content
    private func revisionContent(_ rev: ReplayRevisionPayload) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Protocol Revision #\(rev.revisionNumber)")
                        .font(VialrTypography.title2)
                        .foregroundColor(VialrColors.textPrimary)
                    Text("Dosage & Protocol Adjustment")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }

                Spacer()

                MetricBadge(.warning("Titration Event"))
            }

            if !rev.reasonForChange.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 12))
                        .foregroundColor(VialrColors.accentAmber)

                    Text(rev.reasonForChange)
                        .font(VialrTypography.body)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VialrColors.accentAmber.opacity(0.08))
                .cornerRadius(8)
            }

            if !rev.doseAdjustments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DOSE ADJUSTMENTS")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.textTertiary)

                    ForEach(rev.doseAdjustments, id: \.compoundName) { adj in
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(VialrColors.accentAmber)

                            Text(adj.description)
                                .font(VialrTypography.subheadlineBold)
                                .foregroundColor(VialrColors.textPrimary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - 7. Symptom Content
    private func symptomContent(_ s: ReplaySymptomPayload) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("Subjective Wellness Check-In")
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)

            VStack(spacing: 8) {
                if let energy = s.energyLevel {
                    scoreRow(title: "Energy Level", score: energy, icon: "bolt.fill", color: VialrColors.accentAmber)
                }
                if let sleep = s.sleepQuality {
                    scoreRow(title: "Sleep Quality", score: sleep, icon: "bed.double.fill", color: VialrColors.accentCyan)
                }
                if let recovery = s.recoveryScore {
                    scoreRow(title: "Recovery", score: recovery, icon: "heart.fill", color: VialrColors.accentEmerald)
                }
                if let pain = s.painScore {
                    scoreRow(title: "Pain Index", score: pain, icon: "bandage.fill", color: pain > 3 ? VialrColors.accentRose : VialrColors.textTertiary)
                }
            }

            if let notes = s.notes, !notes.isEmpty {
                Text(notes)
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textSecondary)
            }
        }
    }

    private func scoreRow(title: String, score: Int, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 18)

            Text(title)
                .font(VialrTypography.bodyMedium)
                .foregroundColor(VialrColors.textPrimary)

            Spacer()

            // Visual Progress Bar
            ProgressView(value: Double(score), total: 10.0)
                .tint(color)
                .frame(width: 90)

            Text("\(score)/10")
                .font(VialrTypography.monoDose)
                .foregroundColor(color)
                .frame(width: 44, alignment: .trailing)
        }
    }

    // MARK: - 8. Milestone Content
    private var milestoneContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.title)
                .font(VialrTypography.title1)
                .foregroundColor(VialrColors.textPrimary)

            Text(event.subtitle)
                .font(VialrTypography.body)
                .foregroundColor(VialrColors.textSecondary)

            if let detail = event.detailText {
                Text(detail)
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textTertiary)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - 9. Generic Fallback Content
    private var genericContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title)
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)

            Text(event.subtitle)
                .font(VialrTypography.body)
                .foregroundColor(VialrColors.textSecondary)

            if let detail = event.detailText {
                Text(detail)
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textTertiary)
            }
        }
    }

    // MARK: - 10. Narrative Commentary Banner
    private func narrativeCommentaryBanner(_ narrative: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(VialrColors.accentTeal)
                .padding(.top, 1)

            Text(narrative)
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textPrimary)
                .lineSpacing(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(8)
    }
}
