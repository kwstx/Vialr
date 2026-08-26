import XCTest
import SwiftUI
@testable import Feature
@testable import Domain
@testable import Data
@testable import CalculationEngine

@MainActor
final class LabUploadUITests: XCTestCase {

    private var viewModel: BloodworkViewModel!
    private var labPanelRepo: LocalLabPanelRepository!
    private var biomarkerRepo: LocalBiomarkerRepository!

    override func setUp() async throws {
        let store = LocalStore()
        labPanelRepo = LocalLabPanelRepository(store: store)
        biomarkerRepo = LocalBiomarkerRepository(store: store)
        viewModel = BloodworkViewModel(
            labPanelRepo: labPanelRepo,
            biomarkerRepo: biomarkerRepo
        )
    }

    func testHandleExtractedCandidateAndConfirmPanel() async throws {
        let candidateId = UUID()
        let result1 = ExtractedBiomarkerCandidate(
            id: UUID(),
            rawName: "Total Testosterone",
            normalizedName: "Total Testosterone",
            value: 850.0,
            unit: "ng/dL",
            referenceRangeMin: 250.0,
            referenceRangeMax: 1100.0,
            confidenceScore: 0.98,
            isConfirmed: true
        )
        let result2 = ExtractedBiomarkerCandidate(
            id: UUID(),
            rawName: "Free Testosterone",
            normalizedName: "Free Testosterone",
            value: 22.5,
            unit: "pg/mL",
            referenceRangeMin: 8.7,
            referenceRangeMax: 25.1,
            confidenceScore: 0.95,
            isConfirmed: true
        )

        let candidate = ExtractedLabReportCandidate(
            id: candidateId,
            labName: "Quest Diagnostics",
            collectionDate: Date(),
            extractedResults: [result1, result2],
            documentConfidence: 0.96
        )

        // 1. Present candidate confirmation sheet
        viewModel.handleExtractedCandidate(candidate)
        XCTAssertTrue(viewModel.isCandidateConfirmationPresented)
        XCTAssertEqual(viewModel.candidateReportToVerify?.id, candidateId)
        XCTAssertEqual(viewModel.candidateReportToVerify?.extractedResults.count, 2)

        // 2. User confirms candidate into full LabPanel
        let confirmedResults = candidate.extractedResults.map { c in
            LabResult(
                biomarkerName: c.normalizedName,
                value: c.value,
                unit: c.unit,
                referenceRangeMin: c.referenceRangeMin,
                referenceRangeMax: c.referenceRangeMax,
                category: .hormones
            )
        }
        let panel = LabPanel(
            id: candidateId,
            labName: candidate.labName,
            collectionDate: candidate.collectionDate,
            results: confirmedResults
        )

        await viewModel.saveConfirmedPanel(panel)

        // 3. Verify panel saved to bloodwork hub
        XCTAssertEqual(viewModel.panels.count, 1)
        XCTAssertEqual(viewModel.panels.first?.id, candidateId)
        XCTAssertEqual(viewModel.panels.first?.results.count, 2)

        // 4. Verify longitudinal biomarkers were populated for trending
        let biomarkers = try await biomarkerRepo.fetchAll()
        XCTAssertEqual(biomarkers.count, 2)
        XCTAssertTrue(biomarkers.contains(where: { $0.name == "Total Testosterone" && $0.value == 850.0 }))
        XCTAssertTrue(biomarkers.contains(where: { $0.name == "Free Testosterone" && $0.value == 22.5 }))
    }

    func testDeletePanelRemovesFromHub() async throws {
        let panelId = UUID()
        let panel = LabPanel(
            id: panelId,
            labName: "Labcorp",
            collectionDate: Date(),
            results: [
                LabResult(biomarkerName: "Fasting Glucose", value: 85.0, unit: "mg/dL", referenceRangeMin: 70.0, referenceRangeMax: 99.0, category: .metabolic)
            ]
        )
        await viewModel.saveConfirmedPanel(panel)
        XCTAssertEqual(viewModel.panels.count, 1)

        await viewModel.deletePanel(id: panelId)
        XCTAssertEqual(viewModel.panels.count, 0)
    }
}
