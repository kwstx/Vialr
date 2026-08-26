import Foundation
import Domain

// MARK: - Validation Severity

/// Classification of validation findings by operational urgency and blocking behavior.
public enum ValidationSeverity: String, Codable, Sendable, CaseIterable, Identifiable, Comparable {
    /// Informational notices, non-critical observations, or helpful suggestions. Does not impede saving or execution.
    case info = "Notice"
    
    /// Unusual data patterns, statistical outliers, unexpected intervals, or potential data entry mistakes.
    /// Explains what is unusual without making presumptuous clinical claims. Does not impede saving or execution.
    case warning = "Warning"
    
    /// Hard structural violations, missing mandatory fields, physical impossibilities, or relational corruption.
    /// Completely blocks persistence and execution.
    case blockingError = "Blocking Error"

    public var id: String { rawValue }

    public var isBlocking: Bool {
        self == .blockingError
    }

    public var sortOrder: Int {
        switch self {
        case .blockingError: return 0
        case .warning: return 1
        case .info: return 2
        }
    }

    public static func < (lhs: ValidationSeverity, rhs: ValidationSeverity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Validation Category

/// Functional categorization of issues detected across the Vialr system.
public enum ValidationCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Unit dimension mismatches, incompatible units (e.g. volume used for mass), missing biological activity conversion.
    case inconsistentUnits = "Inconsistent Units"
    
    /// Mandatory entity properties or relational foreign keys that are omitted, empty, or zero.
    case missingRequiredField = "Missing Required Field"
    
    /// Rapid repeat events logged within an abnormal time window, duplicate IDs, or redundant submissions.
    case unexpectedDuplicate = "Unexpected Duplicate"
    
    /// Vial volume/mass overdraw, draw from depleted/unopened vials, stock level contradictions, or compound mismatch.
    case inventoryDiscrepancy = "Inventory Discrepancy"
    
    /// Expired vial inventory, post-reconstitution freshness window exceeded, or temporal record date inversions.
    case expiredRecord = "Expired Record"
    
    /// Dosing on protocol rest/off-days, overlapping active protocols with identical compounds, or inverted protocol date ranges.
    case scheduleConflict = "Schedule Conflict"
    
    /// Biomarkers, vitals, or measurements outside possible physiological limits (e.g. Diastolic >= Systolic BP, sleep > 24h).
    case physiologicalRange = "Physiological Range Anomaly"
    
    /// Dosage amounts deviating significantly (e.g. >3x, >10x, or <0.01x) from reference typical dose without being syntactically invalid.
    case outlierDose = "Dosage Outlier"
    
    /// Route incompatibility with selected injection site, non-injectable routes given injection sites, or consecutive site overuse.
    case anatomicalRouteMismatch = "Anatomical Route Mismatch"
    
    /// Structural data corruption such as NaN, Infinite numbers, malformed identifiers, or corrupted calendar components.
    case dataIntegrity = "Data Integrity"
    
    /// General catch-all domain validation rules.
    case general = "General"

    public var id: String { rawValue }
}

// MARK: - Validation Issue

/// A discrete finding emitted by the `ValidationEngine`.
public struct ValidationIssue: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let severity: ValidationSeverity
    public let category: ValidationCategory
    public let field: String?
    public let title: String
    public let explanation: String
    public let suggestedFix: String?
    public let contextData: [String: String]

    public init(
        id: UUID = UUID(),
        severity: ValidationSeverity,
        category: ValidationCategory,
        field: String? = nil,
        title: String,
        explanation: String,
        suggestedFix: String? = nil,
        contextData: [String: String] = [:]
    ) {
        self.id = id
        self.severity = severity
        self.category = category
        self.field = field
        self.title = title
        self.explanation = explanation
        self.suggestedFix = suggestedFix
        self.contextData = contextData
    }

    /// Convenience factory for a blocking error.
    public static func blockingError(
        category: ValidationCategory,
        field: String? = nil,
        title: String,
        explanation: String,
        suggestedFix: String? = nil,
        contextData: [String: String] = [:]
    ) -> ValidationIssue {
        ValidationIssue(
            severity: .blockingError,
            category: category,
            field: field,
            title: title,
            explanation: explanation,
            suggestedFix: suggestedFix,
            contextData: contextData
        )
    }

    /// Convenience factory for a warning that neutrally describes what is unusual.
    public static func warning(
        category: ValidationCategory,
        field: String? = nil,
        title: String,
        explanation: String,
        suggestedFix: String? = nil,
        contextData: [String: String] = [:]
    ) -> ValidationIssue {
        ValidationIssue(
            severity: .warning,
            category: category,
            field: field,
            title: title,
            explanation: explanation,
            suggestedFix: suggestedFix,
            contextData: contextData
        )
    }

    /// Convenience factory for an informational notice.
    public static func info(
        category: ValidationCategory,
        field: String? = nil,
        title: String,
        explanation: String,
        suggestedFix: String? = nil,
        contextData: [String: String] = [:]
    ) -> ValidationIssue {
        ValidationIssue(
            severity: .info,
            category: category,
            field: field,
            title: title,
            explanation: explanation,
            suggestedFix: suggestedFix,
            contextData: contextData
        )
    }
}

// MARK: - Validation Result

/// Comprehensive evaluation result aggregate returned by all validation engine queries.
public struct ValidationResult: Sendable, Codable, Hashable {
    public let issues: [ValidationIssue]

    public init(issues: [ValidationIssue] = []) {
        self.issues = issues.sorted(by: { $0.severity < $1.severity })
    }

    /// True if there are zero blocking errors. Warnings and informational notices do not prevent validity.
    public var isValid: Bool {
        blockingErrors.isEmpty
    }

    /// All issues classified as blocking errors.
    public var blockingErrors: [ValidationIssue] {
        issues.filter { $0.severity == .blockingError }
    }

    /// All issues classified as warnings.
    public var warnings: [ValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    /// All issues classified as informational notices.
    public var informationalMessages: [ValidationIssue] {
        issues.filter { $0.severity == .info }
    }

    public var hasBlockingErrors: Bool {
        !blockingErrors.isEmpty
    }

    public var hasWarnings: Bool {
        !warnings.isEmpty
    }

    public var hasInformational: Bool {
        !informationalMessages.isEmpty
    }

    /// Filters issues by targeted field name.
    public func issues(for field: String) -> [ValidationIssue] {
        issues.filter { $0.field == field }
    }

    /// Filters blocking errors by targeted field name.
    public func blockingErrors(for field: String) -> [ValidationIssue] {
        blockingErrors.filter { $0.field == field }
    }

    /// Filters warnings by targeted field name.
    public func warnings(for field: String) -> [ValidationIssue] {
        warnings.filter { $0.field == field }
    }

    /// Merges this result with another validation result.
    public func merged(with other: ValidationResult) -> ValidationResult {
        ValidationResult(issues: self.issues + other.issues)
    }

    /// Throws a `ValidationError` if any blocking errors exist.
    public func throwIfInvalid() throws {
        if hasBlockingErrors {
            throw ValidationError(blockingIssues: blockingErrors)
        }
    }

    /// Single valid static instance with no issues.
    public static let valid = ValidationResult(issues: [])
}

// MARK: - Validation Error

/// Concrete Error thrown when one or more blocking errors prevent an operation.
public struct ValidationError: Error, LocalizedError, CustomStringConvertible, Sendable {
    public let blockingIssues: [ValidationIssue]

    public init(blockingIssues: [ValidationIssue]) {
        self.blockingIssues = blockingIssues
    }

    public var errorDescription: String? {
        if blockingIssues.isEmpty {
            return "Validation failed."
        }
        if blockingIssues.count == 1, let first = blockingIssues.first {
            return "\(first.title): \(first.explanation)"
        }
        let list = blockingIssues.map { "• \($0.title): \($0.explanation)" }.joined(separator: "\n")
        return "Validation failed with \(blockingIssues.count) blocking errors:\n\(list)"
    }

    public var description: String {
        errorDescription ?? "ValidationError"
    }
}
