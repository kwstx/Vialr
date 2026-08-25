import SwiftUI
import Domain
import DesignSystem

public struct ProtocolDetailView: View {
    public let protocolModel: ProtocolModel
    public var onEdit: (ProtocolModel) -> Void
    public var onToggleStatus: (ProtocolModel) -> Void
    @Environment(\.dismiss) private var dismiss

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
                        }
                        .padding(VialrSpacing.lg)
                        .vialrCard()

                        // Scheduled Compounds Section
                        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                            Text("COMPOUND SCHEDULE & DOSES")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            ForEach(protocolModel.items) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(item.compoundName)
                                            .font(VialrTypography.headline)
                                            .foregroundColor(VialrColors.textPrimary)
                                        Spacer()
                                        Text("\(String(format: "%.0f", item.doseAmount)) \(item.doseUnit.rawValue)")
                                            .font(VialrTypography.metricSmall)
                                            .foregroundColor(VialrColors.accentEmerald)
                                    }

                                    HStack(spacing: 8) {
                                        Image(systemName: item.preferredTimeOfDay.iconName)
                                            .foregroundColor(VialrColors.accentTeal)
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

                        // Clinical Notes
                        if !protocolModel.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PROTOCOL NOTES & OBJECTIVES")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.accentTeal)

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
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
        }
    }
}

public struct CreateProtocolView: View {
    public var onSave: (ProtocolModel) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var goalSummary: String = ""
    @State private var compoundName: String = "BPC-157"
    @State private var doseAmount: Double = 250
    @State private var doseUnit: DoseUnit = .mcg
    @State private var selectedFrequency: String = "Daily"
    @State private var selectedTime: TimeOfDay = .morning
    @State private var notes: String = ""

    public init(onSave: @escaping (ProtocolModel) -> Void) {
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            Text("PROTOCOL OVERVIEW")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            VialrInputField("Protocol Name", placeholder: "e.g. Tendon & Joint Recovery", value: $name)
                            VialrInputField("Primary Goal", placeholder: "e.g. Rotator cuff healing post-op", value: $goalSummary)
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            Text("INITIAL COMPOUND SCHEDULE")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            VialrInputField("Compound Name", placeholder: "e.g. BPC-157", value: $compoundName)

                            VialrStepper(
                                title: "Dose Amount",
                                value: $doseAmount,
                                step: doseUnit == .mcg ? 50 : 0.5,
                                range: 1...5000,
                                unit: doseUnit.rawValue,
                                format: "%.0f"
                            )

                            HStack {
                                Text("Dose Unit")
                                    .font(VialrTypography.subheadline)
                                    .foregroundColor(VialrColors.textSecondary)
                                Spacer()
                                Picker("Dose Unit", selection: $doseUnit) {
                                    ForEach(DoseUnit.allCases) { unit in
                                        Text(unit.rawValue).tag(unit)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(VialrSpacing.sm)
                            .background(VialrColors.cardSurfaceElevated)
                            .cornerRadius(VialrSpacing.radiusSm)

                            HStack {
                                Text("Time of Day")
                                    .font(VialrTypography.subheadline)
                                    .foregroundColor(VialrColors.textSecondary)
                                Spacer()
                                Picker("Time of Day", selection: $selectedTime) {
                                    ForEach(TimeOfDay.allCases) { slot in
                                        Text(slot.rawValue).tag(slot)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(VialrSpacing.sm)
                            .background(VialrColors.cardSurfaceElevated)
                            .cornerRadius(VialrSpacing.radiusSm)
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        VialrButton("Create & Start Protocol", icon: "checkmark.circle.fill", style: .primary) {
                            let item = ProtocolItem(
                                compoundId: UUID(),
                                compoundName: compoundName.isEmpty ? "Compound" : compoundName,
                                doseAmount: doseAmount,
                                doseUnit: doseUnit,
                                scheduleRule: .everyDay,
                                preferredTimeOfDay: selectedTime
                            )
                            let newProtocol = ProtocolModel(
                                name: name.isEmpty ? "New Protocol" : name,
                                goalSummary: goalSummary,
                                status: .active,
                                items: [item],
                                startDate: Date(),
                                notes: notes
                            )
                            onSave(newProtocol)
                            dismiss()
                        }
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("New Protocol")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
        }
    }
}

public struct ProtocolComparisonView: View {
    public let protocols: [ProtocolModel]
    @Environment(\.dismiss) private var dismiss

    public init(protocols: [ProtocolModel]) {
        self.protocols = protocols
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        Text("Side-by-Side Protocol Comparison")
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textSecondary)

                        ForEach(protocols) { proto in
                            VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                                HStack {
                                    Text(proto.name)
                                        .font(VialrTypography.title3)
                                        .foregroundColor(VialrColors.textPrimary)
                                    Spacer()
                                    MetricBadge(proto.status == .active ? .success("Active") : .neutral(proto.status.rawValue))
                                }

                                Text(proto.goalSummary)
                                    .font(VialrTypography.footnote)
                                    .foregroundColor(VialrColors.textSecondary)

                                Divider().background(VialrColors.glassBorder)

                                ForEach(proto.items) { item in
                                    HStack {
                                        Text(item.compoundName)
                                            .font(VialrTypography.bodyMedium)
                                            .foregroundColor(VialrColors.accentTeal)
                                        Spacer()
                                        Text("\(String(format: "%.0f", item.doseAmount)) \(item.doseUnit.rawValue)")
                                            .font(VialrTypography.monoDose)
                                            .foregroundColor(VialrColors.textPrimary)
                                        Text("(\(item.scheduleRule.description))")
                                            .font(VialrTypography.caption)
                                            .foregroundColor(VialrColors.textTertiary)
                                    }
                                }
                            }
                            .padding(VialrSpacing.md)
                            .vialrCard()
                        }
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("Compare Protocols")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
        }
    }
}
