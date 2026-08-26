import SwiftUI
import Domain
import DesignSystem
import CalculationEngine

/// Interactive modal sheet allowing users to perform an audited inventory reconciliation
/// when physical vial liquid levels differ from expected accounting calculations.
public struct VialReconciliationSheetView: View {
    public let vial: Vial
    public let currentState: VialAccountingState
    public var onReconcile: (Double, ReconciliationReason, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var observedVolumeMl: Double
    @State private var selectedReason: ReconciliationReason = .deadSpaceLoss
    @State private var notes: String = ""
    @State private var isSubmitting: Bool = false

    public init(
        vial: Vial,
        currentState: VialAccountingState,
        onReconcile: @escaping (Double, ReconciliationReason, String) -> Void
    ) {
        self.vial = vial
        self.currentState = currentState
        self._observedVolumeMl = State(initialValue: max(0.0, currentState.currentVolumeRemainingMl))
        self.onReconcile = onReconcile
    }

    private var expectedVolumeMl: Double {
        currentState.currentVolumeRemainingMl
    }

    private var volumeVarianceMl: Double {
        observedVolumeMl - expectedVolumeMl
    }

    private var massVarianceMg: Double {
        guard let conc = currentState.currentConcentrationMgMl, conc > 0 else { return 0.0 }
        return volumeVarianceMl * conc
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // 1. Vial Summary Header
                        headerCard

                        // 2. Expected vs Observed Variance Comparison Card
                        varianceComparisonCard

                        // 3. Observed Physical Volume Stepper
                        observedInputCard

                        // 4. Clinical / Operational Reason Selector
                        reasonSelectionCard

                        // 5. Notes Card
                        notesCard

                        // 6. Action Button
                        VStack(spacing: VialrSpacing.xs) {
                            VialrButton(
                                isSubmitting ? "Recording Adjustment..." : "Commit Reconciliation Adjustment",
                                icon: "arrow.left.arrow.right.circle.fill",
                                style: .vitality,
                                size: .large,
                                isLoading: isSubmitting
                            ) {
                                submitReconciliation()
                            }
                            .disabled(isSubmitting)

                            Text("Creates an audited accounting event rather than overwriting historical records.")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, VialrSpacing.sm)
                        .padding(.bottom, VialrSpacing.xl)
                    }
                    .padding(.horizontal, VialrSpacing.screenHorizontal)
                    .padding(.top, VialrSpacing.sm)
                }
            }
            .navigationTitle("Reconcile Stock")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(VialrColors.textSecondary)
                }
            }
        }
    }

    // MARK: - 1. Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("INVENTORY RECONCILIATION")
                    .font(VialrTypography.captionBold)
                    .tracking(1.1)
                    .foregroundColor(VialrColors.accentAmber)

                Spacer()

                Text(vial.lotNumber.isEmpty ? "Lot: Standard" : "Lot: \(vial.lotNumber)")
                    .font(VialrTypography.monoSub)
                    .foregroundColor(VialrColors.textTertiary)
            }

            Text(vial.compoundName)
                .font(VialrTypography.screenTitle)
                .foregroundColor(VialrColors.textPrimary)

            if let conc = currentState.currentConcentrationMgMl {
                Text("\(String(format: "%.2f", conc)) mg/mL Active Solution")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.accentTeal)
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard(isElevated: true)
    }

    // MARK: - 2. Variance Comparison Card
    private var varianceComparisonCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("EXPECTED VS PHYSICAL OBSERVATION")
                .vialrEyebrow()

            HStack(spacing: VialrSpacing.md) {
                // Expected Ledger Amount
                VStack(alignment: .leading, spacing: 2) {
                    Text("EXPECTED (LEDGER)")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.textTertiary)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(String(format: "%.2f", expectedVolumeMl))
                            .font(VialrTypography.metricMedium)
                            .foregroundColor(VialrColors.textSecondary)
                        Text("mL")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 36).background(VialrColors.glassBorder)

                // Observed Physical Amount
                VStack(alignment: .leading, spacing: 2) {
                    Text("OBSERVED (PHYSICAL)")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentVitality)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(String(format: "%.2f", observedVolumeMl))
                            .font(VialrTypography.metricMedium)
                            .foregroundColor(VialrColors.accentVitality)
                        Text("mL")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().background(VialrColors.glassBorder)

            // Variance Calculation
            HStack {
                Text("Calculated Variance (Delta):")
                    .font(VialrTypography.subheadline)
                    .foregroundColor(VialrColors.textSecondary)

                Spacer()

                let varianceSign = volumeVarianceMl >= 0 ? "+" : ""
                let varianceColor = abs(volumeVarianceMl) < 0.001 ? VialrColors.textSecondary : (volumeVarianceMl > 0 ? VialrColors.accentEmerald : VialrColors.accentAmber)

                Text("\(varianceSign)\(String(format: "%.2f", volumeVarianceMl)) mL (\(varianceSign)\(String(format: "%.2f", massVarianceMg)) mg)")
                    .font(VialrTypography.monoDose)
                    .fontWeight(.bold)
                    .foregroundColor(varianceColor)
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    // MARK: - 3. Observed Physical Input Card
    private var observedInputCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("ENTER OBSERVED LIQUID LEVEL")
                .vialrEyebrow()

            VialrStepper(
                title: "Observed Physical Volume",
                value: $observedVolumeMl,
                step: 0.05,
                range: 0.0...10.0,
                unit: "mL",
                format: "%.2f"
            )

            // Quick Preset Buttons
            HStack(spacing: 8) {
                quickPresetButton(label: "Empty (0 mL)", value: 0.0)
                quickPresetButton(label: "-0.05 mL", delta: -0.05)
                quickPresetButton(label: "-0.10 mL", delta: -0.10)
                quickPresetButton(label: "Reset", value: expectedVolumeMl)
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    private func quickPresetButton(label: String, value: Double? = nil, delta: Double? = nil) -> some View {
        Button {
            VialrHaptics.lightImpact()
            if let val = value {
                observedVolumeMl = max(0.0, val)
            } else if let d = delta {
                observedVolumeMl = max(0.0, round((observedVolumeMl + d) * 100) / 100)
            }
        } label: {
            Text(label)
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusSm)
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                        .stroke(VialrColors.glassBorder, lineWidth: 1)
                )
        }
    }

    // MARK: - 4. Reason Selection Card
    private var reasonSelectionCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("RECONCILIATION RATIONALE")
                .vialrEyebrow()

            Picker("Reason", selection: $selectedReason) {
                ForEach(ReconciliationReason.allCases) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .pickerStyle(.menu)
            .tint(VialrColors.accentVitality)
            .padding(8)
            .background(VialrColors.cardSurfaceElevated)
            .cornerRadius(VialrSpacing.radiusSm)

            Text(selectedReason.descriptionText)
                .font(VialrTypography.caption)
                .foregroundColor(VialrColors.textSecondary)
                .padding(.top, 2)
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    // MARK: - 5. Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
            Text("OBSERVATION NOTES")
                .vialrEyebrow()

            TextField("e.g. Visual meniscus check on Day 14, 0.1 mL dead space cumulative adjustment.", text: $notes)
                .font(VialrTypography.body)
                .padding(10)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusSm)
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    private func submitReconciliation() {
        guard !isSubmitting else { return }
        isSubmitting = true
        VialrHaptics.lightImpact()

        onReconcile(observedVolumeMl, selectedReason, notes)
        VialrHaptics.success()
        dismiss()
    }
}
