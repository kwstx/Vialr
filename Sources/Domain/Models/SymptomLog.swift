import Foundation

/// Represents a subjective outcome, symptom, or quality of life assessment.
public struct SymptomLog: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var timestamp: Date
    public var energyLevel: Int // 1 to 10
    public var sleepQuality: Int // 1 to 10
    public var recoveryScore: Int // 1 to 10
    public var moodScore: Int // 1 to 10
    public var appetiteScore: Int? // 1 to 10
    public var painScore: Int? // 0 to 10
    public var sideEffects: [String]
    public var notes: String
    public var associatedProtocolId: UUID?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        energyLevel: Int = 7,
        sleepQuality: Int = 8,
        recoveryScore: Int = 8,
        moodScore: Int = 8,
        appetiteScore: Int? = nil,
        painScore: Int? = nil,
        sideEffects: [String] = [],
        notes: String = "",
        associatedProtocolId: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.energyLevel = energyLevel
        self.sleepQuality = sleepQuality
        self.recoveryScore = recoveryScore
        self.moodScore = moodScore
        self.appetiteScore = appetiteScore
        self.painScore = painScore
        self.sideEffects = sideEffects
        self.notes = notes
        self.associatedProtocolId = associatedProtocolId
    }

    /// Overall composite subjective well-being score from 0 to 100.
    public var overallWellbeingScore: Double {
        let components: [Int] = [energyLevel, sleepQuality, recoveryScore, moodScore]
        let avg = Double(components.reduce(0, +)) / Double(components.count)
        return avg * 10.0
    }
}
