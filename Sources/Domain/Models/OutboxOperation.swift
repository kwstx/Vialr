import Foundation

/// Defines the category of entity being mutated in the outbox.
public enum OutboxEntityType: String, Codable, Sendable, CaseIterable {
    case doseEvent = "doseEvent"
    case labResult = "labResult"
    case labPanel = "labPanel"
    case protocolModel = "protocol"
    case protocolRevision = "protocolRevision"
    case vial = "vial"
    case supply = "supply"
    case biomarker = "biomarker"
    case symptomLog = "symptomLog"
    case measurement = "measurement"
    case costEvent = "costEvent"
    case userPreference = "userPreference"
    case user = "user"
    case document = "document"
    case injectionSiteEvent = "injectionSiteEvent"
    case reconstitutionRecord = "reconstitutionRecord"
    case outcomeMetric = "outcomeMetric"
    case custom = "custom"
}

/// Defines the type of database mutation represented by an outbox operation.
public enum OutboxOperationType: String, Codable, Sendable, CaseIterable {
    case create = "create"
    case update = "update"
    case delete = "delete"
    case append = "append"
}

/// Defines the conflict resolution policy for a specific operation.
public enum ConflictStrategy: String, Codable, Sendable, CaseIterable {
    /// Simple preferences & transient settings: the highest version / newest timestamp wins.
    case lastWriteWins = "lastWriteWins"
    
    /// Historical medical / health events (DoseEvents, LabResults): concurrent writes must
    /// NEVER silently overwrite. Instead, both records are preserved or merged safely.
    case preserveBoth = "preserveBoth"
    
    /// Strictly append-only record (e.g. ProtocolRevision, DoseAuditTrail).
    case appendRecord = "appendRecord"
    
    /// Requires manual intervention or clinician review.
    case manualResolution = "manualResolution"
}

/// Processing lifecycle status of an Outbox operation.
public enum OutboxStatus: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
    case inFlight = "inFlight"
    case completed = "completed"
    case failed = "failed"
    case conflict = "conflict"
}

/// Represents a persistent mutation recorded in the client Outbox.
///
/// Whenever the user mutates data locally (logging doses, updating protocols, editing preferences),
/// the application writes the change to the local store and instantly creates an `OutboxOperation`.
/// The synchronization manager periodically batches and processes these operations,
/// uploading them to the backend where PostgreSQL validates and stores them, assigning canonical versions.
public struct OutboxOperation: Identifiable, Codable, Sendable, Hashable {
    /// Unique identifier for this outbox operation.
    public let id: UUID
    
    /// Identifier of the target domain entity (e.g., doseEvent.id, protocol.id, vial.id).
    public var objectIdentifier: UUID
    
    /// The entity model type name.
    public var entityType: OutboxEntityType
    
    /// CRUD operation type (create, update, delete, append).
    public var operationType: OutboxOperationType
    
    /// Monotonically increasing local version at the time the operation was recorded.
    public var version: Int
    
    /// Timestamp when this mutation was performed on the client.
    public var timestamp: Date
    
    /// Serialized JSON payload containing the entity data.
    public var payload: String?
    
    /// Conflict resolution strategy to use if remote conflict occurs.
    public var conflictStrategy: ConflictStrategy
    
    /// Current synchronization status of this operation.
    public var status: OutboxStatus
    
    /// Number of sync attempts made so far.
    public var retryCount: Int
    
    /// Maximum allowable retry attempts before failing permanently.
    public var maxRetries: Int
    
    /// Last error description if a sync attempt failed.
    public var lastError: String?
    
    /// Scheduled next retry timestamp for exponential backoff.
    public var nextRetryAt: Date?
    
    /// Canonical server version assigned by PostgreSQL upon successful synchronization.
    public var canonicalServerVersion: Int?
    
    /// Server timestamp when the operation was committed to the database.
    public var serverTimestamp: Date?

    public init(
        id: UUID = UUID(),
        objectIdentifier: UUID,
        entityType: OutboxEntityType,
        operationType: OutboxOperationType,
        version: Int = 1,
        timestamp: Date = Date(),
        payload: String? = nil,
        conflictStrategy: ConflictStrategy = .lastWriteWins,
        status: OutboxStatus = .pending,
        retryCount: Int = 0,
        maxRetries: Int = 5,
        lastError: String? = nil,
        nextRetryAt: Date? = nil,
        canonicalServerVersion: Int? = nil,
        serverTimestamp: Date? = nil
    ) {
        self.id = id
        self.objectIdentifier = objectIdentifier
        self.entityType = entityType
        self.operationType = operationType
        self.version = version
        self.timestamp = timestamp
        self.payload = payload
        self.conflictStrategy = conflictStrategy
        self.status = status
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.lastError = lastError
        self.nextRetryAt = nextRetryAt
        self.canonicalServerVersion = canonicalServerVersion
        self.serverTimestamp = serverTimestamp
    }

    /// Factory method to create an OutboxOperation with an encodable domain payload.
    public static func create<T: Encodable>(
        objectIdentifier: UUID,
        entityType: OutboxEntityType,
        operationType: OutboxOperationType,
        entity: T,
        version: Int = 1,
        conflictStrategy: ConflictStrategy? = nil,
        timestamp: Date = Date()
    ) -> OutboxOperation {
        let strategy = conflictStrategy ?? defaultStrategy(for: entityType)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonString: String?
        if let data = try? encoder.encode(entity) {
            jsonString = String(data: data, encoding: .utf8)
        } else {
            jsonString = nil
        }

        return OutboxOperation(
            objectIdentifier: objectIdentifier,
            entityType: entityType,
            operationType: operationType,
            version: version,
            timestamp: timestamp,
            payload: jsonString,
            conflictStrategy: strategy
        )
    }

    /// Automatically selects default conflict resolution strategy based on entity safety requirements.
    public static func defaultStrategy(for type: OutboxEntityType) -> ConflictStrategy {
        switch type {
        case .doseEvent, .labResult, .labPanel, .biomarker, .symptomLog:
            // Medical and health events must never be silently overwritten
            return .preserveBoth
        case .protocolRevision:
            // Append-only revision records
            return .appendRecord
        case .protocolModel:
            // Protocol definitions track revisions
            return .preserveBoth
        case .userPreference, .user:
            // User preferences use Last-Write-Wins
            return .lastWriteWins
        default:
            return .lastWriteWins
        }
    }

    /// Decodes the payload JSON back into a specific domain model.
    public func decodePayload<T: Decodable>(as type: T.Type) -> T? {
        guard let json = payload, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    /// Calculates exponential backoff delay in seconds for retries (e.g. 2s, 4s, 8s, 16s...).
    public var backoffDelaySeconds: TimeInterval {
        let base: Double = 2.0
        let exponent = min(Double(retryCount), 6.0)
        return pow(base, exponent)
    }
}
