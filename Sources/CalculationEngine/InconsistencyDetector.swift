import Foundation
import Domain

/// Intelligent safety rules and anomaly detection for dosing entries.
/// Serves as a domain adapter bridging legacy calls to the centralized `ValidationEngine`.
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

        public init(from issue: ValidationIssue) {
            self.id = issue.id
            switch issue.severity {
            case .blockingError:
                self.severity = .critical
            case .warning:
                self.severity = .warning
            case .info:
                self.severity = .info
            }
            self.title = issue.title
            self.explanation = issue.explanation
            self.recommendation = issue.suggestedFix ?? "Verify dose parameters before confirming."
        }
    }

    public enum WarningSeverity: String, Codable, Sendable {
        case warning = "Warning"
        case critical = "Critical Alert"
        case info = "Notice"
    }

    private let validationEngine: ValidationEngine

    public init(validationEngine: ValidationEngine = ValidationEngine()) {
        self.validationEngine = validationEngine
    }

    /// Evaluates a candidate dose log against compound rules, vial state, and recent history.
    public func evaluateDoseEntry(
        candidate: DoseLog,
        compound: Compound?,
        recentLogs: [DoseLog]
    ) -> [SafetyWarning] {
        let result = validationEngine.validateDoseEntry(
            candidate: candidate,
            compound: compound,
            recentLogs: recentLogs,
            attachedVial: nil,
            activeProtocol: nil,
            recentSiteEvents: nil,
            referenceDate: Date()
        )

        return result.issues.map { SafetyWarning(from: $0) }
    }
}

