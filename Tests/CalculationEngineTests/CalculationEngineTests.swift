import XCTest
import Domain
@testable import CalculationEngine

final class CalculationEngineTests: XCTestCase {

    func testReconstitution5mgIn2mlFor250mcg() {
        let calc = ReconstitutionCalculator()
        let result = calc.calculate(
            dryMassMg: 5.0,
            diluentVolumeMl: 2.0,
            targetDoseAmount: 250.0,
            targetDoseUnit: .mcg,
            vialCostUsd: 50.0
        )

        // 5mg / 2mL = 2.5 mg/mL = 2500 mcg/mL
        XCTAssertEqual(result.concentrationMgMl, 2.5, accuracy: 0.001)
        XCTAssertEqual(result.concentrationMcgMl, 2500.0, accuracy: 0.001)

        // 250 mcg / 2500 mcg/mL = 0.1 mL
        XCTAssertEqual(result.drawVolumeMl, 0.1, accuracy: 0.001)

        // 0.1 mL * 100 = 10 units on U-100 syringe
        XCTAssertEqual(result.u100Units, 10.0, accuracy: 0.001)

        // Total doses = 5000 mcg / 250 mcg = 20 doses
        XCTAssertEqual(result.totalDosesInVial, 20.0, accuracy: 0.001)

        // Cost per dose = $50 / 20 = $2.50
        XCTAssertEqual(result.costPerDoseUsd ?? 0.0, 2.50, accuracy: 0.001)
    }

    func testReverseCalculateDose() {
        let calc = ReconstitutionCalculator()
        // 10 units on U-100 with 2.5 mg/mL concentration -> should equal 250 mcg
        let mcg = calc.reverseCalculateDose(u100Units: 10.0, concentrationMgMl: 2.5, desiredUnit: .mcg)
        XCTAssertEqual(mcg, 250.0, accuracy: 0.001)
    }

    func testSiteRotationEngineRestedRecommendation() {
        let engine = SiteRotationEngine()
        let cal = Calendar.current
        let now = Date()

        // Dose taken yesterday at ab_l_uo
        let log = DoseLog(
            compoundId: UUID(),
            compoundName: "BPC-157",
            scheduledDate: now,
            loggedDate: cal.date(byAdding: .day, value: -1, to: now),
            doseAmount: 250,
            doseUnit: .mcg,
            status: .taken,
            injectionSiteId: "ab_l_uo"
        )

        let analysis = engine.analyzeRotation(history: [log], currentDate: now)

        let ab_l_uo = analysis.first(where: { $0.site.id == "ab_l_uo" })
        XCTAssertEqual(ab_l_uo?.daysSinceLastUse, 1)

        let recommended = analysis.first(where: { $0.isRecommended })
        XCTAssertNotNil(recommended)
        XCTAssertNotEqual(recommended?.site.id, "ab_l_uo")
    }

    func testInconsistencyDetectorOutlierDose() {
        let detector = InconsistencyDetector()
        let compound = Compound(name: "BPC-157", shortCode: "BPC", category: .recovery, defaultUnit: .mcg, typicalDose: 250)

        // Candidate enters 2500mcg (10x typical dose)
        let candidate = DoseLog(
            compoundId: compound.id,
            compoundName: compound.name,
            scheduledDate: Date(),
            doseAmount: 2500,
            doseUnit: .mcg
        )

        let warnings = detector.evaluateDoseEntry(candidate: candidate, compound: compound, recentLogs: [])
        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains(where: { $0.title.contains("Unusually High Dose") }))
    }
}
