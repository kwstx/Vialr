import SwiftUI
import Observation
import Domain
import DesignSystem

public struct OnboardingFlowView: View {
    @Bindable public var viewModel: OnboardingViewModel
    public var onFinish: () -> Void

    public init(viewModel: OnboardingViewModel, onFinish: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            VialrColors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Progress Bar & Back button
                HStack {
                    if viewModel.currentStepIndex > 0 && !viewModel.isComplete {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.previousStep()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(VialrColors.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(VialrColors.cardSurfaceElevated)
                                .clipShape(Circle())
                        }
                    } else {
                        Spacer().frame(width: 40)
                    }

                    Spacer()

                    // Step indicator
                    Text("Question \(viewModel.currentStepIndex + 1) of \(viewModel.totalSteps)")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textTertiary)

                    Spacer()

                    Spacer().frame(width: 40)
                }
                .padding(.horizontal, VialrSpacing.lg)
                .padding(.top, VialrSpacing.sm)

                // Progress line
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(VialrColors.cardSurfaceElevated)
                            .frame(height: 4)

                        Capsule()
                            .fill(VialrColors.primaryGradient)
                            .frame(width: geo.size.width * CGFloat(viewModel.currentStepIndex + 1) / CGFloat(viewModel.totalSteps), height: 4)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.currentStepIndex)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, VialrSpacing.lg)
                .padding(.top, VialrSpacing.sm)

                // Dynamic Step Content
                ScrollView {
                    VStack(alignment: .leading, spacing: VialrSpacing.lg) {
                        stepContent
                    }
                    .padding(.horizontal, VialrSpacing.lg)
                    .padding(.vertical, VialrSpacing.xl)
                }

                Spacer()

                // Bottom Action Bar
                VStack(spacing: VialrSpacing.xs) {
                    VialrButton(
                        viewModel.currentStepIndex == viewModel.totalSteps - 1 ? "Complete Setup & Create Account" : "Continue",
                        icon: viewModel.currentStepIndex == viewModel.totalSteps - 1 ? "sparkles" : "arrow.right",
                        style: .primary
                    ) {
                        if viewModel.currentStepIndex == viewModel.totalSteps - 1 {
                            onFinish()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.nextStep()
                            }
                        }
                    }
                }
                .padding(.horizontal, VialrSpacing.lg)
                .padding(.bottom, VialrSpacing.lg)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStepIndex {
        case 0:
            step1Category
        case 1:
            step2Goals
        case 2:
            step3CompoundCount
        case 3:
            step4DosingSchedule
        case 4:
            step5FeaturesToStayOnTop
        case 5:
            step6ProgressFrequency
        case 6:
            step7Bloodwork
        case 7:
            step8DoseTrackingMethod
        case 8:
            step9CalculationImportance
        case 9:
            step10InjectionSites
        case 10:
            step11AppleHealth
        case 11:
            step12KeyBenefits
        default:
            EmptyView()
        }
    }

    // MARK: - Step 1: What are you looking to track?
    private var step1Category: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "COMPOUND FOCUS",
                title: "What are you looking to track?",
                subtitle: "Vialr supports universal tracking across all compound categories."
            )

            let options = [
                ("Peptides", "BPC-157, TB-500, CJC/Ipam, GHK-Cu, etc.", "cross.case.fill"),
                ("GLP-1 medications", "Tirzepatide, Semaglutide, Retatrutide", "flame.fill"),
                ("TRT / hormones", "Testosterone, HCG, DHEA, Progesterone", "bolt.shield.fill"),
                ("Supplements", "NAD+, Glutathione, Vitamin B12, Amino stacks", "pills.fill"),
                ("Multiple types", "Combined protocols across multiple categories", "square.stack.3d.up.fill"),
                ("Something else", "Custom research & specialized compounds", "sparkles")
            ]

            ForEach(options, id: \.0) { item in
                selectableCard(
                    title: item.0,
                    subtitle: item.1,
                    icon: item.2,
                    isSelected: viewModel.primaryCategory == item.0
                ) {
                    viewModel.primaryCategory = item.0
                }
            }
        }
    }

    // MARK: - Step 2: What is your main goal? (Multi-select)
    private var step2Goals: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "PRIMARY OBJECTIVES",
                title: "What is your main goal?",
                subtitle: "Select all that apply to tailor your analytics and outcomes."
            )

            let goals = [
                ("Weight management", "Appetite control, caloric pacing & weight trends", "scalemass.fill"),
                ("Body composition", "Lean mass retention & adipose reduction", "figure.strengthtraining.traditional"),
                ("Performance", "Endurance, strength & output metrics", "bolt.fill"),
                ("Recovery", "Tendon repair, muscle healing & inflammation", "cross.case.fill"),
                ("Energy", "Cellular mitochondria & daily vitality", "battery.100.bolt"),
                ("General wellness", "Overall longevity & biomarker balance", "heart.fill"),
                ("Other", "Specialized focus or personal protocol", "ellipsis.circle.fill")
            ]

            ForEach(goals, id: \.0) { goal in
                let isSelected = viewModel.selectedGoals.contains(goal.0)
                multiSelectCard(
                    title: goal.0,
                    subtitle: goal.1,
                    icon: goal.2,
                    isSelected: isSelected
                ) {
                    viewModel.toggleGoal(goal.0)
                }
            }
        }
    }

    // MARK: - Step 3: How many compounds are you currently tracking?
    private var step3CompoundCount: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "PROTOCOL COMPLEXITY",
                title: "How many compounds are you currently tracking?",
                subtitle: "This helps personalize your dashboard layout and quick actions."
            )

            let counts = [
                ("1", "Focused single compound regimen", "1.circle.fill"),
                ("2–3", "Moderate stack with shared schedules", "2.circle.fill"),
                ("4–5", "Advanced protocol with multiple timings", "4.circle.fill"),
                ("6+", "Full biohacking stack & comprehensive regimen", "plus.circle.fill")
            ]

            ForEach(counts, id: \.0) { item in
                selectableCard(
                    title: item.0,
                    subtitle: item.1,
                    icon: item.2,
                    isSelected: viewModel.compoundCountRange == item.0
                ) {
                    viewModel.compoundCountRange = item.0
                }
            }
        }
    }

    // MARK: - Step 4: Are you currently following a dosing schedule?
    private var step4DosingSchedule: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "SCHEDULE & ROUTINE",
                title: "Are you currently following a dosing schedule?",
                subtitle: "Determines whether to guide you toward protocol creation or tracking."
            )

            let schedules = [
                ("Yes, consistently", "Established routine with set days & times", "checkmark.seal.fill"),
                ("Yes, but it’s inconsistent", "Following a plan but often shift or miss doses", "clock.badge.exclamationmark.fill"),
                ("No", "Taking doses ad-hoc or as needed", "hand.raised.fill"),
                ("I’m just getting started", "Setting up a first protocol from scratch", "sparkles")
            ]

            ForEach(schedules, id: \.0) { item in
                selectableCard(
                    title: item.0,
                    subtitle: item.1,
                    icon: item.2,
                    isSelected: viewModel.dosingScheduleStatus == item.0
                ) {
                    viewModel.dosingScheduleStatus = item.0
                }
            }
        }
    }

    // MARK: - Step 5: What do you want the app to help you stay on top of? (Multi-select)
    private var step5FeaturesToStayOnTop: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "KEY PRIORITIES",
                title: "What do you want the app to help you stay on top of?",
                subtitle: "Select the core tools you want front-and-center."
            )

            let features = [
                ("Doses", "Smart reminders & one-tap logging", "calendar.badge.clock"),
                ("Results", "Subjective notes, symptom trends & photos", "chart.xyaxis.line"),
                ("Bloodwork", "Biomarker panels, lab imports & clinician PDFs", "waveform.path.ecg"),
                ("Reconstitution", "Exact diluent math, mcg/unit syringe calculations", "function"),
                ("Injection sites", "Automated 4-quadrant rotation & scar prevention", "arrow.triangle.2.circlepath"),
                ("Inventory", "Vial volume depletion & low supply warnings", "cylinder.split.1x2.fill"),
                ("Costs", "Financial tracking per compound & month", "dollarsign.circle.fill"),
                ("Everything", "All-in-one comprehensive protocol command center", "star.circle.fill")
            ]

            ForEach(features, id: \.0) { feature in
                let isSelected = viewModel.featuresToStayOnTop.contains(feature.0)
                multiSelectCard(
                    title: feature.0,
                    subtitle: feature.1,
                    icon: feature.2,
                    isSelected: isSelected
                ) {
                    viewModel.toggleFeatureToStayOnTop(feature.0)
                }
            }
        }
    }

    // MARK: - Step 6: How often do you want to track your progress?
    private var step6ProgressFrequency: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "CHECK-IN CADENCE",
                title: "How often do you want to track your progress?",
                subtitle: "Determines measurement reminders and check-in cadence."
            )

            let frequencies = [
                ("Daily", "Daily morning or evening check-in prompts", "sun.max.fill"),
                ("A few times per week", "Mid-week & weekend milestone checks", "calendar.day.timeline.left"),
                ("Weekly", "Sunday weekly protocol review & summary", "calendar"),
                ("Monthly", "Long-term trend analysis & cycle replays", "chart.bar.xaxis"),
                ("Only when I choose", "On-demand manual logging without prompts", "hand.tap.fill")
            ]

            ForEach(frequencies, id: \.0) { item in
                selectableCard(
                    title: item.0,
                    subtitle: item.1,
                    icon: item.2,
                    isSelected: viewModel.progressTrackingFrequency == item.0
                ) {
                    viewModel.progressTrackingFrequency = item.0
                }
            }
        }
    }

    // MARK: - Step 7: Do you currently track your bloodwork somewhere?
    private var step7Bloodwork: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "LABORATORY & BIOMARKERS",
                title: "Do you currently track your bloodwork somewhere?",
                subtitle: "Correlate biomarker shifts directly with your protocol timeline."
            )

            let options = [
                ("Yes", "Organized records ready for tracking", "doc.text.fill"),
                ("No", "Haven't logged baseline lab markers yet", "xmark.circle.fill"),
                ("I have lab reports but they’re scattered", "PDFs and portal screenshots that need consolidating", "folder.badge.questionmark"),
                ("I want to start tracking it", "Planning upcoming lab panels for protocol safety", "plus.magnifyingglass")
            ]

            ForEach(options, id: \.0) { item in
                selectableCard(
                    title: item.0,
                    subtitle: item.1,
                    icon: item.2,
                    isSelected: viewModel.bloodworkTrackingStatus == item.0
                ) {
                    viewModel.bloodworkTrackingStatus = item.0
                }
            }
        }
    }

    // MARK: - Step 8: How do you currently keep track of your doses?
    private var step8DoseTrackingMethod: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "CURRENT WORKFLOW",
                title: "How do you currently keep track of your doses?",
                subtitle: "We make migrating your current routine seamless."
            )

            let methods = [
                ("Another app", "Switching from a generic reminder app", "app.badge.fill"),
                ("Notes", "Apple Notes or text drafts", "note.text"),
                ("Spreadsheet", "Excel or Google Sheets formulas", "tablecells.fill"),
                ("Calendar/reminders", "Default iOS reminders or calendar alerts", "bell.badge.fill"),
                ("I don’t track them", "Dosing without formal records", "slash.circle.fill"),
                ("I just remember", "Relying on mental memory", "brain.fill")
            ]

            ForEach(methods, id: \.0) { item in
                selectableCard(
                    title: item.0,
                    subtitle: item.1,
                    icon: item.2,
                    isSelected: viewModel.doseTrackingMethod == item.0
                ) {
                    viewModel.doseTrackingMethod = item.0
                }
            }
        }
    }

    // MARK: - Step 9: How important is automatic dose calculation to you?
    private var step9CalculationImportance: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "DOSING CALCULATOR",
                title: "How important is automatic dose calculation to you?",
                subtitle: "Reconstitution math, diluent volumes, and syringe tick conversions."
            )

            let options = [
                ("Essential", "Must have exact tick marks & reconstitution math", "sparkles.rectangle.stack.fill"),
                ("Very useful", "Great for verifying concentration and unit scales", "checkmark.circle.fill"),
                ("Nice to have", "Helpful occasional reference", "hand.thumbsup.fill"),
                ("I don’t need it", "Already know exact volumes and draw amounts", "minus.circle.fill")
            ]

            ForEach(options, id: \.0) { item in
                selectableCard(
                    title: item.0,
                    subtitle: item.1,
                    icon: item.2,
                    isSelected: viewModel.calculationImportance == item.0
                ) {
                    viewModel.calculationImportance = item.0
                }
            }
        }
    }

    // MARK: - Step 10: Would you like to track your injection sites?
    private var step10InjectionSites: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "TISSUE HEALTH & ROTATION",
                title: "Would you like to track your injection sites?",
                subtitle: "Prevents tissue fatigue, bruising, and scar tissue via smart rotation."
            )

            let options = [
                ("Yes", "Enable smart rotation across abdomen, thighs, & deltoids", "arrow.triangle.2.circlepath.circle.fill"),
                ("No", "Manual ad-hoc injection site logging only", "xmark.circle"),
                ("Not sure", "We will enable gentle suggestions you can toggle anytime", "questionmark.circle")
            ]

            ForEach(options, id: \.0) { item in
                selectableCard(
                    title: item.0,
                    subtitle: item.1,
                    icon: item.2,
                    isSelected: viewModel.injectionSiteTracking == item.0
                ) {
                    viewModel.injectionSiteTracking = item.0
                }
            }
        }
    }

    // MARK: - Step 11: Would you like to connect Apple Health?
    private var step11AppleHealth: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "BIOMETRICS INTEGRATION",
                title: "Would you like to connect Apple Health?",
                subtitle: "Correlate compound dosing with resting heart rate, HRV, weight, and blood glucose."
            )

            let options = [
                ("Yes", "Automatically sync weight, HRV, resting HR, and glucose", "heart.fill"),
                ("Maybe later", "Explore the app first before connecting data", "clock.arrow.circlepath"),
                ("No", "Keep protocol tracking independent of Apple Health", "shield.slash.fill")
            ]

            ForEach(options, id: \.0) { item in
                selectableCard(
                    title: item.0,
                    subtitle: item.1,
                    icon: item.2,
                    isSelected: viewModel.appleHealthPreference == item.0
                ) {
                    viewModel.appleHealthPreference = item.0
                }
            }

            // Explanatory note
            HStack(alignment: .top, spacing: VialrSpacing.xs) {
                Image(systemName: "info.circle")
                    .foregroundColor(VialrColors.textTertiary)
                    .font(.footnote)
                Text("We will explain specific HealthKit permissions and request system access after account setup.")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }
            .padding(.top, VialrSpacing.xs)
        }
    }

    // MARK: - Step 12: What would make this app most valuable to you? (Multi-select)
    private var step12KeyBenefits: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "YOUR VALUE PRIORITIES",
                title: "What would make this app most valuable to you?",
                subtitle: "Select everything you expect Vialr to solve for your journey."
            )

            let benefits = [
                ("Never forget a dose", "Timely, discreet actionable reminders", "bell.fill"),
                ("Understand my results", "Correlate compound schedules with biomarker trends", "chart.line.uptrend.xyaxis"),
                ("Keep my bloodwork organized", "Structured lab panels and clinician export summaries", "doc.plaintext.fill"),
                ("Get my dosing math right", "Zero-error reconstitution & interactive syringe guides", "function"),
                ("Track my inventory", "Remaining vial volume & low supply depletion alerts", "cylinder.split.1x2"),
                ("Compare protocols", "Evaluate before-and-after protocol cycles longitudinally", "arrow.left.arrow.right"),
                ("Keep everything in one place", "One secure, private home for your entire protocol", "lock.shield.fill")
            ]

            ForEach(benefits, id: \.0) { benefit in
                let isSelected = viewModel.keyValuedBenefits.contains(benefit.0)
                multiSelectCard(
                    title: benefit.0,
                    subtitle: benefit.1,
                    icon: benefit.2,
                    isSelected: isSelected
                ) {
                    viewModel.toggleBenefit(benefit.0)
                }
            }
        }
    }

    // MARK: - Header Component
    private func header(tag: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tag)
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)
            Text(title)
                .font(VialrTypography.title1)
                .foregroundColor(VialrColors.textPrimary)
            Text(subtitle)
                .font(VialrTypography.body)
                .foregroundColor(VialrColors.textSecondary)
        }
        .padding(.bottom, VialrSpacing.xs)
    }

    // MARK: - Single-Select Card
    private func selectableCard(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            action()
        }) {
            HStack(spacing: VialrSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? VialrColors.accentTeal : VialrColors.textTertiary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)

                    Text(subtitle)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? VialrColors.accentTeal : VialrColors.textTertiary)
            }
            .padding(VialrSpacing.md)
            .vialrCard(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Multi-Select Card
    private func multiSelectCard(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            action()
        }) {
            HStack(spacing: VialrSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? VialrColors.accentTeal : VialrColors.textTertiary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)

                    Text(subtitle)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? VialrColors.accentTeal : VialrColors.textTertiary)
            }
            .padding(VialrSpacing.md)
            .vialrCard(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}
