import Foundation
import Domain

/// Pharmacokinetic modeling engine for half-life clearance curves and active serum concentration estimation.
public struct HalfLifeEstimator: Sendable {

    public struct SerumDataPoint: Identifiable, Sendable, Hashable {
        public let id: UUID
        public let date: Date
        public let activeLevelMg: Double
        public let compoundName: String

        public init(id: UUID = UUID(), date: Date, activeLevelMg: Double, compoundName: String) {
            self.id = id
            self.date = date
            self.activeLevelMg = activeLevelMg
            self.compoundName = compoundName
        }
    }

    public init() {}

    /// Calculates estimated serum concentration curve for a given compound over a timeline.
    public func estimateClearanceCurve(
        doseLogs: [DoseLog],
        halfLifeHours: Double,
        compoundName: String,
        startDate: Date,
        endDate: Date,
        intervalHours: Int = 4
    ) -> [SerumDataPoint] {
        guard halfLifeHours > 0 else { return [] }

        let completedDoses = doseLogs
            .filter { $0.status == .taken }
            .sorted(by: { ($0.loggedDate ?? $0.scheduledDate) < ($1.loggedDate ?? $1.scheduledDate) })

        var dataPoints: [SerumDataPoint] = []
        var currentTime = startDate

        let stepSeconds = Double(intervalHours) * 3600.0

        while currentTime <= endDate {
            var activeTotalMg: Double = 0.0

            for dose in completedDoses {
                let doseDate = dose.loggedDate ?? dose.scheduledDate
                guard doseDate <= currentTime else { continue }

                let elapsedHours = currentTime.timeIntervalSince(doseDate) / 3600.0
                let doseMg = dose.doseUnit == .mg ? dose.doseAmount : (dose.doseAmount / 1000.0)

                // First-order elimination: C(t) = D * (0.5)^(elapsed / halfLife)
                let remainingFraction = pow(0.5, elapsedHours / halfLifeHours)
                
                // Only consider non-negligible levels (>5 half-lives is <3.125%)
                if elapsedHours <= (halfLifeHours * 6.0) {
                    activeTotalMg += (doseMg * remainingFraction)
                }
            }

            dataPoints.append(
                SerumDataPoint(
                    date: currentTime,
                    activeLevelMg: max(0.0, activeTotalMg),
                    compoundName: compoundName
                )
            )

            currentTime = currentTime.addingTimeInterval(stepSeconds)
        }

        return dataPoints
    }
}
