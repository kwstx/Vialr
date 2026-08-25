import SwiftUI
import Domain
import DesignSystem
import CalculationEngine

public struct ProtocolCreationFlowView: View {
    @State public var viewModel: ProtocolCreationViewModel
    public var onProtocolCreated: (ProtocolModel) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(
        viewModel: ProtocolCreationViewModel = ProtocolCreationViewModel(),
        onProtocolCreated: @escaping (ProtocolModel) -> Void
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.onProtocolCreated = onProtocolCreated
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Progress & Navigation Bar
                    topStepHeader
                        .padding(.horizontal, VialrSpacing.md)
                        .padding(.top, VialrSpacing.xs)
                        .padding(.bottom, VialrSpacing.sm)

                    // Step Content
                    ScrollView {
                        VStack(spacing: VialrSpacing.lg) {
                            stepHeaderTitle

                            stepContent
                        }
                        .padding(.horizontal, VialrSpacing.md)
                        .padding(.bottom, 120)
                    }

                    Spacer(minLength: 0)
                }

                // Floating Bottom Action Bar
                VStack {
                    Spacer()
                    bottomActionBar
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadData()
            }
            .sheet(isPresented: $viewModel.isShowingNewCompoundSheet) {
                newCustomCompoundSheet
            }
        }
    }

    // MARK: - Top Step Header & Progress
    private var topStepHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    if viewModel.currentStep == .compound {
                        dismiss()
                    } else {
                        viewModel.previousStep()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.currentStep == .compound ? "xmark" : "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        if viewModel.currentStep != .compound {
                            Text("Back")
                                .font(VialrTypography.subheadlineBold)
                        }
                    }
                    .foregroundColor(VialrColors.textSecondary)
                    .frame(height: 36)
                    .padding(.horizontal, 8)
                }

                Spacer()

                Text("Step \(viewModel.currentStep.rawValue + 1) of \(ProtocolCreationStep.allCases.count)")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentVitality)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(VialrColors.accentVitality.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .font(VialrTypography.subheadline)
                .foregroundColor(VialrColors.textTertiary)
                .frame(height: 36)
                .padding(.horizontal, 8)
            }

            // Step Progress Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(VialrColors.cardSurfaceElevated)
                        .frame(height: 4)

                    let progress = Double(viewModel.currentStep.rawValue + 1) / Double(ProtocolCreationStep.allCases.count)
                    Capsule()
                        .fill(VialrColors.accentVitality)
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Step Title Header
    private var stepHeaderTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.currentStep.title)
                .font(VialrTypography.largeHero)
                .foregroundColor(VialrColors.textPrimary)

            Text(viewModel.currentStep.stepSubtitle)
                .font(VialrTypography.body)
                .foregroundColor(VialrColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Step Switcher Content
    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .compound:
            compoundStepView
        case .dose:
            doseStepView
        case .frequency:
            frequencyStepView
        case .route:
            routeStepView
        case .scheduleDates:
            scheduleDatesStepView
        case .reminders:
            remindersStepView
        case .attachVial:
            attachVialStepView
        case .review:
            reviewStepView
        }
    }

    // MARK: - Step 1: Choose Compound
    private var compoundStepView: some View {
        VStack(spacing: VialrSpacing.md) {
            // Search Input Field
            VialrInputField(
                "SEARCH LIBRARY",
                placeholder: "Search BPC-157, Tirzepatide, CJC...",
                value: $viewModel.compoundSearchQuery,
                icon: "magnifyingglass"
            )

            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryPill(title: "All", category: nil)
                    ForEach(CompoundCategory.allCases) { cat in
                        categoryPill(title: cat.rawValue, category: cat)
                    }
                }
                .padding(.vertical, 2)
            }

            // Create Custom Button Card
            Button {
                viewModel.isShowingNewCompoundSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(VialrColors.accentVitality)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Custom Compound")
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)
                        Text("Track any custom peptide, supplement, or medicine")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(VialrColors.textTertiary)
                }
                .padding(VialrSpacing.cardPadding)
                .vialrCard()
            }
            .buttonStyle(.plain)

            // Compound Selection List
            VStack(spacing: 10) {
                ForEach(viewModel.filteredCompounds) { compound in
                    let isSelected = viewModel.selectedCompound?.id == compound.id
                    Button {
                        viewModel.selectCompound(compound)
                        VialrHaptics.selection()
                    } label: {
                        HStack(spacing: 14) {
                            // Category Icon Circle
                            ZStack {
                                Circle()
                                    .fill(isSelected ? VialrColors.accentVitality.opacity(0.2) : VialrColors.cardSurfaceElevated)
                                    .frame(width: 44, height: 44)

                                Image(systemName: compound.category.iconName)
                                    .font(.system(size: 18))
                                    .foregroundColor(isSelected ? VialrColors.accentVitality : VialrColors.textSecondary)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(compound.name)
                                        .font(VialrTypography.headline)
                                        .foregroundColor(VialrColors.textPrimary)

                                    if !compound.shortCode.isEmpty {
                                        Text(compound.shortCode)
                                            .font(VialrTypography.captionBold)
                                            .foregroundColor(VialrColors.accentVitality)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(VialrColors.accentVitality.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(compound.displayCategory)
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textSecondary)

                                if compound.typicalDose > 0 {
                                    Text("Typical: \(String(format: "%.0f", compound.typicalDose)) \(compound.defaultUnit.rawValue) • \(compound.administrationRoute.shortName)")
                                        .font(VialrTypography.caption)
                                        .foregroundColor(VialrColors.textTertiary)
                                }
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(VialrColors.accentVitality)
                            } else {
                                Circle()
                                    .stroke(VialrColors.glassBorder, lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .padding(VialrSpacing.cardPadding)
                        .vialrCard()
                        .overlay(
                            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous)
                                .stroke(isSelected ? VialrColors.accentVitality : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func categoryPill(title: String, category: CompoundCategory?) -> some View {
        let isSelected = viewModel.selectedCategoryFilter == category
        return Button {
            viewModel.selectedCategoryFilter = category
            VialrHaptics.lightImpact()
        } label: {
            Text(title)
                .font(VialrTypography.captionBold)
                .foregroundColor(isSelected ? Color.black : VialrColors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : VialrColors.glassBorder, lineWidth: 1)
                )
        }
    }

    // MARK: - Step 2: Planned Dose
    private var doseStepView: some View {
        VStack(spacing: VialrSpacing.lg) {
            // Selected Compound Banner
            if let compound = viewModel.selectedCompound {
                HStack(spacing: 12) {
                    Image(systemName: compound.category.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(VialrColors.accentVitality)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(compound.name)
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)
                        Text(compound.displayCategory)
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(VialrSpacing.md)
                .background(VialrColors.cardSurfaceSubtle)
                .cornerRadius(VialrSpacing.radiusSm)
            }

            // Dose Amount Stepper Card
            VialrStepper(
                title: "TARGET DOSE AMOUNT",
                value: $viewModel.doseAmount,
                step: viewModel.doseUnit == .mcg ? 50 : 0.5,
                range: 0.1...10000,
                unit: viewModel.doseUnit.rawValue,
                format: viewModel.doseUnit == .mg ? "%.2f" : "%.0f"
            )

            // Dose Unit Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("MEASUREMENT UNIT")
                    .vialrEyebrow()

                HStack(spacing: 8) {
                    ForEach(DoseUnit.allCases) { unit in
                        let isSelected = viewModel.doseUnit == unit
                        Button {
                            viewModel.doseUnit = unit
                            VialrHaptics.selection()
                        } label: {
                            VStack(spacing: 3) {
                                Text(unit.rawValue)
                                    .font(VialrTypography.headline)
                                    .foregroundColor(isSelected ? Color.black : VialrColors.textPrimary)
                                Text(unit.displayName.components(separatedBy: " ").first ?? "")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(isSelected ? Color.black.opacity(0.8) : VialrColors.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isSelected ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                            .cornerRadius(VialrSpacing.radiusSm)
                            .overlay(
                                RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                                    .stroke(isSelected ? Color.clear : VialrColors.glassBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(VialrSpacing.cardPadding)
            .vialrCard()

            // Quick Preset Dose Chips
            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK PRESETS")
                    .vialrEyebrow()

                let presets: [Double] = viewModel.doseUnit == .mcg
                    ? [100, 250, 500, 750, 1000]
                    : (viewModel.doseUnit == .mg ? [1.0, 2.5, 5.0, 7.5, 10.0, 15.0] : [1, 2, 5, 10])

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { preset in
                            let isSelected = viewModel.doseAmount == preset
                            Button {
                                viewModel.doseAmount = preset
                                VialrHaptics.selection()
                            } label: {
                                Text(String(format: viewModel.doseUnit == .mg ? "%.1f" : "%.0f", preset) + " \(viewModel.doseUnit.rawValue)")
                                    .font(VialrTypography.footnote)
                                    .fontWeight(.semibold)
                                    .foregroundColor(isSelected ? Color.black : VialrColors.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(isSelected ? Color.clear : VialrColors.glassBorder, lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(VialrSpacing.cardPadding)
            .vialrCard()

            // Optional Titration Rule Toggle & Accordion
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                Toggle(isOn: $viewModel.enableTitration.animation(.spring)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Progressive Titration / Taper")
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)
                        Text("Automatically ramp dose over scheduled weekly intervals")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                }
                .tint(VialrColors.accentVitality)

                if viewModel.enableTitration {
                    VStack(spacing: 12) {
                        Divider().background(VialrColors.divider)

                        VialrStepper(
                            title: "TARGET FINAL DOSE",
                            value: $viewModel.titrationTargetDose,
                            step: viewModel.doseUnit == .mcg ? 50 : 0.5,
                            range: 0.1...10000,
                            unit: viewModel.doseUnit.rawValue,
                            format: viewModel.doseUnit == .mg ? "%.2f" : "%.0f"
                        )

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("STEP INCREASE")
                                    .vialrEyebrow()
                                HStack {
                                    Text("+\(String(format: "%.0f", viewModel.titrationStepAmount)) \(viewModel.doseUnit.rawValue)")
                                        .font(VialrTypography.bodyMedium)
                                        .foregroundColor(VialrColors.accentVitality)
                                }
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("EVERY")
                                    .vialrEyebrow()
                                Text("\(viewModel.titrationStepDays) Days")
                                    .font(VialrTypography.bodyMedium)
                                    .foregroundColor(VialrColors.textPrimary)
                            }
                        }
                        .padding(VialrSpacing.sm)
                        .background(VialrColors.cardSurfaceElevated)
                        .cornerRadius(VialrSpacing.radiusSm)
                    }
                }
            }
            .padding(VialrSpacing.cardPadding)
            .vialrCard()
        }
    }

    // MARK: - Step 3: Dosing Frequency
    private var frequencyStepView: some View {
        VStack(spacing: VialrSpacing.lg) {
            // Frequency Type Selection Cards
            VStack(alignment: .leading, spacing: 8) {
                Text("RECURRENCE SCHEDULE")
                    .vialrEyebrow()

                ForEach(FrequencyType.allCases) { freq in
                    let isSelected = viewModel.frequencyType == freq
                    Button {
                        viewModel.frequencyType = freq
                        VialrHaptics.selection()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: freq.iconName)
                                .font(.system(size: 18))
                                .foregroundColor(isSelected ? VialrColors.accentVitality : VialrColors.textSecondary)
                                .frame(width: 32)

                            Text(freq.rawValue)
                                .font(VialrTypography.headline)
                                .foregroundColor(VialrColors.textPrimary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(VialrColors.accentVitality)
                            } else {
                                Circle()
                                    .stroke(VialrColors.glassBorder, lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding(VialrSpacing.cardPadding)
                        .background(isSelected ? VialrColors.cardSurfaceSelected : VialrColors.cardSurface)
                        .cornerRadius(VialrSpacing.radiusMd)
                        .overlay(
                            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                                .stroke(isSelected ? VialrColors.accentVitality : VialrColors.glassBorder, lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Sub-configurations for Specific Frequency Types
            if viewModel.frequencyType == .daysOfWeek {
                daysOfWeekConfigCard
            } else if viewModel.frequencyType == .cycle {
                cycleConfigCard
            } else if viewModel.frequencyType == .everyNDays {
                everyNDaysConfigCard
            }

            // Times Per Day & Preferred Time
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                Text("TIMING & TIME OF DAY")
                    .vialrEyebrow()

                // Times per day pills
                HStack {
                    Text("Times Per Day")
                        .font(VialrTypography.subheadline)
                        .foregroundColor(VialrColors.textSecondary)
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach([1, 2, 3], id: \.self) { count in
                            let isSel = viewModel.timesPerDay == count
                            Button("\(count)x") {
                                viewModel.timesPerDay = count
                                VialrHaptics.selection()
                            }
                            .font(VialrTypography.captionBold)
                            .foregroundColor(isSel ? Color.black : VialrColors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(isSel ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(VialrSpacing.sm)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusSm)

                // Preferred Time of Day Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferred Administration Window")
                        .font(VialrTypography.subheadline)
                        .foregroundColor(VialrColors.textSecondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(TimeOfDay.allCases) { timeSlot in
                            let isSelected = viewModel.preferredTimeOfDay == timeSlot
                            Button {
                                viewModel.preferredTimeOfDay = timeSlot
                                VialrHaptics.selection()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: timeSlot.iconName)
                                        .font(.system(size: 14))
                                        .foregroundColor(isSelected ? Color.black : VialrColors.accentVitality)
                                    Text(timeSlot.rawValue.components(separatedBy: " ").first ?? "")
                                        .font(VialrTypography.captionBold)
                                        .foregroundColor(isSelected ? Color.black : VialrColors.textPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(isSelected ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusSm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                                        .stroke(isSelected ? Color.clear : VialrColors.glassBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(VialrSpacing.cardPadding)
            .vialrCard()
        }
    }

    private var daysOfWeekConfigCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                Text("SELECT DOSING DAYS")
                    .vialrEyebrow()
                Spacer()
                Button("MWF") {
                    viewModel.selectedWeekdays = [2, 4, 6]
                    VialrHaptics.selection()
                }
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentVitality)

                Button("Weekdays") {
                    viewModel.selectedWeekdays = [2, 3, 4, 5, 6]
                    VialrHaptics.selection()
                }
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentVitality)
            }

            let days: [(Int, String)] = [
                (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat")
            ]

            HStack(spacing: 6) {
                ForEach(days, id: \.0) { day in
                    let isSelected = viewModel.selectedWeekdays.contains(day.0)
                    Button {
                        viewModel.toggleWeekday(day.0)
                    } label: {
                        Text(day.1)
                            .font(VialrTypography.captionBold)
                            .foregroundColor(isSelected ? Color.black : VialrColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(isSelected ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.clear : VialrColors.glassBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    private var cycleConfigCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("CYCLE CONFIGURATION")
                    .vialrEyebrow()
                Spacer()
                Text("\(viewModel.cycleDaysOn) Days On / \(viewModel.cycleDaysOff) Days Off")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.accentVitality)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Days On")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                    Stepper("\(viewModel.cycleDaysOn)", value: $viewModel.cycleDaysOn, in: 1...30)
                        .font(VialrTypography.headline)
                }
                .padding(VialrSpacing.sm)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusSm)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Days Off")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                    Stepper("\(viewModel.cycleDaysOff)", value: $viewModel.cycleDaysOff, in: 1...30)
                        .font(VialrTypography.headline)
                }
                .padding(VialrSpacing.sm)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusSm)
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    private var everyNDaysConfigCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INTERVAL FREQUENCY")
                .vialrEyebrow()

            HStack {
                Text("Dose Every")
                    .font(VialrTypography.headline)
                    .foregroundColor(VialrColors.textPrimary)
                Spacer()
                Stepper("\(viewModel.everyNIntervalDays) Days", value: $viewModel.everyNIntervalDays, in: 2...30)
                    .font(VialrTypography.metricSmall)
                    .foregroundColor(VialrColors.accentVitality)
            }
            .padding(VialrSpacing.sm)
            .background(VialrColors.cardSurfaceElevated)
            .cornerRadius(VialrSpacing.radiusSm)
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    // MARK: - Step 4: Administration Route
    private var routeStepView: some View {
        VStack(spacing: VialrSpacing.lg) {
            // Route Selection Grid
            VStack(alignment: .leading, spacing: 8) {
                Text("PRIMARY DELIVERY ROUTE")
                    .vialrEyebrow()

                ForEach(AdministrationRoute.allCases) { route in
                    let isSelected = viewModel.selectedRoute == route
                    Button {
                        viewModel.selectedRoute = route
                        VialrHaptics.selection()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: routeIcon(for: route))
                                .font(.system(size: 18))
                                .foregroundColor(isSelected ? VialrColors.accentVitality : VialrColors.textSecondary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(route.rawValue)
                                    .font(VialrTypography.headline)
                                    .foregroundColor(VialrColors.textPrimary)
                                Text(routeDescription(for: route))
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textSecondary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(VialrColors.accentVitality)
                            } else {
                                Circle()
                                    .stroke(VialrColors.glassBorder, lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding(VialrSpacing.cardPadding)
                        .background(isSelected ? VialrColors.cardSurfaceSelected : VialrColors.cardSurface)
                        .cornerRadius(VialrSpacing.radiusMd)
                        .overlay(
                            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                                .stroke(isSelected ? VialrColors.accentVitality : VialrColors.glassBorder, lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Food Requirement Card
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                Text("FOOD / FASTING REQUIREMENT")
                    .vialrEyebrow()

                ForEach(FoodRequirement.allCases) { req in
                    let isSelected = viewModel.foodRequirement == req
                    Button {
                        viewModel.foodRequirement = req
                        VialrHaptics.selection()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: req.iconName)
                                .font(.system(size: 16))
                                .foregroundColor(isSelected ? VialrColors.accentVitality : VialrColors.textSecondary)
                                .frame(width: 24)

                            Text(req.rawValue)
                                .font(VialrTypography.bodyMedium)
                                .foregroundColor(VialrColors.textPrimary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(VialrColors.accentVitality)
                            }
                        }
                        .padding(VialrSpacing.sm)
                        .background(isSelected ? VialrColors.cardSurfaceSelected : VialrColors.cardSurfaceElevated)
                        .cornerRadius(VialrSpacing.radiusSm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(VialrSpacing.cardPadding)
            .vialrCard()
        }
    }

    private func routeIcon(for route: AdministrationRoute) -> String {
        switch route {
        case .subcutaneous: return "syringe"
        case .intramuscular: return "cross.vial.fill"
        case .oral: return "pills.fill"
        case .nasal: return "nose"
        case .sublingual: return "mouth.fill"
        case .topical: return "hand.raised.fill"
        case .transdermal: return "bandage.fill"
        case .intravenous: return "ivfluid.bag.fill"
        }
    }

    private func routeDescription(for route: AdministrationRoute) -> String {
        switch route {
        case .subcutaneous: return "Standard fatty tissue injection (abdomen, thighs, deltoids)"
        case .intramuscular: return "Deep muscle injection (gluteal, vastus lateralis)"
        case .oral: return "Capsule, tablet, or oral liquid solution"
        case .nasal: return "Intranasal spray delivery"
        case .sublingual: return "Under-the-tongue dissolving tablets or liquid drops"
        case .topical: return "Direct cream or gel application on skin"
        case .transdermal: return "Time-released dermal patch application"
        case .intravenous: return "Direct systemic IV infusion"
        }
    }

    // MARK: - Step 5: Start & End Dates
    private var scheduleDatesStepView: some View {
        VStack(spacing: VialrSpacing.lg) {
            // Start Date Selection Card
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                Text("PROTOCOL START DATE")
                    .vialrEyebrow()

                HStack(spacing: 8) {
                    ForEach(StartDateOption.allCases) { opt in
                        let isSelected = viewModel.startDateOption == opt
                        Button {
                            viewModel.startDateOption = opt
                            VialrHaptics.selection()
                        } label: {
                            Text(opt.rawValue)
                                .font(VialrTypography.subheadlineBold)
                                .foregroundColor(isSelected ? Color.black : VialrColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isSelected ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusSm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                                        .stroke(isSelected ? Color.clear : VialrColors.glassBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.startDateOption == .custom {
                    DatePicker("Start Date", selection: $viewModel.customStartDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(VialrColors.accentVitality)
                        .padding(8)
                        .background(VialrColors.cardSurfaceElevated)
                        .cornerRadius(VialrSpacing.radiusSm)
                }

                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(VialrColors.accentVitality)
                    Text("Starts: \(viewModel.effectiveStartDate.formatted(date: .long, time: .omitted))")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textPrimary)
                }
                .padding(.top, 4)
            }
            .padding(VialrSpacing.cardPadding)
            .vialrCard()

            // Protocol Duration & End Date Card
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                Text("PROTOCOL DURATION & END DATE")
                    .vialrEyebrow()

                VStack(spacing: 8) {
                    ForEach(DurationPreset.allCases) { preset in
                        let isSelected = viewModel.durationPreset == preset
                        Button {
                            viewModel.durationPreset = preset
                            VialrHaptics.selection()
                        } label: {
                            HStack {
                                Image(systemName: preset == .ongoing ? "infinity" : "timer")
                                    .foregroundColor(isSelected ? VialrColors.accentVitality : VialrColors.textSecondary)
                                    .frame(width: 24)

                                Text(preset.rawValue)
                                    .font(VialrTypography.bodyMedium)
                                    .foregroundColor(VialrColors.textPrimary)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(VialrColors.accentVitality)
                                }
                            }
                            .padding(VialrSpacing.sm)
                            .background(isSelected ? VialrColors.cardSurfaceSelected : VialrColors.cardSurfaceElevated)
                            .cornerRadius(VialrSpacing.radiusSm)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.durationPreset == .custom {
                    DatePicker("End Date", selection: $viewModel.customEndDate, in: viewModel.effectiveStartDate..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(VialrColors.accentVitality)
                        .padding(8)
                        .background(VialrColors.cardSurfaceElevated)
                        .cornerRadius(VialrSpacing.radiusSm)
                }

                // Duration Summary Badge
                HStack {
                    if let days = viewModel.totalDurationDays, let end = viewModel.effectiveEndDate {
                        MetricBadge(.success("\(days) Total Days (\(days / 7) Weeks)"), showDot: true)
                        Spacer()
                        Text("Ends \(end.formatted(date: .abbreviated, time: .omitted))")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)
                    } else {
                        MetricBadge(.neutral("Ongoing / Open-Ended Protocol"), showDot: true)
                    }
                }
            }
            .padding(VialrSpacing.cardPadding)
            .vialrCard()
        }
    }

    // MARK: - Step 6: Smart Reminders
    private var remindersStepView: some View {
        VStack(spacing: VialrSpacing.lg) {
            // Reminders Master Toggle
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                Toggle(isOn: $viewModel.reminderEnabled.animation(.spring)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dose Reminders")
                            .font(VialrTypography.title3)
                            .foregroundColor(VialrColors.textPrimary)
                        Text("Send smart push notification before each scheduled dose")
                            .font(VialrTypography.subheadline)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                }
                .tint(VialrColors.accentVitality)

                if viewModel.reminderEnabled {
                    Divider().background(VialrColors.divider)

                    // Time Picker
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("REMINDER TIME")
                                .vialrEyebrow()
                            Text("Scheduled alert time")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                        }
                        Spacer()
                        DatePicker("", selection: $viewModel.reminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(VialrColors.accentVitality)
                    }
                    .padding(VialrSpacing.sm)
                    .background(VialrColors.cardSurfaceElevated)
                    .cornerRadius(VialrSpacing.radiusSm)

                    // Lead Time Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LEAD TIME NOTICE")
                            .vialrEyebrow()

                        let leadTimes: [(Int, String)] = [
                            (0, "At Time"),
                            (15, "15m Before"),
                            (30, "30m Before"),
                            (60, "1h Before")
                        ]

                        HStack(spacing: 8) {
                            ForEach(leadTimes, id: \.0) { item in
                                let isSelected = viewModel.reminderLeadTimeMinutes == item.0
                                Button {
                                    viewModel.reminderLeadTimeMinutes = item.0
                                    VialrHaptics.selection()
                                } label: {
                                    Text(item.1)
                                        .font(VialrTypography.captionBold)
                                        .foregroundColor(isSelected ? Color.black : VialrColors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(isSelected ? VialrColors.accentVitality : VialrColors.cardSurfaceElevated)
                                        .cornerRadius(VialrSpacing.radiusSm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                                                .stroke(isSelected ? Color.clear : VialrColors.glassBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(VialrSpacing.cardPadding)
            .vialrCard()

            // Notification Live Preview Card
            if viewModel.reminderEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    Text("NOTIFICATION PREVIEW")
                        .vialrEyebrow()

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 24))
                            .foregroundColor(VialrColors.accentVitality)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Vialr Protocol Reminder")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textPrimary)
                                Spacer()
                                Text("Now")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textTertiary)
                            }

                            Text("Time for your \(viewModel.selectedCompound?.name ?? "Compound") dose: \(String(format: "%.0f", viewModel.doseAmount)) \(viewModel.doseUnit.rawValue) (\(viewModel.selectedRoute.shortName)).")
                                .font(VialrTypography.footnote)
                                .foregroundColor(VialrColors.textSecondary)
                        }
                    }
                    .padding(VialrSpacing.md)
                    .background(VialrColors.cardSurfaceElevated)
                    .cornerRadius(VialrSpacing.radiusSm)
                    .overlay(
                        RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                            .stroke(VialrColors.activeBorder, lineWidth: 1)
                    )
                }
                .padding(VialrSpacing.cardPadding)
                .vialrCard()
            }
        }
    }

    // MARK: - Step 7: Attach Existing Vial
    private var attachVialStepView: some View {
        VStack(spacing: VialrSpacing.lg) {
            // Master Option Toggle
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LINK INVENTORY VIAL")
                            .vialrEyebrow()
                        Text("Auto-deduct volume on dose logging and forecast supplies")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $viewModel.shouldAttachVial.animation(.spring))
                        .labelsHidden()
                        .tint(VialrColors.accentVitality)
                }
            }
            .padding(VialrSpacing.cardPadding)
            .vialrCard()

            if viewModel.shouldAttachVial {
                let matching = viewModel.matchingVialsForSelectedCompound

                if matching.isEmpty {
                    // No matching vials found card
                    VStack(spacing: VialrSpacing.md) {
                        Image(systemName: "cross.vial")
                            .font(.system(size: 36))
                            .foregroundColor(VialrColors.textTertiary)
                        Text("No In-Stock Vials for \(viewModel.selectedCompound?.name ?? "this compound")")
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)
                        Text("You can still create this protocol now and link a reconstituted vial later from your inventory tab.")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(VialrSpacing.xl)
                    .frame(maxWidth: .infinity)
                    .vialrCard()
                } else {
                    // Matching Vials List
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MATCHING VIALS IN STOCK")
                            .vialrEyebrow()

                        ForEach(matching) { vial in
                            let isSelected = viewModel.selectedVial?.id == vial.id
                            Button {
                                viewModel.selectedVial = vial
                                VialrHaptics.selection()
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(vial.compoundName)
                                                    .font(VialrTypography.headline)
                                                    .foregroundColor(VialrColors.textPrimary)
                                                if !vial.lotNumber.isEmpty {
                                                    Text(vial.lotNumber)
                                                        .font(VialrTypography.captionBold)
                                                        .foregroundColor(VialrColors.accentVitality)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(VialrColors.accentVitality.opacity(0.12))
                                                        .clipShape(Capsule())
                                                }
                                            }
                                            Text(vial.status.rawValue)
                                                .font(VialrTypography.caption)
                                                .foregroundColor(VialrColors.textSecondary)
                                        }

                                        Spacer()

                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(VialrColors.accentVitality)
                                        } else {
                                            Circle()
                                                .stroke(VialrColors.glassBorder, lineWidth: 1.5)
                                                .frame(width: 22, height: 22)
                                        }
                                    }

                                    // Vial stats row
                                    HStack(spacing: 12) {
                                        if let remVol = vial.currentVolumeRemainingMl, let bacWater = vial.bacWaterAddedMl, bacWater > 0 {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("VOLUME")
                                                    .font(VialrTypography.caption)
                                                    .foregroundColor(VialrColors.textTertiary)
                                                Text("\(String(format: "%.1f", remVol)) / \(String(format: "%.1f", bacWater)) mL")
                                                    .font(VialrTypography.footnote)
                                                    .foregroundColor(VialrColors.accentVitality)
                                            }
                                        }

                                        if let conc = vial.concentrationMcgMl {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("CONCENTRATION")
                                                    .font(VialrTypography.caption)
                                                    .foregroundColor(VialrColors.textTertiary)
                                                Text("\(String(format: "%.0f", conc)) mcg/mL")
                                                    .font(VialrTypography.footnote)
                                                    .foregroundColor(VialrColors.textPrimary)
                                            }
                                        }

                                        if let estDoses = vial.estimatedDosesRemaining(doseAmount: viewModel.doseAmount, unit: viewModel.doseUnit) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("EST. DOSES")
                                                    .font(VialrTypography.caption)
                                                    .foregroundColor(VialrColors.textTertiary)
                                                Text("~\(estDoses) Doses")
                                                    .font(VialrTypography.footnote)
                                                    .foregroundColor(VialrColors.textPrimary)
                                            }
                                        }
                                    }
                                }
                                .padding(VialrSpacing.cardPadding)
                                .background(isSelected ? VialrColors.cardSurfaceSelected : VialrColors.cardSurface)
                                .cornerRadius(VialrSpacing.radiusMd)
                                .overlay(
                                    RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                                        .stroke(isSelected ? VialrColors.accentVitality : VialrColors.glassBorder, lineWidth: 1.2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Live Vial Depletion Forecast Banner
                    if let forecast = viewModel.vialDepletionForecast {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "chart.line.downtrend.xyaxis")
                                    .foregroundColor(VialrColors.accentVitality)
                                Text("DEPLETION PROJECTION")
                                    .vialrEyebrow()
                            }

                            Text(forecast.summary)
                                .font(VialrTypography.headline)
                                .foregroundColor(VialrColors.textPrimary)

                            if let depDate = forecast.projectedDepletionDate {
                                Text("At planned recurrence, this vial will run out on \(depDate.formatted(date: .long, time: .omitted)).")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textSecondary)
                            }
                        }
                        .padding(VialrSpacing.cardPadding)
                        .vialrCard()
                    }
                }
            }
        }
    }

    // MARK: - Step 8: Review & Confirm
    private var reviewStepView: some View {
        VStack(spacing: VialrSpacing.lg) {
            // Protocol Name & Goal Customization Card
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                Text("PROTOCOL IDENTITY")
                    .vialrEyebrow()

                VialrInputField("Protocol Name", placeholder: "e.g. Tendon & Joint Recovery Stack", value: $viewModel.protocolName)
                VialrInputField("Primary Clinical Goal", placeholder: "e.g. Rotator cuff healing & tissue repair", value: $viewModel.protocolGoal)
            }
            .padding(VialrSpacing.cardPadding)
            .vialrCard()

            // Protocol Blueprint Card
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                HStack {
                    Text("PROTOCOL BLUEPRINT")
                        .vialrEyebrow()
                    Spacer()
                    MetricBadge(.success("Ready to Launch"), showDot: true)
                }

                // Primary Compound Details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: viewModel.selectedCompound?.category.iconName ?? "cross.vial")
                            .foregroundColor(VialrColors.accentVitality)
                        Text(viewModel.selectedCompound?.name ?? "Compound")
                            .font(VialrTypography.title3)
                            .foregroundColor(VialrColors.textPrimary)
                        Spacer()
                        Text("\(String(format: viewModel.doseUnit == .mg ? "%.2f" : "%.0f", viewModel.doseAmount)) \(viewModel.doseUnit.rawValue)")
                            .font(VialrTypography.metricMedium)
                            .foregroundColor(VialrColors.accentVitality)
                    }

                    Divider().background(VialrColors.divider)

                    // Blueprint grid
                    summaryRow(label: "Frequency", value: viewModel.computedScheduleRule.description, icon: "calendar")
                    summaryRow(label: "Route", value: "\(viewModel.selectedRoute.rawValue) (\(viewModel.foodRequirement.rawValue))", icon: "syringe")
                    summaryRow(label: "Start Date", value: viewModel.effectiveStartDate.formatted(date: .abbreviated, time: .omitted), icon: "play.circle")

                    if let end = viewModel.effectiveEndDate {
                        summaryRow(label: "End Date", value: "\(end.formatted(date: .abbreviated, time: .omitted)) (\(viewModel.totalDurationDays ?? 0) days)", icon: "stop.circle")
                    } else {
                        summaryRow(label: "End Date", value: "Ongoing (Open-Ended)", icon: "infinity")
                    }

                    if viewModel.reminderEnabled {
                        summaryRow(label: "Reminders", value: "\(viewModel.reminderTime.formatted(date: .omitted, time: .shortened)) (\(viewModel.reminderLeadTimeMinutes)m before)", icon: "bell.fill")
                    } else {
                        summaryRow(label: "Reminders", value: "Disabled", icon: "bell.slash")
                    }

                    if let vial = viewModel.selectedVial, viewModel.shouldAttachVial {
                        summaryRow(label: "Linked Vial", value: "\(vial.compoundName) (\(vial.lotNumber))", icon: "cross.vial")
                    }
                }
                .padding(VialrSpacing.md)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusSm)
            }
            .padding(VialrSpacing.cardPadding)
            .vialrCard()

            // Dynamic 14-Day Upcoming Occurrences Preview
            VStack(alignment: .leading, spacing: VialrSpacing.md) {
                Text("PROJECTED OCCURRENCES PREVIEW")
                    .vialrEyebrow()

                let preview = viewModel.previewOccurrences
                if preview.isEmpty {
                    Text("No doses scheduled within the initial 14-day projection window.")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                } else {
                    VStack(spacing: 6) {
                        ForEach(preview.prefix(5)) { occ in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(VialrColors.accentVitality)

                                Text(occ.scheduledTimestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textPrimary)

                                Spacer()

                                Text(occ.formattedDose)
                                    .font(VialrTypography.monoSub)
                                    .foregroundColor(VialrColors.accentVitality)

                                Text("• \(occ.route.shortName)")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textTertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(VialrSpacing.sm)
                    .background(VialrColors.cardSurfaceElevated)
                    .cornerRadius(VialrSpacing.radiusSm)
                }
            }
            .padding(VialrSpacing.cardPadding)
            .vialrCard()
        }
    }

    private func summaryRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(VialrColors.accentVitality)
                .frame(width: 18)

            Text(label)
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)

            Spacer()

            Text(value)
                .font(VialrTypography.footnoteBold)
                .foregroundColor(VialrColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 8) {
            if viewModel.currentStep == .review {
                VialrButton(
                    "Create & Start Protocol",
                    icon: "checkmark.circle.fill",
                    style: .vitality,
                    isLoading: viewModel.isSubmitting
                ) {
                    Task {
                        do {
                            let created = try await viewModel.saveProtocol()
                            onProtocolCreated(created)
                            dismiss()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                }
            } else {
                VialrButton(
                    "Continue",
                    icon: "arrow.right",
                    style: .vitality,
                    isDisabled: !viewModel.canProceedToNextStep
                ) {
                    viewModel.nextStep()
                }
            }
        }
        .padding(.horizontal, VialrSpacing.md)
        .padding(.vertical, VialrSpacing.md)
        .background(
            Rectangle()
                .fill(VialrColors.backgroundPrimary.opacity(0.96))
                .ignoresSafeArea()
                .overlay(
                    Rectangle().frame(height: 1).foregroundColor(VialrColors.glassBorder),
                    alignment: .top
                )
        )
    }

    // MARK: - New Custom Compound Modal
    private var newCustomCompoundSheet: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            Text("COMPOUND IDENTITY")
                                .vialrEyebrow()

                            VialrInputField("Compound Name", placeholder: "e.g. MOTS-c, SS-31, Semax", value: $viewModel.newCompoundName)

                            HStack {
                                Text("Category")
                                    .font(VialrTypography.subheadline)
                                    .foregroundColor(VialrColors.textSecondary)
                                Spacer()
                                Picker("Category", selection: $viewModel.newCompoundCategory) {
                                    ForEach(CompoundCategory.allCases) { cat in
                                        Text(cat.rawValue).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(VialrSpacing.sm)
                            .background(VialrColors.cardSurfaceElevated)
                            .cornerRadius(VialrSpacing.radiusSm)

                            HStack {
                                Text("Default Unit")
                                    .font(VialrTypography.subheadline)
                                    .foregroundColor(VialrColors.textSecondary)
                                Spacer()
                                Picker("Unit", selection: $viewModel.newCompoundUnit) {
                                    ForEach(DoseUnit.allCases) { u in
                                        Text(u.rawValue).tag(u)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(VialrSpacing.sm)
                            .background(VialrColors.cardSurfaceElevated)
                            .cornerRadius(VialrSpacing.radiusSm)

                            HStack {
                                Text("Default Route")
                                    .font(VialrTypography.subheadline)
                                    .foregroundColor(VialrColors.textSecondary)
                                Spacer()
                                Picker("Route", selection: $viewModel.newCompoundRoute) {
                                    ForEach(AdministrationRoute.allCases) { r in
                                        Text(r.rawValue).tag(r)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(VialrSpacing.sm)
                            .background(VialrColors.cardSurfaceElevated)
                            .cornerRadius(VialrSpacing.radiusSm)
                        }
                        .padding(VialrSpacing.cardPadding)
                        .vialrCard()

                        VialrButton("Save & Use Compound", icon: "plus.circle.fill", style: .vitality) {
                            Task {
                                _ = await viewModel.createCustomCompound()
                            }
                        }
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("New Compound")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.isShowingNewCompoundSheet = false }
                        .foregroundColor(VialrColors.accentVitality)
                }
            }
        }
    }
}
