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

    // Services
    public let healthService: HealthServiceProtocol
    public let syncEngine: SyncEngineProtocol

    public init(
        compoundRepository: CompoundRepositoryProtocol = LocalCompoundRepository(),
        protocolRepository: ProtocolRepositoryProtocol = LocalProtocolRepository(),
        doseLogRepository: DoseLogRepositoryProtocol = LocalDoseLogRepository(),
        vialRepository: VialRepositoryProtocol = LocalVialRepository(),
        supplyRepository: SupplyRepositoryProtocol = LocalSupplyRepository(),
        biomarkerRepository: BiomarkerRepositoryProtocol = LocalBiomarkerRepository(),
        symptomRepository: SymptomRepositoryProtocol = LocalSymptomRepository(),
        costRepository: CostRepositoryProtocol = LocalCostRepository(),
        healthService: HealthServiceProtocol = HealthKitManager.shared,
        syncEngine: SyncEngineProtocol = SyncEngine.shared
    ) {
        self.compoundRepository = compoundRepository
        self.protocolRepository = protocolRepository
        self.doseLogRepository = doseLogRepository
        self.vialRepository = vialRepository
        self.supplyRepository = supplyRepository
        self.biomarkerRepository = biomarkerRepository
        self.symptomRepository = symptomRepository
        self.costRepository = costRepository
        self.healthService = healthService
        self.syncEngine = syncEngine
    }
}
