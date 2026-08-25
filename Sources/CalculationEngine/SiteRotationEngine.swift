import Foundation
import Domain

/// Evaluates anatomical injection history and recommends the optimal rotation site.
public struct SiteRotationEngine: Sendable {
    
    public struct SiteStatus: Identifiable, Sendable {
        public let site: InjectionSite
        public let lastUsedDate: Date?
        public let daysSinceLastUse: Int?
        public let timesUsedTotal: Int
        public let restingScore: Double // 0 (recently used) to 100 (fully rested)
        public let isRecommended: Bool

        public var id: String { site.id }

        public init(
            site: InjectionSite,
            lastUsedDate: Date? = nil,
            daysSinceLastUse: Int? = nil,
            timesUsedTotal: Int = 0,
            restingScore: Double = 100.0,
            isRecommended: Bool = false
        ) {
            self.site = site
            self.lastUsedDate = lastUsedDate
            self.daysSinceLastUse = daysSinceLastUse
            self.timesUsedTotal = timesUsedTotal
            self.restingScore = restingScore
            self.isRecommended = isRecommended
        }
    }

    public init() {}

    /// Analyzes dose history and generates scored site recommendations.
    public func analyzeRotation(
        history: [DoseLog],
        allSites: [InjectionSite] = InjectionSite.standardSites,
        currentDate: Date = Date()
    ) -> [SiteStatus] {
        let calendar = Calendar.current
        var siteStats: [String: (lastDate: Date?, count: Int)] = [:]

        // Pre-populate with all sites
        for site in allSites {
            siteStats[site.id] = (nil, 0)
        }

        // Aggregate taken doses with valid injectionSiteId
        let completedDoses = history
            .filter { $0.status == .taken && $0.injectionSiteId != nil }
            .sorted(by: { ($0.loggedDate ?? $0.scheduledDate) < ($1.loggedDate ?? $1.scheduledDate) })

        for dose in completedDoses {
            guard let siteId = dose.injectionSiteId else { continue }
            let date = dose.loggedDate ?? dose.scheduledDate
            let current = siteStats[siteId] ?? (nil, 0)
            siteStats[siteId] = (date, current.count + 1)
        }

        // Compute scores
        var scoredList: [SiteStatus] = []

        for site in allSites {
            let stat = siteStats[site.id] ?? (nil, 0)
            let daysSince: Int?
            let restingScore: Double

            if let lastDate = stat.lastDate {
                let diff = calendar.dateComponents([.day], from: lastDate, to: currentDate).day ?? 0
                daysSince = max(0, diff)

                // 7 days is considered fully rested (100%), less than 1 day is 0%
                if diff >= 7 {
                    restingScore = 100.0
                } else {
                    restingScore = Double(diff) / 7.0 * 100.0
                }
            } else {
                daysSince = nil
                restingScore = 100.0 // Never used = pristine
            }

            scoredList.append(
                SiteStatus(
                    site: site,
                    lastUsedDate: stat.lastDate,
                    daysSinceLastUse: daysSince,
                    timesUsedTotal: stat.count,
                    restingScore: restingScore,
                    isRecommended: false
                )
            )
        }

        // Identify the top recommended site:
        // Highest resting score, ties broken by least times used total
        if let bestIndex = scoredList.indices.max(by: { (a, b) -> Bool in
            if scoredList[a].restingScore != scoredList[b].restingScore {
                return scoredList[a].restingScore < scoredList[b].restingScore
            }
            return scoredList[a].timesUsedTotal > scoredList[b].timesUsedTotal
        }) {
            let best = scoredList[bestIndex]
            scoredList[bestIndex] = SiteStatus(
                site: best.site,
                lastUsedDate: best.lastUsedDate,
                daysSinceLastUse: best.daysSinceLastUse,
                timesUsedTotal: best.timesUsedTotal,
                restingScore: best.restingScore,
                isRecommended: true
            )
        }

        return scoredList
    }
}
