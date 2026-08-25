import SwiftUI
import Domain
import DesignSystem

public struct DashboardView: View {
    @Bindable public var viewModel: DashboardViewModel
    public var onOpenQuickLog: (DoseLog?) -> Void
    public var onOpenReconstitution: () -> Void
    public var onOpenSiteRotation: () -> Void
    public var onOpenProtocolDetail: (ProtocolModel) -> Void

    public init(
        viewModel: DashboardViewModel,
        onOpenQuickLog: @escaping (DoseLog?) -> Void,
        onOpenReconstitution: @escaping () -> Void,
        onOpenSiteRotation: @escaping () -> Void,
        onOpenProtocolDetail: @escaping (ProtocolModel) -> Void
    ) {
        self.viewModel = viewModel
        self.onOpenQuickLog = onOpenQuickLog
        self.onOpenReconstitution = onOpenReconstitution
        self.onOpenSiteRotation = onOpenSiteRotation
        self.onOpenProtocolDetail = onOpenProtocolDetail
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Top Header Bar
                        headerBar

                        // Hero Next Dose Card
                        if let nextDose = viewModel.nextUpcomingDose {
                            heroNextDoseCard(nextDose)
                        } else {
                            allDosesCompletedCard
                        }

                        // Site Rotation Recommendation Pill
                        siteRotationRecommendationCard

                        // Quick Vitals Strip
                        vitalsStrip

                        // Active Protocols Section
                        activeProtocolsSection

                        // Today's Schedule Timeline
                        todaysTimelineSection

                        // Low Inventory Warnings (if any)
                        if !viewModel.lowStockSupplies.isEmpty {
                            lowStockBanner
                        }
                    }
                    .padding(.horizontal, VialrSpacing.md)
                    .padding(.bottom, 100) // Padding for floating tab bar
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

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Text("Protocol Dashboard")
                    .font(VialrTypography.largeHero)
                    .foregroundColor(VialrColors.textPrimary)
            }

            Spacer()

            // Quick Calculator Button
            Button {
                onOpenReconstitution()
            } label: {
                Image(systemName: "plus.forwardslash.minus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(VialrColors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(VialrColors.cardSurfaceElevated)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(VialrColors.glassBorder, lineWidth: 1)
                    )
            }
        }
        .padding(.top, VialrSpacing.sm)
    }

    // MARK: - Hero Next Dose Card
    private func heroNextDoseCard(_ dose: DoseLog) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                MetricBadge(.custom(title: "UP NEXT", color: VialrColors.accentTeal, icon: "clock.fill"))
                Spacer()
                Text("Scheduled for Today")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textTertiary)
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dose.compoundName)
                        .font(VialrTypography.title1)
                        .foregroundColor(VialrColors.textPrimary)

                    HStack(spacing: 8) {
                        Text("\(String(format: "%.0f", dose.doseAmount)) \(dose.doseUnit.rawValue)")
                            .font(VialrTypography.metricMedium)
                            .foregroundColor(VialrColors.accentEmerald)

                        Text("•")
                            .foregroundColor(VialrColors.textTertiary)

                        Text(dose.administrationRoute.shortName)
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                }

                Spacer()
            }

            Divider()
                .background(VialrColors.glassBorder)

            // Bottom CTA
            HStack(spacing: VialrSpacing.sm) {
                VialrButton("Log Dose Now", icon: "checkmark.circle.fill", style: .primary) {
                    onOpenQuickLog(dose)
                }

                Button {
                    Task {
                        await viewModel.quickLogDose(dose, siteId: nil)
                    }
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18))
                        .foregroundColor(VialrColors.accentTeal)
                        .frame(width: 52, height: 52)
                        .background(VialrColors.cardSurfaceElevated)
                        .cornerRadius(VialrSpacing.radiusMd)
                        .overlay(
                            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                                .stroke(VialrColors.glassBorder, lineWidth: 1)
                        )
                }
            }
        }
        .padding(VialrSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusXl, style: .continuous)
                .fill(VialrColors.heroCardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusXl)
                        .stroke(VialrColors.accentTeal.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var allDosesCompletedCard: some View {
        VStack(spacing: VialrSpacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundColor(VialrColors.accentEmerald)
            Text("All Doses Completed for Today")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)
            Text("Your protocol adherence streak is currently \(viewModel.currentStreakDays) days.")
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)
        }
        .padding(VialrSpacing.xl)
        .frame(maxWidth: .infinity)
        .vialrCard()
    }

    // MARK: - Site Rotation Pill
    private var siteRotationRecommendationCard: some View {
        Button {
            onOpenSiteRotation()
        } label: {
            HStack(spacing: VialrSpacing.sm) {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 20))
                    .foregroundColor(VialrColors.accentTeal)

                VStack(alignment: .leading, spacing: 2) {
                    Text("RECOMMENDED INJECTION TARGET")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text(viewModel.recommendedSite?.name ?? "Abdomen - Upper Right")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(VialrColors.textTertiary)
            }
            .padding(VialrSpacing.md)
            .vialrCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Vitals Strip
    private var vitalsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VialrSpacing.sm) {
                vitalCard(title: "Adherence", value: "\(Int(viewModel.adherenceScore))%", subtitle: "\(viewModel.currentStreakDays) Day Streak", icon: "flame.fill", color: VialrColors.accentEmerald)
                vitalCard(title: "Weight", value: "182.4", subtitle: "lbs (HealthKit)", icon: "scalemass.fill", color: VialrColors.accentCyan)
                vitalCard(title: "Resting HR", value: "54", subtitle: "bpm", icon: "heart.fill", color: VialrColors.accentRose)
                vitalCard(title: "Active Vials", value: "\(viewModel.activeVials.count)", subtitle: "In Use", icon: "cylinder.split.1x2.fill", color: VialrColors.accentViolet)
            }
        }
    }

    private func vitalCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                Text(title)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textSecondary)
            }
            Text(value)
                .font(VialrTypography.metricSmall)
                .foregroundColor(VialrColors.textPrimary)
            Text(subtitle)
                .font(VialrTypography.caption)
                .foregroundColor(VialrColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minWidth: 120, alignment: .leading)
        .vialrCard()
    }

    // MARK: - Active Protocols Section
    private var activeProtocolsSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("Active Stacks & Protocols")
                    .font(VialrTypography.title3)
                    .foregroundColor(VialrColors.textPrimary)
                Spacer()
                Text("\(viewModel.activeProtocols.count) Running")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textTertiary)
            }

            ForEach(viewModel.activeProtocols) { proto in
                Button {
                    onOpenProtocolDetail(proto)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(proto.name)
                                .font(VialrTypography.headline)
                                .foregroundColor(VialrColors.textPrimary)
                            Spacer()
                            MetricBadge(.success("Active"))
                        }

                        if !proto.goalSummary.isEmpty {
                            Text(proto.goalSummary)
                                .font(VialrTypography.subheadline)
                                .foregroundColor(VialrColors.textSecondary)
                        }

                        HStack(spacing: 6) {
                            ForEach(proto.items) { item in
                                Text("\(item.compoundName) (\(String(format: "%.0f", item.doseAmount)) \(item.doseUnit.rawValue))")
                                    .font(VialrTypography.caption)
                                    .foregroundColor(VialrColors.accentTeal)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(VialrColors.cardSurfaceElevated)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding(VialrSpacing.md)
                    .vialrCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Timeline Section
    private var todaysTimelineSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("Recent Activity & Log")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)

            ForEach(viewModel.recentCompletedDoses) { log in
                HStack(spacing: VialrSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(VialrColors.accentEmerald)
                        .font(.system(size: 18))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.compoundName)
                            .font(VialrTypography.bodyMedium)
                            .foregroundColor(VialrColors.textPrimary)

                        HStack(spacing: 4) {
                            Text("\(String(format: "%.0f", log.doseAmount)) \(log.doseUnit.rawValue)")
                                .foregroundColor(VialrColors.textSecondary)
                            if let site = log.injectionSiteName {
                                Text("• \(site)")
                                    .foregroundColor(VialrColors.textTertiary)
                            }
                        }
                        .font(VialrTypography.caption)
                    }

                    Spacer()

                    if let logged = log.loggedDate {
                        Text(logged, style: .time)
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }
                }
                .padding(VialrSpacing.sm)
                .vialrCard()
            }
        }
    }

    // MARK: - Low Stock Banner
    private var lowStockBanner: some View {
        HStack(spacing: VialrSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(VialrColors.accentAmber)

            VStack(alignment: .leading, spacing: 2) {
                Text("Low Supplies Detected")
                    .font(VialrTypography.subheadline)
                    .foregroundColor(VialrColors.textPrimary)
                Text("\(viewModel.lowStockSupplies.map(\.name).joined(separator: ", ")) running low.")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textSecondary)
            }

            Spacer()
        }
        .padding(VialrSpacing.md)
        .background(VialrColors.accentAmber.opacity(0.12))
        .cornerRadius(VialrSpacing.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                .stroke(VialrColors.accentAmber.opacity(0.3), lineWidth: 1)
        )
    }
}
