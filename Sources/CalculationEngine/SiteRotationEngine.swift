import Foundation
import Domain

/// Protocol defining the contract for the injection site rotation service.
public protocol SiteRotationServiceProtocol: Sendable {
    /// Evaluates anatomical injection history and calculates the next recommended site
    /// by deterministically enforcing the user's selected rotation strategy.
    ///
    /// Non-Medical Disclaimer: This service does not provide medical recommendations. It strictly enforces
    /// the user's chosen pattern (e.g. alternating sides, clockwise quadrants, maximum rest, or sequential order).
    func evaluateNextSite(
        siteEvents: [InjectionSiteEvent],
        availableSites: [InjectionSite],
        strategy: SiteRotationStrategy,
        targetRegion: BodyRegion?,
        currentDate: Date
    ) -> SiteRotationResult

    /// Evaluates dose logs (legacy / convenience overload) and calculates the next rotation site.
    func evaluateRotation(
        history: [DoseLog],
        availableSites: [InjectionSite],
        strategy: SiteRotationStrategy,
        targetRegion: BodyRegion?,
        currentDate: Date
    ) -> SiteRotationResult
}

/// Evaluates anatomical injection history across all protocols and calculates the next available
/// injection site based on the user's chosen rotation strategy pattern.
///
/// Policy: Vialr does not give clinical or medical recommendations. It strictly and deterministically
/// enforces the user's selected rotation pattern (e.g. bilateral alternating, clockwise quadrants, maximum rest).
public struct SiteRotationEngine: SiteRotationServiceProtocol, Sendable {

    /// Backwards-compatibility typealias for existing call sites referencing `SiteRotationEngine.SiteStatus`.
    public typealias SiteStatus = Domain.SiteRotationStatus

    public init() {}

    // MARK: - 1. Core Evaluation from InjectionSiteEvents (Protocol-Independent)

    public func evaluateNextSite(
        siteEvents: [InjectionSiteEvent],
        availableSites: [InjectionSite] = InjectionSite.standardSites,
        strategy: SiteRotationStrategy = .bilateralAlternating,
        targetRegion: BodyRegion? = nil,
        currentDate: Date = Date()
    ) -> SiteRotationResult {
        let calendar = Calendar.current
        let activeSites = availableSites.filter { $0.isActive }
        let sitesPool = activeSites.isEmpty ? InjectionSite.standardSites : activeSites

        // Filter candidate sites by region if specified
        let candidateSites: [InjectionSite]
        if let region = targetRegion {
            let regionFiltered = sitesPool.filter { $0.region == region }
            candidateSites = regionFiltered.isEmpty ? sitesPool : regionFiltered
        } else {
            candidateSites = sitesPool
        }

        // Sort events chronologically descending (most recent first)
        let sortedEvents = siteEvents.sorted(by: { $0.timestamp > $1.timestamp })
        let lastEvent = sortedEvents.first
        let lastSite = lastEvent.flatMap { ev in
            availableSites.first(where: { $0.id == ev.siteId }) ?? InjectionSite.standardSites.first(where: { $0.id == ev.siteId })
        }

        // Aggregate statistics per site
        var siteStats: [String: (lastDate: Date?, count: Int, lastReaction: SiteReactionSeverity?)] = [:]
        for site in sitesPool {
            siteStats[site.id] = (nil, 0, nil)
        }

        for event in sortedEvents {
            let current = siteStats[event.siteId] ?? (nil, 0, nil)
            let lastDate = current.lastDate ?? event.timestamp
            let reaction = current.lastReaction ?? (event.reaction != .none ? event.reaction : nil)
            siteStats[event.siteId] = (lastDate, current.count + 1, reaction)
        }

        // Calculate SiteStatus for all sites
        var statuses: [SiteRotationStatus] = []
        for (index, site) in sitesPool.enumerated() {
            let stat = siteStats[site.id] ?? (nil, 0, nil)
            let daysSince: Int?
            let restingScore: Double

            if let lastDate = stat.lastDate {
                let diff = calendar.dateComponents([.day], from: lastDate, to: currentDate).day ?? 0
                let days = max(0, diff)
                daysSince = days

                // 7 days = 100% rest score, linear ramp 0..100%
                if days >= 7 {
                    restingScore = 100.0
                } else {
                    restingScore = min(100.0, max(0.0, Double(days) / 7.0 * 100.0))
                }
            } else {
                daysSince = nil
                restingScore = 100.0 // Pristine / never used
            }

            let isLast = lastSite?.id == site.id

            statuses.append(
                SiteRotationStatus(
                    site: site,
                    lastUsedDate: stat.lastDate,
                    daysSinceLastUse: daysSince,
                    timesUsedTotal: stat.count,
                    restingScore: restingScore,
                    isRecommended: false,
                    isLastUsed: isLast,
                    activeReaction: stat.lastReaction,
                    orderIndex: index
                )
            )
        }

        // Determine Next Recommended Site according to User's Strategy Pattern
        let (nextSite, reason) = determineNextSite(
            candidateSites: candidateSites,
            statuses: statuses,
            lastSite: lastSite,
            strategy: strategy
        )

        // Mark the selected site as recommended in the returned statuses
        let updatedStatuses = statuses.map { status in
            SiteRotationStatus(
                site: status.site,
                lastUsedDate: status.lastUsedDate,
                daysSinceLastUse: status.daysSinceLastUse,
                timesUsedTotal: status.timesUsedTotal,
                restingScore: status.restingScore,
                isRecommended: status.site.id == nextSite.id,
                isLastUsed: status.isLastUsed,
                activeReaction: status.activeReaction,
                orderIndex: status.orderIndex
            )
        }

        return SiteRotationResult(
            lastSite: lastSite,
            nextSite: nextSite,
            lastEvent: lastEvent,
            siteStatuses: updatedStatuses,
            enforcedStrategy: strategy,
            strategyReason: reason,
            evaluatedAt: currentDate
        )
    }

    // MARK: - 2. Compatibility Evaluation from DoseLogs

    public func evaluateRotation(
        history: [DoseLog],
        availableSites: [InjectionSite] = InjectionSite.standardSites,
        strategy: SiteRotationStrategy = .bilateralAlternating,
        targetRegion: BodyRegion? = nil,
        currentDate: Date = Date()
    ) -> SiteRotationResult {
        // Convert taken dose logs into equivalent InjectionSiteEvents
        let siteEvents: [InjectionSiteEvent] = history
            .filter { $0.status == .taken && $0.injectionSiteId != nil }
            .compactMap { log -> InjectionSiteEvent? in
                guard let siteId = log.injectionSiteId else { return nil }
                let site = availableSites.first(where: { $0.id == siteId }) ?? InjectionSite.standardSites.first(where: { $0.id == siteId })
                let timestamp = log.loggedDate ?? log.scheduledDate
                return InjectionSiteEvent(
                    id: log.id,
                    doseEventId: log.id,
                    siteId: siteId,
                    siteName: log.injectionSiteName ?? site?.name ?? siteId,
                    region: site?.region ?? .abdomen,
                    side: site?.side ?? .left,
                    quadrant: site?.quadrant,
                    route: log.actualRoute,
                    timestamp: timestamp,
                    compoundId: log.compoundId,
                    compoundName: log.compoundName,
                    doseAmount: log.actualDoseAmount,
                    doseUnit: log.doseUnit,
                    reaction: .none,
                    painScore: 0,
                    notes: log.notes
                )
            }

        return evaluateNextSite(
            siteEvents: siteEvents,
            availableSites: availableSites,
            strategy: strategy,
            targetRegion: targetRegion,
            currentDate: currentDate
        )
    }

    /// Backwards-compatible `analyzeRotation` signature returning `[SiteStatus]`.
    public func analyzeRotation(
        history: [DoseLog],
        allSites: [InjectionSite] = InjectionSite.standardSites,
        currentDate: Date = Date()
    ) -> [SiteRotationStatus] {
        let result = evaluateRotation(
            history: history,
            availableSites: allSites,
            strategy: .maximumRest,
            targetRegion: nil,
            currentDate: currentDate
        )
        return result.siteStatuses
    }

    // MARK: - 3. Strategy Pattern Enforcement Algorithms

    private func determineNextSite(
        candidateSites: [InjectionSite],
        statuses: [SiteRotationStatus],
        lastSite: InjectionSite?,
        strategy: SiteRotationStrategy
    ) -> (InjectionSite, String) {
        guard !candidateSites.isEmpty else {
            let fallback = InjectionSite.standardSites[0]
            return (fallback, "Default standard starting site.")
        }

        let statusMap = Dictionary(uniqueKeysWithValues: statuses.map { ($0.site.id, $0) })

        switch strategy {

        // MARK: Strategy A - Bilateral Alternating (Left ↔ Right)
        case .bilateralAlternating:
            guard let last = lastSite else {
                let first = candidateSites[0]
                return (first, "Pattern initialized: Starting with \(first.conciseDescription).")
            }

            let targetSide = last.side.opposite
            let oppositeSites = candidateSites.filter { $0.side == targetSide }

            let candidates = oppositeSites.isEmpty ? candidateSites : oppositeSites

            // Pick the best rested site on the target opposite side
            let best = candidates.max(by: { a, b in
                let statA = statusMap[a.id]?.restingScore ?? 100
                let statB = statusMap[b.id]?.restingScore ?? 100
                if statA != statB { return statA < statB }
                let useA = statusMap[a.id]?.timesUsedTotal ?? 0
                let useB = statusMap[b.id]?.timesUsedTotal ?? 0
                return useA > useB
            }) ?? candidates[0]

            let reason = "Enforcing 'Alternate Sides': Previous dose was on the \(last.side.rawValue.lowercased()) side (\(last.conciseDescription)). Next location switched to \(best.conciseDescription)."
            return (best, reason)

        // MARK: Strategy B - Clockwise Quadrants
        case .clockwise:
            let orderedSequence = getClockwiseOrder(from: candidateSites)
            guard let last = lastSite, let currentIndex = orderedSequence.firstIndex(where: { $0.id == last.id }) else {
                let first = orderedSequence.first ?? candidateSites[0]
                return (first, "Pattern initialized: Starting clockwise sequence at \(first.conciseDescription).")
            }

            let nextIndex = (currentIndex + 1) % orderedSequence.count
            let next = orderedSequence[nextIndex]
            let reason = "Enforcing 'Clockwise Quadrants': Advanced from \(last.conciseDescription) to \(next.conciseDescription)."
            return (next, reason)

        // MARK: Strategy C - Counter-Clockwise Quadrants
        case .counterClockwise:
            let orderedSequence = getClockwiseOrder(from: candidateSites)
            guard let last = lastSite, let currentIndex = orderedSequence.firstIndex(where: { $0.id == last.id }) else {
                let first = orderedSequence.first ?? candidateSites[0]
                return (first, "Pattern initialized: Starting counter-clockwise sequence at \(first.conciseDescription).")
            }

            let prevIndex = (currentIndex - 1 + orderedSequence.count) % orderedSequence.count
            let next = orderedSequence[prevIndex]
            let reason = "Enforcing 'Counter-Clockwise': Advanced from \(last.conciseDescription) to \(next.conciseDescription)."
            return (next, reason)

        // MARK: Strategy D - Maximum Rest (Least Recently Used)
        case .maximumRest:
            let best = candidateSites.max(by: { a, b in
                let statA = statusMap[a.id]
                let statB = statusMap[b.id]
                let daysA = statA?.daysSinceLastUse ?? Int.max
                let daysB = statB?.daysSinceLastUse ?? Int.max

                if daysA != daysB { return daysA < daysB }
                let scoreA = statA?.restingScore ?? 100
                let scoreB = statB?.restingScore ?? 100
                if scoreA != scoreB { return scoreA < scoreB }
                return (statA?.timesUsedTotal ?? 0) > (statB?.timesUsedTotal ?? 0)
            }) ?? candidateSites[0]

            let daysText = statusMap[best.id]?.daysSinceLastUse.map { "\($0) days rested" } ?? "Never used (pristine)"
            let reason = "Enforcing 'Maximum Rest': \(best.conciseDescription) has the highest tissue rest (\(daysText))."
            return (best, reason)

        // MARK: Strategy E - Balanced Usage (Least Frequently Used)
        case .leastFrequentlyUsed:
            let best = candidateSites.min(by: { a, b in
                let useA = statusMap[a.id]?.timesUsedTotal ?? 0
                let useB = statusMap[b.id]?.timesUsedTotal ?? 0
                if useA != useB { return useA < useB }
                let scoreA = statusMap[a.id]?.restingScore ?? 100
                let scoreB = statusMap[b.id]?.restingScore ?? 100
                return scoreA > scoreB
            }) ?? candidateSites[0]

            let count = statusMap[best.id]?.timesUsedTotal ?? 0
            let reason = "Enforcing 'Balanced Usage': \(best.conciseDescription) has the lowest lifetime administrations (\(count) total)."
            return (best, reason)

        // MARK: Strategy F - Sequential Order
        case .sequential:
            guard let last = lastSite, let currentIndex = candidateSites.firstIndex(where: { $0.id == last.id }) else {
                let first = candidateSites[0]
                return (first, "Pattern initialized: Starting sequential list with \(first.conciseDescription).")
            }

            let nextIndex = (currentIndex + 1) % candidateSites.count
            let next = candidateSites[nextIndex]
            let reason = "Enforcing 'Sequential Order': Advanced from site #\(currentIndex + 1) (\(last.shortName)) to site #\(nextIndex + 1) (\(next.shortName))."
            return (next, reason)

        // MARK: Strategy G - Cycle Body Regions
        case .regionCycling:
            let regionCycle: [BodyRegion] = [.abdomen, .thigh, .deltoid, .glute, .tricep]
            guard let last = lastSite, let currentRegionIdx = regionCycle.firstIndex(of: last.region) else {
                let first = candidateSites[0]
                return (first, "Pattern initialized: Starting region cycle with \(first.region.conciseName).")
            }

            // Find next region in cycle that exists in candidateSites
            var targetSite: InjectionSite?
            for offset in 1...regionCycle.count {
                let nextRegion = regionCycle[(currentRegionIdx + offset) % regionCycle.count]
                let matching = candidateSites.filter { $0.region == nextRegion }
                if let bestInRegion = matching.max(by: {
                    (statusMap[$0.id]?.restingScore ?? 100) < (statusMap[$1.id]?.restingScore ?? 100)
                }) {
                    targetSite = bestInRegion
                    break
                }
            }

            let next = targetSite ?? candidateSites[0]
            let reason = "Enforcing 'Region Cycling': Rotated from \(last.region.conciseName) to \(next.region.conciseName) (\(next.conciseDescription))."
            return (next, reason)
        }
    }

    // MARK: - 4. Clockwise Canonical Ordering Helper

    private func getClockwiseOrder(from sites: [InjectionSite]) -> [InjectionSite] {
        // Standard clockwise progression for abdomen quadrants:
        // Left Upper Outer -> Right Upper Outer -> Right Lower Outer -> Left Lower Outer
        let canonicalAbdomenIds = ["ab_l_uo", "ab_r_uo", "ab_r_lo", "ab_l_lo"]

        var ordered: [InjectionSite] = []

        // 1. Add canonical abdomen sites if present
        for siteId in canonicalAbdomenIds {
            if let found = sites.first(where: { $0.id == siteId }) {
                ordered.append(found)
            }
        }

        // 2. Add other sites not yet in ordered list (e.g. Thighs L->R, Deltoids L->R, Glutes L->R)
        let remaining = sites.filter { !ordered.contains($0) }
        ordered.append(contentsOf: remaining)

        return ordered.isEmpty ? sites : ordered
    }
}

/// Factory and alias for SiteRotationService.
public typealias SiteRotationService = SiteRotationEngine

