import Foundation

/// Protocol that every synchronizeable domain model in Vialr must conform to.
/// Ensures all important entities have a globally unique identifier, creation timestamp,
/// modification timestamp, version counter for optimistic concurrency, and synchronization state.
public protocol SyncableRecord: Identifiable, Sendable {
    /// Globally unique identifier across devices and servers.
    var id: UUID { get }

    /// Timestamp when this record was originally created.
    var createdAt: Date { get set }

    /// Timestamp when this record was last modified.
    var updatedAt: Date { get set }

    /// Monotonically increasing version number for conflict resolution.
    var version: Int { get set }

    /// Current synchronization lifecycle state.
    var syncState: SyncState { get set }
}
