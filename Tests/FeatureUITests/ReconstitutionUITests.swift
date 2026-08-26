import XCTest
import SwiftUI
@testable import Feature
@testable import Domain
@testable import CalculationEngine

@MainActor
final class ReconstitutionUITests: XCTestCase {

    private var viewModel: ReconstitutionViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ReconstitutionViewModel()
    }

    func testForwardReconstitutionCalculationFlow() {
        viewModel.mode = .forward
        viewModel.selectedCompoundName = "BPC-157"
        viewModel.dryMassAmount = 5.0
        viewModel.dryMassUnit = .mg
        viewModel.diluentVolumeAmount = 2.0
        viewModel.diluentVolumeUnit = .ml
        viewModel.targetDoseAmount = 250.0
        viewModel.targetDoseUnit = .mcg
        viewModel.selectedSyringeSpec = .u100_50unit
        viewModel.vialCostUsd = 40.0

        viewModel.recalculate()

        guard let result = viewModel.result else {
            XCTFail("Expected calculation result, got nil")
            return
        }

        XCTAssertEqual(result.concentrationMgMl, 2.5, accuracy: 0.001)
        XCTAssertEqual(result.drawVolumeMl, 0.1, accuracy: 0.001)
        XCTAssertEqual(result.u100Units, 10.0, accuracy: 0.001)
        XCTAssertEqual(result.totalDosesInVial, 20.0, accuracy: 0.001)
        XCTAssertEqual(result.costPerDoseUsd ?? 0, 2.00, accuracy: 0.001)
        XCTAssertNil(viewModel.calculationError)
    }

    func testDiluentSolverModeFlow() {
        viewModel.mode = .solveDiluent
        viewModel.dryMassAmount = 10.0
        viewModel.dryMassUnit = .mg
        viewModel.targetDoseAmount = 500.0
        viewModel.targetDoseUnit = .mcg
        viewModel.desiredSyringeUnits = 10.0 // 0.1 mL on U-100

        viewModel.recalculate()

        guard let solverResult = viewModel.diluentSolverResult else {
            XCTFail("Expected solver result, got nil")
            return
        }

        // 10 mg / (0.5 mg / 0.1 mL) = 2.0 mL
        XCTAssertEqual(solverResult.recommendedDiluentVolumeMl, 2.0, accuracy: 0.001)
        XCTAssertEqual(solverResult.resultingConcentrationMgMl, 5.0, accuracy: 0.001)
        XCTAssertEqual(solverResult.totalDosesInVial, 20.0, accuracy: 0.001)
        XCTAssertNil(viewModel.calculationError)
    }

    func testReverseDoseModeFlow() {
        viewModel.mode = .reverseDose
        viewModel.drawnSyringeUnits = 20.0 // 0.2 mL on U-100
        viewModel.currentConcentrationMgMl = 2.5 // 2.5 mg/mL

        viewModel.recalculate()

        guard let reverseResult = viewModel.reverseDoseResult else {
            XCTFail("Expected reverse dose result, got nil")
            return
        }

        // 0.2 mL * 2.5 mg/mL = 0.5 mg = 500 mcg
        XCTAssertEqual(reverseResult.drawnVolumeMl, 0.2, accuracy: 0.001)
        XCTAssertEqual(reverseResult.administeredDoseMg, 0.5, accuracy: 0.001)
        XCTAssertEqual(reverseResult.administeredDoseMcg, 500.0, accuracy: 0.001)
        XCTAssertNil(viewModel.calculationError)
    }

    func testSyringeCapacityWarningInViewModel() {
        viewModel.mode = .forward
        viewModel.dryMassAmount = 5.0
        viewModel.diluentVolumeAmount = 2.0
        viewModel.targetDoseAmount = 1000.0 // 1.0 mg -> 0.4 mL draw
        viewModel.targetDoseUnit = .mcg
        viewModel.selectedSyringeSpec = .u100_30unit // 0.3 mL capacity

        viewModel.recalculate()

        guard let result = viewModel.result else {
            XCTFail("Expected calculation result, got nil")
            return
        }

        XCTAssertFalse(result.isWithinSyringeCapacity)
        XCTAssertTrue(result.warnings.contains(where: { $0.id == "syringe_overflow" }))
    }
}
