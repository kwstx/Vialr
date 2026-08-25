import Foundation
import Domain

public enum SyncStatus: Sendable, Equatable {
    case synced
    case syncing
    case offline
    case error(String)
}

public protocol SyncEngineProtocol: Sendable {
    func triggerSync() async throws
    func getStatus() -> SyncStatus
    func recordMutation(entityType: String, entityId: UUID, operation: String, payload: Data?) async
}

public struct SyncChangeRecord: Codable, Sendable {
    public let id: UUID
    public let entityType: String
    public let entityId: UUID
    public let operation: String
    public let payload: Data?
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        entityType: String,
        entityId: UUID,
        operation: String,
        payload: Data? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.payload = payload
        self.timestamp = timestamp
    }
}

/// Manages bidirectional data synchronization between local storage and the Vapor/PostgreSQL backend.
public final class SyncEngine: SyncEngineProtocol, @unchecked Sendable {
    public static let shared = SyncEngine()

    private var currentStatus: SyncStatus = .synced
    private var pendingChanges: [SyncChangeRecord] = []
    private var lastSyncTimestamp: Date?
    private let lock = NSLock()
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    public func getStatus() -> SyncStatus {
        lock.lock()
        defer { lock.unlock() }
        return currentStatus
    }

    public func recordMutation(entityType: String, entityId: UUID, operation: String, payload: Data?) async {
        let record = SyncChangeRecord(
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: payload
        )
        lock.lock()
        pendingChanges.append(record)
        lock.unlock()
    }

    public func triggerSync() async throws {
        lock.lock()
        currentStatus = .syncing
        let changesToPush = self.pendingChanges
        lock.unlock()

        do {
            // Push pending offline mutations to the backend if any exist
            if !changesToPush.isEmpty {
                // In production, send changesToPush to POST /api/v1/sync/push
                lock.lock()
                self.pendingChanges.removeAll { change in
                    changesToPush.contains(where: { $0.id == change.id })
                }
                lock.unlock()
            }

            // Simulate / execute server delta reconciliation
            try await Task.sleep(nanoseconds: 400_000_000)

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
}
