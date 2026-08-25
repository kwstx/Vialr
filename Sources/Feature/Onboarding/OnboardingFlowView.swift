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
                    Text("\(viewModel.currentStepIndex + 1) of \(viewModel.totalSteps)")
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
                        viewModel.currentStepIndex == viewModel.totalSteps - 1 ? "Complete Setup & Launch" : "Continue",
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
            step0Goals
        case 1:
            step1Experience
        case 2:
            step2Compounds
        case 3:
            step3AdministrationRoute
        case 4:
            step4TimeOfDay
        case 5:
            step5Syringes
        case 6:
            step6SiteRotation
        case 7:
            step7HealthKit
        case 8:
            step8Notifications
        case 9:
            step9UnitPreferences
        case 10:
            step10BlueprintSummary
        default:
            EmptyView()
        }
    }

    // MARK: - Step 0: Goals
    private var step0Goals: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "PRIMARY OBJECTIVE",
                title: "What are your main tracking goals?",
                subtitle: "Select all areas you are focusing on for this protocol."
            )

            let goals = [
                ("Recovery & Injury Repair", "cross.case.fill", "Tendons, joints, surgery, tissue healing"),
                ("Metabolic & Body Composition", "flame.fill", "Fat loss, insulin sensitivity, GLP-1"),
                ("Longevity & Vitality", "waveform.path.ecg", "Cellular rejuvenation, mitochondrial health"),
                ("Cognitive & Nootropic", "brain.head.profile", "Focus, sleep architecture, mental clarity"),
                ("Anti-Aging & Collagen", "sparkles", "Skin elasticity, hair, extracellular matrix")
            ]

            ForEach(goals, id: \.0) { goal in
                let isSelected = viewModel.selectedGoals.contains(goal.0)
                selectableCard(
                    title: goal.0,
                    subtitle: goal.2,
                    icon: goal.1,
                    isSelected: isSelected
                ) {
                    viewModel.toggleGoal(goal.0)
                }
            }
        }
    }

    // MARK: - Step 1: Experience
    private var step1Experience: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "EXPERIENCE LEVEL",
                title: "How experienced are you with peptides?",
                subtitle: "We'll tailor dosing calculators, alerts, and guided instructions accordingly."
            )

            let levels = [
                ("First-Time Beginner", "circle.badge.questionmark", "Need step-by-step reconstitution math & site rotation guidance"),
                ("Intermediate (1–2 cycles)", "chart.bar.fill", "Familiar with SubQ injections, wanting consolidated records"),
                ("Advanced Biohacker / Pro", "bolt.shield.fill", "Managing multi-compound stacks, bloodwork, and half-life clearance")
            ]

            ForEach(levels, id: \.0) { level in
                selectableCard(
                    title: level.0,
                    subtitle: level.2,
                    icon: level.1,
                    isSelected: viewModel.experienceLevel == level.0
                ) {
                    viewModel.experienceLevel = level.0
                }
            }
        }
    }

    // MARK: - Step 2: Compounds
    private var step2Compounds: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "COMPOUNDS OF INTEREST",
                title: "Which compounds are you planning to track?",
                subtitle: "Select active or planned peptides for your initial dashboard."
            )

            let items = [
                ("BPC-157", "Recovery / Healing"),
                ("TB-500", "Systemic Tissue Repair"),
                ("Tirzepatide", "Metabolic / GLP-1"),
                ("CJC-1295 / Ipamorelin", "GH Secretagogue"),
                ("GHK-Cu", "Collagen & Skin Remodeling"),
                ("NAD+", "Mitochondrial Cellular Energy"),
                ("Semaglutide", "Metabolic / Appetite")
            ]

            ForEach(items, id: \.0) { item in
                let isSelected = viewModel.selectedCompounds.contains(item.0)
                selectableCard(
                    title: item.0,
                    subtitle: item.1,
                    icon: "pills.fill",
                    isSelected: isSelected
                ) {
                    viewModel.toggleCompound(item.0)
                }
            }
        }
    }

    // MARK: - Step 3: Route
    private var step3AdministrationRoute: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "ADMINISTRATION ROUTE",
                title: "What is your primary route of administration?",
                subtitle: "Determines syringe visuals, needle sizes, and site rotation maps."
            )

            ForEach(AdministrationRoute.allCases) { route in
                selectableCard(
                    title: route.rawValue,
                    subtitle: route == .subcutaneous ? "Pinched skin in abdomen, thighs, or deltoids" : "Deep muscle or oral/nasal delivery",
                    icon: "syringe.fill",
                    isSelected: viewModel.primaryAdministrationRoute == route
                ) {
                    viewModel.primaryAdministrationRoute = route
                }
            }
        }
    }

    // MARK: - Step 4: Time of Day
    private var step4TimeOfDay: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "DAILY TIMING",
                title: "When do you typically take your doses?",
                subtitle: "We'll set smart reminder notifications around your daily rhythm."
            )

            ForEach(TimeOfDay.allCases) { slot in
                selectableCard(
                    title: slot.rawValue,
                    subtitle: "Scheduled reminder slot",
                    icon: slot.iconName,
                    isSelected: viewModel.preferredDoseTime == slot
                ) {
                    viewModel.preferredDoseTime = slot
                }
            }
        }
    }

    // MARK: - Step 5: Syringes
    private var step5Syringes: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "SYRINGE HARDWARE",
                title: "Which syringes do you use most often?",
                subtitle: "Configures default unit tick markings on the interactive calculator."
            )

            let types = [
                ("U-100 Insulin Syringe (0.3 mL)", "Best for micro-dosing up to 30 units"),
                ("U-100 Insulin Syringe (0.5 mL)", "Standard standard size up to 50 units"),
                ("U-100 Insulin Syringe (1.0 mL)", "High volume doses up to 100 units"),
                ("Luer-Lock 3 mL Syringe", "Reconstitution & mixing with diluent")
            ]

            ForEach(types, id: \.0) { type in
                selectableCard(
                    title: type.0,
                    subtitle: type.1,
                    icon: "syringe",
                    isSelected: viewModel.defaultSyringeType == type.0
                ) {
                    viewModel.defaultSyringeType = type.0
                }
            }
        }
    }

    // MARK: - Step 6: Site Rotation
    private var step6SiteRotation: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "TISSUE HEALTH",
                title: "Enable automated injection site rotation?",
                subtitle: "Rotates between 4 abdominal quadrants, thighs, and deltoids to prevent scar tissue."
            )

            selectableCard(
                title: "Enable Smart Site Rotation (Recommended)",
                subtitle: "Vialr automatically prompts the optimal rested site with heat map indicators.",
                icon: "arrow.triangle.2.circlepath.circle.fill",
                isSelected: viewModel.enableSiteRotationReminders
            ) {
                viewModel.enableSiteRotationReminders = true
            }

            selectableCard(
                title: "Manual Site Selection",
                subtitle: "Choose injection site manually every time without automated rotation suggestions.",
                icon: "hand.tap.fill",
                isSelected: !viewModel.enableSiteRotationReminders
            ) {
                viewModel.enableSiteRotationReminders = false
            }
        }
    }

    // MARK: - Step 7: HealthKit
    private var step7HealthKit: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "APPLE HEALTH INTEGRATION",
                title: "Connect Apple Health for automated biometric sync?",
                subtitle: "Correlate compound dosing with resting heart rate, HRV, weight, and blood glucose."
            )

            selectableCard(
                title: "Connect Apple Health",
                subtitle: "Sync weight, resting HR, HRV, sleep metrics, and fasting glucose in the background.",
                icon: "heart.fill",
                isSelected: viewModel.enableAppleHealthSync
            ) {
                viewModel.enableAppleHealthSync = true
            }

            selectableCard(
                title: "Skip for Now",
                subtitle: "You can manually enter bloodwork and vitals at any time.",
                icon: "xmark.circle",
                isSelected: !viewModel.enableAppleHealthSync
            ) {
                viewModel.enableAppleHealthSync = false
            }
        }
    }

    // MARK: - Step 8: Notifications
    private var step8Notifications: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "DOSE REMINDERS",
                title: "Never miss a scheduled dose",
                subtitle: "Receive discreet, actionable reminders when your next administration is due."
            )

            DatePicker(
                "Preferred Reminder Time",
                selection: $viewModel.reminderTime,
                displayedComponents: .hourAndMinute
            )
            .padding(VialrSpacing.md)
            .vialrCard()

            selectableCard(
                title: "Enable Dose Reminders & Restock Alerts",
                subtitle: "Alerts for upcoming doses and low vial inventory.",
                icon: "bell.badge.fill",
                isSelected: viewModel.enablePushNotifications
            ) {
                viewModel.enablePushNotifications = true
            }
        }
    }

    // MARK: - Step 9: Unit Preferences
    private var step9UnitPreferences: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "MEASUREMENT UNITS",
                title: "Select your preferred dose unit",
                subtitle: "Can be changed per compound at any time."
            )

            ForEach(DoseUnit.allCases) { unit in
                selectableCard(
                    title: unit.displayName,
                    subtitle: "Default display unit on dashboards and logs",
                    icon: "scalemass.fill",
                    isSelected: viewModel.preferredUnit == unit
                ) {
                    viewModel.preferredUnit = unit
                }
            }
        }
    }

    // MARK: - Step 10: Blueprint Summary
    private var step10BlueprintSummary: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            header(
                tag: "YOUR CUSTOM PROTOCOL BLUEPRINT",
                title: "Your Vialr dashboard is ready",
                subtitle: "We configured your personalized tracking suite based on your selections."
            )

            VStack(alignment: .leading, spacing: 14) {
                summaryRow(title: "Primary Compounds", value: viewModel.selectedCompounds.joined(separator: ", "))
                summaryRow(title: "Default Syringe", value: viewModel.defaultSyringeType)
                summaryRow(title: "Preferred Route", value: viewModel.primaryAdministrationRoute.shortName)
                summaryRow(title: "Site Rotation", value: viewModel.enableSiteRotationReminders ? "Active (4 Quadrant)" : "Manual")
                summaryRow(title: "Biometrics Sync", value: viewModel.enableAppleHealthSync ? "Apple Health Connected" : "Manual")
            }
            .padding(VialrSpacing.md)
            .vialrCard()
        }
    }

    // MARK: - Helpers
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

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(VialrTypography.subheadline)
                .foregroundColor(VialrColors.textSecondary)
            Spacer()
            Text(value)
                .font(VialrTypography.headline)
                .foregroundColor(VialrColors.accentEmerald)
        }
    }
}
