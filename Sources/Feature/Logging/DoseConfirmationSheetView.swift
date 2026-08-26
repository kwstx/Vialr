import SwiftUI
import Domain
import DesignSystem
import CalculationEngine

/// Minimal, high-contrast confirmation interface opened when logging a scheduled or PRN dose.
/// Pre-populates the expected protocol, planned dose, optimal rotation injection site, and attached vial.
public struct DoseConfirmationSheetView: View {
    public let engine: DoseLoggingEngineProtocol
    public var preselectedDose: DoseLog?
    public var preselectedOccurrence: ExpectedDoseOccurrence?
    public var preselectedProtocol: ProtocolModel?
    public var availableVials: [Vial]
    public var onCompleted: (DoseLoggingResult) -> Void

    @Environment(\.dismiss) private var dismiss

    // Editable State
    @State private var request: DoseConfirmationRequest = DoseConfirmationRequest(
        compoundId: UUID(),
        compoundName: "BPC-157",
        plannedDoseAmount: 250,
        actualDoseAmount: 250,
        doseUnit: .mcg
    )
    @State private var selectedVial: Vial?
    @State private var isLoading: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var showAdvancedOptions: Bool = false
    @State private var showFullBodyMap: Bool = false
    @State private var errorMessage: String?

    public init(
        engine: DoseLoggingEngineProtocol,
        preselectedDose: DoseLog? = nil,
        preselectedOccurrence: ExpectedDoseOccurrence? = nil,
        preselectedProtocol: ProtocolModel? = nil,
        availableVials: [Vial] = [],
        onCompleted: @escaping (DoseLoggingResult) -> Void
    ) {
        self.engine = engine
        self.preselectedDose = preselectedDose
        self.preselectedOccurrence = preselectedOccurrence
        self.preselectedProtocol = preselectedProtocol
        self.availableVials = availableVials
        self.onCompleted = onCompleted
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                if isLoading {
                    VStack(spacing: VialrSpacing.md) {
                        ProgressView()
                            .tint(VialrColors.accentVitality)
                        Text("Loading protocol context...")
                            .font(VialrTypography.footnote)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: VialrSpacing.md) {
                            // 1. Expected Protocol & Planned Dose Header Card
                            protocolHeaderCard

                            // 2. Confirmed Amount & Quick Stepper
                            dosageConfirmationCard

                            // 3. Injection Site Confirmation (Site Rotation Engine)
                            injectionSiteCard

                            // 4. Attached Reconstituted Vial & Draw Info (Inventory Engine)
                            vialDrawCard

                            // 5. Administration Time
                            timestampCard

                            // 6. Optional Notes & Reaction Details (Collapsible)
                            advancedDetailsSection

                            // 7. Error Alert Banner (if any)
                            if let error = errorMessage {
                                Text(error)
                                    .font(VialrTypography.footnote)
                                    .foregroundColor(VialrColors.accentRose)
                                    .padding(VialrSpacing.sm)
                                    .frame(maxWidth: .infinity)
                                    .background(VialrColors.accentRose.opacity(0.12))
                                    .cornerRadius(VialrSpacing.radiusSm)
                            }

                            // 8. Confirm & Log CTA Button
                            VStack(spacing: VialrSpacing.xs) {
                                VialrButton(
                                    isSubmitting ? "Logging Dose..." : "Confirm & Log Dose",
                                    icon: "checkmark.circle.fill",
                                    style: .vitality,
                                    size: .large,
                                    isLoading: isSubmitting
                                ) {
                                    submitConfirmedDose()
                                }
                                .disabled(isSubmitting)

                                Text("One tap updates inventory, site rotation, analytics & reminders.")
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
            }
            .navigationTitle("Confirm Dose")
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
            .task {
                await loadConfirmationContext()
            }
        }
    }

    // MARK: - 1. Protocol Header Card
    private var protocolHeaderCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(request.protocolId != nil ? "EXPECTED PROTOCOL DOSE" : "UNSCHEDULED / PRN DOSE")
                    .font(VialrTypography.captionBold)
                    .tracking(1.1)
                    .foregroundColor(VialrColors.accentVitality)

                Spacer()

                if let planned = request.plannedDoseAmount {
                    Text("Planned: \(formatAmount(planned)) \(request.doseUnit.rawValue)")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                }
            }

            Text(request.compoundName)
                .font(VialrTypography.screenTitle)
                .foregroundColor(VialrColors.textPrimary)

            HStack(spacing: 8) {
                Text(request.actualRoute.rawValue)
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textSecondary)

                if request.actualDoseAmount != (request.plannedDoseAmount ?? request.actualDoseAmount) {
                    Text("• Adjusted Dose")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentAmber)
                }
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard(isElevated: true)
    }

    // MARK: - 2. Dosage Confirmation Card
    private var dosageConfirmationCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("ADMINISTERED AMOUNT")
                .vialrEyebrow()

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(formatAmount(request.actualDoseAmount))
                    .font(VialrTypography.largeHero)
                    .foregroundColor(VialrColors.textPrimary)

                Text(request.doseUnit.rawValue)
                    .font(VialrTypography.title3)
                    .foregroundColor(VialrColors.accentVitality)
            }

            // Quick Step Increment Buttons
            HStack(spacing: VialrSpacing.xs) {
                let step = request.doseUnit == .mcg ? 50.0 : (request.doseUnit == .mg ? 0.5 : 1.0)
                let fineStep = request.doseUnit == .mcg ? 10.0 : 0.1

                dosageAdjustmentButton(delta: -step, label: "-\(formatAmount(step))")
                dosageAdjustmentButton(delta: -fineStep, label: "-\(formatAmount(fineStep))")
                dosageAdjustmentButton(delta: fineStep, label: "+\(formatAmount(fineStep))")
                dosageAdjustmentButton(delta: step, label: "+\(formatAmount(step))")

                if let planned = request.plannedDoseAmount, request.actualDoseAmount != planned {
                    Button {
                        VialrHaptics.lightImpact()
                        request.actualDoseAmount = planned
                    } label: {
                        Text("Reset")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentVitality)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(VialrColors.cardSurfaceSubtle)
                            .cornerRadius(VialrSpacing.radiusSm)
                    }
                }
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    private func dosageAdjustmentButton(delta: Double, label: String) -> some View {
        Button {
            VialrHaptics.lightImpact()
            let newAmount = max(0.0, request.actualDoseAmount + delta)
            request.actualDoseAmount = round(newAmount * 100) / 100
        } label: {
            Text(label)
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusSm)
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                        .stroke(VialrColors.glassBorder, lineWidth: 1)
                )
        }
    }

    // MARK: - 3. Injection Site Confirmation Card
    private var injectionSiteCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("INJECTION SITE (ROTATION)")
                    .vialrEyebrow()

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showFullBodyMap.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showFullBodyMap ? "Hide Map" : "Body Map")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentVitality)
                        Image(systemName: showFullBodyMap ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(VialrColors.accentVitality)
                    }
                }
            }

            // Recommended Site Indicator
            HStack(spacing: VialrSpacing.xs) {
                Image(systemName: "cross.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(VialrColors.accentVitality)

                Text(request.injectionSiteName ?? "Select injection site")
                    .font(VialrTypography.bodyMedium)
                    .foregroundColor(VialrColors.textPrimary)

                Spacer()

                Text("Optimal Rotation")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.accentEmerald)
            }
            .padding(VialrSpacing.sm)
            .background(VialrColors.cardSurfaceElevated)
            .cornerRadius(VialrSpacing.radiusSm)

            // Horizontal Quick Selection Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(InjectionSite.standardSites) { site in
                        let isSelected = request.injectionSiteId == site.id
                        Button {
                            VialrHaptics.lightImpact()
                            request.injectionSiteId = site.id
                            request.injectionSiteName = site.name
                        } label: {
                            Text(site.name.replacingOccurrences(of: "Abdomen - ", with: "Ab: "))
                                .font(VialrTypography.caption)
                                .fontWeight(isSelected ? .bold : .medium)
                                .foregroundColor(isSelected ? VialrColors.textInverse : VialrColors.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isSelected ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(isSelected ? Color.clear : VialrColors.glassBorder, lineWidth: 1)
                                )
                        }
                    }
                }
            }

            // Expandable Body Map Selector
            if showFullBodyMap {
                let siteItems = InjectionSite.standardSites.map { s in
                    SiteSelectionItem(
                        id: s.id,
                        name: s.name,
                        shortLabel: s.name.replacingOccurrences(of: "Abdomen - ", with: ""),
                        daysSinceLastUse: s.id == request.injectionSiteId ? 8 : 4,
                        isRecommended: s.id == request.injectionSiteId
                    )
                }

                BodyMapSelectorView(sites: siteItems, selectedSiteId: Binding(
                    get: { request.injectionSiteId },
                    set: { newId in
                        request.injectionSiteId = newId
                        if let s = InjectionSite.standardSites.first(where: { $0.id == newId }) {
                            request.injectionSiteName = s.name
                        }
                    }
                ))
                .padding(.top, 4)
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    // MARK: - 4. Vial & Draw Volume Card
    private var vialDrawCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("VIAL & DRAW CALCULATION")
                .vialrEyebrow()

            if let vial = selectedVial {
                HStack(spacing: VialrSpacing.sm) {
                    Image(systemName: "cross.vial.fill")
                        .font(.system(size: 20))
                        .foregroundColor(VialrColors.accentCyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(vial.compoundName) (Lot: \(vial.lotNumber.isEmpty ? "Standard" : vial.lotNumber))")
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)

                        Text("\(String(format: "%.2f", vial.currentVolumeRemainingMl ?? 0)) mL remaining in stock")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)
                    }

                    Spacer()

                    if let drawMl = vial.drawVolumeMl(for: request.actualDoseAmount, unit: request.doseUnit),
                       let units = vial.u100SyringeUnits(for: request.actualDoseAmount, unit: request.doseUnit) {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(String(format: "%.1f", units)) IU")
                                .font(VialrTypography.metricSmall)
                                .foregroundColor(VialrColors.accentVitality)
                            Text("(\(String(format: "%.2f", drawMl)) mL)")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                        }
                    }
                }
                .padding(VialrSpacing.sm)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusSm)
            } else {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(VialrColors.textTertiary)
                    Text("No reconstituted vial selected. Dose will be logged directly.")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .padding(VialrSpacing.sm)
                .background(VialrColors.cardSurfaceSubtle)
                .cornerRadius(VialrSpacing.radiusSm)
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    // MARK: - 5. Timestamp Card
    private var timestampCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ADMINISTRATION TIME")
                    .vialrEyebrow()
                DatePicker("", selection: $request.actualTimestamp)
                    .labelsHidden()
                    .font(VialrTypography.body)
            }

            Spacer()

            Button {
                VialrHaptics.lightImpact()
                request.actualTimestamp = Date()
            } label: {
                Text("Now")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentVitality)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(VialrColors.cardSurfaceElevated)
                    .cornerRadius(VialrSpacing.radiusSm)
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    // MARK: - 6. Advanced Details Section
    private var advancedDetailsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showAdvancedOptions.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(VialrColors.textSecondary)
                    Text("Needle, Reaction & Notes")
                        .font(VialrTypography.subheadline)
                        .foregroundColor(VialrColors.textPrimary)
                    Spacer()
                    Image(systemName: showAdvancedOptions ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(VialrColors.textTertiary)
                }
            }

            if showAdvancedOptions {
                VStack(alignment: .leading, spacing: VialrSpacing.md) {
                    // Needle Parameters
                    HStack(spacing: VialrSpacing.sm) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Needle Gauge")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                            TextField("31G", text: Binding(
                                get: { request.needleGauge ?? "31G" },
                                set: { request.needleGauge = $0 }
                            ))
                            .font(VialrTypography.subheadline)
                            .padding(8)
                            .background(VialrColors.cardSurfaceElevated)
                            .cornerRadius(VialrSpacing.radiusSm)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Needle Length")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                            TextField("5/16\"", text: Binding(
                                get: { request.needleLength ?? "5/16\"" },
                                set: { request.needleLength = $0 }
                            ))
                            .font(VialrTypography.subheadline)
                            .padding(8)
                            .background(VialrColors.cardSurfaceElevated)
                            .cornerRadius(VialrSpacing.radiusSm)
                        }
                    }

                    // Site Reaction Severity
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Site Reaction Severity")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)

                        Picker("Site Reaction", selection: $request.siteReaction) {
                            ForEach(SiteReactionSeverity.allCases) { r in
                                Text(r.rawValue).tag(r)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(VialrColors.accentVitality)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optional Notes")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)

                        TextField("e.g. Taken post-workout on empty stomach, zero sting.", text: $request.notes)
                            .font(VialrTypography.body)
                            .padding(10)
                            .background(VialrColors.cardSurfaceElevated)
                            .cornerRadius(VialrSpacing.radiusSm)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    // MARK: - Data Loading & Actions
    private func loadConfirmationContext() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let occurrence = preselectedOccurrence {
                request = try await engine.prepareConfirmationRequest(for: occurrence)
            } else if let dose = preselectedDose {
                request = try await engine.prepareConfirmationRequest(for: dose)
            } else if let proto = preselectedProtocol, let firstCompound = proto.compounds.first {
                request = try await engine.prepareConfirmationRequest(forProtocol: proto.id, compoundId: firstCompound.compoundId)
            }

            // Find matching vial
            if let vId = request.vialId {
                selectedVial = availableVials.first(where: { $0.id == vId })
            } else {
                selectedVial = availableVials.first(where: { $0.compoundId == request.compoundId && $0.isReconstituted })
                request.vialId = selectedVial?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitConfirmedDose() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        VialrHaptics.lightImpact()

        Task {
            do {
                let result = try await engine.logDose(request)
                VialrHaptics.success()
                onCompleted(result)
                dismiss()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
                VialrHaptics.error()
            }
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        amount.truncatingRemainder(dividingBy: 1) == 0 ?
            String(format: "%.0f", amount) :
            String(format: "%.1f", amount)
    }
}
