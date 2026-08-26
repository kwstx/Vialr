import Foundation
import Domain
import CalculationEngine

/// Public interface for multi-domain longitudinal timeline querying, day-group aggregation, and event retrieval.
public protocol TimelineServiceProtocol: Sendable {
    /// Retrieves a complete, fully processed timeline stream organized into calendar day groups.
    func fetchTimeline(filter: TimelineFilter?) async throws -> TimelineResult

    /// Retrieves pre-grouped day sections matching the optional filter criteria.
    func fetchDayGroups(filter: TimelineFilter?) async throws -> [TimelineDayGroup]

    /// Retrieves all raw timeline events matching the filter, sorted chronologically.
    func fetchAllEvents(filter: TimelineFilter?) async throws -> [TimelineEvent]

    /// Computes longitudinal summary statistics across the active timeline.
    func fetchStatistics(filter: TimelineFilter?) async throws -> TimelineStatistics

    /// Looks up a specific event across all underlying domains.
    func fetchEvent(byId id: UUID) async throws -> TimelineEvent?

    /// Fetches the most recent timeline events up to a given limit.
    func fetchRecentEvents(limit: Int) async throws -> [TimelineEvent]
}

/// Thread-safe service aggregating events across all health and protocol domains.
public final class TimelineService: TimelineServiceProtocol, @unchecked Sendable {

    private let doseRepo: DoseLogRepositoryProtocol
    private let labPanelRepo: LabPanelRepositoryProtocol
    private let measurementRepo: MeasurementRepositoryProtocol
    private let protocolRepo: ProtocolRepositoryProtocol
    private let protocolRevisionRepo: ProtocolRevisionRepositoryProtocol?
    private let inventoryEventRepo: InventoryEventRepositoryProtocol
    private let reconstitutionRepo: ReconstitutionRecordRepositoryProtocol
    private let symptomRepo: SymptomRepositoryProtocol
    private let documentRepo: DocumentRepositoryProtocol
    private let engine: TimelineEngineProtocol

    public init(
        doseRepo: DoseLogRepositoryProtocol,
        labPanelRepo: LabPanelRepositoryProtocol,
        measurementRepo: MeasurementRepositoryProtocol,
        protocolRepo: ProtocolRepositoryProtocol,
        protocolRevisionRepo: ProtocolRevisionRepositoryProtocol? = nil,
        inventoryEventRepo: InventoryEventRepositoryProtocol,
        reconstitutionRepo: ReconstitutionRecordRepositoryProtocol,
        symptomRepo: SymptomRepositoryProtocol,
        documentRepo: DocumentRepositoryProtocol,
        engine: TimelineEngineProtocol = TimelineEngine()
    ) {
        self.doseRepo = doseRepo
        self.labPanelRepo = labPanelRepo
        self.measurementRepo = measurementRepo
        self.protocolRepo = protocolRepo
        self.protocolRevisionRepo = protocolRevisionRepo
        self.inventoryEventRepo = inventoryEventRepo
        self.reconstitutionRepo = reconstitutionRepo
        self.symptomRepo = symptomRepo
        self.documentRepo = documentRepo
        self.engine = engine
    }

    // MARK: - 1. Fetch Processed Timeline Result

    public func fetchTimeline(filter: TimelineFilter? = nil) async throws -> TimelineResult {
        let events = try await fetchRawUnifiedEvents()
        return engine.processTimeline(events: events, filter: filter, calendar: .current)
    }

    // MARK: - 2. Fetch Day Groups

    public func fetchDayGroups(filter: TimelineFilter? = nil) async throws -> [TimelineDayGroup] {
        let result = try await fetchTimeline(filter: filter)
        return result.dayGroups
    }

    // MARK: - 3. Fetch All Events

    public func fetchAllEvents(filter: TimelineFilter? = nil) async throws -> [TimelineEvent] {
        let result = try await fetchTimeline(filter: filter)
        return result.allEvents
    }

    // MARK: - 4. Fetch Statistics

    public func fetchStatistics(filter: TimelineFilter? = nil) async throws -> TimelineStatistics {
        let result = try await fetchTimeline(filter: filter)
        return result.statistics
    }

    // MARK: - 5. Fetch Single Event By ID

    public func fetchEvent(byId id: UUID) async throws -> TimelineEvent? {
        let all = try await fetchRawUnifiedEvents()
        return all.first(where: { $0.id == id || $0.associatedEntityId == id })
    }

    // MARK: - 6. Fetch Recent Events

    public func fetchRecentEvents(limit: Int = 10) async throws -> [TimelineEvent] {
        let events = try await fetchRawUnifiedEvents()
        let sorted = engine.sortEvents(events, ascending: false)
        return Array(sorted.prefix(limit))
    }

    // MARK: - Concurrent Multi-Domain Data Fetching

    private func fetchRawUnifiedEvents() async throws -> [TimelineEvent] {
        // Concurrently query all repositories with zero-latency local retrieval
        async let fetchedDoses = doseRepo.fetchAll()
        async let fetchedLabs = labPanelRepo.fetchAll()
        async let fetchedMeasurements = measurementRepo.fetchAll()
        async let fetchedProtocols = protocolRepo.fetchAll()
        async let fetchedInventory = inventoryEventRepo.fetchAll()
        async let fetchedRecons = reconstitutionRepo.fetchAll()
        async let fetchedSymptoms = symptomRepo.fetchAll()
        async let fetchedDocs = documentRepo.fetchAll()

        // Revisions fetched if repository is supplied
        var fetchedRevisions: [ProtocolRevision] = []
        if let revRepo = protocolRevisionRepo {
            let protos = try await fetchedProtocols
            for p in protos {
                if let revs = try? await revRepo.fetchRevisions(forProtocol: p.id) {
                    fetchedRevisions.append(contentsOf: revs)
                }
            }
        }

        let (doses, labs, measurements, protocols, inventory, recons, symptoms, docs) = try await (
            fetchedDoses,
            fetchedLabs,
            fetchedMeasurements,
            fetchedProtocols,
            fetchedInventory,
            fetchedRecons,
            fetchedSymptoms,
            fetchedDocs
        )

        return engine.compileUnifiedEvents(
            doses: [],
            doseLogs: doses,
            labPanels: labs,
            measurements: measurements,
            protocols: protocols,
            revisions: fetchedRevisions,
            inventoryEvents: inventory,
            reconstitutions: recons,
            documents: docs,
            symptoms: symptoms
        )
    }
}
