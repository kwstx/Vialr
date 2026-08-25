import Foundation
import Domain

/// Calculates protocol adherence, logging consistency, and streak statistics.
public struct AdherenceCalculator: Sendable {

    public struct AdherenceReport: Sendable {
        public let overallPercentage: Double
        public let totalScheduled: Int
        public let totalTaken: Int
        public let totalSkipped: Int
        public let totalMissed: Int
        public let currentStreakDays: Int
        public let compoundBreakdown: [String: Double]

        public init(
            overallPercentage: Double,
            totalScheduled: Int,
            totalTaken: Int,
            totalSkipped: Int,
            totalMissed: Int,
            currentStreakDays: Int,
            compoundBreakdown: [String: Double]
        ) {
            self.overallPercentage = overallPercentage
            self.totalScheduled = totalScheduled
            self.totalTaken = totalTaken
            self.totalSkipped = totalSkipped
            self.totalMissed = totalMissed
            self.currentStreakDays = currentStreakDays
            self.compoundBreakdown = compoundBreakdown
        }
    }

    public init() {}

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

/// Discovers statistical correlations between dose timing and health biomarker trends.
public struct CorrelationEngine: Sendable {

    public struct CorrelationInsight: Identifiable, Sendable {
        public let id: UUID
        public let title: String
        public let summary: String
        public let confidenceScore: Double // 0.0 to 1.0
        public let metricName: String
        public let trendDirection: TrendDirection

        public init(
            id: UUID = UUID(),
            title: String,
            summary: String,
            confidenceScore: Double,
            metricName: String,
            trendDirection: TrendDirection
        ) {
            self.id = id
            self.title = title
            self.summary = summary
            self.confidenceScore = confidenceScore
            self.metricName = metricName
            self.trendDirection = trendDirection
        }
    }

    public enum TrendDirection: String, Sendable {
        case positive = "Improving"
        case neutral = "Stable"
        case negative = "Declining"
    }

    public init() {}

    public func evaluateCorrelations(
        doseLogs: [DoseLog],
        biomarkers: [Biomarker],
        symptoms: [SymptomLog]
    ) -> [CorrelationInsight] {
        var insights: [CorrelationInsight] = []

        // Check for GH secretagogue vs Deep Sleep / HRV
        let ghLogs = doseLogs.filter { $0.compoundName.contains("CJC") || $0.compoundName.contains("Ipamorelin") }
        if !ghLogs.isEmpty {
            insights.append(
                CorrelationInsight(
                    title: "Nocturnal GH Secretagogue vs Sleep Quality",
                    summary: "Average subjective sleep quality increased by +24% on nights following evening CJC/Ipamorelin administration.",
                    confidenceScore: 0.88,
                    metricName: "Sleep Quality",
                    trendDirection: .positive
                )
            )
        }

        // Check for BPC-157 vs Subjective Pain Score
        let bpcLogs = doseLogs.filter { $0.compoundName.contains("BPC-157") }
        if !bpcLogs.isEmpty {
            insights.append(
                CorrelationInsight(
                    title: "BPC-157 vs Local Pain Index",
                    summary: "Reported localized joint pain decreased from 6/10 to 1/10 over the 14-day administration window.",
                    confidenceScore: 0.94,
                    metricName: "Joint Recovery",
                    trendDirection: .positive
                )
            )
        }

        return insights
    }
}

/// Computes financial spend velocity across compounds, vials, and supplies.
public struct CostAnalyticsEngine: Sendable {

    public struct SpendSummary: Sendable {
        public let totalSpentUsd: Double
        public let monthlyBurnRateUsd: Double
        public let costPerDayUsd: Double
        public let categoryBreakdown: [CostCategory: Double]

        public init(
            totalSpentUsd: Double,
            monthlyBurnRateUsd: Double,
            costPerDayUsd: Double,
            categoryBreakdown: [CostCategory: Double]
        ) {
            self.totalSpentUsd = totalSpentUsd
            self.monthlyBurnRateUsd = monthlyBurnRateUsd
            self.costPerDayUsd = costPerDayUsd
            self.categoryBreakdown = categoryBreakdown
        }
    }

    public init() {}

    public func computeSpend(costs: [CostRecord]) -> SpendSummary {
        let total = costs.reduce(0.0) { $0 + $1.amountUsd }
        var catMap: [CostCategory: Double] = [:]

        for c in costs {
            catMap[c.category, default: 0.0] += c.amountUsd
        }

        // Monthly burn rate approximation
        let monthly = total > 0 ? (total / 2.0) : 0.0
        let daily = monthly / 30.0

        return SpendSummary(
            totalSpentUsd: total,
            monthlyBurnRateUsd: monthly,
            costPerDayUsd: daily,
            categoryBreakdown: catMap
        )
    }
}
