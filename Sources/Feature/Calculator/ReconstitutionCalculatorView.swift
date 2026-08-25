import SwiftUI
import Domain
import DesignSystem

public struct ReconstitutionCalculatorView: View {
    @Bindable public var viewModel: ReconstitutionViewModel
    public var onSaveVial: ((Vial) -> Void)?
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: ReconstitutionViewModel = ReconstitutionViewModel(), onSaveVial: ((Vial) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onSaveVial = onSaveVial
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Interactive Graphical Syringe Display
                        InteractiveSyringeView(
                            units: viewModel.result.u100Units,
                            syringeSize: viewModel.selectedSyringeSize,
                            doseDescription: "\(String(format: "%.0f", viewModel.targetDoseAmount)) \(viewModel.targetDoseUnit.rawValue)"
                        )

                        // Syringe Size Selector
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SYRINGE CALIBRATION")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            Picker("Syringe Size", selection: $viewModel.selectedSyringeSize) {
                                ForEach(SyringeSize.allCases) { size in
                                    Text(size.rawValue).tag(size)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Mathematical Inputs Card
                        inputsCard

                        // Calculation Results Card
                        resultsSummaryCard

                        // Step-by-Step Instructions Card
                        instructionsCard

                        // Save Reconstituted Vial CTA
                        VialrButton("Save to Inventory as Active Vial", icon: "square.and.arrow.down.fill", style: .primary) {
                            let newVial = Vial(
                                compoundId: UUID(),
                                compoundName: viewModel.selectedCompoundName,
                                lotNumber: "LOT-\(Int.random(in: 1000...9999))",
                                vendor: "Saved via Calculator",
                                totalDryMassMg: viewModel.dryMassMg,
                                bacWaterAddedMl: viewModel.diluentVolumeMl,
                                currentVolumeRemainingMl: viewModel.diluentVolumeMl,
                                isReconstituted: true,
                                reconstitutedDate: Date(),
                                expirationDate: Calendar.current.date(byAdding: .day, value: 28, to: Date()),
                                costUsd: viewModel.vialCostUsd,
                                status: .reconstituted
                            )
                            onSaveVial?(newVial)
                            dismiss()
                        }
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("Reconstitution Calculator")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(VialrColors.accentTeal)
                }
            }
        }
    }

    // MARK: - Inputs Card
    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("RECONSTITUTION PARAMETERS")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            // Lyophilized Dry Mass
            VialrStepper(
                title: "Vial Dry Mass (Powder)",
                value: $viewModel.dryMassMg,
                step: 1.0,
                range: 1.0...50.0,
                unit: "mg",
                format: "%.1f"
            )
            .onChange(of: viewModel.dryMassMg) { _, _ in viewModel.recalculate() }

            // Diluent BAC Water Volume
            VialrStepper(
                title: "Added Bacteriostatic Water",
                value: $viewModel.diluentVolumeMl,
                step: 0.5,
                range: 0.5...10.0,
                unit: "mL",
                format: "%.1f"
            )
            .onChange(of: viewModel.diluentVolumeMl) { _, _ in viewModel.recalculate() }

            // Target Desired Dose
            VialrStepper(
                title: "Target Dose",
                value: $viewModel.targetDoseAmount,
                step: viewModel.targetDoseUnit == .mcg ? 50.0 : 0.5,
                range: 1.0...5000.0,
                unit: viewModel.targetDoseUnit.rawValue,
                format: "%.0f"
            )
            .onChange(of: viewModel.targetDoseAmount) { _, _ in viewModel.recalculate() }

            // Unit Picker
            HStack {
                Text("Dose Unit")
                    .font(VialrTypography.subheadline)
                    .foregroundColor(VialrColors.textSecondary)
                Spacer()
                Picker("Dose Unit", selection: $viewModel.targetDoseUnit) {
                    ForEach([DoseUnit.mcg, DoseUnit.mg, DoseUnit.iu]) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.targetDoseUnit) { _, _ in viewModel.recalculate() }
            }
            .padding(VialrSpacing.sm)
            .background(VialrColors.cardSurfaceElevated)
            .cornerRadius(VialrSpacing.radiusSm)
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Results Summary Card
    private var resultsSummaryCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("DOSING BREAKDOWN")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            HStack(spacing: VialrSpacing.md) {
                resultMetric(
                    label: "U-100 MARK",
                    value: "\(String(format: "%.1f", viewModel.result.u100Units))",
                    unit: "Units",
                    color: VialrColors.accentCyan
                )

                resultMetric(
                    label: "DRAW VOLUME",
                    value: "\(String(format: "%.3f", viewModel.result.drawVolumeMl))",
                    unit: "mL",
                    color: VialrColors.accentTeal
                )

                resultMetric(
                    label: "TOTAL DOSES",
                    value: "\(Int(viewModel.result.totalDosesInVial))",
                    unit: "Doses",
                    color: VialrColors.accentEmerald
                )
            }

            Divider()
                .background(VialrColors.glassBorder)

            HStack {
                Text("Concentration:")
                    .font(VialrTypography.subheadline)
                    .foregroundColor(VialrColors.textSecondary)
                Spacer()
                Text("\(String(format: "%.2f", viewModel.result.concentrationMgMl)) mg/mL (\(Int(viewModel.result.concentrationMcgMl)) mcg/mL)")
                    .font(VialrTypography.monoDose)
                    .foregroundColor(VialrColors.textPrimary)
            }

            if let costPerDose = viewModel.result.costPerDoseUsd {
                HStack {
                    Text("Cost per dose:")
                        .font(VialrTypography.subheadline)
                        .foregroundColor(VialrColors.textSecondary)
                    Spacer()
                    Text("$\(String(format: "%.2f", costPerDose))")
                        .font(VialrTypography.monoDose)
                        .foregroundColor(VialrColors.accentEmerald)
                }
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func resultMetric(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(VialrTypography.metricMedium)
                    .foregroundColor(color)
                Text(unit)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Instructions Card
    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("CLINICAL MIXING INSTRUCTIONS")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            ForEach(Array(viewModel.result.stepByStepInstructions.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                        .frame(width: 20, height: 20)
                        .background(VialrColors.accentTeal.opacity(0.15))
                        .clipShape(Circle())

                    Text(step)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }
}
