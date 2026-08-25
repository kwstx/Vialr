import XCTest
@testable import Domain

final class DomainTests: XCTestCase {

    func testCompoundJSONEncodingDecoding() throws {
        let compound = Compound(
            name: "Tirzepatide",
            shortCode: "TRZ",
            category: .glp1Metabolic,
            defaultUnit: .mg,
            typicalDose: 5.0,
            halfLifeHours: 120.0,
            description: "Dual GIP/GLP-1 agonist."
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(compound)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Compound.self, from: data)

        XCTAssertEqual(decoded.id, compound.id)
        XCTAssertEqual(decoded.name, "Tirzepatide")
        XCTAssertEqual(decoded.category, .glp1Metabolic)
        XCTAssertEqual(decoded.typicalDose, 5.0)
        XCTAssertEqual(decoded.halfLifeHours, 120.0)
    }

    func testProtocolItemScheduleRuleDescription() {
        let daily = ScheduleRule.everyDay
        XCTAssertEqual(daily.description, "Daily")

        let cycle = ScheduleRule.cycle(daysOn: 5, daysOff: 2)
        XCTAssertEqual(cycle.description, "5 Days On / 2 Days Off")
    }

    func testVialRemainingFractionCalculation() {
        let vial = Vial(
            compoundId: UUID(),
            compoundName: "BPC-157",
            totalDryMassMg: 5.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 1.0,
            isReconstituted: true
        )

        XCTAssertEqual(vial.remainingFraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(vial.concentrationMgMl ?? 0, 2.5, accuracy: 0.001)
    }
}
