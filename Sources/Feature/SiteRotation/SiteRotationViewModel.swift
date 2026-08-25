import SwiftUI
import Observation
import Domain
import CalculationEngine
import Data
import DesignSystem

@Observable
public final class SiteRotationViewModel: @unchecked Sendable {
    public var siteStatuses: [SiteRotationEngine.SiteStatus] = []
    public var selectedSiteId: String?
    public var recentLogs: [DoseLog] = []
    public var isLoading: Bool = false

    private let doseRepo: DoseLogRepositoryProtocol
    private let rotationEngine = SiteRotationEngine()

    public init(doseRepo: DoseLogRepositoryProtocol = LocalDoseLogRepository()) {
        self.doseRepo = doseRepo
    }

    public func loadSiteData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await doseRepo.fetchAll()
            recentLogs = try await doseRepo.fetchRecent(limit: 15)
            siteStatuses = rotationEngine.analyzeRotation(history: all)
            selectedSiteId = siteStatuses.first(where: { $0.isRecommended })?.site.id ?? "ab_r_uo"
        } catch {
            print("Failed to load site rotation data: \(error)")
        }
    }

    public var siteSelectionItems: [SiteSelectionItem] {
        siteStatuses.map { s in
            SiteSelectionItem(
                id: s.site.id,
                name: s.site.name,
                shortLabel: s.site.name.replacingOccurrences(of: "Abdomen - ", with: ""),
                daysSinceLastUse: s.daysSinceLastUse,
                isRecommended: s.isRecommended
            )
        }
    }
}
