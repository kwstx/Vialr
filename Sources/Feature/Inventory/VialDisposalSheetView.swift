import SwiftUI
import Domain
import DesignSystem

/// Audited vial disposal sheet allowing users to record disposal events with clinical justification.
public struct VialDisposalSheetView: View {
    public let vial: Vial
    public let currentState: VialAccountingState
    public var onDispose: (DisposalReason, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: DisposalReason = .depleted
    @State private var notes: String = ""
    @State private var isSubmitting: Bool = false

    public init(
        vial: Vial,
        currentState: VialAccountingState,
        onDispose: @escaping (DisposalReason, String) -> Void
    ) {
        self.vial = vial
        self.currentState = currentState
        self.onDispose = onDispose
        if currentState.currentVolumeRemainingMl <= 0.001 {
            self._selectedReason = State(initialValue: .depleted)
        } else if vial.isExpired {
            self._selectedReason = State(initialValue: .expired)
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("AUDITED VIAL DISPOSAL")
                                    .font(VialrTypography.captionBold)
                                    .tracking(1.1)
                                    .foregroundColor(VialrColors.accentRose)
                                Spacer()
                                Text(vial.lotNumber.isEmpty ? "Lot: Standard" : "Lot: \(vial.lotNumber)")
                                    .font(VialrTypography.monoSub)
                                    .foregroundColor(VialrColors.textTertiary)
                            }

                            Text(vial.compoundName)
                                .font(VialrTypography.screenTitle)
                                .foregroundColor(VialrColors.textPrimary)

                            Text("Disposing this vial zeroes remaining stock while preserving its complete event audit trail.")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textSecondary)
                        }
                        .padding(VialrSpacing.cardPadding)
                        .vialrCard(isElevated: true)

                        // Remaining Stock Snapshot
                        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                            Text("STOCK LEVEL AT DISPOSAL")
                                .vialrEyebrow()

                            HStack(spacing: VialrSpacing.md) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("VOLUME TO DISPOSE")
                                        .font(VialrTypography.captionBold)
                                        .foregroundColor(VialrColors.textTertiary)
                                    Text("\(String(format: "%.2f", currentState.currentVolumeRemainingMl)) mL")
                                        .font(VialrTypography.metricSmall)
                                        .foregroundColor(VialrColors.textPrimary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("ACTIVE MASS")
                                        .font(VialrTypography.captionBold)
                                        .foregroundColor(VialrColors.textTertiary)
                                    Text("\(String(format: "%.2f", currentState.currentMassRemainingMg)) mg")
                                        .font(VialrTypography.metricSmall)
                                        .foregroundColor(VialrColors.textPrimary)
                                }
                            }
                        }
                        .padding(VialrSpacing.cardPadding)
                        .vialrCard()

                        // Reason Selector
                        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                            Text("DISPOSAL REASON")
                                .vialrEyebrow()

                            Picker("Reason", selection: $selectedReason) {
                                ForEach(DisposalReason.allCases) { r in
                                    Text(r.rawValue).tag(r)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(VialrColors.accentRose)
                            .padding(8)
                            .background(VialrColors.cardSurfaceElevated)
                            .cornerRadius(VialrSpacing.radiusSm)
                        }
                        .padding(VialrSpacing.cardPadding)
                        .vialrCard()

                        // Notes
                        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
                            Text("DISPOSAL NOTES / DISPOSITION METHOD")
                                .vialrEyebrow()

                            TextField("e.g. Sharps container disposal, expired beyond 30-day window.", text: $notes)
                                .font(VialrTypography.body)
                                .padding(10)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusSm)
                        }
                        .padding(VialrSpacing.cardPadding)
                        .vialrCard()

                        // Action Button
                        VialrButton(
                            isSubmitting ? "Recording Disposal..." : "Confirm & Dispose Vial",
                            icon: "trash.fill",
                            style: .destructive,
                            size: .large,
                            isLoading: isSubmitting
                        ) {
                            submitDisposal()
                        }
                        .disabled(isSubmitting)
                        .padding(.top, VialrSpacing.sm)
                        .padding(.bottom, VialrSpacing.xl)
                    }
                    .padding(.horizontal, VialrSpacing.screenHorizontal)
                    .padding(.top, VialrSpacing.sm)
                }
            }
            .navigationTitle("Dispose Vial")
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

    private func submitDisposal() {
        guard !isSubmitting else { return }
        isSubmitting = true
        VialrHaptics.lightImpact()

        onDispose(selectedReason, notes)
        VialrHaptics.success()
        dismiss()
    }
}
