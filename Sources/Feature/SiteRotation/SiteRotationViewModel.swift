import SwiftUI
import Observation
import Domain
import CalculationEngine
import Data
import DesignSystem

@Observable
public final class SiteRotationViewModel: @unchecked Sendable {
    public var siteStatuses: [SiteRotationStatus] = []
    public var selectedSiteId: String?
    public var lastSite: InjectionSite?
    public var nextSite: InjectionSite?
    public var lastEvent: InjectionSiteEvent?
    public var siteEvents: [InjectionSiteEvent] = []
    public var recentLogs: [DoseLog] = []
    public var selectedStrategy: SiteRotationStrategy = .bilateralAlternating
    public var strategyReason: String = ""
    public var isLoading: Bool = false

    private let doseRepo: DoseLogRepositoryProtocol
    private let siteEventRepo: InjectionSiteEventRepositoryProtocol
    private let userRepo: UserRepositoryProtocol
    private let rotationEngine = SiteRotationEngine()

    public init(
        doseRepo: DoseLogRepositoryProtocol = LocalDoseLogRepository(),
        siteEventRepo: InjectionSiteEventRepositoryProtocol = LocalInjectionSiteEventRepository(),
        userRepo: UserRepositoryProtocol = LocalUserRepository()
    ) {
        self.doseRepo = doseRepo
        self.siteEventRepo = siteEventRepo
        self.userRepo = userRepo
    }

    public func loadSiteData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // 1. Load User Preferences for Rotation Strategy
            if let user = try? await userRepo.fetchCurrentUser() {
                self.selectedStrategy = user.preferences.siteRotationStrategy
            }

            // 2. Fetch Protocol-Independent Site History & Dose Logs
            siteEvents = try await siteEventRepo.fetchAll()
            recentLogs = try await doseRepo.fetchRecent(limit: 20)

            // 3. Evaluate Next Site & Statuses using SiteRotationService
            evaluateRotation()
        } catch {
            print("Failed to load site rotation data: \(error)")
        }
    }

    /// Changes the user's selected rotation strategy and re-evaluates the recommendation.
    public func setStrategy(_ newStrategy: SiteRotationStrategy) {
        selectedStrategy = newStrategy
        evaluateRotation()

        Task {
            if var user = try? await userRepo.fetchCurrentUser() {
                user.preferences.siteRotationStrategy = newStrategy
                try? await userRepo.saveUser(user)
            }
        }
    }

    private func evaluateRotation() {
        let result: SiteRotationResult
        if !siteEvents.isEmpty {
            result = rotationEngine.evaluateNextSite(
                siteEvents: siteEvents,
                availableSites: InjectionSite.standardSites,
                strategy: selectedStrategy
            )
        } else {
            result = rotationEngine.evaluateRotation(
                history: recentLogs,
                availableSites: InjectionSite.standardSites,
                strategy: selectedStrategy
            )
        }

        self.lastSite = result.lastSite
        self.nextSite = result.nextSite
        self.lastEvent = result.lastEvent
        self.siteStatuses = result.siteStatuses
        self.strategyReason = result.strategyReason

        if selectedSiteId == nil {
            self.selectedSiteId = result.nextSite.id
        }
    }

    public var selectedSiteStatus: SiteRotationStatus? {
        guard let id = selectedSiteId else { return nil }
        return siteStatuses.first(where: { $0.site.id == id })
    }

    public var siteSelectionItems: [SiteSelectionItem] {
        siteStatuses.map { s in
            SiteSelectionItem(
                id: s.site.id,
                name: s.site.name,
                shortLabel: s.site.shortName,
                region: s.site.region,
                side: s.site.side,
                coordinates: s.site.coordinates,
                daysSinceLastUse: s.daysSinceLastUse,
                isRecommended: s.isRecommended,
                isLastUsed: s.isLastUsed,
                restingScore: s.restingScore
            )
        }
    }
}

