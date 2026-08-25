import SwiftUI
import Observation
import Domain
import CalculationEngine
import Data
import Health
import Analytics

@Observable
public final class DashboardViewModel: @unchecked Sendable {
    public var activeProtocols: [ProtocolModel] = []
    public var scheduledTodayDoses: [DoseLog] = []
    public var recentCompletedDoses: [DoseLog] = []
    public var nextUpcomingDose: DoseLog?
    public var recommendedSite: InjectionSite?
    public var lowStockSupplies: [SupplyItem] = []
    public var activeVials: [Vial] = []
    public var latestBiomarkers: [Biomarker] = []
    public var adherenceScore: Double = 94.0
    public var currentStreakDays: Int = 12
    public var isLoading: Bool = false
    public var safetyWarnings: [InconsistencyDetector.SafetyWarning] = []

    private let protocolRepo: ProtocolRepositoryProtocol
    private let doseRepo: DoseLogRepositoryProtocol
    private let vialRepo: VialRepositoryProtocol
    private let supplyRepo: SupplyRepositoryProtocol
    private let biomarkerRepo: BiomarkerRepositoryProtocol
    private let rotationEngine = SiteRotationEngine()
    private let adherenceCalculator = AdherenceCalculator()
    private let inconsistencyDetector = InconsistencyDetector()

    public init(
        protocolRepo: ProtocolRepositoryProtocol = LocalProtocolRepository(),
        doseRepo: DoseLogRepositoryProtocol = LocalDoseLogRepository(),
        vialRepo: VialRepositoryProtocol = LocalVialRepository(),
        supplyRepo: SupplyRepositoryProtocol = LocalSupplyRepository(),
        biomarkerRepo: BiomarkerRepositoryProtocol = LocalBiomarkerRepository()
    ) {
        self.protocolRepo = protocolRepo
        self.doseRepo = doseRepo
        self.vialRepo = vialRepo
        self.supplyRepo = supplyRepo
        self.biomarkerRepo = biomarkerRepo
    }

    public func loadDashboardData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            activeProtocols = try await protocolRepo.fetchActive()
            let allDoses = try await doseRepo.fetchAll()
            activeVials = try await vialRepo.fetchActive()
            lowStockSupplies = try await supplyRepo.fetchLowStock()
            latestBiomarkers = try await biomarkerRepo.fetchAll()

            // Sort doses
            let calendar = Calendar.current
            let today = Date()

            scheduledTodayDoses = allDoses.filter {
                $0.status == .scheduled && calendar.isDate($0.scheduledDate, inSameDayAs: today)
            }
            
            recentCompletedDoses = try await doseRepo.fetchRecent(limit: 5)
            nextUpcomingDose = scheduledTodayDoses.first ?? allDoses.first(where: { $0.status == .scheduled })

            // Analyze site rotation
            let siteStatuses = rotationEngine.analyzeRotation(history: allDoses)
            recommendedSite = siteStatuses.first(where: { $0.isRecommended })?.site ?? InjectionSite.standardSites.first

            // Adherence
            let adhReport = adherenceCalculator.calculateAdherence(logs: allDoses)
            adherenceScore = adhReport.overallPercentage
            currentStreakDays = adhReport.currentStreakDays
        } catch {
            print("Dashboard loading error: \(error)")
        }
    }

    public func quickLogDose(_ dose: DoseLog, siteId: String?) async {
        var updated = dose
        updated.status = .taken
        updated.loggedDate = Date()
        updated.injectionSiteId = siteId ?? recommendedSite?.id

        do {
            try await doseRepo.save(updated)
            await loadDashboardData()
        } catch {
            print("Error logging dose: \(error)")
        }
    }
}
