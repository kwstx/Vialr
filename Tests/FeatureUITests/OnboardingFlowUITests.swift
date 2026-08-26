import XCTest
import SwiftUI
@testable import Feature
@testable import Domain
@testable import Data
@testable import Health

@MainActor
final class OnboardingFlowUITests: XCTestCase {

    private var viewModel: OnboardingViewModel!
    private var testUserDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testUserDefaults = UserDefaults(suiteName: "OnboardingFlowUITests_\(UUID().uuidString)")!
        viewModel = OnboardingViewModel()
    }

    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: "OnboardingFlowUITests_\(UUID().uuidString)")
        testUserDefaults = nil
        super.tearDown()
    }

    // MARK: - Legacy Questionnaire ViewModel Tests
    func testOnboardingInitialState() {
        XCTAssertEqual(viewModel.currentStepIndex, 0)
        XCTAssertEqual(viewModel.totalSteps, 12)
        XCTAssertFalse(viewModel.isComplete)
        XCTAssertEqual(viewModel.primaryCategory, "Peptides")
        XCTAssertTrue(viewModel.selectedGoals.contains("Recovery"))
    }

    func testOnboarding12StepProgression() {
        for expectedIndex in 0..<12 {
            XCTAssertEqual(viewModel.currentStepIndex, expectedIndex)
            XCTAssertFalse(viewModel.isComplete)
            viewModel.nextStep()
        }

        XCTAssertTrue(viewModel.isComplete)
        XCTAssertEqual(viewModel.currentStepIndex, 11)
    }

    func testOnboardingPreviousStepNavigation() {
        XCTAssertEqual(viewModel.currentStepIndex, 0)
        viewModel.previousStep()
        XCTAssertEqual(viewModel.currentStepIndex, 0)

        viewModel.nextStep()
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStepIndex, 2)

        viewModel.previousStep()
        XCTAssertEqual(viewModel.currentStepIndex, 1)
    }

    func testGoalsMultiSelectToggling() {
        viewModel.selectedGoals = ["Recovery"]

        viewModel.toggleGoal("Performance")
        XCTAssertTrue(viewModel.selectedGoals.contains("Performance"))
        XCTAssertTrue(viewModel.selectedGoals.contains("Recovery"))

        viewModel.toggleGoal("Longevity")
        XCTAssertTrue(viewModel.selectedGoals.contains("Longevity"))

        viewModel.toggleGoal("Performance")
        XCTAssertFalse(viewModel.selectedGoals.contains("Performance"))

        viewModel.toggleGoal("Longevity")
        viewModel.toggleGoal("Recovery")
        XCTAssertEqual(viewModel.selectedGoals.count, 1, "Must retain at least 1 goal")
    }

    func testFeaturesToStayOnTopEverythingToggle() {
        viewModel.featuresToStayOnTop = ["Doses"]

        viewModel.toggleFeatureToStayOnTop("Everything")
        XCTAssertTrue(viewModel.featuresToStayOnTop.contains("Everything"))
        XCTAssertTrue(viewModel.featuresToStayOnTop.contains("Doses"))
        XCTAssertTrue(viewModel.featuresToStayOnTop.contains("Reconstitution"))
        XCTAssertTrue(viewModel.featuresToStayOnTop.contains("Bloodwork"))

        viewModel.toggleFeatureToStayOnTop("Everything")
        XCTAssertTrue(viewModel.featuresToStayOnTop.isEmpty)
    }

    func testDerivedProtocolSettings() {
        viewModel.injectionSiteTracking = "Yes"
        XCTAssertTrue(viewModel.enableSiteRotation)
        viewModel.injectionSiteTracking = "No"
        XCTAssertFalse(viewModel.enableSiteRotation)

        viewModel.appleHealthPreference = "Yes"
        XCTAssertTrue(viewModel.enableAppleHealthSync)
        viewModel.appleHealthPreference = "No"
        XCTAssertFalse(viewModel.enableAppleHealthSync)

        viewModel.calculationImportance = "Essential"
        XCTAssertTrue(viewModel.needsReconstitutionCalculators)
        viewModel.calculationImportance = "Not needed"
        viewModel.featuresToStayOnTop = ["Doses"]
        XCTAssertFalse(viewModel.needsReconstitutionCalculators)
        viewModel.featuresToStayOnTop = ["Reconstitution"]
        XCTAssertTrue(viewModel.needsReconstitutionCalculators)
    }

    // MARK: - 12 Marketing Pages Pager Tests
    func testPagerViewModel12PagesAndLocalPersistence() {
        let pager = OnboardingPagerViewModel(userDefaults: testUserDefaults)
        XCTAssertEqual(pager.totalPages, 12)
        XCTAssertEqual(pager.currentPageIndex, 0)
        XCTAssertFalse(pager.isLastPage)

        // Advance 3 pages
        pager.nextPage {}
        pager.nextPage {}
        pager.nextPage {}
        XCTAssertEqual(pager.currentPageIndex, 3)

        // Verify local storage is synced
        let storedIndex = testUserDefaults.integer(forKey: OnboardingPagerViewModel.pageIndexStorageKey)
        XCTAssertEqual(storedIndex, 3)

        // Re-instantiate pager model and verify it restores index 3
        let restoredPager = OnboardingPagerViewModel(userDefaults: testUserDefaults)
        XCTAssertEqual(restoredPager.currentPageIndex, 3)

        // Jump to last page
        restoredPager.goToPage(index: 11)
        XCTAssertEqual(restoredPager.currentPageIndex, 11)
        XCTAssertTrue(restoredPager.isLastPage)

        var reachedEnd = false
        restoredPager.nextPage {
            reachedEnd = true
        }
        XCTAssertTrue(reachedEnd, "Should trigger onReachedEnd callback on the last page")
    }

    func testPagerSkipToAuth() {
        let pager = OnboardingPagerViewModel(userDefaults: testUserDefaults)
        var didTransition = false

        pager.skipToAuth {
            didTransition = true
        }

        XCTAssertTrue(didTransition)
        XCTAssertEqual(pager.currentPageIndex, 11)
        XCTAssertTrue(pager.isLastPage)
    }

    // MARK: - User Account & Initial Local Database Initializer Tests
    func testUserAccountInitializer() async throws {
        let localStore = LocalStore.shared
        let userRepo = LocalUserRepository(store: localStore)
        let compoundRepo = LocalCompoundRepository(store: localStore)
        let supplyRepo = LocalSupplyRepository(store: localStore)

        let initializer = UserAccountInitializer(
            userRepo: userRepo,
            compoundRepo: compoundRepo,
            supplyRepo: supplyRepo,
            localStore: localStore
        )

        let initialUser = User(
            accountInfo: AccountInfo(
                email: "test.researcher@vialr.app",
                displayName: "Dr. Elena Vance"
            )
        )

        let initializedUser = try await initializer.initializeAccountAndDatabase(for: initialUser)

        // Check user is saved and active
        XCTAssertEqual(initializedUser.accountInfo.displayName, "Dr. Elena Vance")
        XCTAssertEqual(initializedUser.accountInfo.status, .active)

        let fetchedUser = try await userRepo.fetchCurrentUser()
        XCTAssertNotNil(fetchedUser)
        XCTAssertEqual(fetchedUser?.accountInfo.email, "test.researcher@vialr.app")

        // Verify compound catalog contains standard reference compounds
        let compounds = try await compoundRepo.fetchAll()
        XCTAssertFalse(compounds.isEmpty)
        XCTAssertTrue(compounds.contains(where: { $0.name == "BPC-157" }))
        XCTAssertTrue(compounds.contains(where: { $0.name == "Tirzepatide" }))
        XCTAssertTrue(compounds.contains(where: { $0.name == "Testosterone Cypionate" }))

        // Verify supplies seeded
        let supplies = try await supplyRepo.fetchAll()
        XCTAssertFalse(supplies.isEmpty)
        XCTAssertTrue(supplies.contains(where: { $0.category == .syringes }))
    }

    // MARK: - First-Run Setup Wizard Flow Tests (Item 36)
    func testFirstRunWizardStepSequenceAndInitialState() {
        let setupVM = PostAuthSetupViewModel(
            userDefaults: testUserDefaults
        )

        XCTAssertEqual(setupVM.totalSteps, 7)
        XCTAssertEqual(setupVM.currentStep, .firstProtocolPrompt)
        XCTAssertFalse(setupVM.isLastStep)
        XCTAssertTrue(setupVM.wantsFirstProtocol)
        XCTAssertFalse(setupVM.starterTemplates.isEmpty)
    }

    func testFirstRunWizardCustomProtocolFlow() async throws {
        let localStore = LocalStore.shared
        let userRepo = LocalUserRepository(store: localStore)
        let protocolRepo = LocalProtocolRepository(store: localStore)
        let vialRepo = LocalVialRepository(store: localStore)
        let doseRepo = LocalDoseLogRepository(store: localStore)
        let compoundRepo = LocalCompoundRepository(store: localStore)
        let healthSettings = HealthSettingsManager(userDefaults: testUserDefaults)

        let setupVM = PostAuthSetupViewModel(
            userRepo: userRepo,
            protocolRepo: protocolRepo,
            vialRepo: vialRepo,
            doseRepo: doseRepo,
            compoundRepo: compoundRepo,
            healthSettingsManager: healthSettings,
            healthService: MockHealthService(),
            userDefaults: testUserDefaults
        )

        // Step 0: First Protocol Decision -> Create Custom
        XCTAssertEqual(setupVM.currentStep, .firstProtocolPrompt)
        setupVM.chooseCreateCustomProtocol()
        setupVM.nextStep()

        // Step 1: Add Compound & Planned Dose
        XCTAssertEqual(setupVM.currentStep, .compound)
        let bpc = Compound(
            name: "BPC-157",
            category: .recovery,
            defaultUnit: .mcg,
            typicalDose: 250,
            administrationRoute: .subcutaneous
        )
        setupVM.selectCompound(bpc)
        setupVM.doseAmount = 250
        setupVM.doseUnit = .mcg
        setupVM.selectedRoute = .subcutaneous
        XCTAssertTrue(setupVM.canProceedToNextStep)
        setupVM.nextStep()

        // Step 2: Configure Dosing Schedule
        XCTAssertEqual(setupVM.currentStep, .schedule)
        setupVM.frequencyType = .daily
        setupVM.startDateOption = .today
        setupVM.preferredTimeOfDay = .morning
        XCTAssertEqual(setupVM.computedScheduleRule, .everyDay)
        setupVM.nextStep()

        // Step 3: Optionally Add Inventory Vial
        XCTAssertEqual(setupVM.currentStep, .vial)
        setupVM.shouldAddVial = true
        setupVM.vialDryMassMg = 5.0
        setupVM.vialBacWaterMl = 2.0
        XCTAssertEqual(setupVM.vialConcentrationMgMl, 2.5, accuracy: 0.01)
        XCTAssertEqual(setupVM.vialConcentrationMcgMl, 2500.0, accuracy: 0.1)
        XCTAssertEqual(setupVM.calculatedDrawVolumeMl, 0.10, accuracy: 0.01)
        XCTAssertEqual(setupVM.calculatedSyringeUnits, 10.0, accuracy: 0.1)
        XCTAssertEqual(setupVM.estimatedDosesInVial, 20)
        setupVM.nextStep()

        // Step 4: Configure Reminders
        XCTAssertEqual(setupVM.currentStep, .reminders)
        setupVM.enableDoseReminders = true
        setupVM.reminderLeadTimeMinutes = 15
        setupVM.enableRestockAlerts = true
        setupVM.enableDailyMorningSummary = true
        await setupVM.requestNotificationPermissions()
        XCTAssertTrue(setupVM.notificationPermissionGranted)
        setupVM.nextStep()

        // Step 5: Optionally Connect HealthKit
        XCTAssertEqual(setupVM.currentStep, .healthKit)
        setupVM.enableAppleHealth = true
        setupVM.toggleHealthMetric(.weight)
        setupVM.toggleHealthMetric(.restingHeartRate)
        await setupVM.requestHealthKitPermissions()
        XCTAssertTrue(setupVM.healthAuthRequested)
        setupVM.nextStep()

        // Step 6: "You're Ready" Screen
        XCTAssertEqual(setupVM.currentStep, .ready)
        XCTAssertTrue(setupVM.isLastStep)

        // Finalize Setup
        let baseUser = User(
            accountInfo: AccountInfo(
                email: "wizard.user@vialr.app",
                displayName: "Alex Mercer"
            )
        )
        let finalUser = try await setupVM.finalizeSetup(for: baseUser)

        // 1. Check User Persisted with configured units & preferences
        XCTAssertEqual(finalUser.units.massUnit, .mcg)
        XCTAssertEqual(finalUser.notificationPreferences.doseReminderLeadTimeMinutes, 15)
        XCTAssertTrue(finalUser.preferences.syncWithAppleHealth)

        // 2. Check Protocol Persisted in ProtocolRepository
        let activeProtocols = try await protocolRepo.fetchActive()
        XCTAssertFalse(activeProtocols.isEmpty)
        let createdProto = activeProtocols.first(where: { $0.name.contains("BPC-157") })
        XCTAssertNotNil(createdProto)
        XCTAssertEqual(createdProto?.compounds.first?.doseAmount, 250)
        XCTAssertEqual(createdProto?.compounds.first?.doseUnit, .mcg)
        XCTAssertEqual(createdProto?.compounds.first?.route, .subcutaneous)

        // 3. Check Physical Vial Persisted in VialRepository
        let activeVials = try await vialRepo.fetchActive()
        XCTAssertFalse(activeVials.isEmpty)
        let createdVial = activeVials.first(where: { $0.compoundName.contains("BPC-157") })
        XCTAssertNotNil(createdVial)
        XCTAssertEqual(createdVial?.totalDryMassMg, 5.0)
        XCTAssertEqual(createdVial?.bacWaterAddedMl, 2.0)
        XCTAssertEqual(createdProto?.compounds.first?.attachedVialId, createdVial?.id)

        // 4. Check Scheduled Dose Log Seeded for Today
        let doses = try await doseRepo.fetchAll()
        let todayDose = doses.first(where: { $0.compoundName.contains("BPC-157") && $0.status == .scheduled })
        XCTAssertNotNil(todayDose)
        XCTAssertEqual(todayDose?.doseAmount, 250)
        XCTAssertEqual(todayDose?.doseUnit, .mcg)

        // 5. Check HealthSettingsManager & UserDefaults
        XCTAssertTrue(healthSettings.isIntegrationEnabled)
        XCTAssertTrue(testUserDefaults.bool(forKey: OnboardingPagerViewModel.onboardingCompletedStorageKey))
    }

    func testFirstRunWizardStarterTemplateFlow() async throws {
        let localStore = LocalStore.shared
        let userRepo = LocalUserRepository(store: localStore)
        let protocolRepo = LocalProtocolRepository(store: localStore)
        let vialRepo = LocalVialRepository(store: localStore)
        let doseRepo = LocalDoseLogRepository(store: localStore)

        let setupVM = PostAuthSetupViewModel(
            userRepo: userRepo,
            protocolRepo: protocolRepo,
            vialRepo: vialRepo,
            doseRepo: doseRepo,
            userDefaults: testUserDefaults
        )

        // Select Starter Template: Tirzepatide Metabolic
        let template = setupVM.starterTemplates.first(where: { $0.compoundName == "Tirzepatide" })!
        setupVM.selectTemplate(template)

        XCTAssertEqual(setupVM.selectedCompound?.name, "Tirzepatide")
        XCTAssertEqual(setupVM.doseAmount, 2.5)
        XCTAssertEqual(setupVM.doseUnit, .mg)
        XCTAssertEqual(setupVM.vialDryMassMg, 10.0)
        XCTAssertEqual(setupVM.vialBacWaterMl, 2.0)
        XCTAssertEqual(setupVM.protocolName, template.title)

        // Advance to Ready and Finalize
        setupVM.goToStep(.ready)
        let baseUser = User(accountInfo: AccountInfo(email: "glp1@vialr.app", displayName: "Jordan Lee"))
        let finalUser = try await setupVM.finalizeSetup(for: baseUser)

        XCTAssertEqual(finalUser.accountInfo.displayName, "Jordan Lee")
        let activeProtos = try await protocolRepo.fetchActive()
        XCTAssertTrue(activeProtos.contains(where: { $0.compounds.contains(where: { $0.compoundName == "Tirzepatide" }) }))
    }

    func testFirstRunWizardSkipProtocolFlow() async throws {
        let localStore = LocalStore.shared
        let userRepo = LocalUserRepository(store: localStore)
        let protocolRepo = LocalProtocolRepository(store: localStore)

        let setupVM = PostAuthSetupViewModel(
            userRepo: userRepo,
            protocolRepo: protocolRepo,
            userDefaults: testUserDefaults
        )

        // Step 0: Choose Skip Protocol
        setupVM.chooseSkipProtocol()
        XCTAssertFalse(setupVM.wantsFirstProtocol)

        // Clicking nextStep skips compound, schedule, vial and goes straight to reminders
        setupVM.nextStep()
        XCTAssertEqual(setupVM.currentStep, .reminders)

        setupVM.nextStep()
        XCTAssertEqual(setupVM.currentStep, .healthKit)

        setupVM.nextStep()
        XCTAssertEqual(setupVM.currentStep, .ready)

        let baseUser = User(accountInfo: AccountInfo(email: "skip@vialr.app", displayName: "Adhoc User"))
        let finalUser = try await setupVM.finalizeSetup(for: baseUser)

        XCTAssertEqual(finalUser.accountInfo.displayName, "Adhoc User")
        XCTAssertTrue(testUserDefaults.bool(forKey: OnboardingPagerViewModel.onboardingCompletedStorageKey))
    }

    func testDashboardContainsRealDataImmediatelyAfterSetup() async throws {
        let localStore = LocalStore.shared
        let userRepo = LocalUserRepository(store: localStore)
        let protocolRepo = LocalProtocolRepository(store: localStore)
        let vialRepo = LocalVialRepository(store: localStore)
        let doseRepo = LocalDoseLogRepository(store: localStore)
        let supplyRepo = LocalSupplyRepository(store: localStore)
        let biomarkerRepo = LocalBiomarkerRepository(store: localStore)
        let siteEventRepo = LocalInjectionSiteEventRepository(store: localStore)

        // Run Setup Wizard
        let setupVM = PostAuthSetupViewModel(
            userRepo: userRepo,
            protocolRepo: protocolRepo,
            vialRepo: vialRepo,
            doseRepo: doseRepo,
            supplyRepo: supplyRepo,
            userDefaults: testUserDefaults
        )

        let template = setupVM.starterTemplates.first(where: { $0.compoundName == "BPC-157" })!
        setupVM.selectTemplate(template)
        setupVM.goToStep(.ready)

        let baseUser = User(accountInfo: AccountInfo(email: "realdata@vialr.app", displayName: "Live User"))
        _ = try await setupVM.finalizeSetup(for: baseUser)

        // Initialize Dashboard View Model with the exact same repositories
        let dashboardVM = DashboardViewModel(
            protocolRepo: protocolRepo,
            doseRepo: doseRepo,
            vialRepo: vialRepo,
            supplyRepo: supplyRepo,
            biomarkerRepo: biomarkerRepo,
            userRepo: userRepo,
            siteEventRepo: siteEventRepo
        )

        await dashboardVM.loadDashboardData()

        // Assert Dashboard is NOT empty and contains real live data immediately!
        XCTAssertNotNil(dashboardVM.primaryProtocol, "Home screen must display active protocol")
        XCTAssertTrue(dashboardVM.primaryProtocol?.name.contains("BPC-157") ?? false)
        XCTAssertNotNil(dashboardVM.nextUpcomingDose, "Hero action card must display next upcoming dose")
        XCTAssertEqual(dashboardVM.nextUpcomingDose?.compoundName, "BPC-157")
        XCTAssertFalse(dashboardVM.todayTimelineItems.isEmpty, "Today timeline must show the scheduled dose")
        XCTAssertEqual(dashboardVM.inventorySummary.activeVialsCount, 1, "Inventory card must reflect the created vial")
        XCTAssertNotNil(dashboardVM.recommendedSite, "Site rotation must suggest a target site")
    }
}
