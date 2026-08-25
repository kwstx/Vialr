import Foundation

/// Represents a period during which one or more compounds are being tracked.
/// A Protocol encapsulates a start date, end date, status, notes, and associated protocol compounds.
public struct ProtocolModel: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var status: ProtocolStatus
    public var startDate: Date
    public var endDate: Date?
    public var notes: String
    public var compounds: [ProtocolCompound]
    public var goalSummary: String
    public var colorHex: String
    public var userId: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    /// Compatibility alias to support `items` access.
    public var items: [ProtocolCompound] {
        get { compounds }
        set { compounds = newValue }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        status: ProtocolStatus = .active,
        startDate: Date = Date(),
        endDate: Date? = nil,
        notes: String = "",
        compounds: [ProtocolCompound] = [],
        goalSummary: String = "",
        colorHex: String = "#10B981",
        userId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.compounds = compounds
        self.goalSummary = goalSummary
        self.colorHex = colorHex
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Overloaded initializer allowing initialization with `items:` for backwards compatibility.
    public init(
        id: UUID = UUID(),
        name: String,
        goalSummary: String = "",
        status: ProtocolStatus = .active,
        items: [ProtocolCompound] = [],
        startDate: Date = Date(),
        endDate: Date? = nil,
        notes: String = "",
        colorHex: String = "#10B981",
        userId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(
            id: id,
            name: name,
            status: status,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            compounds: items,
            goalSummary: goalSummary,
            colorHex: colorHex,
            userId: userId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Whether this protocol is currently active based on status and calendar boundaries.
    public var isCurrentlyActive: Bool {
        guard status == .active else { return false }
        let now = Date()
        if now < startDate { return false }
        if let end = endDate, now > end { return false }
        return true
    }

    /// Whether the protocol is ongoing with no specified end date.
    public var isOngoing: Bool {
        endDate == nil
    }

    /// Elapsed duration in days from start date to today (or end date if ended).
    public var elapsedDays: Int {
        let calendar = Calendar.current
        let targetEnd = endDate.map { min($0, Date()) } ?? Date()
        let components = calendar.dateComponents([.day], from: startDate, to: targetEnd)
        return max(0, components.day ?? 0)
    }

    /// Total scheduled duration in days (if end date is set).
    public var totalPlannedDays: Int? {
        guard let end = endDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: end)
        return max(1, components.day ?? 1)
    }

    /// Completion percentage (0.0 - 100.0) if end date is set.
    public var progressPercentage: Double? {
        guard let total = totalPlannedDays, total > 0 else { return nil }
        let progress = (Double(elapsedDays) / Double(total)) * 100.0
        return min(100.0, max(0.0, progress))
    }
}

// MARK: - Protocol Status
public enum ProtocolStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case active = "Active"
    case paused = "Paused"
    case completed = "Completed"
    case draft = "Draft"
    case archived = "Archived"

    public var id: String { rawValue }

    public var badgeColorHex: String {
        switch self {
        case .active: return "#10B981"
        case .paused: return "#F59E0B"
        case .completed: return "#3B82F6"
        case .draft: return "#6B7280"
        case .archived: return "#9CA3AF"
        }
    }
}
