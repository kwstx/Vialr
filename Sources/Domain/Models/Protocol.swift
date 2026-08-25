import Foundation

/// A structured protocol containing one or more compound schedules and cycle definitions.
public struct ProtocolModel: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var goalSummary: String
    public var status: ProtocolStatus
    public var items: [ProtocolItem]
    public var startDate: Date
    public var endDate: Date?
    public var notes: String
    public var colorHex: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        goalSummary: String = "",
        status: ProtocolStatus = .active,
        items: [ProtocolItem] = [],
        startDate: Date = Date(),
        endDate: Date? = nil,
        notes: String = "",
        colorHex: String = "#10B981",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.goalSummary = goalSummary
        self.status = status
        self.items = items
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum ProtocolStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case active = "Active"
    case paused = "Paused"
    case completed = "Completed"
    case draft = "Draft"

    public var id: String { rawValue }
}

/// An individual compound scheduled within a protocol.
public struct ProtocolItem: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var compoundId: UUID
    public var compoundName: String
    public var doseAmount: Double
    public var doseUnit: DoseUnit
    public var scheduleRule: ScheduleRule
    public var preferredTimeOfDay: TimeOfDay
    public var reminderTime: Date?
    public var titrationStep: TitrationRule?
    public var preferredRoute: AdministrationRoute
    public var notes: String

    public init(
        id: UUID = UUID(),
        compoundId: UUID,
        compoundName: String,
        doseAmount: Double,
        doseUnit: DoseUnit = .mcg,
        scheduleRule: ScheduleRule = .everyDay,
        preferredTimeOfDay: TimeOfDay = .morning,
        reminderTime: Date? = nil,
        titrationStep: TitrationRule? = nil,
        preferredRoute: AdministrationRoute = .subcutaneous,
        notes: String = ""
    ) {
        self.id = id
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.scheduleRule = scheduleRule
        self.preferredTimeOfDay = preferredTimeOfDay
        self.reminderTime = reminderTime
        self.titrationStep = titrationStep
        self.preferredRoute = preferredRoute
        self.notes = notes
    }
}

public enum TimeOfDay: String, Codable, Sendable, CaseIterable, Identifiable {
    case morning = "Morning (Fasted)"
    case preWorkout = "Pre-Workout"
    case postWorkout = "Post-Workout"
    case afternoon = "Afternoon"
    case evening = "Evening / Before Bed"
    case custom = "Custom Time"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .morning: return "sun.horizon.fill"
        case .preWorkout: return "figure.run"
        case .postWorkout: return "bolt.shield.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        case .custom: return "clock.fill"
        }
    }
}

/// Frequency rule for scheduling doses.
public enum ScheduleRule: Codable, Sendable, Hashable {
    case everyDay
    case everyOtherDay
    case daysOfWeek([Int]) // 1 = Sunday, 2 = Monday, etc.
    case cycle(daysOn: Int, daysOff: Int)
    case everyNDays(Int)
    case customInterval(hours: Int)
    case asNeeded

    public var description: String {
        switch self {
        case .everyDay:
            return "Daily"
        case .everyOtherDay:
            return "Every Other Day (EOD)"
        case .daysOfWeek(let days):
            let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let names = days.compactMap { $0 >= 1 && $0 <= 7 ? dayNames[$0 - 1] : nil }
            return "Weekly: " + names.joined(separator: ", ")
        case .cycle(let daysOn, let daysOff):
            return "\(daysOn) Days On / \(daysOff) Days Off"
        case .everyNDays(let n):
            return "Every \(n) Days"
        case .customInterval(let hours):
            return "Every \(hours) Hours"
        case .asNeeded:
            return "As Needed (PRN)"
        }
    }
}

/// Rule for progressive dose increases or tapers.
public struct TitrationRule: Codable, Sendable, Hashable {
    public var startDose: Double
    public var targetDose: Double
    public var stepAmount: Double
    public var stepIntervalDays: Int

    public init(startDose: Double, targetDose: Double, stepAmount: Double, stepIntervalDays: Int) {
        self.startDose = startDose
        self.targetDose = targetDose
        self.stepAmount = stepAmount
        self.stepIntervalDays = stepIntervalDays
    }
}
