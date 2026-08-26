import XCTest
@testable import Domain

final class BloodworkSystemTests: XCTestCase {

    // MARK: - 1. Standard Biomarker Catalog Search Tests
    func testBiomarkerCatalogSearchExactAndAlias() throws {
        let catalog = StandardBiomarkerCatalog.shared

        // Exact name lookup
        let test1 = catalog.find(identifier: "Total Testosterone")
        XCTAssertNotNil(test1)
        XCTAssertEqual(test1?.standardUnit, "ng/dL")
        XCTAssertEqual(test1?.category, .hormones)

        // Alias lookup ("Total T")
        let test2 = catalog.find(identifier: "Total T")
        XCTAssertNotNil(test2)
        XCTAssertEqual(test2?.id, "total_testosterone")

        // Alias lookup ("E2")
        let test3 = catalog.find(identifier: "E2")
        XCTAssertNotNil(test3)
        XCTAssertEqual(test3?.id, "estradiol_sensitive")

        // Alias lookup ("Somatomedin C")
        let test4 = catalog.find(identifier: "Somatomedin C")
        XCTAssertNotNil(test4)
        XCTAssertEqual(test4?.id, "igf_1")

        // Search query "Glucose"
        let searchResults = catalog.search(query: "Glucose")
        XCTAssertFalse(searchResults.isEmpty)
        XCTAssertTrue(searchResults.contains(where: { $0.id == "fasting_glucose" }))

        // Search by category
        let hormoneMarkers = catalog.search(query: "", category: .hormones)
        XCTAssertTrue(hormoneMarkers.count >= 8)
        XCTAssertTrue(hormoneMarkers.allSatisfy { $0.category == .hormones })
    }

    // MARK: - 2. Reference Range Flag Evaluation Tests
    func testBiomarkerReferenceRangeFlagEvaluation() throws {
        let catalog = StandardBiomarkerCatalog.shared
        guard let testDef = catalog.find(identifier: "total_testosterone") else {
            XCTFail("Missing total_testosterone definition")
            return
        }

        // Normal: 845 in range [300 - 1000]
        XCTAssertEqual(testDef.evaluateFlag(value: 845), .inRange)

        // Low: 220 < 300
        XCTAssertEqual(testDef.evaluateFlag(value: 220), .low)

        // Critical Low: 100 < 150 (50% of 300)
        XCTAssertEqual(testDef.evaluateFlag(value: 100), .criticalLow)

        // High: 1150 > 1000
        XCTAssertEqual(testDef.evaluateFlag(value: 1150), .high)

        // Critical High: 1600 > 1500 (150% of 1000)
        XCTAssertEqual(testDef.evaluateFlag(value: 1600), .criticalHigh)
    }

    // MARK: - 3. Data Separation Pipeline: Candidate to Structured LabPanel
    func testCandidateToStructuredLabRecordPipeline() throws {
        let candidate1 = ExtractedLabCandidate(
            rawAnalyteName: "TESTOSTERONE, TOTAL",
            matchedCatalogId: "total_testosterone",
            resolvedName: "Total Testosterone",
            category: .hormones,
            extractedValue: 845,
            extractedUnit: "ng/dL",
            referenceRangeMin: 300,
            referenceRangeMax: 1000,
            referenceRangeText: "300 – 1000 ng/dL",
            detectedFlag: .inRange,
            confidenceScore: 0.98,
            isSelected: true
        )

        let candidate2 = ExtractedLabCandidate(
            rawAnalyteName: "GLUCOSE",
            matchedCatalogId: "fasting_glucose",
            resolvedName: "Fasting Blood Glucose",
            category: .metabolic,
            extractedValue: 108,
            extractedUnit: "mg/dL",
            referenceRangeMin: 70,
            referenceRangeMax: 99,
            referenceRangeText: "70 – 99 mg/dL",
            detectedFlag: .high,
            confidenceScore: 0.99,
            isSelected: true
        )

        let candidateExcluded = ExtractedLabCandidate(
            rawAnalyteName: "SPECIMEN INTEGRITY",
            resolvedName: "Specimen Integrity",
            category: .custom,
            extractedValue: 1.0,
            extractedUnit: "status",
            isSelected: false
        )

        let reportCandidate = ExtractedLabReportCandidate(
            documentId: UUID(),
            fileName: "Quest_Report_May2024.pdf",
            detectedLabName: "Quest Diagnostics",
            detectedPanelName: "Comprehensive Hormone & Metabolic Panel",
            detectedCollectionDate: Date(),
            detectedFastingStatus: .fasted,
            detectedOrderingPhysician: "Dr. William Sterling, MD",
            overallConfidence: 0.96,
            candidates: [candidate1, candidate2, candidateExcluded]
        )

        // Verify that candidates are NOT structured records yet
        XCTAssertEqual(reportCandidate.candidates.count, 3)
        XCTAssertEqual(reportCandidate.selectedCandidatesCount, 2)

        // User Confirmation Step -> Creates structured LabPanel
        let structuredPanel = reportCandidate.createConfirmedLabPanel()

        XCTAssertEqual(structuredPanel.labName, "Quest Diagnostics")
        XCTAssertEqual(structuredPanel.results.count, 2)
        XCTAssertFalse(structuredPanel.results.contains(where: { $0.biomarkerName == "Specimen Integrity" }))
        XCTAssertEqual(structuredPanel.hasAbnormalResults, true)
        XCTAssertEqual(structuredPanel.abnormalResults.count, 1)
        XCTAssertEqual(structuredPanel.abnormalResults.first?.biomarkerName, "Fasting Blood Glucose")
        XCTAssertEqual(structuredPanel.abnormalResults.first?.flag, .high)

        // Verify longitudinal Biomarker conversion
        let biomarker = candidate1.toBiomarker(testDate: structuredPanel.collectionDate, labName: structuredPanel.labName)
        XCTAssertEqual(biomarker.name, "Total Testosterone")
        XCTAssertEqual(biomarker.value, 845)
        XCTAssertEqual(biomarker.unit, "ng/dL")
        XCTAssertEqual(biomarker.source, .labImport)
        XCTAssertEqual(biomarker.status, .inRange)
    }

    // MARK: - 4. LabPanel and LabResult JSON Codable Serialization
    func testLabPanelCodableSerialization() throws {
        let panelId = UUID()
        let result = LabResult(
            id: UUID(),
            panelId: panelId,
            biomarkerName: "Free Testosterone",
            category: .hormones,
            value: 24.2,
            unit: "pg/mL",
            referenceRangeMin: 9.0,
            referenceRangeMax: 30.0,
            referenceRangeText: "9.0 – 30.0 pg/mL",
            flag: .inRange
        )

        let panel = LabPanel(
            id: panelId,
            panelName: "Hormone Assessment",
            labName: "Labcorp",
            collectionDate: Date(),
            status: .completed,
            results: [result],
            fastingStatus: .fasted
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(panel)
        XCTAssertFalse(data.isEmpty)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LabPanel.self, from: data)
        XCTAssertEqual(decoded.id, panel.id)
        XCTAssertEqual(decoded.panelName, "Hormone Assessment")
        XCTAssertEqual(decoded.results.count, 1)
        XCTAssertEqual(decoded.results.first?.value, 24.2)
        XCTAssertEqual(decoded.results.first?.unit, "pg/mL")
    }
}
