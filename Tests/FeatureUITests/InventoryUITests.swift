import XCTest
import SwiftUI
@testable import Feature
@testable import Domain
@testable import Data
@testable import CalculationEngine

@MainActor
final class InventoryUITests: XCTestCase {

    private var viewModel: InventoryViewModel!
    private var vialRepo: LocalVialRepository!
    private var eventRepo: LocalInventoryEventRepository!

    override func setUp() async throws {
        let store = LocalStore()
        vialRepo = LocalVialRepository(store: store)
        eventRepo = LocalInventoryEventRepository(store: store)
        viewModel = InventoryViewModel(
            vialRepo: vialRepo,
            supplyRepo: LocalSupplyRepository(store: store),
            protocolRepo: LocalProtocolRepository(store: store),
            inventoryEventRepo: eventRepo
        )
    }

    func testAddVialGeneratesLedgerInitialStockAndReconstitution() async throws {
        let vialId = UUID()
        let compoundId = UUID()

        let vial = Vial(
            id: vialId,
            compoundId: compoundId,
            compoundName: "TB-500",
            lotNumber: "LOT-UI-99",
            totalDryMassMg: 10.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 2.0,
            isReconstituted: true,
            status: .reconstituted
        )

        await viewModel.addVial(vial)

        XCTAssertEqual(viewModel.vials.count, 1)
        XCTAssertEqual(viewModel.vials.first?.id, vialId)

        let state = viewModel.accountingStates[vialId]
        XCTAssertNotNil(state)
        XCTAssertEqual(state?.initialDryMassMg, 10.0)
        XCTAssertEqual(state?.currentVolumeRemainingMl, 2.0)
        XCTAssertEqual(state?.currentConcentrationMgMl, 5.0) // 10 mg / 2 mL = 5 mg/mL
        XCTAssertEqual(state?.auditTrailCount, 2) // Initial stock + Reconstitution
    }

    func testReconcileVialFlow() async throws {
        let vialId = UUID()
        let vial = Vial(
            id: vialId,
            compoundId: UUID(),
            compoundName: "BPC-157",
            totalDryMassMg: 5.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 2.0,
            isReconstituted: true,
            status: .reconstituted
        )
        await viewModel.addVial(vial)

        // Reconcile observed volume: user measured 1.85 mL (variance -0.15 mL)
        await viewModel.reconcileVial(
            vialId: vialId,
            observedVolumeMl: 1.85,
            reason: .deadSpaceLoss,
            notes: "Syringe hub dead-space discrepancy"
        )

        let state = viewModel.accountingStates[vialId]
        XCTAssertNotNil(state)
        XCTAssertEqual(state?.currentVolumeRemainingMl, 1.85, accuracy: 0.001)
        XCTAssertEqual(state?.totalReconciliationVolumeAdjustmentMl, -0.15, accuracy: 0.001)
        XCTAssertTrue(state?.isReconciled ?? false)
    }

    func testDisposeVialFlow() async throws {
        let vialId = UUID()
        let vial = Vial(
            id: vialId,
            compoundId: UUID(),
            compoundName: "CJC-1295",
            totalDryMassMg: 2.0,
            bacWaterAddedMl: 1.0,
            currentVolumeRemainingMl: 0.5,
            isReconstituted: true,
            status: .reconstituted
        )
        await viewModel.addVial(vial)

        // Dispose for expiration
        await viewModel.disposeVial(
            vialId: vialId,
            reason: .expired,
            notes: "Past recommended use window"
        )

        let state = viewModel.accountingStates[vialId]
        XCTAssertNotNil(state)
        XCTAssertEqual(state?.status, .discarded)
        XCTAssertEqual(state?.currentVolumeRemainingMl, 0.0)
        XCTAssertEqual(state?.currentMassRemainingMg, 0.0)
        XCTAssertNotNil(state?.discardDate)
    }
}
