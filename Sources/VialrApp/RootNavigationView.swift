import SwiftUI
import Domain
import DesignSystem
import Feature
import Data

public struct RootNavigationView: View {
    @Bindable public var coordinator: AppCoordinator
    public let container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    // View Models
    @State private var onboardingVM = OnboardingViewModel()
    @State private var dashboardVM: DashboardViewModel
    @State private var protocolsVM: ProtocolsViewModel
    @State private var loggingVM: LoggingViewModel
    @State private var bloodworkVM: BloodworkViewModel
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
            biomarkerRepo: container.biomarkerRepository,
            userRepo: LocalUserRepository(),
            siteEventRepo: container.injectionSiteEventRepository,
            doseLoggingEngine: container.doseLoggingEngine
        ))

        _protocolsVM = State(initialValue: ProtocolsViewModel(
            protocolRepo: container.protocolRepository
        ))

        _loggingVM = State(initialValue: LoggingViewModel(
            doseRepo: container.doseLogRepository,
            protocolRepo: container.protocolRepository,
            vialRepo: container.vialRepository,
            siteEventRepo: container.injectionSiteEventRepository,
            doseLoggingEngine: container.doseLoggingEngine
        ))

        _bloodworkVM = State(initialValue: BloodworkViewModel(
            labPanelRepo: container.labPanelRepository,
            biomarkerRepo: container.biomarkerRepository
        ))

        _inventoryVM = State(initialValue: InventoryViewModel(
            vialRepo: container.vialRepository,
            supplyRepo: container.supplyRepository,
            protocolRepo: container.protocolRepository
        ))

        _siteRotationVM = State(initialValue: SiteRotationViewModel(
            doseRepo: container.doseLogRepository,
            siteEventRepo: container.injectionSiteEventRepository
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
            // Main Content Router
            if !coordinator.hasCompletedOnboarding {
                OnboardingFlowView(viewModel: onboardingVM) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        coordinator.hasCompletedOnboarding = true
                    }
                    coordinator.showToast(title: "Welcome to Vialr", message: "Your personalized protocol suite is ready.")
                }
            } else if !coordinator.isAuthenticated {
                AuthenticationView { authenticatedUser in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        coordinator.isAuthenticated = true
                    }
                    coordinator.showToast(title: "Signed In", message: "Welcome back, \(authenticatedUser.accountInfo.displayName).")
                }
            } else {
                mainTabContent
            }

            // Privacy Blur Overlay for Multitasking / App Switcher (Prevents dosage data leakage)
            if coordinator.securityManager.isPrivacyMaskActive {
                ZStack {
                    VialrColors.backgroundPrimary
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 44))
                            .foregroundColor(VialrColors.accentVitality)
                        Text("Vialr")
                            .font(VialrTypography.largeHero)
                            .foregroundColor(VialrColors.textPrimary)
                    }
                }
                .transition(.opacity)
                .zIndex(90)
            }

            // Local Biometric App Lock Gatekeeper
            if coordinator.securityManager.isAppLocked && coordinator.isAuthenticated {
                BiometricLockView(securityManager: coordinator.securityManager)
                    .transition(.opacity)
                    .zIndex(95)
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
        .task {
            let notifManager = NotificationClientManager.shared
            await notifManager.initialize()
            notifManager.onDoseLogRequested = { _ in
                coordinator.presentSheet(.quickLog(nil))
            }
            notifManager.onDeepLinkTriggered = { url in
                coordinator.handleDeepLink(url)
            }
        }
        .onOpenURL { url in
            coordinator.handleDeepLink(url)
        }
        .onChange(of: scenePhase) { _, newPhase in
            coordinator.securityManager.handleScenePhaseChange(to: newPhase)
        }
    }

    // MARK: - Main Tab Content (5 Primary Tabs with Independent Navigation Stacks)
    private var mainTabContent: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $coordinator.selectedTab) {
                // Tab 1: Home / Dashboard
                homeNavigationStack
                    .tag(AppTab.home)

                // Tab 2: Protocols & Stacks
                protocolsNavigationStack
                    .tag(AppTab.protocols)

                // Tab 3: Fast Dose Log Hub
                logNavigationStack
                    .tag(AppTab.log)

                // Tab 4: Labs & Bloodwork
                labsNavigationStack
                    .tag(AppTab.labs)

                // Tab 5: Inventory & Supplies
                inventoryNavigationStack
                    .tag(AppTab.inventory)
            }

            // Sleek Floating Modern Tab Bar with Prominent Center Action
            VialrFloatingTabBar(
                selectedTab: $coordinator.selectedTab,
                onSelectTab: { tab in
                    coordinator.selectTab(tab)
                },
                onProminentAction: {
                    coordinator.triggerProminentLogAction()
                }
            )
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Tab 1: Home Navigation Stack
    private var homeNavigationStack: some View {
        NavigationStack(path: $coordinator.homePath) {
            DashboardView(
                viewModel: dashboardVM,
                onOpenQuickLog: { dose in coordinator.presentSheet(.quickLog(dose)) },
                onOpenReconstitution: { coordinator.presentSheet(.reconstitution) },
                onOpenSiteRotation: { coordinator.presentSheet(.siteRotation) },
                onOpenProtocolDetail: { proto in coordinator.presentSheet(.protocolDetail(proto)) },
                onOpenBloodwork: { coordinator.selectTab(.labs) },
                onOpenTimeline: { coordinator.presentSheet(.timeline) },
                onNavigateToTab: { tab in coordinator.selectTab(tab) }
            )
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .protocolDetail(let id):
                    if let proto = protocolsVM.allProtocols.first(where: { $0.id == id }) {
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
                            },
                            onOpenReplay: { target in
                                coordinator.presentSheet(.protocolReplay(target))
                            }
                        )
                    }
                case .siteRotation:
                    SiteRotationView(viewModel: siteRotationVM)
                case .reconstitution:
                    ReconstitutionCalculatorView(viewModel: reconstitutionVM) { newVial in
                        Task {
                            try? await container.vialRepository.save(newVial)
                            await inventoryVM.loadInventory()
                            coordinator.showToast(title: "Vial Added", message: "\(newVial.compoundName)")
                        }
                    }
                case .timeline:
                    TimelineView(
                        viewModel: TimelineViewModel(timelineService: container.timelineService),
                        showCloseButton: false
                    )
                case .settings:
                    SettingsView(
                        onOpenClinicianReport: { coordinator.presentSheet(.clinicianReport) },
                        onLockApp: { coordinator.securityManager.lockApp() },
                        onSignOut: { coordinator.signOut() }
                    )
                case .clinicianReport:
                    ClinicianReportView()
                case .analytics:
                    AnalyticsView(viewModel: analyticsVM)
                }
            }
        }
    }

    // MARK: - Tab 2: Protocols Navigation Stack
    private var protocolsNavigationStack: some View {
        NavigationStack(path: $coordinator.protocolsPath) {
            ProtocolsListView(
                viewModel: protocolsVM,
                onSelectProtocol: { proto in coordinator.presentSheet(.protocolDetail(proto)) },
                onCreateProtocol: { coordinator.presentSheet(.createProtocol) },
                onCompareProtocols: { coordinator.presentSheet(.protocolComparison) },
                onReplayProtocol: { proto in coordinator.presentSheet(.protocolReplay(proto)) }
            )
            .navigationDestination(for: ProtocolsDestination.self) { destination in
                switch destination {
                case .protocolDetail(let id):
                    if let proto = protocolsVM.allProtocols.first(where: { $0.id == id }) {
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
                                }
                            },
                            onOpenReplay: { target in
                                coordinator.presentSheet(.protocolReplay(target))
                            }
                        )
                    }
                case .createProtocol:
                    CreateProtocolView { newProtocol in
                        Task {
                            try? await container.protocolRepository.save(newProtocol)
                            await protocolsVM.loadProtocols()
                            coordinator.showToast(title: "Protocol Created", message: newProtocol.name)
                        }
                    }
                case .compareProtocols:
                    ProtocolComparisonView(
                        viewModel: ProtocolComparisonViewModel(
                            protocolRepo: container.protocolRepository,
                            measurementRepo: container.measurementRepository,
                            doseRepo: container.doseLogRepository,
                            symptomRepo: container.symptomRepository,
                            biomarkerRepo: container.biomarkerRepository,
                            costRepo: container.costRepository,
                            initialProtocols: protocolsVM.allProtocols
                        )
                    )
                case .protocolReplay(let id):
                    if let proto = protocolsVM.allProtocols.first(where: { $0.id == id }) {
                        ProtocolReplayView(
                            viewModel: ProtocolReplayViewModel(
                                protocolModel: proto,
                                protocolRepo: container.protocolRepository,
                                doseRepo: container.doseLogRepository,
                                measurementRepo: container.measurementRepository,
                                labRepo: container.labPanelRepository,
                                symptomRepo: container.symptomRepository,
                                siteEventRepo: container.injectionSiteEventRepository
                            )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Tab 3: Fast Dose Log Hub Navigation Stack
    private var logNavigationStack: some View {
        NavigationStack(path: $coordinator.logPath) {
            LoggingHubView(
                viewModel: loggingVM,
                onOpenDoseConfirmation: { dose in
                    coordinator.presentSheet(.quickLog(dose))
                },
                onOpenSiteRotation: {
                    coordinator.presentSheet(.siteRotation)
                },
                onOpenSymptomLog: {
                    coordinator.presentSheet(.logSymptoms)
                },
                onOpenBiomarkerLog: {
                    coordinator.presentSheet(.logBiomarker)
                },
                onOpenReconstitution: {
                    coordinator.presentSheet(.reconstitution)
                }
            )
            .navigationDestination(for: LogDestination.self) { destination in
                switch destination {
                case .doseConfirmation(let doseId):
                    DoseConfirmationSheetView(
                        engine: container.doseLoggingEngine,
                        availableVials: inventoryVM.vials,
                        onCompleted: { result in
                            Task {
                                await loggingVM.loadLoggingData()
                                await dashboardVM.loadDashboardData()
                                coordinator.showToast(
                                    title: "Dose Logged Successfully",
                                    message: "\(result.doseEvent.compoundName)"
                                )
                            }
                        }
                    )
                case .siteRotation:
                    SiteRotationView(viewModel: siteRotationVM)
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
                case .reconstitution:
                    ReconstitutionCalculatorView(viewModel: reconstitutionVM) { newVial in
                        Task {
                            try? await container.vialRepository.save(newVial)
                            await inventoryVM.loadInventory()
                            coordinator.showToast(title: "Vial Added", message: "\(newVial.compoundName)")
                        }
                    }
                case .doseHistory:
                    LoggingHubView(viewModel: loggingVM)
                }
            }
        }
    }

    // MARK: - Tab 4: Labs Navigation Stack
    private var labsNavigationStack: some View {
        NavigationStack(path: $coordinator.labsPath) {
            BloodworkHubView(viewModel: bloodworkVM)
                .navigationDestination(for: LabsDestination.self) { destination in
                    switch destination {
                    case .timeline:
                        LaboratoryTimelineView()
                    case .manualEntry:
                        ManualLabEntryView { newPanel in
                            Task {
                                await bloodworkVM.saveConfirmedPanel(newPanel)
                                coordinator.showToast(title: "Lab Record Saved", message: "\(newPanel.panelName)")
                            }
                        }
                    case .uploadDocument:
                        LabDocumentUploadView { candidate in
                            coordinator.presentSheet(.confirmLabReportCandidate(candidate))
                        }
                    case .panelDetail(let id):
                        if let panel = bloodworkVM.panels.first(where: { $0.id == id }) {
                            LabPanelDetailView(panel: panel) {
                                Task {
                                    await bloodworkVM.deletePanel(id: panel.id)
                                    coordinator.showToast(title: "Lab Record Deleted")
                                }
                            }
                        }
                    case .biomarkerSelector:
                        BiomarkerSelectorView { selected in
                            coordinator.showToast(title: "Biomarker Selected", message: selected.name)
                        }
                    case .clinicianReport:
                        ClinicianReportView()
                    }
                }
        }
    }

    // MARK: - Tab 5: Inventory Navigation Stack
    private var inventoryNavigationStack: some View {
        NavigationStack(path: $coordinator.inventoryPath) {
            InventoryView(
                viewModel: inventoryVM,
                onAddVial: { coordinator.presentSheet(.addVial) }
            )
            .navigationDestination(for: InventoryDestination.self) { destination in
                switch destination {
                case .addVial:
                    AddVialSheetView { newVial in
                        Task {
                            try? await container.vialRepository.save(newVial)
                            await inventoryVM.loadInventory()
                            coordinator.showToast(title: "Vial Added", message: "\(newVial.compoundName)")
                        }
                    }
                case .reconstitution:
                    ReconstitutionCalculatorView(viewModel: reconstitutionVM) { newVial in
                        Task {
                            try? await container.vialRepository.save(newVial)
                            await inventoryVM.loadInventory()
                            coordinator.showToast(title: "Vial Added", message: "\(newVial.compoundName)")
                        }
                    }
                case .vialDetail(let id):
                    if let vial = inventoryVM.vials.first(where: { $0.id == id }) {
                        VialLedgerDetailView(
                            vial: vial,
                            repository: container.vialRepository,
                            inventoryEventRepo: container.inventoryEventRepository
                        )
                    }
                case .vialReconciliation(let id):
                    if let vial = inventoryVM.vials.first(where: { $0.id == id }) {
                        VialReconciliationSheetView(vial: vial, engine: container.doseLoggingEngine) { updated in
                            Task {
                                await inventoryVM.loadInventory()
                                coordinator.showToast(title: "Reconciled", message: "\(updated.compoundName)")
                            }
                        }
                    }
                case .vialDisposal(let id):
                    if let vial = inventoryVM.vials.first(where: { $0.id == id }) {
                        VialDisposalSheetView(vial: vial, engine: container.doseLoggingEngine) {
                            Task {
                                await inventoryVM.loadInventory()
                                coordinator.showToast(title: "Disposed", message: "\(vial.compoundName)")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sheet Router (High-Velocity Modal Flows)
    @ViewBuilder
    private func sheetDestination(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .quickLog(let dose):
            DoseConfirmationSheetView(
                engine: container.doseLoggingEngine,
                preselectedDose: dose,
                availableVials: inventoryVM.vials,
                onCompleted: { result in
                    Task {
                        await dashboardVM.loadDashboardData()
                        await loggingVM.loadLoggingData()
                        await inventoryVM.loadInventory()
                        let amountStr = result.doseEvent.actualDoseAmount.truncatingRemainder(dividingBy: 1) == 0 ?
                            String(format: "%.0f", result.doseEvent.actualDoseAmount) :
                            String(format: "%.1f", result.doseEvent.actualDoseAmount)
                        coordinator.showToast(
                            title: "Dose Logged Successfully",
                            message: "\(result.doseEvent.compoundName) \(amountStr) \(result.doseEvent.doseUnit.rawValue)"
                        )
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
                    await loggingVM.loadLoggingData()
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
                },
                onOpenReplay: { target in
                    coordinator.presentSheet(.protocolReplay(target))
                }
            )

        case .protocolReplay(let proto):
            ProtocolReplayView(
                viewModel: ProtocolReplayViewModel(
                    protocolModel: proto,
                    protocolRepo: container.protocolRepository,
                    doseRepo: container.doseLogRepository,
                    measurementRepo: container.measurementRepository,
                    labRepo: container.labPanelRepository,
                    symptomRepo: container.symptomRepository,
                    siteEventRepo: container.injectionSiteEventRepository
                )
            )

        case .protocolComparison:
            ProtocolComparisonView(
                viewModel: ProtocolComparisonViewModel(
                    protocolRepo: container.protocolRepository,
                    measurementRepo: container.measurementRepository,
                    doseRepo: container.doseLogRepository,
                    symptomRepo: container.symptomRepository,
                    biomarkerRepo: container.biomarkerRepository,
                    costRepo: container.costRepository,
                    initialProtocols: protocolsVM.allProtocols
                )
            )

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

        case .bloodworkHub:
            BloodworkHubView(viewModel: bloodworkVM)

        case .manualBloodworkEntry:
            ManualLabEntryView { newPanel in
                Task {
                    await bloodworkVM.saveConfirmedPanel(newPanel)
                    coordinator.showToast(title: "Lab Record Saved", message: "\(newPanel.panelName) (\(newPanel.results.count) analytes)")
                }
            }

        case .uploadLabReport:
            LabDocumentUploadView { candidate in
                coordinator.presentSheet(.confirmLabReportCandidate(candidate))
            }

        case .confirmLabReportCandidate(let candidate):
            LabCandidateConfirmationView(candidateReport: candidate) { confirmedPanel in
                Task {
                    await bloodworkVM.saveConfirmedPanel(confirmedPanel)
                    coordinator.showToast(title: "Lab Record Verified & Saved", message: "\(confirmedPanel.panelName) (\(confirmedPanel.results.count) analytes)")
                }
            }

        case .labPanelDetail(let panel):
            LabPanelDetailView(panel: panel) {
                Task {
                    await bloodworkVM.deletePanel(id: panel.id)
                    coordinator.showToast(title: "Lab Record Deleted")
                }
            }

        case .timeline:
            TimelineView(
                viewModel: TimelineViewModel(timelineService: container.timelineService),
                showCloseButton: true
            )

        case .settings:
            SettingsView(
                onOpenClinicianReport: { coordinator.presentSheet(.clinicianReport) },
                onLockApp: { coordinator.securityManager.lockApp() },
                onSignOut: { coordinator.signOut() }
            )

        case .analytics:
            AnalyticsView(viewModel: analyticsVM)
        }
    }
}
