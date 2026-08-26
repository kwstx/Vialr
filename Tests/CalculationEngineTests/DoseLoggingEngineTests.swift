import XCTest
import Domain
@testable import CalculationEngine

// MARK: - In-Memory Test Repositories for Hermetic Testing

final class MockDoseRepository: DoseLogRepositoryProtocol, @unchecked Sendable {
    var logs: [DoseLog] = []

    func fetchAll() async throws -> [DoseLog] { logs }
    func fetchRecent(limit: Int) async throws -> [DoseLog] { Array(logs.prefix(limit)) }
    func fetchForDateRange(start: Date, end: Date) async throws -> [DoseLog] {
        logs.filter { ($0.loggedDate ?? $0.scheduledDate) >= start && ($0.loggedDate ?? $0.scheduledDate) <= end }
    }
    func fetchForCompound(compoundId: UUID) async throws -> [DoseLog] {
        logs.filter { $0.compoundId == compoundId }
    }
    func save(_ log: DoseLog) async throws {
        if let idx = logs.firstIndex(where: { $0.id == log.id }) {
            logs[idx] = log
        } else {
            logs.append(log)
        }
    }
    func delete(byId id: UUID) async throws {
        logs.removeAll(where: { $0.id == id })
    }
}

final class MockVialRepository: VialRepositoryProtocol, @unchecked Sendable {
    var vials: [Vial] = []

    func fetchAll() async throws -> [Vial] { vials }
    func fetchActive() async throws -> [Vial] {
        vials.filter { $0.status == .reconstituted || $0.status == .unopened }
    }
    func fetch(byId id: UUID) async throws -> Vial? {
        vials.first(where: { $0.id == id })
    }
    func save(_ vial: Vial) async throws {
        if let idx = vials.firstIndex(where: { $0.id == vial.id }) {
            vials[idx] = vial
        } else {
            vials.append(vial)
        }
    }
    func delete(byId id: UUID) async throws {
        vials.removeAll(where: { $0.id == id })
    }
}

final class MockSiteEventRepository: InjectionSiteEventRepositoryProtocol, @unchecked Sendable {
    var events: [InjectionSiteEvent] = []

    func fetchAll() async throws -> [InjectionSiteEvent] { events }
    func fetchRecent(limit: Int) async throws -> [InjectionSiteEvent] { Array(events.prefix(limit)) }
    func fetchForDoseEvent(doseEventId: UUID) async throws -> InjectionSiteEvent? {
        events.first(where: { $0.doseEventId == doseEventId })
    }
    func fetchForSite(siteId: String) async throws -> [InjectionSiteEvent] {
        events.filter { $0.siteId == siteId }
    }
    func save(_ event: InjectionSiteEvent) async throws {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = event
        } else {
            events.append(event)
        }
    }
    func delete(byId id: UUID) async throws {
        events.removeAll(where: { $0.id == id })
    }
}

final class MockProtocolRepository: ProtocolRepositoryProtocol, @unchecked Sendable {
    var protocols: [ProtocolModel] = []

    func fetchAll() async throws -> [ProtocolModel] { protocols }
    func fetchActive() async throws -> [ProtocolModel] { protocols.filter { $0.status == .active } }
    func fetch(byId id: UUID) async throws -> ProtocolModel? {
        protocols.first(where: { $0.id == id })
    }
    func save(_ protocolModel: ProtocolModel) async throws {
        if let idx = protocols.firstIndex(where: { $0.id == protocolModel.id }) {
            protocols[idx] = protocolModel
        } else {
            protocols.append(protocolModel)
        }
    }
    func delete(byId id: UUID) async throws {
        protocols.removeAll(where: { $0.id == id })
    }
}

// MARK: - Dose Logging Engine Tests

final class DoseLoggingEngineTests: XCTestCase {
    var doseRepo: MockDoseRepository!
    var vialRepo: MockVialRepository!
    var siteEventRepo: MockSiteEventRepository!
    var protocolRepo: MockProtocolRepository!
    var engine: DoseLoggingEngine!
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar.current
        doseRepo = MockDoseRepository()
        vialRepo = MockVialRepository()
        siteEventRepo = MockSiteEventRepository()
        protocolRepo = MockProtocolRepository()

        engine = DoseLoggingEngine(
            doseRepo: doseRepo,
            vialRepo: vialRepo,
            siteEventRepo: siteEventRepo,
            protocolRepo: protocolRepo,
            calendar: calendar
        )
    }

    // MARK: - 1. Full 6-Subsystem Coordination Test
    func testFullDoseLoggingCoordination() async throws {
        let compoundId = UUID()
        let protocolId = UUID()
        let now = Date()

        // Setup active protocol
        let compound = ProtocolCompound(
            compoundId: compoundId,
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay,
            route: .subcutaneous
        )
        let proto = ProtocolModel(
            id: protocolId,
            name: "Healing Stack",
            status: .active,
            startDate: now,
            compounds: [compound]
        )
        try await protocolRepo.save(proto)

        // Setup active reconstituted vial: 5mg in 2.0 mL = 2.5 mg/mL. Draw for 250mcg is 0.1 mL.
        let vial = Vial(
            compoundId: compoundId,
            compoundName: "BPC-157",
            totalDryMassMg: 5.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 2.0,
            isReconstituted: true,
            status: .reconstituted
        )
        try await vialRepo.save(vial)

        // User confirmation request
        let request = DoseConfirmationRequest(
            protocolId: protocolId,
            protocolCompoundId: compound.id,
            compoundId: compoundId,
            compoundName: "BPC-157",
            plannedDoseAmount: 250,
            actualDoseAmount: 250,
            doseUnit: .mcg,
            actualRoute: .subcutaneous,
            injectionSiteId: "ab_l_uo",
            injectionSiteName: "Abdomen - Left Upper Outer",
            vialId: vial.id,
            actualTimestamp: now,
            notes: "Smooth injection, zero sting"
        )

        // Execute Dose Logging Engine
        let result = try await engine.logDose(request)

        // 1. Subsystem: DoseEvent
        XCTAssertEqual(result.doseEvent.status, .taken)
        XCTAssertEqual(result.doseEvent.actualDoseAmount, 250)
        XCTAssertEqual(result.doseEvent.compoundName, "BPC-157")
        XCTAssertEqual(result.doseEvent.notes, "Smooth injection, zero sting")
        let savedLogs = try await doseRepo.fetchAll()
        XCTAssertEqual(savedLogs.count, 1)
        XCTAssertEqual(savedLogs.first?.id, result.doseEvent.id)

        // 2. Subsystem: Inventory Volume Deduction
        XCTAssertNotNil(result.updatedVial)
        XCTAssertEqual(result.consumedVolumeMl ?? 0, 0.1, accuracy: 0.001)
        XCTAssertEqual(result.updatedVial?.currentVolumeRemainingMl ?? 0, 1.9, accuracy: 0.001)
        XCTAssertEqual(result.updatedVial?.status, .reconstituted)
        let savedVials = try await vialRepo.fetchAll()
        XCTAssertEqual(savedVials.first?.currentVolumeRemainingMl ?? 0, 1.9, accuracy: 0.001)

        // 3. Subsystem: Injection Site Event
        XCTAssertNotNil(result.injectionSiteEvent)
        XCTAssertEqual(result.injectionSiteEvent?.siteId, "ab_l_uo")
        XCTAssertEqual(result.injectionSiteEvent?.region, .abdomen)
        XCTAssertEqual(result.injectionSiteEvent?.doseEventId, result.doseEvent.id)
        let savedSiteEvents = try await siteEventRepo.fetchAll()
        XCTAssertEqual(savedSiteEvents.count, 1)

        // 4. Subsystem: Analytics Adherence
        XCTAssertEqual(result.adherenceReport.totalTaken, 1)
        XCTAssertEqual(result.adherenceReport.overallPercentage, 100.0)
        XCTAssertEqual(result.adherenceReport.currentStreakDays, 1)

        // 5. Subsystem: Timeline Event
        XCTAssertEqual(result.timelineEvent.category, .dose)
        XCTAssertEqual(result.timelineEvent.associatedEntityId, result.doseEvent.id)
        XCTAssertTrue(result.timelineEvent.title.contains("BPC-157"))
        XCTAssertTrue(result.timelineEvent.subtitle.contains("250 mcg"))

        // 6. Subsystem: Notification Scheduler
        XCTAssertNotNil(result.nextScheduledReminder)
        XCTAssertEqual(result.nextScheduledReminder?.compoundName, "BPC-157")
        XCTAssertEqual(result.nextScheduledReminder?.plannedDoseAmount, 250)
    }

    // MARK: - 2. Vial Depletion Lifecycle Transition
    func testVialDepletionWhenExhausted() async throws {
        let compoundId = UUID()
        let now = Date()

        // Vial has only 0.1 mL remaining (exactly 1 dose left)
        let vial = Vial(
            compoundId: compoundId,
            compoundName: "TB-500",
            totalDryMassMg: 5.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 0.1,
            isReconstituted: true,
            status: .reconstituted
        )
        try await vialRepo.save(vial)

        let request = DoseConfirmationRequest(
            compoundId: compoundId,
            compoundName: "TB-500",
            actualDoseAmount: 250,
            doseUnit: .mcg,
            vialId: vial.id,
            actualTimestamp: now
        )

        let result = try await engine.logDose(request)

        XCTAssertEqual(result.updatedVial?.currentVolumeRemainingMl ?? 1, 0.0, accuracy: 0.0001)
        XCTAssertEqual(result.updatedVial?.status, .depleted)
        XCTAssertNotNil(result.updatedVial?.depletedDate)
    }

    // MARK: - 3. Site Rotation Recommendation Preparation
    func testPrepareConfirmationRequestRotatesSite() async throws {
        let compoundId = UUID()
        let now = Date()

        // Previous injection was at Left Upper Outer abdomen
        let prevDose = DoseLog(
            compoundId: compoundId,
            compoundName: "BPC-157",
            scheduledDate: now.addingTimeInterval(-3600),
            loggedDate: now.addingTimeInterval(-3600),
            doseAmount: 250,
            doseUnit: .mcg,
            status: .taken,
            injectionSiteId: "ab_l_uo",
            injectionSiteName: "Abdomen - Left Upper Outer"
        )
        try await doseRepo.save(prevDose)

        let nextScheduled = DoseLog(
            compoundId: compoundId,
            compoundName: "BPC-157",
            scheduledDate: now,
            doseAmount: 250,
            doseUnit: .mcg,
            status: .scheduled
        )

        let preparedRequest = try await engine.prepareConfirmationRequest(for: nextScheduled)

        XCTAssertNotNil(preparedRequest.injectionSiteId)
        // Site rotation engine must not recommend the just-used site
        XCTAssertNotEqual(preparedRequest.injectionSiteId, "ab_l_uo")
    }

    // MARK: - 4. Dose Deviation Tracking (Actual != Planned)
    func testDoseDeviationTracking() async throws {
        let compoundId = UUID()
        let now = Date()

        let request = DoseConfirmationRequest(
            compoundId: compoundId,
            compoundName: "Semaglutide",
            plannedDoseAmount: 250,
            actualDoseAmount: 500, // User stepped up dose
            doseUnit: .mcg,
            actualTimestamp: now
        )

        let result = try await engine.logDose(request)

        XCTAssertEqual(result.doseEvent.plannedDoseAmount, 250)
        XCTAssertEqual(result.doseEvent.actualDoseAmount, 500)
        XCTAssertEqual(result.doseEvent.dosageDeviation, 250)
    }

    // MARK: - 5. Skip Dose Workflow
    func testSkipDoseWorkflow() async throws {
        let compoundId = UUID()
        let protoId = UUID()
        let now = Date()

        let compound = ProtocolCompound(
            compoundId: compoundId,
            compoundName: "CJC-1295",
            doseAmount: 100,
            doseUnit: .mcg,
            scheduleRule: .everyDay
        )
        let proto = ProtocolModel(
            id: protoId,
            name: "GH Stack",
            status: .active,
            startDate: now,
            compounds: [compound]
        )
        try await protocolRepo.save(proto)

        let skippedEvent = try await engine.skipDose(
            protocolId: protoId,
            compoundId: compoundId,
            compoundName: "CJC-1295",
            scheduledDate: now,
            reason: "Traveling without refrigeration"
        )

        XCTAssertEqual(skippedEvent.status, .skipped)
        XCTAssertEqual(skippedEvent.skippedReason, "Traveling without refrigeration")
        let savedLogs = try await doseRepo.fetchAll()
        XCTAssertEqual(savedLogs.first?.status, .skipped)
    }
}
