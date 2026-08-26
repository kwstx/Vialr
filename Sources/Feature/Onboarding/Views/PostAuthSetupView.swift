import SwiftUI
import Domain
import Health
import DesignSystem

/// The first-run setup wizard displayed immediately after user signup:
/// 1. First Protocol Prompt: Ask whether they want to create their first protocol
/// 2. Add Compound: Select from catalog or create custom + planned dose
/// 3. Configure Schedule: Dosing cadence, routine, start date, and time of day
/// 4. Optionally Add Vial: Reconstitution math, liquid draw volume, syringe tick units
/// 5. Configure Reminders: Scheduled alert times, lead times, low-stock warnings
/// 6. Optionally Connect HealthKit: Apple Health biometrics integration
/// 7. "You're Ready": Summary verification and dashboard launch with real data
public struct PostAuthSetupView: View {
    @Bindable public var viewModel: PostAuthSetupViewModel
    public let authenticatedUser: User
    public var onSetupComplete: (User) -> Void

    public init(
        viewModel: PostAuthSetupViewModel,
        authenticatedUser: User,
        onSetupComplete: @escaping (User) -> Void
    ) {
        self.viewModel = viewModel
        self.authenticatedUser = authenticatedUser
        self.onSetupComplete = onSetupComplete
    }

    public var body: some View {
        ZStack {
            VialrColors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Progress Bar & Back button
                topNavBar
                    .padding(.horizontal, VialrSpacing.lg)
                    .padding(.top, VialrSpacing.xs)

                // Step content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: VialrSpacing.lg) {
                        stepHeader

                        stepCardContent
                    }
                    .padding(.horizontal, VialrSpacing.lg)
                    .padding(.vertical, VialrSpacing.md)
                }

                Spacer(minLength: VialrSpacing.xs)

                // Bottom Action Button
                bottomActionBar
                    .padding(.horizontal, VialrSpacing.lg)
                    .padding(.bottom, VialrSpacing.lg)
            }
        }
        .sheet(isPresented: $viewModel.isShowingCustomCompoundSheet) {
            customCompoundSheet
        }
    }

    // MARK: - Top Nav Bar
    private var topNavBar: some View {
        HStack {
            if viewModel.currentStepIndex > 0 && viewModel.currentStep != .ready {
                Button {
                    viewModel.previousStep()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(VialrColors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(VialrColors.cardSurfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous Step")
            } else {
                Spacer().frame(width: 36)
            }

            Spacer()

            Text(viewModel.currentStep.stepTag)
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentVitality)
                .tracking(1.5)

            Spacer()

            Spacer().frame(width: 36)
        }
        .frame(height: 44)
    }

    // MARK: - Step Header
    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.currentStep.title)
                .font(VialrTypography.largeHero)
                .foregroundColor(VialrColors.textPrimary)

            Text(viewModel.currentStep.subtitle)
                .font(VialrTypography.body)
                .foregroundColor(VialrColors.textSecondary)
                .lineSpacing(3)
        }
        .padding(.bottom, VialrSpacing.xs)
    }

    // MARK: - Dynamic Step Content
    @ViewBuilder
    private var stepCardContent: some View {
        switch viewModel.currentStep {
        case .firstProtocolPrompt:
            firstProtocolPromptStepView
        case .compound:
            compoundStepView
        case .schedule:
            scheduleStepView
        case .vial:
            vialStepView
        case .reminders:
            remindersStepView
        case .healthKit:
            healthKitStepView
        case .ready:
            readyStepView
        }
    }

    // MARK: - Step 1: First Protocol Prompt
    private var firstProtocolPromptStepView: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            // Option A: Create Custom Protocol
            choiceCard(
                title: "Create My First Protocol",
                subtitle: "Configure your compound, target dose, and schedule from scratch.",
                icon: "plus.circle.fill",
                badge: "Recommended",
                isSelected: viewModel.firstProtocolChoice == .createCustom
            ) {
                viewModel.chooseCreateCustomProtocol()
            }

            // Option B: Pick a Starter Template
            VStack(alignment: .leading, spacing: VialrSpacing.xs) {
                Text("OR START WITH A PROVEN TEMPLATE")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textTertiary)
                    .tracking(1.2)
                    .padding(.top, 4)

                ForEach(viewModel.starterTemplates) { template in
                    let isSelected = viewModel.selectedTemplateId == template.id
                    Button {
                        viewModel.selectTemplate(template)
                    } label: {
                        HStack(spacing: VialrSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                                    .frame(width: 40, height: 40)
                                Image(systemName: template.iconName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(isSelected ? Color.black : VialrColors.accentVitality)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(template.title)
                                        .font(VialrTypography.headline)
                                        .foregroundColor(VialrColors.textPrimary)
                                    Spacer()
                                    MetricBadge(.custom(title: template.badgeText, color: VialrColors.accentVitality, icon: nil))
                                }

                                Text(template.subtitle)
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard(isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Option C: Skip Protocol Creation
            Button {
                viewModel.chooseSkipProtocol()
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(VialrColors.textTertiary)
                    Text("I'll set up my protocols later")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                    Spacer()
                }
                .padding(VialrSpacing.md)
                .vialrCard(isSelected: viewModel.firstProtocolChoice == .skipForNow)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Step 2: Compound & Planned Dose
    private var compoundStepView: some View {
        VStack(spacing: VialrSpacing.md) {
            // Search Bar
            VialrInputField(
                title: "",
                placeholder: "Search compound (e.g. BPC-157, Tirzepatide)",
                text: $viewModel.compoundSearchQuery,
                systemImage: "magnifyingglass"
            )

            // Compound Selection List
            VStack(spacing: 2) {
                ForEach(viewModel.filteredCompounds.prefix(5)) { compound in
                    let isSelected = viewModel.selectedCompound?.id == compound.id
                    Button {
                        viewModel.selectCompound(compound)
                        VialrHaptics.selection()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(compound.name)
                                    .font(VialrTypography.subheadline)
                                    .foregroundColor(isSelected ? VialrColors.accentVitality : VialrColors.textPrimary)
                                Text("\(compound.category.displayName) • Half-life: \(String(format: "%.1f", compound.halfLifeHours))h")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textTertiary)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(VialrColors.accentVitality)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, VialrSpacing.md)
                        .background(isSelected ? VialrColors.cardSurfaceSelected : VialrColors.cardSurface)
                    }
                    .buttonStyle(.plain)
                    Divider().background(VialrColors.glassBorder)
                }

                // Add Custom Compound Button
                Button {
                    viewModel.isShowingCustomCompoundSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(VialrColors.accentVitality)
                        Text("+ Create Custom Compound")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentVitality)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, VialrSpacing.md)
                    .background(VialrColors.cardSurfaceSubtle)
                }
                .buttonStyle(.plain)
            }
            .clipShape(RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous)
                    .stroke(VialrColors.glassBorder, lineWidth: 1)
            )

            // Planned Dose Configuration
            if let compound = viewModel.selectedCompound {
                VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                    Text("PLANNED DOSE & ROUTE FOR \(compound.name.uppercased())")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentVitality)

                    HStack(spacing: 12) {
                        // Dose Amount
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dose Amount")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)

                            HStack {
                                TextField("250", value: $viewModel.doseAmount, format: .number)
                                    .keyboardType(.decimalPad)
                                    .font(VialrTypography.headline)
                                    .foregroundColor(VialrColors.textPrimary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(VialrColors.cardSurfaceElevated)
                            .cornerRadius(VialrSpacing.radiusSm)
                        }

                        // Dose Unit Selector
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unit")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)

                            HStack(spacing: 4) {
                                ForEach([DoseUnit.mcg, DoseUnit.mg, DoseUnit.iu], id: \.self) { unit in
                                    Button {
                                        viewModel.doseUnit = unit
                                        VialrHaptics.selection()
                                    } label: {
                                        Text(unit.rawValue)
                                            .font(VialrTypography.captionBold)
                                            .foregroundColor(viewModel.doseUnit == unit ? Color.black : VialrColors.textSecondary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 10)
                                            .background(viewModel.doseUnit == unit ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                                            .cornerRadius(VialrSpacing.radiusSm)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Administration Route
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Delivery Route")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)

                        HStack(spacing: 8) {
                            ForEach([AdministrationRoute.subcutaneous, AdministrationRoute.intramuscular, AdministrationRoute.oral], id: \.self) { route in
                                Button {
                                    viewModel.selectedRoute = route
                                    VialrHaptics.selection()
                                } label: {
                                    Text(route.shortName)
                                        .font(VialrTypography.captionBold)
                                        .foregroundColor(viewModel.selectedRoute == route ? Color.black : VialrColors.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(viewModel.selectedRoute == route ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                                        .cornerRadius(VialrSpacing.radiusSm)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(VialrSpacing.md)
                .vialrCard(isSelected: true)
            }
        }
    }

    // MARK: - Step 3: Dosing Schedule
    private var scheduleStepView: some View {
        VStack(spacing: VialrSpacing.md) {
            // Frequency Type Selector
            VStack(alignment: .leading, spacing: VialrSpacing.xs) {
                Text("DOSING FREQUENCY")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentVitality)

                let frequencies: [(FrequencyType, String, String)] = [
                    (.daily, "Daily", "Administer every calendar day"),
                    (.everyOtherDay, "Every Other Day (EOD)", "Alternating 48-hour cadence"),
                    (.daysOfWeek, "Specific Days of Week", "e.g. Mon, Wed, Fri routine"),
                    (.cycle, "Cycle (On / Off)", "e.g. 5 days on, 2 days off"),
                    (.everyNDays, "Every N Days", "e.g. Once every 3 or 7 days")
                ]

                ForEach(frequencies, id: \.0) { item in
                    let isSelected = viewModel.frequencyType == item.0
                    Button {
                        viewModel.frequencyType = item.0
                        VialrHaptics.selection()
                    } label: {
                        HStack {
                            Image(systemName: item.0.iconName)
                                .font(.system(size: 16))
                                .foregroundColor(isSelected ? VialrColors.accentVitality : VialrColors.textTertiary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.1)
                                    .font(VialrTypography.headline)
                                    .foregroundColor(VialrColors.textPrimary)
                                Text(item.2)
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? VialrColors.accentVitality : VialrColors.textTertiary)
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard(isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Days of week selector if daysOfWeek is chosen
            if viewModel.frequencyType == .daysOfWeek {
                VStack(alignment: .leading, spacing: VialrSpacing.xs) {
                    Text("SELECT DOSING DAYS")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.textTertiary)

                    let days = [(2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")]
                    HStack(spacing: 8) {
                        ForEach(days, id: \.0) { d in
                            let isSelected = viewModel.selectedWeekdays.contains(d.0)
                            Button {
                                viewModel.toggleWeekday(d.0)
                            } label: {
                                Text(d.1)
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(isSelected ? Color.black : VialrColors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(isSelected ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(VialrSpacing.md)
                .vialrCard()
            }

            // Start Date Selector
            VStack(alignment: .leading, spacing: VialrSpacing.xs) {
                Text("PROTOCOL START DATE")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textTertiary)

                HStack(spacing: 8) {
                    ForEach([StartDateOption.today, StartDateOption.tomorrow], id: \.self) { opt in
                        unitPill(
                            title: opt.rawValue,
                            isSelected: viewModel.startDateOption == opt
                        ) {
                            viewModel.startDateOption = opt
                        }
                    }
                }
            }
            .padding(VialrSpacing.md)
            .vialrCard()
        }
    }

    // MARK: - Step 4: Optional Inventory Vial
    private var vialStepView: some View {
        VStack(spacing: VialrSpacing.md) {
            // Master Add Vial Toggle
            toggleCard(
                title: "Add Inventory Vial to Vault",
                subtitle: "Link a physical vial to auto-calculate draw volume and track volume depletion",
                icon: "cross.vial.fill",
                isOn: $viewModel.shouldAddVial
            )

            if viewModel.shouldAddVial {
                VStack(alignment: .leading, spacing: VialrSpacing.md) {
                    Text("RECONSTITUTION CONFIGURATION")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentVitality)

                    HStack(spacing: 12) {
                        // Total Dry Mass (mg)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dry Mass (mg)")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)

                            TextField("5.0", value: $viewModel.vialDryMassMg, format: .number)
                                .keyboardType(.decimalPad)
                                .font(VialrTypography.headline)
                                .foregroundColor(VialrColors.textPrimary)
                                .padding(10)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusSm)
                        }

                        // BAC Water Added (mL)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BAC Water (mL)")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)

                            TextField("2.0", value: $viewModel.vialBacWaterMl, format: .number)
                                .keyboardType(.decimalPad)
                                .font(VialrTypography.headline)
                                .foregroundColor(VialrColors.textPrimary)
                                .padding(10)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusSm)
                        }
                    }

                    // Live Calculated Concentration & Draw Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Solution Concentration:")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                            Spacer()
                            Text("\(String(format: "%.2f", viewModel.vialConcentrationMgMl)) mg/mL (\(String(format: "%.0f", viewModel.vialConcentrationMcgMl)) mcg/mL)")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentVitality)
                        }

                        HStack {
                            Text("Syringe Draw Mark:")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                            Spacer()
                            Text("\(String(format: "%.1f", viewModel.calculatedSyringeUnits)) Units on U-100 Syringe")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentCyan)
                        }

                        HStack {
                            Text("Yield / Capacity:")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                            Spacer()
                            Text("\(viewModel.estimatedDosesInVial) Planned Doses")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.textPrimary)
                        }
                    }
                    .padding(12)
                    .background(VialrColors.cardSurfaceSubtle)
                    .cornerRadius(VialrSpacing.radiusSm)
                    .overlay(
                        RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                            .stroke(VialrColors.accentVitality.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(VialrSpacing.md)
                .vialrCard()
            }
        }
    }

    // MARK: - Step 5: Smart Reminders
    private var remindersStepView: some View {
        VStack(spacing: VialrSpacing.md) {
            // Main Dose Reminders Toggle
            toggleCard(
                title: "Scheduled Dose Reminders",
                subtitle: "Discreet push notifications aligned with your protocol time",
                icon: "bell.badge.fill",
                isOn: $viewModel.enableDoseReminders
            )

            if viewModel.enableDoseReminders {
                // Reminder Lead Time Selector
                VStack(alignment: .leading, spacing: VialrSpacing.xs) {
                    Text("Reminder Lead Time")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.textTertiary)

                    HStack(spacing: 8) {
                        ForEach([0, 5, 15, 30, 60], id: \.self) { minutes in
                            let label = minutes == 0 ? "Exact time" : "\(minutes)m prior"
                            unitPill(
                                title: label,
                                isSelected: viewModel.reminderLeadTimeMinutes == minutes
                            ) {
                                viewModel.reminderLeadTimeMinutes = minutes
                            }
                        }
                    }
                }
                .padding(VialrSpacing.md)
                .vialrCard()

                // Request Permissions CTA
                VialrButton(
                    viewModel.notificationPermissionGranted ? "Push Notifications Armed" : "Enable iOS Push Notifications",
                    icon: viewModel.notificationPermissionGranted ? "checkmark.circle.fill" : "bell.fill",
                    style: viewModel.notificationPermissionGranted ? .secondary : .vitality,
                    size: .compact
                ) {
                    Task {
                        await viewModel.requestNotificationPermissions()
                    }
                }
            }

            // Low Stock Warnings
            toggleCard(
                title: "Low-Stock Depletion Warnings",
                subtitle: "Alerts when a vial drops below 2 doses or BAC water is low",
                icon: "cylinder.split.1x2.fill",
                isOn: $viewModel.enableRestockAlerts
            )

            // Daily Morning Summary
            toggleCard(
                title: "Daily Morning Protocol Summary",
                subtitle: "8:00 AM daily briefing of scheduled doses and active rotations",
                icon: "sun.max.fill",
                isOn: $viewModel.enableDailyMorningSummary
            )
        }
    }

    // MARK: - Step 6: Apple Health
    private var healthKitStepView: some View {
        VStack(spacing: VialrSpacing.md) {
            // Master Apple Health Toggle
            toggleCard(
                title: "Connect Apple Health",
                subtitle: "Correlate compound dosing with longitudinal biometrics",
                icon: "heart.fill",
                isOn: $viewModel.enableAppleHealth
            )

            if viewModel.enableAppleHealth {
                VStack(alignment: .leading, spacing: VialrSpacing.xs) {
                    Text("BIOMETRICS TO SYNC")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentVitality)

                    let metrics: [(HealthMetricType, String, String)] = [
                        (.weight, "Body Weight", "figure.walk"),
                        (.restingHeartRate, "Resting Heart Rate", "heart.fill"),
                        (.heartRateVariability, "Heart Rate Variability (HRV)", "waveform.path.ecg"),
                        (.bloodGlucose, "Blood Glucose", "drop.fill"),
                        (.sleepAnalysis, "Sleep Stages & Duration", "bed.double.fill")
                    ]

                    ForEach(metrics, id: \.0) { item in
                        let isSelected = viewModel.enabledHealthMetrics.contains(item.0)
                        Button {
                            viewModel.toggleHealthMetric(item.0)
                        } label: {
                            HStack(spacing: VialrSpacing.md) {
                                Image(systemName: item.2)
                                    .foregroundColor(isSelected ? VialrColors.accentVitality : VialrColors.textTertiary)
                                    .frame(width: 24)
                                Text(item.1)
                                    .font(VialrTypography.subheadline)
                                    .foregroundColor(VialrColors.textPrimary)
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                    .foregroundColor(isSelected ? VialrColors.accentVitality : VialrColors.textTertiary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(VialrSpacing.md)
                .vialrCard()

                // Permission Authorization Button
                VialrButton(
                    viewModel.healthAuthRequested ? "HealthKit Permissions Granted" : "Authorize Apple HealthKit",
                    icon: viewModel.healthAuthRequested ? "checkmark.seal.fill" : "heart.text.square.fill",
                    style: viewModel.healthAuthRequested ? .secondary : .vitality,
                    size: .compact
                ) {
                    Task {
                        await viewModel.requestHealthKitPermissions()
                    }
                }
            }
        }
    }

    // MARK: - Step 7: "You're Ready" Celebration & Verification
    private var readyStepView: some View {
        VStack(spacing: VialrSpacing.lg) {
            // Hero Status Badge
            ZStack {
                Circle()
                    .fill(VialrColors.accentVitality.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundColor(VialrColors.accentVitality)
            }

            VStack(spacing: 6) {
                Text("You’re ready.")
                    .font(VialrTypography.largeHero)
                    .foregroundColor(VialrColors.textPrimary)

                Text("Your protocol vault is prepared and scheduled with live tracking data.")
                    .font(VialrTypography.subheadline)
                    .foregroundColor(VialrColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Summary Vault Card
            VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                HStack {
                    Text("CONFIGURED SUMMARY")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentVitality)
                    Spacer()
                    MetricBadge(.success("Live Ready"))
                }

                Divider().background(VialrColors.glassBorder)

                if viewModel.wantsFirstProtocol, let compound = viewModel.selectedCompound {
                    // Protocol summary row
                    summaryRow(
                        title: "Active Protocol",
                        value: viewModel.protocolName.isEmpty ? "\(compound.name) Protocol" : viewModel.protocolName,
                        subtitle: "\(String(format: viewModel.doseAmount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", viewModel.doseAmount)) \(viewModel.doseUnit.rawValue) • \(viewModel.selectedRoute.shortName) • \(viewModel.computedScheduleRule.description)",
                        icon: "list.bullet.clipboard.fill"
                    )

                    // First Dose Schedule row
                    summaryRow(
                        title: "First Scheduled Dose",
                        value: "Today • Morning",
                        subtitle: "Ready on your Home Screen timeline",
                        icon: "clock.badge.checkmark.fill"
                    )

                    // Inventory vial row
                    if viewModel.shouldAddVial {
                        summaryRow(
                            title: "Inventory Stock",
                            value: "\(String(format: "%.1f", viewModel.vialDryMassMg))mg \(compound.name) Vial",
                            subtitle: "\(String(format: "%.1f", viewModel.vialBacWaterMl))mL BAC Water (\(viewModel.estimatedDosesInVial) doses available)",
                            icon: "cross.vial.fill"
                        )
                    }
                } else {
                    summaryRow(
                        title: "Protocol Setup",
                        value: "Custom Ad-Hoc Mode",
                        subtitle: "Create protocols on-demand from the Protocols tab",
                        icon: "sparkles"
                    )
                }

                // Apple Health row
                summaryRow(
                    title: "Apple Health Sync",
                    value: viewModel.enableAppleHealth ? "Connected (\(viewModel.enabledHealthMetrics.count) metrics)" : "Disabled",
                    subtitle: viewModel.enableAppleHealth ? "Vitals & glucose synced" : "Manual metric logging",
                    icon: "heart.fill"
                )
            }
            .padding(VialrSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusLg, style: .continuous)
                    .fill(VialrColors.heroCardGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: VialrSpacing.radiusLg, style: .continuous)
                            .stroke(VialrColors.accentVitality.opacity(0.35), lineWidth: 1.2)
                    )
            )
        }
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VialrButton(
            viewModel.isLastStep ? "Launch Protocol Vault" : "Continue",
            icon: viewModel.isLastStep ? "sparkles" : "arrow.right",
            isLoading: viewModel.isSubmitting,
            style: .vitality
        ) {
            if viewModel.isLastStep {
                Task {
                    do {
                        let finalUser = try await viewModel.finalizeSetup(for: authenticatedUser)
                        await MainActor.run {
                            onSetupComplete(finalUser)
                        }
                    } catch {
                        print("[PostAuthSetupView] Error finalizing setup: \(error)")
                        onSetupComplete(authenticatedUser)
                    }
                }
            } else {
                viewModel.nextStep()
            }
        }
    }

    // MARK: - Custom Compound Sheet
    private var customCompoundSheet: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: VialrSpacing.md) {
                    VialrInputField(
                        title: "Compound Name",
                        placeholder: "e.g. BPC-157 / TB-500 Blend",
                        text: $viewModel.newCompoundName,
                        systemImage: "cross.case.fill"
                    )

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Typical Dose")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)

                            TextField("250", value: $viewModel.newCompoundTypicalDose, format: .number)
                                .keyboardType(.decimalPad)
                                .font(VialrTypography.headline)
                                .foregroundColor(VialrColors.textPrimary)
                                .padding(10)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusSm)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unit")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)

                            HStack(spacing: 4) {
                                ForEach([DoseUnit.mcg, DoseUnit.mg], id: \.self) { unit in
                                    Button {
                                        viewModel.newCompoundUnit = unit
                                    } label: {
                                        Text(unit.rawValue)
                                            .font(VialrTypography.captionBold)
                                            .foregroundColor(viewModel.newCompoundUnit == unit ? Color.black : VialrColors.textSecondary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 10)
                                            .background(viewModel.newCompoundUnit == unit ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                                            .cornerRadius(VialrSpacing.radiusSm)
                                    }
                                }
                            }
                        }
                    }

                    Spacer()

                    VialrButton("Save & Select Compound", icon: "checkmark", style: .vitality) {
                        Task {
                            _ = await viewModel.createCustomCompound()
                        }
                    }
                }
                .padding(VialrSpacing.lg)
            }
            .navigationTitle("New Compound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.isShowingCustomCompoundSheet = false
                    }
                    .foregroundColor(VialrColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Helper UI Builders
    private func choiceCard(
        title: String,
        subtitle: String,
        icon: String,
        badge: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            VialrHaptics.selection()
            action()
        }) {
            HStack(spacing: VialrSpacing.md) {
                ZStack {
                    Circle()
                        .fill(isSelected ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? Color.black : VialrColors.accentVitality)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)
                        Spacer()
                        if let b = badge {
                            MetricBadge(.success(b))
                        }
                    }

                    Text(subtitle)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }
            .padding(VialrSpacing.md)
            .vialrCard(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func summaryRow(title: String, value: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: VialrSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(VialrColors.accentVitality)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textTertiary)
                Text(value)
                    .font(VialrTypography.subheadline)
                    .foregroundColor(VialrColors.textPrimary)
                Text(subtitle)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func unitPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            VialrHaptics.selection()
            action()
        }) {
            Text(title)
                .font(VialrTypography.footnoteBold)
                .foregroundColor(isSelected ? Color.black : VialrColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? VialrColors.accentVitality : VialrColors.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: VialrSpacing.radiusSm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusSm, style: .continuous)
                        .stroke(isSelected ? Color.clear : VialrColors.glassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func toggleCard(title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: VialrSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(isOn.wrappedValue ? VialrColors.accentVitality : VialrColors.textTertiary)
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

            Toggle("", isOn: isOn)
                .tint(VialrColors.accentVitality)
                .labelsHidden()
        }
        .padding(VialrSpacing.md)
        .vialrCard(isSelected: isOn.wrappedValue)
    }
}
