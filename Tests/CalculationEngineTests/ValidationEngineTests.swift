import XCTest
import Domain
@testable import CalculationEngine

final class ValidationEngineTests: XCTestCase {

    var engine: ValidationEngine!
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar.current
        engine = ValidationEngine(calendar: calendar)
    }

    override func tearDown() {
        engine = nil
        calendar = nil
        super.tearDown()
    }

    // MARK: - 1. Unit Consistency Tests

    func testInconsistentUnitDimensionMismatch() {
        let compound = Compound(
            name: "BPC-157",
            category: .recovery,
            defaultUnit: .mcg,
            typicalDose: 250,
            requiresReconstitution: false
        )

        // Dose entered in liquid volume (mL) for mass-defined compound without vial
        let dose = DoseLog(
            compoundId: compound.id,
            compoundName: compound.name,
            scheduledDate: Date(),
            doseAmount: 0.5,
            doseUnit: .ml
        )

        let result = engine.validateDoseEntry(
            candidate: dose,
            compound: compound,
            recentLogs: []
        )

        XCTAssertTrue(result.isValid) // Warnings do not block
        XCTAssertTrue(result.hasWarnings)
        let warning = result.warnings.first(where: { $0.category == .inconsistentUnits })
        XCTAssertNotNil(warning)
        XCTAssertEqual(warning?.field, "doseUnit")
        XCTAssertTrue(warning?.title.contains("Unit Dimension Mismatch") ?? false)
    }

    func testMissingBiologicalActivityRatioForIUDosing() {
        // Target dose in IU without conversion ratio in Reconstitution
        let result = engine.validateReconstitution(
            dryMassMg: 5.0,
            diluentVolumeMl: 2.0,
            diluentType: .bacteriostaticWater,
            targetDoseAmount: 3.0,
            targetDoseUnit: .iu,
            compoundActivityRatio: nil
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.hasBlockingErrors)
        let blocking = result.blockingErrors.first(where: { $0.category == .inconsistentUnits })
        XCTAssertNotNil(blocking)
        XCTAssertTrue(blocking?.title.contains("Biological Activity") ?? false)
    }

    func testUnitScaleMagnitudeDisparityWarning() {
        let compound = Compound(
            name: "BPC-157",
            defaultUnit: .mcg,
            typicalDose: 250
        )

        // User entered 25 mg instead of 250 mcg (100x scale difference)
        let dose = DoseLog(
            compoundId: compound.id,
            compoundName: compound.name,
            scheduledDate: Date(),
            doseAmount: 25.0,
            doseUnit: .mg
        )

        let result = engine.validateDoseEntry(
            candidate: dose,
            compound: compound,
            recentLogs: []
        )

        XCTAssertTrue(result.hasWarnings)
        let scaleWarning = result.warnings.first(where: { $0.title.contains("Scale Disparity") })
        XCTAssertNotNil(scaleWarning)
        XCTAssertTrue(scaleWarning?.explanation.contains("1 mg = 1,000 mcg") ?? false)
    }

    // MARK: - 2. Missing Required Fields Tests

    func testMissingDoseCompoundName() {
        let dose = DoseLog(
            compoundId: UUID(),
            compoundName: "   ",
            scheduledDate: Date(),
            doseAmount: 250,
            doseUnit: .mcg
        )

        let result = engine.validateDoseEntry(candidate: dose)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.field == "compoundName" }))
    }

    func testNonPositiveDoseAmount() {
        let zeroDose = DoseLog(
            compoundId: UUID(),
            compoundName: "BPC-157",
            scheduledDate: Date(),
            doseAmount: 0.0,
            doseUnit: .mcg
        )

        let zeroResult = engine.validateDoseEntry(candidate: zeroDose)
        XCTAssertFalse(zeroResult.isValid)
        XCTAssertTrue(zeroResult.blockingErrors.contains(where: { $0.field == "doseAmount" }))

        let negativeDose = DoseLog(
            compoundId: UUID(),
            compoundName: "BPC-157",
            scheduledDate: Date(),
            doseAmount: -100.0,
            doseUnit: .mcg
        )
        let negResult = engine.validateDoseEntry(candidate: negativeDose)
        XCTAssertFalse(negResult.isValid)
        XCTAssertTrue(negResult.blockingErrors.contains(where: { $0.field == "doseAmount" }))
    }

    func testMissingProtocolFields() {
        // Empty protocol name & empty compounds
        let emptyProtocol = ProtocolModel(
            name: "   ",
            status: .active,
            compounds: []
        )

        let result = engine.validateProtocol(protocolModel: emptyProtocol)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.blockingErrors.count, 2)
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.field == "name" }))
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.field == "compounds" }))
    }

    func testMissingReconstitutionDiluentVolume() {
        let result = engine.validateReconstitution(
            dryMassMg: 5.0,
            diluentVolumeMl: 0.0,
            targetDoseAmount: 250.0,
            targetDoseUnit: .mcg
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.field == "diluentVolumeMl" }))
    }

    // MARK: - 3. Unexpected Duplicate Events Tests

    func testRapidDuplicateDoseSubmission() {
        let compoundId = UUID()
        let now = Date()

        let existingLog = DoseLog(
            id: UUID(),
            compoundId: compoundId,
            compoundName: "BPC-157",
            scheduledDate: now.addingTimeInterval(-120), // 2 mins ago
            loggedDate: now.addingTimeInterval(-120),
            doseAmount: 250,
            doseUnit: .mcg,
            status: .taken
        )

        let candidate = DoseLog(
            id: UUID(),
            compoundId: compoundId,
            compoundName: "BPC-157",
            scheduledDate: now,
            loggedDate: now,
            doseAmount: 250,
            doseUnit: .mcg,
            status: .taken
        )

        let result = engine.validateDoseEntry(
            candidate: candidate,
            recentLogs: [existingLog],
            referenceDate: now
        )

        XCTAssertTrue(result.isValid) // Warning does not block
        XCTAssertTrue(result.hasWarnings)
        let dupWarning = result.warnings.first(where: { $0.category == .unexpectedDuplicate })
        XCTAssertNotNil(dupWarning)
        XCTAssertTrue(dupWarning?.title.contains("Duplicate") ?? false)
    }

    func testShortDosingIntervalWarning() {
        let compoundId = UUID()
        let now = Date()

        let previousDose = DoseLog(
            id: UUID(),
            compoundId: compoundId,
            compoundName: "Ipamorelin",
            scheduledDate: now.addingTimeInterval(-7200), // 2 hours ago
            loggedDate: now.addingTimeInterval(-7200),
            doseAmount: 200,
            doseUnit: .mcg,
            status: .taken
        )

        let candidate = DoseLog(
            id: UUID(),
            compoundId: compoundId,
            compoundName: "Ipamorelin",
            scheduledDate: now,
            loggedDate: now,
            doseAmount: 200,
            doseUnit: .mcg,
            status: .taken
        )

        let result = engine.validateDoseEntry(
            candidate: candidate,
            recentLogs: [previousDose],
            referenceDate: now
        )

        XCTAssertTrue(result.hasWarnings)
        let intervalWarning = result.warnings.first(where: { $0.title.contains("Short Dosing Interval") })
        XCTAssertNotNil(intervalWarning)
        XCTAssertTrue(intervalWarning?.explanation.contains("2.0 hours ago") ?? false)
    }

    // MARK: - 4. Inventory Discrepancy Tests

    func testVialCompoundMismatch() {
        let bpcId = UUID()
        let tb500Id = UUID()

        let vial = Vial(
            compoundId: tb500Id,
            compoundName: "TB-500",
            totalDryMassMg: 10.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 2.0,
            isReconstituted: true,
            status: .reconstituted
        )

        let dose = DoseLog(
            compoundId: bpcId,
            compoundName: "BPC-157",
            scheduledDate: Date(),
            doseAmount: 250,
            doseUnit: .mcg,
            vialId: vial.id
        )

        let result = engine.validateDoseEntry(
            candidate: dose,
            attachedVial: vial
        )

        XCTAssertFalse(result.isValid)
        let mismatchError = result.blockingErrors.first(where: { $0.category == .inventoryDiscrepancy })
        XCTAssertNotNil(mismatchError)
        XCTAssertTrue(mismatchError?.title.contains("Mismatch") ?? false)
    }

    func testVialDepletedStatusBlockingError() {
        let compoundId = UUID()
        let vial = Vial(
            compoundId: compoundId,
            compoundName: "Semaglutide",
            totalDryMassMg: 5.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 0.0,
            isReconstituted: true,
            status: .depleted
        )

        let dose = DoseLog(
            compoundId: compoundId,
            compoundName: "Semaglutide",
            scheduledDate: Date(),
            doseAmount: 250,
            doseUnit: .mcg,
            vialId: vial.id
        )

        let result = engine.validateDoseEntry(
            candidate: dose,
            attachedVial: vial
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.title.contains("Depleted") }))
    }

    func testDoseVolumeOverdrawsRemainingVial() {
        let compoundId = UUID()
        // 5 mg dry mass in 2 mL BAC water -> 2.5 mg/mL (2500 mcg/mL)
        // Current remaining volume is 0.05 mL (125 mcg)
        let vial = Vial(
            compoundId: compoundId,
            compoundName: "BPC-157",
            totalDryMassMg: 5.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 0.05,
            isReconstituted: true,
            status: .reconstituted
        )

        // Dose is 500 mcg (requires 0.2 mL draw, but only 0.05 mL remains)
        let dose = DoseLog(
            compoundId: compoundId,
            compoundName: "BPC-157",
            scheduledDate: Date(),
            doseAmount: 500,
            doseUnit: .mcg,
            vialId: vial.id
        )

        let result = engine.validateDoseEntry(
            candidate: dose,
            attachedVial: vial
        )

        XCTAssertFalse(result.isValid)
        let overdrawError = result.blockingErrors.first(where: { $0.field == "doseAmount" })
        XCTAssertNotNil(overdrawError)
        XCTAssertTrue(overdrawError?.title.contains("Insufficient Vial Volume") ?? false)
    }

    func testVialRemainingVolumeExceedsAddedDiluent() {
        let vial = Vial(
            compoundId: UUID(),
            compoundName: "CJC-1295",
            totalDryMassMg: 2.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 3.5, // Discrepancy: 3.5 mL in 2.0 mL reconstitution
            isReconstituted: true,
            status: .reconstituted
        )

        let result = engine.validateVial(vial: vial)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.title.contains("Exceeds Diluent") }))
    }

    func testNegativeSupplyItemQuantity() {
        let supply = SupplyItem(
            name: "Alcohol Swabs",
            category: .prepPads,
            quantityRemaining: -5,
            reorderThreshold: 10
        )

        let result = engine.validateSupplyItem(item: supply)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.field == "quantityRemaining" }))
    }

    // MARK: - 5. Expired Records Tests

    func testVialPastExpirationDateWarning() {
        let compoundId = UUID()
        let pastDate = calendar.date(byAdding: .day, value: -10, to: Date())!

        let vial = Vial(
            compoundId: compoundId,
            compoundName: "BPC-157",
            totalDryMassMg: 5.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 1.5,
            isReconstituted: true,
            expirationDate: pastDate,
            status: .reconstituted
        )

        let dose = DoseLog(
            compoundId: compoundId,
            compoundName: "BPC-157",
            scheduledDate: Date(),
            doseAmount: 250,
            doseUnit: .mcg,
            vialId: vial.id
        )

        let result = engine.validateDoseEntry(
            candidate: dose,
            attachedVial: vial,
            referenceDate: Date()
        )

        XCTAssertTrue(result.hasWarnings)
        let expWarning = result.warnings.first(where: { $0.category == .expiredRecord })
        XCTAssertNotNil(expWarning)
        XCTAssertTrue(expWarning?.title.contains("Expiration Date Passed") ?? false)
    }

    func testReconstitutionFreshnessWindowExceeded() {
        let compoundId = UUID()
        let reconDate = calendar.date(byAdding: .day, value: -45, to: Date())!

        let vial = Vial(
            compoundId: compoundId,
            compoundName: "BPC-157",
            totalDryMassMg: 5.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 1.0,
            isReconstituted: true,
            reconstitutedDate: reconDate,
            status: .reconstituted
        )

        let dose = DoseLog(
            compoundId: compoundId,
            compoundName: "BPC-157",
            scheduledDate: Date(),
            doseAmount: 250,
            doseUnit: .mcg,
            vialId: vial.id
        )

        let result = engine.validateDoseEntry(
            candidate: dose,
            attachedVial: vial,
            referenceDate: Date()
        )

        XCTAssertTrue(result.hasWarnings)
        let freshnessWarning = result.warnings.first(where: { $0.title.contains("Freshness Window") })
        XCTAssertNotNil(freshnessWarning)
        XCTAssertTrue(freshnessWarning?.explanation.contains("45 days ago") ?? false)
    }

    func testInvertedDiagnosticLabPanelDates() {
        let collectionDate = Date()
        let resultDateInPast = calendar.date(byAdding: .day, value: -3, to: collectionDate)!

        let panel = LabPanel(
            panelName: "Thyroid Complete",
            collectionDate: collectionDate,
            resultDate: resultDateInPast,
            results: [
                LabResult(biomarkerName: "TSH", value: 2.1, unit: "uIU/mL")
            ]
        )

        let result = engine.validateLabPanel(panel: panel)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.field == "resultDate" }))
    }

    // MARK: - 6. Schedule Conflicts Tests

    func testInvertedProtocolStartAndEndDates() {
        let startDate = Date()
        let endDateInPast = calendar.date(byAdding: .day, value: -7, to: startDate)!

        let proto = ProtocolModel(
            name: "Protocol A",
            startDate: startDate,
            endDate: endDateInPast,
            compounds: [
                ProtocolCompound(
                    compoundId: UUID(),
                    compoundName: "BPC-157",
                    doseAmount: 250,
                    doseUnit: .mcg
                )
            ]
        )

        let result = engine.validateProtocol(protocolModel: proto)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.field == "endDate" }))
    }

    func testDoseOnUnscheduledRestDay() {
        let startDate = calendar.startOfDay(for: Date())
        let compoundId = UUID()

        // 5 Days On / 2 Days Off cycle. Day 5 (index 5) is Day 1 of Days Off.
        let protoCompound = ProtocolCompound(
            compoundId: compoundId,
            compoundName: "Tesamorelin",
            doseAmount: 1.0,
            doseUnit: .mg,
            scheduleRule: .cycle(daysOn: 5, daysOff: 2)
        )

        let proto = ProtocolModel(
            name: "GH Optimization",
            status: .active,
            startDate: startDate,
            compounds: [protoCompound]
        )

        // Target date is Day 5 (an off-day)
        let offDate = calendar.date(byAdding: .day, value: 5, to: startDate)!
        let dose = DoseLog(
            compoundId: compoundId,
            compoundName: "Tesamorelin",
            scheduledDate: offDate,
            doseAmount: 1.0,
            doseUnit: .mg,
            isPRNOrUnscheduled: false
        )

        let result = engine.validateDoseEntry(
            candidate: dose,
            activeProtocol: proto,
            referenceDate: offDate
        )

        XCTAssertTrue(result.hasWarnings)
        let restDayWarning = result.warnings.first(where: { $0.category == .scheduleConflict })
        XCTAssertNotNil(restDayWarning)
        XCTAssertTrue(restDayWarning?.title.contains("Rest Day") ?? false)
    }

    func testConcurrentActiveProtocolCompoundOverlap() {
        let sharedCompoundId = UUID()

        let existingProto = ProtocolModel(
            id: UUID(),
            name: "Existing Protocol",
            status: .active,
            compounds: [
                ProtocolCompound(compoundId: sharedCompoundId, compoundName: "BPC-157", doseAmount: 250, doseUnit: .mcg)
            ]
        )

        let newProto = ProtocolModel(
            id: UUID(),
            name: "New Joint Protocol",
            status: .active,
            compounds: [
                ProtocolCompound(compoundId: sharedCompoundId, compoundName: "BPC-157", doseAmount: 500, doseUnit: .mcg)
            ]
        )

        let result = engine.validateProtocol(protocolModel: newProto, existingProtocols: [existingProto])
        XCTAssertTrue(result.isValid) // Warning only
        XCTAssertTrue(result.hasWarnings)
        XCTAssertTrue(result.warnings.contains(where: { $0.title.contains("Active Compound Overlap") }))
    }

    func testInvertedProtocolDoseRangeMinMax() {
        let item = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "Semaglutide",
            doseAmount: 500,
            doseUnit: .mcg,
            doseRangeMin: 1000,
            doseRangeMax: 250 // Inverted: min > max
        )

        let result = engine.validateProtocolCompound(item: item)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.field == "doseRangeMax" }))
    }

    func testTitrationStepDirectionMismatch() {
        let titration = TitrationRule(
            startDose: 250,
            targetDose: 1000,
            stepAmount: -50, // Conflict: target > start but step is negative
            stepIntervalDays: 7
        )

        let item = ProtocolCompound(
            compoundId: UUID(),
            compoundName: "Tirzepatide",
            doseAmount: 250,
            doseUnit: .mcg,
            titrationStep: titration
        )

        let result = engine.validateProtocolCompound(item: item)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.field == "titrationStep" }))
    }

    // MARK: - 7. Physiological Bounds Tests

    func testBloodPressureDiastolicExceedsSystolic() {
        // Diastolic 130 > Systolic 110 (Impossible)
        let measurement = Measurement.bloodPressure(
            systolic: 110,
            diastolic: 130,
            dateRecorded: Date()
        )

        let result = engine.validateMeasurement(measurement: measurement)
        XCTAssertFalse(result.isValid)
        let bpError = result.blockingErrors.first(where: { $0.field == "secondaryValue" })
        XCTAssertNotNil(bpError)
        XCTAssertTrue(bpError?.title.contains("Diastolic Exceeds Systolic") ?? false)
    }

    func testSleepDurationExceeds24Hours() {
        let measurement = Measurement.sleep(
            hours: 26.5,
            dateRecorded: Date()
        )

        let result = engine.validateMeasurement(measurement: measurement)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.title.contains("Exceeds 24 Hours") }))
    }

    func testNegativeBodyWeight() {
        let measurement = Measurement.weight(
            -150.0,
            unit: .lbs,
            dateRecorded: Date()
        )

        let result = engine.validateMeasurement(measurement: measurement)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.title.contains("Non-Positive Body Weight") }))
    }

    func testSubjectiveScoreOutOfBounds() {
        let measurement = Measurement.energy(
            level: 15.0, // Scale is 0 to 10
            dateRecorded: Date()
        )

        let result = engine.validateMeasurement(measurement: measurement)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.blockingErrors.contains(where: { $0.title.contains("Score Out of Range") }))
    }

    func testConsecutiveInjectionSiteOveruseWarning() {
        let siteId = "ab_l_uo"
        let now = Date()

        let event1 = InjectionSiteEvent(
            id: UUID(),
            doseEventId: UUID(),
            siteId: siteId,
            siteName: "Left Abdomen (Upper Outer)",
            region: .abdomen,
            side: .left,
            quadrant: .upperOuter,
            route: .subcutaneous,
            timestamp: now.addingTimeInterval(-86400),
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg
        )

        let event2 = InjectionSiteEvent(
            id: UUID(),
            doseEventId: UUID(),
            siteId: siteId,
            siteName: "Left Abdomen (Upper Outer)",
            region: .abdomen,
            side: .left,
            quadrant: .upperOuter,
            route: .subcutaneous,
            timestamp: now.addingTimeInterval(-43200),
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg
        )

        let candidateEvent = InjectionSiteEvent(
            id: UUID(),
            doseEventId: UUID(),
            siteId: siteId,
            siteName: "Left Abdomen (Upper Outer)",
            region: .abdomen,
            side: .left,
            quadrant: .upperOuter,
            route: .subcutaneous,
            timestamp: now,
            compoundId: UUID(),
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg
        )

        let result = engine.validateInjectionSiteEvent(
            event: candidateEvent,
            recentSiteEvents: [event2, event1]
        )

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.hasWarnings)
        let siteWarning = result.warnings.first(where: { $0.category == .anatomicalRouteMismatch })
        XCTAssertNotNil(siteWarning)
        XCTAssertTrue(siteWarning?.title.contains("Site Overuse") ?? false)
    }

    // MARK: - 8. Severity Classification & Neutral Phrasing Tests

    func testSeverityOrderingAndFiltering() {
        let issueBlocking = ValidationIssue.blockingError(
            category: .missingRequiredField,
            title: "Blocking Error",
            explanation: "Must be fixed."
        )
        let issueWarning = ValidationIssue.warning(
            category: .outlierDose,
            title: "Warning Outlier",
            explanation: "Mathematical outlier."
        )
        let issueInfo = ValidationIssue.info(
            category: .general,
            title: "Info Notice",
            explanation: "Helpful tip."
        )

        let result = ValidationResult(issues: [issueInfo, issueBlocking, issueWarning])

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.blockingErrors.count, 1)
        XCTAssertEqual(result.warnings.count, 1)
        XCTAssertEqual(result.informationalMessages.count, 1)

        // Verify sorted order: blockingError < warning < info
        XCTAssertEqual(result.issues[0].severity, .blockingError)
        XCTAssertEqual(result.issues[1].severity, .warning)
        XCTAssertEqual(result.issues[2].severity, .info)

        XCTAssertThrowsError(try result.throwIfInvalid())
    }

    func testWarningExplanationsAreNeutralAndNonPresumptuous() {
        let compound = Compound(
            name: "Tirzepatide",
            defaultUnit: .mg,
            typicalDose: 2.5
        )

        // 10x typical dose
        let candidate = DoseLog(
            compoundId: compound.id,
            compoundName: "Tirzepatide",
            scheduledDate: Date(),
            doseAmount: 25.0,
            doseUnit: .mg
        )

        let result = engine.validateDoseEntry(
            candidate: candidate,
            compound: compound,
            recentLogs: []
        )

        XCTAssertTrue(result.hasWarnings)
        let outlierWarning = result.warnings.first(where: { $0.category == .outlierDose })
        XCTAssertNotNil(outlierWarning)

        // Ensure explanation describes the mathematical/factual difference (10x ratio, 25 mg vs 2.5 mg)
        // rather than claiming clinical/medical diagnosis ("will cause death / hypoglycemia / toxic")
        let explanation = outlierWarning!.explanation
        XCTAssertTrue(explanation.contains("10.0x higher than the reference typical dose"))
        XCTAssertFalse(explanation.lowercased().contains("toxic"))
        XCTAssertFalse(explanation.lowercased().contains("lethal"))
        XCTAssertFalse(explanation.lowercased().contains("hypoglycemia"))
    }
}
