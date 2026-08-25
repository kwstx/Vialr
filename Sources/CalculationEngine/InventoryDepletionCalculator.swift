import Foundation
import Domain

/// Projects supply depletion rates, days of stock remaining, and expiration alerts.
public struct InventoryDepletionCalculator: Sendable {

    public struct VialDepletionForecast: Identifiable, Sendable {
        public let vial: Vial
        public let dailyConsumptionMl: Double
        public let daysRemaining: Int?
        public let estimatedDepletionDate: Date?
        public let isExpiringSoon: Bool // Expiration within 7 days
        public let isLowVolume: Bool   // Less than 20% remaining

        public var id: UUID { vial.id }

        public init(
            vial: Vial,
            dailyConsumptionMl: Double,
            daysRemaining: Int?,
            estimatedDepletionDate: Date?,
            isExpiringSoon: Bool,
            isLowVolume: Bool
        ) {
            self.vial = vial
            self.dailyConsumptionMl = dailyConsumptionMl
            self.daysRemaining = daysRemaining
            self.estimatedDepletionDate = estimatedDepletionDate
            self.isExpiringSoon = isExpiringSoon
            self.isLowVolume = isLowVolume
        }
    }

    public init() {}

    /// Forecasts vial depletion based on active protocol schedules.
    public func forecastVials(
        vials: [Vial],
        activeProtocols: [ProtocolModel],
        currentDate: Date = Date()
    ) -> [VialDepletionForecast] {
        let calendar = Calendar.current
        var forecasts: [VialDepletionForecast] = []

        for vial in vials {
            // Find active protocol items for this compound
            let matchingItems = activeProtocols
                .filter { $0.status == .active }
                .flatMap { $0.items }
                .filter { $0.compoundId == vial.compoundId }

            // Estimate daily volume usage in mL
            var totalDailyMl: Double = 0.0
            if let conc = vial.concentrationMgMl, conc > 0 {
                for item in matchingItems {
                    let doseMg = convertToMg(amount: item.doseAmount, unit: item.doseUnit)
                    let doseMl = doseMg / conc
                    let dosesPerDay = calculateDosesPerDay(rule: item.scheduleRule)
                    totalDailyMl += (doseMl * dosesPerDay)
                }
            }

            let daysRemaining: Int?
            let depletionDate: Date?

            if totalDailyMl > 0, let remMl = vial.currentVolumeRemainingMl, remMl > 0 {
                let days = Int(ceil(remMl / totalDailyMl))
                daysRemaining = days
                depletionDate = calendar.date(byAdding: .day, value: days, to: currentDate)
            } else {
                daysRemaining = nil
                depletionDate = nil
            }

            // Expiration check (within 7 days)
            var expiringSoon = false
            if let expDate = vial.expirationDate {
                let daysToExp = calendar.dateComponents([.day], from: currentDate, to: expDate).day ?? 999
                expiringSoon = daysToExp <= 7 && daysToExp >= 0
            }

            let lowVol = (vial.remainingFraction <= 0.20 && vial.isReconstituted)

            forecasts.append(
                VialDepletionForecast(
                    vial: vial,
                    dailyConsumptionMl: totalDailyMl,
                    daysRemaining: daysRemaining,
                    estimatedDepletionDate: depletionDate,
                    isExpiringSoon: expiringSoon,
                    isLowVolume: lowVol
                )
            )
        }

        return forecasts
    }

    private func convertToMg(amount: Double, unit: DoseUnit) -> Double {
        switch unit {
        case .mg: return amount
        case .mcg: return amount / 1000.0
        case .iu: return amount / 3.0
        case .ml: return amount // fallback
        }
    }

    private func calculateDosesPerDay(rule: ScheduleRule) -> Double {
        switch rule {
        case .everyDay: return 1.0
        case .everyOtherDay: return 0.5
        case .daysOfWeek(let days): return Double(days.count) / 7.0
        case .cycle(let daysOn, let daysOff):
            let total = Double(daysOn + daysOff)
            return total > 0 ? Double(daysOn) / total : 1.0
        case .everyNDays(let n): return n > 0 ? 1.0 / Double(n) : 1.0
        case .customInterval(let hours): return hours > 0 ? 24.0 / Double(hours) : 1.0
        case .asNeeded: return 0.25
        }
    }
}
