import XCTest
import Domain
@testable import CalculationEngine

final class ExtensiveCalculationEngineTests: XCTestCase {

    private var calculator: ReconstitutionCalculator!

    override func setUp() {
        super.setUp()
        calculator = ReconstitutionCalculator()
    }

    // MARK: - 1. Normal Inputs Matrix

    func testNormalReconstitutionMatrix() throws {
        // Case A: BPC-157 (5 mg in 2.0 mL BAC water, target dose 250 mcg)
        let bpcInput = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(250.0, .mcg)),
            syringeSpecification: .u100_50unit,
            vialCostUsd: 45.0,
            compoundName: "BPC-157"
        )
        let bpcResult = try calculator.calculate(bpcInput)
        XCTAssertEqual(bpcResult.concentrationMgMl, 2.5, accuracy: 0.0001)
        XCTAssertEqual(bpcResult.concentrationMcgMl, 2500.0, accuracy: 0.0001)
        XCTAssertEqual(bpcResult.drawVolumeMl, 0.1, accuracy: 0.0001)
        XCTAssertEqual(bpcResult.drawVolumeMcl, 100.0, accuracy: 0.0001)
        XCTAssertEqual(bpcResult.u100Units, 10.0, accuracy: 0.0001)
        XCTAssertEqual(bpcResult.u40Units, 4.0, accuracy: 0.0001)
        XCTAssertEqual(bpcResult.totalDosesInVial, 20.0, accuracy: 0.0001)
        XCTAssertEqual(bpcResult.exactDosesCount, 20)
        XCTAssertEqual(bpcResult.costPerDoseUsd ?? 0, 2.25, accuracy: 0.0001)
        XCTAssertTrue(bpcResult.isWithinSyringeCapacity)
        XCTAssertTrue(bpcResult.warnings.isEmpty)

        // Case B: TB-500 (10 mg in 3.0 mL BAC water, target dose 2.5 mg)
        let tbInput = ReconstitutionInput(
            dryMass: MassQuantity(10.0, .mg),
            diluentVolume: VolumeQuantity(3.0, .ml),
            targetDose: .mass(MassQuantity(2.5, .mg)),
            syringeSpecification: .u100_100unit,
            vialCostUsd: 80.0,
            compoundName: "TB-500"
        )
        let tbResult = try calculator.calculate(tbInput)
        XCTAssertEqual(tbResult.concentrationMgMl, 3.3333, accuracy: 0.001)
        XCTAssertEqual(tbResult.drawVolumeMl, 0.75, accuracy: 0.0001)
        XCTAssertEqual(tbResult.u100Units, 75.0, accuracy: 0.0001)
        XCTAssertEqual(tbResult.totalDosesInVial, 4.0, accuracy: 0.0001)
        XCTAssertEqual(tbResult.exactDosesCount, 4)
        XCTAssertEqual(tbResult.costPerDoseUsd ?? 0, 20.0, accuracy: 0.0001)

        // Case C: Tirzepatide (15 mg in 3.0 mL BAC water, target dose 5.0 mg)
        let tirzInput = ReconstitutionInput(
            dryMass: MassQuantity(15.0, .mg),
            diluentVolume: VolumeQuantity(3.0, .ml),
            targetDose: .mass(MassQuantity(5.0, .mg)),
            syringeSpecification: .u100_100unit,
            vialCostUsd: 120.0,
            compoundName: "Tirzepatide"
        )
        let tirzResult = try calculator.calculate(tirzInput)
        XCTAssertEqual(tirzResult.concentrationMgMl, 5.0, accuracy: 0.0001)
        XCTAssertEqual(tirzResult.drawVolumeMl, 1.0, accuracy: 0.0001)
        XCTAssertEqual(tirzResult.u100Units, 100.0, accuracy: 0.0001)
        XCTAssertEqual(tirzResult.totalDosesInVial, 3.0, accuracy: 0.0001)
        XCTAssertEqual(tirzResult.costPerDoseUsd ?? 0, 40.0, accuracy: 0.0001)
        XCTAssertTrue(tirzResult.isWithinSyringeCapacity)
    }

    // MARK: - 2. Boundary Values

    func testDrawVolumeBelowImprecisionThresholdWarning() throws {
        // Draw volume < 0.005 mL (e.g. 50 mcg target from a high concentration 50 mg/mL vial -> 0.001 mL = 0.1 units)
        let input = ReconstitutionInput(
            dryMass: MassQuantity(50.0, .mg),
            diluentVolume: VolumeQuantity(1.0, .ml),
            targetDose: .mass(MassQuantity(50.0, .mcg)),
            syringeSpecification: .u100_30unit
        )
        let result = try calculator.calculate(input)
        XCTAssertEqual(result.drawVolumeMl, 0.001, accuracy: 0.0001)
        XCTAssertTrue(result.warnings.contains(where: { $0.id == "imprecise_draw_volume" }))
    }

    func testHighConcentrationWarning() throws {
        // Concentration > 50.0 mg/mL
        let input = ReconstitutionInput(
            dryMass: MassQuantity(60.0, .mg),
            diluentVolume: VolumeQuantity(1.0, .ml),
            targetDose: .mass(MassQuantity(1.0, .mg))
        )
        let result = try calculator.calculate(input)
        XCTAssertEqual(result.concentrationMgMl, 60.0, accuracy: 0.0001)
        XCTAssertTrue(result.warnings.contains(where: { $0.id == "high_concentration" }))
    }

    func testSyringeCapacityBoundaryExactAndOverflow() throws {
        // Syringe is 0.5 mL (50 units U-100)
        // 1. Exact match (0.5 mL draw in 0.5 mL syringe) -> Within capacity
        let exactInput = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml), // Conc = 2.5 mg/mL
            targetDose: .mass(MassQuantity(1.25, .mg)), // Draw = 1.25 / 2.5 = 0.5 mL
            syringeSpecification: .u100_50unit
        )
        let exactResult = try calculator.calculate(exactInput)
        XCTAssertTrue(exactResult.isWithinSyringeCapacity)
        XCTAssertEqual(exactResult.syringeBarrelFillFraction, 1.0, accuracy: 0.0001)
        XCTAssertFalse(exactResult.warnings.contains(where: { $0.id == "syringe_overflow" }))

        // 2. Overflow (0.501 mL draw in 0.5 mL syringe) -> Exceeds capacity
        let overflowInput = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(1.26, .mg)), // Draw = 1.26 / 2.5 = 0.504 mL
            syringeSpecification: .u100_50unit
        )
        let overflowResult = try calculator.calculate(overflowInput)
        XCTAssertFalse(overflowResult.isWithinSyringeCapacity)
        XCTAssertGreaterThan(overflowResult.syringeBarrelFillFraction, 1.0)
        XCTAssertTrue(overflowResult.warnings.contains(where: { $0.id == "syringe_overflow" }))
    }

    func testDoseEqualAndExceedingTotalDryMass() throws {
        // 1. Dose exactly equals total dry mass
        let fullVialDose = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(5.0, .mg)),
            syringeSpecification: .u100_100unit
        )
        let fullResult = try calculator.calculate(fullVialDose)
        XCTAssertEqual(fullResult.totalDosesInVial, 1.0, accuracy: 0.0001)
        XCTAssertEqual(fullResult.exactDosesCount, 1)
        XCTAssertFalse(fullResult.warnings.contains(where: { $0.id == "dose_exceeds_vial" }))

        // 2. Dose exceeds total dry mass
        let excessDose = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(10.0, .mg)),
            syringeSpecification: .u100_100unit
        )
        let excessResult = try calculator.calculate(excessDose)
        XCTAssertEqual(excessResult.totalDosesInVial, 0.5, accuracy: 0.0001)
        XCTAssertEqual(excessResult.exactDosesCount, 0)
        XCTAssertTrue(excessResult.warnings.contains(where: { $0.id == "dose_exceeds_vial" }))
    }

    func testMaximumVialCapacityLimit() {
        // 100 mL diluent is accepted
        let maxAcceptable = ReconstitutionInput(
            dryMass: MassQuantity(100.0, .mg),
            diluentVolume: VolumeQuantity(100.0, .ml),
            targetDose: .mass(MassQuantity(1.0, .mg))
        )
        XCTAssertNoThrow(try calculator.calculate(maxAcceptable))

        // 100.01 mL diluent throws unrealisticVialCapacity
        let tooLarge = ReconstitutionInput(
            dryMass: MassQuantity(100.0, .mg),
            diluentVolume: VolumeQuantity(100.1, .ml),
            targetDose: .mass(MassQuantity(1.0, .mg))
        )
        XCTAssertThrowsError(try calculator.calculate(tooLarge)) { error in
            guard case ReconstitutionCalculationError.unrealisticVialCapacity = error else {
                XCTFail("Expected unrealisticVialCapacity, got \(error)")
                return
            }
        }
    }

    // MARK: - 3. Decimal Precision & High-Precision Calculations

    func testRepeatingDecimalsAndHighPrecision() throws {
        // 3.333333 mg in 1.666667 mL -> Conc = 2.000 mg/mL
        // Target dose: 0.333333 mg (333.33 mcg) -> Draw = 0.166667 mL = 16.6667 U-100 units
        let input = ReconstitutionInput(
            dryMass: MassQuantity(10.0 / 3.0, .mg),
            diluentVolume: VolumeQuantity(5.0 / 3.0, .ml),
            targetDose: .mass(MassQuantity(1.0 / 3.0, .mg)),
            syringeSpecification: .u100_50unit
        )
        let result = try calculator.calculate(input)
        XCTAssertEqual(result.concentrationMgMl, 2.0, accuracy: 0.0001)
        XCTAssertEqual(result.drawVolumeMl, 0.166667, accuracy: 0.0001)
        XCTAssertEqual(result.u100Units, 16.6667, accuracy: 0.01)
        XCTAssertEqual(result.totalDosesInVial, 10.0, accuracy: 0.0001)
        XCTAssertEqual(result.exactDosesCount, 10)
    }

    func testSubUnitSyringePrecision() throws {
        // 2.0 mg in 2.0 mL -> Conc = 1.0 mg/mL
        // Target dose 35 mcg = 0.035 mg -> Draw = 0.035 mL = 3.5 units on U-100 syringe
        let input = ReconstitutionInput(
            dryMass: MassQuantity(2.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(35.0, .mcg)),
            syringeSpecification: .u100_30unit
        )
        let result = try calculator.calculate(input)
        XCTAssertEqual(result.drawVolumeMl, 0.035, accuracy: 0.0001)
        XCTAssertEqual(result.u100Units, 3.5, accuracy: 0.0001)
        XCTAssertEqual(result.u40Units, 1.4, accuracy: 0.0001)
    }

    // MARK: - 4. Unit Conversions & Dimensional Matrix

    func testExhaustiveMassConversions() {
        let grams = MassQuantity(2.5, .g)
        XCTAssertEqual(grams.mg, 2500.0, accuracy: 0.0001)
        XCTAssertEqual(grams.mcg, 2_500_000.0, accuracy: 0.0001)
        XCTAssertEqual(grams.ng, 2_500_000_000.0, accuracy: 0.0001)

        let mg = MassQuantity(10.0, .mg)
        XCTAssertEqual(mg.g, 0.01, accuracy: 0.00001)
        XCTAssertEqual(mg.mcg, 10000.0, accuracy: 0.0001)
        XCTAssertEqual(mg.ng, 10_000_000.0, accuracy: 0.0001)

        let mcg = MassQuantity(500.0, .mcg)
        XCTAssertEqual(mcg.mg, 0.5, accuracy: 0.0001)
        XCTAssertEqual(mcg.g, 0.0005, accuracy: 0.000001)
        XCTAssertEqual(mcg.ng, 500_000.0, accuracy: 0.0001)

        let ng = MassQuantity(250_000.0, .ng)
        XCTAssertEqual(ng.mcg, 250.0, accuracy: 0.0001)
        XCTAssertEqual(ng.mg, 0.25, accuracy: 0.0001)
        XCTAssertEqual(ng.g, 0.00025, accuracy: 0.000001)
    }

    func testExhaustiveVolumeConversions() {
        let liters = VolumeQuantity(0.005, .l)
        XCTAssertEqual(liters.ml, 5.0, accuracy: 0.0001)
        XCTAssertEqual(liters.mcl, 5000.0, accuracy: 0.0001)

        let ml = VolumeQuantity(2.5, .ml)
        XCTAssertEqual(ml.l, 0.0025, accuracy: 0.000001)
        XCTAssertEqual(ml.mcl, 2500.0, accuracy: 0.0001)

        let mcl = VolumeQuantity(1500.0, .mcl)
        XCTAssertEqual(mcl.ml, 1.5, accuracy: 0.0001)
        XCTAssertEqual(mcl.l, 0.0015, accuracy: 0.000001)

        let cc = VolumeQuantity(3.0, .cc)
        XCTAssertEqual(cc.ml, 3.0, accuracy: 0.0001)
        XCTAssertEqual(cc.mcl, 3000.0, accuracy: 0.0001)
    }

    func testSyringeTypeConversions() {
        // U-100: 100 units/mL -> 1 unit = 0.01 mL = 10 µL
        XCTAssertEqual(SyringeType.u100.unitsPerMl, 100.0)
        XCTAssertEqual(SyringeType.u100.volumePerUnitMl, 0.01, accuracy: 0.0001)
        XCTAssertEqual(SyringeType.u100.units(forVolumeMl: 0.25), 25.0, accuracy: 0.0001)
        XCTAssertEqual(SyringeType.u100.volumeMl(forUnits: 50.0), 0.5, accuracy: 0.0001)

        // U-40: 40 units/mL -> 1 unit = 0.025 mL = 25 µL
        XCTAssertEqual(SyringeType.u40.unitsPerMl, 40.0)
        XCTAssertEqual(SyringeType.u40.volumePerUnitMl, 0.025, accuracy: 0.0001)
        XCTAssertEqual(SyringeType.u40.units(forVolumeMl: 0.25), 10.0, accuracy: 0.0001)
        XCTAssertEqual(SyringeType.u40.volumeMl(forUnits: 20.0), 0.5, accuracy: 0.0001)

        // U-500: 500 units/mL -> 1 unit = 0.002 mL = 2 µL
        XCTAssertEqual(SyringeType.u500.unitsPerMl, 500.0)
        XCTAssertEqual(SyringeType.u500.volumePerUnitMl, 0.002, accuracy: 0.0001)
        XCTAssertEqual(SyringeType.u500.units(forVolumeMl: 0.1), 50.0, accuracy: 0.0001)
        XCTAssertEqual(SyringeType.u500.volumeMl(forUnits: 100.0), 0.2, accuracy: 0.0001)
    }

    // MARK: - 5. Invalid Values & Error Handlers

    func testRejectsNaNAndInfinity() {
        // NaN Dry Mass
        let nanMass = ReconstitutionInput(
            dryMass: MassQuantity(Double.nan, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(250.0, .mcg))
        )
        XCTAssertThrowsError(try calculator.calculate(nanMass))

        // Infinity Diluent
        let infDiluent = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(Double.infinity, .ml),
            targetDose: .mass(MassQuantity(250.0, .mcg))
        )
        XCTAssertThrowsError(try calculator.calculate(infDiluent))

        // Negative Infinity Target Dose
        let negInfDose = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(-Double.infinity, .mcg))
        )
        XCTAssertThrowsError(try calculator.calculate(negInfDose))
    }

    func testRejectsZeroAndNegativeValues() {
        // Negative Dry Mass
        let negMass = ReconstitutionInput(
            dryMass: MassQuantity(-5.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(250.0, .mcg))
        )
        XCTAssertThrowsError(try calculator.calculate(negMass))

        // Zero Diluent Volume
        let zeroDiluent = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(0.0, .ml),
            targetDose: .mass(MassQuantity(250.0, .mcg))
        )
        XCTAssertThrowsError(try calculator.calculate(zeroDiluent))

        // Negative Target Dose
        let negDose = ReconstitutionInput(
            dryMass: MassQuantity(5.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(-100.0, .mcg))
        )
        XCTAssertThrowsError(try calculator.calculate(negDose))
    }

    // MARK: - 6. Mismatched Units & Multi-Way Solvers

    func testDiluentSolverNormalAndEdgeCases() throws {
        // Normal Case: 10 mg dry mass, target dose 500 mcg (0.5 mg), want 10 units U-100 (0.1 mL)
        // Required Conc = 0.5 mg / 0.1 mL = 5.0 mg/mL -> Diluent = 10 mg / 5.0 mg/mL = 2.0 mL
        let normalSolver = DiluentSolverInput(
            dryMass: MassQuantity(10.0, .mg),
            targetDose: .mass(MassQuantity(500.0, .mcg)),
            desiredSyringeUnits: 10.0,
            syringeType: .u100,
            vialCostUsd: 60.0
        )
        let normalResult = try calculator.solveRequiredDiluentVolume(normalSolver)
        XCTAssertEqual(normalResult.recommendedDiluentVolumeMl, 2.0, accuracy: 0.0001)
        XCTAssertEqual(normalResult.resultingConcentrationMgMl, 5.0, accuracy: 0.0001)
        XCTAssertEqual(normalResult.totalDosesInVial, 20.0, accuracy: 0.0001)
        XCTAssertEqual(normalResult.costPerDoseUsd ?? 0, 3.0, accuracy: 0.0001)
        XCTAssertTrue(normalResult.warnings.isEmpty)

        // Large Diluent Warning (> 10 mL)
        let largeSolver = DiluentSolverInput(
            dryMass: MassQuantity(100.0, .mg),
            targetDose: .mass(MassQuantity(500.0, .mcg)),
            desiredSyringeUnits: 10.0,
            syringeType: .u100
        )
        let largeResult = try calculator.solveRequiredDiluentVolume(largeSolver)
        XCTAssertEqual(largeResult.recommendedDiluentVolumeMl, 20.0, accuracy: 0.0001)
        XCTAssertTrue(largeResult.warnings.contains(where: { $0.id == "large_diluent_volume" }))

        // Small Diluent Warning (< 0.5 mL)
        let smallSolver = DiluentSolverInput(
            dryMass: MassQuantity(2.0, .mg),
            targetDose: .mass(MassQuantity(1.0, .mg)),
            desiredSyringeUnits: 10.0,
            syringeType: .u100
        )
        let smallResult = try calculator.solveRequiredDiluentVolume(smallSolver)
        XCTAssertEqual(smallResult.recommendedDiluentVolumeMl, 0.2, accuracy: 0.0001)
        XCTAssertTrue(smallResult.warnings.contains(where: { $0.id == "small_diluent_volume" }))
    }

    func testReverseDoseCalculationFromSyringe() throws {
        // 20 units U-100 (0.2 mL) from 2.5 mg/mL solution = 0.5 mg = 500 mcg
        let u100Input = ReverseDoseInput(
            drawnSyringeUnits: 20.0,
            syringeType: .u100,
            concentrationMgMl: 2.5
        )
        let u100Result = try calculator.reverseCalculateDoseFromSyringe(u100Input)
        XCTAssertEqual(u100Result.drawnVolumeMl, 0.2, accuracy: 0.0001)
        XCTAssertEqual(u100Result.administeredDoseMg, 0.5, accuracy: 0.0001)
        XCTAssertEqual(u100Result.administeredDoseMcg, 500.0, accuracy: 0.0001)

        // 10 units U-40 (0.25 mL) from 4.0 mg/mL solution = 1.0 mg = 1000 mcg
        let u40Input = ReverseDoseInput(
            drawnSyringeUnits: 10.0,
            syringeType: .u40,
            concentrationMgMl: 4.0
        )
        let u40Result = try calculator.reverseCalculateDoseFromSyringe(u40Input)
        XCTAssertEqual(u40Result.drawnVolumeMl, 0.25, accuracy: 0.0001)
        XCTAssertEqual(u40Result.administeredDoseMg, 1.0, accuracy: 0.0001)
        XCTAssertEqual(u40Result.administeredDoseMcg, 1000.0, accuracy: 0.0001)
    }

    func testBiologicalActivityWithAndWithoutRatio() throws {
        let ratio = CompoundActivityRatio(iuPerMg: 3.0)

        // Target dose 6.0 IU = 2.0 mg
        let validIUInput = ReconstitutionInput(
            dryMass: MassQuantity(10.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .biologicalActivity(iu: 6.0),
            compoundActivity: ratio,
            compoundName: "Somatropin"
        )
        let result = try calculator.calculate(validIUInput)
        XCTAssertEqual(result.normalizedDoseMg, 2.0, accuracy: 0.0001)
        XCTAssertEqual(result.normalizedDoseMcg, 2000.0, accuracy: 0.0001)
        XCTAssertEqual(result.drawVolumeMl, 0.4, accuracy: 0.0001)
        XCTAssertEqual(result.u100Units, 40.0, accuracy: 0.0001)

        // Missing ratio throws
        let invalidIUInput = ReconstitutionInput(
            dryMass: MassQuantity(10.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .biologicalActivity(iu: 6.0),
            compoundActivity: nil,
            compoundName: "Somatropin"
        )
        XCTAssertThrowsError(try calculator.calculate(invalidIUInput)) { error in
            guard case ReconstitutionCalculationError.missingBiologicalConversionRatio = error else {
                XCTFail("Expected missingBiologicalConversionRatio, got \(error)")
                return
            }
        }
    }
}
