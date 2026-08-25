import Foundation

/// Represents a single recorded or scheduled dose event.
public struct DoseLog: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var protocolId: UUID?
    public var protocolItemId: UUID?
    public var compoundId: UUID
    public var compoundName: String
    public var scheduledDate: Date
    public var loggedDate: Date?
    public var doseAmount: Double
    public var doseUnit: DoseUnit
    public var status: DoseStatus
    public var injectionSiteId: String?
    public var injectionSiteName: String?
    public var vialId: UUID?
    public var administrationRoute: AdministrationRoute
    public var notes: String
    public var skippedReason: String?
    public var subjectiveEffectScore: Int? // 1-10
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        protocolId: UUID? = nil,
        protocolItemId: UUID? = nil,
        compoundId: UUID,
        compoundName: String,
        scheduledDate: Date,
        loggedDate: Date? = nil,
        doseAmount: Double,
        doseUnit: DoseUnit = .mcg,
        status: DoseStatus = .scheduled,
        injectionSiteId: String? = nil,
        injectionSiteName: String? = nil,
        vialId: UUID? = nil,
        administrationRoute: AdministrationRoute = .subcutaneous,
        notes: String = "",
        skippedReason: String? = nil,
        subjectiveEffectScore: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.protocolId = protocolId
        self.protocolItemId = protocolItemId
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.scheduledDate = scheduledDate
        self.loggedDate = loggedDate
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.status = status
        self.injectionSiteId = injectionSiteId
        self.injectionSiteName = injectionSiteName
        self.vialId = vialId
        self.administrationRoute = administrationRoute
        self.notes = notes
        self.skippedReason = skippedReason
        self.subjectiveEffectScore = subjectiveEffectScore
        self.createdAt = createdAt
    }
}

public enum DoseStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case scheduled = "Scheduled"
    case taken = "Taken"
    case skipped = "Skipped"
    case missed = "Missed"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .scheduled: return "clock"
        case .taken: return "checkmark.circle.fill"
        case .skipped: return "slash.circle"
        case .missed: return "exclamationmark.circle.fill"
        }
    }
}
