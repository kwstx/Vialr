import Foundation

/// Represents a specific quantitative or qualitative health metric evaluated against a protocol.
/// Tracks baseline values, targets, latest progress, and clinical efficacy over the course of a tracking period.
public struct OutcomeMetric: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var protocolId: UUID
    public var userId: UUID?
    public var name: String
    public var category: OutcomeMetricCategory
    
    // MARK: - Baseline & Target Goals
    public var baselineValue: Double
    public var baselineDate: Date
    public var targetValue: Double
    public var targetDirection: TargetDirection
    public var unit: String
    
    // MARK: - Current Evaluation State
    public var currentValue: Double?
    public var latestMeasurementDate: Date?
    public var priority: OutcomePriority
    public var targetDate: Date?
    public var evaluationNotes: String
    
    // MARK: - Domain Linkages
    public var linkedMeasurementType: MeasurementType?
    public var linkedBiomarkerName: String?
    
    public var createdAt: Date
    public var updatedAt: Date

    // MARK: - Primary Initializer
    public init(
        id: UUID = UUID(),
        protocolId: UUID,
        userId: UUID? = nil,
        name: String,
        category: OutcomeMetricCategory = .bodyComposition,
        baselineValue: Double,
        baselineDate: Date = Date(),
        targetValue: Double,
        targetDirection: TargetDirection = .decrease,
        unit: String,
        currentValue: Double? = nil,
        latestMeasurementDate: Date? = nil,
        priority: OutcomePriority = .primary,
        targetDate: Date? = nil,
        linkedMeasurementType: MeasurementType? = nil,
        linkedBiomarkerName: String? = nil,
        evaluationNotes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.protocolId = protocolId
        self.userId = userId
        self.name = name
        self.category = category
        self.baselineValue = baselineValue
        self.baselineDate = baselineDate
        self.targetValue = targetValue
        self.targetDirection = targetDirection
        self.unit = unit
        self.currentValue = currentValue ?? baselineValue
        self.latestMeasurementDate = latestMeasurementDate ?? baselineDate
        self.priority = priority
        self.targetDate = targetDate
        self.linkedMeasurementType = linkedMeasurementType
        self.linkedBiomarkerName = linkedBiomarkerName
        self.evaluationNotes = evaluationNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Progress & Efficacy Calculations

    /// Absolute change from baseline (Current - Baseline).
    public var deltaFromBaseline: Double? {
        guard let current = currentValue else { return nil }
        return current - baselineValue
    }

    /// Percentage change from baseline ((Current - Baseline) / Baseline * 100).
    public var percentageChangeFromBaseline: Double? {
        guard let delta = deltaFromBaseline, baselineValue != 0 else { return nil }
        return (delta / abs(baselineValue)) * 100.0
    }

    /// Total progress toward target as a percentage from 0.0% to 100.0%+
    public var progressPercentage: Double {
        guard let current = currentValue else { return 0.0 }
        let totalDeltaNeeded = targetValue - baselineValue
        guard totalDeltaNeeded != 0 else {
            return isTargetAchieved ? 100.0 : 0.0
        }
        let deltaAchieved = current - baselineValue
        let progress = (deltaAchieved / totalDeltaNeeded) * 100.0
        return max(0.0, progress)
    }

    /// Evaluates whether the objective target has been satisfied.
    public var isTargetAchieved: Bool {
        guard let current = currentValue else { return false }
        switch targetDirection {
        case .decrease:
            return current <= targetValue
        case .increase:
            return current >= targetValue
        case .maintain:
            return abs(current - targetValue) <= (abs(targetValue) * 0.05) // within 5% tolerance
        }
    }

    /// Clinical evaluation status of this metric against the protocol.
    public var evaluationStatus: MetricEvaluationStatus {
        guard let current = currentValue else { return .insufficientData }
        if isTargetAchieved {
            return .targetReached
        }
        
        guard let delta = deltaFromBaseline else { return .insufficientData }
        if delta == 0 {
            return .stalled
        }

        switch targetDirection {
        case .decrease:
            return delta < 0 ? .onTrack : .regressing
        case .increase:
            return delta > 0 ? .onTrack : .regressing
        case .maintain:
            return abs(delta) <= (abs(baselineValue) * 0.05) ? .onTrack : .regressing
        }
    }

    /// Formatted progress summary (e.g. "195.0 -> 182.4 lbs (-12.6 lbs / 63% to goal)")
    public var summaryProgressText: String {
        guard let current = currentValue, let delta = deltaFromBaseline else {
            return "Baseline: \(baselineValue) \(unit)"
        }
        let deltaSign = delta > 0 ? "+" : ""
        let deltaStr = String(format: "%.1f", delta)
        let progStr = String(format: "%.0f", progressPercentage)
        return "\(baselineValue) → \(current) \(unit) (\(deltaSign)\(deltaStr) \(unit) • \(progStr)% achieved)"
    }
}

// MARK: - Supporting Enums

public enum OutcomeMetricCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case bodyComposition = "Body Composition"
    case bloodBiomarker = "Blood Biomarker / Lab"
    case cardiovascularVital = "Cardiovascular & Vitals"
    case subjectiveWellbeing = "Subjective & Well-Being"
    case athleticPerformance = "Athletic Performance"
    case custom = "Custom Outcome"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .bodyComposition: return "scalemass.fill"
        case .bloodBiomarker: return "testtube.2"
        case .cardiovascularVital: return "heart.fill"
        case .subjectiveWellbeing: return "face.smiling.inverse"
        case .athleticPerformance: return "figure.run"
        case .custom: return "chart.xyaxis.line"
        }
    }
}

public enum TargetDirection: String, Codable, Sendable, CaseIterable, Identifiable {
    case decrease = "Decrease / Reduce"
    case increase = "Increase / Elevate"
    case maintain = "Maintain / Stable"

    public var id: String { rawValue }
}

public enum OutcomePriority: String, Codable, Sendable, CaseIterable, Identifiable {
    case primary = "Primary Goal"
    case secondary = "Secondary Goal"
    case exploratory = "Exploratory / Monitoring"

    public var id: String { rawValue }

    public var badgeColorHex: String {
        switch self {
        case .primary: return "#3B82F6"
        case .secondary: return "#8B5CF6"
        case .exploratory: return "#6B7280"
        }
    }
}

public enum MetricEvaluationStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case targetReached = "Target Reached"
    case onTrack = "On Track"
    case stalled = "Stalled / No Change"
    case regressing = "Regressing"
    case insufficientData = "Awaiting Data"

    public var id: String { rawValue }

    public var colorHex: String {
        switch self {
        case .targetReached: return "#10B981"
        case .onTrack: return "#3B82F6"
        case .stalled: return "#F59E0B"
        case .regressing: return "#EF4444"
        case .insufficientData: return "#9CA3AF"
        }
    }

    public var iconName: String {
        switch self {
        case .targetReached: return "checkmark.seal.fill"
        case .onTrack: return "arrow.up.right.circle.fill"
        case .stalled: return "pause.circle.fill"
        case .regressing: return "arrow.down.right.circle.fill"
        case .insufficientData: return "clock.badge.questionmark"
        }
    }
}
