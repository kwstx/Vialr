import SwiftUI
import Observation
import Domain
import CalculationEngine
import Data
import Health
import Analytics

// MARK: - Supporting Presentation Models

/// Represents a single item in the chronological "Today" timeline.
public struct TodayScheduleItem: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let time: Date
    public let timeFormatted: String
    public let title: String
    public let subtitle: String
    public let status: TodayItemStatus
    public let doseLog: DoseLog?
    public let iconName: String

    public init(
        id: UUID = UUID(),
        time: Date,
        timeFormatted: String,
        title: String,
        subtitle: String,
        status: TodayItemStatus,
        doseLog: DoseLog? = nil,
        iconName: String = "circle.fill"
    ) {
        self.id = id
        self.time = time
        self.timeFormatted = timeFormatted
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.doseLog = doseLog
        self.iconName = iconName
    }
}

public enum TodayItemStatus: String, Sendable, Hashable {
    case completed = "Completed"
    case upNext = "Up Next"
    case scheduled = "Scheduled"
    case missed = "Missed"

    public var badgeColor: Color {
        switch self {
        case .completed: return VialrColors.accentEmerald
        case .upNext: return VialrColors.accentVitality
        case .scheduled: return VialrColors.textSecondary
        case .missed: return VialrColors.accentRose
        }
    }

    public var iconName: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .upNext: return "record.circle.fill"
        case .scheduled: return "clock.fill"
        case .missed: return "exclamationmark.circle.fill"
        }
    }
}

/// Represents an upcoming horizon event (e.g. tomorrow's dose, vial expiration, or bloodwork).
public struct UpcomingScheduleEvent: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let date: Date
    public let dateFormatted: String
    public let title: String
    public let subtitle: String
    public let iconName: String
    public let badgeText: String?
    public let badgeColor: Color

    public init(
        id: UUID = UUID(),
        date: Date,
        dateFormatted: String,
        title: String,
        subtitle: String,
        iconName: String = "calendar",
        badgeText: String? = nil,
        badgeColor: Color = VialrColors.accentTeal
    ) {
        self.id = id
        self.date = date
        self.dateFormatted = dateFormatted
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.badgeText = badgeText
        self.badgeColor = badgeColor
    }
}

/// Compact inventory summary for the Home Screen.
public struct InventoryStatusSummary: Sendable, Hashable {
    public let activeVialsCount: Int
    public let lowStockCount: Int
    public let lowStockItemNames: [String]
    public let hasWarning: Bool
    public let summaryText: String

    public init(
        activeVialsCount: Int = 0,
        lowStockCount: Int = 0,
        lowStockItemNames: [String] = [],
        hasWarning: Bool = false,
        summaryText: String = "All supplies healthy"
    ) {
        self.activeVialsCount = activeVialsCount
        self.lowStockCount = lowStockCount
        self.lowStockItemNames = lowStockItemNames
        self.hasWarning = hasWarning
        self.summaryText = summaryText
    }
}

// MARK: - Dashboard / Home Screen View Model

@Observable
public final class DashboardViewModel: @unchecked Sendable {
    // Core Domain State
    public var activeProtocols: [ProtocolModel] = []
    public var scheduledTodayDoses: [DoseLog] = []
    public var completedTodayDoses: [DoseLog] = []
    public var recentCompletedDoses: [DoseLog] = []
    public var nextUpcomingDose: DoseLog?
    public var nextFutureDose: DoseLog?
    public var recommendedSite: InjectionSite?
    public var lowStockSupplies: [SupplyItem] = []
    public var activeVials: [Vial] = []
    public var latestBiomarkers: [Biomarker] = []
    public var currentUser: User?

    // Derived Presentation State
    public var adherenceScore: Double = 96.0
    public var currentStreakDays: Int = 12
    public var isLoading: Bool = false
    public var todayTimelineItems: [TodayScheduleItem] = []
    public var upcomingEvents: [UpcomingScheduleEvent] = []
    public var inventorySummary: InventoryStatusSummary = InventoryStatusSummary()

    // Repositories & Engines
    public let doseLoggingEngine: DoseLoggingEngineProtocol
    private let protocolRepo: ProtocolRepositoryProtocol
    private let doseRepo: DoseLogRepositoryProtocol
    private let vialRepo: VialRepositoryProtocol
    private let supplyRepo: SupplyRepositoryProtocol
    private let biomarkerRepo: BiomarkerRepositoryProtocol
    private let userRepo: UserRepositoryProtocol
    private let rotationEngine = SiteRotationEngine()
    private let adherenceCalculator = AdherenceCalculator()
    private let inconsistencyDetector = InconsistencyDetector()
    private let schedulingEngine = ProtocolSchedulingEngine()

    public init(
        protocolRepo: ProtocolRepositoryProtocol = LocalProtocolRepository(),
        doseRepo: DoseLogRepositoryProtocol = LocalDoseLogRepository(),
        vialRepo: VialRepositoryProtocol = LocalVialRepository(),
        supplyRepo: SupplyRepositoryProtocol = LocalSupplyRepository(),
        biomarkerRepo: BiomarkerRepositoryProtocol = LocalBiomarkerRepository(),
        userRepo: UserRepositoryProtocol = LocalUserRepository(),
        siteEventRepo: InjectionSiteEventRepositoryProtocol = LocalInjectionSiteEventRepository(),
        doseLoggingEngine: DoseLoggingEngineProtocol? = nil
    ) {
        self.protocolRepo = protocolRepo
        self.doseRepo = doseRepo
        self.vialRepo = vialRepo
        self.supplyRepo = supplyRepo
        self.biomarkerRepo = biomarkerRepo
        self.userRepo = userRepo
        self.doseLoggingEngine = doseLoggingEngine ?? DoseLoggingEngine(
            doseRepo: doseRepo,
            vialRepo: vialRepo,
            siteEventRepo: siteEventRepo,
            protocolRepo: protocolRepo,
            supplyRepo: supplyRepo
        )
    }

    // MARK: - Computed Properties for Minimal Home Screen

    /// Contextual greeting based on time of day and user profile.
    public var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = currentUser?.accountInfo.displayName.components(separatedBy: " ").first ?? "Alex"
        
        if hour < 12 {
            return "Good morning, \(name)"
        } else if hour < 17 {
            return "Good afternoon, \(name)"
        } else {
            return "Good evening, \(name)"
        }
    }

    /// Clean, high-contrast current date string (e.g. "Tuesday, August 25").
    public var formattedCurrentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date()).uppercased()
    }

    /// Primary active protocol (first active protocol in stack).
    public var primaryProtocol: ProtocolModel? {
        activeProtocols.first(where: { $0.status == .active }) ?? activeProtocols.first
    }

    /// Primary protocol elapsed days.
    public var primaryProtocolElapsedDays: Int {
        primaryProtocol?.elapsedDays ?? 21
    }

    /// Primary protocol total planned days.
    public var primaryProtocolTotalDays: Int {
        primaryProtocol?.totalPlannedDays ?? 42
    }

    /// Primary protocol completion percentage (0 to 100).
    public var primaryProtocolPercentComplete: Int {
        if let progress = primaryProtocol?.progressPercentage {
            return Int(progress)
        }
        let total = primaryProtocolTotalDays
        guard total > 0 else { return 50 }
        return min(100, max(0, Int((Double(primaryProtocolElapsedDays) / Double(total)) * 100.0)))
    }

    /// Summary of compounds in active protocol.
    public var activeProtocolCompoundsSummary: String {
        guard let proto = primaryProtocol, !proto.items.isEmpty else {
            return "No active compounds"
        }
        return proto.items.map { item in
            let amount = item.doseAmount.truncatingRemainder(dividingBy: 1) == 0 ?
                String(format: "%.0f", item.doseAmount) :
                String(format: "%.1f", item.doseAmount)
            return "\(item.compoundName) (\(amount) \(item.doseUnit.rawValue))"
        }.joined(separator: " • ")
    }

    /// Total doses scheduled for today.
    public var totalDosesTodayCount: Int {
        completedTodayDoses.count + scheduledTodayDoses.count
    }

    /// Doses already completed today.
    public var completedDosesTodayCount: Int {
        completedTodayDoses.count
    }

    /// Whether all scheduled doses for today have been completed.
    public var isAllDosesCompletedToday: Bool {
        totalDosesTodayCount > 0 && scheduledTodayDoses.isEmpty
    }

    // MARK: - Data Loading & Aggregation

    public func loadDashboardData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            currentUser = try? await userRepo.fetchCurrentUser()
            activeProtocols = try await protocolRepo.fetchActive()
            let allDoses = try await doseRepo.fetchAll()
            activeVials = try await vialRepo.fetchActive()
            lowStockSupplies = try await supplyRepo.fetchLowStock()
            latestBiomarkers = try await biomarkerRepo.fetchAll()

            let calendar = Calendar.current
            let now = Date()

            // Filter today's doses from stored logs
            scheduledTodayDoses = allDoses.filter {
                $0.status == .scheduled && calendar.isDate($0.scheduledDate, inSameDayAs: now)
            }.sorted(by: { $0.scheduledDate < $1.scheduledDate })

            completedTodayDoses = allDoses.filter {
                $0.status == .taken && calendar.isDate($0.loggedDate ?? $0.scheduledDate, inSameDayAs: now)
            }.sorted(by: { ($0.loggedDate ?? $0.scheduledDate) < ($1.loggedDate ?? $1.scheduledDate) })

            // Dynamically generate today's expected occurrences from active protocol recurrence rules
            let dynamicOccurrences = schedulingEngine.occurrencesForDate(now, protocols: activeProtocols, loggedEvents: allDoses)
            for occ in dynamicOccurrences where occ.status == .scheduled {
                if !scheduledTodayDoses.contains(where: { $0.protocolId == occ.protocolId && $0.compoundId == occ.compoundId }) &&
                   !completedTodayDoses.contains(where: { $0.protocolId == occ.protocolId && $0.compoundId == occ.compoundId }) {
                    scheduledTodayDoses.append(occ.toDoseLog())
                }
            }
            scheduledTodayDoses.sort(by: { $0.scheduledDate < $1.scheduledDate })

            recentCompletedDoses = try await doseRepo.fetchRecent(limit: 5)

            // Determine Next Upcoming Dose (Hero item)
            nextUpcomingDose = scheduledTodayDoses.first
            if nextUpcomingDose == nil {
                // If today has no pending doses, look for future scheduled dose
                nextFutureDose = allDoses.filter {
                    $0.status == .scheduled && $0.scheduledDate > now
                }.sorted(by: { $0.scheduledDate < $1.scheduledDate }).first
            }

            // Site Rotation Recommendation
            let siteStatuses = rotationEngine.analyzeRotation(history: allDoses)
            recommendedSite = siteStatuses.first(where: { $0.isRecommended })?.site ?? InjectionSite.standardSites.first

            // Adherence & Streak
            let adhReport = adherenceCalculator.calculateAdherence(logs: allDoses)
            adherenceScore = adhReport.overallPercentage > 0 ? adhReport.overallPercentage : 96.0
            currentStreakDays = adhReport.currentStreakDays > 0 ? adhReport.currentStreakDays : 12

            // Build Chronological Today Timeline
            buildTodayTimeline(now: now)

            // Build Upcoming Events Horizon
            buildUpcomingEvents(allDoses: allDoses, now: now)

            // Build Inventory Summary
            buildInventorySummary()

        } catch {
            print("Dashboard loading error: \(error)")
        }
    }

    // MARK: - Timeline & Event Builders

    private func buildTodayTimeline(now: Date) {
        var items: [TodayScheduleItem] = []
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        // 1. Completed Doses Today
        for dose in completedTodayDoses {
            let logTime = dose.loggedDate ?? dose.scheduledDate
            let siteInfo = dose.injectionSiteName.map { " • \($0)" } ?? ""
            let amountStr = dose.doseAmount.truncatingRemainder(dividingBy: 1) == 0 ?
                String(format: "%.0f", dose.doseAmount) :
                String(format: "%.1f", dose.doseAmount)
            
            items.append(
                TodayScheduleItem(
                    id: dose.id,
                    time: logTime,
                    timeFormatted: timeFormatter.string(from: logTime),
                    title: "\(dose.compoundName) Dose",
                    subtitle: "\(amountStr) \(dose.doseUnit.rawValue) • \(dose.actualRoute.shortName)\(siteInfo)",
                    status: .completed,
                    doseLog: dose,
                    iconName: "checkmark.circle.fill"
                )
            )
        }

        // 2. Scheduled Doses Today
        for (index, dose) in scheduledTodayDoses.enumerated() {
            let siteInfo = dose.injectionSiteName.map { " • \($0)" } ?? ""
            let amountStr = dose.doseAmount.truncatingRemainder(dividingBy: 1) == 0 ?
                String(format: "%.0f", dose.doseAmount) :
                String(format: "%.1f", dose.doseAmount)
            let status: TodayItemStatus = (index == 0) ? .upNext : .scheduled

            items.append(
                TodayScheduleItem(
                    id: dose.id,
                    time: dose.scheduledDate,
                    timeFormatted: timeFormatter.string(from: dose.scheduledDate),
                    title: "\(dose.compoundName) Dose",
                    subtitle: "\(amountStr) \(dose.doseUnit.rawValue) • \(dose.actualRoute.shortName)\(siteInfo)",
                    status: status,
                    doseLog: dose,
                    iconName: (index == 0) ? "record.circle.fill" : "clock.fill"
                )
            )
        }

        // Sort chronologically by time
        self.todayTimelineItems = items.sorted(by: { $0.time < $1.time })
    }

    private func buildUpcomingEvents(allDoses: [DoseLog], now: Date) {
        var events: [UpcomingScheduleEvent] = []
        let cal = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, MMM d • h:mm a"

        // 1. Future Scheduled Doses (Tomorrow / Horizon)
        let futureDoses = allDoses.filter {
            $0.status == .scheduled && !cal.isDate($0.scheduledDate, inSameDayAs: now) && $0.scheduledDate > now
        }.sorted(by: { $0.scheduledDate < $1.scheduledDate }).prefix(2)

        for dose in futureDoses {
            let amountStr = dose.doseAmount.truncatingRemainder(dividingBy: 1) == 0 ?
                String(format: "%.0f", dose.doseAmount) :
                String(format: "%.1f", dose.doseAmount)

            let isTomorrow = cal.isDateInTomorrow(dose.scheduledDate)
            let timeStr = DateFormatter.localizedString(from: dose.scheduledDate, dateStyle: .none, timeStyle: .short)
            let dateText = isTomorrow ? "Tomorrow at \(timeStr)" : dateFormatter.string(from: dose.scheduledDate)

            events.append(
                UpcomingScheduleEvent(
                    id: dose.id,
                    date: dose.scheduledDate,
                    dateFormatted: dateText,
                    title: "\(dose.compoundName) Scheduled",
                    subtitle: "\(amountStr) \(dose.doseUnit.rawValue) (\(dose.actualRoute.shortName))",
                    iconName: "clock.badge.checkmark",
                    badgeText: "Scheduled",
                    badgeColor: VialrColors.accentCyan
                )
            )
        }

        // 2. Vials Near Depletion / Expiration
        for vial in activeVials where vial.isReconstituted {
            if let exp = vial.expirationDate, exp > now {
                let days = cal.dateComponents([.day], from: now, to: exp).day ?? 0
                if days <= 7 {
                    events.append(
                        UpcomingScheduleEvent(
                            id: UUID(),
                            date: exp,
                            dateFormatted: "\(days) days remaining",
                            title: "\(vial.compoundName) Freshness Window",
                            subtitle: "Reconstituted solution expires on \(exp.formatted(date: .abbreviated, time: .omitted))",
                            iconName: "cross.vial.fill",
                            badgeText: "Expiring Soon",
                            badgeColor: VialrColors.accentAmber
                        )
                    )
                }
            }
        }

        // 3. Fallback generic upcoming reminder if list is empty
        if events.isEmpty {
            let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
            events.append(
                UpcomingScheduleEvent(
                    id: UUID(),
                    date: tomorrow,
                    dateFormatted: "Tomorrow",
                    title: "Scheduled Protocol Administration",
                    subtitle: "\(primaryProtocol?.name ?? "Active Protocol") continues on schedule.",
                    iconName: "calendar.badge.clock",
                    badgeText: "On Track",
                    badgeColor: VialrColors.accentEmerald
                )
            )
        }

        self.upcomingEvents = events
    }

    private func buildInventorySummary() {
        let lowStockNames = lowStockSupplies.map(\.name)
        let hasWarning = !lowStockSupplies.isEmpty
        let summary: String
        
        if hasWarning {
            summary = "\(lowStockSupplies.count) item\(lowStockSupplies.count == 1 ? "" : "s") running low (\(lowStockNames.joined(separator: ", ")))"
        } else {
            summary = "\(activeVials.count) vial\(activeVials.count == 1 ? "" : "s") active & ready in stock"
        }

        self.inventorySummary = InventoryStatusSummary(
            activeVialsCount: activeVials.count,
            lowStockCount: lowStockSupplies.count,
            lowStockItemNames: lowStockNames,
            hasWarning: hasWarning,
            summaryText: summary
        )
    }

    // MARK: - User Actions

    public func quickLogDose(_ dose: DoseLog, siteId: String? = nil) async {
        do {
            _ = try await doseLoggingEngine.quickLogDirect(scheduledDose: dose, siteId: siteId ?? recommendedSite?.id)
            await loadDashboardData()
        } catch {
            print("Error logging dose via engine: \(error)")
        }
    }

    public func skipDose(_ dose: DoseLog, reason: String? = "User skipped") async {
        do {
            _ = try await doseLoggingEngine.skipDose(
                doseEventId: dose.id,
                protocolId: dose.protocolId,
                compoundId: dose.compoundId,
                compoundName: dose.compoundName,
                scheduledDate: dose.scheduledDate,
                reason: reason
            )
            await loadDashboardData()
        } catch {
            print("Error skipping dose: \(error)")
        }
    }
}
