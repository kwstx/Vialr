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
                OnboardingCoordinatorView { finalUser in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        coordinator.hasCompletedOnboarding = true
                        coordinator.isAuthenticated = true
                    }
                    coordinator.showToast(title: "Welcome to Vialr", message: "Vault initialized for \(finalUser.accountInfo.displayName).")
                }
            } else if !coordinator.isAuthenticated {
                AuthenticationView { authenticatedUser in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        coordinator.isAuthenticated = true
                    }
                    coordinator.showToast(title: "Signed In", message: "Welcome back, \(authenticatedUser.accountInfo.displayName).")
                }
            } else {
                mainTabContent
            }

            // Privacy Blur Overlay for Multitasking / App Switcher
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
        // MARK: - Bottom Sheets for Quick Actions (Interactive Detents)
        .sheet(item: $coordinator.activeBottomSheet) { sheet in
            bottomSheetDestination(sheet)
                .presentationDetents([.fraction(0.65), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(VialrColors.backgroundPrimary)
        }
        // MARK: - Full-Screen Flows for Important Setup Tasks
        .fullScreenCover(item: $coordinator.activeFullScreenFlow) { flow in
            fullScreenDestination(flow)
        }
        // MARK: - Legacy Sheet Router (Fallback for backward compatibility)
        .sheet(item: $coordinator.activeSheet) { sheet in
            sheetDestination(sheet)
                .presentationDetents(sheet.isQuickActionBottomSheet ? [.fraction(0.65), .large] : [.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(VialrColors.backgroundPrimary)
        }
        .task {
            let notifManager = NotificationClientManager.shared
            await notifManager.initialize()
            notifManager.onDoseLogRequested = { _ in
                coordinator.presentBottomSheet(.quickLog(nil))
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
                onOpenQuickLog: { dose in coordinator.presentBottomSheet(.quickLog(dose)) },
                onOpenReconstitution: { coordinator.presentFullScreenFlow(.reconstitution) },
                onOpenSiteRotation: { coordinator.presentBottomSheet(.siteRotation) },
                onOpenProtocolDetail: { proto in coordinator.presentFullScreenFlow(.protocolDetail(proto)) },
                onOpenBloodwork: { coordinator.selectTab(.labs) },
                onOpenTimeline: { coordinator.presentFullScreenFlow(.timeline) },
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
                                coordinator.presentFullScreenFlow(.protocolReplay(target))
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
                        onOpenClinicianReport: { coordinator.presentFullScreenFlow(.clinicianReport) },
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
                onSelectProtocol: { proto in coordinator.presentFullScreenFlow(.protocolDetail(proto)) },
                onCreateProtocol: { coordinator.presentFullScreenFlow(.createProtocol) },
                onCompareProtocols: { coordinator.presentFullScreenFlow(.protocolComparison) },
                onReplayProtocol: { proto in coordinator.presentFullScreenFlow(.protocolReplay(proto)) }
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
                                coordinator.presentFullScreenFlow(.protocolReplay(target))
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
                    coordinator.presentBottomSheet(.quickLog(dose))
                },
                onOpenSiteRotation: {
                    coordinator.presentBottomSheet(.siteRotation)
                },
                onOpenSymptomLog: {
                    coordinator.presentBottomSheet(.logSymptoms)
                },
                onOpenBiomarkerLog: {
                    coordinator.presentBottomSheet(.logBiomarker)
                },
                onOpenReconstitution: {
                    coordinator.presentFullScreenFlow(.reconstitution)
                }
            )
            .navigationDestination(for: LogDestination.self) { destination in
                switch destination {
                case .doseConfirmation:
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
                            coordinator.presentFullScreenFlow(.confirmLabReportCandidate(candidate))
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
                onAddVial: { coordinator.presentBottomSheet(.addVial) }
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

    // MARK: - Bottom Sheet Router (Quick Actions with Interactive Detents)
    @ViewBuilder
    private func bottomSheetDestination(_ sheet: ActiveBottomSheet) -> some View {
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

        case .siteRotation:
            SiteRotationView(viewModel: siteRotationVM)

        case .addVial:
            AddVialSheetView { newVial in
                Task {
                    try? await container.vialRepository.save(newVial)
                    await inventoryVM.loadInventory()
                    coordinator.showToast(title: "Vial Added", message: "\(newVial.compoundName) in stock.")
                }
            }

        case .explainability(let title, let explanation):
            ExplainabilityInspectionSheet(
                anomalyTitle: title,
                explanation: explanation,
                recommendation: "Review schedule to prevent tissue saturation or inconsistent absorption."
            )
        }
    }

    // MARK: - Full-Screen Setup Flow Router
    @ViewBuilder
    private func fullScreenDestination(_ flow: ActiveFullScreenFlow) -> some View {
        switch flow {
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

        case .clinicianReport:
            ClinicianReportView()

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

        case .reconstitution:
            ReconstitutionCalculatorView(viewModel: reconstitutionVM) { newVial in
                Task {
                    try? await container.vialRepository.save(newVial)
                    await inventoryVM.loadInventory()
                    coordinator.showToast(title: "Vial Added to Inventory", message: "\(newVial.compoundName) (\(String(format: "%.1f", newVial.totalDryMassMg))mg)")
                }
            }

        case .uploadLabReport:
            LabDocumentUploadView { candidate in
                coordinator.presentFullScreenFlow(.confirmLabReportCandidate(candidate))
            }

        case .confirmLabReportCandidate(let candidate):
            LabCandidateConfirmationView(candidateReport: candidate) { confirmedPanel in
                Task {
                    await bloodworkVM.saveConfirmedPanel(confirmedPanel)
                    coordinator.showToast(title: "Lab Record Verified & Saved", message: "\(confirmedPanel.panelName) (\(confirmedPanel.results.count) analytes)")
                }
            }

        case .manualBloodworkEntry:
            ManualLabEntryView { newPanel in
                Task {
                    await bloodworkVM.saveConfirmedPanel(newPanel)
                    coordinator.showToast(title: "Lab Record Saved", message: "\(newPanel.panelName) (\(newPanel.results.count) analytes)")
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
                    coordinator.presentFullScreenFlow(.protocolReplay(target))
                }
            )

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
                onOpenClinicianReport: { coordinator.presentFullScreenFlow(.clinicianReport) },
                onLockApp: { coordinator.securityManager.lockApp() },
                onSignOut: { coordinator.signOut() }
            )

        case .analytics:
            AnalyticsView(viewModel: analyticsVM)
        }
    }

    // MARK: - Legacy Sheet Router (Fallback for backward compatibility)
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
                    coordinator.showToast(title: "Vial Added to Inventory", message: "\(newVial.compoundName)")
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
                    coordinator.presentFullScreenFlow(.protocolReplay(target))
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
                    coordinator.showToast(title: "Lab Record Saved", message: "\(newPanel.panelName)")
                }
            }

        case .uploadLabReport:
            LabDocumentUploadView { candidate in
                coordinator.presentFullScreenFlow(.confirmLabReportCandidate(candidate))
            }

        case .confirmLabReportCandidate(let candidate):
            LabCandidateConfirmationView(candidateReport: candidate) { confirmedPanel in
                Task {
                    await bloodworkVM.saveConfirmedPanel(confirmedPanel)
                    coordinator.showToast(title: "Lab Record Verified & Saved", message: "\(confirmedPanel.panelName)")
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
                onOpenClinicianReport: { coordinator.presentFullScreenFlow(.clinicianReport) },
                onLockApp: { coordinator.securityManager.lockApp() },
                onSignOut: { coordinator.signOut() }
            )

        case .analytics:
            AnalyticsView(viewModel: analyticsVM)
        }
    }
}
