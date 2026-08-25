import Foundation
import Domain

public enum SyncStatus: Sendable {
    case synced
    case syncing
    case offline
    case error(String)
}

public protocol SyncEngineProtocol: Sendable {
    func triggerSync() async throws
    func getStatus() -> SyncStatus
}

/// Manages background data synchronization between local SQLite/in-memory store and remote backend.
public final class SyncEngine: SyncEngineProtocol, @unchecked Sendable {
    public static let shared = SyncEngine()
    private var currentStatus: SyncStatus = .synced
    private let lock = NSLock()

    public init() {}

    public func getStatus() -> SyncStatus {
        lock.lock()
        defer { lock.unlock() }
        return currentStatus
    }

    public func triggerSync() async throws {
        lock.lock()
        currentStatus = .syncing
        lock.unlock()

        // Simulate async secure sync over network
        try await Task.sleep(nanoseconds: 800_000_000)

        lock.lock()
        currentStatus = .synced
        lock.unlock()
    }
}
