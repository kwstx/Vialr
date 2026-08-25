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

    func testCustomCompoundCreationAndShortCodeGeneration() throws {
        let customCompound = Compound.custom(
            name: "Epitalon Peptide",
            category: .custom,
            customCategoryName: "Telomere Extension",
            createdByUserId: UUID(),
            defaultUnit: .mg,
            typicalDose: 10.0,
            halfLifeHours: 0.5,
            administrationRoute: .subcutaneous,
            storageCondition: .refrigerated,
            requiresReconstitution: true,
            description: "Synthetic tetrapeptide for telomerase activation.",
            instructions: "Administer 10mg daily for 10 consecutive days each quarter.",
            tags: ["Longevity", "Anti-Aging"]
        )

        XCTAssertTrue(customCompound.isCustom)
        XCTAssertEqual(customCompound.source, .customUserCreated)
        XCTAssertEqual(customCompound.displayCategory, "Telomere Extension")
        XCTAssertEqual(customCompound.displayShortCode, "EP")
        XCTAssertTrue(customCompound.requiresReconstitution)
        XCTAssertEqual(customCompound.effectiveIconName, "flask.fill")

        let encoder = JSONEncoder()
        let data = try encoder.encode(customCompound)
        let decoded = try JSONDecoder().decode(Compound.self, from: data)

        XCTAssertEqual(decoded.name, "Epitalon Peptide")
        XCTAssertTrue(decoded.isCustom)
        XCTAssertEqual(decoded.source, .customUserCreated)
        XCTAssertEqual(decoded.customCategoryName, "Telomere Extension")
        XCTAssertEqual(decoded.displayCategory, "Telomere Extension")
        XCTAssertEqual(decoded.instructions, "Administer 10mg daily for 10 consecutive days each quarter.")
    }


    func testProtocolItemScheduleRuleDescription() {
        let daily = ScheduleRule.everyDay
        XCTAssertEqual(daily.description, "Daily")

        let cycle = ScheduleRule.cycle(daysOn: 5, daysOff: 2)
        XCTAssertEqual(cycle.description, "5 Days On / 2 Days Off")
    }

    func testProtocolModelAndCompounds() throws {
        let protoId = UUID()
        let bpcId = UUID()
        let tbId = UUID()
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -10, to: Date())!
        let end = calendar.date(byAdding: .day, value: 20, to: Date())!

        let protocolModel = ProtocolModel(
            id: protoId,
            name: "Joint Healing Stack",
            status: .active,
            startDate: start,
            endDate: end,
            notes: "Rotate injection sites daily; monitor mobility.",
            compounds: [
                ProtocolCompound(
                    compoundId: bpcId,
                    compoundName: "BPC-157",
                    doseAmount: 250,
                    doseUnit: .mcg,
                    scheduleRule: .everyDay,
                    preferredTimeOfDay: .morning,
                    preferredRoute: .subcutaneous,
                    notes: "Morning fasted dose"
                ),
                ProtocolCompound(
                    compoundId: tbId,
                    compoundName: "TB-500",
                    doseAmount: 2.5,
                    doseUnit: .mg,
                    scheduleRule: .daysOfWeek([2, 5]),
                    preferredTimeOfDay: .evening,
                    preferredRoute: .subcutaneous,
                    notes: "Bi-weekly loading"
                )
            ],
            goalSummary: "Accelerate tendon rehabilitation"
        )

        XCTAssertEqual(protocolModel.name, "Joint Healing Stack")
        XCTAssertEqual(protocolModel.status, .active)
        XCTAssertTrue(protocolModel.isCurrentlyActive)
        XCTAssertFalse(protocolModel.isOngoing)
        XCTAssertEqual(protocolModel.compounds.count, 2)
        XCTAssertEqual(protocolModel.items.count, 2)
        XCTAssertEqual(protocolModel.totalPlannedDays, 30)
        XCTAssertGreaterThan(protocolModel.progressPercentage ?? 0, 30.0)

        let encoder = JSONEncoder()
        let data = try encoder.encode(protocolModel)
        let decoded = try JSONDecoder().decode(ProtocolModel.self, from: data)

        XCTAssertEqual(decoded.id, protoId)
        XCTAssertEqual(decoded.name, "Joint Healing Stack")
        XCTAssertEqual(decoded.status, .active)
        XCTAssertEqual(decoded.compounds.count, 2)
        XCTAssertEqual(decoded.compounds[0].compoundName, "BPC-157")
        XCTAssertEqual(decoded.compounds[1].compoundName, "TB-500")
        XCTAssertEqual(decoded.notes, "Rotate injection sites daily; monitor mobility.")
    }

    func testProtocolCompoundSchedulingAndTitration() throws {
        let compoundId = UUID()
        let protocolStart = Date(timeIntervalSince1970: 1704067200) // Jan 1, 2024 (Monday)

        let item = ProtocolCompound(
            compoundId: compoundId,
            compoundName: "Tirzepatide",
            doseAmount: 2.5,
            doseUnit: .mg,
            route: .subcutaneous,
            scheduleRule: .everyNDays(7),
            preferredTimeOfDay: .morning,
            reminderEnabled: true,
            titrationStep: TitrationRule(
                startDose: 2.5,
                targetDose: 10.0,
                stepAmount: 2.5,
                stepIntervalDays: 28
            ),
            foodRequirement: .fasted,
            instructions: "Take once weekly in morning fasted state."
        )

        // Day 0: start dose = 2.5mg, scheduled = true
        XCTAssertTrue(item.isScheduled(on: protocolStart, protocolStart: protocolStart))
        XCTAssertEqual(item.effectiveDoseAmount(on: protocolStart, relativeTo: protocolStart), 2.5)

        // Day 3: not scheduled on everyNDays(7)
        let day3 = Calendar.current.date(byAdding: .day, value: 3, to: protocolStart)!
        XCTAssertFalse(item.isScheduled(on: day3, protocolStart: protocolStart))

        // Day 7: scheduled on everyNDays(7)
        let day7 = Calendar.current.date(byAdding: .day, value: 7, to: protocolStart)!
        XCTAssertTrue(item.isScheduled(on: day7, protocolStart: protocolStart))

        // Day 28: first titration step (+2.5mg -> 5.0mg)
        let day28 = Calendar.current.date(byAdding: .day, value: 28, to: protocolStart)!
        XCTAssertEqual(item.effectiveDoseAmount(on: day28, relativeTo: protocolStart), 5.0)

        // Day 84: 3 steps (+7.5mg -> 10.0mg target cap)
        let day84 = Calendar.current.date(byAdding: .day, value: 84, to: protocolStart)!
        XCTAssertEqual(item.effectiveDoseAmount(on: day84, relativeTo: protocolStart), 10.0)

        // Summary string
        XCTAssertTrue(item.summaryDescription.contains("Tirzepatide 2.5 mg"))
        XCTAssertTrue(item.summaryDescription.contains("SubQ"))
    }

    func testDoseEventPlannedVsActualAndAdherence() throws {
        let calendar = Calendar.current
        let baseDate = Date(timeIntervalSince1970: 1704096000) // Jan 1, 2024 08:00 UTC
        let scheduledTime = baseDate
        let actualTakenTime = calendar.date(byAdding: .minute, value: 35, to: scheduledTime)! // 35 min late

        let event = DoseEvent(
            compoundId: UUID(),
            compoundName: "BPC-157",
            scheduledTimestamp: scheduledTime,
            actualTimestamp: actualTakenTime,
            plannedDoseAmount: 250.0,
            actualDoseAmount: 250.0,
            doseUnit: .mcg,
            status: .taken,
            injectionSiteId: "ab_l_uo",
            injectionSiteName: "Abdomen - Left Upper Outer",
            actualRoute: .subcutaneous,
            plannedRoute: .subcutaneous,
            notes: "Quick painless morning injection"
        )

        XCTAssertTrue(event.isTaken)
        XCTAssertEqual(event.adherenceVarianceMinutes, 35)
        XCTAssertTrue(event.isTakenOnTime(toleranceMinutes: 60))
        XCTAssertFalse(event.isTakenOnTime(toleranceMinutes: 30))
        XCTAssertEqual(event.dosageDeviation, 0.0)

        // Test skipped dose with reason
        let skippedEvent = DoseEvent(
            compoundId: UUID(),
            compoundName: "TB-500",
            scheduledTimestamp: scheduledTime,
            actualTimestamp: nil,
            plannedDoseAmount: 2.5,
            actualDoseAmount: 0.0,
            doseUnit: .mg,
            status: .skipped,
            actualRoute: .subcutaneous,
            skippedReason: "Traveling - forgot vial in hotel fridge"
        )

        XCTAssertFalse(skippedEvent.isTaken)
        XCTAssertNil(skippedEvent.adherenceVarianceMinutes)
        XCTAssertEqual(skippedEvent.dosageDeviation, -2.5)
        XCTAssertEqual(skippedEvent.skippedReason, "Traveling - forgot vial in hotel fridge")

        // JSON Codable verification
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let decoded = try JSONDecoder().decode(DoseEvent.self, from: data)

        XCTAssertEqual(decoded.compoundName, "BPC-157")
        XCTAssertEqual(decoded.status, .taken)
        XCTAssertEqual(decoded.actualDoseAmount, 250.0)
        XCTAssertEqual(decoded.plannedDoseAmount, 250.0)
    }

    func testInjectionSiteEventConnectingToDoseEvent() throws {
        let doseEventId = UUID()
        let compoundId = UUID()
        let timestamp = Date(timeIntervalSince1970: 1704096000)

        let doseEvent = DoseEvent(
            id: doseEventId,
            compoundId: compoundId,
            compoundName: "BPC-157",
            scheduledTimestamp: timestamp,
            actualTimestamp: timestamp,
            plannedDoseAmount: 250.0,
            actualDoseAmount: 250.0,
            doseUnit: .mcg,
            status: .taken,
            injectionSiteId: "ab_r_uo",
            injectionSiteName: "Abdomen - Right Upper Outer",
            actualRoute: .subcutaneous
        )

        let site = InjectionSite.standardSites.first(where: { $0.id == "ab_r_uo" })!
        let siteEvent = InjectionSiteEvent(
            site: site,
            doseEvent: doseEvent,
            needleGauge: "31G",
            needleLength: "5/16\"",
            reaction: .none,
            painScore: 1,
            notes: "Smooth injection, no resistance."
        )

        XCTAssertEqual(siteEvent.doseEventId, doseEventId)
        XCTAssertEqual(siteEvent.siteId, "ab_r_uo")
        XCTAssertEqual(siteEvent.siteName, "Abdomen - Right Upper Outer")
        XCTAssertEqual(siteEvent.region, .abdomen)
        XCTAssertEqual(siteEvent.side, .right)
        XCTAssertEqual(siteEvent.quadrant, .upperOuter)
        XCTAssertEqual(siteEvent.route, .subcutaneous)
        XCTAssertEqual(siteEvent.compoundName, "BPC-157")
        XCTAssertEqual(siteEvent.doseAmount, 250.0)
        XCTAssertEqual(siteEvent.reaction, .none)
        XCTAssertFalse(siteEvent.reaction.requiresRest)
        XCTAssertTrue(siteEvent.isFullyRested)

        // Codable serialization test
        let encoder = JSONEncoder()
        let data = try encoder.encode(siteEvent)
        let decoded = try JSONDecoder().decode(InjectionSiteEvent.self, from: data)

        XCTAssertEqual(decoded.id, siteEvent.id)
        XCTAssertEqual(decoded.doseEventId, doseEventId)
        XCTAssertEqual(decoded.siteId, "ab_r_uo")
        XCTAssertEqual(decoded.painScore, 1)
    }





    func testVialDynamicsAndInventoryProperties() throws {
        let vialId = UUID()
        let compoundId = UUID()
        let now = Date()

        let vial = Vial(
            id: vialId,
            compoundId: compoundId,
            compoundName: "Tirzepatide",
            compoundCategory: .glp1Metabolic,
            lotNumber: "LOT-TRZ-2024",
            batchNumber: "B-902",
            vendor: "Precision Research",
            purityPercentage: 99.6,
            totalDryMassMg: 10.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 1.5,
            isReconstituted: true,
            reconstitutedDate: now,
            expirationDate: Calendar.current.date(byAdding: .day, value: 30, to: now),
            costUsd: 80.0,
            status: .reconstituted,
            notes: "High purity batch, stored in fridge door."
        )

        // Concentration: 10mg / 2mL = 5.0 mg/mL = 5000 mcg/mL
        XCTAssertEqual(vial.concentrationMgMl ?? 0, 5.0, accuracy: 0.001)
        XCTAssertEqual(vial.concentrationMcgMl ?? 0, 5000.0, accuracy: 0.001)

        // Remaining fractions: 1.5mL / 2.0mL = 0.75 (75%)
        XCTAssertEqual(vial.remainingFraction, 0.75, accuracy: 0.001)
        XCTAssertEqual(vial.remainingPercentage, 75.0, accuracy: 0.001)
        XCTAssertEqual(vial.remainingMassMg ?? 0, 7.5, accuracy: 0.001)

        // Target dose: 2.5mg -> draw volume = 0.5 mL -> 50 U-100 units
        XCTAssertEqual(vial.drawVolumeMl(for: 2.5, unit: .mg) ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(vial.u100SyringeUnits(for: 2.5, unit: .mg) ?? 0, 50.0, accuracy: 0.001)

        // Estimated remaining doses: 1.5mL / 0.5mL = 3 doses
        XCTAssertEqual(vial.estimatedDosesRemaining(doseAmount: 2.5, unit: .mg), 3)

        // Financial costs: $80 / 10mg = $8.00 per mg -> 2.5mg dose = $20.00
        XCTAssertEqual(vial.costPerMgUsd ?? 0, 8.0, accuracy: 0.001)
        XCTAssertEqual(vial.costPerDoseUsd(doseAmount: 2.5, unit: .mg) ?? 0, 20.0, accuracy: 0.001)

        // Freshness and Expiration
        XCTAssertFalse(vial.isExpired)
        XCTAssertTrue(vial.isWithinOptimalFreshness(maxDays: 30))

        // JSON Codable
        let encoder = JSONEncoder()
        let data = try encoder.encode(vial)
        let decoded = try JSONDecoder().decode(Vial.self, from: data)

        XCTAssertEqual(decoded.id, vialId)
        XCTAssertEqual(decoded.lotNumber, "LOT-TRZ-2024")
        XCTAssertEqual(decoded.vendor, "Precision Research")
        XCTAssertEqual(decoded.purityPercentage, 99.6)
        XCTAssertEqual(decoded.costUsd, 80.0)
        XCTAssertEqual(decoded.status, .reconstituted)
    }

    func testReconstitutionRecordImmutabilityAndRevisionHistory() throws {
        let vialId = UUID()
        let compoundId = UUID()
        let prepDate = Date(timeIntervalSince1970: 1704096000)

        // Version 1: 5mg in 2.0mL BAC water -> 2.5mg/mL
        let recordV1 = ReconstitutionRecord(
            vialId: vialId,
            compoundId: compoundId,
            compoundName: "BPC-157",
            dryMassMg: 5.0,
            diluentVolumeMl: 2.0,
            diluentType: .bacteriostaticWater,
            diluentLotNumber: "BAC-4481",
            reconstitutedAt: prepDate,
            isConfirmed: true,
            confirmedAt: prepDate,
            version: 1,
            effectiveFrom: prepDate
        )

        XCTAssertEqual(recordV1.concentrationMgMl, 2.5, accuracy: 0.001)
        XCTAssertEqual(recordV1.concentrationMcgMl, 2500.0, accuracy: 0.001)
        XCTAssertEqual(recordV1.drawVolumeMl(for: 250, unit: .mcg), 0.1, accuracy: 0.001)
        XCTAssertEqual(recordV1.u100SyringeUnits(for: 250, unit: .mcg), 10.0, accuracy: 0.001)
        XCTAssertTrue(recordV1.isConfirmed)
        XCTAssertTrue(recordV1.isCurrentActiveRevision)
        XCTAssertNil(recordV1.effectiveTo)

        // Superseding Revision (e.g. Added 0.5 mL extra diluent to dilute solution)
        let revisionDate = Calendar.current.date(byAdding: .day, value: 5, to: prepDate)!
        let (supersededV1, recordV2) = recordV1.createSupersedingRevision(
            newDiluentVolumeMl: 2.5,
            revisionReason: "Added 0.5mL BAC water to dilute injection volume",
            effectiveDate: revisionDate
        )

        // Old revision is locked with effectiveTo timestamp and pointer to new record
        XCTAssertFalse(supersededV1.isCurrentActiveRevision)
        XCTAssertEqual(supersededV1.effectiveTo, revisionDate)
        XCTAssertEqual(supersededV1.supersededByRecordId, recordV2.id)
        XCTAssertEqual(supersededV1.concentrationMgMl, 2.5, accuracy: 0.001) // Historical calculation preserved!

        // New revision is active with new concentration: 5mg / 2.5mL = 2.0mg/mL
        XCTAssertTrue(recordV2.isCurrentActiveRevision)
        XCTAssertEqual(recordV2.version, 2)
        XCTAssertEqual(recordV2.previousRecordId, recordV1.id)
        XCTAssertEqual(recordV2.concentrationMgMl, 2.0, accuracy: 0.001)
        XCTAssertEqual(recordV2.concentrationMcgMl, 2000.0, accuracy: 0.001)
        // Under V2, 250mcg dose now draws 0.125 mL (12.5 units)
        XCTAssertEqual(recordV2.drawVolumeMl(for: 250, unit: .mcg), 0.125, accuracy: 0.001)
        XCTAssertEqual(recordV2.u100SyringeUnits(for: 250, unit: .mcg), 12.5, accuracy: 0.001)

        // Codable serialization test
        let encoder = JSONEncoder()
        let data = try encoder.encode(recordV2)
        let decoded = try JSONDecoder().decode(ReconstitutionRecord.self, from: data)

        XCTAssertEqual(decoded.id, recordV2.id)
        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(decoded.concentrationMgMl, 2.0, accuracy: 0.001)
        XCTAssertEqual(decoded.previousRecordId, recordV1.id)
    }

    func testMeasurementDiversityAndFormatting() throws {
        let date = Date(timeIntervalSince1970: 1704096000)

        // 1. Body Weight
        let weight = Measurement.weight(182.4, unit: .lbs, dateRecorded: date)
        XCTAssertEqual(weight.type, .weight)
        XCTAssertEqual(weight.category, .bodyComposition)
        XCTAssertEqual(weight.formattedValue, "182.4 lbs")

        // 2. Waist
        let waist = Measurement.waist(32.5, unit: .inches, dateRecorded: date)
        XCTAssertEqual(waist.type, .waist)
        XCTAssertEqual(waist.formattedValue, "32.5 in")

        // 3. Blood Pressure
        let bp = Measurement.bloodPressure(systolic: 118, diastolic: 78, dateRecorded: date)
        XCTAssertEqual(bp.type, .bloodPressure)
        XCTAssertEqual(bp.category, .cardiovascular)
        XCTAssertEqual(bp.formattedValue, "118/78 mmHg")
        XCTAssertEqual(bp.status, .inRange)

        // 4. Sleep
        let sleep = Measurement.sleep(hours: 8.2, qualityScore: 9.0, dateRecorded: date)
        XCTAssertEqual(sleep.type, .sleep)
        XCTAssertEqual(sleep.formattedValue, "8.2 hrs")

        // 5. Energy Level (Subjective 1-10)
        let energy = Measurement.energy(level: 9.0, dateRecorded: date)
        XCTAssertEqual(energy.type, .energy)
        XCTAssertEqual(energy.category, .subjectiveWellbeing)
        XCTAssertEqual(energy.formattedValue, "9 / 10")

        // 6. Appetite
        let appetite = Measurement.appetite(level: 4.0, dateRecorded: date)
        XCTAssertEqual(appetite.type, .appetite)
        XCTAssertEqual(appetite.formattedValue, "4 / 10")

        // 7. Custom Metric
        let custom = Measurement.custom(
            name: "Dominant Hand Grip Strength",
            value: 54.0,
            unit: "kg",
            category: .custom,
            referenceRangeMin: 45.0,
            referenceRangeMax: 65.0,
            dateRecorded: date
        )
        XCTAssertEqual(custom.type, .custom)
        XCTAssertEqual(custom.formattedValue, "54 kg")
        XCTAssertEqual(custom.status, .inRange)

        // JSON Codable
        let encoder = JSONEncoder()
        let data = try encoder.encode(bp)
        let decoded = try JSONDecoder().decode(Measurement.self, from: data)

        XCTAssertEqual(decoded.name, "Blood Pressure")
        XCTAssertEqual(decoded.value, 118.0)
        XCTAssertEqual(decoded.secondaryValue, 78.0)
        XCTAssertEqual(decoded.unit, "mmHg")
        XCTAssertEqual(decoded.formattedValue, "118/78 mmHg")
    }


    func testLabPanelAndLabResultAggregation() throws {
        let panelId = UUID()
        let protocolId = UUID()
        let drawDate = Date(timeIntervalSince1970: 1704096000)

        let result1 = LabResult(
            panelId: panelId,
            biomarkerName: "Total Testosterone",
            category: .hormones,
            value: 840.0,
            unit: "ng/dL",
            referenceRangeMin: 250.0,
            referenceRangeMax: 1100.0,
            referenceRangeText: "250 - 1100 ng/dL"
        )

        let result2 = LabResult(
            panelId: panelId,
            biomarkerName: "Fasting Blood Glucose",
            category: .metabolic,
            value: 86.0,
            unit: "mg/dL",
            referenceRangeMin: 70.0,
            referenceRangeMax: 99.0
        )

        let result3 = LabResult(
            panelId: panelId,
            biomarkerName: "hs-CRP (High-Sensitivity)",
            category: .inflammatory,
            value: 4.2,
            unit: "mg/L",
            referenceRangeMin: 0.0,
            referenceRangeMax: 3.0 // High / Elevated
        )

        XCTAssertTrue(result1.isNormal)
        XCTAssertEqual(result1.flag, .inRange)
        XCTAssertEqual(result1.formattedValue, "840 ng/dL")

        XCTAssertTrue(result2.isNormal)
        XCTAssertEqual(result2.flag, .inRange)

        XCTAssertFalse(result3.isNormal)
        XCTAssertEqual(result3.flag, .high)

        let panel = LabPanel(
            id: panelId,
            panelName: "Comprehensive Hormone & Metabolic Diagnostic",
            labName: "Labcorp",
            collectionDate: drawDate,
            status: .completed,
            results: [result1, result2, result3],
            orderingPhysician: "Dr. Alexander Vance, MD",
            associatedProtocolId: protocolId,
            fastingStatus: .fasted
        )

        XCTAssertEqual(panel.resultCount, 3)
        XCTAssertTrue(panel.hasAbnormalResults)
        XCTAssertEqual(panel.abnormalResults.count, 1)
        XCTAssertEqual(panel.abnormalResults.first?.biomarkerName, "hs-CRP (High-Sensitivity)")

        let lookup = panel.result(forBiomarker: "Testosterone")
        XCTAssertNotNil(lookup)
        XCTAssertEqual(lookup?.value, 840.0)

        // JSON Codable
        let encoder = JSONEncoder()
        let data = try encoder.encode(panel)
        let decoded = try JSONDecoder().decode(LabPanel.self, from: data)

        XCTAssertEqual(decoded.id, panelId)
        XCTAssertEqual(decoded.panelName, "Comprehensive Hormone & Metabolic Diagnostic")
        XCTAssertEqual(decoded.results.count, 3)
        XCTAssertEqual(decoded.fastingStatus, .fasted)
    }

    func testDocumentPropertiesAndSerialization() throws {
        let docId = UUID()
        let labPanelId = UUID()
        let protocolId = UUID()
        let drawDate = Date(timeIntervalSince1970: 1704096000)

        // 1. Lab Report PDF
        let labDoc = Document.labReport(
            title: "Quest Comprehensive Metabolic & Hormone Panel",
            fileName: "quest_labs_jan2024.pdf",
            byteSize: 1024 * 1024 * 3, // 3 MB
            sha256Checksum: "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
            labPanelId: labPanelId,
            protocolId: protocolId,
            documentDate: drawDate,
            pageCount: 4,
            notes: "Fasted morning draw @ 8:00 AM"
        )

        XCTAssertEqual(labDoc.category, .labReport)
        XCTAssertEqual(labDoc.fileExtension, "pdf")
        XCTAssertEqual(labDoc.mimeType, "application/pdf")
        XCTAssertTrue(labDoc.isPDF)
        XCTAssertFalse(labDoc.isImage)
        XCTAssertEqual(labDoc.pageCount, 4)
        XCTAssertEqual(labDoc.labPanelId, labPanelId)
        XCTAssertTrue(labDoc.formattedFileSize.contains("3"))

        // 2. Certificate of Analysis (CoA)
        let vialId = UUID()
        let compoundId = UUID()
        let coaDoc = Document.certificateOfAnalysis(
            title: "Tirzepatide 10mg HPLC Purity Report",
            fileName: "tirzepatide_batch_902_coa.pdf",
            byteSize: 512 * 1024,
            vialId: vialId,
            compoundId: compoundId,
            notes: "Purity verified at 99.6%"
        )

        XCTAssertEqual(coaDoc.category, .certificateOfAnalysis)
        XCTAssertEqual(coaDoc.vialId, vialId)
        XCTAssertEqual(coaDoc.compoundId, compoundId)

        // JSON Codable
        let encoder = JSONEncoder()
        let data = try encoder.encode(labDoc)
        let decoded = try JSONDecoder().decode(Document.self, from: data)

        XCTAssertEqual(decoded.title, "Quest Comprehensive Metabolic & Hormone Panel")
        XCTAssertEqual(decoded.fileName, "quest_labs_jan2024.pdf")
        XCTAssertEqual(decoded.category, .labReport)
        XCTAssertEqual(decoded.sha256Checksum, "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08")
    }

    func testTimelineEventUnifiedFeedAggregation() throws {
        let baseDate = Date(timeIntervalSince1970: 1704096000) // Jan 1, 2024
        let day2 = Calendar.current.date(byAdding: .day, value: 1, to: baseDate)!
        let day3 = Calendar.current.date(byAdding: .day, value: 2, to: baseDate)!
        let day4 = Calendar.current.date(byAdding: .day, value: 3, to: baseDate)!

        // 1. Reconstitution Event (Day 1)
        let recon = ReconstitutionRecord(
            vialId: UUID(),
            compoundId: UUID(),
            compoundName: "BPC-157",
            dryMassMg: 5.0,
            diluentVolumeMl: 2.0,
            reconstitutedAt: baseDate
        )
        let reconEvent = TimelineEvent(from: recon)
        XCTAssertEqual(reconEvent.category, .reconstitution)
        XCTAssertTrue(reconEvent.title.contains("Reconstituted BPC-157"))

        // 2. Dose Event (Day 2)
        let dose = DoseEvent(
            compoundId: UUID(),
            compoundName: "BPC-157",
            scheduledTimestamp: day2,
            actualTimestamp: day2,
            plannedDoseAmount: 250.0,
            actualDoseAmount: 250.0,
            doseUnit: .mcg,
            status: .taken,
            injectionSiteName: "Abdomen - Left Upper Outer"
        )
        let doseEvent = TimelineEvent(from: dose)
        XCTAssertEqual(doseEvent.category, .dose)
        XCTAssertTrue(doseEvent.subtitle.contains("250 mcg"))
        XCTAssertTrue(doseEvent.subtitle.contains("Abdomen"))

        // 3. Weight Measurement (Day 3)
        let weight = Measurement.weight(181.8, unit: .lbs, dateRecorded: day3)
        let weightEvent = TimelineEvent(from: weight)
        XCTAssertEqual(weightEvent.category, .measurement)
        XCTAssertEqual(weightEvent.subtitle, "181.8 lbs")

        // 4. Document Upload (Day 4)
        let doc = Document.labReport(
            title: "Quest Blood Panel",
            fileName: "quest.pdf",
            byteSize: 1024 * 500,
            documentDate: day4
        )
        let docEvent = TimelineEvent(from: doc)
        XCTAssertEqual(docEvent.category, .document)

        // 5. Test Unified Feed Sorting
        let feed = TimelineEvent.unifiedFeed(
            doses: [dose],
            measurements: [weight],
            labPanels: [],
            reconstitutions: [recon],
            documents: [doc],
            protocols: []
        )

        XCTAssertEqual(feed.count, 4)
        // Feed must be sorted reverse-chronologically (newest first)
        XCTAssertEqual(feed[0].category, .document)
        XCTAssertEqual(feed[1].category, .measurement)
        XCTAssertEqual(feed[2].category, .dose)
        XCTAssertEqual(feed[3].category, .reconstitution)

        // JSON Codable
        let encoder = JSONEncoder()
        let data = try encoder.encode(doseEvent)
        let decoded = try JSONDecoder().decode(TimelineEvent.self, from: data)

        XCTAssertEqual(decoded.title, doseEvent.title)
        XCTAssertEqual(decoded.category, .dose)
        XCTAssertEqual(decoded.badgeText, "Taken")
    }

    func testOutcomeMetricEfficacyAndProgressCalculations() throws {
        let protocolId = UUID()
        let startDate = Date(timeIntervalSince1970: 1704096000)

        // 1. Weight loss metric (Decrease target)
        // Baseline: 200 lbs, Target: 180 lbs (Delta needed: -20 lbs)
        // Current: 185 lbs (Delta achieved: -15 lbs -> 75% progress)
        let weightMetric = OutcomeMetric(
            protocolId: protocolId,
            name: "Body Weight",
            category: .bodyComposition,
            baselineValue: 200.0,
            baselineDate: startDate,
            targetValue: 180.0,
            targetDirection: .decrease,
            unit: "lbs",
            currentValue: 185.0,
            priority: .primary
        )

        XCTAssertEqual(weightMetric.deltaFromBaseline, -15.0)
        XCTAssertEqual(weightMetric.percentageChangeFromBaseline ?? 0, -7.5, accuracy: 0.001)
        XCTAssertEqual(weightMetric.progressPercentage, 75.0, accuracy: 0.001)
        XCTAssertFalse(weightMetric.isTargetAchieved)
        XCTAssertEqual(weightMetric.evaluationStatus, .onTrack)
        XCTAssertTrue(weightMetric.summaryProgressText.contains("75% achieved"))

        // 2. Goal achieved state
        var achievedMetric = weightMetric
        achievedMetric.currentValue = 178.0 // Exceeded target of 180 lbs
        XCTAssertTrue(achievedMetric.isTargetAchieved)
        XCTAssertEqual(achievedMetric.evaluationStatus, .targetReached)

        // 3. Biomarker elevation metric (Increase target)
        // Baseline: 350 ng/dL -> Target: 850 ng/dL (+500 delta needed)
        // Current: 600 ng/dL (+250 delta achieved -> 50% progress)
        let testMetric = OutcomeMetric(
            protocolId: protocolId,
            name: "Total Testosterone",
            category: .bloodBiomarker,
            baselineValue: 350.0,
            baselineDate: startDate,
            targetValue: 850.0,
            targetDirection: .increase,
            unit: "ng/dL",
            currentValue: 600.0,
            linkedBiomarkerName: "Total Testosterone"
        )

        XCTAssertEqual(testMetric.deltaFromBaseline, 250.0)
        XCTAssertEqual(testMetric.progressPercentage, 50.0, accuracy: 0.001)
        XCTAssertEqual(testMetric.evaluationStatus, .onTrack)

        // JSON Codable
        let encoder = JSONEncoder()
        let data = try encoder.encode(weightMetric)
        let decoded = try JSONDecoder().decode(OutcomeMetric.self, from: data)

        XCTAssertEqual(decoded.name, "Body Weight")
        XCTAssertEqual(decoded.baselineValue, 200.0)
        XCTAssertEqual(decoded.targetValue, 180.0)
        XCTAssertEqual(decoded.targetDirection, .decrease)
        XCTAssertEqual(decoded.currentValue, 185.0)
    }

    func testCostEventAndProtocolRealCostCalculations() throws {
        let protocolId = UUID()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())! // 30 days elapsed

        let proto = ProtocolModel(
            id: protocolId,
            name: "GLP-1 Metabolic Phase 1",
            status: .active,
            startDate: startDate,
            endDate: nil,
            notes: "Active weight optimization"
        )

        // 1. Compound vial expense ($160 for 2 vials)
        let costVial1 = CostEvent(
            title: "Tirzepatide 10mg Vial",
            amount: 80.0,
            category: .peptideVial,
            protocolId: protocolId
        )
        let costVial2 = CostEvent(
            title: "Tirzepatide 10mg Vial #2",
            amount: 80.0,
            category: .peptideVial,
            protocolId: protocolId
        )

        // 2. Ancillary supplies ($25 for syringes & BAC water)
        let costSupplies = CostEvent(
            title: "100x Insulin Syringes + 30mL BAC Water",
            amount: 25.0,
            category: .medicalSupplies,
            protocolId: protocolId
        )

        // 3. Baseline bloodwork panel ($120)
        let costLabs = CostEvent(
            title: "Quest Baseline Metabolic Panel",
            amount: 120.0,
            category: .bloodwork,
            protocolId: protocolId
        )

        XCTAssertEqual(costVial1.formattedAmount, "$80.00")
        XCTAssertEqual(costSupplies.category, .medicalSupplies)

        // 4. Completed Doses (e.g. 8 weekly doses taken)
        var doses: [DoseEvent] = []
        for i in 0..<8 {
            doses.append(
                DoseEvent(
                    protocolId: protocolId,
                    compoundId: UUID(),
                    compoundName: "Tirzepatide",
                    actualDoseAmount: 2.5,
                    status: .taken
                )
            )
        }

        // 5. Calculate Real Cost Summary
        let allCosts = [costVial1, costVial2, costSupplies, costLabs]
        let summary = ProtocolCostSummary.calculate(
            protocolModel: proto,
            costEvents: allCosts,
            completedDoses: doses
        )

        // Total: 80 + 80 + 25 + 120 = $285.00
        XCTAssertEqual(summary.totalCost, 285.0, accuracy: 0.001)
        XCTAssertEqual(summary.totalCompoundCost, 160.0, accuracy: 0.001)
        XCTAssertEqual(summary.totalSuppliesCost, 25.0, accuracy: 0.001)
        XCTAssertEqual(summary.totalBloodworkCost, 120.0, accuracy: 0.001)

        // Cost per day: $285 / 30 days = $9.50/day
        XCTAssertEqual(summary.costPerDay, 9.50, accuracy: 0.05)

        // Cost per dose: $285 / 8 doses = $35.625/dose
        XCTAssertEqual(summary.costPerDoseAverage, 35.625, accuracy: 0.001)

        // JSON Codable
        let encoder = JSONEncoder()
        let data = try encoder.encode(costVial1)
        let decoded = try JSONDecoder().decode(CostEvent.self, from: data)

        XCTAssertEqual(decoded.title, "Tirzepatide 10mg Vial")
        XCTAssertEqual(decoded.amount, 80.0)
        XCTAssertEqual(decoded.protocolId, protocolId)
    }









    func testStoredFileRecordEncodingDecoding() throws {
        let fileId = UUID()
        let userId = UUID()
        let vialId = UUID()
        let record = StoredFileRecord(
            id: fileId,
            userId: userId,
            category: .vialPhoto,
            fileName: "bpc157_batch_402.jpg",
            contentType: "image/jpeg",
            byteSize: 1024 * 500,
            sha256Checksum: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            storageBucket: "vialr-secure-vault",
            storageKey: "vault/users/\(userId.uuidString)/vial-photos/\(fileId.uuidString).enc",
            encryption: StorageEncryptionMetadata(
                algorithm: "AES-256-GCM",
                keyId: "vialr-vault-primary",
                initializationVector: "YWJjZGVmZ2hpams=",
                authenticationTag: "dGFnMTIzNDU2Nzg=",
                isEncrypted: true
            ),
            vialId: vialId,
            metadata: ["width": "1920", "height": "1080"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(record)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StoredFileRecord.self, from: data)

        XCTAssertEqual(decoded.id, fileId)
        XCTAssertEqual(decoded.userId, userId)
        XCTAssertEqual(decoded.category, .vialPhoto)
        XCTAssertEqual(decoded.fileName, "bpc157_batch_402.jpg")
        XCTAssertEqual(decoded.contentType, "image/jpeg")
        XCTAssertEqual(decoded.vialId, vialId)
        XCTAssertEqual(decoded.encryption.algorithm, "AES-256-GCM")
        XCTAssertTrue(decoded.encryption.isEncrypted)
        XCTAssertEqual(decoded.metadata["width"], "1920")
    }

    func testStoredFileCategoryConstraints() {
        XCTAssertEqual(StoredFileCategory.userDocument.defaultFolderPrefix, "documents")
        XCTAssertEqual(StoredFileCategory.labPdf.defaultFolderPrefix, "lab-pdfs")
        XCTAssertEqual(StoredFileCategory.vialPhoto.defaultFolderPrefix, "vial-photos")
        XCTAssertEqual(StoredFileCategory.progressPhoto.defaultFolderPrefix, "progress-photos")
        XCTAssertEqual(StoredFileCategory.exportedReport.defaultFolderPrefix, "reports")

        XCTAssertTrue(StoredFileCategory.labPdf.allowedContentTypes.contains("application/pdf"))
        XCTAssertFalse(StoredFileCategory.labPdf.allowedContentTypes.contains("image/jpeg"))

        XCTAssertTrue(StoredFileCategory.vialPhoto.allowedContentTypes.contains("image/jpeg"))
        XCTAssertTrue(StoredFileCategory.progressPhoto.allowedContentTypes.contains("image/png"))

        XCTAssertGreaterThan(StoredFileCategory.labPdf.maxAllowedSizeBytes, 10 * 1024 * 1024)
        XCTAssertGreaterThan(StoredFileCategory.userDocument.maxAllowedSizeBytes, 10 * 1024 * 1024)
    }

    func testUserEncodingDecodingAndProperties() throws {
        let userId = UUID()
        let user = User(
            id: userId,
            accountInfo: AccountInfo(
                email: "alex@example.com",
                displayName: "Alex Mercer",
                avatarUrl: "https://vialr.internal/avatars/alex.png",
                phoneNumber: "+1 555-0199",
                tier: .pro,
                status: .active,
                isEmailVerified: true
            ),
            preferences: UserPreferences(
                appearanceMode: .dark,
                enableHapticFeedback: true,
                enableSoundEffects: true,
                weekStartsOn: .monday,
                defaultDoseTimeOfDay: .morning,
                autoRotateInjectionSites: true,
                syncWithAppleHealth: true,
                showSafetyWarnings: true
            ),
            timezone: "America/New_York",
            notificationPreferences: NotificationPreferences(
                enableDoseReminders: true,
                doseReminderLeadTimeMinutes: 30,
                enableRestockAlerts: true,
                enableStreakCelebrations: true,
                enableDailyMorningSummary: true,
                morningSummaryTime: "07:00",
                enableQuietHours: true,
                quietHoursStart: "22:00",
                quietHoursEnd: "06:00",
                criticalAlertsEnabled: true
            ),
            privacyPreferences: PrivacyPreferences(
                requireBiometricUnlock: true,
                biometricLockTimeoutSeconds: 120,
                maskSensitiveDosagesOnLockScreen: true,
                allowDiagnosticTelemetry: false,
                enableCloudBackupEncryption: true,
                allowClinicianDataSharing: true
            ),
            units: UnitPreferences(
                massUnit: .mg,
                weightUnit: .lbs,
                heightUnit: .inches,
                bloodGlucoseUnit: .mgDl,
                temperatureUnit: .fahrenheit,
                liquidVolumeUnit: .milliliters
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(user)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(User.self, from: data)

        XCTAssertEqual(decoded.id, userId)
        XCTAssertEqual(decoded.accountInfo.email, "alex@example.com")
        XCTAssertEqual(decoded.accountInfo.displayName, "Alex Mercer")
        XCTAssertEqual(decoded.accountInfo.tier, .pro)
        XCTAssertTrue(decoded.accountInfo.tier.isProOrHigher)
        XCTAssertEqual(decoded.preferences.appearanceMode, .dark)
        XCTAssertEqual(decoded.timezone, "America/New_York")
        XCTAssertEqual(decoded.timeZone.identifier, "America/New_York")
        XCTAssertEqual(decoded.notificationPreferences.doseReminderLeadTimeMinutes, 30)
        XCTAssertEqual(decoded.privacyPreferences.biometricLockTimeoutSeconds, 120)
        XCTAssertTrue(decoded.privacyPreferences.requireBiometricUnlock)
        XCTAssertEqual(decoded.units.massUnit, .mg)
        XCTAssertEqual(decoded.units.weightUnit.symbol, "lbs")
        XCTAssertEqual(decoded.units.heightUnit.symbol, "in")
        XCTAssertEqual(decoded.units.temperatureUnit.symbol, "°F")
        XCTAssertEqual(decoded.units.liquidVolumeUnit.symbol, "mL")
    }
}


