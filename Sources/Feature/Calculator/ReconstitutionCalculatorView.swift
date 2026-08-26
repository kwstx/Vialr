import SwiftUI
import Domain
import CalculationEngine
import DesignSystem

public struct ReconstitutionCalculatorView: View {
    @Bindable public var viewModel: ReconstitutionViewModel
    public var onSaveVial: ((Vial) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var isDerivationExpanded: Bool = false

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
                        // Mode Selector Segmented Control
                        Picker("Calculation Mode", selection: $viewModel.mode) {
                            ForEach(ReconstitutionMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: viewModel.mode) { _, _ in viewModel.recalculate() }

                        // Calculation Mode Content
                        switch viewModel.mode {
                        case .forward:
                            forwardCalculationContent
                        case .solveDiluent:
                            diluentSolverContent
                        case .reverseDose:
                            reverseDoseContent
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

    // MARK: - Forward Reconstitution Mode Content
    private var forwardCalculationContent: some View {
        VStack(spacing: VialrSpacing.lg) {
            // Interactive Graphical Syringe Display
            if let result = viewModel.result {
                InteractiveSyringeView(
                    units: result.selectedSyringeUnits,
                    syringeSize: viewModel.selectedSyringeSize,
                    doseDescription: "\(String(format: "%.0f", result.normalizedDoseMcg)) mcg (\(String(format: "%.3g", result.normalizedDoseMg)) mg)",
                    volumeMl: result.drawVolumeMl,
                    concentrationMgMl: result.concentrationMgMl,
                    compoundName: viewModel.selectedCompoundName,
                    presentationStyle: .full,
                    showUnderlyingNumbers: true,
                    showTargetCallout: true,
                    showScaleNumbers: true
                )
            }

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
                .onChange(of: viewModel.selectedSyringeSize) { _, _ in viewModel.recalculate() }
            }

            // Inputs Card
            forwardInputsCard

            // Validation Error Banner (if input rejected)
            if let err = viewModel.calculationError {
                errorBanner(message: err)
            }

            // Calculation Results Card
            if let result = viewModel.result {
                // Safety Advisories / Warnings
                if !result.warnings.isEmpty {
                    warningsCard(warnings: result.warnings)
                }

                resultsSummaryCard(result: result)

                derivationAuditCard(result: result)

                instructionsCard(instructions: result.clinicalInstructions)

                // Save Reconstituted Vial CTA
                VialrButton("Save to Inventory as Active Vial", icon: "square.and.arrow.down.fill", style: .primary) {
                    let newVial = Vial(
                        compoundId: UUID(),
                        compoundName: viewModel.selectedCompoundName,
                        lotNumber: "LOT-\(Int.random(in: 1000...9999))",
                        vendor: "Saved via Calculator",
                        totalDryMassMg: result.normalizedDoseMg * result.totalDosesInVial,
                        bacWaterAddedMl: viewModel.diluentVolumeMl,
                        currentVolumeRemainingMl: viewModel.diluentVolumeMl,
                        isReconstituted: true,
                        reconstitutedDate: Date(),
                        expirationDate: Calendar.current.date(byAdding: .day, value: 28, to: Date()),
                        costUsd: viewModel.vialCostUsd > 0 ? viewModel.vialCostUsd : nil,
                        status: .reconstituted
                    )
                    onSaveVial?(newVial)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Forward Inputs Card
    private var forwardInputsCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("RECONSTITUTION PARAMETERS")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            // Lyophilized Dry Mass
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dry Mass (Powder)")
                        .font(VialrTypography.subheadline)
                        .foregroundColor(VialrColors.textSecondary)
                }
                Spacer()
                Picker("Mass Unit", selection: $viewModel.dryMassUnit) {
                    ForEach([MassUnit.mg, MassUnit.mcg, MassUnit.g]) { u in
                        Text(u.symbol).tag(u)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.dryMassUnit) { _, _ in viewModel.recalculate() }
            }

            VialrStepper(
                title: "Mass Amount",
                value: $viewModel.dryMassAmount,
                step: viewModel.dryMassUnit == .mcg ? 500.0 : 1.0,
                range: 0.1...10000.0,
                unit: viewModel.dryMassUnit.symbol,
                format: "%.1f"
            )
            .onChange(of: viewModel.dryMassAmount) { _, _ in viewModel.recalculate() }

            Divider().background(VialrColors.glassBorder)

            // Added Diluent Volume
            HStack {
                Text("Added Diluent Solvent")
                    .font(VialrTypography.subheadline)
                    .foregroundColor(VialrColors.textSecondary)
                Spacer()
                Picker("Diluent Type", selection: $viewModel.diluentType) {
                    ForEach(DiluentType.allCases) { d in
                        Text(d.shortName).tag(d)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.diluentType) { _, _ in viewModel.recalculate() }
            }

            VialrStepper(
                title: "Diluent Volume",
                value: $viewModel.diluentVolumeAmount,
                step: 0.5,
                range: 0.1...20.0,
                unit: viewModel.diluentVolumeUnit.symbol,
                format: "%.1f"
            )
            .onChange(of: viewModel.diluentVolumeAmount) { _, _ in viewModel.recalculate() }

            Divider().background(VialrColors.glassBorder)

            // Target Desired Dose
            HStack {
                Text("Target Dose Unit")
                    .font(VialrTypography.subheadline)
                    .foregroundColor(VialrColors.textSecondary)
                Spacer()
                Picker("Dose Unit", selection: $viewModel.targetDoseUnit) {
                    ForEach([DoseUnit.mcg, DoseUnit.mg, DoseUnit.iu, DoseUnit.ml]) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.targetDoseUnit) { _, _ in viewModel.recalculate() }
            }

            VialrStepper(
                title: "Target Dose Amount",
                value: $viewModel.targetDoseAmount,
                step: viewModel.targetDoseUnit == .mcg ? 50.0 : 0.5,
                range: 0.1...10000.0,
                unit: viewModel.targetDoseUnit.rawValue,
                format: "%.1f"
            )
            .onChange(of: viewModel.targetDoseAmount) { _, _ in viewModel.recalculate() }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Results Summary Card
    private func resultsSummaryCard(result: ReconstitutionResult) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("DOSING BREAKDOWN")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            HStack(spacing: VialrSpacing.md) {
                resultMetric(
                    label: "U-100 MARK",
                    value: "\(String(format: "%.1f", result.u100Units))",
                    unit: "Units",
                    color: VialrColors.accentCyan
                )

                resultMetric(
                    label: "DRAW VOLUME",
                    value: "\(String(format: "%.3f", result.drawVolumeMl))",
                    unit: "mL",
                    color: VialrColors.accentTeal
                )

                resultMetric(
                    label: "TOTAL DOSES",
                    value: "\(result.exactDosesCount)",
                    unit: "Doses",
                    color: VialrColors.accentEmerald
                )
            }

            Divider().background(VialrColors.glassBorder)

            HStack {
                Text("Concentration:")
                    .font(VialrTypography.subheadline)
                    .foregroundColor(VialrColors.textSecondary)
                Spacer()
                Text("\(String(format: "%.2f", result.concentrationMgMl)) mg/mL (\(Int(result.concentrationMcgMl)) mcg/mL)")
                    .font(VialrTypography.monoDose)
                    .foregroundColor(VialrColors.textPrimary)
            }

            if let costPerDose = result.costPerDoseUsd {
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

    // MARK: - Derivation Audit Card
    private func derivationAuditCard(result: ReconstitutionResult) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isDerivationExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("MATHEMATICAL DERIVATION AUDIT")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Spacer()
                    Image(systemName: isDerivationExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
            .buttonStyle(.plain)

            if isDerivationExpanded {
                VStack(alignment: .leading, spacing: VialrSpacing.md) {
                    ForEach(result.derivationSteps) { step in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Step \(step.stepIndex): \(step.title)")
                                    .font(VialrTypography.subheadlineBold)
                                    .foregroundColor(VialrColors.textPrimary)
                                Spacer()
                            }
                            Text(step.formula)
                                .font(VialrTypography.monoSub)
                                .foregroundColor(VialrColors.accentCyan)
                            Text(step.substitution)
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textSecondary)
                            Text("↳ Result: \(step.evaluatedResult)")
                                .font(VialrTypography.footnoteBold)
                                .foregroundColor(VialrColors.accentEmerald)
                            if let note = step.clinicalNote {
                                Text(note)
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textTertiary)
                                    .italic()
                            }
                        }
                        .padding(VialrSpacing.sm)
                        .background(VialrColors.cardSurfaceElevated)
                        .cornerRadius(VialrSpacing.radiusSm)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Warnings Card
    private func warningsCard(warnings: [CalculationWarning]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(warnings) { w in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: w.severity == .critical ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(w.severity == .critical ? .red : .orange)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.title)
                            .font(VialrTypography.subheadlineBold)
                            .foregroundColor(w.severity == .critical ? .red : .orange)
                        Text(w.message)
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textPrimary)
                    }
                }
                .padding(VialrSpacing.sm)
                .background(w.severity == .critical ? Color.red.opacity(0.12) : Color.orange.opacity(0.12))
                .cornerRadius(VialrSpacing.radiusSm)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Instructions Card
    private func instructionsCard(instructions: [String]) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("CLINICAL MIXING INSTRUCTIONS")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            ForEach(Array(instructions.enumerated()), id: \.offset) { index, step in
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

    // MARK: - Diluent Solver Mode Content
    private var diluentSolverContent: some View {
        VStack(spacing: VialrSpacing.lg) {
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                Text("DILUENT SOLVER INPUTS")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)

                VialrStepper(
                    title: "Vial Dry Mass (mg)",
                    value: $viewModel.dryMassAmount,
                    step: 1.0,
                    range: 1.0...50.0,
                    unit: "mg",
                    format: "%.1f"
                )
                .onChange(of: viewModel.dryMassAmount) { _, _ in viewModel.recalculate() }

                VialrStepper(
                    title: "Target Dose (\(viewModel.targetDoseUnit.rawValue))",
                    value: $viewModel.targetDoseAmount,
                    step: 50.0,
                    range: 10.0...5000.0,
                    unit: viewModel.targetDoseUnit.rawValue,
                    format: "%.0f"
                )
                .onChange(of: viewModel.targetDoseAmount) { _, _ in viewModel.recalculate() }

                VialrStepper(
                    title: "Desired Syringe Units to Draw",
                    value: $viewModel.desiredSyringeUnits,
                    step: 1.0,
                    range: 1.0...100.0,
                    unit: "Units",
                    format: "%.0f"
                )
                .onChange(of: viewModel.desiredSyringeUnits) { _, _ in viewModel.recalculate() }
            }
            .padding(VialrSpacing.md)
            .vialrCard()

            if let res = viewModel.diluentSolverResult {
                InteractiveSyringeView(
                    units: res.syringeUnits,
                    syringeSize: viewModel.selectedSyringeSize,
                    doseDescription: "\(String(format: "%.0f", res.targetDoseMcg)) mcg (\(String(format: "%.3g", res.targetDoseMg)) mg)",
                    volumeMl: res.drawVolumeMl,
                    concentrationMgMl: res.resultingConcentrationMgMl,
                    compoundName: viewModel.selectedCompoundName,
                    presentationStyle: .full,
                    showUnderlyingNumbers: true,
                    showTargetCallout: true,
                    showScaleNumbers: true,
                    titleOverride: "CALCULATED DRAW MARKING"
                )

                VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                    Text("SOLVER RECOMMENDATION")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)

                    HStack {
                        Text("Add BAC Water:")
                            .font(VialrTypography.subheadline)
                            .foregroundColor(VialrColors.textSecondary)
                        Spacer()
                        Text("\(String(format: "%.2f", res.recommendedDiluentVolumeMl)) mL")
                            .font(VialrTypography.metricMedium)
                            .foregroundColor(VialrColors.accentEmerald)
                    }

                    Text(res.summaryExplanation)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .padding(VialrSpacing.md)
                .vialrCard()
            }
        }
    }

    // MARK: - Reverse Syringe Mode Content
    private var reverseDoseContent: some View {
        VStack(spacing: VialrSpacing.lg) {
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                Text("REVERSE DOSE INPUTS")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)

                VialrStepper(
                    title: "Vial Concentration (mg/mL)",
                    value: $viewModel.currentConcentrationMgMl,
                    step: 0.5,
                    range: 0.1...50.0,
                    unit: "mg/mL",
                    format: "%.2f"
                )
                .onChange(of: viewModel.currentConcentrationMgMl) { _, _ in viewModel.recalculate() }

                VialrStepper(
                    title: "Syringe Units Drawn (U-100)",
                    value: $viewModel.drawnSyringeUnits,
                    step: 1.0,
                    range: 0.5...100.0,
                    unit: "Units",
                    format: "%.1f"
                )
                .onChange(of: viewModel.drawnSyringeUnits) { _, _ in viewModel.recalculate() }
            }
            .padding(VialrSpacing.md)
            .vialrCard()

            if let res = viewModel.reverseDoseResult {
                InteractiveSyringeView(
                    units: viewModel.drawnSyringeUnits,
                    syringeSize: viewModel.selectedSyringeSize,
                    doseDescription: "\(String(format: "%.0f", res.administeredDoseMcg)) mcg (\(String(format: "%.3g", res.administeredDoseMg)) mg)",
                    volumeMl: res.drawnVolumeMl,
                    concentrationMgMl: viewModel.currentConcentrationMgMl,
                    compoundName: viewModel.selectedCompoundName,
                    presentationStyle: .full,
                    showUnderlyingNumbers: true,
                    showTargetCallout: true,
                    showScaleNumbers: true,
                    titleOverride: "ADMINISTERED SYRINGE DRAW"
                )

                VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                    Text("ADMINISTERED DOSE RESULT")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)

                    HStack {
                        Text("Delivered Dose:")
                            .font(VialrTypography.subheadline)
                            .foregroundColor(VialrColors.textSecondary)
                        Spacer()
                        Text("\(String(format: "%.0f", res.administeredDoseMcg)) mcg (\(String(format: "%.3g", res.administeredDoseMg)) mg)")
                            .font(VialrTypography.metricMedium)
                            .foregroundColor(VialrColors.accentEmerald)
                    }

                    Text(res.summaryExplanation)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .padding(VialrSpacing.md)
                .vialrCard()
            }
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Calculation Error")
                    .font(VialrTypography.subheadlineBold)
                    .foregroundColor(.red)
                Text(message)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textPrimary)
            }
        }
        .padding(VialrSpacing.sm)
        .background(Color.red.opacity(0.12))
        .cornerRadius(VialrSpacing.radiusSm)
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
}
