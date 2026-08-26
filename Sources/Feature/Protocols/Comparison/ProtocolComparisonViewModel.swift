import SwiftUI
import Observation
import Domain
import Analytics
import Data

public enum ComparisonMode: String, CaseIterable, Identifiable {
    case protocols = "Protocols"
    case dateRanges = "Date Ranges"

    public var id: String { rawValue }
}

public enum ComparisonDomainTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case weight = "Weight & Body"
    case vitals = "Vitals"
    case adherence = "Adherence"
    case symptoms = "Well-Being"
    case biomarkers = "Bloodwork"
    case cost = "Cost"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .weight: return "scalemass.fill"
        case .vitals: return "heart.fill"
        case .adherence: return "checklist.checked"
        case .symptoms: return "bolt.heart.fill"
        case .biomarkers: return "testtube.2"
        case .cost: return "dollarsign.circle.fill"
        }
    }
}

@Observable
public final class ProtocolComparisonViewModel: @unchecked Sendable {
    // Dependencies
    public let engine: ProtocolComparisonEngine
    public let protocolRepo: ProtocolRepositoryProtocol
    public let measurementRepo: MeasurementRepositoryProtocol
    public let doseRepo: DoseLogRepositoryProtocol
    public let symptomRepo: SymptomRepositoryProtocol
    public let biomarkerRepo: BiomarkerRepositoryProtocol
    public let costRepo: CostRepositoryProtocol

    // State
    public var mode: ComparisonMode = .protocols
    public var selectedDomain: ComparisonDomainTab = .overview
    public var availableProtocols: [ProtocolModel] = []

    public var selectedProtocolA: ProtocolModel?
    public var selectedProtocolB: ProtocolModel?

    public var dateRangeAStart: Date = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
    public var dateRangeAEnd: Date = Calendar.current.date(byAdding: .day, value: -31, to: Date()) ?? Date()
    public var dateRangeBStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    public var dateRangeBEnd: Date = Date()

    public var comparisonReport: ProtocolComparisonReport?
    public var isLoading: Bool = false
    public var errorMessage: String?

    public init(
        engine: ProtocolComparisonEngine = ProtocolComparisonEngine(),
        protocolRepo: ProtocolRepositoryProtocol = LocalProtocolRepository(),
        measurementRepo: MeasurementRepositoryProtocol = LocalMeasurementRepository(),
        doseRepo: DoseLogRepositoryProtocol = LocalDoseLogRepository(),
        symptomRepo: SymptomRepositoryProtocol = LocalSymptomRepository(),
        biomarkerRepo: BiomarkerRepositoryProtocol = LocalBiomarkerRepository(),
        costRepo: CostRepositoryProtocol = LocalCostRepository(),
        initialProtocols: [ProtocolModel] = []
    ) {
        self.engine = engine
        self.protocolRepo = protocolRepo
        self.measurementRepo = measurementRepo
        self.doseRepo = doseRepo
        self.symptomRepo = symptomRepo
        self.biomarkerRepo = biomarkerRepo
        self.costRepo = costRepo
        self.availableProtocols = initialProtocols
    }

    public func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            let protocols = try await protocolRepo.fetchAll()
            self.availableProtocols = protocols.sorted(by: { $0.startDate < $1.startDate })

            if selectedProtocolA == nil && protocols.count >= 2 {
                selectedProtocolA = protocols[0]
                selectedProtocolB = protocols[1]
            } else if selectedProtocolA == nil && !protocols.isEmpty {
                selectedProtocolA = protocols[0]
            }

            await computeComparison()
        } catch {
            errorMessage = "Failed to load protocol data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    public func computeComparison() async {
        let periodA: ProtocolComparisonPeriod
        let periodB: ProtocolComparisonPeriod

        switch mode {
        case .protocols:
            guard let protoA = selectedProtocolA, let protoB = selectedProtocolB else {
                comparisonReport = nil
                return
            }
            periodA = ProtocolComparisonPeriod.fromProtocol(protoA)
            periodB = ProtocolComparisonPeriod.fromProtocol(protoB)

        case .dateRanges:
            guard dateRangeAStart < dateRangeAEnd && dateRangeBStart < dateRangeBEnd else {
                errorMessage = "Invalid date ranges specified."
                return
            }
            let intervalA = DateInterval(start: dateRangeAStart, end: dateRangeAEnd)
            let intervalB = DateInterval(start: dateRangeBStart, end: dateRangeBEnd)
            periodA = ProtocolComparisonPeriod.fromInterval(intervalA, name: "Period A")
            periodB = ProtocolComparisonPeriod.fromInterval(intervalB, name: "Period B")
        }

        do {
            let measurements = try await measurementRepo.fetchAll()
            let doseLogs = try await doseRepo.fetchAll()
            let symptoms = try await symptomRepo.fetchAll()
            let biomarkers = try await biomarkerRepo.fetchAll()
            let costs = try await costRepo.fetchAll()

            let report = engine.generateComparisonReport(
                periodA: periodA,
                periodB: periodB,
                measurements: measurements,
                doseLogs: doseLogs,
                completedDoses: [],
                symptomLogs: symptoms,
                biomarkers: biomarkers,
                costEvents: costs,
                customMetrics: []
            )

            self.comparisonReport = report
        } catch {
            self.errorMessage = "Failed to compute time-series comparison: \(error.localizedDescription)"
        }
    }
}
