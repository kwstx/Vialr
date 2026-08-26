import XCTest
import Domain
@testable import CalculationEngine

final class InventoryEngineLifecycleTests: XCTestCase {

    private var engine: InventoryAccountingEngine!
    private let compoundId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    override func setUp() {
        super.setUp()
        engine = InventoryAccountingEngine()
    }

    private func makeVial(
        id: UUID = UUID(),
        lotNumber: String = "LOT-1001",
        dryMassMg: Double = 5.0,
        status: VialStatus = .unopened
    ) -> Vial {
        Vial(
            id: id,
            compoundId: compoundId,
            compoundName: "BPC-157",
            lotNumber: lotNumber,
            totalDryMassMg: dryMassMg,
            bacWaterAddedMl: nil,
            currentVolumeRemainingMl: nil,
            isReconstituted: false,
            status: status
        )
    }

    // MARK: - 1. Purchases & Initial Stock Intake

    func testSingleVialPurchaseAndStockIntake() {
        let vial = makeVial(lotNumber: "LOT-A101", dryMassMg: 10.0)
        let costId = UUID()
        let intakeDate = Date().addingTimeInterval(-86400 * 5)

        let (event, state) = engine.recordInitialStock(
            vial: vial,
            initialDryMassMg: 10.0,
            costEventId: costId,
            timestamp: intakeDate,
            notes: "Purchased from BioLabs batch 2026-Q3"
        )

        XCTAssertEqual(event.eventType, .initialStock)
        XCTAssertEqual(event.vialId, vial.id)
        XCTAssertEqual(event.costEventId, costId)
        XCTAssertEqual(state.status, .unopened)
        XCTAssertEqual(state.initialDryMassMg, 10.0)
        XCTAssertEqual(state.currentMassRemainingMg, 10.0)
        XCTAssertEqual(state.currentVolumeRemainingMl, 0.0)
        XCTAssertFalse(state.isReconstituted)
        XCTAssertEqual(state.auditTrailCount, 1)
    }

    func testMultiVialBatchPurchaseIntake() {
        let costBatchId = UUID()
        let vial1 = makeVial(id: UUID(), lotNumber: "BATCH-42-A", dryMassMg: 5.0)
        let vial2 = makeVial(id: UUID(), lotNumber: "BATCH-42-B", dryMassMg: 5.0)

        let (event1, state1) = engine.recordInitialStock(vial: vial1, initialDryMassMg: 5.0, costEventId: costBatchId)
        let (event2, state2) = engine.recordInitialStock(vial: vial2, initialDryMassMg: 5.0, costEventId: costBatchId)

        XCTAssertEqual(event1.costEventId, costBatchId)
        XCTAssertEqual(event2.costEventId, costBatchId)
        XCTAssertEqual(state1.currentMassRemainingMg, 5.0)
        XCTAssertEqual(state2.currentMassRemainingMg, 5.0)
        XCTAssertEqual(state1.status, .unopened)
        XCTAssertEqual(state2.status, .unopened)
    }

    // MARK: - 2. Reconstitution & Doses

    func testReconstitutionAndSequentialDoseDeduction() {
        let vial = makeVial(lotNumber: "LOT-99", dryMassMg: 5.0)
        let t0 = Date().addingTimeInterval(-7200)
        let tRecon = Date().addingTimeInterval(-3600)

        let (e0, _) = engine.recordInitialStock(vial: vial, initialDryMassMg: 5.0, timestamp: t0)
        let (eRecon, stateRecon) = engine.recordReconstitution(
            vial: vial,
            existingEvents: [e0],
            diluentVolumeMl: 2.0,
            dryMassMg: 5.0,
            timestamp: tRecon
        )

        XCTAssertTrue(stateRecon.isReconstituted)
        XCTAssertEqual(stateRecon.currentConcentrationMgMl, 2.5) // 5 mg / 2 mL = 2.5 mg/mL
        XCTAssertEqual(stateRecon.currentVolumeRemainingMl, 2.0)
        XCTAssertEqual(stateRecon.currentMassRemainingMg, 5.0)

        // Draw Dose 1: 250 mcg (0.25 mg = 0.1 mL draw)
        var events = [e0, eRecon]
        let dose1 = DoseEvent(compoundId: compoundId, compoundName: "BPC-157", actualTimestamp: tRecon.addingTimeInterval(600), actualDoseAmount: 250.0, doseUnit: .mcg, status: .taken, vialId: vial.id)
        let (eDose1, stateAfter1) = engine.recordDoseConsumption(vial: vial, existingEvents: events, doseEvent: dose1)
        events.append(eDose1)

        XCTAssertEqual(stateAfter1.currentVolumeRemainingMl, 1.9, accuracy: 0.001)
        XCTAssertEqual(stateAfter1.currentMassRemainingMg, 4.75, accuracy: 0.001)
        XCTAssertEqual(stateAfter1.totalDosesAdministered, 1)

        // Draw Dose 2: 500 mcg (0.5 mg = 0.2 mL draw)
        let dose2 = DoseEvent(compoundId: compoundId, compoundName: "BPC-157", actualTimestamp: tRecon.addingTimeInterval(1200), actualDoseAmount: 500.0, doseUnit: .mcg, status: .taken, vialId: vial.id)
        let (eDose2, stateAfter2) = engine.recordDoseConsumption(vial: vial, existingEvents: events, doseEvent: dose2)
        events.append(eDose2)

        XCTAssertEqual(stateAfter2.currentVolumeRemainingMl, 1.7, accuracy: 0.001) // 1.9 - 0.2 = 1.7 mL
        XCTAssertEqual(stateAfter2.currentMassRemainingMg, 4.25, accuracy: 0.001)  // 4.75 - 0.5 = 4.25 mg
        XCTAssertEqual(stateAfter2.totalDosesAdministered, 2)
        XCTAssertEqual(stateAfter2.auditTrailCount, 4)
    }

    func testDoseDepletesVialToZero() {
        let vial = makeVial(lotNumber: "LOT-DEP", dryMassMg: 2.0)
        let t0 = Date().addingTimeInterval(-3600)
        let (e0, _) = engine.recordInitialStock(vial: vial, initialDryMassMg: 2.0, timestamp: t0)
        let (eRecon, _) = engine.recordReconstitution(vial: vial, existingEvents: [e0], diluentVolumeMl: 1.0, timestamp: t0)

        // Administer 2.0 mg (full 1.0 mL)
        let dose = DoseEvent(compoundId: compoundId, compoundName: "BPC-157", actualTimestamp: Date(), actualDoseAmount: 2.0, doseUnit: .mg, status: .taken, vialId: vial.id)
        let (_, finalState) = engine.recordDoseConsumption(vial: vial, existingEvents: [e0, eRecon], doseEvent: dose)

        XCTAssertEqual(finalState.currentVolumeRemainingMl, 0.0)
        XCTAssertEqual(finalState.currentMassRemainingMg, 0.0)
        XCTAssertEqual(finalState.status, .depleted)
        XCTAssertNotNil(finalState.depletedDate)
    }

    // MARK: - 3. Corrections & Ledger Replay

    func testLedgerReplayAfterDoseCorrection() {
        let vial = makeVial(lotNumber: "LOT-CORR", dryMassMg: 5.0)
        let t0 = Date(timeIntervalSince1970: 1700000000)
        let tRecon = Date(timeIntervalSince1970: 1700001000)
        let tDose = Date(timeIntervalSince1970: 1700002000)

        let (e0, _) = engine.recordInitialStock(vial: vial, initialDryMassMg: 5.0, timestamp: t0)
        let (eRecon, _) = engine.recordReconstitution(vial: vial, existingEvents: [e0], diluentVolumeMl: 2.0, timestamp: tRecon)

        // Erroneous dose: logged 1000 mcg (0.4 mL) instead of 250 mcg (0.1 mL)
        let errDose = DoseEvent(compoundId: compoundId, compoundName: "BPC-157", actualTimestamp: tDose, actualDoseAmount: 1000.0, doseUnit: .mcg, status: .taken, vialId: vial.id)
        let (eErrDose, stateErr) = engine.recordDoseConsumption(vial: vial, existingEvents: [e0, eRecon], doseEvent: errDose)
        XCTAssertEqual(stateErr.currentVolumeRemainingMl, 1.6, accuracy: 0.001)

        // User corrects entry: Replaces erroneous event with corrected 250 mcg dose event
        let corrDose = DoseEvent(id: errDose.id, compoundId: compoundId, compoundName: "BPC-157", actualTimestamp: tDose, actualDoseAmount: 250.0, doseUnit: .mcg, status: .taken, vialId: vial.id)
        let (eCorrDose, _) = engine.recordDoseConsumption(vial: vial, existingEvents: [e0, eRecon], doseEvent: corrDose)

        let replayedState = engine.calculateVialState(vial: vial, events: [e0, eRecon, eCorrDose])
        XCTAssertEqual(replayedState.currentVolumeRemainingMl, 1.9, accuracy: 0.001)
        XCTAssertEqual(replayedState.currentMassRemainingMg, 4.75, accuracy: 0.001)
    }

    // MARK: - 4. Disposal

    func testVialDisposalForExpirationAndDamage() {
        let vial = makeVial(lotNumber: "LOT-DISP", dryMassMg: 5.0)
        let (e0, _) = engine.recordInitialStock(vial: vial, initialDryMassMg: 5.0)
        let (eRecon, _) = engine.recordReconstitution(vial: vial, existingEvents: [e0], diluentVolumeMl: 2.0)

        // 1. Expired disposal
        let (expEvent, expState) = engine.recordDisposal(
            vial: vial,
            existingEvents: [e0, eRecon],
            reason: .expired,
            notes: "Exceeded 28-day stability guideline",
            timestamp: Date()
        )
        XCTAssertEqual(expEvent.disposalReason, .expired)
        XCTAssertEqual(expState.status, .discarded)
        XCTAssertEqual(expState.currentVolumeRemainingMl, 0.0)
        XCTAssertEqual(expState.currentMassRemainingMg, 0.0)
        XCTAssertNotNil(expState.discardDate)

        // 2. Damaged/Contaminated disposal
        let (damEvent, damState) = engine.recordDisposal(
            vial: vial,
            existingEvents: [e0, eRecon],
            reason: .damaged,
            notes: "Vial dropped and cracked",
            timestamp: Date()
        )
        XCTAssertEqual(damEvent.disposalReason, .damaged)
        XCTAssertEqual(damState.status, .discarded)
        XCTAssertEqual(damState.currentVolumeRemainingMl, 0.0)
    }

    // MARK: - 5. Multiple Vials & FIFO Workflow

    func testMultipleVialsFIFODepletion() {
        let vial1 = makeVial(id: UUID(), lotNumber: "LOT-V1", dryMassMg: 2.0)
        let vial2 = makeVial(id: UUID(), lotNumber: "LOT-V2", dryMassMg: 5.0)

        let t0 = Date().addingTimeInterval(-10000)
        let t1 = Date().addingTimeInterval(-8000)

        // Vial 1 Reconstituted with 1.0 mL (2.0 mg/mL) -> 2 doses of 1.0 mg (0.5 mL each)
        let (e1_init, _) = engine.recordInitialStock(vial: vial1, initialDryMassMg: 2.0, timestamp: t0)
        let (e1_recon, _) = engine.recordReconstitution(vial: vial1, existingEvents: [e1_init], diluentVolumeMl: 1.0, timestamp: t0)

        // Dose 1 from Vial 1 (0.5 mL)
        let d1 = DoseEvent(compoundId: compoundId, compoundName: "BPC-157", actualTimestamp: t1, actualDoseAmount: 1.0, doseUnit: .mg, status: .taken, vialId: vial1.id)
        let (e1_d1, _) = engine.recordDoseConsumption(vial: vial1, existingEvents: [e1_init, e1_recon], doseEvent: d1)

        // Dose 2 from Vial 1 (0.5 mL) -> Vial 1 depleted!
        let d2 = DoseEvent(compoundId: compoundId, compoundName: "BPC-157", actualTimestamp: t1.addingTimeInterval(3600), actualDoseAmount: 1.0, doseUnit: .mg, status: .taken, vialId: vial1.id)
        let (e1_d2, stateV1Final) = engine.recordDoseConsumption(vial: vial1, existingEvents: [e1_init, e1_recon, e1_d1], doseEvent: d2)

        XCTAssertEqual(stateV1Final.status, .depleted)
        XCTAssertEqual(stateV1Final.currentVolumeRemainingMl, 0.0)

        // Switch to Vial 2: Reconstitute with 2.0 mL (2.5 mg/mL) and draw Dose 3
        let (e2_init, _) = engine.recordInitialStock(vial: vial2, initialDryMassMg: 5.0, timestamp: t1.addingTimeInterval(3700))
        let (e2_recon, _) = engine.recordReconstitution(vial: vial2, existingEvents: [e2_init], diluentVolumeMl: 2.0, timestamp: t1.addingTimeInterval(3700))

        let d3 = DoseEvent(compoundId: compoundId, compoundName: "BPC-157", actualTimestamp: t1.addingTimeInterval(7200), actualDoseAmount: 1.0, doseUnit: .mg, status: .taken, vialId: vial2.id)
        let (e2_d3, stateV2) = engine.recordDoseConsumption(vial: vial2, existingEvents: [e2_init, e2_recon], doseEvent: d3)

        XCTAssertEqual(stateV2.status, .reconstituted)
        XCTAssertEqual(stateV2.currentVolumeRemainingMl, 1.6, accuracy: 0.001) // 2.0 - (1.0 / 2.5) = 1.6 mL
        XCTAssertEqual(stateV2.currentMassRemainingMg, 4.0, accuracy: 0.001)

        // Aggregate stock across both vials = Vial 1 (0.0 mg) + Vial 2 (4.0 mg) = 4.0 mg
        let activeVials = [stateV1Final, stateV2].filter { $0.status != .depleted && $0.status != .discarded }
        let totalActiveMass = activeVials.reduce(0.0) { $0 + $1.currentMassRemainingMg }
        XCTAssertEqual(totalActiveMass, 4.0, accuracy: 0.001)
    }

    // MARK: - 6. Reconciliation

    func testPhysicalVolumeReconciliationWithVariance() {
        let vial = makeVial(lotNumber: "LOT-RECONC", dryMassMg: 5.0)
        let t0 = Date().addingTimeInterval(-7200)
        let (e0, _) = engine.recordInitialStock(vial: vial, initialDryMassMg: 5.0, timestamp: t0)
        let (eRecon, _) = engine.recordReconstitution(vial: vial, existingEvents: [e0], diluentVolumeMl: 2.0, timestamp: t0)

        // Expected: 2.0 mL. User observes physical level is 1.85 mL (0.15 mL loss)
        let (reconcileEvent, state) = engine.reconcileVial(
            vial: vial,
            existingEvents: [e0, eRecon],
            observedVolumeRemainingMl: 1.85,
            reason: .deadSpaceLoss,
            notes: "Syringe hub dead space loss over multiple draws"
        )

        XCTAssertEqual(reconcileEvent.eventType, .reconciliation)
        XCTAssertEqual(reconcileEvent.changeVolumeMl ?? 0, -0.15, accuracy: 0.001)
        XCTAssertEqual(state.currentVolumeRemainingMl, 1.85, accuracy: 0.001)
        XCTAssertEqual(state.totalReconciliationVolumeAdjustmentMl, -0.15, accuracy: 0.001)
        XCTAssertEqual(state.reconciliationCount, 1)
        XCTAssertTrue(state.isReconciled)
    }

    func testAncillarySuppliesInventoryAndReconciliation() {
        let needles = SupplyItem(
            id: UUID(),
            name: "31G 5/16\" Insulin Needles",
            category: .syringes,
            quantityRemaining: 50,
            reorderThreshold: 15
        )

        // Reconcile physical count: counted 42 needles (variance -8)
        let (event, count) = engine.reconcileSupply(
            item: needles,
            existingEvents: [],
            observedQuantity: 42,
            reason: .countingError,
            notes: "Physical box audit"
        )

        XCTAssertEqual(event.eventType, .reconciliation)
        XCTAssertEqual(event.changeQuantityCount, -8)
        XCTAssertEqual(count, 42)

        let state = engine.calculateSupplyState(item: needles, events: [event])
        XCTAssertEqual(state.currentQuantityRemaining, 42)
        XCTAssertFalse(state.isLowStock) // 42 > 15

        // Another count dropping below reorder threshold
        let (_, lowCount) = engine.reconcileSupply(item: needles, existingEvents: [event], observedQuantity: 10, reason: .other)
        let lowState = engine.calculateSupplyState(item: needles, events: [event, InventoryEvent(supplyItemId: needles.id, eventType: .reconciliation, changeQuantityCount: 10 - 42)])
        XCTAssertEqual(lowState.currentQuantityRemaining, 10)
        XCTAssertTrue(lowState.isLowStock) // 10 <= 15
    }
}
