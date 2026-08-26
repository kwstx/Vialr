import XCTest
import Domain
import CalculationEngine
@testable import Data

// MARK: - Mocks for Hermetic TimelineService Testing

final class MockTimelineDoseRepository: DoseLogRepositoryProtocol, @unchecked Sendable {
    var items: [DoseLog] = []
    func fetchAll() async throws -> [DoseLog] { items }
    func fetchRecent(limit: Int) async throws -> [DoseLog] { Array(items.prefix(limit)) }
    func fetchForDateRange(start: Date, end: Date) async throws -> [DoseLog] { items }
    func fetchForCompound(compoundId: UUID) async throws -> [DoseLog] { items }
    func save(_ log: DoseLog) async throws { items.append(log) }
    func delete(byId id: UUID) async throws { items.removeAll(where: { $0.id == id }) }
}

final class MockTimelineLabRepository: LabPanelRepositoryProtocol, @unchecked Sendable {
    var items: [LabPanel] = []
    func fetchAll() async throws -> [LabPanel] { items }
    func fetchRecent(limit: Int) async throws -> [LabPanel] { Array(items.prefix(limit)) }
    func fetchForDateRange(start: Date, end: Date) async throws -> [LabPanel] { items }
    func fetchForProtocol(protocolId: UUID) async throws -> [LabPanel] { items }
    func fetch(byId id: UUID) async throws -> LabPanel? { items.first(where: { $0.id == id }) }
    func save(_ panel: LabPanel) async throws { items.append(panel) }
    func delete(byId id: UUID) async throws { items.removeAll(where: { $0.id == id }) }
}

final class MockTimelineMeasurementRepository: MeasurementRepositoryProtocol, @unchecked Sendable {
    var items: [Measurement] = []
    func fetchAll() async throws -> [Measurement] { items }
    func fetchByType(_ type: MeasurementType) async throws -> [Measurement] { items }
    func fetchByCategory(_ category: MeasurementCategory) async throws -> [Measurement] { items }
    func fetchForMetric(code: String) async throws -> [Measurement] { items }
    func fetchForProtocol(protocolId: UUID) async throws -> [Measurement] { items }
    func fetchForDateRange(start: Date, end: Date) async throws -> [Measurement] { items }
    func fetch(byId id: UUID) async throws -> Measurement? { items.first(where: { $0.id == id }) }
    func save(_ measurement: Measurement) async throws { items.append(measurement) }
    func delete(byId id: UUID) async throws { items.removeAll(where: { $0.id == id }) }
}

final class MockTimelineProtocolRepository: ProtocolRepositoryProtocol, @unchecked Sendable {
    var items: [ProtocolModel] = []
    func fetchAll() async throws -> [ProtocolModel] { items }
    func fetchActive() async throws -> [ProtocolModel] { items.filter { $0.status == .active } }
    func fetch(byId id: UUID) async throws -> ProtocolModel? { items.first(where: { $0.id == id }) }
    func save(_ protocolModel: ProtocolModel) async throws { items.append(protocolModel) }
    func delete(byId id: UUID) async throws { items.removeAll(where: { $0.id == id }) }
}

final class MockTimelineInventoryRepository: InventoryEventRepositoryProtocol, @unchecked Sendable {
    var items: [InventoryEvent] = []
    func fetchAll() async throws -> [InventoryEvent] { items }
    func fetchForVial(vialId: UUID) async throws -> [InventoryEvent] { items }
    func fetchForSupply(supplyId: UUID) async throws -> [InventoryEvent] { items }
    func fetchForCompound(compoundId: UUID) async throws -> [InventoryEvent] { items }
    func fetchForDateRange(start: Date, end: Date) async throws -> [InventoryEvent] { items }
    func fetch(byId id: UUID) async throws -> InventoryEvent? { items.first(where: { $0.id == id }) }
    func save(_ event: InventoryEvent) async throws { items.append(event) }
    func saveBatch(_ events: [InventoryEvent]) async throws { items.append(contentsOf: events) }
    func delete(byId id: UUID) async throws { items.removeAll(where: { $0.id == id }) }
}

final class MockTimelineReconRepository: ReconstitutionRecordRepositoryProtocol, @unchecked Sendable {
    var items: [ReconstitutionRecord] = []
    func fetchAll() async throws -> [ReconstitutionRecord] { items }
    func fetch(byId id: UUID) async throws -> ReconstitutionRecord? { items.first(where: { $0.id == id }) }
    func fetchForVial(vialId: UUID) async throws -> [ReconstitutionRecord] { items }
    func fetchActiveRecord(forVial vialId: UUID) async throws -> ReconstitutionRecord? { items.first }
    func save(_ record: ReconstitutionRecord) async throws { items.append(record) }
    func delete(byId id: UUID) async throws { items.removeAll(where: { $0.id == id }) }
}

final class MockTimelineSymptomRepository: SymptomRepositoryProtocol, @unchecked Sendable {
    var items: [SymptomLog] = []
    func fetchAll() async throws -> [SymptomLog] { items }
    func fetchRecent(limit: Int) async throws -> [SymptomLog] { Array(items.prefix(limit)) }
    func save(_ symptomLog: SymptomLog) async throws { items.append(symptomLog) }
    func delete(byId id: UUID) async throws { items.removeAll(where: { $0.id == id }) }
}

final class MockTimelineDocumentRepository: DocumentRepositoryProtocol, @unchecked Sendable {
    var items: [Document] = []
    func fetchAll() async throws -> [Document] { items }
    func fetchByCategory(_ category: DocumentCategory) async throws -> [Document] { items }
    func fetchForLabPanel(labPanelId: UUID) async throws -> [Document] { items }
    func fetchForProtocol(protocolId: UUID) async throws -> [Document] { items }
    func fetchForVial(vialId: UUID) async throws -> [Document] { items }
    func fetch(byId id: UUID) async throws -> Document? { items.first(where: { $0.id == id }) }
    func save(_ document: Document) async throws { items.append(document) }
    func delete(byId id: UUID) async throws { items.removeAll(where: { $0.id == id }) }
}

// MARK: - TimelineService Test Suite

final class TimelineServiceTests: XCTestCase {

    var doseRepo: MockTimelineDoseRepository!
    var labRepo: MockTimelineLabRepository!
    var measurementRepo: MockTimelineMeasurementRepository!
    var protocolRepo: MockTimelineProtocolRepository!
    var inventoryRepo: MockTimelineInventoryRepository!
    var reconRepo: MockTimelineReconRepository!
    var symptomRepo: MockTimelineSymptomRepository!
    var docRepo: MockTimelineDocumentRepository!
    var service: TimelineService!

    override func setUp() {
        super.setUp()
        doseRepo = MockTimelineDoseRepository()
        labRepo = MockTimelineLabRepository()
        measurementRepo = MockTimelineMeasurementRepository()
        protocolRepo = MockTimelineProtocolRepository()
        inventoryRepo = MockTimelineInventoryRepository()
        reconRepo = MockTimelineReconRepository()
        symptomRepo = MockTimelineSymptomRepository()
        docRepo = MockTimelineDocumentRepository()

        service = TimelineService(
            doseRepo: doseRepo,
            labPanelRepo: labRepo,
            measurementRepo: measurementRepo,
            protocolRepo: protocolRepo,
            inventoryEventRepo: inventoryRepo,
            reconstitutionRepo: reconRepo,
            symptomRepo: symptomRepo,
            documentRepo: docRepo,
            engine: TimelineEngine()
        )
    }

    override func tearDown() {
        doseRepo = nil
        labRepo = nil
        measurementRepo = nil
        protocolRepo = nil
        inventoryRepo = nil
        reconRepo = nil
        symptomRepo = nil
        docRepo = nil
        service = nil
        super.tearDown()
    }

    func testFetchTimelineAggregatesAcrossAllDomains() async throws {
        // Populate one item in each domain
        let dose = DoseLog(
            compoundId: UUID(),
            compoundName: "BPC-157",
            scheduledDate: Date(timeIntervalSince1970: 1787738400),
            doseAmount: 250,
            status: .taken
        )
        doseRepo.items.append(dose)

        let lab = LabPanel(
            panelName: "Thyroid Complete",
            collectionDate: Date(timeIntervalSince1970: 1787738500),
            results: [LabResult(biomarkerName: "TSH", value: 1.8, unit: "mIU/L")]
        )
        labRepo.items.append(lab)

        let measurement = Measurement.weight(185.0, dateRecorded: Date(timeIntervalSince1970: 1787738600))
        measurementRepo.items.append(measurement)

        let proto = ProtocolModel(
            name: "Longevity Protocol",
            startDate: Date(timeIntervalSince1970: 1787738000)
        )
        protocolRepo.items.append(proto)

        let inv = InventoryEvent.initialStock(
            vialId: UUID(),
            compoundId: UUID(),
            compoundName: "NAD+",
            initialDryMassMg: 500,
            timestamp: Date(timeIntervalSince1970: 1787738100)
        )
        inventoryRepo.items.append(inv)

        let result = try await service.fetchTimeline(filter: nil)

        // All 5 events should be present in the unified feed
        XCTAssertEqual(result.allEvents.count, 5)
        XCTAssertEqual(result.statistics.totalEventsCount, 5)
        XCTAssertEqual(result.statistics.totalDosesCount, 1)
        XCTAssertEqual(result.statistics.totalLabPanelsCount, 1)
        XCTAssertEqual(result.statistics.totalMeasurementsCount, 1)
        XCTAssertEqual(result.statistics.totalInventoryEventsCount, 1)
        XCTAssertFalse(result.dayGroups.isEmpty)
    }

    func testFetchRecentEventsHonorsLimit() async throws {
        for i in 1...15 {
            let d = DoseLog(
                compoundId: UUID(),
                compoundName: "Compound \(i)",
                scheduledDate: Date(timeIntervalSince1970: Double(1000 + i * 100)),
                doseAmount: Double(i),
                status: .taken
            )
            doseRepo.items.append(d)
        }

        let recent = try await service.fetchRecentEvents(limit: 5)
        XCTAssertEqual(recent.count, 5)
        // Ensure reverse chronological sorting
        XCTAssertTrue(recent[0].timestamp > recent[1].timestamp)
    }
}
