import SwiftUI
import Domain
import DesignSystem

public struct LogMeasurementSheetView: View {
    public let metric: MetricDefinition
    public let protocols: [ProtocolModel]
    public let onSave: (Double, Double?, String, Date, MeasurementSource, UUID?, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var valueString: String = ""
    @State private var secondaryValueString: String = ""
    @State private var selectedUnit: String
    @State private var selectedDate: Date = Date()
    @State private var selectedSource: MeasurementSource = .manualEntry
    @State private var selectedProtocolId: UUID?
    @State private var notes: String = ""

    public init(
        metric: MetricDefinition,
        protocols: [ProtocolModel] = [],
        onSave: @escaping (Double, Double?, String, Date, MeasurementSource, UUID?, String) -> Void
    ) {
        self.metric = metric
        self.protocols = protocols
        self.onSave = onSave
        self._selectedUnit = State(initialValue: metric.defaultUnit)
        self._selectedProtocolId = State(initialValue: protocols.first(where: { $0.status == .active })?.id)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Metric Header Card
                        HStack(spacing: VialrSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: metric.colorHex).opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: metric.iconName)
                                    .foregroundColor(Color(hex: metric.colorHex))
                                    .font(.system(size: 20, weight: .semibold))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.category.rawValue.uppercased())
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.accentTeal)
                                Text(metric.name)
                                    .font(VialrTypography.title3)
                                    .foregroundColor(VialrColors.textPrimary)
                            }
                            Spacer()
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        // Value Input
                        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
                            Text("MEASUREMENT VALUE")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.textTertiary)

                            HStack(spacing: VialrSpacing.sm) {
                                TextField("0.0", text: $valueString)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(VialrColors.textPrimary)
                                    .padding(VialrSpacing.md)
                                    .background(VialrColors.cardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(VialrColors.glassBorder, lineWidth: 1)
                                    )

                                if metric.supportedUnits.count > 1 {
                                    Picker("Unit", selection: $selectedUnit) {
                                        ForEach(metric.supportedUnits, id: \.self) { u in
                                            Text(u).tag(u)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .padding(.horizontal, VialrSpacing.sm)
                                    .frame(height: 58)
                                    .background(VialrColors.cardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(VialrColors.glassBorder, lineWidth: 1)
                                    )
                                } else {
                                    Text(selectedUnit)
                                        .font(VialrTypography.headline)
                                        .foregroundColor(VialrColors.textSecondary)
                                        .padding(.horizontal, VialrSpacing.md)
                                        .frame(height: 58)
                                        .background(VialrColors.cardBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(VialrColors.glassBorder, lineWidth: 1)
                                        )
                                }
                            }
                        }

                        // Secondary Value (e.g. Diastolic for BP or Sleep Quality)
                        if metric.allowsSecondaryValue {
                            VStack(alignment: .leading, spacing: VialrSpacing.xs) {
                                Text(metric.type == .bloodPressure ? "DIASTOLIC PRESSURE" : (metric.secondaryUnit ?? "SECONDARY VALUE").uppercased())
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textTertiary)

                                HStack(spacing: VialrSpacing.sm) {
                                    TextField("0.0", text: $secondaryValueString)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                                        .foregroundColor(VialrColors.textPrimary)
                                        .padding(VialrSpacing.md)
                                        .background(VialrColors.cardBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(VialrColors.glassBorder, lineWidth: 1)
                                        )

                                    Text(metric.secondaryUnit ?? metric.defaultUnit)
                                        .font(VialrTypography.subheadline)
                                        .foregroundColor(VialrColors.textSecondary)
                                        .padding(.horizontal, VialrSpacing.md)
                                }
                            }
                        }

                        // Timestamp & Source
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            DatePicker(
                                "Date & Time",
                                selection: $selectedDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .font(VialrTypography.bodyMedium)
                            .foregroundColor(VialrColors.textPrimary)

                            Divider().background(VialrColors.glassBorder)

                            HStack {
                                Text("Data Source")
                                    .font(VialrTypography.bodyMedium)
                                    .foregroundColor(VialrColors.textPrimary)
                                Spacer()
                                Picker("Source", selection: $selectedSource) {
                                    ForEach(MeasurementSource.allCases) { src in
                                        Text(src.rawValue).tag(src)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            if !protocols.isEmpty {
                                Divider().background(VialrColors.glassBorder)

                                HStack {
                                    Text("Link to Protocol")
                                        .font(VialrTypography.bodyMedium)
                                        .foregroundColor(VialrColors.textPrimary)
                                    Spacer()
                                    Picker("Protocol", selection: $selectedProtocolId) {
                                        Text("None / General").tag(UUID?.none)
                                        ForEach(protocols) { p in
                                            Text(p.name).tag(UUID?.some(p.id))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        // Notes Input
                        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
                            Text("OPTIONAL NOTES")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.textTertiary)

                            TextField("Context (e.g. fasted, post-workout, morning wake-up)", text: $notes, axis: .vertical)
                                .lineLimit(3...5)
                                .font(VialrTypography.bodyMedium)
                                .foregroundColor(VialrColors.textPrimary)
                                .padding(VialrSpacing.md)
                                .background(VialrColors.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(VialrColors.glassBorder, lineWidth: 1)
                                )
                        }

                        // Save Button
                        VialrButton("Log Measurement", style: .primary) {
                            guard let val = Double(valueString.replacingOccurrences(of: ",", with: ".")) else { return }
                            let secVal = Double(secondaryValueString.replacingOccurrences(of: ",", with: "."))
                            onSave(val, secVal, selectedUnit, selectedDate, selectedSource, selectedProtocolId, notes)
                            dismiss()
                        }
                        .disabled(Double(valueString.replacingOccurrences(of: ",", with: ".")) == nil)
                        .padding(.top, VialrSpacing.sm)
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("Record Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
        }
    }
}
