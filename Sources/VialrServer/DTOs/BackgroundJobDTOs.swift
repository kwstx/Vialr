import Vapor
import Foundation
import Domain

// MARK: - Background Job DTO
public struct BackgroundJobDTO: Content, Sendable {
    public let id: UUID
    public let userId: UUID
    public let jobType: String
    public let status: String
    public let progress: Double
    public let formattedProgress: String
    public let stepDescription: String
    public let payloadJson: String?
    public let resultJson: String?
    public let errorMessage: String?
    public let retryCount: Int
    public let maxRetries: Int
    public let createdAt: Date?
    public let startedAt: Date?
    public let completedAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        userId: UUID,
        jobType: String,
        status: String,
        progress: Double,
        stepDescription: String,
        payloadJson: String? = nil,
        resultJson: String? = nil,
        errorMessage: String? = nil,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        createdAt: Date? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.jobType = jobType
        self.status = status
        self.progress = progress
        self.formattedProgress = "\(Int(progress * 100))%"
        self.stepDescription = stepDescription
        self.payloadJson = payloadJson
        self.resultJson = resultJson
        self.errorMessage = errorMessage
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }

    public init(from entity: BackgroundJobEntity) {
        self.id = entity.id ?? UUID()
        self.userId = entity.$user.id
        self.jobType = entity.jobType
        self.status = entity.status
        self.progress = entity.progress
        self.formattedProgress = "\(Int(entity.progress * 100))%"
        self.stepDescription = entity.stepDescription
        self.payloadJson = entity.payloadJson
        self.resultJson = entity.resultJson
        self.errorMessage = entity.errorMessage
        self.retryCount = entity.retryCount
        self.maxRetries = entity.maxRetries
        self.createdAt = entity.createdAt
        self.startedAt = entity.startedAt
        self.completedAt = entity.completedAt
        self.updatedAt = entity.updatedAt
    }
}

// MARK: - Enqueue Job Request
public struct CreateBackgroundJobRequestDTO: Content, Sendable {
    public let jobType: String
    public let payloadJson: String?
    public let maxRetries: Int?

    public init(jobType: String, payloadJson: String? = nil, maxRetries: Int? = 3) {
        self.jobType = jobType
        self.payloadJson = payloadJson
        self.maxRetries = maxRetries
    }
}

// MARK: - Filter Query DTO
public struct BackgroundJobListFilterQueryDTO: Content, Sendable {
    public let status: String?
    public let jobType: String?
    public let limit: Int?
}

// MARK: - Generic Action / Status Response
public struct BackgroundJobActionResponseDTO: Content, Sendable {
    public let job: BackgroundJobDTO
    public let message: String

    public init(job: BackgroundJobDTO, message: String) {
        self.job = job
        self.message = message
    }
}
