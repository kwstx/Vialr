import XCTest
import SwiftUI
@testable import Feature
@testable import Domain
@testable import CalculationEngine
@testable import Data

@MainActor
final class DoseLoggingUITests: XCTestCase {

    private var localStore: LocalStore!
    private var siteRotationEngine: SiteRotationEngine!

    override func setUp() async throws {
        localStore = LocalStore()
        siteRotationEngine = SiteRotationEngine()
    }

    func testSiteRotationRecommendationForDoseLogging() {
        let compoundId = UUID()
        let now = Date()
        let cal = Calendar.current

        // User injected in Abdomen Left yesterday (1 day ago)
        let logYesterday = DoseLog(
            compoundId: compoundId,
            compoundName: "BPC-157",
            scheduledDate: now,
            loggedDate: cal.date(byAdding: .day, value: -1, to: now),
            doseAmount: 250,
            doseUnit: .mcg,
            status: .taken,
            injectionSiteId: "ab_l_uo" // Abdomen Upper Left
        )

        let analysis = siteRotationEngine.analyzeRotation(history: [logYesterday], currentDate: now)

        let leftUpperAb = analysis.first(where: { $0.site.id == "ab_l_uo" })
        XCTAssertEqual(leftUpperAb?.daysSinceLastUse, 1)

        // Recommended site should be a well-rested alternative (e.g. Right side or Deltoid/Thigh)
        let recommended = analysis.first(where: { $0.isRecommended })
        XCTAssertNotNil(recommended)
        XCTAssertNotEqual(recommended?.site.id, "ab_l_uo")
    }

    func testInstantDoseLoggingWithLocalVialDeduction() async throws {
        let compoundId = UUID()
        let vialId = UUID()

        // 1. Setup local vial: 5 mg in 2.0 mL BAC water (2.5 mg/mL)
        let vial = Vial(
            id: vialId,
            compoundId: compoundId,
            compoundName: "BPC-157",
            lotNumber: "LOT-UI-01",
            totalDryMassMg: 5.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 2.0,
            isReconstituted: true,
            status: .reconstituted
        )
        await localStore.saveVial(vial)

        // 2. Perform 250 mcg dose draw (0.25 mg / 2.5 mg/mL = 0.1 mL draw = 10 units U-100)
        let doseId = UUID()
        let doseLog = DoseLog(
            id: doseId,
            compoundId: compoundId,
            compoundName: "BPC-157",
            scheduledDate: Date(),
            loggedDate: Date(),
            doseAmount: 250,
            doseUnit: .mcg,
            status: .taken,
            vialId: vialId,
            injectionSiteId: "ab_r_uo"
        )
        await localStore.saveDoseLog(doseLog)

        // 3. Verify dose log saved locally with .pendingCreation sync status
        let doses = await localStore.getAllDoseLogs()
        let savedDose = doses.first(where: { $0.id == doseId })
        XCTAssertNotNil(savedDose)
        XCTAssertEqual(savedDose?.actualDoseAmount, 250)
        XCTAssertEqual(savedDose?.syncState, .pendingCreation)

        // 4. Verify local vial liquid volume is immediately reduced by 0.1 mL (2.0 - 0.1 = 1.9 mL)
        let vials = await localStore.getAllVials()
        let updatedVial = vials.first(where: { $0.id == vialId })
        XCTAssertEqual(updatedVial?.currentVolumeRemainingMl, 1.9, accuracy: 0.001)
        XCTAssertEqual(updatedVial?.syncState, .pendingUpdate)

        // 5. Verify mutation was automatically enqueued in persistent sync queue
        let queue = await localStore.getPendingSyncQueue()
        XCTAssertTrue(queue.contains(where: { $0.entityId == doseId && $0.action == .create }))
    }

    func testInconsistencyDetectionOnExtremeDoseInput() {
        let detector = InconsistencyDetector()
        let compound = Compound(name: "Semaglutide", shortCode: "SEMA", category: .metabolic, defaultUnit: .mg, typicalDose: 0.5)

        // User mistakenly typed 50 mg instead of 0.5 mg
        let candidateLog = DoseLog(
            compoundId: compound.id,
            compoundName: compound.name,
            doseAmount: 50.0,
            doseUnit: .mg
        )

        let warnings = detector.evaluateDoseEntry(candidate: candidateLog, compound: compound, recentLogs: [])
        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains(where: { $0.title.contains("Unusually High Dose") }))
    }
}
