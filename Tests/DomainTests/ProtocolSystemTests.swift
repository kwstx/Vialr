import XCTest
@testable import Domain

final class ProtocolSystemTests: XCTestCase {

    func testProtocolCompoundAttachedVialAndRoutes() throws {
        let vialId = UUID()
        let compoundId = UUID()
        let protoId = UUID()

        let compound = ProtocolCompound(
            protocolId: protoId,
            compoundId: compoundId,
            compoundName: "BPC-157",
            doseAmount: 500,
            doseUnit: .mcg,
            route: .subcutaneous,
            scheduleRule: .everyDay,
            timesPerDay: 2,
            preferredTimeOfDay: .morning,
            reminderEnabled: true,
            reminderLeadTimeMinutes: 15,
            foodRequirement: .fasted,
            attachedVialId: vialId
        )

        XCTAssertEqual(compound.attachedVialId, vialId)
        XCTAssertEqual(compound.vialId, vialId)
        XCTAssertEqual(compound.route, .subcutaneous)
        XCTAssertEqual(compound.preferredRoute, .subcutaneous)
        XCTAssertEqual(compound.timesPerDay, 2)
        XCTAssertEqual(compound.foodRequirement, .fasted)
        XCTAssertTrue(compound.reminderEnabled)

        // Test JSON encode/decode
        let data = try JSONEncoder().encode(compound)
        let decoded = try JSONDecoder().decode(ProtocolCompound.self, from: data)

        XCTAssertEqual(decoded.compoundId, compoundId)
        XCTAssertEqual(decoded.attachedVialId, vialId)
        XCTAssertEqual(decoded.doseAmount, 500)
        XCTAssertEqual(decoded.timesPerDay, 2)
    }

    func testExpectedDoseOccurrenceConversion() {
        let protoId = UUID()
        let compId = UUID()
        let vialId = UUID()
        let now = Date()

        let occurrence = ExpectedDoseOccurrence(
            protocolId: protoId,
            protocolName: "Tendon Recovery",
            protocolCompoundId: UUID(),
            compoundId: compId,
            compoundName: "BPC-157",
            scheduledTimestamp: now,
            plannedDoseAmount: 250,
            doseUnit: .mcg,
            route: .subcutaneous,
            attachedVialId: vialId
        )

        XCTAssertEqual(occurrence.formattedDose, "250 mcg")
        XCTAssertTrue(occurrence.isToday)
        XCTAssertFalse(occurrence.isTaken)

        let doseLog = occurrence.toDoseLog(
            injectionSiteId: "ab_l_uo",
            injectionSiteName: "Abdomen Upper Left",
            status: .taken,
            notes: "Smooth administration"
        )

        XCTAssertEqual(doseLog.protocolId, protoId)
        XCTAssertEqual(doseLog.compoundId, compId)
        XCTAssertEqual(doseLog.vialId, vialId)
        XCTAssertEqual(doseLog.status, .taken)
        XCTAssertEqual(doseLog.actualDoseAmount, 250)
        XCTAssertEqual(doseLog.injectionSiteName, "Abdomen Upper Left")
    }

    func testAllScheduleRuleDescriptions() {
        XCTAssertEqual(ScheduleRule.everyDay.description, "Daily")
        XCTAssertEqual(ScheduleRule.everyOtherDay.description, "Every Other Day (EOD)")
        XCTAssertEqual(ScheduleRule.daysOfWeek([2, 4, 6]).description, "Weekly: Mon, Wed, Fri")
        XCTAssertEqual(ScheduleRule.cycle(daysOn: 5, daysOff: 2).description, "5 Days On / 2 Days Off")
        XCTAssertEqual(ScheduleRule.everyNDays(3).description, "Every 3 Days")
        XCTAssertEqual(ScheduleRule.customInterval(hours: 12).description, "Every 12 Hours")
        XCTAssertEqual(ScheduleRule.asNeeded.description, "As Needed (PRN)")
    }
}
