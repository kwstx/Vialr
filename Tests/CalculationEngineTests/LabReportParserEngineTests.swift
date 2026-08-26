import XCTest
@testable import Domain
@testable import CalculationEngine

final class LabReportParserEngineTests: XCTestCase {

    func testQuestDiagnosticsReportParsing() throws {
        let parser = LabReportParserEngine()
        let sampleReportText = """
        QUEST DIAGNOSTICS
        COLLECTION DATE: 05/15/2024
        FASTING: YES
        ORDERED BY: Dr. William Sterling, MD

        TESTOSTERONE, TOTAL 845 ng/dL 250-1100
        FREE TESTOSTERONE 24.2 pg/mL 9.0-30.0
        ESTRADIOL, SENSITIVE 28.5 pg/mL 8.0-35.0
        IGF-1 268 ng/mL 115-307
        GLUCOSE 88 mg/dL 70-99
        INSULIN, FASTING 3.8 uIU/mL 2.0-6.0
        APOB 68 mg/dL < 90
        HEMATOCRIT 47.2 % 38.5-50.0
        ALT 22 IU/L 9-44
        HS CRP 0.35 mg/L < 1.0
        """

        let candidate = parser.parse(rawText: sampleReportText, fileName: "Quest_May_2024.pdf")

        XCTAssertEqual(candidate.detectedLabName, "Quest Diagnostics")
        XCTAssertEqual(candidate.detectedFastingStatus, .fasted)
        XCTAssertEqual(candidate.detectedOrderingPhysician, "Dr. William Sterling, MD")
        XCTAssertTrue(candidate.overallConfidence >= 0.85)

        // Verify candidate analytes extracted
        XCTAssertTrue(candidate.candidates.count >= 8)

        // Verify Total Testosterone
        let tt = candidate.candidates.first { $0.resolvedName.localizedCaseInsensitiveContains("Testosterone") }
        XCTAssertNotNil(tt)
        XCTAssertEqual(tt?.extractedValue, 845)
        XCTAssertEqual(tt?.extractedUnit, "ng/dL")
        XCTAssertEqual(tt?.detectedFlag, .inRange)
        XCTAssertEqual(tt?.confidenceLevel, .high)

        // Verify Glucose
        let glu = candidate.candidates.first { $0.resolvedName.localizedCaseInsensitiveContains("Glucose") }
        XCTAssertNotNil(glu)
        XCTAssertEqual(glu?.extractedValue, 88)
        XCTAssertEqual(glu?.extractedUnit, "mg/dL")

        // Verify Free Testosterone
        let ft = candidate.candidates.first { $0.resolvedName.localizedCaseInsensitiveContains("Free Testosterone") }
        XCTAssertNotNil(ft)
        XCTAssertEqual(ft?.extractedValue, 24.2)
        XCTAssertEqual(ft?.extractedUnit, "pg/mL")
    }

    func testLabcorpReportParsingWithAbnormalFlag() throws {
        let parser = LabReportParserEngine()
        let sampleReportText = """
        LABORATORY CORPORATION OF AMERICA
        COLLECTION DATE: 2024-02-10
        FASTING: YES
        ORDERED BY: Dr. Sarah Jenkins, MD

        TESTOSTERONE, TOTAL 620 ng/dL 264-916
        FREE TESTOSTERONE 16.8 pg/mL 8.7-25.1
        ESTRADIOL 22.0 pg/mL 7.6-42.6
        CHOLESTEROL, TOTAL 192 mg/dL 100-199
        LDL-C 112 H mg/dL 0-99
        HDL-C 58 mg/dL > 39
        TRIGLYCERIDES 110 mg/dL 0-149
        TSH 1.65 uIU/mL 0.450-4.500
        HEMATOCRIT 45.0 % 37.5-51.0
        ALT (SGPT) 28 IU/L 0-44
        """

        let candidate = parser.parse(rawText: sampleReportText, fileName: "Labcorp_Feb_2024.pdf")

        XCTAssertEqual(candidate.detectedLabName, "Labcorp")
        XCTAssertEqual(candidate.detectedFastingStatus, .fasted)
        XCTAssertTrue(candidate.candidates.count >= 8)

        // Verify LDL-C flag
        let ldl = candidate.candidates.first { $0.resolvedName.localizedCaseInsensitiveContains("LDL") }
        XCTAssertNotNil(ldl)
        XCTAssertEqual(ldl?.extractedValue, 112)
        XCTAssertEqual(ldl?.detectedFlag, .high)
    }

    func testSingleLineCandidateParsing() throws {
        let parser = LabReportParserEngine()

        // In range
        let c1 = parser.parseCandidateLine("IGF-1 (Somatomedin C)   245   ng/mL   115 - 307")
        XCTAssertNotNil(c1)
        XCTAssertEqual(c1?.extractedValue, 245)
        XCTAssertEqual(c1?.extractedUnit, "ng/mL")
        XCTAssertEqual(c1?.detectedFlag, .inRange)

        // High with explicit flag
        let c2 = parser.parseCandidateLine("GLUCOSE 114 H mg/dL 70-99")
        XCTAssertNotNil(c2)
        XCTAssertEqual(c2?.extractedValue, 114)
        XCTAssertEqual(c2?.detectedFlag, .high)

        // Header line skipped
        let skip1 = parser.parseCandidateLine("Patient: Jane Doe DOB: 01/01/1985")
        XCTAssertNil(skip1)
    }
}
