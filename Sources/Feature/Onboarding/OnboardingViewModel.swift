import SwiftUI
import Observation
import Domain
import DesignSystem

@Observable
public final class OnboardingViewModel: @unchecked Sendable {
    public var currentStepIndex: Int = 0
    
    // Total number of onboarding steps (12 product-driven screens)
    public let totalSteps: Int = 12
    public var isComplete: Bool = false

    // MARK: - 1. What are you looking to track?
    public var primaryCategory: String = "Peptides"

    // MARK: - 2. What is your main goal? (Multi-select)
    public var selectedGoals: Set<String> = ["Recovery", "Performance"]

    // MARK: - 3. How many compounds are you currently tracking?
    public var compoundCountRange: String = "2–3"

    // MARK: - 4. Are you currently following a dosing schedule?
    public var dosingScheduleStatus: String = "Yes, consistently"

    // MARK: - 5. What do you want the app to help you stay on top of? (Multi-select)
    public var featuresToStayOnTop: Set<String> = ["Doses", "Reconstitution", "Injection sites", "Inventory"]

    // MARK: - 6. How often do you want to track your progress?
    public var progressTrackingFrequency: String = "Weekly"

    // MARK: - 7. Do you currently track your bloodwork somewhere?
    public var bloodworkTrackingStatus: String = "I want to start tracking it"

    // MARK: - 8. How do you currently keep track of your doses?
    public var doseTrackingMethod: String = "Notes"

    // MARK: - 9. How important is automatic dose calculation to you?
    public var calculationImportance: String = "Essential"

    // MARK: - 10. Would you like to track your injection sites?
    public var injectionSiteTracking: String = "Yes"

    // MARK: - 11. Would you like to connect Apple Health?
    public var appleHealthPreference: String = "Yes"

    // MARK: - 12. What would make this app most valuable to you? (Multi-select)
    public var keyValuedBenefits: Set<String> = [
        "Never forget a dose",
        "Get my dosing math right",
        "Keep everything in one place"
    ]

    // MARK: - Derived Protocol Settings
    public var enableSiteRotation: Bool {
        injectionSiteTracking == "Yes"
    }

    public var enableAppleHealthSync: Bool {
        appleHealthPreference == "Yes"
    }

    public var needsReconstitutionCalculators: Bool {
        calculationImportance == "Essential" || calculationImportance == "Very useful" || featuresToStayOnTop.contains("Reconstitution")
    }

    public init() {}

    // MARK: - Navigation
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

    // MARK: - Multi-Select Toggles
    public func toggleGoal(_ goal: String) {
        if selectedGoals.contains(goal) {
            if selectedGoals.count > 1 {
                selectedGoals.remove(goal)
            }
        } else {
            selectedGoals.insert(goal)
        }
    }

    public func toggleFeatureToStayOnTop(_ feature: String) {
        if feature == "Everything" {
            if featuresToStayOnTop.contains("Everything") {
                featuresToStayOnTop.removeAll()
            } else {
                featuresToStayOnTop = ["Doses", "Results", "Bloodwork", "Reconstitution", "Injection sites", "Inventory", "Costs", "Everything"]
            }
            return
        }

        if featuresToStayOnTop.contains(feature) {
            featuresToStayOnTop.remove(feature)
            featuresToStayOnTop.remove("Everything")
        } else {
            featuresToStayOnTop.insert(feature)
            let baseFeatures: Set<String> = ["Doses", "Results", "Bloodwork", "Reconstitution", "Injection sites", "Inventory", "Costs"]
            if baseFeatures.isSubset(of: featuresToStayOnTop) {
                featuresToStayOnTop.insert("Everything")
            }
        }
    }

    public func toggleBenefit(_ benefit: String) {
        if keyValuedBenefits.contains(benefit) {
            if keyValuedBenefits.count > 1 {
                keyValuedBenefits.remove(benefit)
            }
        } else {
            keyValuedBenefits.insert(benefit)
        }
    }
}
