import SwiftUI
import Observation
import Domain
import Data
import CalculationEngine

@Observable
public final class BloodworkViewModel: @unchecked Sendable {
    public var panels: [LabPanel] = []
    public var isLoading: Bool = false
    public var selectedCategoryFilter: LabCategory? = nil

    // Sheets & Nav State
    public var isManualEntrySheetPresented: Bool = false
    public var isUploadSheetPresented: Bool = false
    public var isCandidateConfirmationPresented: Bool = false
    public var candidateReportToVerify: ExtractedLabReportCandidate? = nil
    public var selectedPanelForDetail: LabPanel? = nil

    private let labPanelRepo: LabPanelRepositoryProtocol
    private let biomarkerRepo: BiomarkerRepositoryProtocol

    public init(
        labPanelRepo: LabPanelRepositoryProtocol = LocalLabPanelRepository(),
        biomarkerRepo: BiomarkerRepositoryProtocol = LocalBiomarkerRepository()
    ) {
        self.labPanelRepo = labPanelRepo
        self.biomarkerRepo = biomarkerRepo
    }

    @MainActor
    public func loadPanels() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.panels = try await labPanelRepo.fetchAll()
        } catch {
            self.panels = []
        }
    }

    @MainActor
    public func saveConfirmedPanel(_ panel: LabPanel) async {
        do {
            try await labPanelRepo.save(panel)
            
            // Also store longitudinal Biomarker objects for trending
            for result in panel.results {
                let biomarker = Biomarker(
                    name: result.biomarkerName,
                    category: biomarkerCategory(for: result.category),
                    value: result.value,
                    unit: result.unit,
                    referenceRangeMin: result.referenceRangeMin,
                    referenceRangeMax: result.referenceRangeMax,
                    dateRecorded: panel.collectionDate,
                    source: .labImport,
                    notes: "Imported from \(panel.labName)"
                )
                try? await biomarkerRepo.save(biomarker)
            }

            await loadPanels()
        } catch {
            // Handle save error
        }
    }

    @MainActor
    public func deletePanel(id: UUID) async {
        do {
            try await labPanelRepo.delete(byId: id)
            await loadPanels()
        } catch {
            // Handle error
        }
    }

    @MainActor
    public func handleExtractedCandidate(_ candidate: ExtractedLabReportCandidate) {
        self.candidateReportToVerify = candidate
        self.isCandidateConfirmationPresented = true
    }

    // MARK: - Key Biomarkers Summary Stats
    public var keyBiomarkerCards: [KeyBiomarkerSummary] {
        let keyNames = ["Total Testosterone", "Free Testosterone", "IGF-1 (Somatomedin C)", "Fasting Blood Glucose", "Apolipoprotein B (ApoB)", "ALT (Alanine Aminotransferase)"]
        
        return keyNames.compactMap { name in
            let matchingResults = panels
                .flatMap { p in p.results.map { (panel: p, result: $0) } }
                .filter { $0.result.biomarkerName.localizedCaseInsensitiveContains(name) }
                .sorted(by: { $0.panel.collectionDate > $1.panel.collectionDate })

            guard let latest = matchingResults.first else { return nil }
            let previous = matchingResults.count > 1 ? matchingResults[1] : nil

            return KeyBiomarkerSummary(
                name: latest.result.biomarkerName,
                category: latest.result.category,
                latestValue: latest.result.value,
                unit: latest.result.unit,
                flag: latest.result.flag,
                referenceMin: latest.result.referenceRangeMin,
                referenceMax: latest.result.referenceRangeMax,
                latestDate: latest.panel.collectionDate,
                previousValue: previous?.result.value,
                previousDate: previous?.panel.collectionDate
            )
        }
    }

    private func biomarkerCategory(for labCat: LabCategory) -> BiomarkerCategory {
        switch labCat {
        case .hormones, .cbcHematology, .thyroid, .inflammatory, .custom: return .bloodwork
        case .metabolic, .vitaminsElectrolytes: return .metabolic
        case .lipids: return .cardiovascular
        case .liverHepatic, .kidneyRenal: return .bloodwork
        }
    }
}

public struct KeyBiomarkerSummary: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let category: LabCategory
    public let latestValue: Double
    public let unit: String
    public let flag: LabResultFlag
    public let referenceMin: Double?
    public let referenceMax: Double?
    public let latestDate: Date
    public let previousValue: Double?
    public let previousDate: Date?

    public var deltaPercent: Double? {
        guard let prev = previousValue, prev > 0 else { return nil }
        return ((latestValue - prev) / prev) * 100.0
    }
}
