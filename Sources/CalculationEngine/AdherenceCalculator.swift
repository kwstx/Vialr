import Foundation
import Domain

/// Calculates protocol adherence, logging consistency, and streak statistics.
public struct AdherenceCalculator: Sendable {

    public init() {}

    /// Evaluates history of dose logs and computes comprehensive adherence and streak analytics.
    public func calculateAdherence(logs: [DoseLog]) -> AdherenceReport {
        guard !logs.isEmpty else {
            return AdherenceReport(
                overallPercentage: 100.0,
                totalScheduled: 0,
                totalTaken: 0,
                totalSkipped: 0,
                totalMissed: 0,
                currentStreakDays: 0,
                compoundBreakdown: [:]
            )
        }

        let takenCount = logs.filter { $0.status == .taken }.count
        let skippedCount = logs.filter { $0.status == .skipped }.count
        let missedCount = logs.filter { $0.status == .missed }.count
        let total = logs.count

        let percentage = Double(takenCount) / Double(max(1, total)) * 100.0

        // Calculate compound breakdown
        var breakdown: [String: (taken: Int, total: Int)] = [:]
        for log in logs {
            var curr = breakdown[log.compoundName] ?? (0, 0)
            curr.total += 1
            if log.status == .taken {
                curr.taken += 1
            }
            breakdown[log.compoundName] = curr
        }

        var compPct: [String: Double] = [:]
        for (comp, val) in breakdown {
            compPct[comp] = Double(val.taken) / Double(max(1, val.total)) * 100.0
        }

        // Streak calculation (consecutive days with at least one taken dose)
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()

        let takenDates = Set(logs.filter { $0.status == .taken }.compactMap {
            calendar.startOfDay(for: $0.loggedDate ?? $0.scheduledDate)
        })

        while takenDates.contains(calendar.startOfDay(for: checkDate)) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }

        return AdherenceReport(
            overallPercentage: percentage,
            totalScheduled: total,
            totalTaken: takenCount,
            totalSkipped: skippedCount,
            totalMissed: missedCount,
            currentStreakDays: streak,
            compoundBreakdown: compPct
        )
    }
}
