import XCTest
@testable import Domain
@testable import Data

// Mock API Client for testing sync network interactions
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    var shouldFail: Bool = false
    var pushedChanges: [SyncDeltaItemDTO] = []
    
    func request<T: Decodable>(
        endpoint: Endpoint,
        body: (any Encodable)? = nil,
        responseType: T.Type
    ) async throws -> T {
        if shouldFail {
            throw NSError(domain: "NSURLErrorDomain", code: -1009, userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."])
        }
        
        if case .syncPush = endpoint {
            if let pushReq = body as? SyncPushRequestDTO {
                pushedChanges.append(contentsOf: pushReq.changes)
            }
            if T.self == String.self {
                return "OK" as! T
            }
        }
        
        if case .syncPull = endpoint {
            return SyncPullResponseDTO(serverTimestamp: Date(), changes: []) as! T
        }
        
        throw NSError(domain: "MockAPI", code: 404, userInfo: nil)
    }
}

final class LocalFirstSyncTests: XCTestCase {

    func testInstantDoseLoggingWithLocalVialDeductionAndSyncQueue() async throws {
        let store = LocalStore()
        
        let vialId = UUID()
        let compoundId = UUID()
        
        // Initial reconstituted vial: 10mg in 2.0mL BAC water (5mg/mL)
        let vial = Vial(
            id: vialId,
            compoundId: compoundId,
            compoundName: "Tirzepatide",
            totalDryMassMg: 10.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 2.0,
            isReconstituted: true,
            status: .reconstituted
        )
        
        await store.saveVial(vial)
        
        let initialVials = await store.getAllVials()
        XCTAssertEqual(initialVials.first?.currentVolumeRemainingMl, 2.0)
        
        // Log a 5.0mg dose (draw volume = 5.0mg / 5.0mg/mL = 1.0 mL)
        let doseId = UUID()
        let doseLog = DoseLog(
            id: doseId,
            compoundId: compoundId,
            compoundName: "Tirzepatide",
            actualDoseAmount: 5.0,
            doseUnit: .mg,
            status: .taken,
            vialId: vialId
        )
        
        // Save immediately to local store
        await store.saveDoseLog(doseLog)
        
        // 1. Verify 0ms local read has the new dose log
        let doses = await store.getAllDoseLogs()
        XCTAssertEqual(doses.count, 1)
        XCTAssertEqual(doses.first?.id, doseId)
        XCTAssertEqual(doses.first?.syncState, .pendingCreation)
        
        // 2. Verify local vial liquid volume was immediately deducted by 1.0 mL (2.0 - 1.0 = 1.0 mL)
        let updatedVials = await store.getAllVials()
        let updatedVial = updatedVials.first(where: { $0.id == vialId })
        XCTAssertEqual(updatedVial?.currentVolumeRemainingMl, 1.0)
        XCTAssertEqual(updatedVial?.version, 2)
        XCTAssertEqual(updatedVial?.syncState, .pendingUpdate)
        
        // 3. Verify mutations were automatically enqueued in the persistent sync queue
        let pendingQueue = await store.getPendingSyncQueue()
        XCTAssertGreaterThanOrEqual(pendingQueue.count, 2) // vial update + dose creation
        
        let doseQueueItem = pendingQueue.first(where: { $0.entityId == doseId })
        XCTAssertNotNil(doseQueueItem)
        XCTAssertEqual(doseQueueItem?.action, .create)
        XCTAssertEqual(doseQueueItem?.status, .pending)
    }

    func testOfflineToOnlineSyncRecovery() async throws {
        let store = LocalStore.shared
        await store.clearAllSyncQueue()
        
        let mockApi = MockAPIClient()
        let networkMonitor = NetworkMonitor.shared
        let syncQueueRepo = LocalSyncQueueRepository(store: store)
        
        let syncEngine = SyncEngine(
            apiClient: mockApi,
            syncQueueRepo: syncQueueRepo,
            networkMonitor: networkMonitor
        )
        
        // 1. User is offline
        networkMonitor.simulateNetworkStatusChange(isConnected: false)
        XCTAssertFalse(networkMonitor.isConnected)
        
        // 2. User logs a dose while offline
        let doseId = UUID()
        let dose = DoseLog(
            id: doseId,
            compoundId: UUID(),
            compoundName: "BPC-157",
            actualDoseAmount: 250,
            doseUnit: .mcg,
            status: .taken
        )
        
        await store.saveDoseLog(dose)
        
        // 3. Dose exists locally immediately with .pendingCreation state
        let localDoses = await store.getAllDoseLogs()
        let loggedDose = localDoses.first(where: { $0.id == doseId })
        XCTAssertNotNil(loggedDose)
        XCTAssertEqual(loggedDose?.syncState, .pendingCreation)
        
        // 4. Queue item exists in pending status
        let pendingBefore = try await syncQueueRepo.fetchPending(limit: nil)
        XCTAssertTrue(pendingBefore.contains(where: { $0.entityId == doseId }))
        
        // 5. Trigger sync while offline -> Should not fail/purge items, status becomes .offline
        try await syncEngine.triggerSync()
        XCTAssertEqual(syncEngine.getStatus(), .offline)
        XCTAssertEqual(mockApi.pushedChanges.count, 0)
        
        // 6. Connectivity returns!
        networkMonitor.simulateNetworkStatusChange(isConnected: true)
        XCTAssertTrue(networkMonitor.isConnected)
        
        // 7. Trigger sync cycle (network restored)
        try await syncEngine.triggerSync()
        
        // 8. Verify payload was uploaded to backend
        XCTAssertGreaterThanOrEqual(mockApi.pushedChanges.count, 1)
        let pushedDose = mockApi.pushedChanges.first(where: { $0.entityId == doseId })
        XCTAssertNotNil(pushedDose)
        XCTAssertEqual(pushedDose?.operation, "create")
        
        // 9. Local dose transitioned from .pendingCreation to .synced
        let localDosesAfter = await store.getAllDoseLogs()
        let syncedDose = localDosesAfter.first(where: { $0.id == doseId })
        XCTAssertEqual(syncedDose?.syncState, .synced)
        
        // 10. Queue is purged of completed items
        let pendingAfter = try await syncQueueRepo.fetchPending(limit: nil)
        XCTAssertFalse(pendingAfter.contains(where: { $0.entityId == doseId }))
        XCTAssertEqual(syncEngine.getStatus(), .synced)
    }

    func testSyncQueueLifecycleTransitions() async throws {
        let store = LocalStore()
        let repo = LocalSyncQueueRepository(store: store)
        
        let itemId = UUID()
        let queueItem = SyncQueueItem(
            id: itemId,
            entityType: "doseEvent",
            entityId: UUID(),
            action: .create,
            payloadJSON: "{\"name\":\"Test\"}",
            version: 1,
            status: .pending
        )
        
        try await repo.enqueue(queueItem)
        
        var pending = try await repo.fetchPending(limit: nil)
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.id, itemId)
        
        // Mark in flight
        try await repo.markInFlight(id: itemId)
        
        // Mark completed
        try await repo.markCompleted(id: itemId)
        
        // Completed items shouldn't show in pending queue
        pending = try await repo.fetchPending(limit: nil)
        XCTAssertEqual(pending.count, 0)
        
        // Purge completed
        try await repo.purgeCompleted()
        let count = try await repo.countPending()
        XCTAssertEqual(count, 0)
    }

    func testSyncQueueRetryOnFailure() async throws {
        let store = LocalStore()
        let repo = LocalSyncQueueRepository(store: store)
        
        let itemId = UUID()
        let queueItem = SyncQueueItem(
            id: itemId,
            entityType: "biomarker",
            entityId: UUID(),
            action: .create,
            status: .pending
        )
        
        try await repo.enqueue(queueItem)
        
        // Simulate failure
        try await repo.markFailed(id: itemId, error: "Network timeout", retryable: true)
        
        let pending = await store.syncQueue
        let item = pending.first(where: { $0.id == itemId })
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.lastError, "Network timeout")
        XCTAssertNotNil(item?.nextRetryAt)
    }
}
