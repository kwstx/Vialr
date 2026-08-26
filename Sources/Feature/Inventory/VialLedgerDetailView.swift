import SwiftUI
import Domain
import DesignSystem
import CalculationEngine

/// Detailed accounting ledger and audit trail view for a specific vial.
/// Displays derived state metrics, concentration dynamics, and full chronological transaction history.
public struct VialLedgerDetailView: View {
    public let vial: Vial
    @Bindable public var viewModel: InventoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showReconciliationSheet: Bool = false
    @State private var showDisposalSheet: Bool = false
    @State private var showReconstitutionSheet: Bool = false
    @State private var selectedDiluentVolumeMl: Double = 2.0
    @State private var selectedDiluentType: DiluentType = .bacteriostaticWater

    public init(vial: Vial, viewModel: InventoryViewModel) {
        self.vial = vial
        self.viewModel = viewModel
    }

    private var accountingState: VialAccountingState {
        viewModel.getAccountingState(for: vial.id) ?? VialAccountingState(
            vialId: vial.id,
            compoundId: vial.compoundId,
            compoundName: vial.compoundName,
            lotNumber: vial.lotNumber,
            initialDryMassMg: vial.totalDryMassMg,
            totalDiluentVolumeMl: vial.bacWaterAddedMl ?? 0.0,
            isReconstituted: vial.isReconstituted,
            currentConcentrationMgMl: vial.concentrationMgMl,
            currentVolumeRemainingMl: vial.currentVolumeRemainingMl ?? 0.0,
            status: vial.status
        )
    }

    private var auditTrail: [InventoryEvent] {
        viewModel.getAuditTrail(for: vial.id)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // 1. Vial Header & Graphic Card
                        vialHeaderCard

                        // 2. Quick Action Toolbar
                        actionToolbar

                        // 3. Key Accounting Metrics Grid
                        accountingMetricsGrid

                        // 4. Chronological Event Ledger (Audit Trail)
                        auditLedgerSection
                    }
                    .padding(.horizontal, VialrSpacing.screenHorizontal)
                    .padding(.top, VialrSpacing.sm)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Vial Accounting Ledger")
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
            .sheet(isPresented: $showReconciliationSheet) {
                VialReconciliationSheetView(
                    vial: vial,
                    currentState: accountingState
                ) { observedMl, reason, notes in
                    Task {
                        await viewModel.reconcileVial(
                            vialId: vial.id,
                            observedVolumeMl: observedMl,
                            reason: reason,
                            notes: notes
                        )
                    }
                }
            }
            .sheet(isPresented: $showDisposalSheet) {
                VialDisposalSheetView(
                    vial: vial,
                    currentState: accountingState
                ) { reason, notes in
                    Task {
                        await viewModel.disposeVial(
                            vialId: vial.id,
                            reason: reason,
                            notes: notes
                        )
                    }
                }
            }
            .sheet(isPresented: $showReconstitutionSheet) {
                reconstitutionSheet
            }
        }
    }

    // MARK: - 1. Vial Header & Graphic Card
    private var vialHeaderCard: some View {
        VStack(spacing: VialrSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(accountingState.status.rawValue)
                            .font(VialrTypography.captionBold)
                            .foregroundColor(Color(hex: accountingState.status.badgeColorHex))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: accountingState.status.badgeColorHex).opacity(0.15))
                            .clipShape(Capsule())

                        if accountingState.isReconciled {
                            Text("Reconciled")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentAmber)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(VialrColors.accentAmber.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Text(vial.compoundName)
                        .font(VialrTypography.screenTitle)
                        .foregroundColor(VialrColors.textPrimary)
                }

                Spacer()

                if !vial.lotNumber.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("LOT NUMBER")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textTertiary)
                        Text(vial.lotNumber)
                            .font(VialrTypography.monoSub)
                            .foregroundColor(VialrColors.textPrimary)
                    }
                }
            }

            // Visual Vial Liquid Fill Bar
            VialGraphicView(
                compoundName: vial.compoundName,
                concentrationText: accountingState.currentConcentrationMgMl != nil ?
                    "\(String(format: "%.2f", accountingState.currentConcentrationMgMl!)) mg/mL" :
                    "Dry Powder (\(String(format: "%.0f", accountingState.initialDryMassMg))mg)",
                fillPercentage: accountingState.remainingFraction,
                isReconstituted: accountingState.isReconstituted,
                badgeColor: Color(hex: accountingState.status.badgeColorHex)
            )

            // Concentration & Volume Footer
            HStack {
                if let exp = accountingState.expirationDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("Exp: \(exp.formatted(date: .abbreviated, time: .omitted))")
                            .font(VialrTypography.caption)
                    }
                    .foregroundColor(VialrColors.textTertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("\(String(format: "%.2f", accountingState.currentVolumeRemainingMl)) mL remaining")
                        .font(VialrTypography.footnoteBold)
                        .foregroundColor(VialrColors.accentVitality)
                    if accountingState.isReconstituted {
                        Text("(\(String(format: "%.1f", accountingState.remainingPercentage))%)")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                }
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard(isElevated: true)
    }

    // MARK: - 2. Action Toolbar
    private var actionToolbar: some View {
        HStack(spacing: VialrSpacing.sm) {
            // Reconcile Stock Button
            Button {
                VialrHaptics.lightImpact()
                showReconciliationSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                    Text("Reconcile Stock")
                }
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusSm)
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                        .stroke(VialrColors.accentAmber.opacity(0.4), lineWidth: 1)
                )
            }

            // Reconstitute (if unopened)
            if !accountingState.isReconstituted {
                Button {
                    VialrHaptics.lightImpact()
                    showReconstitutionSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.fill")
                        Text("Reconstitute")
                    }
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(VialrColors.accentCyan)
                    .cornerRadius(VialrSpacing.radiusSm)
                }
            }

            // Dispose Button
            Button {
                VialrHaptics.lightImpact()
                showDisposalSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text("Dispose")
                }
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentRose)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusSm)
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                        .stroke(VialrColors.accentRose.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 3. Accounting Metrics Grid
    private var accountingMetricsGrid: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("LEDGER ACCOUNTING METRICS")
                .vialrEyebrow()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VialrSpacing.sm) {
                metricCard(
                    title: "INITIAL DRY MASS",
                    value: "\(String(format: "%.1f", accountingState.initialDryMassMg)) mg",
                    subtitle: "Lyophilized Powder",
                    color: VialrColors.accentCyan
                )

                metricCard(
                    title: "DILUENT ADDED",
                    value: "\(String(format: "%.2f", accountingState.totalDiluentVolumeMl)) mL",
                    subtitle: accountingState.isReconstituted ? "Active Solution" : "Not Reconstituted",
                    color: VialrColors.accentTeal
                )

                metricCard(
                    title: "DOSES DRAWN",
                    value: "\(accountingState.totalDosesAdministered)",
                    subtitle: "\(String(format: "%.2f", accountingState.totalDoseVolumeConsumedMl)) mL consumed",
                    color: VialrColors.accentEmerald
                )

                let adj = accountingState.totalReconciliationVolumeAdjustmentMl
                let adjSign = adj >= 0 ? "+" : ""
                metricCard(
                    title: "RECONCILIATION DELTA",
                    value: "\(adjSign)\(String(format: "%.2f", adj)) mL",
                    subtitle: "\(accountingState.reconciliationCount) adjustment\(accountingState.reconciliationCount == 1 ? "" : "s")",
                    color: VialrColors.accentAmber
                )
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    private func metricCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.textTertiary)
            Text(value)
                .font(VialrTypography.metricSmall)
                .foregroundColor(color)
            Text(subtitle)
                .font(VialrTypography.caption)
                .foregroundColor(VialrColors.textSecondary)
        }
        .padding(VialrSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusSm)
    }

    // MARK: - 4. Chronological Event Ledger (Audit Trail)
    private var auditLedgerSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("CHRONOLOGICAL AUDIT TRAIL")
                    .vialrEyebrow()
                Spacer()
                Text("\(auditTrail.count) Event\(auditTrail.count == 1 ? "" : "s")")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textTertiary)
            }

            if auditTrail.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.title2)
                        .foregroundColor(VialrColors.textTertiary)
                    Text("No events recorded yet")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(VialrSpacing.lg)
                .vialrCard()
            } else {
                ForEach(Array(auditTrail.enumerated()), id: \.element.id) { index, event in
                    auditEventRow(event: event, isLast: index == auditTrail.count - 1)
                }
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    private func auditEventRow(event: InventoryEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Event Type Icon Column
            VStack(spacing: 4) {
                Image(systemName: event.eventType.iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: event.eventType.badgeColorHex))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: event.eventType.badgeColorHex).opacity(0.15))
                    .clipShape(Circle())

                if !isLast {
                    Rectangle()
                        .fill(VialrColors.glassBorder)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            // Event Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.eventType.rawValue)
                        .font(VialrTypography.subheadlineBold)
                        .foregroundColor(VialrColors.textPrimary)

                    Spacer()

                    Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                }

                Text(event.reason)
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textSecondary)

                // Quantities Delta & Balance
                HStack(spacing: 8) {
                    if let vol = event.changeVolumeMl, abs(vol) > 0.0001 {
                        let sign = vol >= 0 ? "+" : ""
                        Text("Volume: \(sign)\(String(format: "%.3f", vol)) mL")
                            .font(VialrTypography.monoSub)
                            .foregroundColor(vol >= 0 ? VialrColors.accentCyan : VialrColors.accentAmber)
                    }

                    if let mass = event.changeMassMg, abs(mass) > 0.0001 {
                        let sign = mass >= 0 ? "+" : ""
                        Text("Mass: \(sign)\(String(format: "%.2f", mass)) mg")
                            .font(VialrTypography.monoSub)
                            .foregroundColor(mass >= 0 ? VialrColors.accentEmerald : VialrColors.accentAmber)
                    }
                }

                // Balance Snapshot
                if let remVol = event.resultingVolumeRemainingMl {
                    Text("↳ Balance remaining: \(String(format: "%.2f", remVol)) mL")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentVitality)
                }

                if !event.notes.isEmpty {
                    Text("Note: \(event.notes)")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                        .italic()
                }
            }
            .padding(.bottom, isLast ? 0 : 12)
        }
    }

    // MARK: - Reconstitution Sheet
    private var reconstitutionSheet: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: VialrSpacing.lg) {
                    VStack(alignment: .leading, spacing: VialrSpacing.md) {
                        Text("RECONSTITUTION PARAMETERS")
                            .vialrEyebrow()

                        VialrStepper(
                            title: "Diluent Volume Added",
                            value: $selectedDiluentVolumeMl,
                            step: 0.5,
                            range: 0.5...10.0,
                            unit: "mL",
                            format: "%.1f"
                        )

                        Picker("Diluent Type", selection: $selectedDiluentType) {
                            ForEach(DiluentType.allCases) { d in
                                Text(d.shortName).tag(d)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(VialrColors.accentCyan)
                    }
                    .padding(VialrSpacing.cardPadding)
                    .vialrCard()

                    let conc = selectedDiluentVolumeMl > 0 ? (vial.totalDryMassMg / selectedDiluentVolumeMl) : 0.0
                    Text("Resulting concentration: \(String(format: "%.2f", conc)) mg/mL (\(Int(conc * 1000)) mcg/mL)")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.accentTeal)

                    VialrButton("Commit Reconstitution Event", icon: "drop.fill", style: .primary) {
                        Task {
                            await viewModel.reconstituteVial(
                                vialId: vial.id,
                                diluentVolumeMl: selectedDiluentVolumeMl,
                                diluentType: selectedDiluentType
                            )
                            showReconstitutionSheet = false
                        }
                    }

                    Spacer()
                }
                .padding(VialrSpacing.screenHorizontal)
                .padding(.top, VialrSpacing.md)
            }
            .navigationTitle("Reconstitute Vial")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showReconstitutionSheet = false }
                        .foregroundColor(VialrColors.textSecondary)
                }
            }
        }
    }
}
