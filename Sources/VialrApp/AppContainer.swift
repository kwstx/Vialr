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
    public let measurementRepository: MeasurementRepositoryProtocol
    public let symptomRepository: SymptomRepositoryProtocol
    public let costRepository: CostRepositoryProtocol
    public let injectionSiteEventRepository: InjectionSiteEventRepositoryProtocol
    public let timelineEventRepository: TimelineEventRepositoryProtocol
    public let syncQueueRepository: SyncQueueRepositoryProtocol
    public let inventoryEventRepository: InventoryEventRepositoryProtocol
    public let healthRepository: HealthRepositoryProtocol
    public let labPanelRepository: LabPanelRepositoryProtocol
    public let documentRepository: DocumentRepositoryProtocol

    // Services & Engines
    public let healthService: HealthServiceProtocol
    public let healthSettingsManager: HealthSettingsManager
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
        measurementRepository: MeasurementRepositoryProtocol = LocalMeasurementRepository(),
        symptomRepository: SymptomRepositoryProtocol = LocalSymptomRepository(),
        costRepository: CostRepositoryProtocol = LocalCostRepository(),
        injectionSiteEventRepository: InjectionSiteEventRepositoryProtocol = LocalInjectionSiteEventRepository(),
        timelineEventRepository: TimelineEventRepositoryProtocol = LocalTimelineEventRepository(),
        syncQueueRepository: SyncQueueRepositoryProtocol = LocalSyncQueueRepository(),
        inventoryEventRepository: InventoryEventRepositoryProtocol = LocalInventoryEventRepository(),
        labPanelRepository: LabPanelRepositoryProtocol = LocalLabPanelRepository(),
        documentRepository: DocumentRepositoryProtocol = LocalDocumentRepository(),
        healthService: HealthServiceProtocol = HealthKitManager.shared,
        healthSettingsManager: HealthSettingsManager = .shared,
        healthRepository: HealthRepositoryProtocol? = nil,
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
        self.measurementRepository = measurementRepository
        self.symptomRepository = symptomRepository
        self.costRepository = costRepository
        self.injectionSiteEventRepository = injectionSiteEventRepository
        self.timelineEventRepository = timelineEventRepository
        self.syncQueueRepository = syncQueueRepository
        self.inventoryEventRepository = inventoryEventRepository
        self.labPanelRepository = labPanelRepository
        self.documentRepository = documentRepository
        self.healthService = healthService
        self.healthSettingsManager = healthSettingsManager
        self.healthRepository = healthRepository ?? HealthRepository(
            healthService: healthService,
            measurementRepository: measurementRepository,
            settingsManager: healthSettingsManager
        )
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
