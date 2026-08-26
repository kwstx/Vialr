import XCTest
import Domain
import CalculationEngine
import Data
@testable import Analytics

final class ClinicianReportGeneratorTests: XCTestCase {

    func testReportGenerationDataRetrievalAndAggregation() async throws {
        let generator = ClinicianReportGenerator()
        let config = ClinicianReportConfiguration(
            preset: .last30Days,
            patientName: "Jane Doe",
            patientDateOfBirth: "1988-04-12",
            clinicianName: "Dr. Alexander Smith, MD",
            practiceOrClinic: "Longevity & Metabolic Clinic",
            patientNotes: "Patient reports elevated recovery and reduced joint soreness."
        )

        let report = try await generator.generateReport(configuration: config)

        XCTAssertEqual(report.patientIdentifier, "Jane Doe")
        XCTAssertEqual(report.patientDateOfBirth, "1988-04-12")
        XCTAssertEqual(report.clinicianName, "Dr. Alexander Smith, MD")
        XCTAssertEqual(report.practiceOrClinic, "Longevity & Metabolic Clinic")
        XCTAssertFalse(report.patientObservations.isEmpty)
        XCTAssertGreaterThanOrEqual(report.adherencePercentage, 0.0)
        XCTAssertLessThanOrEqual(report.adherencePercentage, 100.0)
    }

    func testChronologicalLedgerSorting() async throws {
        let generator = ClinicianReportGenerator()
        let config = ClinicianReportConfiguration(preset: .allTime)

        let report = try await generator.generateReport(configuration: config)

        let ledger = report.chronologicalLedger
        if ledger.count >= 2 {
            for i in 0..<(ledger.count - 1) {
                XCTAssertLessThanOrEqual(ledger[i].timestamp, ledger[i + 1].timestamp, "Ledger items must be strictly chronological")
            }
        }
    }

    func testDoseSummaryCalculations() async throws {
        let generator = ClinicianReportGenerator()
        let config = ClinicianReportConfiguration(preset: .allTime)

        let report = try await generator.generateReport(configuration: config)

        for summary in report.doseSummary {
            XCTAssertFalse(summary.compoundName.isEmpty)
            XCTAssertGreaterThanOrEqual(summary.totalDoseDelivered, 0.0)
            XCTAssertGreaterThanOrEqual(summary.numberOfInjections, 0)
        }
    }

    func testSectionExclusionFilters() async throws {
        let generator = ClinicianReportGenerator()
        let config = ClinicianReportConfiguration(
            preset: .last30Days,
            includeProtocols: false,
            includeDoses: false,
            includeLabs: false,
            includeMeasurements: false,
            includeSymptoms: false,
            includeNotes: false
        )

        let report = try await generator.generateReport(configuration: config)

        XCTAssertTrue(report.activeProtocols.isEmpty)
        XCTAssertTrue(report.doseSummary.isEmpty)
        XCTAssertTrue(report.labPanels.isEmpty)
        XCTAssertTrue(report.measurementSummaries.isEmpty)
        XCTAssertNil(report.symptomSummary)
        XCTAssertTrue(report.chronologicalLedger.isEmpty)
    }

    func testVectorPDFByteStreamGeneration() {
        let now = Date()
        let report = ClinicianReport(
            patientIdentifier: "Test Patient",
            patientDateOfBirth: "1990-01-01",
            clinicianName: "Dr. House",
            practiceOrClinic: "Princeton Plainsboro",
            generatedDate: now,
            dateRangeStart: now.addingTimeInterval(-86400 * 30),
            dateRangeEnd: now,
            adherencePercentage: 92.5,
            totalDosesScheduled: 30,
            totalDosesAdministered: 28,
            totalDosesMissed: 2,
            clinicalNotes: "Patient compliance is high."
        )

        let pdfService = ClinicianPDFRenderer()
        let pdfData = pdfService.renderVectorPDFStream(report: report)

        XCTAssertFalse(pdfData.isEmpty)
        let pdfString = String(decoding: pdfData, as: UTF8.self)
        XCTAssertTrue(pdfString.hasPrefix("%PDF-1.4"))
        XCTAssertTrue(pdfString.contains("Test Patient"))
        XCTAssertTrue(pdfString.contains("Princeton Plainsboro"))
        XCTAssertTrue(pdfString.contains("%%EOF"))
    }
}
