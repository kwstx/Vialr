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


