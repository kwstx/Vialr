import XCTest
import SwiftUI
@testable import Feature
@testable import Domain
@testable import Data
@testable import Analytics
@testable import CalculationEngine

@MainActor
final class ReportGenerationUITests: XCTestCase {

    private var localStore: LocalStore!
    private var protocolRepo: LocalProtocolRepository!
    private var doseRepo: LocalDoseLogRepository!
    private var biomarkerRepo: LocalBiomarkerRepository!
    private var labPanelRepo: LocalLabPanelRepository!
    private var generator: ClinicianReportGenerator!

    override func setUp() async throws {
        localStore = LocalStore()
        protocolRepo = LocalProtocolRepository(store: store)
        doseRepo = LocalDoseLogRepository(store: store)
        biomarkerRepo = LocalBiomarkerRepository(store: store)
        labPanelRepo = LocalLabPanelRepository(store: store)

        generator = ClinicianReportGenerator(
            protocolRepo: protocolRepo,
            doseRepo: doseRepo,
            biomarkerRepo: biomarkerRepo,
            labPanelRepo: labPanelRepo
        )
    }

    private var store: LocalStore {
        localStore
    }

    func testClinicianReportDatePresetsAndConfiguration() {
        var config = ClinicianReportConfiguration()
        config.datePreset = .last30Days
        let interval30 = config.effectiveDateInterval
        let days30 = Calendar.current.dateComponents([.day], from: interval30.start, to: interval30.end).day ?? 0
        XCTAssertEqual(days30, 30)

        config.datePreset = .last90Days
        let interval90 = config.effectiveDateInterval
        let days90 = Calendar.current.dateComponents([.day], from: interval90.start, to: interval90.end).day ?? 0
        XCTAssertEqual(days90, 90)

        config.datePreset = .last180Days
        let interval180 = config.effectiveDateInterval
        let days180 = Calendar.current.dateComponents([.day], from: interval180.start, to: interval180.end).day ?? 0
        XCTAssertEqual(days180, 180)
    }

    func testFullClinicianReportGenerationWithDosesAndBiomarkers() async throws {
        let compoundId = UUID()
        let now = Date()

        // 1. Create active protocol
        let compound = ProtocolCompound(
            compoundId: compoundId,
            compoundName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg,
            scheduleRule: .everyDay
        )
        let proto = ProtocolModel(
            name: "BPC Protocol",
            status: .active,
            startDate: now.addingTimeInterval(-86400 * 30),
            compounds: [compound]
        )
        try await protocolRepo.save(proto)

        // 2. Add doses in the last 30 days (25 taken doses)
        for i in 1...25 {
            let doseDate = now.addingTimeInterval(-86400 * Double(30 - i))
            let doseLog = DoseLog(
                compoundId: compoundId,
                compoundName: "BPC-157",
                scheduledDate: doseDate,
                loggedDate: doseDate,
                doseAmount: 250,
                doseUnit: .mcg,
                status: .taken,
                injectionSite: "Abdomen (SubQ)"
            )
            try await doseRepo.save(doseLog)
        }

        // 3. Add longitudinal biomarkers (Initial vs Latest)
        let bio1 = Biomarker(
            name: "hs-CRP (High-Sensitivity C-Reactive Protein)",
            category: .inflammatory,
            value: 2.8,
            unit: "mg/L",
            referenceRangeMin: 0.0,
            referenceRangeMax: 1.0,
            dateRecorded: now.addingTimeInterval(-86400 * 28),
            source: .labImport
        )
        let bio2 = Biomarker(
            name: "hs-CRP (High-Sensitivity C-Reactive Protein)",
            category: .inflammatory,
            value: 0.7, // Reduced inflammation after BPC protocol!
            unit: "mg/L",
            referenceRangeMin: 0.0,
            referenceRangeMax: 1.0,
            dateRecorded: now.addingTimeInterval(-86400 * 2),
            source: .labImport
        )
        try await biomarkerRepo.save(bio1)
        try await biomarkerRepo.save(bio2)

        // 4. Generate Report
        var config = ClinicianReportConfiguration()
        config.datePreset = .last30Days
        config.includeProtocols = true
        config.includeDoses = true
        config.includeBiomarkers = true
        config.includeAdherenceStats = true

        let report = try await generator.generateReport(configuration: config)

        // 5. Verify Report Statistics & Content
        XCTAssertEqual(report.activeProtocols.count, 1)
        XCTAssertEqual(report.activeProtocols.first?.name, "BPC Protocol")

        XCTAssertEqual(report.compoundSummaries.count, 1)
        let bpcSummary = report.compoundSummaries.first
        XCTAssertEqual(bpcSummary?.compoundName, "BPC-157")
        XCTAssertEqual(bpcSummary?.numberOfInjections, 25)
        XCTAssertEqual(bpcSummary?.totalDoseDelivered, 6250.0) // 25 * 250 mcg = 6250 mcg
        XCTAssertEqual(bpcSummary?.averageDose, 250.0)

        // Biomarker delta check
        XCTAssertEqual(report.biomarkerSummaries.count, 1)
        let crpSummary = report.biomarkerSummaries.first
        XCTAssertEqual(crpSummary?.biomarkerName, "hs-CRP (High-Sensitivity C-Reactive Protein)")
        XCTAssertEqual(crpSummary?.initialValue, 2.8)
        XCTAssertEqual(crpSummary?.latestValue, 0.7)
        XCTAssertEqual(crpSummary?.absoluteChange, -2.1, accuracy: 0.001) // Reduced by 2.1 mg/L

        // PDF Generation Data
        let pdfData = ClinicianPDFRenderer.shared.renderReportToPDFData(report)
        XCTAssertFalse(pdfData.isEmpty)
    }
}
