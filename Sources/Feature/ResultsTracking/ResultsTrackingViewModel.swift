import SwiftUI
import Observation
import Domain
import Analytics
import Data

public enum TimeRangeFilter: String, CaseIterable, Identifiable, Sendable {
    case sevenDays = "7D"
    case fourteenDays = "14D"
    case thirtyDays = "30D"
    case ninetyDays = "90D"
    case oneYear = "1Y"
    case all = "ALL"

    public var id: String { rawValue }

    public var dayCount: Int? {
        switch self {
        case .sevenDays: return 7
        case .fourteenDays: return 14
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        case .oneYear: return 365
        case .all: return nil
        }
    }
}

public enum MovingAverageOverlayOption: String, CaseIterable, Identifiable, Sendable {
    case sma7 = "7D SMA"
    case sma14 = "14D SMA"
    case sma30 = "30D SMA"
    case ema = "14D EMA"
    case off = "None"

    public var id: String { rawValue }
}

@Observable
public final class ResultsTrackingViewModel: @unchecked Sendable {
    // MARK: - State Properties
    public var metricDefinitions: [MetricDefinition] = []
    public var selectedMetric: MetricDefinition?
    public var rawMeasurements: [Measurement] = []
    public var activeProtocols: [ProtocolModel] = []
    public var doseLogs: [DoseLog] = []

    // Time-Series & Derived Analytics (Guaranteed decoupled from raw data)
    public var analyticsSummary: ComprehensiveMetricAnalytics?
    public var masterReport: MasterAnalyticsReport?
    public var selectedTimeRange: TimeRangeFilter = .thirtyDays
    public var selectedMovingAverage: MovingAverageOverlayOption = .sma7
    public var showRawPointsOnChart: Bool = true
    public var showReferenceRangeBand: Bool = true
    public var showBaselineRule: Bool = true

    // Explainability & Audit Inspection
    public var selectedAuditTrail: CalculationAuditTrail?
    public var isExplainabilitySheetPresented: Bool = false

    // Sheets & Dialogs
    public var isLogMeasurementSheetPresented: Bool = false
    public var isCreateCustomMetricSheetPresented: Bool = false
    public var isProtocolComparisonSheetPresented: Bool = false
    public var isLoading: Bool = false
    public var errorMessage: String?

    // Repositories & Engines
    private let measurementRepo: MeasurementRepositoryProtocol
    private let metricDefRepo: MetricDefinitionRepositoryProtocol
    private let protocolRepo: ProtocolRepositoryProtocol
    private let doseRepo: DoseLogRepositoryProtocol
    private let engine = ResultsTrackingEngine()
    private let analyticsEngine = AnalyticsEngine()

    public init(
        measurementRepo: MeasurementRepositoryProtocol = LocalMeasurementRepository(),
        metricDefRepo: MetricDefinitionRepositoryProtocol = LocalMetricDefinitionRepository(),
        protocolRepo: ProtocolRepositoryProtocol = LocalProtocolRepository(),
        doseRepo: DoseLogRepositoryProtocol = LocalDoseLogRepository()
    ) {
        self.measurementRepo = measurementRepo
        self.metricDefRepo = metricDefRepo
        self.protocolRepo = protocolRepo
        self.doseRepo = doseRepo
    }

    // MARK: - Data Loading
    public func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            metricDefinitions = try await metricDefRepo.fetchAll()
            if selectedMetric == nil {
                selectedMetric = metricDefinitions.first(where: { $0.code == "body_weight" }) ?? metricDefinitions.first
            }

            activeProtocols = try await protocolRepo.fetchAll()
            doseLogs = try await doseRepo.fetchAll()
            await refreshSelectedMetricAnalytics()
        } catch {
            errorMessage = "Failed to load results tracking data: \(error.localizedDescription)"
        }
    }

    public func selectMetric(_ metric: MetricDefinition) async {
        selectedMetric = metric
        await refreshSelectedMetricAnalytics()
    }

    public func refreshSelectedMetricAnalytics() async {
        guard let metric = selectedMetric else { return }

        do {
            let allMeasurements = try await measurementRepo.fetchAll()
            // Filter raw measurements for the active metric (by code or matching type/name)
            rawMeasurements = allMeasurements.filter { m in
                if let code = m.customMetricCode, code == metric.code { return true }
                if m.type == metric.type && !metric.isCustom { return true }
                if m.name.lowercased() == metric.name.lowercased() { return true }
                return false
            }.sorted(by: { $0.dateRecorded < $1.dateRecorded })

            // Filter measurements by selected time range
            let filteredMeasurements: [Measurement]
            if let days = selectedTimeRange.dayCount {
                let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                filteredMeasurements = rawMeasurements.filter { $0.dateRecorded >= cutoff }
            } else {
                filteredMeasurements = rawMeasurements
            }

            // Generate non-destructive derived analytics
            analyticsSummary = engine.generateAnalyticsSummary(
                metric: metric,
                measurements: filteredMeasurements,
                doseLogs: doseLogs,
                protocols: activeProtocols
            )

            // Generate full deterministic master analytics report with explainability audit trails
            masterReport = analyticsEngine.generateMasterAnalytics(
                metric: metric,
                measurements: filteredMeasurements,
                doseLogs: doseLogs,
                protocols: activeProtocols,
                costs: [],
                targetGoal: nil
            )
        } catch {
            errorMessage = "Failed to compute analytics: \(error.localizedDescription)"
        }
    }

    // MARK: - Audit Trail Inspection Helper
    public func presentAuditTrail(_ audit: CalculationAuditTrail) {
        selectedAuditTrail = audit
        isExplainabilitySheetPresented = true
    }

    // MARK: - Measurement Logging (Zero-Latency Local Write)
    public func logMeasurement(
        value: Double,
        secondaryValue: Double? = nil,
        unit: String,
        date: Date = Date(),
        source: MeasurementSource = .manualEntry,
        protocolId: UUID? = nil,
        notes: String = ""
    ) async {
        guard let metric = selectedMetric else { return }

        let newMeasurement = Measurement(
            name: metric.name,
            type: metric.type,
            category: metric.category,
            value: value,
            secondaryValue: secondaryValue,
            unit: unit,
            dateRecorded: date,
            source: source,
            referenceRangeMin: metric.referenceRangeMin,
            referenceRangeMax: metric.referenceRangeMax,
            associatedProtocolId: protocolId,
            customMetricId: metric.isCustom ? metric.id : nil,
            customMetricCode: metric.code,
            notes: notes
        )

        do {
            try await measurementRepo.save(newMeasurement)
            await refreshSelectedMetricAnalytics()
        } catch {
            errorMessage = "Failed to save measurement: \(error.localizedDescription)"
        }
    }

    // MARK: - Custom Metric Creation
    public func createCustomMetric(
        name: String,
        category: MeasurementCategory = .custom,
        unit: String,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        targetDirection: TargetDirection = .decrease,
        iconName: String = "chart.xyaxis.line",
        colorHex: String = "#3B82F6",
        description: String = ""
    ) async {
        let newMetric = MetricDefinition.custom(
            name: name,
            category: category,
            defaultUnit: unit,
            referenceRangeMin: referenceRangeMin,
            referenceRangeMax: referenceRangeMax,
            targetDirection: targetDirection,
            iconName: iconName,
            colorHex: colorHex,
            metricDescription: description
        )

        do {
            try await metricDefRepo.save(newMetric)
            metricDefinitions = try await metricDefRepo.fetchAll()
            await selectMetric(newMetric)
        } catch {
            errorMessage = "Failed to create custom metric: \(error.localizedDescription)"
        }
    }

    // MARK: - Active Chart Moving Average Helper
    public var activeMovingAveragePoints: [MovingAveragePoint] {
        guard let summary = analyticsSummary else { return [] }
        switch selectedMovingAverage {
        case .sma7:
            return summary.movingAverages.first(where: { $0.windowDays == 7 && $0.calculationType == .timeWeighted })?.points ?? []
        case .sma14:
            return summary.movingAverages.first(where: { $0.windowDays == 14 })?.points ?? []
        case .sma30:
            return summary.movingAverages.first(where: { $0.windowDays == 30 && $0.calculationType == .timeWeighted })?.points ?? []
        case .ema:
            return summary.movingAverages.first(where: { $0.calculationType == .exponential })?.points ?? []
        case .off:
            return []
        }
    }
}
