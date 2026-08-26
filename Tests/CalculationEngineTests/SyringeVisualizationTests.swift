import XCTest
import Domain
@testable import CalculationEngine

final class SyringeVisualizationTests: XCTestCase {

    // MARK: - 1. Volume to Normalized Position Tests

    func testNormalizedFillPositionCalculations() {
        // Test U-100 0.5 mL (50 Units)
        let spec50 = SyringeSpecification.u100_50unit
        XCTAssertEqual(spec50.barrelCapacityMl, 0.5, accuracy: 0.0001)
        XCTAssertEqual(spec50.totalUnits, 50.0, accuracy: 0.0001)

        // 0.1 mL in 0.5 mL barrel -> 20% fill
        let fill01 = spec50.barrelFillFraction(forVolumeMl: 0.1)
        XCTAssertEqual(fill01, 0.2, accuracy: 0.0001)
        XCTAssertTrue(spec50.isWithinCapacity(volumeMl: 0.1))

        // 0.25 mL in 0.5 mL barrel -> 50% fill
        let fill025 = spec50.barrelFillFraction(forVolumeMl: 0.25)
        XCTAssertEqual(fill025, 0.5, accuracy: 0.0001)
        XCTAssertTrue(spec50.isWithinCapacity(volumeMl: 0.25))

        // 0.5 mL in 0.5 mL barrel -> 100% fill
        let fill05 = spec50.barrelFillFraction(forVolumeMl: 0.5)
        XCTAssertEqual(fill05, 1.0, accuracy: 0.0001)
        XCTAssertTrue(spec50.isWithinCapacity(volumeMl: 0.5))

        // 0.6 mL in 0.5 mL barrel -> 120% fill (Over capacity)
        let fill06 = spec50.barrelFillFraction(forVolumeMl: 0.6)
        XCTAssertEqual(fill06, 1.2, accuracy: 0.0001)
        XCTAssertFalse(spec50.isWithinCapacity(volumeMl: 0.6))
    }

    func testStandardSyringeSizesCalibration() {
        // 0.3 mL U-100 (30 units)
        let spec30 = SyringeSpecification.u100_30unit
        XCTAssertEqual(spec30.totalUnits, 30.0, accuracy: 0.0001)
        XCTAssertEqual(spec30.barrelCapacityMl, 0.3, accuracy: 0.0001)
        XCTAssertEqual(spec30.type.unitsPerMl, 100.0, accuracy: 0.0001)

        // 1.0 mL U-100 (100 units)
        let spec100 = SyringeSpecification.u100_100unit
        XCTAssertEqual(spec100.totalUnits, 100.0, accuracy: 0.0001)
        XCTAssertEqual(spec100.barrelCapacityMl, 1.0, accuracy: 0.0001)

        // 0.5 mL U-40 (20 units)
        let specU40_20 = SyringeSpecification.u40_20unit
        XCTAssertEqual(specU40_20.totalUnits, 20.0, accuracy: 0.0001)
        XCTAssertEqual(specU40_20.barrelCapacityMl, 0.5, accuracy: 0.0001)
        XCTAssertEqual(specU40_20.type.unitsPerMl, 40.0, accuracy: 0.0001)

        // 1.0 mL U-40 (40 units)
        let specU40_40 = SyringeSpecification.u40_40unit
        XCTAssertEqual(specU40_40.totalUnits, 40.0, accuracy: 0.0001)
        XCTAssertEqual(specU40_40.barrelCapacityMl, 1.0, accuracy: 0.0001)
    }

    func testEngineCalculationGeneratesAccurateSyringeMarkings() throws {
        let calc = ReconstitutionCalculator()

        // 10 mg vial, 2 mL diluent -> 5 mg/mL
        // Target dose: 500 mcg (0.5 mg) -> Draw volume: 0.1 mL
        let input = ReconstitutionInput(
            dryMass: MassQuantity(10.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(500.0, .mcg)),
            syringeSpecification: .u100_50unit
        )

        let result = try calc.calculate(input)

        // Numerical verifications for syringe display
        XCTAssertEqual(result.drawVolumeMl, 0.1, accuracy: 0.0001)
        XCTAssertEqual(result.drawVolumeMcl, 100.0, accuracy: 0.0001)
        XCTAssertEqual(result.u100Units, 10.0, accuracy: 0.0001)
        XCTAssertEqual(result.selectedSyringeUnits, 10.0, accuracy: 0.0001)
        XCTAssertEqual(result.syringeBarrelFillFraction, 0.2, accuracy: 0.0001)
        XCTAssertTrue(result.isWithinSyringeCapacity)
        XCTAssertFalse(result.syringeVisualDescription.isEmpty)
    }

    func testSyringeOverflowDetection() throws {
        let calc = ReconstitutionCalculator()

        // 2 mg vial in 2 mL diluent (1 mg/mL).
        // Target dose 500 mcg = 0.5 mL draw.
        // Syringe is 0.3 mL (30 units U-100).
        let input = ReconstitutionInput(
            dryMass: MassQuantity(2.0, .mg),
            diluentVolume: VolumeQuantity(2.0, .ml),
            targetDose: .mass(MassQuantity(500.0, .mcg)),
            syringeSpecification: .u100_30unit
        )

        let result = try calc.calculate(input)

        XCTAssertEqual(result.drawVolumeMl, 0.5, accuracy: 0.0001)
        XCTAssertEqual(result.u100Units, 50.0, accuracy: 0.0001)
        XCTAssertFalse(result.isWithinSyringeCapacity)
        XCTAssertEqual(result.syringeBarrelFillFraction, 0.5 / 0.3, accuracy: 0.001)
        XCTAssertTrue(result.warnings.contains { $0.id == "syringe_overflow" })
    }
}
