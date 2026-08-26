import SwiftUI
import Domain
import DesignSystem
import CalculationEngine

public struct ProtocolDetailView: View {
    public let protocolModel: ProtocolModel
    public var onEdit: (ProtocolModel) -> Void
    public var onToggleStatus: (ProtocolModel) -> Void
    @Environment(\.dismiss) private var dismiss

    private let schedulingEngine = ProtocolSchedulingEngine()

    public init(
        protocolModel: ProtocolModel,
        onEdit: @escaping (ProtocolModel) -> Void,
        onToggleStatus: @escaping (ProtocolModel) -> Void
    ) {
        self.protocolModel = protocolModel
        self.onEdit = onEdit
        self.onToggleStatus = onToggleStatus
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Header Card
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            HStack {
                                MetricBadge(protocolModel.status == .active ? .success("Active Protocol") : .neutral(protocolModel.status.rawValue))
                                Spacer()
                                Text("Started \(protocolModel.startDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textTertiary)
                            }

                            Text(protocolModel.name)
                                .font(VialrTypography.largeHero)
                                .foregroundColor(VialrColors.textPrimary)

                            if !protocolModel.goalSummary.isEmpty {
                                Text(protocolModel.goalSummary)
                                    .font(VialrTypography.body)
                                    .foregroundColor(VialrColors.textSecondary)
                            }

                            if let end = protocolModel.endDate {
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 13))
                                        .foregroundColor(VialrColors.accentVitality)
                                    Text("Ends: \(end.formatted(date: .abbreviated, time: .omitted)) (\(protocolModel.elapsedDays) of \(protocolModel.totalPlannedDays ?? 0) days)")
                                        .font(VialrTypography.caption)
                                        .foregroundColor(VialrColors.textSecondary)
                                }
                            }
                        }
                        .padding(VialrSpacing.lg)
                        .vialrCard()

                        // Scheduled Compounds Section
                        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                            Text("COMPOUND SCHEDULE & DOSES")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentVitality)

                            ForEach(protocolModel.items) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(item.compoundName)
                                            .font(VialrTypography.headline)
                                            .foregroundColor(VialrColors.textPrimary)
                                        Spacer()
                                        Text("\(String(format: item.doseUnit == .mg ? "%.2f" : "%.0f", item.doseAmount)) \(item.doseUnit.rawValue)")
                                            .font(VialrTypography.metricSmall)
                                            .foregroundColor(VialrColors.accentVitality)
                                    }

                                    HStack(spacing: 8) {
                                        Image(systemName: item.preferredTimeOfDay.iconName)
                                            .foregroundColor(VialrColors.accentVitality)
                                            .font(.system(size: 13))
                                        Text(item.preferredTimeOfDay.rawValue)
                                            .font(VialrTypography.footnote)
                                            .foregroundColor(VialrColors.textSecondary)

                                        Text("•")
                                            .foregroundColor(VialrColors.textTertiary)

                                        Text(item.scheduleRule.description)
                                            .font(VialrTypography.footnote)
                                            .foregroundColor(VialrColors.textSecondary)
                                    }

                                    HStack(spacing: 8) {
                                        Text("Route: \(item.route.rawValue)")
                                            .font(VialrTypography.caption)
                                            .foregroundColor(VialrColors.textTertiary)

                                        if item.foodRequirement != .unspecified {
                                            Text("• \(item.foodRequirement.rawValue)")
                                                .font(VialrTypography.caption)
                                                .foregroundColor(VialrColors.textTertiary)
                                        }
                                    }

                                    if let _ = item.attachedVialId {
                                        HStack(spacing: 6) {
                                            Image(systemName: "cross.vial.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(VialrColors.accentVitality)
                                            Text("Attached to inventory vial")
                                                .font(VialrTypography.caption)
                                                .foregroundColor(VialrColors.accentVitality)
                                        }
                                        .padding(.top, 2)
                                    }

                                    if !item.notes.isEmpty {
                                        Text(item.notes)
                                            .font(VialrTypography.caption)
                                            .foregroundColor(VialrColors.textTertiary)
                                    }
                                }
                                .padding(VialrSpacing.md)
                                .vialrCard()
                            }
                        }

                        // Upcoming Dynamically Generated Occurrences
                        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                            Text("UPCOMING PROJECTED DOSES")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentVitality)

                            let upcoming = schedulingEngine.upcomingOccurrences(for: [protocolModel], limit: 5)
                            if upcoming.isEmpty {
                                Text("No upcoming doses scheduled.")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textSecondary)
                                    .padding(VialrSpacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .vialrCard()
                            } else {
                                VStack(spacing: 6) {
                                    ForEach(upcoming) { occ in
                                        HStack {
                                            Image(systemName: "circle.fill")
                                                .font(.system(size: 6))
                                                .foregroundColor(VialrColors.accentVitality)

                                            Text(occ.scheduledTimestamp.formatted(date: .abbreviated, time: .shortened))
                                                .font(VialrTypography.captionBold)
                                                .foregroundColor(VialrColors.textPrimary)

                                            Spacer()

                                            Text(occ.formattedDose)
                                                .font(VialrTypography.monoSub)
                                                .foregroundColor(VialrColors.accentVitality)

                                            Text("• \(occ.route.shortName)")
                                                .font(VialrTypography.caption)
                                                .foregroundColor(VialrColors.textTertiary)
                                        }
                                        .padding(VialrSpacing.sm)
                                    }
                                }
                                .padding(VialrSpacing.xs)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusSm)
                            }
                        }

                        // Clinical Notes
                        if !protocolModel.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PROTOCOL NOTES & OBJECTIVES")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.accentVitality)

                                Text(protocolModel.notes)
                                    .font(VialrTypography.body)
                                    .foregroundColor(VialrColors.textSecondary)
                            }
                            .padding(VialrSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .vialrCard()
                        }

                        // Action Buttons
                        VStack(spacing: VialrSpacing.sm) {
                            VialrButton(
                                protocolModel.status == .active ? "Pause Protocol" : "Activate Protocol",
                                icon: protocolModel.status == .active ? "pause.fill" : "play.fill",
                                style: .secondary
                            ) {
                                onToggleStatus(protocolModel)
                                dismiss()
                            }
                        }
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("Protocol Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(VialrColors.accentVitality)
                }
            }
        }
    }
}

/// CreateProtocolView wraps the guided multi-step ProtocolCreationFlowView.
public struct CreateProtocolView: View {
    public var onSave: (ProtocolModel) -> Void

    public init(onSave: @escaping (ProtocolModel) -> Void) {
        self.onSave = onSave
    }

    public var body: some View {
        ProtocolCreationFlowView(onProtocolCreated: onSave)
    }
}

