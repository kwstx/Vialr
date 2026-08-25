import XCTest
import Domain
import CalculationEngine
@testable import Analytics

final class AnalyticsTests: XCTestCase {

    func testAdherenceCalculation() {
        let calculator = AdherenceCalculator()
        let bpcId = UUID()

        let logs = [
            DoseLog(compoundId: bpcId, compoundName: "BPC-157", scheduledDate: Date(), status: .taken, doseAmount: 250),
            DoseLog(compoundId: bpcId, compoundName: "BPC-157", scheduledDate: Date(), status: .taken, doseAmount: 250),
            DoseLog(compoundId: bpcId, compoundName: "BPC-157", scheduledDate: Date(), status: .taken, doseAmount: 250),
            DoseLog(compoundId: bpcId, compoundName: "BPC-157", scheduledDate: Date(), status: .missed, doseAmount: 250)
        ]

        let report = calculator.calculateAdherence(logs: logs)

        // 3 taken out of 4 total = 75%
        XCTAssertEqual(report.overallPercentage, 75.0, accuracy: 0.001)
        XCTAssertEqual(report.totalTaken, 3)
        XCTAssertEqual(report.totalMissed, 1)
    }

    func testHalfLifeClearanceCurveDecay() {
        let estimator = HalfLifeEstimator()
        let cal = Calendar.current
        let doseDate = cal.date(byAdding: .hour, value: -24, to: Date())!

        let log = DoseLog(
            compoundId: UUID(),
            compoundName: "BPC-157",
            scheduledDate: doseDate,
            loggedDate: doseDate,
            doseAmount: 1000, // 1 mg = 1000 mcg
            doseUnit: .mcg,
            status: .taken
        )

        // Half life 4 hours. After 24 hours = 6 half-lives.
        // Remaining: 1mg * (0.5)^6 = 1mg / 64 = ~0.0156 mg
        let curve = estimator.estimateClearanceCurve(
            doseLogs: [log],
            halfLifeHours: 4.0,
            compoundName: "BPC-157",
            startDate: doseDate,
            endDate: Date(),
            intervalHours: 4
        )

        XCTAssertFalse(curve.isEmpty)
        let initialPoint = curve.first(where: { $0.date == doseDate })
        XCTAssertEqual(initialPoint?.activeLevelMg ?? 0, 1.0, accuracy: 0.01)
    }
}
