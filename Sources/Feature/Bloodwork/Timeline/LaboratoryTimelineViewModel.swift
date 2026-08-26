import SwiftUI
import Observation
import Domain
import Data
import CalculationEngine
import Analytics

public enum TimelineTimeRange: String, CaseIterable, Identifiable, Sendable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "ALL"

    public var id: String { rawValue }

    public var dayCount: Int? {
        switch self {
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        case .all: return nil
        }
    }
}

public enum EventStreamFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All Events"
    case labsOnly = "Labs Only"
    case protocolsOnly = "Protocols & Changes"
    case dosesOnly = "Doses"
    case measurementsOnly = "Measurements"

    public var id: String { rawValue }
}

@Observable
public final class LaboratoryTimelineViewModel: @unchecked Sendable {
    // MARK: - Published State
    public var analysis: LaboratoryTimelineAnalysis = LaboratoryTimelineAnalysis()
    public var isLoading: Bool = false
    public var selectedBiomarker: String? = nil
    public var selectedTimeRange: TimelineTimeRange = .all
    public var isProtocolOverlayEnabled: Bool = true
    public var isReferenceRangeVisible: Bool = true
    public var isDoseDensityVisible: Bool = true
    public var selectedEventFilter: EventStreamFilter = .all
    public var selectedAlignedItem: AlignedTimelineItem? = nil
    public var selectedLabPoint: LabTimeSeriesPoint? = nil
    public var isShareSheetPresented: Bool = false

    // Raw Domain Cache
    public var cachedPanels: [LabPanel] = []
    public var cachedProtocols: [ProtocolModel] = []
    public var cachedRevisions: [ProtocolRevision] = []
    public var cachedDoseLogs: [DoseLog] = []
    public var cachedMeasurements: [Measurement] = []
    public var cachedBiomarkers: [Biomarker] = []

    // Repositories & Engine
    private let labPanelRepo: LabPanelRepositoryProtocol
    private let protocolRepo: ProtocolRepositoryProtocol
    private let doseLogRepo: DoseLogRepositoryProtocol
    private let measurementRepo: MeasurementRepositoryProtocol
    private let biomarkerRepo: BiomarkerRepositoryProtocol
    private let engine: LaboratoryTimelineEngine

    public init(
        labPanelRepo: LabPanelRepositoryProtocol = LocalLabPanelRepository(),
        protocolRepo: ProtocolRepositoryProtocol = LocalProtocolRepository(),
        doseLogRepo: DoseLogRepositoryProtocol = LocalDoseLogRepository(),
        measurementRepo: MeasurementRepositoryProtocol = LocalMeasurementRepository(),
        biomarkerRepo: BiomarkerRepositoryProtocol = LocalBiomarkerRepository(),
        engine: LaboratoryTimelineEngine = LaboratoryTimelineEngine()
    ) {
        self.labPanelRepo = labPanelRepo
        self.protocolRepo = protocolRepo
        self.doseLogRepo = doseLogRepo
        self.measurementRepo = measurementRepo
        self.biomarkerRepo = biomarkerRepo
        self.engine = engine
    }

    // MARK: - Data Loading Pipeline
    @MainActor
    public func loadTimelineData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedPanels = labPanelRepo.fetchAll()
            async let fetchedProtocols = protocolRepo.fetchAll()
            async let fetchedDoses = doseLogRepo.fetchAll()
            async let fetchedMeasurements = measurementRepo.fetchAll()
            async let fetchedBiomarkers = biomarkerRepo.fetchAll()

            self.cachedPanels = try await fetchedPanels
            self.cachedProtocols = try await fetchedProtocols
            self.cachedDoseLogs = try await fetchedDoses
            self.cachedMeasurements = try await fetchedMeasurements
            self.cachedBiomarkers = try await fetchedBiomarkers

            // If empty, generate demonstrative longitudinal dataset for showcase
            if self.cachedPanels.isEmpty && self.cachedProtocols.isEmpty {
                synthesizeDemonstrationData()
            }

            recomputeAnalysis()
        } catch {
            recomputeAnalysis()
        }
    }

    // MARK: - Actions
    @MainActor
    public func selectBiomarker(_ name: String) {
        self.selectedBiomarker = name
        self.selectedLabPoint = nil
        recomputeAnalysis()
    }

    @MainActor
    public func selectTimeRange(_ range: TimelineTimeRange) {
        self.selectedTimeRange = range
    }

    @MainActor
    private func recomputeAnalysis() {
        self.analysis = engine.generateAnalysis(
            labPanels: cachedPanels,
            biomarkers: cachedBiomarkers,
            protocols: cachedProtocols,
            protocolRevisions: cachedRevisions,
            doseLogs: cachedDoseLogs,
            measurements: cachedMeasurements,
            selectedBiomarkerName: selectedBiomarker
        )

        if selectedBiomarker == nil {
            self.selectedBiomarker = analysis.selectedBiomarkerName
        }
    }

    // MARK: - Filtered Accessors
    public var filteredActivePoints: [LabTimeSeriesPoint] {
        let points = analysis.activePoints
        guard let days = selectedTimeRange.dayCount, let latestDate = points.last?.timestamp else {
            return points
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: latestDate) ?? Date.distantPast
        return points.filter { $0.timestamp >= cutoff }
    }

    public var filteredAlignedEvents: [AlignedTimelineItem] {
        var items = analysis.alignedEvents

        // Apply Time Range
        if let days = selectedTimeRange.dayCount, let latestDate = items.last?.timestamp {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: latestDate) ?? Date.distantPast
            items = items.filter { $0.timestamp >= cutoff }
        }

        // Apply Category Filter
        switch selectedEventFilter {
        case .all:
            return items
        case .labsOnly:
            return items.filter { $0.type == .labResult || $0.type == .baselineDraw || $0.type == .followUpLab }
        case .protocolsOnly:
            return items.filter { $0.type == .protocolStart || $0.type == .protocolEnd || $0.type == .doseChange }
        case .dosesOnly:
            return items.filter { $0.type == .doseAdministered || $0.type == .doseMissed }
        case .measurementsOnly:
            return items.filter { $0.type == .measurement }
        }
    }

    // MARK: - Synthesize Longitudinal Showcase Data
    private func synthesizeDemonstrationData() {
        let cal = Calendar.current
        let now = Date()

        // 1. Baseline Draw (60 days ago)
        let baselineDate = cal.date(byAdding: .day, value: -75, to: now)!
        let baselinePanel = LabPanel(
            id: UUID(),
            panelName: "Comprehensive Baseline Wellness Panel",
            labName: "Quest Diagnostics",
            collectionDate: baselineDate,
            status: .completed,
            results: [
                LabResult(biomarkerName: "Total Testosterone", category: .hormones, value: 480, unit: "ng/dL", referenceRangeMin: 300, referenceRangeMax: 1000, flag: .inRange),
                LabResult(biomarkerName: "Free Testosterone", category: .hormones, value: 11.2, unit: "pg/mL", referenceRangeMin: 9.0, referenceRangeMax: 30.0, flag: .inRange),
                LabResult(biomarkerName: "IGF-1 (Somatomedin C)", category: .hormones, value: 165, unit: "ng/mL", referenceRangeMin: 115, referenceRangeMax: 355, flag: .inRange),
                LabResult(biomarkerName: "Fasting Blood Glucose", category: .metabolic, value: 96, unit: "mg/dL", referenceRangeMin: 70, referenceRangeMax: 99, flag: .inRange),
                LabResult(biomarkerName: "ALT (Alanine Aminotransferase)", category: .liverHepatic, value: 24, unit: "U/L", referenceRangeMin: 7, referenceRangeMax: 56, flag: .inRange),
                LabResult(biomarkerName: "Apolipoprotein B (ApoB)", category: .lipids, value: 88, unit: "mg/dL", referenceRangeMin: 50, referenceRangeMax: 90, flag: .inRange)
            ],
            notes: "Pre-intervention baseline blood draw"
        )

        // 2. Protocol A: BPC-157 250mcg (Day -60 to Day -31)
        let protoAId = UUID()
        let startA = cal.date(byAdding: .day, value: -60, to: now)!
        let endA = cal.date(byAdding: .day, value: -31, to: now)!
        let protoA = ProtocolModel(
            id: protoAId,
            name: "Protocol A (BPC-157 250mcg)",
            status: .completed,
            startDate: startA,
            endDate: endA,
            notes: "Initial tissue recovery & gut repair phase",
            compounds: [
                ProtocolCompound(compoundName: "BPC-157", dosageAmount: 250, unit: .mcg, frequency: .daily, route: .subcutaneous)
            ],
            colorHex: "#10B981"
        )

        // Mid-Protocol A Lab Draw (Day -45)
        let midDateA = cal.date(byAdding: .day, value: -45, to: now)!
        let midPanelA = LabPanel(
            id: UUID(),
            panelName: "Mid-Protocol A Diagnostic Check",
            labName: "Labcorp",
            collectionDate: midDateA,
            status: .completed,
            results: [
                LabResult(biomarkerName: "Total Testosterone", category: .hormones, value: 520, unit: "ng/dL", referenceRangeMin: 300, referenceRangeMax: 1000, flag: .inRange),
                LabResult(biomarkerName: "Free Testosterone", category: .hormones, value: 12.8, unit: "pg/mL", referenceRangeMin: 9.0, referenceRangeMax: 30.0, flag: .inRange),
                LabResult(biomarkerName: "IGF-1 (Somatomedin C)", category: .hormones, value: 210, unit: "ng/mL", referenceRangeMin: 115, referenceRangeMax: 355, flag: .inRange),
                LabResult(biomarkerName: "Fasting Blood Glucose", category: .metabolic, value: 92, unit: "mg/dL", referenceRangeMin: 70, referenceRangeMax: 99, flag: .inRange),
                LabResult(biomarkerName: "ALT (Alanine Aminotransferase)", category: .liverHepatic, value: 26, unit: "U/L", referenceRangeMin: 7, referenceRangeMax: 56, flag: .inRange),
                LabResult(biomarkerName: "Apolipoprotein B (ApoB)", category: .lipids, value: 84, unit: "mg/dL", referenceRangeMin: 50, referenceRangeMax: 90, flag: .inRange)
            ]
        )

        // 3. Dose Change / Titration Revision (Day -30)
        let protoBId = UUID()
        let startB = cal.date(byAdding: .day, value: -30, to: now)!
        let protoB = ProtocolModel(
            id: protoBId,
            name: "Protocol B (CJC-1295 + Ipamorelin)",
            status: .active,
            startDate: startB,
            endDate: nil,
            notes: "Growth hormone secretagogue optimization protocol",
            compounds: [
                ProtocolCompound(compoundName: "CJC-1295", dosageAmount: 100, unit: .mcg, frequency: .daily, route: .subcutaneous),
                ProtocolCompound(compoundName: "Ipamorelin", dosageAmount: 200, unit: .mcg, frequency: .daily, route: .subcutaneous)
            ],
            colorHex: "#06B6D4"
        )

        let revB = ProtocolRevision(
            protocolId: protoBId,
            revisionNumber: 2,
            name: "Protocol B (Titration: +50mcg)",
            compounds: [
                ProtocolCompound(compoundName: "CJC-1295", dosageAmount: 150, unit: .mcg, frequency: .daily, route: .subcutaneous),
                ProtocolCompound(compoundName: "Ipamorelin", dosageAmount: 250, unit: .mcg, frequency: .daily, route: .subcutaneous)
            ],
            reasonForChange: "Titrated secretagogue dose for enhanced nocturnal pulse",
            effectiveDate: cal.date(byAdding: .day, value: -14, to: now)!
        )

        // 4. Follow-Up Lab Draw (Day -3)
        let followUpDate = cal.date(byAdding: .day, value: -3, to: now)!
        let followUpPanel = LabPanel(
            id: UUID(),
            panelName: "Protocol B Follow-Up & Hormone Evaluation",
            labName: "Quest Diagnostics",
            collectionDate: followUpDate,
            status: .completed,
            results: [
                LabResult(biomarkerName: "Total Testosterone", category: .hormones, value: 710, unit: "ng/dL", referenceRangeMin: 300, referenceRangeMax: 1000, flag: .inRange),
                LabResult(biomarkerName: "Free Testosterone", category: .hormones, value: 18.4, unit: "pg/mL", referenceRangeMin: 9.0, referenceRangeMax: 30.0, flag: .inRange),
                LabResult(biomarkerName: "IGF-1 (Somatomedin C)", category: .hormones, value: 298, unit: "ng/mL", referenceRangeMin: 115, referenceRangeMax: 355, flag: .inRange),
                LabResult(biomarkerName: "Fasting Blood Glucose", category: .metabolic, value: 86, unit: "mg/dL", referenceRangeMin: 70, referenceRangeMax: 99, flag: .inRange),
                LabResult(biomarkerName: "ALT (Alanine Aminotransferase)", category: .liverHepatic, value: 28, unit: "U/L", referenceRangeMin: 7, referenceRangeMax: 56, flag: .inRange),
                LabResult(biomarkerName: "Apolipoprotein B (ApoB)", category: .lipids, value: 78, unit: "mg/dL", referenceRangeMin: 50, referenceRangeMax: 90, flag: .inRange)
            ],
            notes: "Marked elevation in IGF-1 (+80.6%) confirming biological responsiveness."
        )

        // Synthesize Doses
        var demoDoses: [DoseLog] = []
        for d in 0..<60 {
            let dt = cal.date(byAdding: .day, value: d - 60, to: now)!
            let isProtoA = d < 30
            let compound = isProtoA ? "BPC-157" : "Ipamorelin"
            let amt: Double = isProtoA ? 250 : (d > 45 ? 250 : 200)
            let protoId = isProtoA ? protoAId : protoBId

            demoDoses.append(
                DoseLog(
                    compoundId: UUID(),
                    compoundName: compound,
                    scheduledDate: dt,
                    loggedDate: dt,
                    status: .taken,
                    associatedProtocolId: protoId,
                    doseAmount: amt,
                    doseUnit: .mcg,
                    administrationRoute: .subcutaneous
                )
            )
        }

        self.cachedPanels = [baselinePanel, midPanelA, followUpPanel]
        self.cachedProtocols = [protoA, protoB]
        self.cachedRevisions = [revB]
        self.cachedDoseLogs = demoDoses
    }
}
