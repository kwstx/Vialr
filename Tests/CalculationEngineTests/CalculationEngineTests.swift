import XCTest
import Domain
@testable import CalculationEngine

final class CalculationEngineTests: XCTestCase {

    // MARK: - 1. Unit Normalization Tests

    func testMassUnitNormalization() {
        let oneGram = MassQuantity(1.0, .g)
        XCTAssertEqual(oneGram.mg, 1000.0, accuracy: 0.0001)
        XCTAssertEqual(oneGram.mcg, 1_000_000.0, accuracy: 0.0001)

        let fiveMg = MassQuantity(5.0, .mg)
        XCTAssertEqual(fiveMg.mg, 5.0, accuracy: 0.0001)
        XCTAssertEqual(fiveMg.mcg, 5000.0, accuracy: 0.0001)
        XCTAssertEqual(fiveMg.g, 0.005, accuracy: 0.000001)

        let fiveHundredMcg = MassQuantity(500.0, .mcg)
        XCTAssertEqual(fiveHundredMcg.mg, 0.5, accuracy: 0.0001)
        XCTAssertEqual(fiveHundredMcg.mcg, 500.0, accuracy: 0.0001)

        let nano = MassQuantity(100_000.0, .ng)
        XCTAssertEqual(nano.mg, 0.1, accuracy: 0.0001)
        XCTAssertEqual(nano.mcg, 100.0, accuracy: 0.0001)
    }

    func testVolumeUnitNormalization() {
        let twoMl = VolumeQuantity(2.0, .ml)
        XCTAssertEqual(twoMl.ml, 2.0, accuracy: 0.0001)
        XCTAssertEqual(twoMl.mcl, 2000.0, accuracy: 0.0001)
        XCTAssertEqual(twoMl.l, 0.002, accuracy: 0.000001)

        let microliters = VolumeQuantity(500.0, .mcl)
        XCTAssertEqual(microliters.ml, 0.5, accuracy: 0.0001)

        let cc = VolumeQuantity(3.0, .cc)
        XCTAssertEqual(cc.ml, 3.0, accuracy: 0.0001)
    }

    // MARK: - 2. Dimensional Validation Tests

    func testRejectsNonPositiveInputs() {
        let calc = ReconstitutionCalculator()

        // Zero dry mass
        let zeroMassInput = ReconstitutionInput(
            dryMass: MassQuantity(0.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(250.0, .mcg))
        )
        XCTAssertThrowsError(try calc.calculate(zeroMassInput)) { error in
            guard case ReconstitutionCalculationError.nonPositiveDryMass = error else {
                XCTFail("Expected nonPositiveDryMass error, got: \(error)")
                return
            }
        }

        // Negative diluent volume
        let negVolInput = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(-1.0, .ml),
            targetDose: .mass(MassQuantity(250.0, .mcg))
        )
        XCTAssertThrowsError(try calc.calculate(negVolInput)) { error in
            guard case ReconstitutionCalculationError.nonPositiveDiluentVolume = error else {
                XCTFail("Expected nonPositiveDiluentVolume error, got: \(error)")
                return
            }
        }

        // Zero target dose
        let zeroDoseInput = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(0.0, .mcg))
        )
        XCTAssertThrowsError(try calc.calculate(zeroDoseInput)) { error in
            guard case ReconstitutionCalculationError.nonPositiveTargetDose = error else {
                XCTFail("Expected nonPositiveTargetDose error, got: \(error)")
                return
            }
        }
    }

    func testRejectsMissingBiologicalActivityConversion() {
        let calc = ReconstitutionCalculator()

        let iuInputWithoutRatio = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .biologicalActivity(iu: 3.0),
            compoundActivity: nil,
            compoundName: "Somatropin"
        )

        XCTAssertThrowsError(try calc.calculate(iuInputWithoutRatio)) { error in
            guard case ReconstitutionCalculationError.missingBiologicalConversionRatio = error else {
                XCTFail("Expected missingBiologicalConversionRatio, got: \(error)")
                return
            }
        }
    }

    func testRejectsUnrealisticVialCapacity() {
        let calc = ReconstitutionCalculator()

        let hugeVolInput = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(500.0, .ml),
            targetDose: .mass(MassQuantity(250.0, .mcg))
        )

        XCTAssertThrowsError(try calc.calculate(hugeVolInput)) { error in
            guard case ReconstitutionCalculationError.unrealisticVialCapacity = error else {
                XCTFail("Expected unrealisticVialCapacity error, got: \(error)")
                return
            }
        }
    }

    // MARK: - 3. Forward Reconstitution Calculation Tests

    func testStandardReconstitution5mgIn2mlFor250mcg() throws {
        let calc = ReconstitutionCalculator()
        let input = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(250.0, .mcg)),
            syringeSpecification: .u100_50unit,
            vialCostUsd: 50.0,
            compoundName: "BPC-157"
        )

        let result = try calc.calculate(input)

        // Concentration: 5 mg / 2 mL = 2.5 mg/mL = 2500 mcg/mL
        XCTAssertEqual(result.concentrationMgMl, 2.5, accuracy: 0.001)
        XCTAssertEqual(result.concentrationMcgMl, 2500.0, accuracy: 0.001)

        // Target dose: 250 mcg = 0.25 mg
        XCTAssertEqual(result.normalizedDoseMg, 0.25, accuracy: 0.001)
        XCTAssertEqual(result.normalizedDoseMcg, 250.0, accuracy: 0.001)

        // Draw volume: 0.25 mg / 2.5 mg/mL = 0.1 mL = 100 mcL
        XCTAssertEqual(result.drawVolumeMl, 0.1, accuracy: 0.001)
        XCTAssertEqual(result.drawVolumeMcl, 100.0, accuracy: 0.001)

        // Syringe markings:
        // U-100: 0.1 mL * 100 = 10.0 units
        XCTAssertEqual(result.u100Units, 10.0, accuracy: 0.001)
        // U-40: 0.1 mL * 40 = 4.0 units
        XCTAssertEqual(result.u40Units, 4.0, accuracy: 0.001)
        XCTAssertEqual(result.selectedSyringeUnits, 10.0, accuracy: 0.001)

        // Syringe Geometry: 0.1 mL in 0.5 mL barrel = 20% fill fraction
        XCTAssertEqual(result.syringeBarrelFillFraction, 0.2, accuracy: 0.001)
        XCTAssertTrue(result.isWithinSyringeCapacity)

        // Yield: 5.0 mg / 0.25 mg = 20 doses
        XCTAssertEqual(result.totalDosesInVial, 20.0, accuracy: 0.001)
        XCTAssertEqual(result.exactDosesCount, 20)
        XCTAssertEqual(result.remainingResidualDose, 0.0, accuracy: 0.001)

        // Economics: $50 / 20 doses = $2.50 / dose
        XCTAssertEqual(result.costPerDoseUsd ?? 0.0, 2.50, accuracy: 0.001)
        XCTAssertEqual(result.costPerMgUsd ?? 0.0, 10.00, accuracy: 0.001)

        // Derivation Steps: 6 steps generated
        XCTAssertEqual(result.derivationSteps.count, 6)
        XCTAssertFalse(result.summaryExplanation.isEmpty)
        XCTAssertFalse(result.clinicalInstructions.isEmpty)
    }

    func testReconstitutionWithCrossUnitInputs() throws {
        let calc = ReconstitutionCalculator()

        // 10,000 mcg powder (10 mg) + 2000 mcL BAC water (2 mL) + 0.5 mg dose (500 mcg)
        let input = ReconstitutionInput(
            dryMass: MassQuantity(10_000.0, .mcg),
            diluentVolume: VolumeQuantity(2000.0, .mcl),
            targetDose: .mass(MassQuantity(0.5, .mg)),
            syringeSpecification: .u100_100unit
        )

        let result = try calc.calculate(input)

        XCTAssertEqual(result.concentrationMgMl, 5.0, accuracy: 0.001)
        XCTAssertEqual(result.concentrationMcgMl, 5000.0, accuracy: 0.001)
        XCTAssertEqual(result.drawVolumeMl, 0.1, accuracy: 0.001)
        XCTAssertEqual(result.u100Units, 10.0, accuracy: 0.001)
        XCTAssertEqual(result.totalDosesInVial, 20.0, accuracy: 0.001)
    }

    func testBiologicalActivityReconstitution() throws {
        let calc = ReconstitutionCalculator()

        // Somatropin GH: 3.333 mg in 2.0 mL BAC water for a 3.0 IU dose
        // Somatropin standard: 1 mg = 3.0 IU -> 3.333 mg = 10.0 IU
        let ratio = CompoundActivityRatio.standardSomatropin
        let input = ReconstitutionInput(
            dryMass: MassQuantity(3.333333, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .biologicalActivity(iu: 3.0),
            compoundActivity: ratio,
            compoundName: "Somatropin GH"
        )

        let result = try calc.calculate(input)

        // Concentration = 3.333333 mg / 2.0 mL = 1.6666 mg/mL = 5.0 IU/mL
        XCTAssertEqual(result.concentrationMgMl, 1.6666, accuracy: 0.01)
        XCTAssertEqual(result.concentrationIuMl ?? 0, 5.0, accuracy: 0.01)

        // 3.0 IU dose = 1.0 mg -> 1.0 mg / 1.6666 mg/mL = 0.6 mL
        XCTAssertEqual(result.drawVolumeMl, 0.6, accuracy: 0.01)
        XCTAssertEqual(result.u100Units, 60.0, accuracy: 0.01)
    }

    func testSyringeCapacityOverflowWarning() throws {
        let calc = ReconstitutionCalculator()

        // Target dose requires 0.4 mL, but syringe is 0.3 mL (30 units)
        let input = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(1000.0, .mcg)), // 1.0 mg -> 0.4 mL draw
            syringeSpecification: .u100_30unit
        )

        let result = try calc.calculate(input)

        XCTAssertFalse(result.isWithinSyringeCapacity)
        XCTAssertGreaterThan(result.syringeBarrelFillFraction, 1.0)
        XCTAssertTrue(result.warnings.contains(where: { $0.id == "syringe_overflow" }))
    }

    // MARK: - 4. Multi-Way Solver Tests

    func testDiluentVolumeSolver() throws {
        let calc = ReconstitutionCalculator()

        // User has a 10 mg Tirzepatide vial, wants 500 mcg dose to be exactly 10 units (0.1 mL) on U-100 syringe
        let solverInput = DiluentSolverInput(
            dryMass: MassQuantity(10.0, .mg),
            targetDose: .mass(MassQuantity(500.0, .mcg)),
            desiredSyringeUnits: 10.0,
            syringeType: .u100
        )

        let result = try calc.solveRequiredDiluentVolume(solverInput)

        // 500 mcg (0.5 mg) in 0.1 mL requires 5.0 mg/mL concentration.
        // 10 mg dry mass / 5.0 mg/mL = 2.0 mL required diluent.
        XCTAssertEqual(result.recommendedDiluentVolumeMl, 2.0, accuracy: 0.001)
        XCTAssertEqual(result.resultingConcentrationMgMl, 5.0, accuracy: 0.001)
        XCTAssertEqual(result.totalDosesInVial, 20.0, accuracy: 0.001)
        XCTAssertEqual(result.derivationSteps.count, 3)
    }

    func testReverseDoseFromSyringe() throws {
        let calc = ReconstitutionCalculator()

        // User drew 15 units on U-100 syringe from a 2.5 mg/mL vial
        let reverseInput = ReverseDoseInput(
            drawnSyringeUnits: 15.0,
            syringeType: .u100,
            concentrationMgMl: 2.5
        )

        let result = try calc.reverseCalculateDoseFromSyringe(reverseInput)

        // 15 units = 0.15 mL
        XCTAssertEqual(result.drawnVolumeMl, 0.15, accuracy: 0.001)
        // 0.15 mL * 2.5 mg/mL = 0.375 mg = 375 mcg
        XCTAssertEqual(result.administeredDoseMg, 0.375, accuracy: 0.001)
        XCTAssertEqual(result.administeredDoseMcg, 375.0, accuracy: 0.001)
    }

    // MARK: - 5. Backwards Compatibility Tests

    func testLegacyCalculateSignature() {
        let calc = ReconstitutionCalculator()
        let result = calc.calculate(
            dryMassMg: 5.0,
            diluentVolumeMl: 2.0,
            targetDoseAmount: 250.0,
            targetDoseUnit: .mcg,
            vialCostUsd: 50.0
        )

        XCTAssertEqual(result.concentrationMgMl, 2.5, accuracy: 0.001)
        XCTAssertEqual(result.drawVolumeMl, 0.1, accuracy: 0.001)
        XCTAssertEqual(result.u100Units, 10.0, accuracy: 0.001)
    }

    func testLegacyReverseCalculateDose() {
        let calc = ReconstitutionCalculator()
        let mcg = calc.reverseCalculateDose(u100Units: 10.0, concentrationMgMl: 2.5, desiredUnit: .mcg)
        XCTAssertEqual(mcg, 250.0, accuracy: 0.001)
    }

    // MARK: - 6. Site Rotation & Inconsistency Detector Engine Tests

    func testSiteRotationEngineRestedRecommendation() {
        let engine = SiteRotationEngine()
        let cal = Calendar.current
        let now = Date()

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
