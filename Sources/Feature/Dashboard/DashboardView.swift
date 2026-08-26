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

    @Namespace private var dashboardNamespace

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
                    VStack(spacing: VialrSpacing.lg) {
                        // 1. Top Header Bar (Date + Minimal Greeting)
                        headerSection

                        // 2. Primary Hero Action Card ("What do I need to do right now?")
                        if let nextDose = viewModel.nextUpcomingDose {
                            heroNextDoseCard(nextDose)
                                .transition(VialrAnimations.modalTransition)
                        } else {
                            allDosesCompletedHeroCard
                                .transition(VialrAnimations.modalTransition)
                        }

                        // 3. Current Protocol Stack & Cycle Progression
                        currentProtocolSection

                        // 4. Three High-Signal Numerical Metrics
                        glanceableMetricsSection

                        // 5. Supplies & Horizon Status
                        suppliesAndHorizonSection

                        // 6. Chronological Today Timeline
                        todayTimelineSection
                    }
                    .padding(.horizontal, VialrSpacing.screenHorizontal)
                    .padding(.bottom, 110) // Space for floating tab bar
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadDashboardData()
            }
            .refreshable {
                VialrHaptics.lightImpact()
                await viewModel.loadDashboardData()
            }
        }
    }

    // MARK: - 1. Top Header Bar (Date + Greeting + Fast Actions)
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.formattedCurrentDate)
                    .font(VialrTypography.eyebrow)
                    .tracking(1.4)
                    .foregroundColor(VialrColors.accentVitality)

                Text(viewModel.greeting)
                    .font(VialrTypography.largeHero)
                    .foregroundColor(VialrColors.textPrimary)
                    .tracking(-0.5)
            }

            Spacer()

            HStack(spacing: 8) {
                // Quick Lab Results Action
                Button {
                    VialrHaptics.lightImpact()
                    onOpenBloodwork?()
                } label: {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(VialrColors.accentRose)
                        .frame(width: 40, height: 40)
                        .background(VialrColors.cardSurfaceElevated)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(VialrColors.glassBorder, lineWidth: 1))
                }
                .accessibilityLabel("Open Bloodwork & Lab Hub")

                // Quick Reconstitution Calculator Action
                Button {
                    VialrHaptics.lightImpact()
                    onOpenReconstitution()
                } label: {
                    Image(systemName: "plus.forwardslash.minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(VialrColors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(VialrColors.cardSurfaceElevated)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(VialrColors.glassBorder, lineWidth: 1))
                }
                .accessibilityLabel("Open Reconstitution Calculator")
            }
        }
        .padding(.top, VialrSpacing.xs)
    }

    // MARK: - 2. Hero Action Card: Next Dose (High Signal, Large Numbers, 1-Tap Log)
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
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(VialrColors.accentVitality.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(VialrColors.accentVitality.opacity(0.3), lineWidth: 1))

                Spacer()

                Text("Today")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textTertiary)
            }

            // Compound Name & Massive Dosage Number
            VStack(alignment: .leading, spacing: 4) {
                Text(dose.compoundName)
                    .font(VialrTypography.title1)
                    .foregroundColor(VialrColors.textPrimary)
                    .tracking(-0.3)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(formatAmount(dose.doseAmount))
                        .font(VialrTypography.metricLarge)
                        .foregroundColor(VialrColors.accentVitality)
                        .tracking(-0.5)

                    Text(dose.doseUnit.rawValue)
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.accentVitality)

                    Text("•")
                        .foregroundColor(VialrColors.textTertiary)
                        .padding(.horizontal, 2)

                    Text(dose.administrationRoute.shortName)
                        .font(VialrTypography.subheadlineBold)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

            // Injection Site Recommendation Callout
            Button {
                VialrHaptics.lightImpact()
                onOpenSiteRotation()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cross.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(VialrColors.accentVitality)

                    Text("SITE:")
                        .font(VialrTypography.eyebrowMono)
                        .foregroundColor(VialrColors.textTertiary)

                    Text(viewModel.recommendedSite?.name ?? "Abdomen - Upper Right")
                        .font(VialrTypography.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(VialrColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(VialrColors.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(VialrColors.cardSurfaceSubtle)
                .cornerRadius(VialrSpacing.radiusSm)
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                        .stroke(VialrColors.glassBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Divider()
                .background(VialrColors.glassBorder)

            // Primary Interactive CTAs (Fast 1-Tap + Full Bottom Sheet)
            HStack(spacing: VialrSpacing.sm) {
                // Main Fast 1-Tap Log Button
                Button {
                    VialrHaptics.doseConfirmed()
                    Task {
                        // Instant optimistic local update
                        await viewModel.quickLogDose(dose, siteId: nil)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Log Dose Now")
                            .font(VialrTypography.headline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: VialrSpacing.buttonHeight)
                    .background(VialrColors.accentVitality)
                    .cornerRadius(VialrSpacing.radiusMd)
                }
                .buttonStyle(VialrButtonPressStyle())

                // Custom Details / Adjust Button (Opens Bottom Sheet)
                Button {
                    VialrHaptics.lightImpact()
                    onOpenQuickLog(dose)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(VialrColors.textPrimary)
                        .frame(width: VialrSpacing.buttonHeight, height: VialrSpacing.buttonHeight)
                        .background(VialrColors.cardSurfaceElevated)
                        .cornerRadius(VialrSpacing.radiusMd)
                        .overlay(
                            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                                .stroke(VialrColors.glassBorder, lineWidth: 1)
                        )
                }
                .accessibilityLabel("Adjust dose details before logging")
            }
        }
        .padding(VialrSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusLg, style: .continuous)
                .fill(VialrColors.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusLg, style: .continuous)
                        .stroke(VialrColors.accentVitality.opacity(0.3), lineWidth: 1.2)
                )
        )
    }

    /// Completed State Hero when all today's doses are done.
    private var allDosesCompletedHeroCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack(alignment: .center, spacing: VialrSpacing.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32))
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
                        .font(.system(size: 12))
                        .foregroundColor(VialrColors.textTertiary)

                    Text("NEXT:")
                        .font(VialrTypography.eyebrowMono)
                        .foregroundColor(VialrColors.textTertiary)

                    Text(future.compoundName)
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

    // MARK: - 3. Current Protocol Stack Section
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(proto.name)
                                    .font(VialrTypography.headline)
                                    .foregroundColor(VialrColors.textPrimary)

                                if !proto.goalSummary.isEmpty {
                                    Text(proto.goalSummary)
                                        .font(VialrTypography.caption)
                                        .foregroundColor(VialrColors.textSecondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            MetricBadge(proto.status == .active ? .success("Active") : .neutral(proto.status.rawValue))
                        }

                        // Cycle Progress Bar with Large Percentage
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Cycle: Day \(viewModel.primaryProtocolElapsedDays) of \(viewModel.primaryProtocolTotalDays)")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.textTertiary)

                                Spacer()

                                Text("\(viewModel.primaryProtocolPercentComplete)%")
                                    .font(VialrTypography.headline)
                                    .fontWeight(.bold)
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
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(VialrColors.accentVitality)
                                        .frame(width: 5, height: 5)
                                    Text("\(item.compoundName) (\(formatAmount(item.doseAmount)) \(item.doseUnit.rawValue))")
                                        .font(VialrTypography.caption)
                                        .foregroundColor(VialrColors.textPrimary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
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
                VStack(spacing: VialrSpacing.sm) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 24))
                        .foregroundColor(VialrColors.textTertiary)
                    Text("No Active Protocol")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                    Text("Create a protocol stack to begin automated scheduling.")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)
                }
                .padding(VialrSpacing.lg)
                .frame(maxWidth: .infinity)
                .vialrCard()
            }
        }
    }

    // MARK: - 4. Glanceable High-Signal Numerical Metrics (Large Numbers, Short Labels)
    private var glanceableMetricsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
            Text("PROTOCOL STATS")
                .vialrEyebrow()
                .padding(.horizontal, 4)

            HStack(spacing: VialrSpacing.sm) {
                // 1. Adherence Metric
                glanceableStatCard(
                    label: "ADHERENCE",
                    value: "\(Int(viewModel.adherenceScore))%",
                    subtitle: "\(viewModel.currentStreakDays)d Streak",
                    icon: "flame.fill",
                    color: VialrColors.accentEmerald
                )

                // 2. Protocol Cycle Day
                glanceableStatCard(
                    label: "CYCLE DAY",
                    value: "Day \(viewModel.primaryProtocolElapsedDays)",
                    subtitle: "of \(viewModel.primaryProtocolTotalDays)d",
                    icon: "calendar.badge.clock",
                    color: VialrColors.accentCyan
                )

                // 3. Today's Doses Completed
                glanceableStatCard(
                    label: "TODAY",
                    value: "\(viewModel.completedDosesTodayCount) / \(max(1, viewModel.totalDosesTodayCount))",
                    subtitle: viewModel.scheduledTodayDoses.isEmpty ? "All done" : "\(viewModel.scheduledTodayDoses.count) left",
                    icon: "checkmark.circle.fill",
                    color: VialrColors.accentVitality
                )
            }
        }
    }

    private func glanceableStatCard(label: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)

                Text(label)
                    .font(VialrTypography.eyebrowMono)
                    .foregroundColor(VialrColors.textTertiary)
                    .lineLimit(1)
            }

            Text(value)
                .font(VialrTypography.metricMedium)
                .foregroundColor(VialrColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(subtitle)
                .font(VialrTypography.caption)
                .foregroundColor(VialrColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vialrCard()
    }

    // MARK: - 5. Supplies & Horizon Status
    private var suppliesAndHorizonSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.xs) {
            Text("SUPPLIES & HORIZON")
                .vialrEyebrow()
                .padding(.horizontal, 4)

            VStack(spacing: VialrSpacing.sm) {
                // Inventory Status Strip
                HStack(spacing: VialrSpacing.sm) {
                    Image(systemName: "cylinder.split.1x2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(viewModel.inventorySummary.hasWarning ? VialrColors.accentAmber : VialrColors.accentVitality)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inventory Status")
                            .font(VialrTypography.subheadlineBold)
                            .foregroundColor(VialrColors.textPrimary)

                        Text(viewModel.inventorySummary.summaryText)
                            .font(VialrTypography.caption)
                            .foregroundColor(viewModel.inventorySummary.hasWarning ? VialrColors.accentAmber : VialrColors.textSecondary)
                    }

                    Spacer()

                    MetricBadge(
                        viewModel.inventorySummary.hasWarning ?
                            .warning("\(viewModel.inventorySummary.lowStockCount) Low") :
                            .success("\(viewModel.inventorySummary.activeVialsCount) Active")
                    )
                }
                .padding(VialrSpacing.sm)
                .vialrCard()

                // Upcoming Events Preview
                ForEach(viewModel.upcomingEvents.prefix(2)) { event in
                    HStack(spacing: VialrSpacing.sm) {
                        Image(systemName: event.iconName)
                            .font(.system(size: 14))
                            .foregroundColor(event.badgeColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(VialrTypography.footnote)
                                .fontWeight(.semibold)
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
                    .padding(VialrSpacing.sm)
                    .vialrCard()
                }
            }
        }
    }

    // MARK: - 6. Chronological Today Timeline
    private var todayTimelineSection: some View {
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
                }
            }
            .padding(.horizontal, 4)

            if viewModel.todayTimelineItems.isEmpty {
                HStack(spacing: VialrSpacing.sm) {
                    Image(systemName: "calendar.badge.checkmark")
                        .foregroundColor(VialrColors.accentVitality)
                        .font(.system(size: 18))

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
                .font(.system(size: 16))
                .foregroundColor(item.status.badgeColor)
                .frame(width: 22)

            // Timeline Item Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(VialrTypography.footnote)
                        .fontWeight(.semibold)
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
                    VialrHaptics.lightImpact()
                    onOpenQuickLog(dose)
                } label: {
                    Text("Log")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(Color.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(VialrColors.accentVitality)
                        .clipShape(Capsule())
                }
            } else {
                Text(item.timeFormatted)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }
        }
        .padding(VialrSpacing.sm)
        .vialrCard()
    }

    private func formatAmount(_ amount: Double) -> String {
        amount.truncatingRemainder(dividingBy: 1) == 0 ?
            String(format: "%.0f", amount) :
            String(format: "%.1f", amount)
    }
}

// MARK: - Compatibility Alias
public typealias HomeScreenView = DashboardView
