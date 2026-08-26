import SwiftUI
import Observation
import Domain
import Data
import CalculationEngine

public enum TimelineTimeRangeFilter: String, CaseIterable, Identifiable, Sendable {
    case allTime = "All Time"
    case last30Days = "30 Days"
    case last90Days = "90 Days"
    case thisYear = "This Year"

    public var id: String { rawValue }

    public func dateInterval(relativeTo date: Date = Date(), calendar: Calendar = .current) -> (start: Date?, end: Date?) {
        switch self {
        case .allTime:
            return (nil, nil)
        case .last30Days:
            return (calendar.date(byAdding: .day, value: -30, to: date), date)
        case .last90Days:
            return (calendar.date(byAdding: .day, value: -90, to: date), date)
        case .thisYear:
            let components = calendar.dateComponents([.year], from: date)
            let startOfYear = calendar.date(from: components)
            return (startOfYear, date)
        }
    }
}

@Observable
public final class TimelineViewModel: @unchecked Sendable {
    // MARK: - Injected Dependencies
    public let timelineService: TimelineServiceProtocol

    // MARK: - Observable State
    public var dayGroups: [TimelineDayGroup] = []
    public var allEvents: [TimelineEvent] = []
    public var statistics: TimelineStatistics = TimelineStatistics()
    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    // Filter & Search Controls
    public var selectedCategory: TimelineCategory? = nil
    public var searchQuery: String = ""
    public var selectedTimeRange: TimelineTimeRangeFilter = .allTime
    public var showHighlightedOnly: Bool = false

    // Inspection Modal
    public var selectedEvent: TimelineEvent? = nil

    // MARK: - Initializer
    public init(timelineService: TimelineServiceProtocol) {
        self.timelineService = timelineService
    }

    // MARK: - Data Loading & Filtering Pipeline

    @MainActor
    public func loadTimelineData() async {
        isLoading = true
        errorMessage = nil

        do {
            let (start, end) = selectedTimeRange.dateInterval()
            let categories: Set<TimelineCategory>? = selectedCategory.map { [$0] }

            let filter = TimelineFilter(
                categories: categories,
                startDate: start,
                endDate: end,
                searchQuery: searchQuery.isEmpty ? nil : searchQuery,
                highlightedOnly: showHighlightedOnly
            )

            let result = try await timelineService.fetchTimeline(filter: filter)
            self.dayGroups = result.dayGroups
            self.allEvents = result.allEvents
            self.statistics = result.statistics
            self.isLoading = false
        } catch {
            self.errorMessage = "Failed to load timeline history: \(error.localizedDescription)"
            self.isLoading = false
        }
    }

    // MARK: - Filter Actions

    @MainActor
    public func selectCategory(_ category: TimelineCategory?) {
        self.selectedCategory = category
        Task {
            await loadTimelineData()
        }
    }

    @MainActor
    public func updateSearchQuery(_ query: String) {
        self.searchQuery = query
        Task {
            await loadTimelineData()
        }
    }

    @MainActor
    public func selectTimeRange(_ range: TimelineTimeRangeFilter) {
        self.selectedTimeRange = range
        Task {
            await loadTimelineData()
        }
    }

    @MainActor
    public func toggleHighlightedOnly() {
        self.showHighlightedOnly.toggle()
        Task {
            await loadTimelineData()
        }
    }

    @MainActor
    public func selectEvent(_ event: TimelineEvent?) {
        self.selectedEvent = event
    }

    @MainActor
    public func refresh() async {
        await loadTimelineData()
    }
}
