import XCTest
import Domain
@testable import CalculationEngine

final class InventoryAccountingTests: XCTestCase {
    private var engine: InventoryAccountingEngine!
    private let compoundId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let vialId = UUID(uuidString: "vial-test-1")!

    override func setUp() {
        super.setUp()
        engine = InventoryAccountingEngine()
    }

    private func createTestVial() -> Vial {
        Vial(
            id: vialId,
            compoundId: compoundId,
            compoundName: "BPC-157",
            lotNumber: "LOT-9921",
            totalDryMassMg: 5.0,
            bacWaterAddedMl: nil,
            currentVolumeRemainingMl: nil,
            isReconstituted: false,
            status: .unopened
        )
    }

    // MARK: - 1. Initial Stock Intake
    func testInitialStockDerivation() {
        let vial = createTestVial()
        let now = Date()
        let (initialEvent, state) = engine.recordInitialStock(
            vial: vial,
            initialDryMassMg: 5.0,
            timestamp: now,
            notes: "Initial receipt"
        )

        XCTAssertEqual(initialEvent.eventType, .initialStock)
        XCTAssertEqual(initialEvent.changeMassMg, 5.0)
        XCTAssertEqual(state.initialDryMassMg, 5.0)
        XCTAssertEqual(state.currentMassRemainingMg, 5.0)
        XCTAssertEqual(state.currentVolumeRemainingMl, 0.0)
        XCTAssertFalse(state.isReconstituted)
        XCTAssertEqual(state.status, .unopened)
        XCTAssertEqual(state.auditTrailCount, 1)
    }

    // MARK: - 2. Reconstitution Changes Concentration State
    func testReconstitutionConcentrationChange() {
        let vial = createTestVial()
        let t0 = Date().addingTimeInterval(-3600)
        let t1 = Date()

        let (initEvent, _) = engine.recordInitialStock(vial: vial, initialDryMassMg: 5.0, timestamp: t0)
        let (reconEvent, state) = engine.recordReconstitution(
            vial: vial,
            existingEvents: [initEvent],
            diluentVolumeMl: 2.0,
            dryMassMg: 5.0,
            diluentType: .bacteriostaticWater,
            timestamp: t1
        )

        XCTAssertEqual(reconEvent.eventType, .reconstitution)
        XCTAssertEqual(reconEvent.changeVolumeMl, 2.0)
        XCTAssertTrue(state.isReconstituted)
        XCTAssertEqual(state.totalDiluentVolumeMl, 2.0)
        XCTAssertEqual(state.currentVolumeRemainingMl, 2.0)
        XCTAssertEqual(state.currentMassRemainingMg, 5.0)
        XCTAssertEqual(state.currentConcentrationMgMl, 2.5) // 5.0mg / 2.0mL = 2.5 mg/mL
        XCTAssertEqual(state.currentConcentrationMcgMl, 2500.0)
        XCTAssertEqual(state.status, .reconstituted)
        XCTAssertNotNil(state.expirationDate)
        XCTAssertEqual(state.auditTrailCount, 2)
    }

    // MARK: - 3. Dose Consumption Reduces Volume & Mass Deterministically
    func testSequentialDoseConsumption() {
        let vial = createTestVial()
        let t0 = Date().addingTimeInterval(-7200)
        let t1 = Date().addingTimeInterval(-3600)

        let (initEvent, _) = engine.recordInitialStock(vial: vial, initialDryMassMg: 5.0, timestamp: t0)
        let (reconEvent, _) = engine.recordReconstitution(
            vial: vial,
            existingEvents: [initEvent],
            diluentVolumeMl: 2.0,
            dryMassMg: 5.0,
            timestamp: t1
        )

        var events = [initEvent, reconEvent]

        // Log 3 sequential doses: 250 mcg (0.25 mg = 0.1 mL draw at 2.5 mg/mL)
        for i in 1...3 {
            let doseTime = t1.addingTimeInterval(Double(i * 600))
            let doseEvent = DoseEvent(
                compoundId: compoundId,
                compoundName: "BPC-157",
                scheduledTimestamp: doseTime,
                actualTimestamp: doseTime,
                actualDoseAmount: 250.0,
                doseUnit: .mcg,
                status: .taken,
                vialId: vial.id
            )

            let (doseInvEvent, _) = engine.recordDoseConsumption(
                vial: vial,
                existingEvents: events,
                doseEvent: doseEvent,
                timestamp: doseTime
            )
            events.append(doseInvEvent)
        }

        let finalState = engine.calculateVialState(vial: vial, events: events)

        XCTAssertEqual(finalState.totalDosesAdministered, 3)
        XCTAssertEqual(finalState.totalDoseVolumeConsumedMl, 0.3, accuracy: 0.001) // 3 * 0.1 mL = 0.3 mL
        XCTAssertEqual(finalState.totalDoseMassConsumedMg, 0.75, accuracy: 0.001)   // 3 * 0.25 mg = 0.75 mg
        XCTAssertEqual(finalState.currentVolumeRemainingMl, 1.7, accuracy: 0.001)  // 2.0 - 0.3 = 1.7 mL
        XCTAssertEqual(finalState.currentMassRemainingMg, 4.25, accuracy: 0.001)   // 5.0 - 0.75 = 4.25 mg
        XCTAssertEqual(finalState.status, .reconstituted)
        XCTAssertEqual(finalState.auditTrailCount, 5) // Initial + Recon + 3 Doses
    }

    // MARK: - 4. Inventory Reconciliation Creates Audited Adjustment Event
    func testInventoryReconciliationAdjustment() {
        let vial = createTestVial()
        let t0 = Date().addingTimeInterval(-7200)
        let t1 = Date().addingTimeInterval(-3600)

        let (initEvent, _) = engine.recordInitialStock(vial: vial, initialDryMassMg: 5.0, timestamp: t0)
        let (reconEvent, _) = engine.recordReconstitution(vial: vial, existingEvents: [initEvent], diluentVolumeMl: 2.0, timestamp: t1)

        var events = [initEvent, reconEvent]

        // 5 doses of 0.1 mL each -> expected remaining is 1.50 mL
        for i in 1...5 {
            let doseTime = t1.addingTimeInterval(Double(i * 300))
            let dose = DoseEvent(
                compoundId: compoundId,
                compoundName: "BPC-157",
                actualTimestamp: doseTime,
                actualDoseAmount: 250.0,
                doseUnit: .mcg,
                status: .taken,
                vialId: vial.id
            )
            let (invDose, _) = engine.recordDoseConsumption(vial: vial, existingEvents: events, doseEvent: dose, timestamp: doseTime)
            events.append(invDose)
        }

        let stateBeforeReconciliation = engine.calculateVialState(vial: vial, events: events)
        XCTAssertEqual(stateBeforeReconciliation.currentVolumeRemainingMl, 1.50, accuracy: 0.001)

        // User performs reconciliation observing physical volume of 1.35 mL (due to 0.15 mL cumulative dead space loss)
        let reconcileTime = Date()
        let (reconcileEvent, stateAfter) = engine.reconcileVial(
            vial: vial,
            existingEvents: events,
            observedVolumeRemainingMl: 1.35,
            reason: .deadSpaceLoss,
            notes: "Observed 1.35 mL in vial after 5 injections with standard insulin syringes",
            timestamp: reconcileTime
        )
        events.append(reconcileEvent)

        XCTAssertEqual(reconcileEvent.eventType, .reconciliation)
        XCTAssertEqual(reconcileEvent.reconciliationReason, .deadSpaceLoss)
        XCTAssertEqual(reconcileEvent.changeVolumeMl ?? 0.0, -0.15, accuracy: 0.001) // Variance delta: 1.35 - 1.50 = -0.15 mL
        XCTAssertEqual(stateAfter.currentVolumeRemainingMl, 1.35, accuracy: 0.001)
        XCTAssertEqual(stateAfter.totalReconciliationVolumeAdjustmentMl, -0.15, accuracy: 0.001)
        XCTAssertEqual(stateAfter.reconciliationCount, 1)
        XCTAssertTrue(stateAfter.isReconciled)
        XCTAssertEqual(stateAfter.auditTrailCount, 8) // 1 initial + 1 recon + 5 doses + 1 reconciliation
    }

    // MARK: - 5. Depletion on Complete Consumption
    func testVialDepletionWhenDosesReachZero() {
        let vial = createTestVial()
        let t0 = Date().addingTimeInterval(-3600)
        let (initEvent, _) = engine.recordInitialStock(vial: vial, initialDryMassMg: 2.0, timestamp: t0)
        let (reconEvent, _) = engine.recordReconstitution(vial: vial, existingEvents: [initEvent], diluentVolumeMl: 1.0, dryMassMg: 2.0, timestamp: t0)

        // Consume entire 1.0 mL
        let fullDose = DoseEvent(
            compoundId: compoundId,
            compoundName: "BPC-157",
            actualTimestamp: Date(),
            actualDoseAmount: 2.0,
            doseUnit: .mg,
            status: .taken,
            vialId: vial.id
        )

        let (doseInv, state) = engine.recordDoseConsumption(
            vial: vial,
            existingEvents: [initEvent, reconEvent],
            doseEvent: fullDose,
            drawVolumeMl: 1.0
        )

        XCTAssertEqual(state.currentVolumeRemainingMl, 0.0)
        XCTAssertEqual(state.status, .depleted)
        XCTAssertNotNil(state.depletedDate)
        XCTAssertEqual(doseInv.resultingStatus, .depleted)
    }

    // MARK: - 6. Audited Disposal Zeros Remaining Stock While Preserving Ledger
    func testVialDisposal() {
        let vial = createTestVial()
        let t0 = Date().addingTimeInterval(-3600)
        let (initEvent, _) = engine.recordInitialStock(vial: vial, initialDryMassMg: 5.0, timestamp: t0)
        let (reconEvent, _) = engine.recordReconstitution(vial: vial, existingEvents: [initEvent], diluentVolumeMl: 2.0, timestamp: t0)

        let (dispEvent, state) = engine.recordDisposal(
            vial: vial,
            existingEvents: [initEvent, reconEvent],
            reason: .expired,
            notes: "Past 30-day freshness window",
            timestamp: Date()
        )

        XCTAssertEqual(dispEvent.eventType, .disposal)
        XCTAssertEqual(dispEvent.disposalReason, .expired)
        XCTAssertEqual(state.currentVolumeRemainingMl, 0.0)
        XCTAssertEqual(state.currentMassRemainingMg, 0.0)
        XCTAssertEqual(state.status, .discarded)
        XCTAssertNotNil(state.discardDate)
        XCTAssertEqual(state.auditTrailCount, 3) // Initial + Recon + Disposal preserved
    }

    // MARK: - 7. Historical Point-in-Time State Replay
    func testHistoricalPointInTimeReplay() {
        let vial = createTestVial()
        let t0 = Date(timeIntervalSince1970: 1700000000)
        let tRecon = Date(timeIntervalSince1970: 1700003600)
        let tDose1 = Date(timeIntervalSince1970: 1700007200)
        let tDose2 = Date(timeIntervalSince1970: 1700010800)

        let (e0, _) = engine.recordInitialStock(vial: vial, initialDryMassMg: 5.0, timestamp: t0)
        let (eRecon, _) = engine.recordReconstitution(vial: vial, existingEvents: [e0], diluentVolumeMl: 2.0, timestamp: tRecon)

        let d1 = DoseEvent(compoundId: compoundId, compoundName: "BPC-157", actualTimestamp: tDose1, actualDoseAmount: 250, doseUnit: .mcg, status: .taken, vialId: vial.id)
        let (eDose1, _) = engine.recordDoseConsumption(vial: vial, existingEvents: [e0, eRecon], doseEvent: d1, timestamp: tDose1)

        let d2 = DoseEvent(compoundId: compoundId, compoundName: "BPC-157", actualTimestamp: tDose2, actualDoseAmount: 250, doseUnit: .mcg, status: .taken, vialId: vial.id)
        let (eDose2, _) = engine.recordDoseConsumption(vial: vial, existingEvents: [e0, eRecon, eDose1], doseEvent: d2, timestamp: tDose2)

        let allEvents = [e0, eRecon, eDose1, eDose2]

        // Replay at t0: Should be dry powder unopened
        let stateAtT0 = engine.replayHistory(vial: vial, events: allEvents, at: t0)
        XCTAssertEqual(stateAtT0.currentVolumeRemainingMl, 0.0)
        XCTAssertFalse(stateAtT0.isReconstituted)
        XCTAssertEqual(stateAtT0.status, .unopened)

        // Replay at tRecon: Should be 2.0 mL reconstituted
        let stateAtRecon = engine.replayHistory(vial: vial, events: allEvents, at: tRecon)
        XCTAssertEqual(stateAtRecon.currentVolumeRemainingMl, 2.0)
        XCTAssertTrue(stateAtRecon.isReconstituted)

        // Replay at tDose1: Should be 1.9 mL (1 dose taken)
        let stateAtDose1 = engine.replayHistory(vial: vial, events: allEvents, at: tDose1)
        XCTAssertEqual(stateAtDose1.currentVolumeRemainingMl, 1.9, accuracy: 0.001)
        XCTAssertEqual(stateAtDose1.totalDosesAdministered, 1)

        // Replay at tDose2: Should be 1.8 mL (2 doses taken)
        let stateAtDose2 = engine.replayHistory(vial: vial, events: allEvents, at: tDose2)
        XCTAssertEqual(stateAtDose2.currentVolumeRemainingMl, 1.8, accuracy: 0.001)
        XCTAssertEqual(stateAtDose2.totalDosesAdministered, 2)
    }

    // MARK: - 8. Ancillary Supply Accounting & Reconciliation
    func testSupplyAccountingAndReconciliation() {
        let supplyItem = SupplyItem(
            id: UUID(),
            name: "Insulin Syringes U-100",
            category: .syringes,
            quantityRemaining: 100,
            reorderThreshold: 20
        )

        let t0 = Date().addingTimeInterval(-3600)
        let (reconEvent, updatedQty) = engine.reconcileSupply(
            item: supplyItem,
            existingEvents: [],
            observedQuantity: 92,
            reason: .countingError,
            notes: "Count correction during weekly inventory check",
            timestamp: t0
        )

        XCTAssertEqual(reconEvent.eventType, .reconciliation)
        XCTAssertEqual(reconEvent.changeQuantityCount, -8) // 92 - 100 = -8 units
        XCTAssertEqual(updatedQty, 92)
    }
}
