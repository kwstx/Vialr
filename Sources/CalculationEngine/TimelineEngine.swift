import Foundation
import Domain

/// High-performance calculation engine for multi-domain event normalization, sorting,
/// calendar day-grouping, filtering, and statistical analysis across the entire patient history.
public protocol TimelineEngineProtocol: Sendable {
    // MARK: - Domain Transformation Protocols
    func transform(doses: [DoseEvent]) -> [TimelineEvent]
    func transform(doseLogs: [DoseLog]) -> [TimelineEvent]
    func transform(labPanels: [LabPanel]) -> [TimelineEvent]
    func transform(measurements: [Measurement]) -> [TimelineEvent]
    func transform(protocols: [ProtocolModel], revisions: [ProtocolRevision]) -> [TimelineEvent]
    func transform(inventoryEvents: [InventoryEvent]) -> [TimelineEvent]
    func transform(reconstitutions: [ReconstitutionRecord]) -> [TimelineEvent]
    func transform(documents: [Document]) -> [TimelineEvent]
    func transform(symptoms: [SymptomLog]) -> [TimelineEvent]

    // MARK: - Aggregation & Processing
    func compileUnifiedEvents(
        doses: [DoseEvent],
        doseLogs: [DoseLog],
        labPanels: [LabPanel],
        measurements: [Measurement],
        protocols: [ProtocolModel],
        revisions: [ProtocolRevision],
        inventoryEvents: [InventoryEvent],
        reconstitutions: [ReconstitutionRecord],
        documents: [Document],
        symptoms: [SymptomLog]
    ) -> [TimelineEvent]

    func sortEvents(_ events: [TimelineEvent], ascending: Bool) -> [TimelineEvent]
    func filterEvents(_ events: [TimelineEvent], using filter: TimelineFilter) -> [TimelineEvent]
    func groupEventsByDay(_ events: [TimelineEvent], calendar: Calendar) -> [TimelineDayGroup]
    func calculateStatistics(from events: [TimelineEvent]) -> TimelineStatistics
    func processTimeline(events: [TimelineEvent], filter: TimelineFilter?, calendar: Calendar) -> TimelineResult
}

// MARK: - Concrete Implementation
public struct TimelineEngine: TimelineEngineProtocol, Sendable {

    public init() {}

    // MARK: - 1. Domain Transformations

    public func transform(doses: [DoseEvent]) -> [TimelineEvent] {
        doses.map { TimelineEvent(from: $0) }
    }

    public func transform(doseLogs: [DoseLog]) -> [TimelineEvent] {
        doseLogs.map { TimelineEvent(from: $0) }
    }

    public func transform(labPanels: [LabPanel]) -> [TimelineEvent] {
        labPanels.map { TimelineEvent(from: $0) }
    }

    public func transform(measurements: [Measurement]) -> [TimelineEvent] {
        measurements.map { TimelineEvent(from: $0) }
    }

    public func transform(protocols: [ProtocolModel], revisions: [ProtocolRevision] = []) -> [TimelineEvent] {
        var events: [TimelineEvent] = []

        for proto in protocols {
            events.append(TimelineEvent(from: proto, milestoneTitle: "Protocol Start: \(proto.name)", timestamp: proto.startDate))
            if let end = proto.endDate {
                events.append(TimelineEvent(from: proto, milestoneTitle: "Protocol Concluded: \(proto.name)", timestamp: end))
            }
        }

        for revision in revisions {
            events.append(TimelineEvent(from: revision))
        }

        return events
    }

    public func transform(inventoryEvents: [InventoryEvent]) -> [TimelineEvent] {
        inventoryEvents.map { TimelineEvent(from: $0) }
    }

    public func transform(reconstitutions: [ReconstitutionRecord]) -> [TimelineEvent] {
        reconstitutions.map { TimelineEvent(from: $0) }
    }

    public func transform(documents: [Document]) -> [TimelineEvent] {
        documents.map { TimelineEvent(from: $0) }
    }

    public func transform(symptoms: [SymptomLog]) -> [TimelineEvent] {
        symptoms.map { TimelineEvent(from: $0) }
    }

    // MARK: - 2. Unified Aggregation

    public func compileUnifiedEvents(
        doses: [DoseEvent] = [],
        doseLogs: [DoseLog] = [],
        labPanels: [LabPanel] = [],
        measurements: [Measurement] = [],
        protocols: [ProtocolModel] = [],
        revisions: [ProtocolRevision] = [],
        inventoryEvents: [InventoryEvent] = [],
        reconstitutions: [ReconstitutionRecord] = [],
        documents: [Document] = [],
        symptoms: [SymptomLog] = []
    ) -> [TimelineEvent] {
        var all: [TimelineEvent] = []

        all.append(contentsOf: transform(doses: doses))

        // Avoid duplicate dose logs if identical doseEvent id exists
        let existingDoseIds = Set(doses.map(\.id))
        let uniqueDoseLogs = doseLogs.filter { !existingDoseIds.contains($0.id) }
        all.append(contentsOf: transform(doseLogs: uniqueDoseLogs))

        all.append(contentsOf: transform(labPanels: labPanels))
        all.append(contentsOf: transform(measurements: measurements))
        all.append(contentsOf: transform(protocols: protocols, revisions: revisions))
        all.append(contentsOf: transform(inventoryEvents: inventoryEvents))
        all.append(contentsOf: transform(reconstitutions: reconstitutions))
        all.append(contentsOf: transform(documents: documents))
        all.append(contentsOf: transform(symptoms: symptoms))

        return sortEvents(all, ascending: false)
    }

    // MARK: - 3. Sorting

    public func sortEvents(_ events: [TimelineEvent], ascending: Bool = false) -> [TimelineEvent] {
        if ascending {
            return events.sorted(by: { $0.timestamp < $1.timestamp })
        } else {
            return events.sorted(by: { $0.timestamp > $1.timestamp })
        }
    }

    // MARK: - 4. Filtering

    public func filterEvents(_ events: [TimelineEvent], using filter: TimelineFilter) -> [TimelineEvent] {
        events.filter { event in
            // Category Filter
            if let categories = filter.categories, !categories.isEmpty {
                if !categories.contains(event.category) {
                    return false
                }
            }

            // Entity Type Filter
            if let entityTypes = filter.entityTypes, !entityTypes.isEmpty {
                if !entityTypes.contains(event.associatedEntityType) {
                    return false
                }
            }

            // Date Range Start
            if let start = filter.startDate {
                if event.timestamp < start {
                    return false
                }
            }

            // Date Range End
            if let end = filter.endDate {
                if event.timestamp > end {
                    return false
                }
            }

            // Highlighted Only
            if filter.highlightedOnly && !event.isHighlighted {
                return false
            }

            // Search Keyword Query
            if let query = filter.searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
                let lower = query.lowercased()
                let titleMatch = event.title.lowercased().contains(lower)
                let subtitleMatch = event.subtitle.lowercased().contains(lower)
                let detailMatch = event.detailText?.lowercased().contains(lower) ?? false
                let badgeMatch = event.badgeText?.lowercased().contains(lower) ?? false
                let metadataMatch = event.metadata.values.contains(where: { $0.lowercased().contains(lower) })

                if !titleMatch && !subtitleMatch && !detailMatch && !badgeMatch && !metadataMatch {
                    return false
                }
            }

            return true
        }
    }

    // MARK: - 5. Day Grouping

    public func groupEventsByDay(_ events: [TimelineEvent], calendar: Calendar = .current) -> [TimelineDayGroup] {
        guard !events.isEmpty else { return [] }

        // Sort events reverse-chronologically before bucketing
        let sorted = sortEvents(events, ascending: false)

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"

        // Group by day string key
        var dayBuckets: [String: (Date, [TimelineEvent])] = [:]

        for event in sorted {
            let startOfDay = calendar.startOfDay(for: event.timestamp)
            let key = dayFormatter.string(from: startOfDay)

            if var existing = dayBuckets[key] {
                existing.1.append(event)
                dayBuckets[key] = existing
            } else {
                dayBuckets[key] = (startOfDay, [event])
            }
        }

        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart

        // Build structured TimelineDayGroup objects
        var resultGroups: [TimelineDayGroup] = []

        for (dayKey, pair) in dayBuckets {
            let startOfDay = pair.0
            let dayEvents = sortEvents(pair.1, ascending: false)

            // Dynamic Day Title
            let title: String
            if calendar.isDate(startOfDay, inSameDayAs: todayStart) {
                title = "Today"
            } else if calendar.isDate(startOfDay, inSameDayAs: yesterdayStart) {
                title = "Yesterday"
            } else {
                let titleFormatter = DateFormatter()
                titleFormatter.calendar = calendar
                titleFormatter.locale = Locale.autoupdatingCurrent
                titleFormatter.dateFormat = "EEEE, MMM d"
                title = titleFormatter.string(from: startOfDay)
            }

            // Subtitle Formatter (e.g. "August 26, 2026")
            let subFormatter = DateFormatter()
            subFormatter.calendar = calendar
            subFormatter.locale = Locale.autoupdatingCurrent
            subFormatter.dateFormat = "MMMM d, yyyy"
            let subtitle = subFormatter.string(from: startOfDay)

            // Category Counts
            var counts: [TimelineCategory: Int] = [:]
            for ev in dayEvents {
                counts[ev.category, default: 0] += 1
            }

            // Summary text generation
            let summary = formatDaySummary(counts: counts, events: dayEvents)

            let group = TimelineDayGroup(
                id: dayKey,
                date: startOfDay,
                formattedDayTitle: title,
                formattedDaySubtitle: subtitle,
                events: dayEvents,
                countsByCategory: counts,
                summaryText: summary
            )

            resultGroups.append(group)
        }

        // Sort day groups in reverse chronological order (newest day first)
        return resultGroups.sorted(by: { $0.date > $1.date })
    }

    // MARK: - 6. Timeline Statistics Calculation

    public func calculateStatistics(from events: [TimelineEvent]) -> TimelineStatistics {
        var dosesTotal = 0
        var takenDoses = 0
        var missedDoses = 0
        var labPanelsCount = 0
        var abnormalLabs = 0
        var measurementsCount = 0
        var protocolChanges = 0
        var inventoryCount = 0

        for event in events {
            switch event.category {
            case .dose:
                dosesTotal += 1
                if let isTakenStr = event.metadata["isTaken"], isTakenStr == "true" {
                    takenDoses += 1
                } else if event.badgeText?.localizedCaseInsensitiveContains("Taken") == true {
                    takenDoses += 1
                } else if event.badgeText?.localizedCaseInsensitiveContains("Missed") == true {
                    missedDoses += 1
                }
            case .labPanel:
                labPanelsCount += 1
                if event.isHighlighted {
                    abnormalLabs += 1
                }
            case .measurement:
                measurementsCount += 1
            case .protocolChange, .protocolMilestone:
                protocolChanges += 1
            case .inventory:
                inventoryCount += 1
            default:
                break
            }
        }

        let adherence: Double? = dosesTotal > 0 ? (Double(takenDoses) / Double(dosesTotal)) * 100.0 : nil

        return TimelineStatistics(
            totalEventsCount: events.count,
            totalDosesCount: dosesTotal,
            takenDosesCount: takenDoses,
            missedDosesCount: missedDoses,
            totalLabPanelsCount: labPanelsCount,
            abnormalLabCount: abnormalLabs,
            totalMeasurementsCount: measurementsCount,
            totalProtocolChangesCount: protocolChanges,
            totalInventoryEventsCount: inventoryCount,
            adherenceScore: adherence
        )
    }

    // MARK: - 7. End-to-End Processing

    public func processTimeline(
        events: [TimelineEvent],
        filter: TimelineFilter? = nil,
        calendar: Calendar = .current
    ) -> TimelineResult {
        let filtered: [TimelineEvent]
        if let f = filter {
            filtered = filterEvents(events, using: f)
        } else {
            filtered = events
        }

        let sorted = sortEvents(filtered, ascending: false)
        let dayGroups = groupEventsByDay(sorted, calendar: calendar)
        let stats = calculateStatistics(from: sorted)

        let dateInterval: DateInterval?
        if let earliest = sorted.last?.timestamp, let latest = sorted.first?.timestamp {
            dateInterval = DateInterval(start: earliest, end: latest)
        } else {
            dateInterval = nil
        }

        return TimelineResult(
            dayGroups: dayGroups,
            allEvents: sorted,
            statistics: stats,
            dateInterval: dateInterval
        )
    }

    // MARK: - Internal Helpers

    private func formatDaySummary(counts: [TimelineCategory: Int], events: [TimelineEvent]) -> String {
        var parts: [String] = []

        if let doses = counts[.dose], doses > 0 {
            parts.append("\(doses) \(doses == 1 ? "Dose" : "Doses")")
        }

        if let labs = counts[.labPanel], labs > 0 {
            parts.append("\(labs) \(labs == 1 ? "Lab Draw" : "Lab Draws")")
        }

        if let metrics = counts[.measurement], metrics > 0 {
            parts.append("\(metrics) \(metrics == 1 ? "Measurement" : "Measurements")")
        }

        if let proto = counts[.protocolChange] ?? counts[.protocolMilestone], proto > 0 {
            parts.append("\(proto) Protocol \(proto == 1 ? "Milestone" : "Milestones")")
        }

        if let inv = counts[.inventory], inv > 0 {
            parts.append("\(inv) Inventory \(inv == 1 ? "Adjustment" : "Adjustments")")
        }

        if let recon = counts[.reconstitution], recon > 0 {
            parts.append("\(recon) \(recon == 1 ? "Reconstitution" : "Reconstitutions")")
        }

        if let symptoms = counts[.symptom], symptoms > 0 {
            parts.append("\(symptoms) \(symptoms == 1 ? "Symptom Log" : "Symptom Logs")")
        }

        if let docs = counts[.document], docs > 0 {
            parts.append("\(docs) \(docs == 1 ? "Document" : "Documents")")
        }

        if parts.isEmpty {
            return "\(events.count) \(events.count == 1 ? "Event" : "Events")"
        }

        return parts.joined(separator: " • ")
    }
}
