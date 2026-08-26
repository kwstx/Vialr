import XCTest
import Domain
@testable import CalculationEngine

final class SiteRotationServiceTests: XCTestCase {

    var engine: SiteRotationEngine!
    var now: Date!
    var cal: Calendar!

    override func setUp() {
        super.setUp()
        engine = SiteRotationEngine()
        now = Date()
        cal = Calendar.current
    }

    // MARK: - 1. Bilateral Alternating Strategy (Left ↔ Right)

    func testBilateralAlternatingStrategyFromLeftToRight() {
        let leftEvent = InjectionSiteEvent(
            id: UUID(),
            doseEventId: UUID(),
            siteId: "ab_l_uo",
            siteName: "Abdomen - Left Upper Outer",
            region: .abdomen,
            side: .left,
            quadrant: .upperOuter,
            timestamp: cal.date(byAdding: .day, value: -1, to: now)!,
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg
        )

        let result = engine.evaluateNextSite(
            siteEvents: [leftEvent],
            availableSites: InjectionSite.standardSites,
            strategy: .bilateralAlternating,
            currentDate: now
        )

        XCTAssertEqual(result.lastSite?.id, "ab_l_uo")
        XCTAssertEqual(result.lastSite?.side, .left)
        XCTAssertEqual(result.nextSite.side, .right)
        XCTAssertTrue(result.strategyReason.contains("Alternate Sides"))
    }

    func testBilateralAlternatingStrategyFromRightToLeft() {
        let rightEvent = InjectionSiteEvent(
            id: UUID(),
            doseEventId: UUID(),
            siteId: "ab_r_uo",
            siteName: "Abdomen - Right Upper Outer",
            region: .abdomen,
            side: .right,
            quadrant: .upperOuter,
            timestamp: cal.date(byAdding: .day, value: -1, to: now)!,
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg
        )

        let result = engine.evaluateNextSite(
            siteEvents: [rightEvent],
            availableSites: InjectionSite.standardSites,
            strategy: .bilateralAlternating,
            currentDate: now
        )

        XCTAssertEqual(result.lastSite?.id, "ab_r_uo")
        XCTAssertEqual(result.lastSite?.side, .right)
        XCTAssertEqual(result.nextSite.side, .left)
    }

    // MARK: - 2. Clockwise Quadrant Strategy

    func testClockwiseQuadrantProgression() {
        let abdomenSites = InjectionSite.standardSites.filter { $0.region == .abdomen }

        // Step 1: Left Upper Outer -> Next should be Right Upper Outer
        let ev1 = InjectionSiteEvent(
            id: UUID(),
            doseEventId: UUID(),
            siteId: "ab_l_uo",
            siteName: "Abdomen - Left Upper Outer",
            region: .abdomen,
            side: .left,
            quadrant: .upperOuter,
            timestamp: now,
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg
        )
        let r1 = engine.evaluateNextSite(siteEvents: [ev1], availableSites: abdomenSites, strategy: .clockwise, currentDate: now)
        XCTAssertEqual(r1.nextSite.id, "ab_r_uo")

        // Step 2: Right Upper Outer -> Next should be Right Lower Outer
        let ev2 = InjectionSiteEvent(
            id: UUID(),
            doseEventId: UUID(),
            siteId: "ab_r_uo",
            siteName: "Abdomen - Right Upper Outer",
            region: .abdomen,
            side: .right,
            quadrant: .upperOuter,
            timestamp: now,
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg
        )
        let r2 = engine.evaluateNextSite(siteEvents: [ev2], availableSites: abdomenSites, strategy: .clockwise, currentDate: now)
        XCTAssertEqual(r2.nextSite.id, "ab_r_lo")

        // Step 3: Right Lower Outer -> Next should be Left Lower Outer
        let ev3 = InjectionSiteEvent(
            id: UUID(),
            doseEventId: UUID(),
            siteId: "ab_r_lo",
            siteName: "Abdomen - Right Lower Outer",
            region: .abdomen,
            side: .right,
            quadrant: .lowerOuter,
            timestamp: now,
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg
        )
        let r3 = engine.evaluateNextSite(siteEvents: [ev3], availableSites: abdomenSites, strategy: .clockwise, currentDate: now)
        XCTAssertEqual(r3.nextSite.id, "ab_l_lo")

        // Step 4: Left Lower Outer -> Next should cycle back to Left Upper Outer
        let ev4 = InjectionSiteEvent(
            id: UUID(),
            doseEventId: UUID(),
            siteId: "ab_l_lo",
            siteName: "Abdomen - Left Lower Outer",
            region: .abdomen,
            side: .left,
            quadrant: .lowerOuter,
            timestamp: now,
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg
        )
        let r4 = engine.evaluateNextSite(siteEvents: [ev4], availableSites: abdomenSites, strategy: .clockwise, currentDate: now)
        XCTAssertEqual(r4.nextSite.id, "ab_l_uo")
    }

    // MARK: - 3. Counter-Clockwise Strategy

    func testCounterClockwiseProgression() {
        let abdomenSites = InjectionSite.standardSites.filter { $0.region == .abdomen }

        let ev1 = InjectionSiteEvent(
            id: UUID(),
            doseEventId: UUID(),
            siteId: "ab_l_uo",
            siteName: "Abdomen - Left Upper Outer",
            region: .abdomen,
            side: .left,
            quadrant: .upperOuter,
            timestamp: now,
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg
        )
        let r1 = engine.evaluateNextSite(siteEvents: [ev1], availableSites: abdomenSites, strategy: .counterClockwise, currentDate: now)
        XCTAssertEqual(r1.nextSite.id, "ab_l_lo")
    }

    // MARK: - 4. Maximum Rest (LRU) Strategy

    func testMaximumRestLRUStrategy() {
        let abdomenSites = InjectionSite.standardSites.filter { $0.region == .abdomen }

        // Use ab_l_uo 1 day ago, ab_r_uo 3 days ago, ab_r_lo 6 days ago
        let ev1 = InjectionSiteEvent(
            id: UUID(), doseEventId: UUID(), siteId: "ab_l_uo", siteName: "UO",
            timestamp: cal.date(byAdding: .day, value: -1, to: now)!,
            compoundId: UUID(), compoundName: "BPC", doseAmount: 250, doseUnit: .mcg
        )
        let ev2 = InjectionSiteEvent(
            id: UUID(), doseEventId: UUID(), siteId: "ab_r_uo", siteName: "RO",
            timestamp: cal.date(byAdding: .day, value: -3, to: now)!,
            compoundId: UUID(), compoundName: "BPC", doseAmount: 250, doseUnit: .mcg
        )
        let ev3 = InjectionSiteEvent(
            id: UUID(), doseEventId: UUID(), siteId: "ab_r_lo", siteName: "RL",
            timestamp: cal.date(byAdding: .day, value: -6, to: now)!,
            compoundId: UUID(), compoundName: "BPC", doseAmount: 250, doseUnit: .mcg
        )

        // ab_l_lo was never used -> Should be selected first because it has maximum rest (pristine)
        let result1 = engine.evaluateNextSite(siteEvents: [ev1, ev2, ev3], availableSites: abdomenSites, strategy: .maximumRest, currentDate: now)
        XCTAssertEqual(result1.nextSite.id, "ab_l_lo")

        // Now also use ab_l_lo 2 days ago -> Now ab_r_lo (6 days rested) has the longest rest time
        let ev4 = InjectionSiteEvent(
            id: UUID(), doseEventId: UUID(), siteId: "ab_l_lo", siteName: "LL",
            timestamp: cal.date(byAdding: .day, value: -2, to: now)!,
            compoundId: UUID(), compoundName: "BPC", doseAmount: 250, doseUnit: .mcg
        )
        let result2 = engine.evaluateNextSite(siteEvents: [ev1, ev2, ev3, ev4], availableSites: abdomenSites, strategy: .maximumRest, currentDate: now)
        XCTAssertEqual(result2.nextSite.id, "ab_r_lo")
    }

    // MARK: - 5. Balanced Usage (LFU) Strategy

    func testBalancedUsageLFUStrategy() {
        let abdomenSites = InjectionSite.standardSites.filter { $0.region == .abdomen }

        // Site A used 3 times, Site B used 2 times, Site C used 1 time
        var events: [InjectionSiteEvent] = []
        for i in 1...3 {
            events.append(InjectionSiteEvent(
                id: UUID(), doseEventId: UUID(), siteId: "ab_l_uo", siteName: "UO",
                timestamp: cal.date(byAdding: .day, value: -i, to: now)!,
                compoundId: UUID(), compoundName: "BPC", doseAmount: 250, doseUnit: .mcg
            ))
        }
        for i in 1...2 {
            events.append(InjectionSiteEvent(
                id: UUID(), doseEventId: UUID(), siteId: "ab_r_uo", siteName: "RO",
                timestamp: cal.date(byAdding: .day, value: -i, to: now)!,
                compoundId: UUID(), compoundName: "BPC", doseAmount: 250, doseUnit: .mcg
            ))
        }
        events.append(InjectionSiteEvent(
            id: UUID(), doseEventId: UUID(), siteId: "ab_r_lo", siteName: "RL",
            timestamp: cal.date(byAdding: .day, value: -5, to: now)!,
            compoundId: UUID(), compoundName: "BPC", doseAmount: 250, doseUnit: .mcg
        ))

        // ab_l_lo was used 0 times -> LFU selects ab_l_lo
        let result = engine.evaluateNextSite(siteEvents: events, availableSites: abdomenSites, strategy: .leastFrequentlyUsed, currentDate: now)
        XCTAssertEqual(result.nextSite.id, "ab_l_lo")
    }

    // MARK: - 6. Sequential Strategy

    func testSequentialStrategy() {
        let customSites = [
            InjectionSite.standardSites[0], // ab_l_uo
            InjectionSite.standardSites[1], // ab_r_uo
            InjectionSite.standardSites[2]  // ab_r_lo
        ]

        let ev = InjectionSiteEvent(
            id: UUID(), doseEventId: UUID(), siteId: "ab_l_uo", siteName: "UO",
            timestamp: now, compoundId: UUID(), compoundName: "BPC", doseAmount: 250, doseUnit: .mcg
        )

        let r = engine.evaluateNextSite(siteEvents: [ev], availableSites: customSites, strategy: .sequential, currentDate: now)
        XCTAssertEqual(r.nextSite.id, "ab_r_uo")
    }

    // MARK: - 7. Protocol-Independent Site History Preservation

    func testProtocolIndependentSiteHistoryPreservation() {
        let protocol1Id = UUID()
        let protocol2Id = UUID()

        // Injection from Protocol 1 (BPC-157)
        let evProto1 = InjectionSiteEvent(
            id: UUID(),
            doseEventId: UUID(),
            siteId: "ab_l_uo",
            siteName: "Abdomen - Left Upper Outer",
            region: .abdomen,
            side: .left,
            quadrant: .upperOuter,
            timestamp: cal.date(byAdding: .day, value: -3, to: now)!,
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg
        )

        // Injection from Protocol 2 (Tirzepatide)
        let evProto2 = InjectionSiteEvent(
            id: UUID(),
            doseEventId: UUID(),
            siteId: "ab_r_uo",
            siteName: "Abdomen - Right Upper Outer",
            region: .abdomen,
            side: .right,
            quadrant: .upperOuter,
            timestamp: cal.date(byAdding: .day, value: -1, to: now)!,
            compoundId: UUID(),
            compoundName: "Tirzepatide",
            doseAmount: 5.0,
            doseUnit: .mg
        )

        // Off-protocol / PRN Injection
        let evPRN = InjectionSiteEvent(
            id: UUID(),
            doseEventId: UUID(),
            siteId: "thigh_l_outer",
            siteName: "Left Thigh",
            region: .thigh,
            side: .left,
            timestamp: cal.date(byAdding: .day, value: -5, to: now)!,
            compoundId: UUID(),
            compoundName: "Glutathione",
            doseAmount: 200,
            doseUnit: .mg
        )

        let allEvents = [evProto1, evProto2, evPRN]

        // Evaluate rotation: Most recent injection was evProto2 on Right side
        let result = engine.evaluateNextSite(
            siteEvents: allEvents,
            availableSites: InjectionSite.standardSites,
            strategy: .bilateralAlternating,
            currentDate: now
        )

        // Verifies that last site is accurately determined from evProto2 despite different protocols
        XCTAssertEqual(result.lastSite?.id, "ab_r_uo")
        XCTAssertEqual(result.lastSite?.side, .right)

        // Next site should alternate to Left side
        XCTAssertEqual(result.nextSite.side, .left)

        // Verify status calculations across distinct protocols
        let statusAbLeft = result.siteStatuses.first(where: { $0.site.id == "ab_l_uo" })
        XCTAssertEqual(statusAbLeft?.daysSinceLastUse, 3)
        XCTAssertEqual(statusAbLeft?.timesUsedTotal, 1)

        let statusThighLeft = result.siteStatuses.first(where: { $0.site.id == "thigh_l_outer" })
        XCTAssertEqual(statusThighLeft?.daysSinceLastUse, 5)
        XCTAssertEqual(statusThighLeft?.timesUsedTotal, 1)
    }

    // MARK: - 8. 2D Coordinates & Visual Bounds

    func testSiteCoordinatesAndVisualBounds() {
        for site in InjectionSite.standardSites {
            XCTAssertGreaterThanOrEqual(site.coordinates.x, 0.0, "Site \(site.id) x coordinate is out of bounds (< 0.0)")
            XCTAssertLessThanOrEqual(site.coordinates.x, 1.0, "Site \(site.id) x coordinate is out of bounds (> 1.0)")
            XCTAssertGreaterThanOrEqual(site.coordinates.y, 0.0, "Site \(site.id) y coordinate is out of bounds (< 0.0)")
            XCTAssertLessThanOrEqual(site.coordinates.y, 1.0, "Site \(site.id) y coordinate is out of bounds (> 1.0)")
        }
    }
}
