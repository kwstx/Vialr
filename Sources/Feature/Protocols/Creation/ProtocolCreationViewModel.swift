import SwiftUI
import Observation
import Domain
import Data
import CalculationEngine
import DesignSystem

// MARK: - Guided Step Enumeration
public enum ProtocolCreationStep: Int, CaseIterable, Identifiable, Comparable {
    case compound = 0
    case dose = 1
    case frequency = 2
    case route = 3
    case scheduleDates = 4
    case reminders = 5
    case attachVial = 6
    case review = 7

    public var id: Int { rawValue }

    public static func < (lhs: ProtocolCreationStep, rhs: ProtocolCreationStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var title: String {
        switch self {
        case .compound: return "Choose Compound"
        case .dose: return "Planned Dose"
        case .frequency: return "Dosing Frequency"
        case .route: return "Administration Route"
        case .scheduleDates: return "Protocol Schedule"
        case .reminders: return "Smart Reminders"
        case .attachVial: return "Attach Inventory Vial"
        case .review: return "Review & Confirm"
        }
    }

    public var stepSubtitle: String {
        switch self {
        case .compound: return "Select from your library or create a custom compound."
        case .dose: return "Set your target amount and measurement unit."
        case .frequency: return "Define how often you administer this compound."
        case .route: return "Select the delivery method and administration timing."
        case .scheduleDates: return "Choose when your protocol starts and optional duration."
        case .reminders: return "Get reminded before your scheduled doses."
        case .attachVial: return "Link a vial to auto-deduct volume and forecast depletion."
        case .review: return "Confirm your protocol setup before launching."
        }
    }
}

// MARK: - Frequency Type Option
public enum FrequencyType: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case everyOtherDay = "Every Other Day (EOD)"
    case daysOfWeek = "Specific Days of Week"
    case cycle = "Cycle (On / Off)"
    case everyNDays = "Every N Days"
    case asNeeded = "As Needed (PRN)"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .daily: return "calendar.day.timeline.left"
        case .everyOtherDay: return "arrow.left.and.right.circle"
        case .daysOfWeek: return "calendar"
        case .cycle: return "arrow.triangle.2.circlepath"
        case .everyNDays: return "number.circle"
        case .asNeeded: return "cross.case"
        }
    }
}

// MARK: - Start Date Option
public enum StartDateOption: String, CaseIterable, Identifiable {
    case today = "Today"
    case tomorrow = "Tomorrow"
    case custom = "Pick Date"

    public var id: String { rawValue }
}

// MARK: - Duration Preset
public enum DurationPreset: String, CaseIterable, Identifiable {
    case ongoing = "Ongoing (No End Date)"
    case weeks4 = "4 Weeks"
    case weeks8 = "8 Weeks"
    case weeks12 = "12 Weeks"
    case weeks16 = "16 Weeks"
    case custom = "Custom Date"

    public var id: String { rawValue }
}

// MARK: - Protocol Creation View Model
@Observable
public final class ProtocolCreationViewModel: @unchecked Sendable {
    // Navigation
    public var currentStep: ProtocolCreationStep = .compound
    public var isSubmitting: Bool = false
    public var errorMessage: String?

    // Repositories
    private let compoundRepo: CompoundRepositoryProtocol
    private let vialRepo: VialRepositoryProtocol
    private let protocolRepo: ProtocolRepositoryProtocol
    private let schedulingEngine: ProtocolSchedulingEngine

    // Step 1: Compound
    public var availableCompounds: [Compound] = []
    public var selectedCompound: Compound?
    public var compoundSearchQuery: String = ""
    public var selectedCategoryFilter: CompoundCategory? = nil
    public var isShowingNewCompoundSheet: Bool = false

    // Custom Compound Inline Creator
    public var newCompoundName: String = ""
    public var newCompoundCategory: CompoundCategory = .recovery
    public var newCompoundUnit: DoseUnit = .mcg
    public var newCompoundTypicalDose: Double = 250
    public var newCompoundRoute: AdministrationRoute = .subcutaneous

    // Step 2: Planned Dose
    public var doseAmount: Double = 250
    public var doseUnit: DoseUnit = .mcg
    public var enableTitration: Bool = false
    public var titrationTargetDose: Double = 500
    public var titrationStepAmount: Double = 50
    public var titrationStepDays: Int = 7

    // Step 3: Frequency / Schedule Rule
    public var frequencyType: FrequencyType = .daily
    public var selectedWeekdays: Set<Int> = [2, 4, 6] // Mon, Wed, Fri (1=Sun, 2=Mon, ...)
    public var cycleDaysOn: Int = 5
    public var cycleDaysOff: Int = 2
    public var everyNIntervalDays: Int = 3
    public var timesPerDay: Int = 1
    public var preferredTimeOfDay: TimeOfDay = .morning

    // Step 4: Administration Route
    public var selectedRoute: AdministrationRoute = .subcutaneous
    public var foodRequirement: FoodRequirement = .fasted
    public var instructions: String = ""

    // Step 5: Start & End Dates
    public var startDateOption: StartDateOption = .today
    public var customStartDate: Date = Date()
    public var durationPreset: DurationPreset = .ongoing
    public var customEndDate: Date = Calendar.current.date(byAdding: .day, value: 56, to: Date()) ?? Date()

    // Step 6: Smart Reminders
    public var reminderEnabled: Bool = true
    public var reminderTime: Date = {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    public var reminderLeadTimeMinutes: Int = 15 // 0, 15, 30, 60

    // Step 7: Attach Existing Vial
    public var userVials: [Vial] = []
    public var selectedVial: Vial?
    public var shouldAttachVial: Bool = true

    // Step 8: Review & Meta
    public var protocolName: String = ""
    public var protocolGoal: String = ""
    public var protocolNotes: String = ""
    public var protocolColorHex: String = "#10E79D"

    public init(
        compoundRepo: CompoundRepositoryProtocol = LocalCompoundRepository(),
        vialRepo: VialRepositoryProtocol = LocalVialRepository(),
        protocolRepo: ProtocolRepositoryProtocol = LocalProtocolRepository(),
        schedulingEngine: ProtocolSchedulingEngine = ProtocolSchedulingEngine()
    ) {
        self.compoundRepo = compoundRepo
        self.vialRepo = vialRepo
        self.protocolRepo = protocolRepo
        self.schedulingEngine = schedulingEngine
    }

    // MARK: - Data Loading
    public func loadData() async {
        do {
            let fetchedCompounds = try await compoundRepo.fetchAll()
            if fetchedCompounds.isEmpty {
                self.availableCompounds = MockDataFactory().defaultCompounds
            } else {
                self.availableCompounds = fetchedCompounds
            }

            let fetchedVials = try await vialRepo.fetchAll()
            self.userVials = fetchedVials.isEmpty ? MockDataFactory().defaultVials : fetchedVials

            // Default selection if empty
            if selectedCompound == nil, let first = availableCompounds.first {
                selectCompound(first)
            }
        } catch {
            print("Failed to load compounds or vials: \(error)")
            self.availableCompounds = MockDataFactory().defaultCompounds
            self.userVials = MockDataFactory().defaultVials
            if let first = availableCompounds.first {
                selectCompound(first)
            }
        }
    }

    // MARK: - Compound Selection
    public func selectCompound(_ compound: Compound) {
        self.selectedCompound = compound
        self.doseAmount = compound.typicalDose > 0 ? compound.typicalDose : 250
        self.doseUnit = compound.defaultUnit
        self.selectedRoute = compound.administrationRoute
        self.protocolName = "\(compound.name) Protocol"
        self.protocolGoal = compound.description.isEmpty ? "Optimized \(compound.name) schedule" : compound.description

        // Auto-match existing vial if available
        let matching = userVials.filter { $0.compoundId == compound.id || $0.compoundName.localizedCaseInsensitiveContains(compound.name) }
        self.selectedVial = matching.first(where: { $0.status == .reconstituted }) ?? matching.first
    }

    // Filtered compounds
    public var filteredCompounds: [Compound] {
        availableCompounds.filter { compound in
            let matchesCategory = selectedCategoryFilter == nil || compound.category == selectedCategoryFilter
            if compoundSearchQuery.isEmpty {
                return matchesCategory
            }
            let query = compoundSearchQuery.lowercased()
            let matchesName = compound.name.lowercased().contains(query)
            let matchesCode = compound.shortCode.lowercased().contains(query)
            let matchesTags = compound.tags.contains { $0.lowercased().contains(query) }
            return matchesCategory && (matchesName || matchesCode || matchesTags)
        }
    }

    // Filtered vials for selected compound
    public var matchingVialsForSelectedCompound: [Vial] {
        guard let compound = selectedCompound else { return [] }
        return userVials.filter { vial in
            vial.compoundId == compound.id || vial.compoundName.localizedCaseInsensitiveContains(compound.name)
        }
    }

    // MARK: - Date Computations
    public var effectiveStartDate: Date {
        let calendar = Calendar.current
        let now = Date()
        switch startDateOption {
        case .today:
            return calendar.startOfDay(for: now)
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        case .custom:
            return calendar.startOfDay(for: customStartDate)
        }
    }

    public var effectiveEndDate: Date? {
        let calendar = Calendar.current
        let start = effectiveStartDate
        switch durationPreset {
        case .ongoing:
            return nil
        case .weeks4:
            return calendar.date(byAdding: .day, value: 28, to: start)
        case .weeks8:
            return calendar.date(byAdding: .day, value: 56, to: start)
        case .weeks12:
            return calendar.date(byAdding: .day, value: 84, to: start)
        case .weeks16:
            return calendar.date(byAdding: .day, value: 112, to: start)
        case .custom:
            return calendar.startOfDay(for: customEndDate)
        }
    }

    // Total planned duration in days
    public var totalDurationDays: Int? {
        guard let end = effectiveEndDate else { return nil }
        let components = Calendar.current.dateComponents([.day], from: effectiveStartDate, to: end)
        return max(1, components.day ?? 1)
    }

    // MARK: - Schedule Rule Builder
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

    // MARK: - Vial Depletion Projection
    public var vialDepletionForecast: VialDepletionProjection? {
        guard let vial = selectedVial, let compound = selectedCompound else { return nil }
        let tempCompound = buildProtocolCompound(protocolId: UUID())
        let tempProtocol = ProtocolModel(
            name: protocolName,
            status: .active,
            startDate: effectiveStartDate,
            endDate: effectiveEndDate,
            compounds: [tempCompound]
        )
        return schedulingEngine.calculateVialDepletion(
            vial: vial,
            protocolModel: tempProtocol,
            compound: tempCompound,
            from: effectiveStartDate
        )
    }

    // Projected upcoming 7-day occurrences preview
    public var previewOccurrences: [ExpectedDoseOccurrence] {
        guard let _ = selectedCompound else { return [] }
        let tempCompound = buildProtocolCompound(protocolId: UUID())
        let tempProtocol = ProtocolModel(
            name: protocolName,
            status: .active,
            startDate: effectiveStartDate,
            endDate: effectiveEndDate,
            compounds: [tempCompound]
        )
        let horizonEnd = Calendar.current.date(byAdding: .day, value: 14, to: effectiveStartDate) ?? effectiveStartDate
        return schedulingEngine.generateOccurrences(for: tempProtocol, in: effectiveStartDate...horizonEnd)
    }

    // MARK: - Step Validation
    public var canProceedToNextStep: Bool {
        switch currentStep {
        case .compound:
            return selectedCompound != nil
        case .dose:
            return doseAmount > 0
        case .frequency:
            if frequencyType == .daysOfWeek {
                return !selectedWeekdays.isEmpty
            }
            return true
        case .route:
            return true
        case .scheduleDates:
            if let end = effectiveEndDate {
                return end >= effectiveStartDate
            }
            return true
        case .reminders:
            return true
        case .attachVial:
            return true
        case .review:
            return !protocolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - Navigation Actions
    public func nextStep() {
        guard canProceedToNextStep else { return }
        if let next = ProtocolCreationStep(rawValue: currentStep.rawValue + 1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self.currentStep = next
            }
            VialrHaptics.selection()
        }
    }

    public func previousStep() {
        if let prev = ProtocolCreationStep(rawValue: currentStep.rawValue - 1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self.currentStep = prev
            }
            VialrHaptics.lightImpact()
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

    // MARK: - Inline Custom Compound Creation
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
        isShowingNewCompoundSheet = false
        return custom
    }

    // MARK: - Final Protocol Assembly
    public func buildProtocolCompound(protocolId: UUID) -> ProtocolCompound {
        let compound = selectedCompound!
        let titration = enableTitration ? TitrationRule(
            startDose: doseAmount,
            targetDose: titrationTargetDose,
            stepAmount: titrationStepAmount,
            stepIntervalDays: max(1, titrationStepDays)
        ) : nil

        return ProtocolCompound(
            id: UUID(),
            protocolId: protocolId,
            compoundId: compound.id,
            compoundName: compound.name,
            doseAmount: doseAmount,
            doseUnit: doseUnit,
            route: selectedRoute,
            scheduleRule: computedScheduleRule,
            timesPerDay: max(1, timesPerDay),
            preferredTimeOfDay: preferredTimeOfDay,
            reminderEnabled: reminderEnabled,
            reminderTime: reminderEnabled ? reminderTime : nil,
            reminderLeadTimeMinutes: reminderLeadTimeMinutes,
            titrationStep: titration,
            foodRequirement: foodRequirement,
            instructions: instructions,
            notes: protocolNotes,
            attachedVialId: shouldAttachVial ? selectedVial?.id : nil,
            startDate: effectiveStartDate,
            endDate: effectiveEndDate,
            isActive: true
        )
    }

    public func buildFinalProtocol() -> ProtocolModel {
        let protocolId = UUID()
        let compoundItem = buildProtocolCompound(protocolId: protocolId)
        let finalName = protocolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(compoundItem.compoundName) Protocol"
            : protocolName.trimmingCharacters(in: .whitespacesAndNewlines)

        return ProtocolModel(
            id: protocolId,
            name: finalName,
            status: .active,
            startDate: effectiveStartDate,
            endDate: effectiveEndDate,
            notes: protocolNotes,
            compounds: [compoundItem],
            goalSummary: protocolGoal.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: protocolColorHex
        )
    }

    public func saveProtocol() async throws -> ProtocolModel {
        isSubmitting = true
        defer { isSubmitting = false }

        let newProtocol = buildFinalProtocol()
        try await protocolRepo.save(newProtocol)
        return newProtocol
    }
}
