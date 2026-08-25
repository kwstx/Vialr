import XCTest
@testable import Domain
@testable import Data

// MARK: - Mock Outbox API Client
final class MockOutboxAPIClient: APIClientProtocol, @unchecked Sendable {
    var shouldFail: Bool = false
    var pushedOutboxOperations: [OutboxOperationDTO] = []
    var customResponse: OutboxPushResponseDTO?
    
    func request<T: Decodable>(
        endpoint: Endpoint,
        body: (any Encodable)? = nil,
        responseType: T.Type
    ) async throws -> T {
        if shouldFail {
            throw NSError(domain: "NSURLErrorDomain", code: -1009, userInfo: [NSLocalizedDescriptionKey: "Network offline."])
        }
        
        if case .syncOutbox = endpoint {
            if let req = body as? OutboxPushRequestDTO {
                pushedOutboxOperations.append(contentsOf: req.operations)
                
                if let custom = customResponse {
                    return custom as! T
                }
                
                let results = req.operations.map { op in
                    OutboxOperationResultDTO(
                        operationId: op.id,
                        objectIdentifier: op.objectIdentifier,
                        status: "applied",
                        canonicalServerVersion: op.version + 1,
                        serverTimestamp: Date()
                    )
                }
                return OutboxPushResponseDTO(serverTimestamp: Date(), results: results) as! T
            }
        }
        
        if case .syncPull = endpoint {
            return SyncPullResponseDTO(serverTimestamp: Date(), changes: []) as! T
        }
        
        if case .syncPush = endpoint {
            if T.self == String.self {
                return "OK" as! T
            }
        }
        
        throw NSError(domain: "MockAPI", code: 404, userInfo: nil)
    }
}

final class OutboxSynchronizationTests: XCTestCase {

    // MARK: - Test 1: Outbox Operation Creation On Local Mutation
    func testOutboxOperationCreationOnDoseLogging() async throws {
        let store = LocalStore()
        
        let doseId = UUID()
        let compoundId = UUID()
        let dose = DoseLog(
            id: doseId,
            compoundId: compoundId,
            compoundName: "BPC-157",
            actualDoseAmount: 250.0,
            doseUnit: .mcg,
            status: .taken,
            version: 1
        )
        
        // Save locally
        await store.saveDoseLog(dose)
        
        // Verify local state
        let doses = await store.getAllDoseLogs()
        XCTAssertEqual(doses.count, 1)
        XCTAssertEqual(doses.first?.id, doseId)
        XCTAssertEqual(doses.first?.syncState, .pendingCreation)
        
        // Verify Outbox operation was created with preserveBoth strategy
        let pendingOutbox = await store.getPendingOutboxOperations()
        XCTAssertGreaterThanOrEqual(pendingOutbox.count, 1)
        
        let doseOp = pendingOutbox.first(where: { $0.objectIdentifier == doseId })
        XCTAssertNotNil(doseOp)
        XCTAssertEqual(doseOp?.entityType, .doseEvent)
        XCTAssertEqual(doseOp?.operationType, .create)
        XCTAssertEqual(doseOp?.version, 1)
        XCTAssertEqual(doseOp?.conflictStrategy, .preserveBoth)
        XCTAssertEqual(doseOp?.status, .pending)
    }

    // MARK: - Test 2: Last-Write-Wins Conflict Policy for Preferences
    func testLastWriteWinsConflictPolicyForUserPreferences() async throws {
        let store = LocalStore()
        let userId = UUID()
        let user = User(
            id: userId,
            accountInfo: AccountInfo(email: "test@vialr.ai", displayName: "Alex"),
            version: 1
        )
        await store.saveUser(user)
        
        // Update preferences
        let newPrefs = UserPreferences(theme: "Dark", reminderLeadTimeMinutes: 15)
        await store.updatePreferences(newPrefs)
        
        let pendingOutbox = await store.getPendingOutboxOperations()
        let prefOp = pendingOutbox.first(where: { $0.objectIdentifier == userId })
        XCTAssertNotNil(prefOp)
        XCTAssertEqual(prefOp?.conflictStrategy, .lastWriteWins)
        XCTAssertEqual(prefOp?.entityType, .user)
    }

    // MARK: - Test 3: Append-Oriented Protocol Revisions
    func testAppendOrientedProtocolRevisionsOnProtocolChange() async throws {
        let store = LocalStore()
        let protocolId = UUID()
        let compoundId = UUID()
        
        let initialProto = ProtocolModel(
            id: protocolId,
            name: "Initial Protocol",
            compounds: [
                ProtocolCompound(compoundId: compoundId, compoundName: "CJC-1295", targetDoseAmount: 100.0)
            ],
            version: 1
        )
        
        // Create initial protocol
        await store.saveProtocol(initialProto, changeReason: "Initial creation")
        
        let revs1 = await store.getProtocolRevisions(forProtocol: protocolId)
        XCTAssertEqual(revs1.count, 1)
        XCTAssertEqual(revs1.first?.revisionNumber, 1)
        XCTAssertEqual(revs1.first?.reasonForChange, "Initial creation")
        
        // Modify protocol (titration increase to 200mcg)
        var updatedProto = initialProto
        updatedProto.name = "Titrated Protocol CJC"
        updatedProto.compounds = [
            ProtocolCompound(compoundId: compoundId, compoundName: "CJC-1295", targetDoseAmount: 200.0)
        ]
        
        await store.saveProtocol(updatedProto, changeReason: "Titration dose increase to 200mcg")
        
        // Verify longitudinal history is preserved: 2 revisions exist
        let revs2 = await store.getProtocolRevisions(forProtocol: protocolId)
        XCTAssertEqual(revs2.count, 2)
        XCTAssertEqual(revs2.first?.revisionNumber, 1)
        XCTAssertEqual(revs2.last?.revisionNumber, 2)
        XCTAssertEqual(revs2.last?.reasonForChange, "Titration dose increase to 200mcg")
        
        // Verify Outbox recorded both revisions
        let pendingOutbox = await store.getPendingOutboxOperations()
        let revOps = pendingOutbox.filter { $0.entityType == .protocolRevision }
        XCTAssertEqual(revOps.count, 2)
    }

    // MARK: - Test 4: End-to-End Outbox Sync with Canonical Version Reflection
    func testOutboxBatchSyncAndCanonicalVersionApplication() async throws {
        let store = LocalStore()
        await store.clearAllOutbox()
        
        let mockApi = MockOutboxAPIClient()
        let networkMonitor = NetworkMonitor.shared
        networkMonitor.simulateNetworkStatusChange(isConnected: true)
        
        let syncEngine = SyncEngine(
            apiClient: mockApi,
            syncQueueRepo: LocalSyncQueueRepository(store: store),
            outboxRepo: LocalOutboxRepository(store: store),
            networkMonitor: networkMonitor
        )
        
        // 1. Log a dose locally
        let doseId = UUID()
        let dose = DoseLog(
            id: doseId,
            compoundId: UUID(),
            compoundName: "NAD+",
            actualDoseAmount: 50.0,
            doseUnit: .mg,
            status: .taken,
            version: 1
        )
        await store.saveDoseLog(dose)
        
        // 2. Mock server response returning canonical server version = 5
        let serverTimestamp = Date()
        mockApi.customResponse = OutboxPushResponseDTO(
            serverTimestamp: serverTimestamp,
            results: [
                OutboxOperationResultDTO(
                    operationId: (await store.getPendingOutboxOperations()).first(where: { $0.objectIdentifier == doseId })!.id,
                    objectIdentifier: doseId,
                    status: "applied",
                    canonicalServerVersion: 5,
                    serverTimestamp: serverTimestamp
                )
            ]
        )
        
        // 3. Trigger sync cycle
        try await syncEngine.triggerSync()
        
        // 4. Verify client marked operation completed and purged Outbox
        let pendingAfter = await store.getPendingOutboxOperations()
        XCTAssertEqual(pendingAfter.count, 0)
        
        // 5. Verify local dose record has canonical server version 5 and is .synced
        let localDoses = await store.getAllDoseLogs()
        let syncedDose = localDoses.first(where: { $0.id == doseId })
        XCTAssertNotNil(syncedDose)
        XCTAssertEqual(syncedDose?.version, 5)
        XCTAssertEqual(syncedDose?.syncState, .synced)
    }

    // MARK: - Test 5: Conflict Detection Preserving Both Medical Records
    func testConflictDetectionPreservingBothHistoricalDoseVersions() async throws {
        let store = LocalStore()
        await store.clearAllOutbox()
        
        let mockApi = MockOutboxAPIClient()
        let networkMonitor = NetworkMonitor.shared
        networkMonitor.simulateNetworkStatusChange(isConnected: true)
        
        let syncEngine = SyncEngine(
            apiClient: mockApi,
            syncQueueRepo: LocalSyncQueueRepository(store: store),
            outboxRepo: LocalOutboxRepository(store: store),
            networkMonitor: networkMonitor
        )
        
        let primaryDoseId = UUID()
        let originalDose = DoseLog(
            id: primaryDoseId,
            compoundId: UUID(),
            compoundName: "Semaglutide",
            actualDoseAmount: 0.25,
            doseUnit: .mg,
            status: .taken,
            notes: "Original entry from Device A",
            version: 1
        )
        await store.saveDoseLog(originalDose)
        
        // Simulate concurrent conflicting version preserved on server from Device B
        let twinId = UUID()
        let twinDose = DoseEvent(
            id: twinId,
            compoundId: originalDose.compoundId,
            compoundName: "Semaglutide",
            actualDoseAmount: 0.50, // Conflicting dose amount entered on Device B
            doseUnit: .mg,
            status: .taken,
            notes: "[Preserved Concurrent Entry from Device B]",
            version: 2,
            syncState: .synced
        )
        
        let twinEncoder = JSONEncoder()
        twinEncoder.dateEncodingStrategy = .iso8601
        let twinJson = String(data: try twinEncoder.encode(twinDose), encoding: .utf8)!
        
        let opId = (await store.getPendingOutboxOperations()).first!.id
        mockApi.customResponse = OutboxPushResponseDTO(
            serverTimestamp: Date(),
            results: [
                OutboxOperationResultDTO(
                    operationId: opId,
                    objectIdentifier: primaryDoseId,
                    status: "preservedBoth",
                    canonicalServerVersion: 2,
                    serverTimestamp: Date(),
                    canonicalPayloadJson: twinJson,
                    preservedSecondaryIdentifier: twinId,
                    message: "Both historical medical versions preserved"
                )
            ]
        )
        
        // Trigger Outbox sync
        try await syncEngine.triggerSync()
        
        // Verify: Both versions are preserved safely in the client database!
        let allDoses = await store.getAllDoseLogs()
        XCTAssertEqual(allDoses.count, 2)
        
        let primary = allDoses.first(where: { $0.id == primaryDoseId })
        let twin = allDoses.first(where: { $0.id == twinId })
        
        XCTAssertNotNil(primary)
        XCTAssertNotNil(twin)
        XCTAssertEqual(primary?.actualDoseAmount, 0.25)
        XCTAssertEqual(twin?.actualDoseAmount, 0.50)
        XCTAssertEqual(twin?.syncState, .synced)
    }

    // MARK: - Test 6: Append-Oriented LabPanel Diagnostics
    func testAppendOrientedLabPanelDiagnostics() async throws {
        let store = LocalStore()
        let panelId = UUID()
        
        let panel = LabPanel(
            id: panelId,
            panelName: "Comprehensive Metabolic Panel",
            labName: "Quest Diagnostics",
            results: [
                LabResult(biomarkerName: "Glucose", value: 88.0, unit: "mg/dL", referenceRangeMin: 65, referenceRangeMax: 99),
                LabResult(biomarkerName: "eGFR", value: 105.0, unit: "mL/min/1.73m2", referenceRangeMin: 90)
            ],
            version: 1
        )
        
        await store.saveLabPanel(panel)
        
        let pending = await store.getPendingOutboxOperations()
        let labOp = pending.first(where: { $0.objectIdentifier == panelId })
        XCTAssertNotNil(labOp)
        XCTAssertEqual(labOp?.entityType, .labPanel)
        XCTAssertEqual(labOp?.conflictStrategy, .preserveBoth)
    }
}
