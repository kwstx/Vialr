import Vapor
import Foundation

// MARK: - Outbox Sync DTOs

public struct OutboxOperationDTO: Content {
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
}

public struct OutboxPushRequestDTO: Content {
    public let operations: [OutboxOperationDTO]

    public init(operations: [OutboxOperationDTO]) {
        self.operations = operations
    }
}

public struct OutboxOperationResultDTO: Content {
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

public struct OutboxPushResponseDTO: Content {
    public let serverTimestamp: Date
    public let results: [OutboxOperationResultDTO]

    public init(serverTimestamp: Date = Date(), results: [OutboxOperationResultDTO] = []) {
        self.serverTimestamp = serverTimestamp
        self.results = results
    }
}
