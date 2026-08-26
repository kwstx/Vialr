import SwiftUI
import Observation
import Domain
import Health
import Data
import CalculationEngine
import DesignSystem

/// View model orchestrating the end-to-end first-run experience setup wizard after signup:
/// 1. First Protocol Prompt: Ask whether to create first protocol or use starter template
/// 2. Add Compound: Select from catalog or custom + planned dose and unit
/// 3. Configure Schedule: Dosing cadence, routine, start date, and time of day
/// 4. Optionally Add Vial: Reconstitution math, liquid draw volume, syringe tick units
/// 5. Configure Reminders: Scheduled alert times, lead times, low-stock warnings
/// 6. Optionally Connect HealthKit: Apple Health biometrics integration
/// 7. "You're Ready": Summary verification and database commitment with real initial data
@Observable
public final class PostAuthSetupViewModel: @unchecked Sendable {
    // MARK: - Step Navigation
    public var currentStepIndex: Int = 0
    public let totalSteps: Int = PostAuthSetupStep.allCases.count
    public var isSubmitting: Bool = false
    public var errorMessage: String? = nil

    // MARK: - Step 1: First Protocol Decision
    public var wantsFirstProtocol: Bool = true
    public var firstProtocolChoice: FirstProtocolChoice = .createCustom
    public var starterTemplates: [StarterProtocolTemplate] = StarterProtocolTemplate.standardTemplates
    public var selectedTemplateId: String? = nil

    // MARK: - Step 2: Compound & Planned Dose
    public var availableCompounds: [Compound] = []
    public var selectedCompound: Compound?
    public var compoundSearchQuery: String = ""
    public var protocolName: String = ""
    public var protocolGoal: String = ""
    public var doseAmount: Double = 250
    public var doseUnit: DoseUnit = .mcg
    public var selectedRoute: AdministrationRoute = .subcutaneous
    public var foodRequirement: FoodRequirement = .fasted
    public var protocolNotes: String = ""
    public var protocolColorHex: String = "#10E79D"

    // Custom Compound Inline Creator
    public var isShowingCustomCompoundSheet: Bool = false
    public var newCompoundName: String = ""
    public var newCompoundCategory: CompoundCategory = .recovery
    public var newCompoundUnit: DoseUnit = .mcg
    public var newCompoundTypicalDose: Double = 250
    public var newCompoundRoute: AdministrationRoute = .subcutaneous

    // MARK: - Step 3: Dosing Schedule
    public var frequencyType: FrequencyType = .daily
    public var selectedWeekdays: Set<Int> = [2, 4, 6] // Mon, Wed, Fri (1=Sun, 2=Mon...)
    public var cycleDaysOn: Int = 5
    public var cycleDaysOff: Int = 2
    public var everyNIntervalDays: Int = 3
    public var startDateOption: StartDateOption = .today
    public var customStartDate: Date = Date()
    public var durationPreset: DurationPreset = .weeks8
    public var customEndDate: Date = Calendar.current.date(byAdding: .day, value: 56, to: Date()) ?? Date()
    public var preferredTimeOfDay: TimeOfDay = .morning

    // MARK: - Step 4: Optional Inventory Vial
    public var shouldAddVial: Bool = true
    public var vialDryMassMg: Double = 5.0
    public var vialBacWaterMl: Double = 2.0
    public var vialLotNumber: String = "LOT-101A"
    public var vialVendor: String = ""
    public var vialStorageCondition: StorageCondition = .refrigerated
    public var vialExpirationDays: Int = 30

    // MARK: - Step 5: Smart Reminders
    public var enableDoseReminders: Bool = true
    public var reminderTime: Date = {
        var comp = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comp.hour = 8
        comp.minute = 0
        return Calendar.current.date(from: comp) ?? Date()
    }()
    public var reminderLeadTimeMinutes: Int = 15
    public var enableRestockAlerts: Bool = true
    public var enableDailyMorningSummary: Bool = true
    public var morningSummaryTime: String = "08:00"
    public var notificationPermissionGranted: Bool = false

    // MARK: - Step 6: Apple Health Integration
    public var enableAppleHealth: Bool = true
    public var enabledHealthMetrics: Set<HealthMetricType> = [
        .weight,
        .restingHeartRate,
        .heartRateVariability,
        .bloodGlucose,
        .sleepAnalysis
    ]
    public var healthAuthRequested: Bool = false

    // MARK: - User Preferences & Privacy (Backwards Compatibility)
    public var massUnit: DoseUnit = .mcg
    public var weightUnit: WeightUnit = .lbs
    public var heightUnit: HeightUnit = .inches
    public var bloodGlucoseUnit: BloodGlucoseUnit = .mgDl
    public var liquidVolumeUnit: LiquidVolumeUnit = .milliliters
    public var selectedTimezone: String = TimeZone.current.identifier
    public var timezoneSearchQuery: String = ""
    public var requireBiometricUnlock: Bool = true
    public var biometricTimeoutSeconds: Int = 60
    public var maskSensitiveDosagesOnLockScreen: Bool = true
    public var allowDiagnosticTelemetry: Bool = false

    // MARK: - Dependencies
    private let userRepo: UserRepositoryProtocol
    private let protocolRepo: ProtocolRepositoryProtocol
    private let vialRepo: VialRepositoryProtocol
    private let doseRepo: DoseLogRepositoryProtocol
    private let compoundRepo: CompoundRepositoryProtocol
    private let supplyRepo: SupplyRepositoryProtocol
    private let healthSettingsManager: HealthSettingsManager
    private let healthService: HealthServiceProtocol
    private let notificationScheduler: NotificationSchedulerProtocol
    private let schedulingEngine: ProtocolSchedulingEngine
    private let userDefaults: UserDefaults

    // MARK: - Computed Step Accessors
    public var currentStep: PostAuthSetupStep {
        PostAuthSetupStep(rawValue: currentStepIndex) ?? .firstProtocolPrompt
    }

    public var isLastStep: Bool {
        currentStepIndex >= totalSteps - 1
    }

    public init(
        userRepo: UserRepositoryProtocol = LocalUserRepository(),
        protocolRepo: ProtocolRepositoryProtocol = LocalProtocolRepository(),
        vialRepo: VialRepositoryProtocol = LocalVialRepository(),
        doseRepo: DoseLogRepositoryProtocol = LocalDoseLogRepository(),
        compoundRepo: CompoundRepositoryProtocol = LocalCompoundRepository(),
        supplyRepo: SupplyRepositoryProtocol = LocalSupplyRepository(),
        healthSettingsManager: HealthSettingsManager = .shared,
        healthService: HealthServiceProtocol = HealthKitManager.shared,
        notificationScheduler: NotificationSchedulerProtocol = NotificationScheduler(),
        schedulingEngine: ProtocolSchedulingEngine = ProtocolSchedulingEngine(),
        userDefaults: UserDefaults = .standard
    ) {
        self.userRepo = userRepo
        self.protocolRepo = protocolRepo
        self.vialRepo = vialRepo
        self.doseRepo = doseRepo
        self.compoundRepo = compoundRepo
        self.supplyRepo = supplyRepo
        self.healthSettingsManager = healthSettingsManager
        self.healthService = healthService
        self.notificationScheduler = notificationScheduler
        self.schedulingEngine = schedulingEngine
        self.userDefaults = userDefaults

        // Preload standard compounds
        Task {
            await loadInitialCompounds()
        }
    }

    // MARK: - Data Initialization
    public func loadInitialCompounds() async {
        do {
            let fetched = try await compoundRepo.fetchAll()
            if fetched.isEmpty {
                self.availableCompounds = MockDataFactory().defaultCompounds
            } else {
                self.availableCompounds = fetched
            }

            if selectedCompound == nil, let first = availableCompounds.first {
                selectCompound(first)
            }
        } catch {
            self.availableCompounds = MockDataFactory().defaultCompounds
            if let first = availableCompounds.first {
                selectCompound(first)
            }
        }
    }

    // MARK: - Step 1 Actions: First Protocol Decisions
    public func selectTemplate(_ template: StarterProtocolTemplate) {
        self.selectedTemplateId = template.id
        self.firstProtocolChoice = .useTemplate
        self.wantsFirstProtocol = true

        // Configure compound & dose
        if let match = availableCompounds.first(where: { $0.name.localizedCaseInsensitiveContains(template.compoundName) }) {
            self.selectedCompound = match
        } else {
            let comp = Compound(
                name: template.compoundName,
                category: template.category,
                defaultUnit: template.doseUnit,
                typicalDose: template.doseAmount,
                administrationRoute: template.route
            )
            self.selectedCompound = comp
        }

        self.protocolName = template.title
        self.protocolGoal = template.goalSummary
        self.doseAmount = template.doseAmount
        self.doseUnit = template.doseUnit
        self.selectedRoute = template.route
        self.frequencyType = template.frequencyType

        // Configure vial defaults
        self.vialDryMassMg = template.defaultVialDryMassMg
        self.vialBacWaterMl = template.defaultVialBacWaterMl
        self.shouldAddVial = true

        VialrHaptics.selection()
    }

    public func chooseCreateCustomProtocol() {
        self.firstProtocolChoice = .createCustom
        self.wantsFirstProtocol = true
        self.selectedTemplateId = nil
        if let first = availableCompounds.first, selectedCompound == nil {
            selectCompound(first)
        }
        VialrHaptics.selection()
    }

    public func chooseSkipProtocol() {
        self.firstProtocolChoice = .skipForNow
        self.wantsFirstProtocol = false
        self.selectedTemplateId = nil
        VialrHaptics.selection()
    }

    public func chooseSampleData() {
        self.firstProtocolChoice = .sampleData
        self.wantsFirstProtocol = true
        if let bpcTemplate = starterTemplates.first {
            selectTemplate(bpcTemplate)
        }
        VialrHaptics.selection()
    }

    // MARK: - Step 2 Actions: Compound Selection
    public func selectCompound(_ compound: Compound) {
        self.selectedCompound = compound
        self.doseAmount = compound.typicalDose > 0 ? compound.typicalDose : (compound.defaultUnit == .mg ? 2.5 : 250)
        self.doseUnit = compound.defaultUnit
        self.selectedRoute = compound.administrationRoute
        self.protocolName = "\(compound.name) Protocol"
        self.protocolGoal = compound.description.isEmpty ? "Optimized \(compound.name) schedule" : compound.description

        // Adjust vial defaults based on typical mass
        if compound.defaultUnit == .mg {
            self.vialDryMassMg = max(5.0, compound.typicalDose * 4)
            self.vialBacWaterMl = 2.0
        } else {
            self.vialDryMassMg = 5.0
            self.vialBacWaterMl = 2.0
        }
    }

    public var filteredCompounds: [Compound] {
        if compoundSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return availableCompounds
        }
        let q = compoundSearchQuery.lowercased()
        return availableCompounds.filter {
            $0.name.lowercased().contains(q) ||
            $0.shortCode.lowercased().contains(q) ||
            $0.tags.contains { $0.lowercased().contains(q) }
        }
    }

    public func createCustomCompound() async -> Compound {
        let name = newCompoundName.trimmingCharacters(in: .whitespacesAndNewlines)
        let custom = Compound.custom(
            name: name.isEmpty ? "Custom Peptide" : name,
            category: newCompoundCategory,
            defaultUnit: newCompoundUnit,
            typicalDose: newCompoundTypicalDose,
            administrationRoute: newCompoundRoute
        )
        try? await compoundRepo.save(custom)
        availableCompounds.insert(custom, at: 0)
        selectCompound(custom)
        newCompoundName = ""
        isShowingCustomCompoundSheet = false
        return custom
    }

    // MARK: - Step 3 Actions: Schedule
    public var effectiveStartDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch startDateOption {
        case .today:
            return cal.startOfDay(for: now)
        case .tomorrow:
            return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
        case .custom:
            return cal.startOfDay(for: customStartDate)
        }
    }

    public var effectiveEndDate: Date? {
        let cal = Calendar.current
        let start = effectiveStartDate
        switch durationPreset {
        case .ongoing:
            return nil
        case .weeks4:
            return cal.date(byAdding: .day, value: 28, to: start)
        case .weeks8:
            return cal.date(byAdding: .day, value: 56, to: start)
        case .weeks12:
            return cal.date(byAdding: .day, value: 84, to: start)
        case .weeks16:
            return cal.date(byAdding: .day, value: 112, to: start)
        case .custom:
            return cal.startOfDay(for: customEndDate)
        }
    }

    public var computedScheduleRule: ScheduleRule {
        switch frequencyType {
        case .daily:
            return .everyDay
        case .everyOtherDay:
            return .everyOtherDay
        case .daysOfWeek:
            let days = Array(selectedWeekdays).sorted()
            return .daysOfWeek(days.isEmpty ? [2, 4, 6] : days)
        case .cycle:
            return .cycle(daysOn: max(1, cycleDaysOn), daysOff: max(1, cycleDaysOff))
        case .everyNDays:
            return .everyNDays(max(1, everyNIntervalDays))
        case .asNeeded:
            return .asNeeded
        }
    }

    public func toggleWeekday(_ day: Int) {
        if selectedWeekdays.contains(day) {
            if selectedWeekdays.count > 1 {
                selectedWeekdays.remove(day)
            }
        } else {
            selectedWeekdays.insert(day)
        }
        VialrHaptics.lightImpact()
    }

    // MARK: - Step 4: Reconstitution & Syringe Math Computations
    public var vialConcentrationMgMl: Double {
        let water = max(0.1, vialBacWaterMl)
        return vialDryMassMg / water
    }

    public var vialConcentrationMcgMl: Double {
        vialConcentrationMgMl * 1000.0
    }

    public var doseInMilligrams: Double {
        (doseUnit == .mg) ? doseAmount : (doseAmount / 1000.0)
    }

    public var calculatedDrawVolumeMl: Double {
        guard vialConcentrationMgMl > 0 else { return 0.0 }
        return doseInMilligrams / vialConcentrationMgMl
    }

    public var calculatedSyringeUnits: Double {
        calculatedDrawVolumeMl * 100.0 // Standard U-100 syringe: 1.0 mL = 100 units
    }

    public var estimatedDosesInVial: Int {
        guard doseInMilligrams > 0 else { return 0 }
        return max(1, Int(vialDryMassMg / doseInMilligrams))
    }

    // MARK: - Step 5: Reminders & Permissions
    public func requestNotificationPermissions() async {
        notificationPermissionGranted = true
        VialrHaptics.mediumImpact()
        _ = await NotificationClientManager.shared.requestAuthorization()
    }

    // MARK: - Step 6: HealthKit Permissions
    public func requestHealthKitPermissions() async {
        healthAuthRequested = true
        VialrHaptics.mediumImpact()
        do {
            _ = try await healthService.requestAuthorization()
        } catch {
            print("[PostAuthSetup] HealthKit request authorization completed: \(error)")
        }
    }

    public func toggleHealthMetric(_ metric: HealthMetricType) {
        if enabledHealthMetrics.contains(metric) {
            if enabledHealthMetrics.count > 1 {
                enabledHealthMetrics.remove(metric)
            }
        } else {
            enabledHealthMetrics.insert(metric)
        }
        VialrHaptics.selection()
    }

    // MARK: - Step Navigation Controls
    public var canProceedToNextStep: Bool {
        switch currentStep {
        case .firstProtocolPrompt:
            return true
        case .compound:
            if !wantsFirstProtocol { return true }
            return selectedCompound != nil && doseAmount > 0
        case .schedule:
            if !wantsFirstProtocol { return true }
            if frequencyType == .daysOfWeek {
                return !selectedWeekdays.isEmpty
            }
            return true
        case .vial:
            return true
        case .reminders:
            return true
        case .healthKit:
            return true
        case .ready:
            return true
        }
    }

    public func nextStep() {
        guard canProceedToNextStep else { return }

        // If user chose to skip protocol creation, skip compound, schedule, and vial steps
        if currentStep == .firstProtocolPrompt && !wantsFirstProtocol {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                currentStepIndex = PostAuthSetupStep.reminders.rawValue
            }
            VialrHaptics.lightImpact()
            return
        }

        if currentStepIndex < totalSteps - 1 {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                currentStepIndex += 1
            }
            VialrHaptics.lightImpact()
        }
    }

    public func previousStep() {
        // If user skipped to reminders from firstProtocolPrompt
        if currentStep == .reminders && !wantsFirstProtocol {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                currentStepIndex = PostAuthSetupStep.firstProtocolPrompt.rawValue
            }
            VialrHaptics.lightImpact()
            return
        }

        if currentStepIndex > 0 {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                currentStepIndex -= 1
            }
            VialrHaptics.lightImpact()
        }
    }

    public func goToStep(_ step: PostAuthSetupStep) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            currentStepIndex = step.rawValue
        }
    }

    // MARK: - Filtered Timezones (Backwards Compatibility)
    public var filteredTimezones: [String] {
        let known = TimeZone.knownTimeZoneIdentifiers
        if timezoneSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let common = [
                TimeZone.current.identifier,
                "America/New_York",
                "America/Chicago",
                "America/Denver",
                "America/Los_Angeles",
                "America/Phoenix",
                "America/Toronto",
                "Europe/London",
                "Europe/Paris",
                "Europe/Berlin",
                "Asia/Dubai",
                "Asia/Singapore",
                "Asia/Tokyo",
                "Australia/Sydney",
                "Pacific/Auckland"
            ]
            return Array(NSOrderedSet(array: common)).compactMap { $0 as? String }
        }
        return known.filter { $0.localizedCaseInsensitiveContains(timezoneSearchQuery) }
    }

    // MARK: - Finalize Setup & Persist Real Initial Data
    public func finalizeSetup(for baseUser: User) async throws -> User {
        isSubmitting = true
        defer { isSubmitting = false }

        // 1. Prepare User Model
        var updatedUser = baseUser
        updatedUser.timezone = selectedTimezone
        updatedUser.units = UnitPreferences(
            massUnit: doseUnit,
            weightUnit: weightUnit,
            heightUnit: heightUnit,
            bloodGlucoseUnit: bloodGlucoseUnit,
            temperatureUnit: .fahrenheit,
            liquidVolumeUnit: liquidVolumeUnit
        )
        updatedUser.notificationPreferences = NotificationPreferences(
            enableDoseReminders: enableDoseReminders,
            doseReminderLeadTimeMinutes: reminderLeadTimeMinutes,
            enableRestockAlerts: enableRestockAlerts,
            enableStreakCelebrations: true,
            enableDailyMorningSummary: enableDailyMorningSummary,
            morningSummaryTime: morningSummaryTime,
            enableQuietHours: false,
            criticalAlertsEnabled: false
        )
        updatedUser.privacyPreferences = PrivacyPreferences(
            requireBiometricUnlock: requireBiometricUnlock,
            biometricLockTimeoutSeconds: biometricTimeoutSeconds,
            maskSensitiveDosagesOnLockScreen: maskSensitiveDosagesOnLockScreen,
            allowDiagnosticTelemetry: allowDiagnosticTelemetry,
            enableCloudBackupEncryption: true,
            allowClinicianDataSharing: true
        )
        updatedUser.preferences.syncWithAppleHealth = enableAppleHealth
        updatedUser.updatedAt = Date()

        // 2. Save User to Repository
        try await userRepo.saveUser(updatedUser)

        // 3. If User Opted to Create Protocol or Starter Template
        if wantsFirstProtocol, let compound = selectedCompound {
            let protocolId = UUID()
            var createdVialId: UUID? = nil

            // 3a. Save Physical Inventory Vial if Enabled
            if shouldAddVial {
                let vialId = UUID()
                let expirationDate = Calendar.current.date(byAdding: .day, value: vialExpirationDays, to: Date())
                let newVial = Vial(
                    id: vialId,
                    userId: updatedUser.id,
                    compoundId: compound.id,
                    compoundName: compound.name,
                    compoundCategory: compound.category,
                    lotNumber: vialLotNumber.isEmpty ? "LOT-101A" : vialLotNumber,
                    vendor: vialVendor.isEmpty ? "Vialr Stock" : vialVendor,
                    totalDryMassMg: vialDryMassMg,
                    bacWaterAddedMl: vialBacWaterMl,
                    currentVolumeRemainingMl: vialBacWaterMl,
                    isReconstituted: true,
                    reconstitutedDate: Date(),
                    expirationDate: expirationDate,
                    storageCondition: vialStorageCondition,
                    notes: "Reconstituted during setup wizard (\(String(format: "%.1f", vialDryMassMg))mg / \(String(format: "%.1f", vialBacWaterMl))mL)",
                    status: .reconstituted
                )
                try await vialRepo.save(newVial)
                createdVialId = vialId
            }

            // 3b. Build Protocol Compound Item
            let protoCompound = ProtocolCompound(
                id: UUID(),
                protocolId: protocolId,
                compoundId: compound.id,
                compoundName: compound.name,
                doseAmount: doseAmount,
                doseUnit: doseUnit,
                route: selectedRoute,
                scheduleRule: computedScheduleRule,
                timesPerDay: 1,
                preferredTimeOfDay: preferredTimeOfDay,
                reminderEnabled: enableDoseReminders,
                reminderTime: enableDoseReminders ? reminderTime : nil,
                reminderLeadTimeMinutes: reminderLeadTimeMinutes,
                titrationStep: nil,
                foodRequirement: foodRequirement,
                instructions: "Administer \(String(format: doseAmount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", doseAmount)) \(doseUnit.rawValue) \(selectedRoute.shortName)",
                notes: protocolNotes,
                attachedVialId: createdVialId,
                startDate: effectiveStartDate,
                endDate: effectiveEndDate,
                isActive: true
            )

            // 3c. Build and Save Protocol Model
            let finalProtoName = protocolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "\(compound.name) Protocol"
                : protocolName.trimmingCharacters(in: .whitespacesAndNewlines)

            let newProtocol = ProtocolModel(
                id: protocolId,
                name: finalProtoName,
                status: .active,
                startDate: effectiveStartDate,
                endDate: effectiveEndDate,
                notes: protocolNotes,
                compounds: [protoCompound],
                goalSummary: protocolGoal.trimmingCharacters(in: .whitespacesAndNewlines),
                colorHex: protocolColorHex,
                userId: updatedUser.id
            )
            try await protocolRepo.save(newProtocol)

            // 3d. Seed Scheduled Doses so Home Screen contains real data immediately!
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            let reminderComponents = calendar.dateComponents([.hour, .minute], from: reminderTime)
            let todayScheduledDate = calendar.date(
                bySettingHour: reminderComponents.hour ?? 8,
                minute: reminderComponents.minute ?? 0,
                second: 0,
                of: startOfToday
            ) ?? Date()

            let initialDoseLog = DoseLog(
                id: UUID(),
                protocolId: protocolId,
                compoundId: compound.id,
                compoundName: compound.name,
                scheduledDate: todayScheduledDate,
                loggedDate: nil,
                doseAmount: doseAmount,
                doseUnit: doseUnit,
                actualRoute: selectedRoute,
                status: .scheduled,
                injectionSiteId: "ab_l_uo",
                injectionSiteName: "Abdomen - Left Upper Outer",
                vialId: createdVialId,
                notes: "Scheduled during first-run setup."
            )
            try await doseRepo.save(initialDoseLog)

            // 3e. Reschedule Notifications
            _ = try? await notificationScheduler.rescheduleReminders(
                for: newProtocol,
                referenceDate: Date(),
                horizonDays: 30,
                timeZone: TimeZone(identifier: selectedTimezone) ?? .current
            )
        }

        // 4. Configure Health Settings Manager
        healthSettingsManager.setIntegrationEnabled(enableAppleHealth)
        for metric in HealthMetricType.allCases {
            healthSettingsManager.toggleMetric(metric, enabled: enabledHealthMetrics.contains(metric))
        }

        // 5. Mark Onboarding Globally Completed in UserDefaults
        userDefaults.set(true, forKey: OnboardingPagerViewModel.onboardingCompletedStorageKey)

        VialrHaptics.notificationSuccess()
        return updatedUser
    }
}
