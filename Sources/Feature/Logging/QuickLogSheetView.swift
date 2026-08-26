import SwiftUI
import Domain
import DesignSystem
import CalculationEngine

public struct QuickLogSheetView: View {
    public var preselectedDose: DoseLog?
    public var availableVials: [Vial]
    public var onSave: (DoseLog) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var compoundName: String = "BPC-157"
    @State private var doseAmount: Double = 250.0
    @State private var doseUnit: DoseUnit = .mcg
    @State private var selectedSiteId: String? = "ab_l_uo"
    @State private var selectedVialId: UUID?
    @State private var route: AdministrationRoute = .subcutaneous
    @State private var notes: String = ""
    @State private var logDate: Date = Date()

    private let siteRotationEngine = SiteRotationEngine()

    public init(
        preselectedDose: DoseLog? = nil,
        availableVials: [Vial] = [],
        onSave: @escaping (DoseLog) -> Void
    ) {
        self.preselectedDose = preselectedDose
        self.availableVials = availableVials
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: VialrSpacing.lg) {
                        // Compound & Large Dosage Display
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            HStack {
                                Text("DOSE DETAILS")
                                    .vialrEyebrow()
                                Spacer()
                                Text(route.shortName)
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.accentVitality)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(VialrColors.accentVitality.opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            Text(compoundName)
                                .font(VialrTypography.title1)
                                .foregroundColor(VialrColors.textPrimary)

                            HStack(alignment: .lastTextBaseline, spacing: 6) {
                                Text(formatAmount(doseAmount))
                                    .font(VialrTypography.metricHero)
                                    .foregroundColor(VialrColors.accentVitality)
                                    .tracking(-0.5)

                                Text(doseUnit.rawValue)
                                    .font(VialrTypography.title3)
                                    .foregroundColor(VialrColors.accentVitality)
                            }

                            // Stepper
                            VialrStepper(
                                title: "ADJUST AMOUNT",
                                value: $doseAmount,
                                step: doseUnit == .mcg ? 50 : 0.5,
                                range: 1...10000,
                                unit: doseUnit.rawValue,
                                format: doseUnit == .mg ? "%.2f" : "%.0f"
                            )

                            DatePicker("Time", selection: $logDate)
                                .font(VialrTypography.subheadline)
                                .padding(VialrSpacing.sm)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusSm)
                        }
                        .padding(VialrSpacing.cardPadding)
                        .vialrCard()

                        // Injection Site Selection (Body Map)
                        let siteItems = InjectionSite.standardSites.map { s in
                            SiteSelectionItem(
                                id: s.id,
                                name: s.name,
                                shortLabel: s.shortName,
                                region: s.region,
                                side: s.side,
                                coordinates: s.coordinates,
                                daysSinceLastUse: s.id == "ab_r_uo" ? 8 : (s.id == "ab_l_uo" ? 1 : 4),
                                isRecommended: s.id == "ab_r_uo"
                            )
                        }

                        BodyMapSelectorView(
                            sites: siteItems,
                            selectedSiteId: $selectedSiteId,
                            lastSiteId: "ab_l_uo",
                            nextSiteId: "ab_r_uo"
                        )

                        // Reconstituted Vial Selection (if available)
                        if !availableVials.isEmpty {
                            vialSelectorSection
                        }

                        // Notes Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOTES")
                                .vialrEyebrow()

                            TextField("e.g. Post-workout, zero sting", text: $notes)
                                .font(VialrTypography.body)
                                .padding(VialrSpacing.md)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusMd)
                        }

                        // Confirm & Log CTA
                        VialrButton("Confirm & Log Dose", icon: "checkmark.circle.fill", style: .vitality, size: .large) {
                            VialrHaptics.doseConfirmed()
                            let site = InjectionSite.standardSites.first(where: { $0.id == selectedSiteId })
                            let log = DoseLog(
                                id: preselectedDose?.id ?? UUID(),
                                protocolId: preselectedDose?.protocolId,
                                protocolItemId: preselectedDose?.protocolItemId,
                                compoundId: preselectedDose?.compoundId ?? UUID(),
                                compoundName: compoundName,
                                scheduledDate: preselectedDose?.scheduledDate ?? logDate,
                                loggedDate: logDate,
                                doseAmount: doseAmount,
                                doseUnit: doseUnit,
                                status: .taken,
                                injectionSiteId: selectedSiteId,
                                injectionSiteName: site?.name,
                                vialId: selectedVialId ?? availableVials.first?.id,
                                administrationRoute: route,
                                notes: notes
                            )
                            onSave(log)
                            dismiss()
                        }
                    }
                    .padding(VialrSpacing.screenHorizontal)
                    .padding(.bottom, VialrSpacing.xl)
                }
            }
            .navigationTitle("Log Dose")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(VialrColors.textSecondary)
                }
            }
            .onAppear {
                if let dose = preselectedDose {
                    compoundName = dose.compoundName
                    doseAmount = dose.doseAmount
                    doseUnit = dose.doseUnit
                    route = dose.administrationRoute
                    selectedSiteId = dose.injectionSiteId ?? "ab_r_uo"
                }
            }
        }
    }

    private var vialSelectorSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("DRAWING FROM VIAL")
                .vialrEyebrow()

            ForEach(availableVials) { vial in
                let isSelected = (selectedVialId ?? availableVials.first?.id) == vial.id
                Button {
                    VialrHaptics.selection()
                    selectedVialId = vial.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(vial.compoundName) (Lot: \(vial.lotNumber.isEmpty ? "Standard" : vial.lotNumber))")
                                .font(VialrTypography.headline)
                                .foregroundColor(VialrColors.textPrimary)
                            Text("\(String(format: "%.1f", vial.currentVolumeRemainingMl ?? 0)) mL remaining")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textSecondary)
                        }
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(VialrColors.accentVitality)
                        }
                    }
                    .padding(VialrSpacing.sm)
                    .vialrCard(isSelected: isSelected)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        amount.truncatingRemainder(dividingBy: 1) == 0 ?
            String(format: "%.0f", amount) :
            String(format: "%.1f", amount)
    }
}
