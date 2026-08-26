import SwiftUI
import Observation
import Domain
import CalculationEngine
import DesignSystem

public struct QuickLogPreset: Identifiable, Sendable, Hashable {
    public let id: String
    public let compoundName: String
    public let defaultAmount: Double
    public let doseUnit: DoseUnit
    public let route: AdministrationRoute
    public let category: String
    public let colorHex: String

    public init(
        id: String = UUID().uuidString,
        compoundName: String,
        defaultAmount: Double,
        doseUnit: DoseUnit,
        route: AdministrationRoute = .subcutaneous,
        category: String = "Peptide",
        colorHex: String = "10E79D"
    ) {
        self.id = id
        self.compoundName = compoundName
        self.defaultAmount = defaultAmount
        self.doseUnit = doseUnit
        self.route = route
        self.category = category
        self.colorHex = colorHex
    }

    public static let standardPresets: [QuickLogPreset] = [
        QuickLogPreset(id: "bpc157_250", compoundName: "BPC-157", defaultAmount: 250, doseUnit: .mcg, route: .subcutaneous, category: "Healing", colorHex: "10E79D"),
        QuickLogPreset(id: "tb500_500", compoundName: "TB-500", defaultAmount: 500, doseUnit: .mcg, route: .subcutaneous, category: "Tissue", colorHex: "38BDF8"),
        QuickLogPreset(id: "cjc_ipam_200", compoundName: "CJC-1295 / Ipamorelin", defaultAmount: 200, doseUnit: .mcg, route: .subcutaneous, category: "GH Axis", colorHex: "A855F7"),
        QuickLogPreset(id: "tirzepatide_2_5", compoundName: "Tirzepatide", defaultAmount: 2.5, doseUnit: .mg, route: .subcutaneous, category: "Metabolic", colorHex: "FF9F0A"),
        QuickLogPreset(id: "semaglutide_0_25", compoundName: "Semaglutide", defaultAmount: 0.25, doseUnit: .mg, route: .subcutaneous, category: "Metabolic", colorHex: "34D399"),
        QuickLogPreset(id: "nad_50", compoundName: "NAD+", defaultAmount: 50, doseUnit: .mg, route: .subcutaneous, category: "Longevity", colorHex: "60A5FA"),
        QuickLogPreset(id: "ghk_cu_2", compoundName: "GHK-Cu", defaultAmount: 2.0, doseUnit: .mg, route: .subcutaneous, category: "Skin / Collagen", colorHex: "F472B6"),
        QuickLogPreset(id: "glutathione_200", compoundName: "Glutathione", defaultAmount: 200, doseUnit: .mg, route: .intramuscular, category: "Antioxidant", colorHex: "FBBF24")
    ]
}

@Observable
public final class LoggingViewModel: @unchecked Sendable {
    // Repositories & Engine
    public let doseRepo: DoseLogRepositoryProtocol
    public let protocolRepo: ProtocolRepositoryProtocol
    public let vialRepo: VialRepositoryProtocol
    public let siteEventRepo: InjectionSiteEventRepositoryProtocol
    public let doseLoggingEngine: DoseLoggingEngineProtocol

    private let siteRotationEngine: SiteRotationEngine
    private let adherenceCalculator: AdherenceCalculator

    // View State
    public var isLoading: Bool = false
    public var isSubmitting: Bool = false
    public var nextUpcomingDose: DoseLog?
    public var recommendedSite: InjectionSite?
    public var activeVials: [Vial] = []
    public var activeProtocols: [ProtocolModel] = []
    public var recentDoses: [DoseLog] = []
    public var presets: [QuickLogPreset] = QuickLogPreset.standardPresets
    public var weeklyAdherencePercentage: Double = 100.0
    public var currentStreakDays: Int = 7
    public var totalDosesLoggedCount: Int = 0
    public var selectedCompoundFilter: String? = nil
    public var successToastMessage: String? = nil
    public var errorMessage: String? = nil

    // Rapid Custom Input State
    public var customCompoundName: String = "BPC-157"
    public var customDoseAmount: Double = 250
    public var customDoseUnit: DoseUnit = .mcg
    public var customRoute: AdministrationRoute = .subcutaneous
    public var customNotes: String = ""

    public init(
        doseRepo: DoseLogRepositoryProtocol,
        protocolRepo: ProtocolRepositoryProtocol,
        vialRepo: VialRepositoryProtocol,
        siteEventRepo: InjectionSiteEventRepositoryProtocol,
        doseLoggingEngine: DoseLoggingEngineProtocol,
        siteRotationEngine: SiteRotationEngine = SiteRotationEngine(),
        adherenceCalculator: AdherenceCalculator = AdherenceCalculator()
    ) {
        self.doseRepo = doseRepo
        self.protocolRepo = protocolRepo
        self.vialRepo = vialRepo
        self.siteEventRepo = siteEventRepo
        self.doseLoggingEngine = doseLoggingEngine
        self.siteRotationEngine = siteRotationEngine
        self.adherenceCalculator = adherenceCalculator
    }

    public var filteredRecentDoses: [DoseLog] {
        guard let filter = selectedCompoundFilter, !filter.isEmpty else {
            return recentDoses
        }
        return recentDoses.filter { $0.compoundName.localizedCaseInsensitiveContains(filter) }
    }

    public func loadLoggingData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Fetch Doses
            let allDoses = try await doseRepo.fetchAll()
            self.totalDosesLoggedCount = allDoses.filter { $0.status == .taken }.count
            self.recentDoses = try await doseRepo.fetchRecent(limit: 30)

            // 2. Fetch Active Protocols & Next Upcoming Dose
            let protocols = try await protocolRepo.fetchActive()
            self.activeProtocols = protocols

            let now = Date()
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: now)
            guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return }

            let todayDoses = try await doseRepo.fetchForDateRange(start: startOfDay, end: endOfDay)
            self.nextUpcomingDose = todayDoses.first(where: { $0.status == .scheduled && $0.scheduledTimestamp >= now.addingTimeInterval(-3600) })
                ?? todayDoses.first(where: { $0.status == .scheduled })

            // 3. Calculate Recommended Injection Site
            let siteHistory = allDoses.filter { $0.status == .taken }
            let siteAnalysis = siteRotationEngine.analyzeRotation(history: siteHistory, currentDate: now)
            self.recommendedSite = siteAnalysis.first(where: { $0.isRecommended })?.site ?? InjectionSite.standardSites.first

            // 4. Fetch Active Vials
            self.activeVials = try await vialRepo.fetchActive()

            // 5. Build Dynamic Presets from Active Protocols + Standards
            var dynamicPresets = QuickLogPreset.standardPresets
            for proto in protocols {
                for comp in proto.compounds {
                    if !dynamicPresets.contains(where: { $0.compoundName.caseInsensitiveCompare(comp.compoundName) == .orderedSame }) {
                        let newPreset = QuickLogPreset(
                            id: "proto_\(comp.id.uuidString)",
                            compoundName: comp.compoundName,
                            defaultAmount: comp.doseAmount,
                            doseUnit: comp.doseUnit,
                            route: comp.route,
                            category: proto.name,
                            colorHex: "10E79D"
                        )
                        dynamicPresets.insert(newPreset, at: 0)
                    }
                }
            }
            self.presets = dynamicPresets

            // 6. Compute Adherence & Streak
            if !allDoses.isEmpty {
                let pastWeek = cal.date(byAdding: .day, value: -7, to: now) ?? now
                let weekDoses = try await doseRepo.fetchForDateRange(start: pastWeek, end: now)
                let takenCount = weekDoses.filter { $0.status == .taken }.count
                let scheduledCount = weekDoses.count
                self.weeklyAdherencePercentage = scheduledCount > 0 ? (Double(takenCount) / Double(scheduledCount)) * 100.0 : 100.0
                self.currentStreakDays = max(1, min(14, takenCount))
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /// Fast 1-Tap Scheduled Dose Logging: Executes under 1 second.
    public func quickLogScheduledDose() async -> DoseLoggingResult? {
        guard let scheduled = nextUpcomingDose else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let result = try await doseLoggingEngine.quickLogDirect(
                scheduledDose: scheduled,
                siteId: recommendedSite?.id
            )
            VialrHaptics.success()
            await loadLoggingData()
            self.successToastMessage = "Logged \(result.doseEvent.compoundName) \(formatDose(result.doseEvent.actualDoseAmount, unit: result.doseEvent.doseUnit))"
            return result
        } catch {
            VialrHaptics.error()
            self.errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Fast 1-Tap Preset Dose Logging.
    public func quickLogPreset(_ preset: QuickLogPreset) async -> DoseLoggingResult? {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let matchingVial = activeVials.first(where: {
                $0.compoundName.caseInsensitiveCompare(preset.compoundName) == .orderedSame && $0.currentVolumeRemainingMl > 0
            })

            let request = DoseConfirmationRequest(
                compoundId: UUID(),
                compoundName: preset.compoundName,
                plannedDoseAmount: preset.defaultAmount,
                actualDoseAmount: preset.defaultAmount,
                doseUnit: preset.doseUnit,
                injectionSiteId: recommendedSite?.id ?? "ab_r_uo",
                injectionSiteName: recommendedSite?.name ?? "Abdomen - Upper Right",
                vialId: matchingVial?.id,
                route: preset.route,
                actualTimestamp: Date(),
                isPRNOrUnscheduled: true,
                notes: "Quick preset logged via Log tab"
            )

            let result = try await doseLoggingEngine.logDose(request)
            VialrHaptics.success()
            await loadLoggingData()
            self.successToastMessage = "Logged \(preset.compoundName) \(formatDose(preset.defaultAmount, unit: preset.doseUnit))"
            return result
        } catch {
            VialrHaptics.error()
            self.errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Fast 1-Tap Repeat of Past Dose.
    public func repeatPastDose(_ previous: DoseLog) async -> DoseLoggingResult? {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let request = DoseConfirmationRequest(
                compoundId: previous.compoundId,
                compoundName: previous.compoundName,
                plannedDoseAmount: previous.doseAmount,
                actualDoseAmount: previous.doseAmount,
                doseUnit: previous.doseUnit,
                injectionSiteId: recommendedSite?.id ?? previous.injectionSiteId ?? "ab_r_uo",
                injectionSiteName: recommendedSite?.name ?? previous.injectionSiteName ?? "Abdomen - Upper Right",
                vialId: previous.vialId ?? activeVials.first(where: { $0.compoundName.caseInsensitiveCompare(previous.compoundName) == .orderedSame })?.id,
                route: previous.actualRoute,
                actualTimestamp: Date(),
                isPRNOrUnscheduled: true,
                notes: "Repeat dose logged via Log tab"
            )

            let result = try await doseLoggingEngine.logDose(request)
            VialrHaptics.success()
            await loadLoggingData()
            self.successToastMessage = "Repeated \(previous.compoundName) \(formatDose(previous.doseAmount, unit: previous.doseUnit))"
            return result
        } catch {
            VialrHaptics.error()
            self.errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Fast Custom Dose Logging.
    public func logCustomDose() async -> DoseLoggingResult? {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let matchingVial = activeVials.first(where: {
                $0.compoundName.caseInsensitiveCompare(customCompoundName) == .orderedSame && $0.currentVolumeRemainingMl > 0
            })

            let request = DoseConfirmationRequest(
                compoundId: UUID(),
                compoundName: customCompoundName,
                plannedDoseAmount: customDoseAmount,
                actualDoseAmount: customDoseAmount,
                doseUnit: customDoseUnit,
                injectionSiteId: recommendedSite?.id ?? "ab_r_uo",
                injectionSiteName: recommendedSite?.name ?? "Abdomen - Upper Right",
                vialId: matchingVial?.id,
                route: customRoute,
                actualTimestamp: Date(),
                isPRNOrUnscheduled: true,
                notes: customNotes.isEmpty ? "Direct dose log" : customNotes
            )

            let result = try await doseLoggingEngine.logDose(request)
            VialrHaptics.success()
            await loadLoggingData()
            self.successToastMessage = "Logged \(customCompoundName) \(formatDose(customDoseAmount, unit: customDoseUnit))"
            return result
        } catch {
            VialrHaptics.error()
            self.errorMessage = error.localizedDescription
            return nil
        }
    }

    public func deleteDose(id: UUID) async {
        do {
            try await doseRepo.delete(byId: id)
            VialrHaptics.lightImpact()
            await loadLoggingData()
            self.successToastMessage = "Dose record deleted"
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func formatDose(_ amount: Double, unit: DoseUnit) -> String {
        let amtStr = amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", amount) : String(format: "%.1f", amount)
        return "\(amtStr) \(unit.rawValue)"
    }
}
