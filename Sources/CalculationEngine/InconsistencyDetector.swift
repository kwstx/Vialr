import Foundation
import Domain

/// Intelligent safety rules and anomaly detection for dosing entries.
public struct InconsistencyDetector: Sendable {

    public struct SafetyWarning: Identifiable, Sendable, Hashable {
        public let id: UUID
        public let severity: WarningSeverity
        public let title: String
        public let explanation: String
        public let recommendation: String

        public init(
            id: UUID = UUID(),
            severity: WarningSeverity,
            title: String,
            explanation: String,
            recommendation: String
        ) {
            self.id = id
            self.severity = severity
            self.title = title
            self.explanation = explanation
            self.recommendation = recommendation
        }
    }

    public enum WarningSeverity: String, Codable, Sendable {
        case warning = "Warning"
        case critical = "Critical Alert"
        case info = "Notice"
    }

    public init() {}

    /// Evaluates a candidate dose log against compound rules and recent history.
    public func evaluateDoseEntry(
        candidate: DoseLog,
        compound: Compound?,
        recentLogs: [DoseLog]
    ) -> [SafetyWarning] {
        var warnings: [SafetyWarning] = []

        // 1. High Dose Outlier Check (>3x typical dose)
        if let typical = compound?.typicalDose, typical > 0 {
            if candidate.doseAmount > typical * 3.0 {
                warnings.append(
                    SafetyWarning(
                        severity: .warning,
                        title: "Unusually High Dose Detected",
                        explanation: "You entered \(candidate.doseAmount) \(candidate.doseUnit.rawValue), which is more than 3x the standard reference dose of \(typical) \(candidate.doseUnit.rawValue).",
                        recommendation: "Please verify your decimal place and syringe unit calculation before injecting."
                    )
                )
            }
        }

        // 2. Minimum Dosing Interval Check
        let candidateDate = candidate.loggedDate ?? candidate.scheduledDate
        let sameCompoundLogs = recentLogs
            .filter { $0.compoundId == candidate.compoundId && $0.id != candidate.id && $0.status == .taken }
            .sorted(by: { ($0.loggedDate ?? $0.scheduledDate) > ($1.loggedDate ?? $1.scheduledDate) })

        if let lastDose = sameCompoundLogs.first {
            let lastDate = lastDose.loggedDate ?? lastDose.scheduledDate
            let intervalHours = abs(candidateDate.timeIntervalSince(lastDate)) / 3600.0

            // If dose is taken within 4 hours for non-insulin/daily compounds
            if intervalHours < 4.0 {
                warnings.append(
                    SafetyWarning(
                        severity: .critical,
                        title: "Potential Double-Dose Detected",
                        explanation: "A dose of \(candidate.compoundName) was already logged \(String(format: "%.1f", intervalHours)) hours ago.",
                        recommendation: "Ensure you are not accidentally logging or taking a duplicate dose."
                    )
                )
            }
        }

        return warnings
    }
}
