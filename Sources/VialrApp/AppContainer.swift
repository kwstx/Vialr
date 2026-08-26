import SwiftUI
import Observation
import Domain
import CalculationEngine
import Data
import Health
import Analytics
import Feature
import DesignSystem

/// Dependency Injection container for Vialr application.
public final class AppContainer: @unchecked Sendable {
    public static let shared = AppContainer()

    // Repositories
    public let compoundRepository: CompoundRepositoryProtocol
    public let protocolRepository: ProtocolRepositoryProtocol
    public let doseLogRepository: DoseLogRepositoryProtocol
    public let vialRepository: VialRepositoryProtocol
    public let supplyRepository: SupplyRepositoryProtocol
    public let biomarkerRepository: BiomarkerRepositoryProtocol
    public let symptomRepository: SymptomRepositoryProtocol
    public let costRepository: CostRepositoryProtocol
    public let injectionSiteEventRepository: InjectionSiteEventRepositoryProtocol
    public let timelineEventRepository: TimelineEventRepositoryProtocol
    public let syncQueueRepository: SyncQueueRepositoryProtocol
    public let inventoryEventRepository: InventoryEventRepositoryProtocol

    // Services & Engines
    public let healthService: HealthServiceProtocol
    public let syncEngine: SyncEngineProtocol
    public let notificationScheduler: NotificationSchedulerProtocol
    public let doseLoggingEngine: DoseLoggingEngineProtocol

    public init(
        compoundRepository: CompoundRepositoryProtocol = LocalCompoundRepository(),
        protocolRepository: ProtocolRepositoryProtocol = LocalProtocolRepository(),
        doseLogRepository: DoseLogRepositoryProtocol = LocalDoseLogRepository(),
        vialRepository: VialRepositoryProtocol = LocalVialRepository(),
        supplyRepository: SupplyRepositoryProtocol = LocalSupplyRepository(),
        biomarkerRepository: BiomarkerRepositoryProtocol = LocalBiomarkerRepository(),
        symptomRepository: SymptomRepositoryProtocol = LocalSymptomRepository(),
        costRepository: CostRepositoryProtocol = LocalCostRepository(),
        injectionSiteEventRepository: InjectionSiteEventRepositoryProtocol = LocalInjectionSiteEventRepository(),
        timelineEventRepository: TimelineEventRepositoryProtocol = LocalTimelineEventRepository(),
        syncQueueRepository: SyncQueueRepositoryProtocol = LocalSyncQueueRepository(),
        inventoryEventRepository: InventoryEventRepositoryProtocol = LocalInventoryEventRepository(),
        healthService: HealthServiceProtocol = HealthKitManager.shared,
        syncEngine: SyncEngineProtocol = SyncEngine.shared,
        notificationScheduler: NotificationSchedulerProtocol = NotificationScheduler(),
        doseLoggingEngine: DoseLoggingEngineProtocol? = nil
    ) {
        self.compoundRepository = compoundRepository
        self.protocolRepository = protocolRepository
        self.doseLogRepository = doseLogRepository
        self.vialRepository = vialRepository
        self.supplyRepository = supplyRepository
        self.biomarkerRepository = biomarkerRepository
        self.symptomRepository = symptomRepository
        self.costRepository = costRepository
        self.injectionSiteEventRepository = injectionSiteEventRepository
        self.timelineEventRepository = timelineEventRepository
        self.syncQueueRepository = syncQueueRepository
        self.inventoryEventRepository = inventoryEventRepository
        self.healthService = healthService
        self.syncEngine = syncEngine
        self.notificationScheduler = notificationScheduler
        self.doseLoggingEngine = doseLoggingEngine ?? DoseLoggingEngine(
            doseRepo: doseLogRepository,
            vialRepo: vialRepository,
            siteEventRepo: injectionSiteEventRepository,
            protocolRepo: protocolRepository,
            supplyRepo: supplyRepository,
            inventoryEventRepo: inventoryEventRepository,
            notificationScheduler: notificationScheduler
        )
    }
}
