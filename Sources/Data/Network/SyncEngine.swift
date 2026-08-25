import Foundation
import Domain

public enum SyncStatus: Sendable, Equatable {
    case synced
    case syncing(pendingCount: Int)
    case offline
    case error(String)

    public var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }

    public var isOffline: Bool {
        if case .offline = self { return true }
        return false
    }
}

public protocol SyncEngineProtocol: Sendable {
    func triggerSync() async throws
    func getStatus() -> SyncStatus
    func recordMutation(entityType: String, entityId: UUID, operation: String, payload: Data?) async
    func pullRemoteDeltas() async throws
    func startPeriodicSync(intervalSeconds: TimeInterval)
    func stopPeriodicSync()
}

// MARK: - Outbox Sync DTOs

public struct OutboxOperationDTO: Codable, Sendable {
    public let id: UUID
    public let objectIdentifier: UUID
    public let entityType: String
    public let operationType: String
    public let version: Int
    public let timestamp: Date
    public let payload: String?
    public let conflictStrategy: String

    public init(
        id: UUID = UUID(),
        objectIdentifier: UUID,
        entityType: String,
        operationType: String,
        version: Int = 1,
        timestamp: Date = Date(),
        payload: String? = nil,
        conflictStrategy: String = "lastWriteWins"
    ) {
        self.id = id
        self.objectIdentifier = objectIdentifier
        self.entityType = entityType
        self.operationType = operationType
        self.version = version
        self.timestamp = timestamp
        self.payload = payload
        self.conflictStrategy = conflictStrategy
    }

    public init(from domain: OutboxOperation) {
        self.id = domain.id
        self.objectIdentifier = domain.objectIdentifier
        self.entityType = domain.entityType.rawValue
        self.operationType = domain.operationType.rawValue
        self.version = domain.version
        self.timestamp = domain.timestamp
        self.payload = domain.payload
        self.conflictStrategy = domain.conflictStrategy.rawValue
    }
}

public struct OutboxPushRequestDTO: Codable, Sendable {
    public let operations: [OutboxOperationDTO]

    public init(operations: [OutboxOperationDTO]) {
        self.operations = operations
    }
}

public struct OutboxOperationResultDTO: Codable, Sendable {
    public let operationId: UUID
    public let objectIdentifier: UUID
    public let status: String // "applied", "resolvedLWW", "preservedBoth", "appended", "rejected"
    public let canonicalServerVersion: Int
    public let serverTimestamp: Date
    public let canonicalPayloadJson: String?
    public let preservedSecondaryIdentifier: UUID?
    public let message: String?

    public init(
        operationId: UUID,
        objectIdentifier: UUID,
        status: String,
        canonicalServerVersion: Int,
        serverTimestamp: Date = Date(),
        canonicalPayloadJson: String? = nil,
        preservedSecondaryIdentifier: UUID? = nil,
        message: String? = nil
    ) {
        self.operationId = operationId
        self.objectIdentifier = objectIdentifier
        self.status = status
        self.canonicalServerVersion = canonicalServerVersion
        self.serverTimestamp = serverTimestamp
        self.canonicalPayloadJson = canonicalPayloadJson
        self.preservedSecondaryIdentifier = preservedSecondaryIdentifier
        self.message = message
    }
}

public struct OutboxPushResponseDTO: Codable, Sendable {
    public let serverTimestamp: Date
    public let results: [OutboxOperationResultDTO]

    public init(serverTimestamp: Date = Date(), results: [OutboxOperationResultDTO] = []) {
        self.serverTimestamp = serverTimestamp
        self.results = results
    }
}

// MARK: - Legacy Delta DTOs (Preserved for compatibility)

public struct SyncDeltaItemDTO: Codable, Sendable {
    public let id: UUID
    public let entityType: String
    public let entityId: UUID
    public let operation: String
    public let payloadJson: String?
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        entityType: String,
        entityId: UUID,
        operation: String,
        payloadJson: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.payloadJson = payloadJson
        self.timestamp = timestamp
    }
}

public struct SyncPushRequestDTO: Codable, Sendable {
    public let changes: [SyncDeltaItemDTO]

    public init(changes: [SyncDeltaItemDTO]) {
        self.changes = changes
    }
}

public struct SyncPullResponseDTO: Codable, Sendable {
    public let serverTimestamp: Date
    public let changes: [SyncDeltaItemDTO]

    public init(serverTimestamp: Date = Date(), changes: [SyncDeltaItemDTO] = []) {
        self.serverTimestamp = serverTimestamp
        self.changes = changes
    }
}

/// Manages reliable, local-first Outbox synchronization between local storage (SwiftData / SQLite / In-Memory)
/// and the cloud PostgreSQL backend.
///
/// Whenever the user mutates data locally:
/// 1. The change is written instantly with 0ms perceived latency.
/// 2. An `OutboxOperation` is recorded in the Outbox containing object ID, operation type, version, timestamp, and payload.
/// 3. The synchronization manager periodically processes pending outbox operations.
/// 4. The server validates the operation, detects conflicts, applies appropriate strategies (LWW for preferences,
///    append-preservation for DoseEvents/LabResults, revisions for protocols), persists in PostgreSQL, and returns canonical versions.
/// 5. The client marks operations as synchronized and updates local version counters.
public final class SyncEngine: SyncEngineProtocol, @unchecked Sendable {
    public static let shared = SyncEngine()

    private var currentStatus: SyncStatus = .synced
    private var lastSyncTimestamp: Date?
    private let lock = NSLock()
    private let apiClient: APIClientProtocol
    private let syncQueueRepo: SyncQueueRepositoryProtocol
    private let outboxRepo: OutboxRepositoryProtocol
    private let networkMonitor: NetworkMonitorProtocol
    private var isSyncInProgress = false
    private var periodicTimerTask: Task<Void, Never>?

    public init(
        apiClient: APIClientProtocol = APIClient.shared,
        syncQueueRepo: SyncQueueRepositoryProtocol = LocalSyncQueueRepository(),
        outboxRepo: OutboxRepositoryProtocol = LocalOutboxRepository(),
        networkMonitor: NetworkMonitorProtocol = NetworkMonitor.shared
    ) {
        self.apiClient = apiClient
        self.syncQueueRepo = syncQueueRepo
        self.outboxRepo = outboxRepo
        self.networkMonitor = networkMonitor

        // Automatically trigger sync whenever network connectivity is restored
        self.networkMonitor.registerConnectivityRestoredHandler { [weak self] in
            guard let self = self else { return }
            Task {
                try? await self.triggerSync()
            }
        }
    }

    deinit {
        periodicTimerTask?.cancel()
    }

    public func getStatus() -> SyncStatus {
        lock.lock()
        defer { lock.unlock() }
        return currentStatus
    }

    public func startPeriodicSync(intervalSeconds: TimeInterval = 30.0) {
        stopPeriodicSync()
        periodicTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
                guard let self = self, !Task.isCancelled else { break }
                try? await self.triggerSync()
            }
        }
    }

    public func stopPeriodicSync() {
        periodicTimerTask?.cancel()
        periodicTimerTask = nil
    }

    public func recordMutation(entityType: String, entityId: UUID, operation: String, payload: Data?) async {
        let jsonString = payload.flatMap { String(data: $0, encoding: .utf8) }
        let item = SyncQueueItem(
            entityType: entityType,
            entityId: entityId,
            action: SyncAction(rawValue: operation) ?? .create,
            payloadJSON: jsonString
        )
        try? await syncQueueRepo.enqueue(item)
    }

    /// Triggers an Outbox synchronization cycle:
    /// 1. Checks network connectivity. If offline, sets `.offline` and keeps outbox operations safely queued.
    /// 2. Processes pending Outbox operations in batch.
    /// 3. Uploads Outbox batch to backend `/api/v1/sync/outbox`.
    /// 4. Applies canonical server versions and conflict resolutions returned by server.
    /// 5. Marks Outbox operations `.completed` and purges them from the local queue.
    /// 6. Pulls remote server deltas and reconciles changes.
    public func triggerSync() async throws {
        // 1. Check network reachability
        guard networkMonitor.isConnected else {
            lock.lock()
            let pendingCount = ((try? await outboxRepo.countPending()) ?? 0) + ((try? await syncQueueRepo.countPending()) ?? 0)
            if pendingCount > 0 {
                currentStatus = .offline
            } else {
                currentStatus = .synced
            }
            lock.unlock()
            print("[SyncEngine] Device is currently offline. Outbox operations remain safely preserved.")
            return
        }

        lock.lock()
        guard !isSyncInProgress else {
            lock.unlock()
            return
        }
        isSyncInProgress = true
        lock.unlock()

        defer {
            lock.lock()
            isSyncInProgress = false
            lock.unlock()
        }

        do {
            // 2. Fetch pending Outbox operations
            let pendingOutbox = try await outboxRepo.fetchPending(limit: 50)
            let pendingSync = try await syncQueueRepo.fetchPending(limit: 50)
            let totalPending = max(pendingOutbox.count, pendingSync.count)

            lock.lock()
            currentStatus = totalPending == 0 ? .synced : .syncing(pendingCount: totalPending)
            lock.unlock()

            // 3. Process Outbox operations if present
            if !pendingOutbox.isEmpty {
                for op in pendingOutbox {
                    try await outboxRepo.markInFlight(id: op.id)
                }

                let dtoArray = pendingOutbox.map { OutboxOperationDTO(from: $0) }
                let outboxPayload = OutboxPushRequestDTO(operations: dtoArray)

                do {
                    let response: OutboxPushResponseDTO = try await apiClient.request(
                        endpoint: .syncOutbox,
                        body: outboxPayload,
                        responseType: OutboxPushResponseDTO.self
                    )

                    // 4. Process server validation results and canonical versions
                    for result in response.results {
                        // Mark outbox operation completed with canonical version
                        try await outboxRepo.markCompleted(
                            id: result.operationId,
                            canonicalVersion: result.canonicalServerVersion,
                            serverTimestamp: result.serverTimestamp
                        )

                        // If server preserved a concurrent conflict twin, record it locally
                        if result.status == "preservedBoth", let twinJson = result.canonicalPayloadJson {
                            let entityType = pendingOutbox.first(where: { $0.id == result.operationId })?.entityType ?? .doseEvent
                            await LocalStore.shared.applyConflictPreservedRecord(
                                entityType: entityType,
                                primaryId: result.objectIdentifier,
                                secondaryPayloadJson: twinJson
                            )
                        }
                    }

                    try await outboxRepo.purgeCompleted()
                    try await syncQueueRepo.purgeCompleted()
                } catch {
                    // Try fallback legacy push if syncOutbox is not available or errors
                    for op in pendingOutbox {
                        try await outboxRepo.markFailed(
                            id: op.id,
                            error: error.localizedDescription,
                            retryable: true
                        )
                    }
                    throw error
                }
            } else if !pendingSync.isEmpty {
                // Fallback / legacy sync queue processing
                for item in pendingSync {
                    try await syncQueueRepo.markInFlight(id: item.id)
                }

                let dtoArray = pendingSync.map { item in
                    SyncDeltaItemDTO(
                        id: item.id,
                        entityType: item.entityType,
                        entityId: item.entityId,
                        operation: item.action.rawValue,
                        payloadJson: item.payloadJSON,
                        timestamp: item.queuedAt
                    )
                }

                let pushPayload = SyncPushRequestDTO(changes: dtoArray)
                
                do {
                    _ = try await apiClient.request(
                        endpoint: .syncPush,
                        body: pushPayload,
                        responseType: String.self
                    )

                    for item in pendingSync {
                        try await syncQueueRepo.markCompleted(id: item.id)
                    }
                    try await syncQueueRepo.purgeCompleted()
                } catch {
                    for item in pendingSync {
                        try await syncQueueRepo.markFailed(
                            id: item.id,
                            error: error.localizedDescription,
                            retryable: true
                        )
                    }
                    throw error
                }
            }

            // 5. Pull remote server deltas and reconcile locally
            try await pullRemoteDeltas()

            lock.lock()
            self.lastSyncTimestamp = Date()
            self.currentStatus = .synced
            lock.unlock()
        } catch {
            lock.lock()
            if !networkMonitor.isConnected {
                self.currentStatus = .offline
            } else {
                self.currentStatus = .error(error.localizedDescription)
            }
            lock.unlock()
            throw error
        }
    }

    /// Pulls incremental updates from the remote backend and merges them locally.
    public func pullRemoteDeltas() async throws {
        guard networkMonitor.isConnected else { return }
        
        let sinceDate = lock.withLock { lastSyncTimestamp }
        
        do {
            let response = try await apiClient.request(
                endpoint: .syncPull(since: sinceDate),
                responseType: SyncPullResponseDTO.self
            )

            // Reconcile incoming changes
            for change in response.changes {
                await reconcileRemoteChange(change)
            }
        } catch {
            print("[SyncEngine] Pull remote deltas notice: \(error.localizedDescription)")
        }
    }

    private func reconcileRemoteChange(_ change: SyncDeltaItemDTO) async {
        guard let json = change.payloadJson, let data = json.data(using: .utf8) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        switch change.entityType {
        case "doseEvent":
            if let dose = try? decoder.decode(DoseEvent.self, from: data) {
                var syncedDose = dose
                syncedDose.syncState = .synced
                await LocalStore.shared.saveDoseLog(syncedDose)
            }
        case "vial":
            if let vial = try? decoder.decode(Vial.self, from: data) {
                var syncedVial = vial
                syncedVial.syncState = .synced
                await LocalStore.shared.saveVial(syncedVial)
            }
        case "protocol":
            if let proto = try? decoder.decode(ProtocolModel.self, from: data) {
                var syncedProto = proto
                syncedProto.syncState = .synced
                await LocalStore.shared.saveProtocol(syncedProto)
            }
        case "protocolRevision":
            if let rev = try? decoder.decode(ProtocolRevision.self, from: data) {
                var syncedRev = rev
                syncedRev.syncState = .synced
                await LocalStore.shared.saveProtocolRevision(syncedRev)
            }
        case "compound":
            if let compound = try? decoder.decode(Compound.self, from: data) {
                var syncedCompound = compound
                syncedCompound.syncState = .synced
                await LocalStore.shared.saveCompound(syncedCompound)
            }
        case "biomarker":
            if let biomarker = try? decoder.decode(Biomarker.self, from: data) {
                var syncedB = biomarker
                syncedB.syncState = .synced
                await LocalStore.shared.saveBiomarker(syncedB)
            }
        case "labPanel":
            if let panel = try? decoder.decode(LabPanel.self, from: data) {
                var syncedP = panel
                syncedP.syncState = .synced
                await LocalStore.shared.saveLabPanel(syncedP)
            }
        default:
            break
        }
    }
}
