import SwiftUI
import Domain
import DesignSystem

public struct InventoryView: View {
    @Bindable public var viewModel: InventoryViewModel
    public var onAddVial: () -> Void

    public init(viewModel: InventoryViewModel, onAddVial: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onAddVial = onAddVial
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SUPPLIES & STOCK")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.accentTeal)
                                Text("Vials & Inventory")
                                    .font(VialrTypography.largeHero)
                                    .foregroundColor(VialrColors.textPrimary)
                            }

                            Spacer()

                            Button {
                                onAddVial()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color.black)
                                    .frame(width: 44, height: 44)
                                    .background(VialrColors.accentTeal)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.top, VialrSpacing.sm)

                        // Vials Section
                        vialsSection

                        // Ancillary Supplies Section
                        suppliesSection
                    }
                    .padding(.horizontal, VialrSpacing.md)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadInventory()
            }
        }
    }

    // MARK: - Vials Section
    private var vialsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("Vial Stock & Liquid Levels")
                    .font(VialrTypography.title3)
                    .foregroundColor(VialrColors.textPrimary)
                Spacer()
                Text("\(viewModel.vials.count) Vials")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textTertiary)
            }

            ForEach(viewModel.vials) { vial in
                VStack(spacing: 8) {
                    VialGraphicView(
                        compoundName: vial.compoundName,
                        concentrationText: vial.concentrationMgMl != nil ? "\(String(format: "%.1f", vial.concentrationMgMl!)) mg/mL" : "Dry Powder (\(String(format: "%.0f", vial.totalDryMassMg))mg)",
                        fillPercentage: vial.remainingFraction,
                        isReconstituted: vial.isReconstituted,
                        badgeColor: vial.status == .reconstituted ? VialrColors.accentTeal : VialrColors.accentAmber
                    )

                    // Vial Metadata Footer
                    HStack {
                        if let exp = vial.expirationDate {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                Text("Exp: \(exp.formatted(date: .abbreviated, time: .omitted))")
                                    .font(VialrTypography.caption)
                            }
                            .foregroundColor(VialrColors.textTertiary)
                        }

                        Spacer()

                        if !vial.lotNumber.isEmpty {
                            Text(vial.lotNumber)
                                .font(VialrTypography.monoSub)
                                .foregroundColor(VialrColors.textTertiary)
                        }

                        if let cost = vial.costUsd {
                            Text("$\(String(format: "%.0f", cost))")
                                .font(VialrTypography.monoSub)
                                .foregroundColor(VialrColors.accentEmerald)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
    }

    // MARK: - Supplies Section
    private var suppliesSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("Ancillary Medical Supplies")
                    .font(VialrTypography.title3)
                    .foregroundColor(VialrColors.textPrimary)
                Spacer()
            }

            ForEach(viewModel.supplies) { item in
                HStack(spacing: VialrSpacing.md) {
                    Image(systemName: item.category.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(item.isLowStock ? VialrColors.accentAmber : VialrColors.accentTeal)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)

                        HStack(spacing: 4) {
                            Text("\(item.quantityRemaining) remaining")
                                .foregroundColor(item.isLowStock ? VialrColors.accentAmber : VialrColors.textSecondary)
                            Text("• \(item.packageUnit)")
                                .foregroundColor(VialrColors.textTertiary)
                        }
                        .font(VialrTypography.caption)
                    }

                    Spacer()

                    // Increment / Decrement Stepper
                    HStack(spacing: 8) {
                        Button {
                            Task {
                                await viewModel.updateSupplyQuantity(item: item, delta: -1)
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(VialrColors.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(VialrColors.cardSurfaceElevated)
                                .clipShape(Circle())
                        }

                        Button {
                            Task {
                                await viewModel.updateSupplyQuantity(item: item, delta: 1)
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(VialrColors.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(VialrColors.accentTeal.opacity(0.25))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(VialrSpacing.md)
                .vialrCard()
            }
        }
    }
}

public struct AddVialSheetView: View {
    public var onSave: (Vial) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var compoundName: String = "BPC-157"
    @State private var dryMassMg: Double = 5.0
    @State private var bacWaterAddedMl: Double = 2.0
    @State private var isReconstituted: Bool = true
    @State private var lotNumber: String = "LOT-1090"
    @State private var vendor: String = "Precision Peptides"
    @State private var costString: String = "45.00"

    public init(onSave: @escaping (Vial) -> Void) {
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
                            Text("VIAL INFORMATION")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            VialrInputField("Compound Name", placeholder: "e.g. BPC-157, Retatrutide", value: $compoundName)
                            VialrInputField("Lot / Batch Number", placeholder: "e.g. LOT-9821A", value: $lotNumber)
                            VialrInputField("Vendor / Source", placeholder: "e.g. Research Lab", value: $vendor)
                            VialrInputField("Cost (USD)", placeholder: "45.00", value: $costString, isNumeric: true)
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            Text("MASS & RECONSTITUTION")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            VialrStepper(title: "Lyophilized Mass", value: $dryMassMg, step: 1.0, range: 1...100, unit: "mg", format: "%.1f")

                            Toggle("Already Reconstituted with BAC Water", isOn: $isReconstituted)
                                .tint(VialrColors.accentTeal)

                            if isReconstituted {
                                VialrStepper(title: "Bacteriostatic Water Added", value: $bacWaterAddedMl, step: 0.5, range: 0.5...10, unit: "mL", format: "%.1f")
                            }
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        VialrButton("Add Vial to Inventory", icon: "plus.circle.fill", style: .primary) {
                            let cost = Double(costString)
                            let vial = Vial(
                                compoundId: UUID(),
                                compoundName: compoundName,
                                lotNumber: lotNumber,
                                vendor: vendor,
                                totalDryMassMg: dryMassMg,
                                bacWaterAddedMl: isReconstituted ? bacWaterAddedMl : nil,
                                currentVolumeRemainingMl: isReconstituted ? bacWaterAddedMl : nil,
                                isReconstituted: isReconstituted,
                                reconstitutedDate: isReconstituted ? Date() : nil,
                                expirationDate: isReconstituted ? Calendar.current.date(byAdding: .day, value: 28, to: Date()) : nil,
                                costUsd: cost,
                                status: isReconstituted ? .reconstituted : .unopened
                            )
                            onSave(vial)
                            dismiss()
                        }
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("Add Vial")
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
