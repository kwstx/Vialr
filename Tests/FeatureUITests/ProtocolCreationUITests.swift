import XCTest
import SwiftUI
@testable import Feature
@testable import Domain
@testable import Data
@testable import CalculationEngine

@MainActor
final class ProtocolCreationUITests: XCTestCase {

    private var viewModel: ProtocolCreationViewModel!
    private var protocolRepo: LocalProtocolRepository!
    private var compoundRepo: LocalCompoundRepository!
    private var vialRepo: LocalVialRepository!

    override func setUp() async throws {
        let store = LocalStore()
        protocolRepo = LocalProtocolRepository(store: store)
        compoundRepo = LocalCompoundRepository(store: store)
        vialRepo = LocalVialRepository(store: store)

        viewModel = ProtocolCreationViewModel(
            compoundRepo: compoundRepo,
            vialRepo: vialRepo,
            protocolRepo: protocolRepo
        )
        await viewModel.loadData()
    }

    func testProtocolCreationStepProgression() {
        XCTAssertEqual(viewModel.currentStep, .compound)
        XCTAssertTrue(viewModel.canProceedToNextStep)

        // Step 0 -> Step 1 (Dose)
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .dose)
        XCTAssertTrue(viewModel.canProceedToNextStep)

        // Step 1 -> Step 2 (Frequency)
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .frequency)

        // Step 2 -> Step 3 (Route)
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .route)

        // Step 3 -> Step 4 (Schedule Dates)
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .scheduleDates)

        // Step 4 -> Step 5 (Reminders)
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .reminders)

        // Step 5 -> Step 6 (Attach Vial)
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .attachVial)

        // Step 6 -> Step 7 (Review)
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .review)

        // Previous step
        viewModel.previousStep()
        XCTAssertEqual(viewModel.currentStep, .attachVial)
    }

    func testTitrationConfigurationAndProtocolAssembly() async throws {
        let compound = Compound(
            name: "Semaglutide",
            shortCode: "SEMA",
            category: .metabolic,
            defaultUnit: .mcg,
            typicalDose: 250
        )
        viewModel.selectCompound(compound)
        viewModel.doseAmount = 250
        viewModel.doseUnit = .mcg
        viewModel.enableTitration = true
        viewModel.titrationTargetDose = 1000
        viewModel.titrationStepAmount = 250
        viewModel.titrationStepDays = 7
        viewModel.frequencyType = .everyNDays
        viewModel.everyNIntervalDays = 7

        let finalProtocol = try await viewModel.saveProtocol()

        XCTAssertEqual(finalProtocol.status, .active)
        XCTAssertEqual(finalProtocol.compounds.count, 1)

        let savedCompound = finalProtocol.compounds.first
        XCTAssertEqual(savedCompound?.compoundName, "Semaglutide")
        XCTAssertEqual(savedCompound?.doseAmount, 250)
        XCTAssertNotNil(savedCompound?.titrationStep)
        XCTAssertEqual(savedCompound?.titrationStep?.targetDose, 1000)
        XCTAssertEqual(savedCompound?.titrationStep?.stepAmount, 250)
        XCTAssertEqual(savedCompound?.titrationStep?.stepIntervalDays, 7)

        // Verify protocol is saved in repository
        let allProtocols = try await protocolRepo.fetchAll()
        XCTAssertTrue(allProtocols.contains(where: { $0.id == finalProtocol.id }))
    }
}
