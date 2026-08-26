import SwiftUI
import Domain
import DesignSystem

public struct DashboardView: View {
    @Bindable public var viewModel: DashboardViewModel
    public var onOpenQuickLog: (DoseLog?) -> Void
    public var onOpenReconstitution: () -> Void
    public var onOpenSiteRotation: () -> Void
    public var onOpenProtocolDetail: (ProtocolModel) -> Void
    public var onOpenBloodwork: (() -> Void)?
    public var onOpenTimeline: (() -> Void)?
    public var onNavigateToTab: ((AppTab) -> Void)?

    public init(
        viewModel: DashboardViewModel,
        onOpenQuickLog: @escaping (DoseLog?) -> Void,
        onOpenReconstitution: @escaping () -> Void,
        onOpenSiteRotation: @escaping () -> Void,
        onOpenProtocolDetail: @escaping (ProtocolModel) -> Void,
        onOpenBloodwork: (() -> Void)? = nil,
        onOpenTimeline: (() -> Void)? = nil,
        onNavigateToTab: ((AppTab) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onOpenQuickLog = onOpenQuickLog
        self.onOpenReconstitution = onOpenReconstitution
        self.onOpenSiteRotation = onOpenSiteRotation
        self.onOpenProtocolDetail = onOpenProtocolDetail
        self.onOpenBloodwork = onOpenBloodwork
        self.onOpenTimeline = onOpenTimeline
        self.onNavigateToTab = onNavigateToTab
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: VialrSpacing.sectionSpacing) {
                        // 1. Top Header (Current Date + Small Greeting)
                        headerSection

                        // 2. Primary Hero Action: Next Dose ("What do I need to do now?")
                        if let nextDose = viewModel.nextUpcomingDose {
                            heroNextDoseCard(nextDose)
                        } else {
                            allDosesCompletedHeroCard
                        }

                        // 3. Current Protocol
                        currentProtocolSection

                        // 4. Compact Progress Section (3 High-Signal Metrics)
                        compactProgressSection

                        // 5. Inventory Status & Upcoming Events
                        inventoryAndUpcomingSection

                        // 6. Chronological "Today" Section
                        todayChronologicalSection
                    }
                    .padding(.horizontal, VialrSpacing.screenHorizontal)
                    .padding(.bottom, 110) // Space for sleek floating tab bar
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadDashboardData()
            }
            .refreshable {
                await viewModel.loadDashboardData()
            }
        }
    }

    // MARK: - 1. Top Header Bar (Date + Greeting)
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.formattedCurrentDate)
                    .font(VialrTypography.eyebrow)
                    .tracking(1.4)
                    .foregroundColor(VialrColors.accentVitality)

                Text(viewModel.greeting)
                    .font(VialrTypography.screenTitle)
                    .foregroundColor(VialrColors.textPrimary)
                    .tracking(-0.5)
            }

            Spacer()

            HStack(spacing: 8) {
                // Quick Bloodwork Button
                Button {
                    VialrHaptics.lightImpact()
                    onOpenBloodwork?()
                } label: {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(VialrColors.accentRose)
                        .frame(width: 44, height: 44)
                        .background(VialrColors.cardSurfaceElevated)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(VialrColors.glassBorder, lineWidth: 1)
                        )
                }
                .accessibilityLabel("Open Bloodwork & Lab Results Hub")

                // Quick Calculator Action Button
                Button {
                    VialrHaptics.lightImpact()
                    onOpenReconstitution()
                } label: {
                    Image(systemName: "plus.forwardslash.minus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(VialrColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(VialrColors.cardSurfaceElevated)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(VialrColors.glassBorder, lineWidth: 1)
                        )
                }
                .accessibilityLabel("Open Reconstitution Calculator")
            }
        }
        .padding(.top, VialrSpacing.xs)
    }

    // MARK: - 2. Hero Action Card: Next Dose ("What do I need to do now?")
    private func heroNextDoseCard(_ dose: DoseLog) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            // Action Eyebrow & Schedule Badge
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(VialrColors.accentVitality)
                        .frame(width: 7, height: 7)
                    Text("ACTION REQUIRED • UP NEXT")
                        .font(VialrTypography.eyebrow)
                        .tracking(1.1)
                        .foregroundColor(VialrColors.accentVitality)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(VialrColors.accentVitality.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(VialrColors.accentVitality.opacity(0.3), lineWidth: 1)
                )

                Spacer()

                Text("Scheduled for Today")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textTertiary)
            }

            // Compound Name & Dosage
            VStack(alignment: .leading, spacing: 4) {
                Text(dose.compoundName)
                    .font(VialrTypography.largeHero)
                    .foregroundColor(VialrColors.textPrimary)
                    .tracking(-0.4)

                HStack(spacing: 8) {
                    Text("\(String(format: dose.doseAmount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", dose.doseAmount)) \(dose.doseUnit.rawValue)")
                        .font(VialrTypography.metricMedium)
                        .foregroundColor(VialrColors.accentVitality)

                    Text("•")
                        .foregroundColor(VialrColors.textTertiary)

                    Text(dose.administrationRoute.shortName)
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }
            .padding(.vertical, 2)

            // Injection Site Recommendation Callout
            Button {
                VialrHaptics.lightImpact()
                onOpenSiteRotation()
            } label: {
                HStack(spacing: VialrSpacing.xs) {
                    Image(systemName: "cross.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(VialrColors.accentVitality)

                    Text("Target Site:")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textTertiary)

                    Text(viewModel.recommendedSite?.name ?? "Abdomen - Upper Right")
                        .font(VialrTypography.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(VialrColors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(VialrColors.textTertiary)
                }
                .padding(.horizontal, VialrSpacing.sm)
                .padding(.vertical, 10)
                .background(VialrColors.cardSurfaceSubtle.opacity(0.8))
                .cornerRadius(VialrSpacing.radiusSm)
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                        .stroke(VialrColors.glassBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Divider()
                .background(VialrColors.glassBorder)

            // Primary Interactive CTAs
            HStack(spacing: VialrSpacing.sm) {
                // Main Log Button
                VialrButton("Log Dose Now", icon: "checkmark.circle.fill", style: .vitality, size: .standard) {
                    onOpenQuickLog(dose)
                }

                // Quick 1-Tap Instant Log
                Button {
                    VialrHaptics.success()
                    Task {
                        await viewModel.quickLogDose(dose, siteId: nil)
                    }
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(VialrColors.accentVitality)
                        .frame(width: VialrSpacing.buttonHeight, height: VialrSpacing.buttonHeight)
                        .background(VialrColors.cardSurfaceElevated)
                        .cornerRadius(VialrSpacing.radiusMd)
                        .overlay(
                            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                                .stroke(VialrColors.glassBorder, lineWidth: 1)
                        )
                }
                .accessibilityLabel("Quick 1-Tap Log Dose")
            }
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

    /// Completed State Hero when all today's doses are done.
    private var allDosesCompletedHeroCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack(alignment: .center, spacing: VialrSpacing.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36))
                    .foregroundColor(VialrColors.accentVitality)

                VStack(alignment: .leading, spacing: 2) {
                    Text("All Doses Completed")
                        .font(VialrTypography.title2)
                        .foregroundColor(VialrColors.textPrimary)

                    Text("You're 100% on track for today.")
                        .font(VialrTypography.subheadline)
                        .foregroundColor(VialrColors.textSecondary)
                }

                Spacer()

                MetricBadge(.success("\(viewModel.currentStreakDays)d Streak"))
            }

            if let future = viewModel.nextFutureDose {
                Divider()
                    .background(VialrColors.glassBorder)

                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13))
                        .foregroundColor(VialrColors.textTertiary)

                    Text("Next upcoming dose:")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textTertiary)

                    Text("\(future.compoundName)")
                        .font(VialrTypography.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(VialrColors.accentCyan)

                    Spacer()

                    Text(future.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard(isElevated: true)
    }

    // MARK: - 3. Current Protocol Section
    private var currentProtocolSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
            HStack {
                Text("CURRENT PROTOCOL")
                    .vialrEyebrow()

                Spacer()

                if let proto = viewModel.primaryProtocol {
                    Button {
                        onOpenProtocolDetail(proto)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Details")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentVitality)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(VialrColors.accentVitality)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)

            if let proto = viewModel.primaryProtocol {
                Button {
                    onOpenProtocolDetail(proto)
                } label: {
                    VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(proto.name)
                                    .font(VialrTypography.title3)
                                    .foregroundColor(VialrColors.textPrimary)

                                if !proto.goalSummary.isEmpty {
                                    Text(proto.goalSummary)
                                        .font(VialrTypography.subheadline)
                                        .foregroundColor(VialrColors.textSecondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            MetricBadge(proto.status == .active ? .success("Active") : .neutral(proto.status.rawValue))
                        }

                        // Cycle Progress Bar
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Cycle Progress: Day \(viewModel.primaryProtocolElapsedDays) of \(viewModel.primaryProtocolTotalDays)")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textTertiary)

                                Spacer()

                                Text("\(viewModel.primaryProtocolPercentComplete)%")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.accentVitality)
                            }

                            VialrProgressBar(
                                value: Double(viewModel.primaryProtocolPercentComplete) / 100.0,
                                tintColor: VialrColors.accentVitality
                            )
                        }
                        .padding(.vertical, 2)

                        // Compounds in Stack
                        HStack(spacing: 6) {
                            ForEach(proto.items.prefix(3)) { item in
                                let amountStr = item.doseAmount.truncatingRemainder(dividingBy: 1) == 0 ?
                                    String(format: "%.0f", item.doseAmount) :
                                    String(format: "%.1f", item.doseAmount)

                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(VialrColors.accentVitality)
                                        .frame(width: 5, height: 5)
                                    Text("\(item.compoundName) (\(amountStr) \(item.doseUnit.rawValue))")
                                        .font(VialrTypography.caption)
                                        .foregroundColor(VialrColors.textPrimary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusXs)
                            }
                        }
                    }
                    .padding(VialrSpacing.cardPadding)
                    .vialrCard()
                }
                .buttonStyle(.plain)
            } else {
                // No Active Protocol Empty State
                VStack(spacing: VialrSpacing.sm) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 28))
                        .foregroundColor(VialrColors.textTertiary)
                    Text("No Active Protocol Configured")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                    Text("Create or activate a protocol stack to begin tracking.")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .padding(VialrSpacing.lg)
                .frame(maxWidth: .infinity)
                .vialrCard()
            }
        }
    }

    // MARK: - 4. Compact Progress Section (3 High-Signal Metrics)
    private var compactProgressSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
            Text("PROTOCOL PROGRESS")
                .vialrEyebrow()
                .padding(.horizontal, 4)

            HStack(spacing: VialrSpacing.sm) {
                // 1. Adherence Metric
                compactMetricCard(
                    title: "Adherence",
                    value: "\(Int(viewModel.adherenceScore))%",
                    subtitle: "\(viewModel.currentStreakDays)d Streak",
                    icon: "flame.fill",
                    color: VialrColors.accentEmerald
                )

                // 2. Protocol Cycle Day
                compactMetricCard(
                    title: "Cycle Day",
                    value: "Day \(viewModel.primaryProtocolElapsedDays)",
                    subtitle: "of \(viewModel.primaryProtocolTotalDays) days",
                    icon: "calendar.badge.clock",
                    color: VialrColors.accentCyan
                )

                // 3. Today's Doses Completed
                compactMetricCard(
                    title: "Today's Doses",
                    value: "\(viewModel.completedDosesTodayCount) / \(max(1, viewModel.totalDosesTodayCount))",
                    subtitle: viewModel.scheduledTodayDoses.isEmpty ? "All complete" : "\(viewModel.scheduledTodayDoses.count) left",
                    icon: "checkmark.circle.fill",
                    color: VialrColors.accentVitality
                )
            }
        }
    }

    private func compactMetricCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)

                Text(title)
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textTertiary)
                    .lineLimit(1)
            }

            Text(value)
                .font(VialrTypography.metricSmall)
                .foregroundColor(VialrColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(VialrTypography.caption)
                .foregroundColor(VialrColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vialrCard()
    }

    // MARK: - 5. Inventory Status & Upcoming Events
    private var inventoryAndUpcomingSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
            Text("SUPPLIES & HORIZON")
                .vialrEyebrow()
                .padding(.horizontal, 4)

            VStack(spacing: VialrSpacing.sm) {
                // Inventory Status Strip
                HStack(spacing: VialrSpacing.sm) {
                    Image(systemName: "cylinder.split.1x2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(viewModel.inventorySummary.hasWarning ? VialrColors.accentAmber : VialrColors.accentVitality)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inventory Status")
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)

                        Text(viewModel.inventorySummary.summaryText)
                            .font(VialrTypography.footnote)
                            .foregroundColor(viewModel.inventorySummary.hasWarning ? VialrColors.accentAmber : VialrColors.textSecondary)
                    }

                    Spacer()

                    MetricBadge(
                        viewModel.inventorySummary.hasWarning ?
                            .warning("\(viewModel.inventorySummary.lowStockCount) Low") :
                            .success("\(viewModel.inventorySummary.activeVialsCount) Active")
                    )
                }
                .padding(VialrSpacing.md)
                .vialrCard()

                // Upcoming Events Preview
                ForEach(viewModel.upcomingEvents.prefix(2)) { event in
                    HStack(spacing: VialrSpacing.sm) {
                        Image(systemName: event.iconName)
                            .font(.system(size: 16))
                            .foregroundColor(event.badgeColor)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(VialrTypography.bodyMedium)
                                .foregroundColor(VialrColors.textPrimary)

                            Text("\(event.dateFormatted) • \(event.subtitle)")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textSecondary)
                        }

                        Spacer()

                        if let badge = event.badgeText {
                            MetricBadge(.custom(title: badge, color: event.badgeColor, icon: nil))
                        }
                    }
                    .padding(VialrSpacing.md)
                    .vialrCard()
                }
            }
        }
    }

    // MARK: - 6. Chronological "Today" Section
    private var todayChronologicalSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
            HStack {
                Text("TODAY'S TIMELINE")
                    .vialrEyebrow()

                Spacer()

                if let openTimeline = onOpenTimeline {
                    Button {
                        VialrHaptics.lightImpact()
                        openTimeline()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Full History")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentVitality)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(VialrColors.accentVitality)
                        }
                    }
                } else {
                    Text("\(viewModel.todayTimelineItems.count) Action\(viewModel.todayTimelineItems.count == 1 ? "" : "s")")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textTertiary)
                }
            }
            .padding(.horizontal, 4)

            if viewModel.todayTimelineItems.isEmpty {
                HStack(spacing: VialrSpacing.sm) {
                    Image(systemName: "calendar.badge.checkmark")
                        .foregroundColor(VialrColors.accentVitality)
                        .font(.system(size: 20))

                    Text("No further actions scheduled for today.")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)

                    Spacer()
                }
                .padding(VialrSpacing.md)
                .vialrCard()
            } else {
                VStack(spacing: VialrSpacing.xs) {
                    ForEach(viewModel.todayTimelineItems) { item in
                        todayTimelineRow(item)
                    }
                }
            }
        }
    }

    private func todayTimelineRow(_ item: TodayScheduleItem) -> some View {
        HStack(spacing: VialrSpacing.sm) {
            // Status Icon Indicator
            Image(systemName: item.status.iconName)
                .font(.system(size: 18))
                .foregroundColor(item.status.badgeColor)
                .frame(width: 24)

            // Timeline Item Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(VialrTypography.bodyMedium)
                        .foregroundColor(item.status == .completed ? VialrColors.textSecondary : VialrColors.textPrimary)

                    if item.status == .completed {
                        Text("• Completed")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.accentEmerald)
                    }
                }

                Text(item.subtitle)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            Spacer()

            // Timestamp / Quick CTA
            if item.status == .upNext, let dose = item.doseLog {
                Button {
                    onOpenQuickLog(dose)
                } label: {
                    Text("Log")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(Color.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(VialrColors.accentVitality)
                        .clipShape(Capsule())
                }
            } else {
                Text(item.timeFormatted)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }
}

// MARK: - Compatibility Alias
public typealias HomeScreenView = DashboardView

