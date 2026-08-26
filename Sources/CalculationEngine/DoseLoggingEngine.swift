import Foundation
import Domain

/// Defines the contract for the core domain coordinator that executes all multi-system operations
/// triggered when a dose is logged by the user.
public protocol DoseLoggingEngineProtocol: Sendable {
    /// Executes the full dose logging workflow across all 6 subsystems:
    /// DoseEvent persistence, inventory vial deduction, injection site recording,
    /// adherence analytics calculation, timeline event creation, and notification reminder scheduling.
    func logDose(_ request: DoseConfirmationRequest) async throws -> DoseLoggingResult

    /// Pre-populates a `DoseConfirmationRequest` with the expected protocol, planned dose,
    /// optimal rotation injection site, and attached active vial.
    func prepareConfirmationRequest(for occurrence: ExpectedDoseOccurrence) async throws -> DoseConfirmationRequest

    /// Pre-populates a `DoseConfirmationRequest` from an existing scheduled `DoseLog`.
    func prepareConfirmationRequest(for scheduledDose: DoseLog) async throws -> DoseConfirmationRequest

    /// Pre-populates a `DoseConfirmationRequest` for a specific active protocol compound.
    func prepareConfirmationRequest(forProtocol protocolId: UUID, compoundId: UUID) async throws -> DoseConfirmationRequest

    /// Directly logs a dose with default confirmed parameters (e.g. 1-tap quick log from Dashboard).
    func quickLogDirect(scheduledDose: DoseLog, siteId: String?) async throws -> DoseLoggingResult

    /// Records a skipped dose event and adjusts upcoming schedules.
    func skipDose(
        doseEventId: UUID?,
        protocolId: UUID?,
        compoundId: UUID,
        compoundName: String,
        scheduledDate: Date,
        reason: String?
    ) async throws -> DoseEvent
}

/// The unified domain engine coordinating dose confirmation, inventory consumption,
/// site rotation, analytics, timeline feed, and notification scheduling.
public final class DoseLoggingEngine: DoseLoggingEngineProtocol, @unchecked Sendable {
    private let doseRepo: DoseLogRepositoryProtocol
    private let vialRepo: VialRepositoryProtocol
    private let siteEventRepo: InjectionSiteEventRepositoryProtocol
    private let protocolRepo: ProtocolRepositoryProtocol
    private let supplyRepo: SupplyRepositoryProtocol?
    private let siteRotationEngine: SiteRotationEngine
    private let schedulingEngine: ProtocolSchedulingEngine
    private let adherenceCalculator: AdherenceCalculator
    private let notificationScheduler: NotificationSchedulerProtocol
    private let calendar: Calendar

    public init(
        doseRepo: DoseLogRepositoryProtocol,
        vialRepo: VialRepositoryProtocol,
        siteEventRepo: InjectionSiteEventRepositoryProtocol,
        protocolRepo: ProtocolRepositoryProtocol,
        supplyRepo: SupplyRepositoryProtocol? = nil,
        siteRotationEngine: SiteRotationEngine = SiteRotationEngine(),
        schedulingEngine: ProtocolSchedulingEngine = ProtocolSchedulingEngine(),
        adherenceCalculator: AdherenceCalculator = AdherenceCalculator(),
        notificationScheduler: NotificationSchedulerProtocol = NotificationScheduler(),
        calendar: Calendar = .current
    ) {
        self.doseRepo = doseRepo
        self.vialRepo = vialRepo
        self.siteEventRepo = siteEventRepo
        self.protocolRepo = protocolRepo
        self.supplyRepo = supplyRepo
        self.siteRotationEngine = siteRotationEngine
        self.schedulingEngine = schedulingEngine
        self.adherenceCalculator = adherenceCalculator
        self.notificationScheduler = notificationScheduler
        self.calendar = calendar
    }

    // MARK: - 1. Core Dose Logging Workflow
    public func logDose(_ request: DoseConfirmationRequest) async throws -> DoseLoggingResult {
        let now = Date()
        let executionTime = request.actualTimestamp

        // 1. Create or Update Ground-Truth DoseEvent
        let doseEventId = request.doseEventId ?? UUID()
        let doseEvent = DoseEvent(
            id: doseEventId,
            protocolId: request.protocolId,
            protocolCompoundId: request.protocolCompoundId,
            compoundId: request.compoundId,
            compoundName: request.compoundName,
            scheduledTimestamp: request.scheduledTimestamp ?? executionTime,
            actualTimestamp: executionTime,
            plannedDoseAmount: request.plannedDoseAmount ?? request.actualDoseAmount,
            actualDoseAmount: request.actualDoseAmount,
            doseUnit: request.doseUnit,
            status: .taken,
            injectionSiteId: request.injectionSiteId,
            injectionSiteName: request.injectionSiteName,
            vialId: request.vialId,
            actualRoute: request.actualRoute,
            plannedRoute: request.actualRoute,
            isPRNOrUnscheduled: request.protocolId == nil,
            skippedReason: nil,
            subjectiveEffectScore: request.subjectiveEffectScore,
            notes: request.notes,
            loggedByUserId: nil,
            createdAt: request.scheduledTimestamp ?? executionTime,
            updatedAt: now,
            version: 1,
            syncState: .pendingCreation
        )

        try await doseRepo.save(doseEvent)

        // 2. Inventory Engine: Consume Liquid Quantity from Reconstituted Vial
        var updatedVial: Vial?
        var consumedVolumeMl: Double?

        if let targetVialId = request.vialId {
            updatedVial = try await vialRepo.fetch(byId: targetVialId)
        } else {
            // Find active reconstituted vial for this compound
            let activeVials = try await vialRepo.fetchActive()
            updatedVial = activeVials.first(where: { $0.compoundId == request.compoundId && $0.isReconstituted })
        }

        if var vial = updatedVial {
            let drawMl = vial.drawVolumeMl(for: request.actualDoseAmount, unit: request.doseUnit) ?? {
                let doseMg = (request.doseUnit == .mg) ? request.actualDoseAmount : (request.actualDoseAmount / 1000.0)
                guard let conc = vial.concentrationMgMl, conc > 0 else { return 0.0 }
                return doseMg / conc
            }()

            consumedVolumeMl = drawMl
            if let currentVol = vial.currentVolumeRemainingMl {
                let newVol = max(0.0, currentVol - drawMl)
                vial.currentVolumeRemainingMl = newVol
                if newVol <= 0.0001 {
                    vial.status = .depleted
                    vial.depletedDate = executionTime
                }
                vial.updatedAt = now
                vial.version += 1
                vial.syncState = .pendingUpdate
                try await vialRepo.save(vial)
                updatedVial = vial
            }
        }

        // Auto-deduct consumable supplies (1 syringe + 1 alcohol prep pad)
        if request.deductSupplies, let supplyRepository = supplyRepo {
            await deductStandardSupplies(using: supplyRepository)
        }

        // 3. Injection-Site Engine: Record Anatomical Location & Reaction
        var injectionSiteEvent: InjectionSiteEvent?
        if let siteId = request.injectionSiteId {
            let site = InjectionSite.standardSites.first(where: { $0.id == siteId }) ?? InjectionSite(
                id: siteId,
                name: request.injectionSiteName ?? "Custom Injection Site",
                region: .abdomen,
                side: .left,
                quadrant: nil,
                route: request.actualRoute
            )

            let event = InjectionSiteEvent(
                id: UUID(),
                doseEventId: doseEvent.id,
                siteId: site.id,
                siteName: request.injectionSiteName ?? site.name,
                region: site.region,
                side: site.side,
                quadrant: site.quadrant,
                route: request.actualRoute,
                timestamp: executionTime,
                compoundId: request.compoundId,
                compoundName: request.compoundName,
                doseAmount: request.actualDoseAmount,
                doseUnit: request.doseUnit,
                needleGauge: request.needleGauge ?? "31G",
                needleLength: request.needleLength ?? "5/16\"",
                reaction: request.siteReaction,
                painScore: request.painScore,
                photoFileId: nil,
                notes: request.notes,
                createdAt: now,
                updatedAt: now,
                version: 1,
                syncState: .pendingCreation
            )

            try await siteEventRepo.save(event)
            injectionSiteEvent = event
        }

        // 4. Analytics Engine: Update Adherence & Streak
        let allLogs = try await doseRepo.fetchAll()
        let adherenceReport = adherenceCalculator.calculateAdherence(logs: allLogs)

        // 5. Timeline Engine: Create Unified Chronological Event
        let timelineEvent = TimelineEvent(from: doseEvent)

        // 6. Notification Scheduler: Determine & Schedule Next Upcoming Reminder
        var nextReminder: ScheduledReminderInfo?
        if let protoId = request.protocolId {
            let protocolModel = try await protocolRepo.fetch(byId: protoId)
            nextReminder = try await notificationScheduler.scheduleNextDoseReminder(
                protocolModel: protocolModel,
                compoundId: request.compoundId,
                compoundName: request.compoundName,
                referenceDate: executionTime,
                leadTimeMinutes: 15
            )
        }

        return DoseLoggingResult(
            doseEvent: doseEvent,
            injectionSiteEvent: injectionSiteEvent,
            updatedVial: updatedVial,
            consumedVolumeMl: consumedVolumeMl,
            adherenceReport: adherenceReport,
            timelineEvent: timelineEvent,
            nextScheduledReminder: nextReminder
        )
    }

    // MARK: - 2. Confirmation Context Preparation
    public func prepareConfirmationRequest(for occurrence: ExpectedDoseOccurrence) async throws -> DoseConfirmationRequest {
        let history = try await doseRepo.fetchAll()
        let siteStatuses = siteRotationEngine.analyzeRotation(history: history)
        let recommendedSite = siteStatuses.first(where: { $0.isRecommended })?.site ?? InjectionSite.standardSites.first

        var targetVialId = occurrence.attachedVialId
        if targetVialId == nil {
            let activeVials = try await vialRepo.fetchActive()
            targetVialId = activeVials.first(where: { $0.compoundId == occurrence.compoundId && $0.isReconstituted })?.id
        }

        return DoseConfirmationRequest(
            doseEventId: occurrence.associatedDoseLogId ?? occurrence.id,
            protocolId: occurrence.protocolId,
            protocolCompoundId: occurrence.protocolCompoundId,
            compoundId: occurrence.compoundId,
            compoundName: occurrence.compoundName,
            plannedDoseAmount: occurrence.plannedDoseAmount,
            actualDoseAmount: occurrence.actualDoseAmount ?? occurrence.plannedDoseAmount,
            doseUnit: occurrence.doseUnit,
            actualRoute: occurrence.route,
            injectionSiteId: recommendedSite?.id,
            injectionSiteName: recommendedSite?.name,
            vialId: targetVialId,
            actualTimestamp: Date(),
            scheduledTimestamp: occurrence.scheduledTimestamp,
            notes: occurrence.notes
        )
    }

    public func prepareConfirmationRequest(for scheduledDose: DoseLog) async throws -> DoseConfirmationRequest {
        let history = try await doseRepo.fetchAll()
        let siteStatuses = siteRotationEngine.analyzeRotation(history: history)
        let recommendedSite = siteStatuses.first(where: { $0.isRecommended })?.site ?? InjectionSite.standardSites.first

        var targetVialId = scheduledDose.vialId
        if targetVialId == nil {
            let activeVials = try await vialRepo.fetchActive()
            targetVialId = activeVials.first(where: { $0.compoundId == scheduledDose.compoundId && $0.isReconstituted })?.id
        }

        return DoseConfirmationRequest(
            doseEventId: scheduledDose.id,
            protocolId: scheduledDose.protocolId,
            protocolCompoundId: scheduledDose.protocolItemId,
            compoundId: scheduledDose.compoundId,
            compoundName: scheduledDose.compoundName,
            plannedDoseAmount: scheduledDose.plannedDoseAmount ?? scheduledDose.actualDoseAmount,
            actualDoseAmount: scheduledDose.actualDoseAmount,
            doseUnit: scheduledDose.doseUnit,
            actualRoute: scheduledDose.actualRoute,
            injectionSiteId: scheduledDose.injectionSiteId ?? recommendedSite?.id,
            injectionSiteName: scheduledDose.injectionSiteName ?? recommendedSite?.name,
            vialId: targetVialId,
            actualTimestamp: Date(),
            scheduledTimestamp: scheduledDose.scheduledTimestamp,
            notes: scheduledDose.notes
        )
    }

    public func prepareConfirmationRequest(forProtocol protocolId: UUID, compoundId: UUID) async throws -> DoseConfirmationRequest {
        guard let proto = try await protocolRepo.fetch(byId: protocolId),
              let compound = proto.compounds.first(where: { $0.compoundId == compoundId }) else {
            throw DoseLoggingError.protocolCompoundNotFound
        }

        let history = try await doseRepo.fetchAll()
        let siteStatuses = siteRotationEngine.analyzeRotation(history: history)
        let recommendedSite = siteStatuses.first(where: { $0.isRecommended })?.site ?? InjectionSite.standardSites.first

        let activeVials = try await vialRepo.fetchActive()
        let targetVial = compound.attachedVialId ?? activeVials.first(where: { $0.compoundId == compoundId && $0.isReconstituted })?.id

        let effectiveAmount = compound.effectiveDoseAmount(on: Date(), relativeTo: proto.startDate)

        return DoseConfirmationRequest(
            doseEventId: UUID(),
            protocolId: proto.id,
            protocolCompoundId: compound.id,
            compoundId: compound.compoundId,
            compoundName: compound.compoundName,
            plannedDoseAmount: effectiveAmount,
            actualDoseAmount: effectiveAmount,
            doseUnit: compound.doseUnit,
            actualRoute: compound.route,
            injectionSiteId: recommendedSite?.id,
            injectionSiteName: recommendedSite?.name,
            vialId: targetVial,
            actualTimestamp: Date(),
            scheduledTimestamp: Date(),
            notes: compound.notes
        )
    }

    // MARK: - 3. Quick 1-Tap Direct Log
    public func quickLogDirect(scheduledDose: DoseLog, siteId: String? = nil) async throws -> DoseLoggingResult {
        var request = try await prepareConfirmationRequest(for: scheduledDose)
        if let customSiteId = siteId {
            let site = InjectionSite.standardSites.first(where: { $0.id == customSiteId })
            request.injectionSiteId = customSiteId
            request.injectionSiteName = site?.name
        }
        return try await logDose(request)
    }

    // MARK: - 4. Skip Dose Workflow
    public func skipDose(
        doseEventId: UUID? = nil,
        protocolId: UUID?,
        compoundId: UUID,
        compoundName: String,
        scheduledDate: Date,
        reason: String? = "Skipped by user"
    ) async throws -> DoseEvent {
        let event = DoseEvent(
            id: doseEventId ?? UUID(),
            protocolId: protocolId,
            compoundId: compoundId,
            compoundName: compoundName,
            scheduledTimestamp: scheduledDate,
            actualTimestamp: Date(),
            plannedDoseAmount: 0,
            actualDoseAmount: 0,
            doseUnit: .mcg,
            status: .skipped,
            skippedReason: reason,
            notes: reason ?? "",
            updatedAt: Date()
        )

        try await doseRepo.save(event)

        // Reschedule next reminder if part of an active protocol
        if let pId = protocolId, let proto = try await protocolRepo.fetch(byId: pId) {
            _ = try await notificationScheduler.scheduleNextDoseReminder(
                protocolModel: proto,
                compoundId: compoundId,
                compoundName: compoundName,
                referenceDate: Date(),
                leadTimeMinutes: 15
            )
        }

        return event
    }

    // MARK: - Internal Supply Deduction Helper
    private func deductStandardSupplies(using repository: SupplyRepositoryProtocol) async {
        do {
            let supplies = try await repository.fetchAll()
            for var item in supplies {
                let nameLower = item.name.lowercased()
                if nameLower.contains("syringe") || nameLower.contains("needle") || nameLower.contains("alcohol") || nameLower.contains("prep") {
                    if item.quantityRemaining > 0 {
                        item.quantityRemaining = max(0, item.quantityRemaining - 1)
                        item.updatedAt = Date()
                        try await repository.save(item)
                    }
                }
            }
        } catch {
            // Silently ignore supply deduction errors to not block primary dose logging
        }
    }
}

public enum DoseLoggingError: Error, LocalizedError {
    case protocolCompoundNotFound
    case invalidDosageAmount
    case vialNotFound

    public var errorDescription: String? {
        switch self {
        case .protocolCompoundNotFound:
            return "The selected compound is not part of the active protocol stack."
        case .invalidDosageAmount:
            return "The dosage amount must be greater than zero."
        case .vialNotFound:
            return "No matching reconstituted vial was found in inventory."
        }
    }
}
