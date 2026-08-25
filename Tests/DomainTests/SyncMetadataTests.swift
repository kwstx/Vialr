import XCTest
@testable import Domain

final class SyncMetadataTests: XCTestCase {

    func testSyncStatePropertiesAndBadges() {
        let synced = SyncState.synced
        XCTAssertFalse(synced.isPending)
        XCTAssertEqual(synced.badgeColorHex, "#10B981")
        XCTAssertEqual(synced.displayTitle, "Synced")

        let pendingCreation = SyncState.pendingCreation
        XCTAssertTrue(pendingCreation.isPending)
        XCTAssertEqual(pendingCreation.badgeColorHex, "#3B82F6")

        let pendingUpdate = SyncState.pendingUpdate
        XCTAssertTrue(pendingUpdate.isPending)

        let pendingDeletion = SyncState.pendingDeletion
        XCTAssertTrue(pendingDeletion.isPending)

        let syncFailed = SyncState.syncFailed
        XCTAssertFalse(syncFailed.isPending)
        XCTAssertEqual(syncFailed.badgeColorHex, "#EF4444")
    }

    func testDoseEventSyncMetadataAndCodable() throws {
        let id = UUID()
        let now = Date()
        let event = DoseEvent(
            id: id,
            compoundId: UUID(),
            compoundName: "BPC-157",
            actualDoseAmount: 250.0,
            doseUnit: .mcg,
            status: .taken,
            createdAt: now,
            updatedAt: now,
            version: 3,
            syncState: .pendingUpdate
        )

        XCTAssertEqual(event.id, id)
        XCTAssertEqual(event.version, 3)
        XCTAssertEqual(event.syncState, .pendingUpdate)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DoseEvent.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.version, 3)
        XCTAssertEqual(decoded.syncState, .pendingUpdate)
    }

    func testVialSyncMetadataAndCodable() throws {
        let vialId = UUID()
        let now = Date()
        let vial = Vial(
            id: vialId,
            compoundId: UUID(),
            compoundName: "Tirzepatide",
            totalDryMassMg: 10.0,
            bacWaterAddedMl: 2.0,
            createdAt: now,
            updatedAt: now,
            version: 2,
            syncState: .pendingCreation
        )

        XCTAssertEqual(vial.id, vialId)
        XCTAssertEqual(vial.version, 2)
        XCTAssertEqual(vial.syncState, .pendingCreation)

        let data = try JSONEncoder().encode(vial)
        let decoded = try JSONDecoder().decode(Vial.self, from: data)

        XCTAssertEqual(decoded.id, vialId)
        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(decoded.syncState, .pendingCreation)
    }

    func testProtocolModelSyncMetadataAndCodable() throws {
        let id = UUID()
        let proto = ProtocolModel(
            id: id,
            name: "Longevity Protocol",
            version: 1,
            syncState: .synced
        )

        XCTAssertEqual(proto.id, id)
        XCTAssertEqual(proto.version, 1)
        XCTAssertEqual(proto.syncState, .synced)

        let data = try JSONEncoder().encode(proto)
        let decoded = try JSONDecoder().decode(ProtocolModel.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.syncState, .synced)
    }

    func testCompoundSyncMetadataAndCodable() throws {
        let id = UUID()
        let compound = Compound(
            id: id,
            name: "Sermorelin",
            version: 1,
            syncState: .pendingCreation
        )

        XCTAssertEqual(compound.id, id)
        XCTAssertEqual(compound.version, 1)
        XCTAssertEqual(compound.syncState, .pendingCreation)

        let data = try JSONEncoder().encode(compound)
        let decoded = try JSONDecoder().decode(Compound.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.syncState, .pendingCreation)
    }

    func testBiomarkerSyncMetadataAndCodable() throws {
        let id = UUID()
        let b = Biomarker(
            id: id,
            name: "IGF-1",
            category: .bloodwork,
            value: 245.0,
            unit: "ng/mL",
            version: 4,
            syncState: .synced
        )

        XCTAssertEqual(b.id, id)
        XCTAssertEqual(b.version, 4)
        XCTAssertEqual(b.syncState, .synced)

        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(Biomarker.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.version, 4)
        XCTAssertEqual(decoded.syncState, .synced)
    }

    func testSupplyItemSyncMetadataAndCodable() throws {
        let id = UUID()
        let supply = SupplyItem(
            id: id,
            name: "BAC Water 30mL",
            category: .bacWater,
            quantityRemaining: 4,
            version: 1,
            syncState: .synced
        )

        XCTAssertEqual(supply.id, id)
        XCTAssertEqual(supply.version, 1)
        XCTAssertEqual(supply.syncState, .synced)

        let data = try JSONEncoder().encode(supply)
        let decoded = try JSONDecoder().decode(SupplyItem.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.syncState, .synced)
    }

    func testMeasurementSyncMetadataAndCodable() throws {
        let id = UUID()
        let m = Measurement.weight(182.4, version: 2, syncState: .pendingUpdate)

        XCTAssertEqual(m.version, 2)
        XCTAssertEqual(m.syncState, .pendingUpdate)

        let data = try JSONEncoder().encode(m)
        let decoded = try JSONDecoder().decode(Measurement.self, from: data)

        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(decoded.syncState, .pendingUpdate)
    }

    func testLabPanelSyncMetadataAndCodable() throws {
        let id = UUID()
        let panel = LabPanel(
            id: id,
            panelName: "Complete Blood Count",
            version: 1,
            syncState: .synced
        )

        XCTAssertEqual(panel.id, id)
        XCTAssertEqual(panel.version, 1)
        XCTAssertEqual(panel.syncState, .synced)

        let data = try JSONEncoder().encode(panel)
        let decoded = try JSONDecoder().decode(LabPanel.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.syncState, .synced)
    }

    func testCostEventSyncMetadataAndCodable() throws {
        let id = UUID()
        let cost = CostEvent(
            id: id,
            title: "Peptide Supply Order",
            amount: 120.0,
            version: 2,
            syncState: .pendingCreation
        )

        XCTAssertEqual(cost.id, id)
        XCTAssertEqual(cost.version, 2)
        XCTAssertEqual(cost.syncState, .pendingCreation)

        let data = try JSONEncoder().encode(cost)
        let decoded = try JSONDecoder().decode(CostEvent.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(decoded.syncState, .pendingCreation)
    }

    func testDocumentSyncMetadataAndCodable() throws {
        let id = UUID()
        let doc = Document.labReport(
            title: "Lab Results Jan 2026",
            fileName: "lab.pdf",
            byteSize: 1024,
            version: 1,
            syncState: .synced
        )

        XCTAssertEqual(doc.version, 1)
        XCTAssertEqual(doc.syncState, .synced)

        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(Document.self, from: data)

        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.syncState, .synced)
    }

    func testOutcomeMetricSyncMetadataAndCodable() throws {
        let id = UUID()
        let metric = OutcomeMetric(
            id: id,
            protocolId: UUID(),
            name: "Body Fat %",
            baselineValue: 18.0,
            targetValue: 12.0,
            unit: "%",
            version: 3,
            syncState: .pendingUpdate
        )

        XCTAssertEqual(metric.id, id)
        XCTAssertEqual(metric.version, 3)
        XCTAssertEqual(metric.syncState, .pendingUpdate)

        let data = try JSONEncoder().encode(metric)
        let decoded = try JSONDecoder().decode(OutcomeMetric.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.version, 3)
        XCTAssertEqual(decoded.syncState, .pendingUpdate)
    }

    func testUserSyncMetadataAndCodable() throws {
        let id = UUID()
        let user = User(
            id: id,
            accountInfo: AccountInfo(email: "alex@example.com", displayName: "Alex Vance"),
            version: 5,
            syncState: .synced
        )

        XCTAssertEqual(user.id, id)
        XCTAssertEqual(user.version, 5)
        XCTAssertEqual(user.syncState, .synced)

        let data = try JSONEncoder().encode(user)
        let decoded = try JSONDecoder().decode(User.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.version, 5)
        XCTAssertEqual(decoded.syncState, .synced)
    }

    func testSyncQueueItemCreationAndPayloadRoundTrip() throws {
        let compoundId = UUID()
        let compound = Compound(
            id: compoundId,
            name: "Epithalon",
            category: .longevityNootropic,
            version: 1,
            syncState: .pendingCreation
        )

        let queueItem = SyncQueueItem.create(
            entityType: "compound",
            entityId: compoundId,
            action: .create,
            entity: compound,
            version: 1
        )

        XCTAssertEqual(queueItem.entityType, "compound")
        XCTAssertEqual(queueItem.entityId, compoundId)
        XCTAssertEqual(queueItem.action, .create)
        XCTAssertEqual(queueItem.status, .pending)
        XCTAssertEqual(queueItem.attempts, 0)

        // Decode payload back
        let decodedCompound = queueItem.decodePayload(as: Compound.self)
        XCTAssertNotNil(decodedCompound)
        XCTAssertEqual(decodedCompound?.id, compoundId)
        XCTAssertEqual(decodedCompound?.name, "Epithalon")

        // Exponential backoff
        var retryItem = queueItem
        retryItem.attempts = 1
        XCTAssertEqual(retryItem.backoffDelaySeconds, 2.0)
        retryItem.attempts = 3
        XCTAssertEqual(retryItem.backoffDelaySeconds, 8.0)
    }
}
