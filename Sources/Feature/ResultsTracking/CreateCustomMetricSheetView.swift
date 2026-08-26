import SwiftUI
import Domain
import DesignSystem

public struct CreateCustomMetricSheetView: View {
    public let onSave: (String, MeasurementCategory, String, Double?, Double?, TargetDirection, String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var category: MeasurementCategory = .custom
    @State private var unit: String = ""
    @State private var targetDirection: TargetDirection = .decrease
    @State private var referenceMinString: String = ""
    @State private var referenceMaxString: String = ""
    @State private var selectedColorHex: String = "#3B82F6"
    @State private var selectedIcon: String = "chart.xyaxis.line"
    @State private var description: String = ""

    private let availableColors = ["#3B82F6", "#10B981", "#8B5CF6", "#EC4899", "#F59E0B", "#EF4444", "#06B6D4", "#64748B"]
    private let availableIcons = [
        "chart.xyaxis.line", "scalemass.fill", "figure.run", "hand.raised.fill",
        "drop.fill", "bolt.fill", "heart.fill", "bed.double.fill", "flame.fill", "bandage.fill"
    ]

    public init(
        onSave: @escaping (String, MeasurementCategory, String, Double?, Double?, TargetDirection, String, String, String) -> Void
    ) {
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Header Preview
                        HStack(spacing: VialrSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: selectedColorHex).opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: selectedIcon)
                                    .foregroundColor(Color(hex: selectedColorHex))
                                    .font(.system(size: 20, weight: .semibold))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(name.isEmpty ? "New Custom Metric" : name)
                                    .font(VialrTypography.title3)
                                    .foregroundColor(VialrColors.textPrimary)
                                Text(unit.isEmpty ? "Unit not set" : "Unit: \(unit)")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        // General Info
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("METRIC NAME")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textTertiary)
                                TextField("e.g. Grip Strength, Fasting Ketones, VO2 Max", text: $name)
                                    .font(VialrTypography.bodyMedium)
                                    .foregroundColor(VialrColors.textPrimary)
                                    .padding(VialrSpacing.sm)
                                    .background(VialrColors.cardBackground)
                                    .cornerRadius(8)
                            }

                            Divider().background(VialrColors.glassBorder)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("UNIT OF MEASUREMENT")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textTertiary)
                                TextField("e.g. lbs, kg, mmol/L, mL/kg/min, /10", text: $unit)
                                    .font(VialrTypography.bodyMedium)
                                    .foregroundColor(VialrColors.textPrimary)
                                    .padding(VialrSpacing.sm)
                                    .background(VialrColors.cardBackground)
                                    .cornerRadius(8)
                            }

                            Divider().background(VialrColors.glassBorder)

                            HStack {
                                Text("Category")
                                    .font(VialrTypography.bodyMedium)
                                    .foregroundColor(VialrColors.textPrimary)
                                Spacer()
                                Picker("Category", selection: $category) {
                                    ForEach(MeasurementCategory.allCases) { cat in
                                        Text(cat.rawValue).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            Divider().background(VialrColors.glassBorder)

                            HStack {
                                Text("Desired Direction")
                                    .font(VialrTypography.bodyMedium)
                                    .foregroundColor(VialrColors.textPrimary)
                                Spacer()
                                Picker("Direction", selection: $targetDirection) {
                                    ForEach(TargetDirection.allCases) { dir in
                                        Text(dir.rawValue).tag(dir)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        // Reference Range & Appearance
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            Text("TARGET REFERENCE RANGES (OPTIONAL)")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.textTertiary)

                            HStack(spacing: VialrSpacing.md) {
                                TextField("Min Target", text: $referenceMinString)
                                    .keyboardType(.decimalPad)
                                    .font(VialrTypography.bodyMedium)
                                    .padding(VialrSpacing.sm)
                                    .background(VialrColors.cardBackground)
                                    .cornerRadius(8)

                                TextField("Max Target", text: $referenceMaxString)
                                    .keyboardType(.decimalPad)
                                    .font(VialrTypography.bodyMedium)
                                    .padding(VialrSpacing.sm)
                                    .background(VialrColors.cardBackground)
                                    .cornerRadius(8)
                            }

                            Divider().background(VialrColors.glassBorder)

                            Text("THEME COLOR")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.textTertiary)

                            HStack(spacing: VialrSpacing.sm) {
                                ForEach(availableColors, id: \.self) { hex in
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColorHex == hex ? 2 : 0)
                                        )
                                        .onTapGesture {
                                            selectedColorHex = hex
                                        }
                                }
                            }
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        // Create Button
                        VialrButton("Create Metric", style: .primary) {
                            let minV = Double(referenceMinString.replacingOccurrences(of: ",", with: "."))
                            let maxV = Double(referenceMaxString.replacingOccurrences(of: ",", with: "."))
                            onSave(name, category, unit, minV, maxV, targetDirection, selectedIcon, selectedColorHex, description)
                            dismiss()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || unit.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(.top, VialrSpacing.sm)
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("New Custom Metric")
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
