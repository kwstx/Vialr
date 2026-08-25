import Foundation

/// Represents the type of CRUD mutation performed locally.
public enum SyncAction: String, Codable, Sendable, CaseIterable {
    case create = "create"
    case update = "update"
    case delete = "delete"
}

/// Represents the processing status of a queued sync operation.
public enum SyncQueueStatus: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
    case inFlight = "inFlight"
    case failed = "failed"
    case completed = "completed"
}

/// Represents a persistent entry in the synchronization queue.
/// Every local write immediately appends an item to this queue before returning to the UI,
/// ensuring reliable offline-to-online reconciliation without data loss.
public struct SyncQueueItem: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var entityType: String
    public var entityId: UUID
    public var action: SyncAction
    public var payloadJSON: String?
    public var version: Int
    public var queuedAt: Date
    public var attempts: Int
    public var maxAttempts: Int
    public var lastError: String?
    public var status: SyncQueueStatus
    public var nextRetryAt: Date?

    public init(
        id: UUID = UUID(),
        entityType: String,
        entityId: UUID,
        action: SyncAction,
        payloadJSON: String? = nil,
        version: Int = 1,
        queuedAt: Date = Date(),
        attempts: Int = 0,
        maxAttempts: Int = 5,
        lastError: String? = nil,
        status: SyncQueueStatus = .pending,
        nextRetryAt: Date? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.action = action
        self.payloadJSON = payloadJSON
        self.version = version
        self.queuedAt = queuedAt
        self.attempts = attempts
        self.maxAttempts = maxAttempts
        self.lastError = lastError
        self.status = status
        self.nextRetryAt = nextRetryAt
    }

    /// Creates a SyncQueueItem with an encodable domain payload.
    public static func create<T: Encodable>(
        entityType: String,
        entityId: UUID,
        action: SyncAction,
        entity: T,
        version: Int = 1
    ) -> SyncQueueItem {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonString: String?
        if let data = try? encoder.encode(entity) {
            jsonString = String(data: data, encoding: .utf8)
        } else {
            jsonString = nil
        }

        return SyncQueueItem(
            entityType: entityType,
            entityId: entityId,
            action: action,
            payloadJSON: jsonString,
            version: version
        )
    }

    /// Decodes the payload JSON back into a specific domain model.
    public func decodePayload<T: Decodable>(as type: T.Type) -> T? {
        guard let json = payloadJSON, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    /// Calculates exponential backoff delay in seconds for retries (e.g. 2s, 4s, 8s, 16s...).
    public var backoffDelaySeconds: TimeInterval {
        let base: Double = 2.0
        let exponent = min(Double(attempts), 6.0)
        return pow(base, exponent)
    }
}
