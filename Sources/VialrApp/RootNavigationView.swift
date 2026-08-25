import SwiftUI
import Domain
import DesignSystem
import Feature
import Data

public struct RootNavigationView: View {
    @Bindable public var coordinator: AppCoordinator
    public let container: AppContainer

    // View Models
    @State private var onboardingVM = OnboardingViewModel()
    @State private var dashboardVM: DashboardViewModel
    @State private var protocolsVM: ProtocolsViewModel
    @State private var inventoryVM: InventoryViewModel
    @State private var siteRotationVM: SiteRotationViewModel
    @State private var analyticsVM: AnalyticsViewModel
    @State private var reconstitutionVM = ReconstitutionViewModel()

    public init(coordinator: AppCoordinator, container: AppContainer = .shared) {
        self.coordinator = coordinator
        self.container = container

        _dashboardVM = State(initialValue: DashboardViewModel(
            protocolRepo: container.protocolRepository,
            doseRepo: container.doseLogRepository,
            vialRepo: container.vialRepository,
            supplyRepo: container.supplyRepository,
            biomarkerRepo: container.biomarkerRepository
        ))

        _protocolsVM = State(initialValue: ProtocolsViewModel(
            protocolRepo: container.protocolRepository
        ))

        _inventoryVM = State(initialValue: InventoryViewModel(
            vialRepo: container.vialRepository,
            supplyRepo: container.supplyRepository,
            protocolRepo: container.protocolRepository
        ))

        _siteRotationVM = State(initialValue: SiteRotationViewModel(
            doseRepo: container.doseLogRepository
        ))

        _analyticsVM = State(initialValue: AnalyticsViewModel(
            doseRepo: container.doseLogRepository,
            biomarkerRepo: container.biomarkerRepository,
            symptomRepo: container.symptomRepository,
            costRepo: container.costRepository
        ))
    }

    public var body: some View {
        ZStack {
            if !coordinator.hasCompletedOnboarding {
                OnboardingFlowView(viewModel: onboardingVM) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        coordinator.hasCompletedOnboarding = true
                    }
                    coordinator.showToast(title: "Welcome to Vialr", message: "Your personalized protocol suite is ready.")
                }
            } else {
                mainTabContent
            }

            // Toast Alert Overlay
            if let toast = coordinator.currentToast {
                VStack {
                    ToastBannerView(toast: toast) {
                        withAnimation {
                            coordinator.currentToast = nil
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 48)
                    Spacer()
                }
                .zIndex(100)
            }
        }
        .sheet(item: $coordinator.activeSheet) { sheet in
            sheetDestination(sheet)
        }
    }

    // MARK: - Main Tab Content
    private var mainTabContent: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $coordinator.selectedTab) {
                DashboardView(
                    viewModel: dashboardVM,
                    onOpenQuickLog: { dose in coordinator.presentSheet(.quickLog(dose)) },
                    onOpenReconstitution: { coordinator.presentSheet(.reconstitution) },
                    onOpenSiteRotation: { coordinator.presentSheet(.siteRotation) },
                    onOpenProtocolDetail: { proto in coordinator.presentSheet(.protocolDetail(proto)) }
                )
                .tag(AppTab.dashboard)

                ProtocolsListView(
                    viewModel: protocolsVM,
                    onSelectProtocol: { proto in coordinator.presentSheet(.protocolDetail(proto)) },
                    onCreateProtocol: { coordinator.presentSheet(.createProtocol) },
                    onCompareProtocols: { coordinator.presentSheet(.protocolComparison) }
                )
                .tag(AppTab.protocols)

                InventoryView(
                    viewModel: inventoryVM,
                    onAddVial: { coordinator.presentSheet(.addVial) }
                )
                .tag(AppTab.inventory)

                AnalyticsView(
                    viewModel: analyticsVM
                )
                .tag(AppTab.analytics)

                SettingsView(
                    onOpenClinicianReport: { coordinator.presentSheet(.clinicianReport) }
                )
                .tag(AppTab.settings)
            }

            // Sleek Floating Modern Tab Bar
            floatingTabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Floating Tab Bar
    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = coordinator.selectedTab == tab
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        coordinator.selectedTab = tab
                    }
                    #if os(iOS)
                    UISelectionFeedbackGenerator().selectionChanged()
                    #endif
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? VialrColors.accentTeal : VialrColors.textTertiary)

                        Text(tab.rawValue)
                            .font(VialrTypography.caption)
                            .foregroundColor(isSelected ? VialrColors.textPrimary : VialrColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusPill, style: .continuous)
                .fill(VialrColors.cardSurfaceElevated.opacity(0.95))
                .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusPill, style: .continuous)
                .stroke(VialrColors.glassBorder, lineWidth: 1)
        )
        .padding(.horizontal, VialrSpacing.lg)
        .padding(.bottom, VialrSpacing.sm)
    }

    // MARK: - Sheet Router
    @ViewBuilder
    private func sheetDestination(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .quickLog(let dose):
            QuickLogSheetView(
                preselectedDose: dose,
                availableVials: inventoryVM.vials,
                onSave: { newLog in
                    Task {
                        try? await container.doseLogRepository.save(newLog)
                        await dashboardVM.loadDashboardData()
                        await inventoryVM.loadInventory()
                        coordinator.showToast(title: "Dose Logged Successfully", message: "\(newLog.compoundName) \(String(format: "%.0f", newLog.doseAmount)) \(newLog.doseUnit.rawValue)")
                    }
                }
            )

        case .reconstitution:
            ReconstitutionCalculatorView(viewModel: reconstitutionVM) { newVial in
                Task {
                    try? await container.vialRepository.save(newVial)
                    await inventoryVM.loadInventory()
                    coordinator.showToast(title: "Vial Added to Inventory", message: "\(newVial.compoundName) (\(String(format: "%.1f", newVial.totalDryMassMg))mg)")
                }
            }

        case .siteRotation:
            SiteRotationView(viewModel: siteRotationVM)

        case .createProtocol:
            CreateProtocolView { newProtocol in
                Task {
                    try? await container.protocolRepository.save(newProtocol)
                    await protocolsVM.loadProtocols()
                    await dashboardVM.loadDashboardData()
                    coordinator.showToast(title: "Protocol Created", message: newProtocol.name)
                }
            }

        case .protocolDetail(let proto):
            ProtocolDetailView(
                protocolModel: proto,
                onEdit: { updated in
                    Task {
                        try? await container.protocolRepository.save(updated)
                        await protocolsVM.loadProtocols()
                    }
                },
                onToggleStatus: { target in
                    var mod = target
                    mod.status = target.status == .active ? .paused : .active
                    Task {
                        try? await container.protocolRepository.save(mod)
                        await protocolsVM.loadProtocols()
                        await dashboardVM.loadDashboardData()
                    }
                }
            )

        case .protocolComparison:
            ProtocolComparisonView(protocols: protocolsVM.allProtocols)

        case .addVial:
            AddVialSheetView { newVial in
                Task {
                    try? await container.vialRepository.save(newVial)
                    await inventoryVM.loadInventory()
                    coordinator.showToast(title: "Vial Added", message: "\(newVial.compoundName) in stock.")
                }
            }

        case .logSymptoms:
            SymptomLogSheetView { log in
                Task {
                    try? await container.symptomRepository.save(log)
                    coordinator.showToast(title: "Symptoms Logged")
                }
            }

        case .logBiomarker:
            BiomarkerLogSheetView { b in
                Task {
                    try? await container.biomarkerRepository.save(b)
                    coordinator.showToast(title: "Biomarker Saved", message: "\(b.name): \(b.value) \(b.unit)")
                }
            }

        case .clinicianReport:
            ClinicianReportView()
        }
    }
}
