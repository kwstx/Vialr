import XCTest
import SwiftUI
@testable import Feature
@testable import Domain

@MainActor
final class OnboardingFlowUITests: XCTestCase {

    private var viewModel: OnboardingViewModel!

    override func setUp() {
        super.setUp()
        viewModel = OnboardingViewModel()
    }

    func testOnboardingInitialState() {
        XCTAssertEqual(viewModel.currentStepIndex, 0)
        XCTAssertEqual(viewModel.totalSteps, 12)
        XCTAssertFalse(viewModel.isComplete)
        XCTAssertEqual(viewModel.primaryCategory, "Peptides")
        XCTAssertTrue(viewModel.selectedGoals.contains("Recovery"))
    }

    func testOnboarding12StepProgression() {
        // Step through all 12 questions from index 0 to 11
        for expectedIndex in 0..<12 {
            XCTAssertEqual(viewModel.currentStepIndex, expectedIndex)
            XCTAssertFalse(viewModel.isComplete)
            viewModel.nextStep()
        }

        // After step 11, nextStep marks onboarding as complete
        XCTAssertTrue(viewModel.isComplete)
        XCTAssertEqual(viewModel.currentStepIndex, 11) // Stays at last step
    }

    func testOnboardingPreviousStepNavigation() {
        XCTAssertEqual(viewModel.currentStepIndex, 0)
        viewModel.previousStep() // Cannot go below 0
        XCTAssertEqual(viewModel.currentStepIndex, 0)

        viewModel.nextStep() // Step 1
        viewModel.nextStep() // Step 2
        XCTAssertEqual(viewModel.currentStepIndex, 2)

        viewModel.previousStep()
        XCTAssertEqual(viewModel.currentStepIndex, 1)
    }

    func testGoalsMultiSelectToggling() {
        viewModel.selectedGoals = ["Recovery"]

        // Add Performance
        viewModel.toggleGoal("Performance")
        XCTAssertTrue(viewModel.selectedGoals.contains("Performance"))
        XCTAssertTrue(viewModel.selectedGoals.contains("Recovery"))

        // Add Longevity
        viewModel.toggleGoal("Longevity")
        XCTAssertTrue(viewModel.selectedGoals.contains("Longevity"))

        // Remove Performance
        viewModel.toggleGoal("Performance")
        XCTAssertFalse(viewModel.selectedGoals.contains("Performance"))

        // Attempt to remove all: minimum 1 goal must always remain selected
        viewModel.toggleGoal("Longevity")
        viewModel.toggleGoal("Recovery")
        XCTAssertEqual(viewModel.selectedGoals.count, 1, "Must retain at least 1 goal")
    }

    func testFeaturesToStayOnTopEverythingToggle() {
        viewModel.featuresToStayOnTop = ["Doses"]

        // Select "Everything" -> fills all features
        viewModel.toggleFeatureToStayOnTop("Everything")
        XCTAssertTrue(viewModel.featuresToStayOnTop.contains("Everything"))
        XCTAssertTrue(viewModel.featuresToStayOnTop.contains("Doses"))
        XCTAssertTrue(viewModel.featuresToStayOnTop.contains("Reconstitution"))
        XCTAssertTrue(viewModel.featuresToStayOnTop.contains("Bloodwork"))

        // Toggle "Everything" again -> deselects all
        viewModel.toggleFeatureToStayOnTop("Everything")
        XCTAssertTrue(viewModel.featuresToStayOnTop.isEmpty)
    }

    func testDerivedProtocolSettings() {
        // Site rotation derived setting
        viewModel.injectionSiteTracking = "Yes"
        XCTAssertTrue(viewModel.enableSiteRotation)
        viewModel.injectionSiteTracking = "No"
        XCTAssertFalse(viewModel.enableSiteRotation)

        // Apple Health derived setting
        viewModel.appleHealthPreference = "Yes"
        XCTAssertTrue(viewModel.enableAppleHealthSync)
        viewModel.appleHealthPreference = "No"
        XCTAssertFalse(viewModel.enableAppleHealthSync)

        // Reconstitution calculator requirement
        viewModel.calculationImportance = "Essential"
        XCTAssertTrue(viewModel.needsReconstitutionCalculators)
        viewModel.calculationImportance = "Not needed"
        viewModel.featuresToStayOnTop = ["Doses"]
        XCTAssertFalse(viewModel.needsReconstitutionCalculators)
        viewModel.featuresToStayOnTop = ["Reconstitution"]
        XCTAssertTrue(viewModel.needsReconstitutionCalculators)
    }
}
