import XCTest
import SwiftUI
@testable import Feature
@testable import Domain
@testable import CalculationEngine
@testable import Data
@testable import VialrApp

@MainActor
final class NavigationArchitectureTests: XCTestCase {

    private var localStore: LocalStore!
    private var coordinator: AppCoordinator!
    private var doseLoggingEngine: DoseLoggingEngine!
    private var siteRotationEngine: SiteRotationEngine!

    override func setUp() async throws {
        localStore = LocalStore()
        coordinator = AppCoordinator()
        siteRotationEngine = SiteRotationEngine()

        let doseRepo = LocalDoseLogRepository(store: localStore)
        let vialRepo = LocalVialRepository(store: localStore)
        let siteRepo = LocalInjectionSiteEventRepository(store: localStore)
        let protoRepo = LocalProtocolRepository(store: localStore)
        let notifScheduler = NotificationScheduler()

        doseLoggingEngine = DoseLoggingEngine(
            doseRepo: doseRepo,
            vialRepo: vialRepo,
            siteEventRepo: siteRepo,
            protocolRepo: protoRepo,
            notificationScheduler: notifScheduler
        )
    }

    // MARK: - 1. Primary Tab Structure Tests
    func testPrimaryTabsConfiguration() {
        let tabs = AppTab.allCases
        XCTAssertEqual(tabs.count, 5, "App should have exactly 5 primary tabs")
        XCTAssertEqual(tabs[0], .home)
        XCTAssertEqual(tabs[1], .protocols)
        XCTAssertEqual(tabs[2], .log)
        XCTAssertEqual(tabs[3], .labs)
        XCTAssertEqual(tabs[4], .inventory)

        // Verify Tab Icons and Accessibility Labels
        XCTAssertFalse(AppTab.home.iconName.isEmpty)
        XCTAssertFalse(AppTab.protocols.iconName.isEmpty)
        XCTAssertFalse(AppTab.log.iconName.isEmpty)
        XCTAssertFalse(AppTab.labs.iconName.isEmpty)
        XCTAssertFalse(AppTab.inventory.iconName.isEmpty)

        XCTAssertTrue(AppTab.log.isProminentAction, "Log tab must be marked as the prominent floating center action")
        XCTAssertFalse(AppTab.home.isProminentAction)
        XCTAssertFalse(AppTab.protocols.isProminentAction)
        XCTAssertFalse(AppTab.labs.isProminentAction)
        XCTAssertFalse(AppTab.inventory.isProminentAction)
    }

    func testAppTabBackwardCompatibilityAliases() {
        XCTAssertEqual(AppTab.dashboard, .home)
        XCTAssertEqual(AppTab.analytics, .labs)
        XCTAssertEqual(AppTab.settings, .home)
    }

    // MARK: - 2. Independent Navigation Stacks & Pop to Root
    func testIndependentNavigationPathsAndPopToRoot() {
        coordinator.selectedTab = .home
        coordinator.homePath.append(.timeline)
        coordinator.homePath.append(.settings)
        XCTAssertEqual(coordinator.homePath.count, 2)

        // Switching to Protocols tab keeps Home path isolated
        coordinator.selectTab(.protocols)
        XCTAssertEqual(coordinator.selectedTab, .protocols)
        XCTAssertEqual(coordinator.homePath.count, 2)
        XCTAssertEqual(coordinator.protocolsPath.count, 0)

        // Push on Protocols tab
        let protoId = UUID()
        coordinator.protocolsPath.append(.protocolDetail(protoId))
        XCTAssertEqual(coordinator.protocolsPath.count, 1)

        // Re-tapping Protocols tab triggers pop-to-root
        coordinator.selectTab(.protocols)
        XCTAssertEqual(coordinator.protocolsPath.count, 0, "Re-selecting active tab should pop navigation stack to root")

        // Switch back to Home and pop to root
        coordinator.selectTab(.home)
        coordinator.selectTab(.home)
        XCTAssertEqual(coordinator.homePath.count, 0)
    }

    // MARK: - 3. Fast Prominent Log Action
    func testProminentLogActionTriggersInstantDoseEntry() {
        coordinator.selectedTab = .home
        XCTAssertNil(coordinator.activeSheet)

        // Trigger prominent action (e.g. Center Tab button tap)
        coordinator.triggerProminentLogAction()

        XCTAssertNotNil(coordinator.activeSheet)
        if case .quickLog(let preselected) = coordinator.activeSheet {
            XCTAssertNil(preselected, "Default prominent action opens quick logger for immediate entry")
        } else {
            XCTFail("Active sheet should be quickLog")
        }
    }

    // MARK: - 4. Universal Deep Linking Routing
    func testUniversalDeepLinkParsing() {
        // Tab Routes
        let homeUrl = URL(string: "vialr://home")!
        XCTAssertEqual(AppDeepLinkRoute.parse(from: homeUrl), .tab(.home))

        let protoUrl = URL(string: "vialr://protocols")!
        XCTAssertEqual(AppDeepLinkRoute.parse(from: protoUrl), .tab(.protocols))

        let logUrl = URL(string: "vialr://log")!
        XCTAssertEqual(AppDeepLinkRoute.parse(from: logUrl), .quickLog(doseId: nil))

        let labsUrl = URL(string: "vialr://labs")!
        XCTAssertEqual(AppDeepLinkRoute.parse(from: labsUrl), .tab(.labs))

        let bloodworkUrl = URL(string: "vialr://bloodwork")!
        XCTAssertEqual(AppDeepLinkRoute.parse(from: bloodworkUrl), .tab(.labs))

        let invUrl = URL(string: "vialr://inventory")!
        XCTAssertEqual(AppDeepLinkRoute.parse(from: invUrl), .tab(.inventory))

        // Feature Schemes
        let reconUrl = URL(string: "vialr://reconstitution")!
        XCTAssertEqual(AppDeepLinkRoute.parse(from: reconUrl), .reconstitution)

        let siteUrl = URL(string: "vialr://site-rotation")!
        XCTAssertEqual(AppDeepLinkRoute.parse(from: siteUrl), .siteRotation)

        let reportUrl = URL(string: "vialr://clinician-report")!
        XCTAssertEqual(AppDeepLinkRoute.parse(from: reportUrl), .clinicianReport)

        // Protocol Detail with ID
        let testUuid = UUID()
        let protoDetailUrl = URL(string: "vialr://protocols?id=\(testUuid.uuidString)")!
        XCTAssertEqual(AppDeepLinkRoute.parse(from: protoDetailUrl), .protocolDetail(protocolId: testUuid))
    }

    func testCoordinatorHandlesDeepLinks() {
        coordinator.selectedTab = .home

        // Deep link to labs
        coordinator.handleDeepLink(URL(string: "vialr://labs")!)
        XCTAssertEqual(coordinator.selectedTab, .labs)

        // Deep link to inventory
        coordinator.handleDeepLink(URL(string: "vialr://inventory")!)
        XCTAssertEqual(coordinator.selectedTab, .inventory)

        // Deep link to reconstitution sheet
        coordinator.handleDeepLink(URL(string: "vialr://reconstitution")!)
        if case .reconstitution = coordinator.activeSheet {
            // Success
        } else {
            XCTFail("Reconstitution sheet should be active")
        }
    }

    // MARK: - 5. Sub-3-Second Fast Dose Logging with LoggingViewModel
    func testFastDoseLoggingFromLoggingViewModel() async throws {
        let doseRepo = LocalDoseLogRepository(store: localStore)
        let vialRepo = LocalVialRepository(store: localStore)
        let protoRepo = LocalProtocolRepository(store: localStore)
        let siteRepo = LocalInjectionSiteEventRepository(store: localStore)

        // 1. Setup active vial in inventory
        let compoundId = UUID()
        let vialId = UUID()
        let testVial = Vial(
            id: vialId,
            compoundId: compoundId,
            compoundName: "BPC-157",
            lotNumber: "LOT-NAV-01",
            totalDryMassMg: 5.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 2.0,
            isReconstituted: true,
            status: .reconstituted
        )
        try await vialRepo.save(testVial)

        // 2. Setup scheduled dose today
        let doseId = UUID()
        let scheduledDose = DoseLog(
            id: doseId,
            compoundId: compoundId,
            compoundName: "BPC-157",
            scheduledDate: Date(),
            doseAmount: 250,
            doseUnit: .mcg,
            status: .scheduled
        )
        try await doseRepo.save(scheduledDose)

        // 3. Initialize LoggingViewModel
        let vm = LoggingViewModel(
            doseRepo: doseRepo,
            protocolRepo: protoRepo,
            vialRepo: vialRepo,
            siteEventRepo: siteRepo,
            doseLoggingEngine: doseLoggingEngine
        )
        await vm.loadLoggingData()

        XCTAssertNotNil(vm.nextUpcomingDose)
        XCTAssertEqual(vm.nextUpcomingDose?.compoundName, "BPC-157")
        XCTAssertNotNil(vm.recommendedSite)

        // 4. Perform 1-Tap Scheduled Dose Log (takes under 100ms)
        let startTime = Date()
        let result = await vm.quickLogScheduledDose()
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertNotNil(result)
        XCTAssertLessThan(elapsed, 2.0, "Dose logging execution must complete in well under 2 seconds")
        XCTAssertEqual(result?.doseEvent.compoundName, "BPC-157")
        XCTAssertEqual(result?.doseEvent.status, .taken)

        // 5. Verify vial volume auto-deducted
        let updatedVial = try await vialRepo.fetch(byId: vialId)
        XCTAssertEqual(updatedVial?.currentVolumeRemainingMl, 1.9, accuracy: 0.001)

        // 6. Test 1-Tap Preset Logging
        let preset = QuickLogPreset(
            compoundName: "BPC-157",
            defaultAmount: 250,
            doseUnit: .mcg
        )
        let presetResult = await vm.quickLogPreset(preset)
        XCTAssertNotNil(presetResult)
        XCTAssertEqual(presetResult?.doseEvent.actualDoseAmount, 250)

        // 7. Test 1-Tap Repeat Logging
        let allDoses = try await doseRepo.fetchAll()
        let takenDose = allDoses.first(where: { $0.status == .taken })!
        let repeatResult = await vm.repeatPastDose(takenDose)
        XCTAssertNotNil(repeatResult)
        XCTAssertEqual(repeatResult?.doseEvent.compoundName, takenDose.compoundName)
    }
}
