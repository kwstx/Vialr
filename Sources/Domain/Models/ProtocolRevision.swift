import Foundation

/// Represents an append-oriented immutable revision snapshot of a protocol.
///
/// Rather than destructively overwriting protocol definitions (titrations, dosage adjustments,
/// schedule frequencies, compound additions), every change creates an immutable `ProtocolRevision`.
/// This ensures full longitudinal auditability, safe historical adherence analytics, and eliminates
/// silent data loss across distributed devices.
public struct ProtocolRevision: SyncableRecord, Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var protocolId: UUID
    public var revisionNumber: Int
    public var previousRevisionId: UUID?
    public var name: String
    public var compounds: [ProtocolCompound]
    public var reasonForChange: String
    public var changedByUserId: UUID?
    public var effectiveDate: Date
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var syncState: SyncState

    public init(
        id: UUID = UUID(),
        protocolId: UUID,
        revisionNumber: Int = 1,
        previousRevisionId: UUID? = nil,
        name: String,
        compounds: [ProtocolCompound] = [],
        reasonForChange: String = "Protocol update",
        changedByUserId: UUID? = nil,
        effectiveDate: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        syncState: SyncState = .synced
    ) {
        self.id = id
        self.protocolId = protocolId
        self.revisionNumber = revisionNumber
        self.previousRevisionId = previousRevisionId
        self.name = name
        self.compounds = compounds
        self.reasonForChange = reasonForChange
        self.changedByUserId = changedByUserId
        self.effectiveDate = effectiveDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.syncState = syncState
    }
}
