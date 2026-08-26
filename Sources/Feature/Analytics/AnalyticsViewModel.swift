import SwiftUI
import Observation
import Domain
import Analytics
import Data

@Observable
public final class AnalyticsViewModel: @unchecked Sendable {
    public var clearanceData: [HalfLifeEstimator.SerumDataPoint] = []
    public var adherenceReport: AdherenceCalculator.AdherenceReport?
    public var explainableAdherence: ExplainableAdherence?
    public var correlationInsights: [CorrelationEngine.CorrelationInsight] = []
    public var spendSummary: CostAnalyticsEngine.SpendSummary?
    public var explainableSpend: ExplainableCostMetrics?
    public var biomarkers: [Biomarker] = []
    public var isLoading: Bool = false

    // Explainability & Audit Inspection
    public var selectedAuditTrail: CalculationAuditTrail?
    public var isExplainabilitySheetPresented: Bool = false

    private let doseRepo: DoseLogRepositoryProtocol
    private let biomarkerRepo: BiomarkerRepositoryProtocol
    private let symptomRepo: SymptomRepositoryProtocol
    private let costRepo: CostRepositoryProtocol

    private let halfLifeEstimator = HalfLifeEstimator()
    private let adherenceCalculator = AdherenceCalculator()
    private let correlationEngine = CorrelationEngine()
    private let costEngine = CostAnalyticsEngine()
    private let analyticsEngine = AnalyticsEngine()

    public init(
        doseRepo: DoseLogRepositoryProtocol = LocalDoseLogRepository(),
        biomarkerRepo: BiomarkerRepositoryProtocol = LocalBiomarkerRepository(),
        symptomRepo: SymptomRepositoryProtocol = LocalSymptomRepository(),
        costRepo: CostRepositoryProtocol = LocalCostRepository()
    ) {
        self.doseRepo = doseRepo
        self.biomarkerRepo = biomarkerRepo
        self.symptomRepo = symptomRepo
        self.costRepo = costRepo
    }

    public func presentAuditTrail(_ audit: CalculationAuditTrail) {
        selectedAuditTrail = audit
        isExplainabilitySheetPresented = true
    }

    public func loadAnalytics() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let doses = try await doseRepo.fetchAll()
            biomarkers = try await biomarkerRepo.fetchAll()
            let symptoms = try await symptomRepo.fetchAll()
            let costs = try await costRepo.fetchAll()

            // 1. Adherence (Legacy + Explainable Deterministic)
            adherenceReport = adherenceCalculator.calculateAdherence(logs: doses)
            explainableAdherence = analyticsEngine.calculateAdherence(doseLogs: doses, calendar: .current)

            // 2. Half-Life Pharmacokinetics curve (Past 7 days to +3 days forecast)
            let cal = Calendar.current
            let now = Date()
            let start = cal.date(byAdding: .day, value: -7, to: now) ?? now
            let end = cal.date(byAdding: .day, value: 3, to: now) ?? now

            clearanceData = halfLifeEstimator.estimateClearanceCurve(
                doseLogs: doses.filter { $0.compoundName.contains("BPC") },
                halfLifeHours: 4.0,
                compoundName: "BPC-157",
                startDate: start,
                endDate: end,
                intervalHours: 6
            )

            // 3. Correlations
            correlationInsights = correlationEngine.evaluateCorrelations(
                doseLogs: doses,
                biomarkers: biomarkers,
                symptoms: symptoms
            )

            // 4. Financials (Legacy + Explainable Deterministic)
            spendSummary = costEngine.computeSpend(costs: costs)
            explainableSpend = analyticsEngine.calculateCostMetrics(
                costs: costs.map { CostEvent(title: $0.title, category: $0.category, amountUsd: $0.amountUsd, dateIncurred: $0.dateIncurred, vendor: $0.vendor, notes: $0.notes) },
                doses: doses,
                elapsedDays: 30
            )
        } catch {
            print("Failed to load analytics: \(error)")
        }
    }
}
