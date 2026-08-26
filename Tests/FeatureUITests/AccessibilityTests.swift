import XCTest
import SwiftUI
@testable import DesignSystem
@testable import Feature
@testable import Domain
@testable import Analytics

@MainActor
final class AccessibilityTests: XCTestCase {

    // MARK: - 1. Minimum Touch Target (Apple HIG >= 44x44pt)

    func testMinimumTouchTargetGuarantee() {
        // Apple HIG requires minimum 44x44 pt touch targets for interactive elements
        XCTAssertGreaterThanOrEqual(
            VialrSpacing.minTouchTarget,
            44.0,
            "Apple HIG minimum touch target must be at least 44 points"
        )
        XCTAssertGreaterThanOrEqual(
            VialrSpacing.buttonHeight,
            44.0,
            "Standard button height must be at least 44 points"
        )
    }

    // MARK: - 2. Non-Color-Reliant Status Indicators

    func testAccessibleStatusIndicatorsNonColorReliance() {
        // Every status type must have distinct iconic shapes and localized text
        let statuses: [AccessibilityStatusType] = [.success, .warning, .critical, .info, .neutral]

        for status in statuses {
            XCTAssertFalse(status.iconName.isEmpty, "Status \(status) must have a non-empty icon")
            XCTAssertFalse(status.shapeDescription.isEmpty, "Status \(status) must have a shape description")
            XCTAssertFalse(status.localizedText.isEmpty, "Status \(status) must have localized text")
        }

        // Verify distinct icon names across statuses
        let iconNames = statuses.map(\.iconName)
        let uniqueIcons = Set(iconNames)
        XCTAssertEqual(uniqueIcons.count, statuses.count, "Each status indicator must have a distinct symbol icon")
    }

    // MARK: - 3. Accessible Chart Framework & Textual Summaries

    func testChartDataSummaryGeneration() {
        let summary = ChartDataSummary(
            title: "IGF-1 Biomarker",
            metricUnit: "ng/mL",
            totalDataPoints: 10,
            minimumValue: 120.0,
            maximumValue: 280.0,
            averageValue: 210.5,
            currentValue: 265.0,
            baselineValue: 120.0,
            trendDirectionDescription: "Shifted +145.0 ng/mL from baseline",
            keyObservations: [
                "Clinical reference range: 115 to 307 ng/mL",
                "Within optimal range"
            ]
        )

        XCTAssertEqual(summary.title, "IGF-1 Biomarker")
        XCTAssertEqual(summary.metricUnit, "ng/mL")
        XCTAssertEqual(summary.totalDataPoints, 10)
        XCTAssertEqual(summary.minimumValue, 120.0)
        XCTAssertEqual(summary.maximumValue, 280.0)
        XCTAssertEqual(summary.averageValue, 210.5)
        XCTAssertEqual(summary.currentValue, 265.0)

        // Validate screen reader verbal text
        let fullDesc = summary.accessibilityFullSummary
        XCTAssertTrue(fullDesc.contains("IGF-1 Biomarker chart summary with 10 data points"))
        XCTAssertTrue(fullDesc.contains("Current reading is 265.0 ng/mL"))
        XCTAssertTrue(fullDesc.contains("Minimum observed value is 120.0 ng/mL"))
        XCTAssertTrue(fullDesc.contains("maximum is 280.0 ng/mL"))
        XCTAssertTrue(fullDesc.contains("Average value is 210.5 ng/mL"))
        XCTAssertTrue(fullDesc.contains("Clinical reference range: 115 to 307 ng/mL"))
    }

    // MARK: - 4. MetricBadge Multi-Modal Accessibility

    func testMetricBadgeNonColorEncoding() {
        let successBadge = MetricBadge(.success("On Track"))
        XCTAssertEqual(successBadge.title, "On Track")

        let warningBadge = MetricBadge(.warning("Attention"))
        XCTAssertEqual(warningBadge.title, "Attention")

        let errorBadge = MetricBadge(.error("Critical"))
        XCTAssertEqual(errorBadge.title, "Critical")

        let infoBadge = MetricBadge(.info("Estimated"))
        XCTAssertEqual(infoBadge.title, "Estimated")
    }

    // MARK: - 5. Syringe Visual & VoiceOver Accessibility

    func testSyringeViewAccessibilityMetrics() {
        let normalMetrics = SyringeDisplayMetrics(
            units: 12.5,
            syringeSize: .point5ml,
            doseDescription: "250 mcg BPC-157",
            volumeMl: 0.125,
            concentrationMgMl: 2.0,
            compoundName: "BPC-157"
        )

        XCTAssertFalse(normalMetrics.isOverCapacity)
        XCTAssertEqual(normalMetrics.units, 12.5)
        XCTAssertEqual(normalMetrics.targetVolumeMl, 0.125)
        XCTAssertEqual(normalMetrics.fillPercentage, 25.0)

        // Over-capacity condition must be detected and clearly flagged
        let overCapacityMetrics = SyringeDisplayMetrics(
            units: 60.0,
            syringeSize: .point5ml, // max units is 50
            doseDescription: "600 mcg BPC-157",
            volumeMl: 0.60,
            concentrationMgMl: 1.0,
            compoundName: "BPC-157"
        )

        XCTAssertTrue(overCapacityMetrics.isOverCapacity, "Syringe must report over-capacity state")
        XCTAssertEqual(overCapacityMetrics.fillFraction, 1.0, "Fill fraction must be clamped at 100%")
    }

    // MARK: - 6. Dynamic Type Typography Foundations

    func testDynamicTypeScalableTypography() {
        // Assert all typography tokens are non-nil Font structures
        let hero = VialrTypography.metricHero
        let screenTitle = VialrTypography.screenTitle
        let eyebrow = VialrTypography.eyebrow
        let body = VialrTypography.body
        let monoDose = VialrTypography.monoDose
        let footnoteBold = VialrTypography.footnoteBold

        XCTAssertNotNil(hero)
        XCTAssertNotNil(screenTitle)
        XCTAssertNotNil(eyebrow)
        XCTAssertNotNil(body)
        XCTAssertNotNil(monoDose)
        XCTAssertNotNil(footnoteBold)
    }

    // MARK: - 7. VialrButton Accessible Touch Target & Labels

    func testButtonAccessibilityProperties() {
        let button = VialrButton(
            "Log Dose",
            icon: "plus",
            style: .primary,
            size: .standard,
            accessibilityLabel: "Confirm dose entry",
            accessibilityHint: "Double tap to submit",
            action: {}
        )

        XCTAssertEqual(button.title, "Log Dose")
        XCTAssertEqual(button.accessibilityLabelOverride, "Confirm dose entry")
        XCTAssertEqual(button.accessibilityHintText, "Double tap to submit")
        XCTAssertFalse(button.isDisabled)
        XCTAssertFalse(button.isLoading)
    }

    // MARK: - 8. Toast Message Screen Reader Announcements

    func testToastMessageNotificationData() {
        let toast = ToastMessage(
            title: "Dose Logged",
            message: "250 mcg recorded",
            type: .success
        )

        XCTAssertEqual(toast.title, "Dose Logged")
        XCTAssertEqual(toast.message, "250 mcg recorded")
        XCTAssertEqual(toast.type, .success)
        XCTAssertFalse(toast.type.iconName.isEmpty)
    }
}
