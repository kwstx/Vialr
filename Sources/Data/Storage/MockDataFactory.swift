import Foundation
import Domain

/// Provides realistic, pre-populated seed data for Vialr demonstrations, tests, and preview canvases.
public struct MockDataFactory: Sendable {
    public init() {}

    // MARK: - User
    public var defaultUser: User {
        User(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            accountInfo: AccountInfo(
                email: "alex.mercer@vialr.internal",
                displayName: "Alex Mercer",
                avatarUrl: nil,
                phoneNumber: "+1 (555) 349-2018",
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
                doseReminderLeadTimeMinutes: 15,
                enableRestockAlerts: true,
                enableStreakCelebrations: true,
                enableDailyMorningSummary: true,
                morningSummaryTime: "07:30",
                enableQuietHours: false,
                quietHoursStart: "22:00",
                quietHoursEnd: "07:00",
                criticalAlertsEnabled: false
            ),
            privacyPreferences: PrivacyPreferences(
                requireBiometricUnlock: true,
                biometricLockTimeoutSeconds: 60,
                maskSensitiveDosagesOnLockScreen: true,
                allowDiagnosticTelemetry: false,
                enableCloudBackupEncryption: true,
                allowClinicianDataSharing: true
            ),
            units: UnitPreferences(
                massUnit: .mcg,
                weightUnit: .lbs,
                heightUnit: .inches,
                bloodGlucoseUnit: .mgDl,
                temperatureUnit: .fahrenheit,
                liquidVolumeUnit: .milliliters
            ),
            createdAt: Date(timeIntervalSince1970: 1704067200), // Jan 1, 2024
            updatedAt: Date()
        )
    }

    // MARK: - Compounds
    public var defaultCompounds: [Compound] {
        [
            Compound(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "BPC-157",
                shortCode: "BPC",
                category: .recovery,
                defaultUnit: .mcg,
                typicalDose: 250,
                halfLifeHours: 4.0,
                description: "Body Protection Compound-157. Known for tendon, ligament, and gut mucosal tissue healing.",
                administrationRoute: .subcutaneous,
                storageCondition: .refrigerated,
                tags: ["Healing", "Tendons", "Gut Health"]
            ),
            Compound(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "TB-500 (Thymosin Beta-4)",
                shortCode: "TB4",
                category: .recovery,
                defaultUnit: .mg,
                typicalDose: 2.5,
                halfLifeHours: 24.0,
                description: "Promotes cellular migration, angiogenesis, and deep muscular repair.",
                administrationRoute: .subcutaneous,
                storageCondition: .refrigerated,
                tags: ["Systemic Repair", "Muscle", "Wound Healing"]
            ),
            Compound(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                name: "Tirzepatide",
                shortCode: "TRZ",
                category: .glp1Metabolic,
                defaultUnit: .mg,
                typicalDose: 5.0,
                halfLifeHours: 120.0, // 5 days
                description: "Dual GLP-1 and GIP receptor agonist for glycemic control and metabolic optimization.",
                administrationRoute: .subcutaneous,
                storageCondition: .refrigerated,
                tags: ["GLP-1", "GIP", "Metabolic", "Insulin Sensitivity"]
            ),
            Compound(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                name: "CJC-1295 / Ipamorelin",
                shortCode: "CJC/IPA",
                category: .growthHormoneSecretagogue,
                defaultUnit: .mcg,
                typicalDose: 300,
                halfLifeHours: 2.0,
                description: "Synergistic GHRH + Ghrelin mimetic blend for natural nocturnal growth hormone release.",
                administrationRoute: .subcutaneous,
                storageCondition: .refrigerated,
                tags: ["GH Pulse", "Deep Sleep", "Collagen"]
            ),
            Compound(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                name: "GHK-Cu",
                shortCode: "GHK",
                category: .cosmeticSkin,
                defaultUnit: .mg,
                typicalDose: 2.0,
                halfLifeHours: 1.0,
                description: "Copper tripeptide involved in skin remodeling, collagen synthesis, and anti-fibrotic action.",
                administrationRoute: .subcutaneous,
                storageCondition: .refrigerated,
                tags: ["Skin", "Collagen", "Anti-Aging"]
            ),
            Compound(
                id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
                name: "NAD+",
                shortCode: "NAD",
                category: .longevityNootropic,
                defaultUnit: .mg,
                typicalDose: 50.0,
                halfLifeHours: 4.0,
                description: "Nicotinamide adenine dinucleotide for cellular energy and mitochondrial biogenesis.",
                administrationRoute: .subcutaneous,
                storageCondition: .refrigerated,
                tags: ["Cellular Energy", "Mitochondria", "Longevity"]
            )
        ]
    }

    // MARK: - Protocols
    public var defaultProtocols: [ProtocolModel] {
        let bpcId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let tbId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let cjcId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let trzId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

        let cal = Calendar.current
        let now = Date()
        let startDate = cal.date(byAdding: .day, value: -21, to: now) ?? now

        return [
            ProtocolModel(
                id: UUID(uuidString: "aaaa1111-aaaa-1111-aaaa-111111111111")!,
                name: "Wolverine Tissue Healing Stack",
                goalSummary: "Targeted shoulder rotator cuff tendon and labrum recovery.",
                status: .active,
                items: [
                    ProtocolItem(
                        id: UUID(uuidString: "item-bpc-1")!,
                        compoundId: bpcId,
                        compoundName: "BPC-157",
                        doseAmount: 250,
                        doseUnit: .mcg,
                        scheduleRule: .everyDay,
                        preferredTimeOfDay: .morning,
                        preferredRoute: .subcutaneous,
                        notes: "Administer near shoulder or abdomen SubQ"
                    ),
                    ProtocolItem(
                        id: UUID(uuidString: "item-tb-1")!,
                        compoundId: tbId,
                        compoundName: "TB-500",
                        doseAmount: 2.5,
                        doseUnit: .mg,
                        scheduleRule: .daysOfWeek([2, 5]), // Mon, Thu
                        preferredTimeOfDay: .evening,
                        preferredRoute: .subcutaneous,
                        notes: "Twice weekly loading phase"
                    )
                ],
                startDate: startDate,
                endDate: cal.date(byAdding: .day, value: 42, to: startDate),
                notes: "Review with orthopedic physical therapist at week 6.",
                colorHex: "#10B981"
            ),
            ProtocolModel(
                id: UUID(uuidString: "bbbb2222-bbbb-2222-bbbb-222222222222")!,
                name: "Nocturnal GH Optimization",
                goalSummary: "Enhance Stage 3/4 slow-wave sleep and recovery.",
                status: .active,
                items: [
                    ProtocolItem(
                        id: UUID(uuidString: "item-cjc-1")!,
                        compoundId: cjcId,
                        compoundName: "CJC-1295 / Ipamorelin",
                        doseAmount: 300,
                        doseUnit: .mcg,
                        scheduleRule: .cycle(daysOn: 5, daysOff: 2),
                        preferredTimeOfDay: .evening,
                        preferredRoute: .subcutaneous,
                        notes: "Take 90 minutes after last food intake before sleep"
                    )
                ],
                startDate: startDate,
                colorHex: "#8B5CF6"
            ),
            ProtocolModel(
                id: UUID(uuidString: "cccc3333-cccc-3333-cccc-333333333333")!,
                name: "Metabolic & Insulin Modulation",
                goalSummary: "Maintain glucose stability and lean body composition.",
                status: .paused,
                items: [
                    ProtocolItem(
                        id: UUID(uuidString: "item-trz-1")!,
                        compoundId: trzId,
                        compoundName: "Tirzepatide",
                        doseAmount: 5.0,
                        doseUnit: .mg,
                        scheduleRule: .everyNDays(7),
                        preferredTimeOfDay: .morning,
                        preferredRoute: .subcutaneous,
                        notes: "Sunday morning dose"
                    )
                ],
                startDate: cal.date(byAdding: .day, value: -60, to: now) ?? now,
                endDate: cal.date(byAdding: .day, value: -10, to: now),
                colorHex: "#06B6D4"
            )
        ]
    }

    // MARK: - Vials
    public var defaultVials: [Vial] {
        let bpcId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let tbId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let cjcId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let trzId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

        let cal = Calendar.current
        let now = Date()

        return [
            Vial(
                id: UUID(uuidString: "vial-bpc-1")!,
                compoundId: bpcId,
                compoundName: "BPC-157",
                lotNumber: "LOT-9821A",
                vendor: "Precision Peptides",
                totalDryMassMg: 5.0,
                bacWaterAddedMl: 2.0,
                currentVolumeRemainingMl: 1.2,
                isReconstituted: true,
                reconstitutedDate: cal.date(byAdding: .day, value: -12, to: now),
                expirationDate: cal.date(byAdding: .day, value: 16, to: now),
                costUsd: 48.0,
                status: .reconstituted
            ),
            Vial(
                id: UUID(uuidString: "vial-tb-1")!,
                compoundId: tbId,
                compoundName: "TB-500",
                lotNumber: "LOT-4412B",
                vendor: "Precision Peptides",
                totalDryMassMg: 10.0,
                bacWaterAddedMl: 2.0,
                currentVolumeRemainingMl: 1.5,
                isReconstituted: true,
                reconstitutedDate: cal.date(byAdding: .day, value: -10, to: now),
                expirationDate: cal.date(byAdding: .day, value: 18, to: now),
                costUsd: 75.0,
                status: .reconstituted
            ),
            Vial(
                id: UUID(uuidString: "vial-cjc-1")!,
                compoundId: cjcId,
                compoundName: "CJC-1295 / Ipamorelin (5mg/5mg)",
                lotNumber: "LOT-7731C",
                vendor: "BioTech Research",
                totalDryMassMg: 10.0,
                bacWaterAddedMl: 3.0,
                currentVolumeRemainingMl: 2.1,
                isReconstituted: true,
                reconstitutedDate: cal.date(byAdding: .day, value: -8, to: now),
                expirationDate: cal.date(byAdding: .day, value: 20, to: now),
                costUsd: 85.0,
                status: .reconstituted
            ),
            Vial(
                id: UUID(uuidString: "vial-trz-dry")!,
                compoundId: trzId,
                compoundName: "Tirzepatide (Dry Reserve)",
                lotNumber: "LOT-1092D",
                vendor: "Apex Lab",
                totalDryMassMg: 15.0,
                bacWaterAddedMl: nil,
                currentVolumeRemainingMl: nil,
                isReconstituted: false,
                costUsd: 110.0,
                status: .unopened
            )
        ]
    }

    // MARK: - Supplies
    public var defaultSupplies: [SupplyItem] {
        [
            SupplyItem(
                name: "EasyTouch U-100 31G 5/16\" 0.5mL",
                category: .syringes,
                quantityRemaining: 68,
                packageUnit: "100-pack",
                reorderThreshold: 20,
                costUsd: 22.0
            ),
            SupplyItem(
                name: "Hospira Bacteriostatic Water 30mL",
                category: .bacWater,
                quantityRemaining: 2,
                packageUnit: "30mL Vials",
                reorderThreshold: 1,
                costUsd: 18.0
            ),
            SupplyItem(
                name: "BD 21G 1.5\" Mixing Needles",
                category: .needles,
                quantityRemaining: 14,
                packageUnit: "50-pack",
                reorderThreshold: 10,
                costUsd: 12.0
            ),
            SupplyItem(
                name: "Alcohol Prep Pads (70% IPA)",
                category: .prepPads,
                quantityRemaining: 180,
                packageUnit: "200-box",
                reorderThreshold: 30,
                costUsd: 8.50
            )
        ]
    }

    // MARK: - Dose Logs (Past 14 days + Today's Scheduled)
    public var defaultDoseLogs: [DoseLog] {
        let cal = Calendar.current
        let now = Date()
        let bpcId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let cjcId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let protoId = UUID(uuidString: "aaaa1111-aaaa-1111-aaaa-111111111111")!
        let vialBpcId = UUID(uuidString: "vial-bpc-1")!
        let vialCjcId = UUID(uuidString: "vial-cjc-1")!

        var logs: [DoseLog] = []

        let sites = [
            ("ab_l_uo", "Abdomen - Left Upper Outer"),
            ("ab_r_uo", "Abdomen - Right Upper Outer"),
            ("ab_l_lo", "Abdomen - Left Lower Outer"),
            ("ab_r_lo", "Abdomen - Right Lower Outer"),
            ("thigh_l_outer", "Left Thigh - Outer Mid"),
            ("delt_l", "Left Deltoid")
        ]

        // Past 10 days of BPC-157 taken doses
        for dayOffset in (1...10).reversed() {
            let logDate = cal.date(byAdding: .day, value: -dayOffset, to: now)!
            let site = sites[dayOffset % sites.count]
            logs.append(
                DoseLog(
                    protocolId: protoId,
                    compoundId: bpcId,
                    compoundName: "BPC-157",
                    scheduledDate: logDate,
                    loggedDate: logDate,
                    doseAmount: 250,
                    doseUnit: .mcg,
                    status: .taken,
                    injectionSiteId: site.0,
                    injectionSiteName: site.1,
                    vialId: vialBpcId,
                    notes: "Morning routine, zero irritation."
                )
            )
        }

        // Today's Scheduled doses
        logs.append(
            DoseLog(
                protocolId: protoId,
                compoundId: bpcId,
                compoundName: "BPC-157",
                scheduledDate: now,
                doseAmount: 250,
                doseUnit: .mcg,
                status: .scheduled,
                vialId: vialBpcId
            )
        )
        logs.append(
            DoseLog(
                protocolId: UUID(uuidString: "bbbb2222-bbbb-2222-bbbb-222222222222")!,
                compoundId: cjcId,
                compoundName: "CJC-1295 / Ipamorelin",
                scheduledDate: cal.date(bySettingHour: 22, minute: 30, second: 0, of: now) ?? now,
                doseAmount: 300,
                doseUnit: .mcg,
                status: .scheduled,
                vialId: vialCjcId
            )
        )

        return logs
    }

    // MARK: - Biomarkers
    public var defaultBiomarkers: [Biomarker] {
        let cal = Calendar.current
        let now = Date()

        return [
            Biomarker(
                name: "IGF-1 (Somatomedin-C)",
                category: .bloodwork,
                value: 245.0,
                unit: "ng/mL",
                referenceRangeMin: 115.0,
                referenceRangeMax: 307.0,
                dateRecorded: cal.date(byAdding: .day, value: -14, to: now)!,
                source: .labImport,
                notes: "Healthy upper quartile response on secretagogues."
            ),
            Biomarker(
                name: "Fasting Blood Glucose",
                category: .metabolic,
                value: 86.0,
                unit: "mg/dL",
                referenceRangeMin: 70.0,
                referenceRangeMax: 99.0,
                dateRecorded: cal.date(byAdding: .day, value: -1, to: now)!,
                source: .appleHealth
            ),
            Biomarker(
                name: "HbA1c",
                category: .metabolic,
                value: 5.1,
                unit: "%",
                referenceRangeMin: 4.0,
                referenceRangeMax: 5.6,
                dateRecorded: cal.date(byAdding: .day, value: -30, to: now)!,
                source: .labImport
            ),
            Biomarker(
                name: "Body Weight",
                category: .bodyComposition,
                value: 182.4,
                unit: "lbs",
                referenceRangeMin: 165.0,
                referenceRangeMax: 195.0,
                dateRecorded: now,
                source: .appleHealth
            ),
            Biomarker(
                name: "Resting Heart Rate",
                category: .cardiovascular,
                value: 54.0,
                unit: "bpm",
                referenceRangeMin: 50.0,
                referenceRangeMax: 75.0,
                dateRecorded: now,
                source: .appleHealth
            ),
            Biomarker(
                name: "Heart Rate Variability (HRV)",
                category: .sleepRecovery,
                value: 78.0,
                unit: "ms",
                referenceRangeMin: 45.0,
                referenceRangeMax: 110.0,
                dateRecorded: now,
                source: .appleHealth
            )
        ]
    }

    // MARK: - Laboratory Panels & Results
    public var defaultLabPanels: [LabPanel] {
        let cal = Calendar.current
        let now = Date()

        let panel1Id = UUID(uuidString: "77777777-7777-7777-7777-777777777771")!
        let panel2Id = UUID(uuidString: "77777777-7777-7777-7777-777777777772")!

        let panel1Results = [
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "Total Testosterone", category: .hormones, value: 845, unit: "ng/dL", referenceRangeMin: 300, referenceRangeMax: 1000, referenceRangeText: "300 – 1000 ng/dL", flag: .inRange, notes: "Optimal mid-high physiological range."),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "Free Testosterone", category: .hormones, value: 24.2, unit: "pg/mL", referenceRangeMin: 9.0, referenceRangeMax: 30.0, referenceRangeText: "9.0 – 30.0 pg/mL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "Estradiol (Sensitive / LC-MS)", category: .hormones, value: 28.5, unit: "pg/mL", referenceRangeMin: 15.0, referenceRangeMax: 40.0, referenceRangeText: "15.0 – 40.0 pg/mL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "Sex Hormone Binding Globulin (SHBG)", category: .hormones, value: 34.0, unit: "nmol/L", referenceRangeMin: 16.5, referenceRangeMax: 55.9, referenceRangeText: "16.5 – 55.9 nmol/L", flag: .inRange),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "DHEA-Sulfate", category: .hormones, value: 385, unit: "ug/dL", referenceRangeMin: 160, referenceRangeMax: 450, referenceRangeText: "160 – 450 ug/dL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "IGF-1 (Somatomedin C)", category: .hormones, value: 268, unit: "ng/mL", referenceRangeMin: 115, referenceRangeMax: 307, referenceRangeText: "115 – 307 ng/mL", flag: .inRange, notes: "Robust GH response on CJC/Ipamorelin."),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "Fasting Blood Glucose", category: .metabolic, value: 88, unit: "mg/dL", referenceRangeMin: 70, referenceRangeMax: 99, referenceRangeText: "70 – 99 mg/dL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "Fasting Insulin", category: .metabolic, value: 3.8, unit: "uIU/mL", referenceRangeMin: 2.0, referenceRangeMax: 6.0, referenceRangeText: "2.0 – 6.0 uIU/mL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "Hemoglobin A1c (HbA1c)", category: .metabolic, value: 5.1, unit: "%", referenceRangeMin: 4.5, referenceRangeMax: 5.6, referenceRangeText: "< 5.7 %", flag: .inRange),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "Apolipoprotein B (ApoB)", category: .lipids, value: 68, unit: "mg/dL", referenceRangeMin: 50, referenceRangeMax: 90, referenceRangeText: "< 90 mg/dL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "Hematocrit", category: .cbcHematology, value: 47.2, unit: "%", referenceRangeMin: 38.5, referenceRangeMax: 50.0, referenceRangeText: "38.5 – 50.0 %", flag: .inRange),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "ALT (Alanine Aminotransferase)", category: .liverHepatic, value: 22, unit: "IU/L", referenceRangeMin: 9, referenceRangeMax: 44, referenceRangeText: "9 – 44 IU/L", flag: .inRange),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "AST (Aspartate Aminotransferase)", category: .liverHepatic, value: 26, unit: "IU/L", referenceRangeMin: 10, referenceRangeMax: 40, referenceRangeText: "10 – 40 IU/L", flag: .inRange),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "High-Sensitivity CRP (hs-CRP)", category: .inflammatory, value: 0.35, unit: "mg/L", referenceRangeMin: 0.1, referenceRangeMax: 1.0, referenceRangeText: "< 1.0 mg/L", flag: .inRange),
            LabResult(id: UUID(), panelId: panel1Id, biomarkerName: "TSH (Thyroid Stimulating Hormone)", category: .thyroid, value: 1.65, unit: "uIU/mL", referenceRangeMin: 0.45, referenceRangeMax: 4.50, referenceRangeText: "0.45 – 4.50 uIU/mL", flag: .inRange)
        ]

        let panel2Results = [
            LabResult(id: UUID(), panelId: panel2Id, biomarkerName: "Total Testosterone", category: .hormones, value: 620, unit: "ng/dL", referenceRangeMin: 300, referenceRangeMax: 1000, referenceRangeText: "300 – 1000 ng/dL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel2Id, biomarkerName: "Free Testosterone", category: .hormones, value: 16.8, unit: "pg/mL", referenceRangeMin: 9.0, referenceRangeMax: 30.0, referenceRangeText: "9.0 – 30.0 pg/mL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel2Id, biomarkerName: "Estradiol (Sensitive / LC-MS)", category: .hormones, value: 22.0, unit: "pg/mL", referenceRangeMin: 15.0, referenceRangeMax: 40.0, referenceRangeText: "15.0 – 40.0 pg/mL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel2Id, biomarkerName: "IGF-1 (Somatomedin C)", category: .hormones, value: 185, unit: "ng/mL", referenceRangeMin: 115, referenceRangeMax: 307, referenceRangeText: "115 – 307 ng/mL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel2Id, biomarkerName: "Fasting Blood Glucose", category: .metabolic, value: 94, unit: "mg/dL", referenceRangeMin: 70, referenceRangeMax: 99, referenceRangeText: "70 – 99 mg/dL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel2Id, biomarkerName: "Total Cholesterol", category: .lipids, value: 192, unit: "mg/dL", referenceRangeMin: 125, referenceRangeMax: 200, referenceRangeText: "< 200 mg/dL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel2Id, biomarkerName: "LDL-C (Calculated / Direct)", category: .lipids, value: 112, unit: "mg/dL", referenceRangeMin: 50, referenceRangeMax: 100, referenceRangeText: "< 100 mg/dL", flag: .high),
            LabResult(id: UUID(), panelId: panel2Id, biomarkerName: "HDL-C (High-Density Lipoprotein)", category: .lipids, value: 58, unit: "mg/dL", referenceRangeMin: 40, referenceRangeMax: 80, referenceRangeText: "> 40 mg/dL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel2Id, biomarkerName: "Triglycerides", category: .lipids, value: 110, unit: "mg/dL", referenceRangeMin: 40, referenceRangeMax: 150, referenceRangeText: "< 150 mg/dL", flag: .inRange),
            LabResult(id: UUID(), panelId: panel2Id, biomarkerName: "Hematocrit", category: .cbcHematology, value: 45.0, unit: "%", referenceRangeMin: 38.5, referenceRangeMax: 50.0, referenceRangeText: "38.5 – 50.0 %", flag: .inRange),
            LabResult(id: UUID(), panelId: panel2Id, biomarkerName: "ALT (Alanine Aminotransferase)", category: .liverHepatic, value: 28, unit: "IU/L", referenceRangeMin: 9, referenceRangeMax: 44, referenceRangeText: "9 – 44 IU/L", flag: .inRange)
        ]

        let p1 = LabPanel(
            id: panel1Id,
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
            panelName: "Comprehensive Male Hormone & Longevity Panel",
            labName: "Quest Diagnostics",
            collectionDate: cal.date(byAdding: .day, value: -14, to: now)!,
            resultDate: cal.date(byAdding: .day, value: -12, to: now)!,
            status: .completed,
            results: panel1Results,
            orderingPhysician: "Dr. William Sterling, MD",
            fastingStatus: .fasted,
            notes: "Routine 12-week protocol monitoring blood draw. All markers within optimal parameters."
        )

        let p2 = LabPanel(
            id: panel2Id,
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
            panelName: "Baseline Diagnostic Lab Panel",
            labName: "Labcorp",
            collectionDate: cal.date(byAdding: .day, value: -90, to: now)!,
            resultDate: cal.date(byAdding: .day, value: -88, to: now)!,
            status: .completed,
            results: panel2Results,
            orderingPhysician: "Dr. Sarah Jenkins, MD",
            fastingStatus: .fasted,
            notes: "Baseline pre-protocol evaluation."
        )

        return [p1, p2]
    }

    // MARK: - Subjective Symptoms
    public var defaultSymptomLogs: [SymptomLog] {
        let cal = Calendar.current
        let now = Date()

        return [
            SymptomLog(
                timestamp: cal.date(byAdding: .day, value: -3, to: now)!,
                energyLevel: 9,
                sleepQuality: 9,
                recoveryScore: 8,
                moodScore: 9,
                painScore: 2,
                notes: "Right shoulder tendon pain significantly diminished during bench press."
            ),
            SymptomLog(
                timestamp: cal.date(byAdding: .day, value: -1, to: now)!,
                energyLevel: 8,
                sleepQuality: 9,
                recoveryScore: 9,
                moodScore: 9,
                painScore: 1,
                notes: "Excellent deep sleep tracking on Apple Watch."
            )
        ]
    }

    // MARK: - Costs
    public var defaultCosts: [CostRecord] {
        let cal = Calendar.current
        let now = Date()

        return [
            CostRecord(
                title: "BPC-157 (5mg) + TB-500 (10mg)",
                category: .peptideVial,
                amountUsd: 123.0,
                dateIncurred: cal.date(byAdding: .day, value: -14, to: now)!,
                vendor: "Precision Peptides"
            ),
            CostRecord(
                title: "Insulin Syringes + BAC Water",
                category: .medicalSupplies,
                amountUsd: 40.50,
                dateIncurred: cal.date(byAdding: .day, value: -20, to: now)!,
                vendor: "Medical Supply Co"
            ),
            CostRecord(
                title: "Comprehensive Metabolic & Hormone Panel",
                category: .bloodwork,
                amountUsd: 189.0,
                dateIncurred: cal.date(byAdding: .day, value: -30, to: now)!,
                vendor: "Quest Diagnostics"
            )
        ]
    }

    // MARK: - Injection Site Events (Longitudinal Protocol-Independent Site History)
    public var defaultInjectionSiteEvents: [InjectionSiteEvent] {
        let cal = Calendar.current
        let now = Date()
        let bpcId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let tbId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let sites = [
            ("ab_l_uo", "Abdomen - Left Upper Outer", BodyRegion.abdomen, BodySide.left, Quadrant.upperOuter),
            ("ab_r_uo", "Abdomen - Right Upper Outer", BodyRegion.abdomen, BodySide.right, Quadrant.upperOuter),
            ("ab_r_lo", "Abdomen - Right Lower Outer", BodyRegion.abdomen, BodySide.right, Quadrant.lowerOuter),
            ("ab_l_lo", "Abdomen - Left Lower Outer", BodyRegion.abdomen, BodySide.left, Quadrant.lowerOuter),
            ("thigh_l_outer", "Left Thigh - Outer Mid", BodyRegion.thigh, BodySide.left, Quadrant.upperOuter),
            ("delt_l", "Left Deltoid", BodyRegion.deltoid, BodySide.left, nil)
        ]

        var events: [InjectionSiteEvent] = []

        // Past 10 administrations across multiple protocols and compounds
        for dayOffset in (1...10).reversed() {
            let logDate = cal.date(byAdding: .day, value: -dayOffset, to: now)!
            let site = sites[dayOffset % sites.count]
            let isTb = dayOffset % 4 == 0

            events.append(
                InjectionSiteEvent(
                    id: UUID(),
                    doseEventId: UUID(),
                    siteId: site.0,
                    siteName: site.1,
                    region: site.2,
                    side: site.3,
                    quadrant: site.4,
                    route: .subcutaneous,
                    timestamp: logDate,
                    compoundId: isTb ? tbId : bpcId,
                    compoundName: isTb ? "TB-500" : "BPC-157",
                    doseAmount: isTb ? 2.5 : 250,
                    doseUnit: isTb ? .mg : .mcg,
                    needleGauge: "31G",
                    needleLength: "5/16\"",
                    reaction: dayOffset == 3 ? .mildRedness : .none,
                    painScore: dayOffset == 3 ? 1 : 0,
                    notes: dayOffset == 3 ? "Slight post-injection redness, cleared within 30 min." : "SubQ administration, smooth draw."
                )
            )
        }

        return events
    }

    // MARK: - Inventory Events (Event-Sourced Accounting Ledger Seed)
    public var defaultInventoryEvents: [InventoryEvent] {
        let cal = Calendar.current
        let now = Date()
        let bpcId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let tbId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let cjcId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let trzId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let vialBpcId = UUID(uuidString: "vial-bpc-1")!
        let vialTbId = UUID(uuidString: "vial-tb-1")!
        let vialCjcId = UUID(uuidString: "vial-cjc-1")!
        let vialTrzId = UUID(uuidString: "vial-trz-dry")!

        var events: [InventoryEvent] = []

        // 1. BPC-157 Vial Ledger
        let bpcReceived = cal.date(byAdding: .day, value: -14, to: now)!
        events.append(InventoryEvent.initialStock(
            vialId: vialBpcId,
            compoundId: bpcId,
            compoundName: "BPC-157",
            initialDryMassMg: 5.0,
            lotNumber: "LOT-9821A",
            timestamp: bpcReceived,
            notes: "Received intact from Precision Peptides"
        ))

        let bpcRecon = cal.date(byAdding: .day, value: -12, to: now)!
        events.append(InventoryEvent.reconstitution(
            vialId: vialBpcId,
            compoundId: bpcId,
            compoundName: "BPC-157",
            diluentVolumeMl: 2.0,
            dryMassMg: 5.0,
            lotNumber: "LOT-9821A",
            timestamp: bpcRecon,
            notes: "Reconstituted with 2.0 mL Hospira Bacteriostatic Water"
        ))

        // Daily doses: 0.1 mL (250 mcg)
        var bpcVol = 2.0
        var bpcMass = 5.0
        for dayOffset in (3...10).reversed() {
            let dTime = cal.date(byAdding: .day, value: -dayOffset, to: now)!
            bpcVol -= 0.1
            bpcMass -= 0.25
            events.append(InventoryEvent.doseConsumption(
                vialId: vialBpcId,
                compoundId: bpcId,
                compoundName: "BPC-157",
                doseEventId: UUID(),
                consumedVolumeMl: 0.1,
                consumedMassMg: 0.25,
                newVolumeRemainingMl: bpcVol,
                newMassRemainingMg: bpcMass,
                concentrationMgMl: 2.5,
                timestamp: dTime,
                notes: "Morning subcutaneous injection"
            ))
        }

        // Audited Reconciliation Event on Day -2: Adjusted for visual level check & dead space
        let bpcReconcileDate = cal.date(byAdding: .day, value: -2, to: now)!
        events.append(InventoryEvent.reconciliation(
            vialId: vialBpcId,
            compoundId: bpcId,
            compoundName: "BPC-157",
            volumeVarianceMl: 0.20,
            massVarianceMg: 0.50,
            newVolumeRemainingMl: 1.20,
            newMassRemainingMg: 3.0,
            concentrationMgMl: 2.5,
            reason: .measurementVariance,
            userNotes: "Meniscus level check indicates 1.20 mL remaining in vial.",
            timestamp: bpcReconcileDate
        ))

        // 2. TB-500 Vial Ledger
        let tbReceived = cal.date(byAdding: .day, value: -14, to: now)!
        events.append(InventoryEvent.initialStock(
            vialId: vialTbId,
            compoundId: tbId,
            compoundName: "TB-500",
            initialDryMassMg: 10.0,
            lotNumber: "LOT-4412B",
            timestamp: tbReceived
        ))

        let tbRecon = cal.date(byAdding: .day, value: -10, to: now)!
        events.append(InventoryEvent.reconstitution(
            vialId: vialTbId,
            compoundId: tbId,
            compoundName: "TB-500",
            diluentVolumeMl: 2.0,
            dryMassMg: 10.0,
            lotNumber: "LOT-4412B",
            timestamp: tbRecon,
            notes: "2.0 mL BAC water added (5.0 mg/mL solution)"
        ))

        let tbDose1 = cal.date(byAdding: .day, value: -6, to: now)!
        events.append(InventoryEvent.doseConsumption(
            vialId: vialTbId,
            compoundId: tbId,
            compoundName: "TB-500",
            doseEventId: UUID(),
            consumedVolumeMl: 0.5,
            consumedMassMg: 2.5,
            newVolumeRemainingMl: 1.5,
            newMassRemainingMg: 7.5,
            concentrationMgMl: 5.0,
            timestamp: tbDose1,
            notes: "2.5 mg SubQ dose"
        ))

        // 3. CJC-1295 / Ipamorelin Vial Ledger
        let cjcReceived = cal.date(byAdding: .day, value: -10, to: now)!
        events.append(InventoryEvent.initialStock(
            vialId: vialCjcId,
            compoundId: cjcId,
            compoundName: "CJC-1295 / Ipamorelin (5mg/5mg)",
            initialDryMassMg: 10.0,
            lotNumber: "LOT-7731C",
            timestamp: cjcReceived
        ))

        let cjcRecon = cal.date(byAdding: .day, value: -8, to: now)!
        events.append(InventoryEvent.reconstitution(
            vialId: vialCjcId,
            compoundId: cjcId,
            compoundName: "CJC-1295 / Ipamorelin (5mg/5mg)",
            diluentVolumeMl: 3.0,
            dryMassMg: 10.0,
            lotNumber: "LOT-7731C",
            timestamp: cjcRecon,
            notes: "3.0 mL BAC water (3.33 mg/mL total peptide)"
        ))

        // 4. Tirzepatide Unopened Dry Powder Reserve
        let trzReceived = cal.date(byAdding: .day, value: -20, to: now)!
        events.append(InventoryEvent.initialStock(
            vialId: vialTrzId,
            compoundId: trzId,
            compoundName: "Tirzepatide (Dry Reserve)",
            initialDryMassMg: 15.0,
            lotNumber: "LOT-1092D",
            timestamp: trzReceived,
            notes: "Stored in freezer at -20°C"
        ))

        return events
    }

    // MARK: - Metric Definitions
    public var defaultMetricDefinitions: [MetricDefinition] {
        var defs = MetricDefinition.allBuiltIns

        // Add user-defined custom metrics
        defs.append(
            MetricDefinition.custom(
                name: "Grip Strength (Dominant)",
                category: .athletic,
                defaultUnit: "lbs",
                supportedUnits: ["lbs", "kg"],
                referenceRangeMin: 100.0,
                referenceRangeMax: 150.0,
                targetDirection: .increase,
                iconName: "hand.raised.fill",
                colorHex: "#10B981",
                metricDescription: "Isometric dominant hand dynamometer grip strength.",
                preferredAggregation: .maximum,
                decimalPlaces: 1
            )
        )

        defs.append(
            MetricDefinition.custom(
                name: "Morning Fasting Ketones",
                category: .metabolic,
                defaultUnit: "mmol/L",
                supportedUnits: ["mmol/L"],
                referenceRangeMin: 0.5,
                referenceRangeMax: 3.0,
                targetDirection: .increase,
                iconName: "flame.fill",
                colorHex: "#F59E0B",
                metricDescription: "Capillary blood beta-hydroxybutyrate level.",
                preferredAggregation: .average,
                decimalPlaces: 2
            )
        )

        return defs
    }

    // MARK: - Generic Time-Series Measurements (30-Day Longitudinal Tracking)
    public var defaultMeasurements: [Measurement] {
        let cal = Calendar.current
        let now = Date()
        var items: [Measurement] = []

        // Tirzepatide & CJC Protocol ID reference
        let protocolId = UUID(uuidString: "77777777-7777-7777-7777-777777777771")

        // 30 days of daily metrics
        for dayOffset in (0...30).reversed() {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let t = Double(30 - dayOffset) / 30.0 // 0.0 at start, 1.0 today

            // 1. Body Weight (Declining from 196.4 lbs to 184.2 lbs with minor natural noise)
            let noiseW = sin(Double(dayOffset) * 1.5) * 0.4
            let weightVal = 196.4 - (12.2 * t) + noiseW
            items.append(
                Measurement(
                    name: "Body Weight",
                    type: .weight,
                    category: .bodyComposition,
                    value: (weightVal * 10).rounded() / 10,
                    unit: "lbs",
                    dateRecorded: date,
                    source: dayOffset % 4 == 0 ? .appleHealth : .manualEntry,
                    associatedProtocolId: protocolId,
                    customMetricCode: "body_weight",
                    notes: dayOffset == 30 ? "Baseline weigh-in before Protocol Cycle 1" : ""
                )
            )

            // 2. Fasting Blood Glucose (Declining from 102 mg/dL to 84 mg/dL)
            let noiseG = cos(Double(dayOffset) * 2.1) * 2.0
            let glucoseVal = 102.0 - (18.0 * t) + noiseG
            items.append(
                Measurement(
                    name: "Fasting Blood Glucose",
                    type: .bloodGlucose,
                    category: .metabolic,
                    value: glucoseVal.rounded(),
                    unit: "mg/dL",
                    dateRecorded: date,
                    source: .deviceSync,
                    referenceRangeMin: 70.0,
                    referenceRangeMax: 99.0,
                    associatedProtocolId: protocolId,
                    customMetricCode: "fasting_glucose"
                )
            )

            // 3. Resting Heart Rate (Settling from 68 bpm to 61 bpm)
            let rhrVal = 68.0 - (7.0 * t) + (Double(dayOffset % 3) - 1.0)
            items.append(
                Measurement(
                    name: "Resting Heart Rate",
                    type: .restingHeartRate,
                    category: .cardiovascular,
                    value: rhrVal.rounded(),
                    unit: "bpm",
                    dateRecorded: date,
                    source: .appleHealth,
                    referenceRangeMin: 50.0,
                    referenceRangeMax: 75.0,
                    associatedProtocolId: protocolId,
                    customMetricCode: "resting_heart_rate"
                )
            )

            // 4. Sleep Duration (Rising from 6.4 hrs to 7.9 hrs)
            let sleepVal = 6.4 + (1.5 * t) + (sin(Double(dayOffset)) * 0.3)
            items.append(
                Measurement(
                    name: "Sleep Duration",
                    type: .sleep,
                    category: .sleepRecovery,
                    value: (sleepVal * 10).rounded() / 10,
                    secondaryValue: min(10.0, max(5.0, 6.0 + (3.0 * t))),
                    unit: "hrs",
                    dateRecorded: date,
                    source: .appleHealth,
                    referenceRangeMin: 7.0,
                    referenceRangeMax: 9.0,
                    associatedProtocolId: protocolId,
                    customMetricCode: "sleep_duration"
                )
            )

            // 5. Subjective Energy Level (Rising from 5.0 to 8.5 / 10)
            if dayOffset % 2 == 0 {
                let energyVal = min(10.0, max(1.0, 5.0 + (3.5 * t) + (cos(Double(dayOffset)) * 0.5)))
                items.append(
                    Measurement(
                        name: "Energy Level",
                        type: .energy,
                        category: .subjectiveWellbeing,
                        value: (energyVal * 10).rounded() / 10,
                        unit: "/10",
                        dateRecorded: date,
                        source: .manualEntry,
                        referenceRangeMin: 7.0,
                        referenceRangeMax: 10.0,
                        associatedProtocolId: protocolId,
                        customMetricCode: "energy_level"
                    )
                )
            }

            // 6. Local Knee Pain Index on BPC-157 (Decreasing from 7.0 to 1.0 / 10)
            if dayOffset % 3 == 0 {
                let painVal = max(1.0, 7.0 - (6.0 * t))
                items.append(
                    Measurement(
                        name: "Pain Index",
                        type: .pain,
                        category: .subjectiveWellbeing,
                        value: (painVal * 10).rounded() / 10,
                        unit: "/10",
                        dateRecorded: date,
                        source: .manualEntry,
                        referenceRangeMin: 0.0,
                        referenceRangeMax: 2.0,
                        associatedProtocolId: protocolId,
                        customMetricCode: "pain_index",
                        notes: dayOffset == 30 ? "Pre-BPC-157 knee patellar tendonitis baseline" : "Post-injection evaluation"
                    )
                )
            }

            // 7. Custom Metric: Grip Strength (Dominant)
            if dayOffset % 5 == 0 {
                let gripVal = 105.0 + (17.0 * t) + (Double(dayOffset % 2) * 1.5)
                items.append(
                    Measurement(
                        name: "Grip Strength (Dominant)",
                        type: .custom,
                        category: .custom,
                        value: (gripVal * 10).rounded() / 10,
                        unit: "lbs",
                        dateRecorded: date,
                        source: .manualEntry,
                        referenceRangeMin: 100.0,
                        referenceRangeMax: 150.0,
                        associatedProtocolId: protocolId,
                        customMetricCode: "custom_grip_strength_dominant"
                    )
                )
            }
        }

        return items
    }
}

