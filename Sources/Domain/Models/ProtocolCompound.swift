import Foundation

/// Connects a compound to a protocol and defines the planned schedule, dose, units,
/// route, frequency, titration, reminders, and administration configuration.
public struct ProtocolCompound: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var protocolId: UUID?
    public var compoundId: UUID
    public var compoundName: String
    public var doseAmount: Double
    public var doseUnit: DoseUnit
    public var doseRangeMin: Double?
    public var doseRangeMax: Double?
    public var route: AdministrationRoute
    public var scheduleRule: ScheduleRule
    public var timesPerDay: Int
    public var preferredTimeOfDay: TimeOfDay
    public var reminderEnabled: Bool
    public var reminderTime: Date?
    public var reminderLeadTimeMinutes: Int
    public var titrationStep: TitrationRule?
    public var preferredSiteRegion: BodyRegion?
    public var foodRequirement: FoodRequirement
    public var instructions: String
    public var notes: String
    public var attachedVialId: UUID?
    public var startDate: Date?
    public var endDate: Date?
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date

    /// Compatibility accessor for `vialId`
    public var vialId: UUID? {
        get { attachedVialId }
        set { attachedVialId = newValue }
    }

    /// Compatibility accessor for `preferredRoute`
    public var preferredRoute: AdministrationRoute {
        get { route }
        set { route = newValue }
    }

    public init(
        id: UUID = UUID(),
        protocolId: UUID? = nil,
        compoundId: UUID,
        compoundName: String,
        doseAmount: Double,
        doseUnit: DoseUnit = .mcg,
        doseRangeMin: Double? = nil,
        doseRangeMax: Double? = nil,
        route: AdministrationRoute = .subcutaneous,
        scheduleRule: ScheduleRule = .everyDay,
        timesPerDay: Int = 1,
        preferredTimeOfDay: TimeOfDay = .morning,
        reminderEnabled: Bool = true,
        reminderTime: Date? = nil,
        reminderLeadTimeMinutes: Int = 15,
        titrationStep: TitrationRule? = nil,
        preferredSiteRegion: BodyRegion? = nil,
        foodRequirement: FoodRequirement = .fasted,
        instructions: String = "",
        notes: String = "",
        attachedVialId: UUID? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.protocolId = protocolId
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.doseRangeMin = doseRangeMin
        self.doseRangeMax = doseRangeMax
        self.route = route
        self.scheduleRule = scheduleRule
        self.timesPerDay = timesPerDay
        self.preferredTimeOfDay = preferredTimeOfDay
        self.reminderEnabled = reminderEnabled
        self.reminderTime = reminderTime
        self.reminderLeadTimeMinutes = reminderLeadTimeMinutes
        self.titrationStep = titrationStep
        self.preferredSiteRegion = preferredSiteRegion
        self.foodRequirement = foodRequirement
        self.instructions = instructions
        self.notes = notes
        self.attachedVialId = attachedVialId
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Backwards compatibility initializer accepting `preferredRoute:`
    public init(
        id: UUID = UUID(),
        protocolId: UUID? = nil,
        compoundId: UUID,
        compoundName: String,
        doseAmount: Double,
        doseUnit: DoseUnit = .mcg,
        doseRangeMin: Double? = nil,
        doseRangeMax: Double? = nil,
        scheduleRule: ScheduleRule = .everyDay,
        preferredTimeOfDay: TimeOfDay = .morning,
        reminderTime: Date? = nil,
        titrationStep: TitrationRule? = nil,
        preferredRoute: AdministrationRoute = .subcutaneous,
        notes: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil
    ) {
        self.init(
            id: id,
            protocolId: protocolId,
            compoundId: compoundId,
            compoundName: compoundName,
            doseAmount: doseAmount,
            doseUnit: doseUnit,
            doseRangeMin: doseRangeMin,
            doseRangeMax: doseRangeMax,
            route: preferredRoute,
            scheduleRule: scheduleRule,
            timesPerDay: 1,
            preferredTimeOfDay: preferredTimeOfDay,
            reminderEnabled: reminderTime != nil,
            reminderTime: reminderTime,
            reminderLeadTimeMinutes: 15,
            titrationStep: titrationStep,
            preferredSiteRegion: nil,
            foodRequirement: .unspecified,
            instructions: "",
            notes: notes,
            startDate: startDate,
            endDate: endDate,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    /// Calculates the effective dose amount on a given target date, taking any active titration steps into account.
    public func effectiveDoseAmount(on date: Date, relativeTo protocolStart: Date) -> Double {
        guard let titration = titrationStep else { return doseAmount }
        let calendar = Calendar.current
        let daysPassed = max(0, calendar.dateComponents([.day], from: protocolStart, to: date).day ?? 0)
        guard titration.stepIntervalDays > 0 else { return titration.targetDose }

        let stepsCompleted = daysPassed / titration.stepIntervalDays
        let calculated = titration.startDose + (Double(stepsCompleted) * titration.stepAmount)

        if titration.stepAmount >= 0 {
            return min(titration.targetDose, calculated)
        } else {
            return max(titration.targetDose, calculated)
        }
    }

    /// Determines if a dose is scheduled on a given target date based on the schedule rule and protocol start date.
    public func isScheduled(on targetDate: Date, protocolStart: Date) -> Bool {
        guard isActive else { return false }
        let calendar = Calendar.current

        if let start = startDate, targetDate < calendar.startOfDay(for: start) { return false }
        if let end = endDate, targetDate > calendar.startOfDay(for: end) { return false }

        let targetDayStart = calendar.startOfDay(for: targetDate)
        let protocolDayStart = calendar.startOfDay(for: protocolStart)

        let daysFromStart = calendar.dateComponents([.day], from: protocolDayStart, to: targetDayStart).day ?? 0
        guard daysFromStart >= 0 else { return false }

        switch scheduleRule {
        case .everyDay:
            return true

        case .everyOtherDay:
            return daysFromStart % 2 == 0

        case .daysOfWeek(let days):
            let weekday = calendar.component(.weekday, from: targetDate) // 1 = Sun, 2 = Mon ...
            return days.contains(weekday)

        case .cycle(let daysOn, let daysOff):
            let cycleLength = daysOn + daysOff
            guard cycleLength > 0 else { return true }
            let dayInCycle = daysFromStart % cycleLength
            return dayInCycle < daysOn

        case .everyNDays(let n):
            guard n > 0 else { return true }
            return daysFromStart % n == 0

        case .customInterval:
            return true

        case .asNeeded:
            return false
        }
    }

    /// Formatted description of the planned dose and route.
    public var summaryDescription: String {
        let doseStr = String(format: doseAmount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", doseAmount)
        return "\(compoundName) \(doseStr) \(doseUnit.rawValue) • \(route.shortName) • \(scheduleRule.description)"
    }
}

/// Backwards compatibility alias for `ProtocolCompound`.
public typealias ProtocolItem = ProtocolCompound

// MARK: - Food Requirement
public enum FoodRequirement: String, Codable, Sendable, CaseIterable, Identifiable {
    case fasted = "Fasted (Empty Stomach)"
    case withFood = "With Food / Meal"
    case beforeMeal = "30 mins Before Meal"
    case afterMeal = "After Meal"
    case unspecified = "No Food Requirement"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .fasted: return "fork.knife.circle"
        case .withFood: return "fork.knife"
        case .beforeMeal: return "clock.arrow.circlepath"
        case .afterMeal: return "checkmark.seal"
        case .unspecified: return "circle.dashed"
        }
    }
}

// MARK: - Time of Day
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

// MARK: - Schedule Rule
/// Frequency rule for scheduling doses within a protocol.
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

// MARK: - Titration Rule
/// Rule for progressive dose increases, tapers, or titration schedules.
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

