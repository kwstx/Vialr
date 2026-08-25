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
}

public protocol SyncEngineProtocol: Sendable {
    func triggerSync() async throws
    func getStatus() -> SyncStatus
    func recordMutation(entityType: String, entityId: UUID, operation: String, payload: Data?) async
    func pullRemoteDeltas() async throws
}

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

/// Manages reliable, offline-first bidirectional synchronization between local SwiftData / SQLite storage
/// and the cloud backend. Ensures all local mutations (dose logs, inventory, protocols) are persisted
/// immediately and reconciled seamlessly in the background.
public final class SyncEngine: SyncEngineProtocol, @unchecked Sendable {
    public static let shared = SyncEngine()

    private var currentStatus: SyncStatus = .synced
    private var lastSyncTimestamp: Date?
    private let lock = NSLock()
    private let apiClient: APIClientProtocol
    private let syncQueueRepo: SyncQueueRepositoryProtocol
    private var isSyncInProgress = false

    public init(
        apiClient: APIClientProtocol = APIClient.shared,
        syncQueueRepo: SyncQueueRepositoryProtocol = LocalSyncQueueRepository()
    ) {
        self.apiClient = apiClient
        self.syncQueueRepo = syncQueueRepo
    }

    public func getStatus() -> SyncStatus {
        lock.lock()
        defer { lock.unlock() }
        return currentStatus
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

    /// Triggers an asynchronous sync cycle: pushes queued local mutations first, then pulls remote deltas.
    public func triggerSync() async throws {
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
            // 1. Fetch pending items from local persistent sync queue
            let pendingItems = try await syncQueueRepo.fetchPending(limit: 50)
            
            lock.lock()
            currentStatus = pendingItems.isEmpty ? .synced : .syncing(pendingCount: pendingItems.count)
            lock.unlock()

            // 2. Push pending mutations if any exist
            if !pendingItems.isEmpty {
                for item in pendingItems {
                    try await syncQueueRepo.markInFlight(id: item.id)
                }

                let dtoArray = pendingItems.map { item in
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
                
                // Attempt push to backend
                do {
                    _ = try await apiClient.request(
                        endpoint: .syncPush,
                        body: pushPayload,
                        responseType: String.self
                    )

                    // On success, mark each queue item completed
                    for item in pendingItems {
                        try await syncQueueRepo.markCompleted(id: item.id)
                    }
                    try await syncQueueRepo.purgeCompleted()
                } catch {
                    // On failure, mark items failed with exponential backoff
                    for item in pendingItems {
                        try await syncQueueRepo.markFailed(
                            id: item.id,
                            error: error.localizedDescription,
                            retryable: true
                        )
                    }
                    throw error
                }
            }

            // 3. Pull remote server deltas and reconcile locally
            try await pullRemoteDeltas()

            lock.lock()
            self.lastSyncTimestamp = Date()
            self.currentStatus = .synced
            lock.unlock()
        } catch {
            lock.lock()
            self.currentStatus = .error(error.localizedDescription)
            lock.unlock()
            throw error
        }
    }

    /// Pulls incremental updates from the remote backend and merges them locally.
    public func pullRemoteDeltas() async throws {
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
            // If offline / network error, silently keep local data intact
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
        default:
            break
        }
    }
}
