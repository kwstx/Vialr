import SwiftUI
import Observation
import Domain
import DesignSystem

@Observable
public final class OnboardingViewModel: @unchecked Sendable {
    public var currentStepIndex: Int = 0
    
    // User Answers
    public var selectedGoals: Set<String> = ["Recovery & Injury Repair"]
    public var experienceLevel: String = "Intermediate (1–2 cycles)"
    public var selectedCompounds: Set<String> = ["BPC-157", "TB-500"]
    public var primaryAdministrationRoute: AdministrationRoute = .subcutaneous
    public var preferredDoseTime: TimeOfDay = .morning
    public var defaultSyringeType: String = "U-100 Insulin Syringe (0.5 mL)"
    public var enableSiteRotationReminders: Bool = true
    public var enableAppleHealthSync: Bool = true
    public var enablePushNotifications: Bool = true
    public var reminderTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    public var preferredUnit: DoseUnit = .mcg
    public var trackingPriority: String = "Longitudinal Outcomes & Biomarkers"
    
    // Total number of onboarding steps (11 interactive screens)
    public let totalSteps: Int = 11

    public var isComplete: Bool = false

    public init() {}

    public func nextStep() {
        if currentStepIndex < totalSteps - 1 {
            currentStepIndex += 1
        } else {
            isComplete = true
        }
    }

    public func previousStep() {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
        }
    }

    public func toggleGoal(_ goal: String) {
        if selectedGoals.contains(goal) {
            selectedGoals.remove(goal)
        } else {
            selectedGoals.insert(goal)
        }
    }

    public func toggleCompound(_ compound: String) {
        if selectedCompounds.contains(compound) {
            selectedCompounds.remove(compound)
        } else {
            selectedCompounds.insert(compound)
        }
    }
}
