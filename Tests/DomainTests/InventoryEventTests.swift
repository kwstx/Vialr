import XCTest
@testable import Domain

final class InventoryEventTests: XCTestCase {

    func testInventoryEventCodableRoundtrip() throws {
        let id = UUID()
        let vialId = UUID()
        let compoundId = UUID()
        let doseEventId = UUID()
        let now = Date()

        let event = InventoryEvent(
            id: id,
            userId: UUID(),
            vialId: vialId,
            supplyItemId: nil,
            compoundId: compoundId,
            compoundName: "BPC-157",
            eventType: .doseConsumption,
            timestamp: now,
            reason: "Dose administration draw (0.100 mL)",
            changeMassMg: -0.25,
            changeVolumeMl: -0.10,
            resultingVolumeRemainingMl: 1.90,
            resultingMassRemainingMg: 4.75,
            resultingConcentrationMgMl: 2.50,
            resultingStatus: .reconstituted,
            doseEventId: doseEventId,
            notes: "Clean draw",
            metadata: ["syringeSize": "0.3mL"],
            createdAt: now,
            updatedAt: now,
            version: 1,
            syncState: .synced
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(InventoryEvent.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.vialId, vialId)
        XCTAssertEqual(decoded.compoundName, "BPC-157")
        XCTAssertEqual(decoded.eventType, .doseConsumption)
        XCTAssertEqual(decoded.changeMassMg, -0.25)
        XCTAssertEqual(decoded.changeVolumeMl, -0.10)
        XCTAssertEqual(decoded.resultingVolumeRemainingMl, 1.90)
        XCTAssertEqual(decoded.resultingStatus, .reconstituted)
        XCTAssertEqual(decoded.doseEventId, doseEventId)
        XCTAssertEqual(decoded.metadata["syringeSize"], "0.3mL")
    }

    func testReconciliationEventFactories() {
        let vialId = UUID()
        let compoundId = UUID()

        let event = InventoryEvent.reconciliation(
            vialId: vialId,
            compoundId: compoundId,
            compoundName: "Retatrutide",
            volumeVarianceMl: -0.15,
            massVarianceMg: -0.75,
            newVolumeRemainingMl: 1.85,
            newMassRemainingMg: 9.25,
            concentrationMgMl: 5.0,
            reason: .deadSpaceLoss,
            userNotes: "Dead space adjustment after 5 injections"
        )

        XCTAssertEqual(event.eventType, .reconciliation)
        XCTAssertEqual(event.reconciliationReason, .deadSpaceLoss)
        XCTAssertEqual(event.changeVolumeMl, -0.15)
        XCTAssertEqual(event.changeMassMg, -0.75)
        XCTAssertEqual(event.resultingVolumeRemainingMl, 1.85)
        XCTAssertTrue(event.reason.contains("Syringe Dead Space"))
    }

    func testDisposalEventFactories() {
        let vialId = UUID()
        let compoundId = UUID()

        let event = InventoryEvent.disposal(
            vialId: vialId,
            compoundId: compoundId,
            compoundName: "CJC-1295",
            remainingVolumeBeforeDisposalMl: 0.4,
            remainingMassBeforeDisposalMg: 1.33,
            reason: .expired,
            userNotes: "Exceeded 30-day refrigerated limit"
        )

        XCTAssertEqual(event.eventType, .disposal)
        XCTAssertEqual(event.disposalReason, .expired)
        XCTAssertEqual(event.resultingVolumeRemainingMl, 0.0)
        XCTAssertEqual(event.resultingMassRemainingMg, 0.0)
        XCTAssertEqual(event.resultingStatus, .discarded)
    }

    func testReconciliationReasonEnumDescriptions() {
        for reason in ReconciliationReason.allCases {
            XCTAssertFalse(reason.rawValue.isEmpty)
            XCTAssertFalse(reason.descriptionText.isEmpty)
        }
    }

    func testDisposalReasonEnumProperties() {
        for reason in DisposalReason.allCases {
            XCTAssertFalse(reason.rawValue.isEmpty)
            XCTAssertFalse(reason.iconName.isEmpty)
        }
    }

    func testTimelineEventFromInventoryEvent() {
        let invEvent = InventoryEvent.reconciliation(
            vialId: UUID(),
            compoundId: UUID(),
            compoundName: "TB-500",
            volumeVarianceMl: -0.10,
            massVarianceMg: -0.50,
            newVolumeRemainingMl: 1.90,
            newMassRemainingMg: 9.50,
            concentrationMgMl: 5.0,
            reason: .measurementVariance
        )

        let timelineEvent = TimelineEvent(from: invEvent)

        XCTAssertEqual(timelineEvent.category, .inventory)
        XCTAssertEqual(timelineEvent.associatedEntityType, .inventoryEvent)
        XCTAssertTrue(timelineEvent.title.contains("TB-500"))
        XCTAssertTrue(timelineEvent.isHighlighted)
    }
}
