import Foundation
import Domain
import DesignSystem

#if canImport(PDFKit)
import PDFKit
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Native multi-page vector PDF rendering engine designed specifically for medical and clinical records.
/// Renders structured chronological timelines, biomarker tables, adherence metrics, and patient notes
/// into a high-resolution, print-ready, vectorized PDF document.
public final class ClinicianPDFRenderer: @unchecked Sendable {
    public static let shared = ClinicianPDFRenderer()

    public init() {}

    // MARK: - Page Geometry
    public static let pageWidth: CGFloat = 612.0 // Standard Letter Width (8.5 inches)
    public static let pageHeight: CGFloat = 792.0 // Standard Letter Height (11.0 inches)
    public static let marginHorizontal: CGFloat = 36.0
    public static let marginTop: CGFloat = 36.0
    public static let marginBottom: CGFloat = 40.0
    public static let contentWidth: CGFloat = pageWidth - (marginHorizontal * 2) // 540.0 pt
    public static let maxY: CGFloat = pageHeight - marginBottom

    /// Generates raw PDF Data from a ClinicianReport model.
    public func renderPDFData(from report: ClinicianReport) -> Data {
        #if canImport(UIKit)
        return renderWithUIKit(report: report)
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        return renderWithAppKit(report: report)
        #else
        return renderVectorPDFStream(report: report)
        #endif
    }

    #if canImport(PDFKit)
    /// Generates a PDFKit PDFDocument for live rendering in SwiftUI views.
    public func renderPDFDocument(from report: ClinicianReport) -> PDFDocument? {
        let data = renderPDFData(from: report)
        return PDFDocument(data: data)
    }
    #endif

    // MARK: - UIKit Renderer (iOS, iPadOS, Catalyst)
    #if canImport(UIKit)
    private func renderWithUIKit(report: ClinicianReport) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: Self.pageWidth, height: Self.pageHeight)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Vialr Medical Protocol Summary - \(report.patientIdentifier)",
            kCGPDFContextAuthor as String: "Vialr Clinical System",
            kCGPDFContextCreator as String: "Vialr iOS Native Engine",
            kCGPDFContextSubject as String: "Longitudinal Peptide & Clinical Protocol Record"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            var pageIndex = 1
            var totalPages = 1 // Will be incremented dynamically
            var currentY: CGFloat = Self.marginTop

            func startNewPage() {
                context.beginPage()
                currentY = Self.marginTop
                drawRunningHeader(context: context.cgContext, report: report, pageNumber: pageIndex)
                currentY += 28.0
            }

            // --- PAGE 1: Start ---
            context.beginPage()
            currentY = Self.marginTop

            // Document Header Banner
            currentY = drawDocumentHeader(context: context.cgContext, report: report, startY: currentY)
            currentY += 12.0

            // 1. Executive Summary & Adherence Stats
            if currentY + 110 > Self.maxY {
                drawRunningFooter(context: context.cgContext, pageNumber: pageIndex, totalPages: totalPages)
                pageIndex += 1
                totalPages = max(totalPages, pageIndex)
                startNewPage()
            }
            currentY = drawExecutiveSummary(context: context.cgContext, report: report, startY: currentY)
            currentY += 14.0

            // 2. Active Protocols Table
            if !report.activeProtocols.isEmpty {
                if currentY + 90 > Self.maxY {
                    drawRunningFooter(context: context.cgContext, pageNumber: pageIndex, totalPages: totalPages)
                    pageIndex += 1
                    totalPages = max(totalPages, pageIndex)
                    startNewPage()
                }
                currentY = drawProtocolsSection(context: context.cgContext, protocols: report.activeProtocols, startY: currentY)
                currentY += 14.0
            }

            // 3. Administered Compounds Breakdown
            if !report.doseSummary.isEmpty {
                if currentY + 80 > Self.maxY {
                    drawRunningFooter(context: context.cgContext, pageNumber: pageIndex, totalPages: totalPages)
                    pageIndex += 1
                    totalPages = max(totalPages, pageIndex)
                    startNewPage()
                }
                currentY = drawCompoundSummaries(context: context.cgContext, summaries: report.doseSummary, startY: currentY)
                currentY += 14.0
            }

            // 4. Objective Laboratory Biomarkers
            if !report.labPanels.isEmpty {
                if currentY + 80 > Self.maxY {
                    drawRunningFooter(context: context.cgContext, pageNumber: pageIndex, totalPages: totalPages)
                    pageIndex += 1
                    totalPages = max(totalPages, pageIndex)
                    startNewPage()
                }
                currentY = drawLabPanels(context: context.cgContext, panels: report.labPanels, startY: currentY) {
                    drawRunningFooter(context: context.cgContext, pageNumber: pageIndex, totalPages: totalPages)
                    pageIndex += 1
                    totalPages = max(totalPages, pageIndex)
                    startNewPage()
                }
                currentY += 14.0
            }

            // 5. Longitudinal Vitals & Physical Measurements
            if !report.measurementSummaries.isEmpty {
                if currentY + 80 > Self.maxY {
                    drawRunningFooter(context: context.cgContext, pageNumber: pageIndex, totalPages: totalPages)
                    pageIndex += 1
                    totalPages = max(totalPages, pageIndex)
                    startNewPage()
                }
                currentY = drawMeasurements(context: context.cgContext, measurements: report.measurementSummaries, startY: currentY) {
                    drawRunningFooter(context: context.cgContext, pageNumber: pageIndex, totalPages: totalPages)
                    pageIndex += 1
                    totalPages = max(totalPages, pageIndex)
                    startNewPage()
                }
                currentY += 14.0
            }

            // 6. Subjective Symptoms & Tolerability
            if let sym = report.symptomSummary {
                if currentY + 85 > Self.maxY {
                    drawRunningFooter(context: context.cgContext, pageNumber: pageIndex, totalPages: totalPages)
                    pageIndex += 1
                    totalPages = max(totalPages, pageIndex)
                    startNewPage()
                }
                currentY = drawSymptomSummary(context: context.cgContext, symptom: sym, startY: currentY)
                currentY += 14.0
            }

            // 7. Chronological Clinical Ledger
            if !report.chronologicalLedger.isEmpty {
                if currentY + 80 > Self.maxY {
                    drawRunningFooter(context: context.cgContext, pageNumber: pageIndex, totalPages: totalPages)
                    pageIndex += 1
                    totalPages = max(totalPages, pageIndex)
                    startNewPage()
                }
                currentY = drawChronologicalLedger(context: context.cgContext, ledger: report.chronologicalLedger, startY: currentY) {
                    drawRunningFooter(context: context.cgContext, pageNumber: pageIndex, totalPages: totalPages)
                    pageIndex += 1
                    totalPages = max(totalPages, pageIndex)
                    startNewPage()
                }
                currentY += 14.0
            }

            // 8. Patient / Clinician Observations
            if !report.patientObservations.isEmpty || !report.clinicalNotes.isEmpty {
                if currentY + 80 > Self.maxY {
                    drawRunningFooter(context: context.cgContext, pageNumber: pageIndex, totalPages: totalPages)
                    pageIndex += 1
                    totalPages = max(totalPages, pageIndex)
                    startNewPage()
                }
                currentY = drawNotesSection(context: context.cgContext, report: report, startY: currentY)
            }

            // Draw footer on the final page
            drawRunningFooter(context: context.cgContext, pageNumber: pageIndex, totalPages: totalPages)
        }
    }

    // MARK: - Drawing Sections (UIKit)
    private func drawDocumentHeader(context: CGContext, report: ClinicianReport, startY: CGFloat) -> CGFloat {
        var y = startY

        // Medical Header Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .bold),
            .foregroundColor: UIColor(red: 0.05, green: 0.15, blue: 0.25, alpha: 1.0)
        ]
        "VIALR CLINICAL PROTOCOL RECORD & SUMMARY".draw(at: CGPoint(x: Self.marginHorizontal, y: y), withAttributes: titleAttrs)
        y += 18.0

        // Subtitle badge
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5, weight: .semibold),
            .foregroundColor: UIColor(red: 0.08, green: 0.65, blue: 0.55, alpha: 1.0)
        ]
        "CONFIDENTIAL MEDICAL REPORT • LONGITUDINAL PATIENT TRACKING".draw(at: CGPoint(x: Self.marginHorizontal, y: y), withAttributes: subAttrs)
        y += 14.0

        // Demographic Grid Box
        let boxRect = CGRect(x: Self.marginHorizontal, y: y, width: Self.contentWidth, height: 48.0)
        context.setFillColor(UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0).cgColor)
        context.fill(boxRect)
        context.setStrokeColor(UIColor(red: 0.88, green: 0.90, blue: 0.92, alpha: 1.0).cgColor)
        context.setLineWidth(0.8)
        context.stroke(boxRect)

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5, weight: .bold),
            .foregroundColor: UIColor(red: 0.45, green: 0.50, blue: 0.55, alpha: 1.0)
        ]
        let valAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.0, weight: .semibold),
            .foregroundColor: UIColor(red: 0.12, green: 0.15, blue: 0.18, alpha: 1.0)
        ]

        let col1 = Self.marginHorizontal + 8.0
        let col2 = Self.marginHorizontal + 180.0
        let col3 = Self.marginHorizontal + 360.0

        // Row 1
        "PATIENT IDENTIFIER".draw(at: CGPoint(x: col1, y: y + 5.0), withAttributes: labelAttrs)
        report.patientIdentifier.draw(at: CGPoint(x: col1, y: y + 15.0), withAttributes: valAttrs)

        "ATTENDING CLINICIAN".draw(at: CGPoint(x: col2, y: y + 5.0), withAttributes: labelAttrs)
        "\(report.clinicianName) (\(report.practiceOrClinic))".draw(at: CGPoint(x: col2, y: y + 15.0), withAttributes: valAttrs)

        "DATE RANGE".draw(at: CGPoint(x: col3, y: y + 5.0), withAttributes: labelAttrs)
        "\(report.dateRangeStart.formatted(date: .abbreviated, time: .omitted)) – \(report.dateRangeEnd.formatted(date: .abbreviated, time: .omitted))".draw(at: CGPoint(x: col3, y: y + 15.0), withAttributes: valAttrs)

        // Row 2
        "DATE OF BIRTH".draw(at: CGPoint(x: col1, y: y + 27.0), withAttributes: labelAttrs)
        (report.patientDateOfBirth ?? "Not Specified").draw(at: CGPoint(x: col1, y: y + 36.0), withAttributes: valAttrs)

        "REPORT GENERATED".draw(at: CGPoint(x: col2, y: y + 27.0), withAttributes: labelAttrs)
        report.generatedDate.formatted(date: .abbreviated, time: .shortened).draw(at: CGPoint(x: col2, y: y + 36.0), withAttributes: valAttrs)

        "RECORD ID".draw(at: CGPoint(x: col3, y: y + 27.0), withAttributes: labelAttrs)
        report.id.uuidString.prefix(12).uppercased().draw(at: CGPoint(x: col3, y: y + 36.0), withAttributes: valAttrs)

        y += 48.0
        return y
    }

    private func drawExecutiveSummary(context: CGContext, report: ClinicianReport, startY: CGFloat) -> CGFloat {
        var y = startY
        y = drawSectionHeading(context: context, title: "1. EXECUTIVE SUMMARY & DOSING ADHERENCE", startY: y)

        // 4 Stat Cards
        let cardWidth = (Self.contentWidth - 18.0) / 4.0
        let cardHeight: CGFloat = 42.0

        let stats: [(title: String, value: String, color: UIColor)] = [
            ("PROTOCOL ADHERENCE", "\(Int(report.adherencePercentage))%", report.adherencePercentage >= 85 ? UIColor(red: 0.08, green: 0.65, blue: 0.45, alpha: 1.0) : UIColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1.0)),
            ("DELIVERED DOSES", "\(report.totalDosesAdministered)", UIColor(red: 0.08, green: 0.60, blue: 0.65, alpha: 1.0)),
            ("MISSED / SKIPPED", "\(report.totalDosesMissed + report.totalDosesSkipped)", report.totalDosesMissed == 0 ? UIColor.darkGray : UIColor(red: 0.90, green: 0.25, blue: 0.20, alpha: 1.0)),
            ("ACTIVE PROTOCOLS", "\(report.activeProtocols.count)", UIColor(red: 0.20, green: 0.25, blue: 0.35, alpha: 1.0))
        ]

        for (i, stat) in stats.enumerated() {
            let cx = Self.marginHorizontal + CGFloat(i) * (cardWidth + 6.0)
            let cardRect = CGRect(x: cx, y: y, width: cardWidth, height: cardHeight)
            context.setFillColor(UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1.0).cgColor)
            context.fill(cardRect)
            context.setStrokeColor(UIColor(red: 0.88, green: 0.90, blue: 0.92, alpha: 1.0).cgColor)
            context.stroke(cardRect)

            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 7.0, weight: .bold),
                .foregroundColor: UIColor(red: 0.45, green: 0.50, blue: 0.55, alpha: 1.0)
            ]
            let valAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14.0, weight: .bold),
                .foregroundColor: stat.color
            ]
            stat.title.draw(at: CGPoint(x: cx + 6.0, y: y + 5.0), withAttributes: titleAttr)
            stat.value.draw(at: CGPoint(x: cx + 6.0, y: y + 18.0), withAttributes: valAttr)
        }

        y += cardHeight
        return y
    }

    private func drawProtocolsSection(context: CGContext, protocols: [ProtocolModel], startY: CGFloat) -> CGFloat {
        var y = startY
        y = drawSectionHeading(context: context, title: "2. ACTIVE PROTOCOL REGIMENS & SCHEDULES", startY: y)

        // Header Row
        let headerRect = CGRect(x: Self.marginHorizontal, y: y, width: Self.contentWidth, height: 16.0)
        context.setFillColor(UIColor(red: 0.92, green: 0.94, blue: 0.96, alpha: 1.0).cgColor)
        context.fill(headerRect)

        let hAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5, weight: .bold),
            .foregroundColor: UIColor(red: 0.25, green: 0.30, blue: 0.35, alpha: 1.0)
        ]
        "PROTOCOL & COMPOUNDS".draw(at: CGPoint(x: Self.marginHorizontal + 6.0, y: y + 3.5), withAttributes: hAttrs)
        "FREQUENCY & ROUTE".draw(at: CGPoint(x: Self.marginHorizontal + 220.0, y: y + 3.5), withAttributes: hAttrs)
        "START DATE".draw(at: CGPoint(x: Self.marginHorizontal + 360.0, y: y + 3.5), withAttributes: hAttrs)
        "CYCLE STATUS".draw(at: CGPoint(x: Self.marginHorizontal + 460.0, y: y + 3.5), withAttributes: hAttrs)
        y += 16.0

        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5, weight: .regular),
            .foregroundColor: UIColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1.0)
        ]

        for (idx, p) in protocols.enumerated() {
            let rowRect = CGRect(x: Self.marginHorizontal, y: y, width: Self.contentWidth, height: 18.0)
            if idx % 2 == 1 {
                context.setFillColor(UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0).cgColor)
                context.fill(rowRect)
            }
            let compDesc = p.compounds.map { "\($0.compoundName) \($0.dosageAmount)\($0.unit.rawValue)" }.joined(separator: ", ")
            let freqDesc = p.compounds.first?.frequency.rawValue ?? "Daily"
            let routeDesc = p.compounds.first?.route.rawValue ?? "SubQ"

            "\(p.name) (\(compDesc))".draw(at: CGPoint(x: Self.marginHorizontal + 6.0, y: y + 3.0), withAttributes: rowAttrs)
            "\(freqDesc) • \(routeDesc)".draw(at: CGPoint(x: Self.marginHorizontal + 220.0, y: y + 3.0), withAttributes: rowAttrs)
            p.startDate.formatted(date: .abbreviated, time: .omitted).draw(at: CGPoint(x: Self.marginHorizontal + 360.0, y: y + 3.0), withAttributes: rowAttrs)
            "\(p.status.rawValue) (\(p.cycleDurationWeeks) wks)".draw(at: CGPoint(x: Self.marginHorizontal + 460.0, y: y + 3.0), withAttributes: rowAttrs)

            y += 18.0
        }

        return y
    }

    private func drawCompoundSummaries(context: CGContext, summaries: [CompoundDoseSummary], startY: CGFloat) -> CGFloat {
        var y = startY
        y = drawSectionHeading(context: context, title: "3. ADMINISTERED COMPOUNDS & DOSAGE DELIVERED", startY: y)

        let headerRect = CGRect(x: Self.marginHorizontal, y: y, width: Self.contentWidth, height: 16.0)
        context.setFillColor(UIColor(red: 0.92, green: 0.94, blue: 0.96, alpha: 1.0).cgColor)
        context.fill(headerRect)

        let hAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5, weight: .bold),
            .foregroundColor: UIColor(red: 0.25, green: 0.30, blue: 0.35, alpha: 1.0)
        ]
        "COMPOUND".draw(at: CGPoint(x: Self.marginHorizontal + 6.0, y: y + 3.5), withAttributes: hAttrs)
        "TOTAL DELIVERED".draw(at: CGPoint(x: Self.marginHorizontal + 160.0, y: y + 3.5), withAttributes: hAttrs)
        "INJECTIONS".draw(at: CGPoint(x: Self.marginHorizontal + 270.0, y: y + 3.5), withAttributes: hAttrs)
        "AVG DOSE & ROUTE".draw(at: CGPoint(x: Self.marginHorizontal + 350.0, y: y + 3.5), withAttributes: hAttrs)
        "COMPLIANCE".draw(at: CGPoint(x: Self.marginHorizontal + 470.0, y: y + 3.5), withAttributes: hAttrs)
        y += 16.0

        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5, weight: .regular),
            .foregroundColor: UIColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1.0)
        ]

        for (idx, s) in summaries.enumerated() {
            let rowRect = CGRect(x: Self.marginHorizontal, y: y, width: Self.contentWidth, height: 18.0)
            if idx % 2 == 1 {
                context.setFillColor(UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0).cgColor)
                context.fill(rowRect)
            }
            s.compoundName.draw(at: CGPoint(x: Self.marginHorizontal + 6.0, y: y + 3.0), withAttributes: rowAttrs)
            "\(String(format: "%.1f", s.totalDoseDelivered)) \(s.unit.rawValue)".draw(at: CGPoint(x: Self.marginHorizontal + 160.0, y: y + 3.0), withAttributes: rowAttrs)
            "\(s.numberOfInjections) doses".draw(at: CGPoint(x: Self.marginHorizontal + 270.0, y: y + 3.0), withAttributes: rowAttrs)
            "\(String(format: "%.1f", s.averageDose)) \(s.unit.rawValue) (\(s.mostFrequentSite))".draw(at: CGPoint(x: Self.marginHorizontal + 350.0, y: y + 3.0), withAttributes: rowAttrs)
            "\(Int(s.compliancePercentage))%".draw(at: CGPoint(x: Self.marginHorizontal + 470.0, y: y + 3.0), withAttributes: rowAttrs)

            y += 18.0
        }

        return y
    }

    private func drawLabPanels(context: CGContext, panels: [BiomarkerPanelSummary], startY: CGFloat, onPageBreak: () -> Void) -> CGFloat {
        var y = startY
        y = drawSectionHeading(context: context, title: "4. OBJECTIVE LABORATORY BIOMARKERS & BLOODWORK", startY: y)

        let hAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5, weight: .bold),
            .foregroundColor: UIColor(red: 0.25, green: 0.30, blue: 0.35, alpha: 1.0)
        ]
        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.0, weight: .regular),
            .foregroundColor: UIColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1.0)
        ]
        let flagAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5, weight: .bold),
            .foregroundColor: UIColor(red: 0.90, green: 0.25, blue: 0.20, alpha: 1.0)
        ]

        for panel in panels {
            if y + 40 > Self.maxY {
                onPageBreak()
                y = drawSectionHeading(context: context, title: "4. OBJECTIVE LABORATORY BIOMARKERS (CONT.)", startY: Self.marginTop + 28.0)
            }

            // Panel Title Banner
            let pRect = CGRect(x: Self.marginHorizontal, y: y, width: Self.contentWidth, height: 16.0)
            context.setFillColor(UIColor(red: 0.90, green: 0.93, blue: 0.96, alpha: 1.0).cgColor)
            context.fill(pRect)
            "PANEL: \(panel.panelName) (\(panel.labName)) — Collected: \(panel.collectionDate.formatted(date: .abbreviated, time: .omitted))".draw(at: CGPoint(x: Self.marginHorizontal + 6.0, y: y + 3.0), withAttributes: hAttrs)
            y += 16.0

            for (idx, r) in panel.results.enumerated() {
                if y + 18 > Self.maxY {
                    onPageBreak()
                    y = drawSectionHeading(context: context, title: "4. OBJECTIVE LABORATORY BIOMARKERS (CONT.)", startY: Self.marginTop + 28.0)
                }

                let rowRect = CGRect(x: Self.marginHorizontal, y: y, width: Self.contentWidth, height: 16.0)
                if idx % 2 == 1 {
                    context.setFillColor(UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0).cgColor)
                    context.fill(rowRect)
                }

                r.biomarkerName.draw(at: CGPoint(x: Self.marginHorizontal + 6.0, y: y + 2.5), withAttributes: rowAttrs)
                r.formattedValue.draw(at: CGPoint(x: Self.marginHorizontal + 220.0, y: y + 2.5), withAttributes: rowAttrs)
                "Ref: \(r.referenceRangeDisplay)".draw(at: CGPoint(x: Self.marginHorizontal + 330.0, y: y + 2.5), withAttributes: rowAttrs)

                if r.isAbnormal {
                    "[\(r.flag.uppercased())]".draw(at: CGPoint(x: Self.marginHorizontal + 470.0, y: y + 2.5), withAttributes: flagAttrs)
                } else {
                    "Optimal".draw(at: CGPoint(x: Self.marginHorizontal + 470.0, y: y + 2.5), withAttributes: rowAttrs)
                }

                y += 16.0
            }
            y += 4.0
        }

        return y
    }

    private func drawMeasurements(context: CGContext, measurements: [MeasurementMetricSummary], startY: CGFloat, onPageBreak: () -> Void) -> CGFloat {
        var y = startY
        y = drawSectionHeading(context: context, title: "5. LONGITUDINAL VITALS & BIOMETRIC MEASUREMENTS", startY: y)

        let hAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5, weight: .bold),
            .foregroundColor: UIColor(red: 0.25, green: 0.30, blue: 0.35, alpha: 1.0)
        ]
        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.0, weight: .regular),
            .foregroundColor: UIColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1.0)
        ]

        let headerRect = CGRect(x: Self.marginHorizontal, y: y, width: Self.contentWidth, height: 16.0)
        context.setFillColor(UIColor(red: 0.92, green: 0.94, blue: 0.96, alpha: 1.0).cgColor)
        context.fill(headerRect)

        "METRIC & CATEGORY".draw(at: CGPoint(x: Self.marginHorizontal + 6.0, y: y + 3.5), withAttributes: hAttrs)
        "LATEST RECORDED".draw(at: CGPoint(x: Self.marginHorizontal + 220.0, y: y + 3.5), withAttributes: hAttrs)
        "READINGS / INTERVAL".draw(at: CGPoint(x: Self.marginHorizontal + 340.0, y: y + 3.5), withAttributes: hAttrs)
        "STATUS".draw(at: CGPoint(x: Self.marginHorizontal + 470.0, y: y + 3.5), withAttributes: hAttrs)
        y += 16.0

        for (idx, m) in measurements.enumerated() {
            if y + 18 > Self.maxY {
                onPageBreak()
                y = drawSectionHeading(context: context, title: "5. LONGITUDINAL VITALS (CONT.)", startY: Self.marginTop + 28.0)
            }

            let rowRect = CGRect(x: Self.marginHorizontal, y: y, width: Self.contentWidth, height: 16.0)
            if idx % 2 == 1 {
                context.setFillColor(UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0).cgColor)
                context.fill(rowRect)
            }

            "\(m.metricName) [\(m.category)]".draw(at: CGPoint(x: Self.marginHorizontal + 6.0, y: y + 2.5), withAttributes: rowAttrs)
            m.formattedValue.draw(at: CGPoint(x: Self.marginHorizontal + 220.0, y: y + 2.5), withAttributes: rowAttrs)
            "\(m.entryCount) readings (\(m.dateRecorded.formatted(date: .abbreviated, time: .omitted)))".draw(at: CGPoint(x: Self.marginHorizontal + 340.0, y: y + 2.5), withAttributes: rowAttrs)
            m.status.draw(at: CGPoint(x: Self.marginHorizontal + 470.0, y: y + 2.5), withAttributes: rowAttrs)

            y += 16.0
        }

        return y
    }

    private func drawSymptomSummary(context: CGContext, symptom: SymptomQualitySummary, startY: CGFloat) -> CGFloat {
        var y = startY
        y = drawSectionHeading(context: context, title: "6. SUBJECTIVE SYMPTOMS, TOLERABILITY & RECOVERY", startY: y)

        let boxRect = CGRect(x: Self.marginHorizontal, y: y, width: Self.contentWidth, height: 42.0)
        context.setFillColor(UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1.0).cgColor)
        context.fill(boxRect)
        context.setStrokeColor(UIColor(red: 0.88, green: 0.90, blue: 0.92, alpha: 1.0).cgColor)
        context.stroke(boxRect)

        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5, weight: .regular),
            .foregroundColor: UIColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1.0)
        ]

        let sideEffectsStr = symptom.reportedSideEffects.isEmpty ? "None Reported" : symptom.reportedSideEffects.joined(separator: ", ")
        "Composite Well-Being: \(Int(symptom.averageWellbeingScore))/100 | Energy: \(String(format: "%.1f", symptom.averageEnergy))/10 | Sleep: \(String(format: "%.1f", symptom.averageSleepQuality))/10 | Recovery: \(String(format: "%.1f", symptom.averageRecovery))/10".draw(at: CGPoint(x: Self.marginHorizontal + 8.0, y: y + 6.0), withAttributes: textAttrs)
        "Total Check-ins: \(symptom.totalLogsCount) | Reported Side Effects: \(sideEffectsStr)".draw(at: CGPoint(x: Self.marginHorizontal + 8.0, y: y + 22.0), withAttributes: textAttrs)

        y += 42.0
        return y
    }

    private func drawChronologicalLedger(context: CGContext, ledger: [ClinicianLedgerItem], startY: CGFloat, onPageBreak: () -> Void) -> CGFloat {
        var y = startY
        y = drawSectionHeading(context: context, title: "7. LONGITUDINAL CHRONOLOGICAL CLINICAL LEDGER", startY: y)

        let hAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5, weight: .bold),
            .foregroundColor: UIColor(red: 0.25, green: 0.30, blue: 0.35, alpha: 1.0)
        ]
        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5, weight: .regular),
            .foregroundColor: UIColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1.0)
        ]

        let headerRect = CGRect(x: Self.marginHorizontal, y: y, width: Self.contentWidth, height: 16.0)
        context.setFillColor(UIColor(red: 0.92, green: 0.94, blue: 0.96, alpha: 1.0).cgColor)
        context.fill(headerRect)

        "DATE & TIME".draw(at: CGPoint(x: Self.marginHorizontal + 6.0, y: y + 3.5), withAttributes: hAttrs)
        "CATEGORY".draw(at: CGPoint(x: Self.marginHorizontal + 110.0, y: y + 3.5), withAttributes: hAttrs)
        "CLINICAL EVENT / DETAIL".draw(at: CGPoint(x: Self.marginHorizontal + 220.0, y: y + 3.5), withAttributes: hAttrs)
        "METRIC / STATUS".draw(at: CGPoint(x: Self.marginHorizontal + 440.0, y: y + 3.5), withAttributes: hAttrs)
        y += 16.0

        for (idx, item) in ledger.enumerated() {
            if y + 18 > Self.maxY {
                onPageBreak()
                y = drawSectionHeading(context: context, title: "7. CHRONOLOGICAL CLINICAL LEDGER (CONT.)", startY: Self.marginTop + 28.0)
            }

            let rowRect = CGRect(x: Self.marginHorizontal, y: y, width: Self.contentWidth, height: 16.0)
            if idx % 2 == 1 {
                context.setFillColor(UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0).cgColor)
                context.fill(rowRect)
            }

            item.timestamp.formatted(date: .numeric, time: .shortened).draw(at: CGPoint(x: Self.marginHorizontal + 6.0, y: y + 2.5), withAttributes: rowAttrs)
            item.category.rawValue.draw(at: CGPoint(x: Self.marginHorizontal + 110.0, y: y + 2.5), withAttributes: rowAttrs)
            "\(item.title) - \(item.subtitle)".draw(at: CGPoint(x: Self.marginHorizontal + 220.0, y: y + 2.5), withAttributes: rowAttrs)
            (item.metricsSummary ?? item.statusOrFlag ?? "").draw(at: CGPoint(x: Self.marginHorizontal + 440.0, y: y + 2.5), withAttributes: rowAttrs)

            y += 16.0
        }

        return y
    }

    private func drawNotesSection(context: CGContext, report: ClinicianReport, startY: CGFloat) -> CGFloat {
        var y = startY
        y = drawSectionHeading(context: context, title: "8. PRACTITIONER & PATIENT OBSERVATIONS", startY: y)

        let notesText = !report.patientObservations.isEmpty ? report.patientObservations : report.clinicalNotes
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.0, weight: .regular),
            .foregroundColor: UIColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1.0)
        ]

        let rect = CGRect(x: Self.marginHorizontal, y: y, width: Self.contentWidth, height: 40.0)
        notesText.draw(in: rect, withAttributes: textAttrs)
        y += 40.0
        return y
    }

    private func drawSectionHeading(context: CGContext, title: String, startY: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.0, weight: .bold),
            .foregroundColor: UIColor(red: 0.08, green: 0.45, blue: 0.55, alpha: 1.0)
        ]
        title.draw(at: CGPoint(x: Self.marginHorizontal, y: startY), withAttributes: attrs)

        context.setStrokeColor(UIColor(red: 0.08, green: 0.45, blue: 0.55, alpha: 0.4).cgColor)
        context.setLineWidth(0.8)
        context.move(to: CGPoint(x: Self.marginHorizontal, y: startY + 13.0))
        context.addLine(to: CGPoint(x: Self.pageWidth - Self.marginHorizontal, y: startY + 13.0))
        context.strokePath()

        return startY + 18.0
    }

    private func drawRunningHeader(context: CGContext, report: ClinicianReport, pageNumber: Int) {
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5, weight: .regular),
            .foregroundColor: UIColor.gray
        ]
        let headerText = "VIALR CLINICAL SUMMARY • \(report.patientIdentifier) • \(report.dateRangeStart.formatted(date: .abbreviated, time: .omitted)) – \(report.dateRangeEnd.formatted(date: .abbreviated, time: .omitted))"
        headerText.draw(at: CGPoint(x: Self.marginHorizontal, y: Self.marginTop), withAttributes: headerAttrs)

        context.setStrokeColor(UIColor(white: 0.85, alpha: 1.0).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: Self.marginHorizontal, y: Self.marginTop + 12.0))
        context.addLine(to: CGPoint(x: Self.pageWidth - Self.marginHorizontal, y: Self.marginTop + 12.0))
        context.strokePath()
    }

    private func drawRunningFooter(context: CGContext, pageNumber: Int, totalPages: Int) {
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.0, weight: .regular),
            .foregroundColor: UIColor.lightGray
        ]
        let footerText = "CONFIDENTIAL MEDICAL RECORD • PRODUCED VIA VIALR SECURE CLINICAL ENGINE"
        footerText.draw(at: CGPoint(x: Self.marginHorizontal, y: Self.pageHeight - 24.0), withAttributes: footerAttrs)

        let pageStr = "Page \(pageNumber)"
        pageStr.draw(at: CGPoint(x: Self.pageWidth - Self.marginHorizontal - 40.0, y: Self.pageHeight - 24.0), withAttributes: footerAttrs)
    }
    #endif

    // MARK: - AppKit Renderer (macOS)
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func renderWithAppKit(report: ClinicianReport) -> Data {
        return renderVectorPDFStream(report: report)
    }
    #endif

    // MARK: - Cross-Platform Vector Stream Fallback
    public func renderVectorPDFStream(report: ClinicianReport) -> Data {
        var pdf = "%PDF-1.4\n"
        pdf += "%\u{E2}\u{E3}\u{CF}\u{D3}\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let startStr = dateFormatter.string(from: report.dateRangeStart)
        let endStr = dateFormatter.string(from: report.dateRangeEnd)
        let genStr = dateFormatter.string(from: report.generatedDate)

        var textLines: [String] = []
        textLines.append("VIALR CLINICAL PROTOCOL SUMMARY & RECORD")
        textLines.append("CONFIDENTIAL MEDICAL DOCUMENT - STRICTLY FOR CLINICIAN REVIEW")
        textLines.append("--------------------------------------------------------------------------------")
        textLines.append("Patient: \(report.patientIdentifier) | DOB: \(report.patientDateOfBirth ?? "N/A")")
        textLines.append("Clinician: \(report.clinicianName) | Clinic: \(report.practiceOrClinic)")
        textLines.append("Date Interval: \(startStr) to \(endStr) | Generated: \(genStr)")
        textLines.append("--------------------------------------------------------------------------------")
        textLines.append("")
        textLines.append("1. EXECUTIVE SUMMARY & ADHERENCE")
        textLines.append("Compliance Rate: \(Int(report.adherencePercentage))% | Delivered: \(report.totalDosesAdministered) | Missed: \(report.totalDosesMissed)")
        textLines.append("Active Protocols (\(report.activeProtocols.count)): \(report.activeProtocols.map(\.name).joined(separator: ", "))")
        textLines.append("")

        if !report.doseSummary.isEmpty {
            textLines.append("2. ADMINISTERED COMPOUNDS & DOSAGE DELIVERED")
            for s in report.doseSummary {
                textLines.append(" - \(s.compoundName): \(String(format: "%.1f", s.totalDoseDelivered)) \(s.unit.rawValue) across \(s.numberOfInjections) injections (\(s.mostFrequentSite), \(s.route)). Adherence: \(Int(s.compliancePercentage))%")
            }
            textLines.append("")
        }

        if !report.labPanels.isEmpty {
            textLines.append("3. LABORATORY BLOODWORK & BIOMARKER FINDINGS")
            for panel in report.labPanels {
                textLines.append(" [Panel: \(panel.panelName) - \(panel.labName) on \(dateFormatter.string(from: panel.collectionDate))]")
                for r in panel.results {
                    let flagStr = r.isAbnormal ? " [FLAG: \(r.flag)]" : " [Normal]"
                    textLines.append("   * \(r.biomarkerName): \(r.formattedValue) (Ref: \(r.referenceRangeDisplay))\(flagStr)")
                }
            }
            textLines.append("")
        }

        if !report.measurementSummaries.isEmpty {
            textLines.append("4. LONGITUDINAL VITALS & BIOMETRIC READINGS")
            for m in report.measurementSummaries {
                textLines.append(" - \(m.metricName): Latest \(m.formattedValue) [\(m.category)] (\(m.entryCount) readings)")
            }
            textLines.append("")
        }

        if let sym = report.symptomSummary {
            textLines.append("5. SUBJECTIVE SYMPTOM TOLERABILITY & RECOVERY")
            textLines.append("Wellbeing Score: \(Int(sym.averageWellbeingScore))/100 | Energy: \(String(format: "%.1f", sym.averageEnergy))/10 | Sleep: \(String(format: "%.1f", sym.averageSleepQuality))/10")
            if !sym.reportedSideEffects.isEmpty {
                textLines.append("Reported Side Effects: \(sym.reportedSideEffects.joined(separator: ", "))")
            }
            textLines.append("")
        }

        if !report.chronologicalLedger.isEmpty {
            textLines.append("6. CHRONOLOGICAL CLINICAL LEDGER (Total Items: \(report.chronologicalLedger.count))")
            textLines.append("DATE & TIME        | CATEGORY             | EVENT                                | METRIC")
            textLines.append("--------------------------------------------------------------------------------")
            for item in report.chronologicalLedger.prefix(40) {
                let dtStr = dateFormatter.string(from: item.timestamp)
                let cat = item.category.rawValue.padding(toLength: 20, withPad: " ", startingAt: 0)
                let title = item.title.padding(toLength: 36, withPad: " ", startingAt: 0)
                let val = item.metricsSummary ?? item.statusOrFlag ?? ""
                textLines.append("\(dtStr) | \(cat) | \(title) | \(val)")
            }
            textLines.append("")
        }

        var streamContent = "BT\n/F1 9 Tf\n12 TL\n40 750 Td\n"
        for line in textLines {
            let sanitized = line
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "(", with: "\\(")
                .replacingOccurrences(of: ")", with: "\\)")
            streamContent += "(\(sanitized)) '\n"
        }
        streamContent += "ET\n"

        let streamBytes = streamContent.data(using: .utf8) ?? Data()

        var objects: [String] = []
        objects.append("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
        objects.append("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
        objects.append("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n")
        objects.append("4 0 obj\n<< /Length \(streamBytes.count) >>\nstream\n\(streamContent)endstream\nendobj\n")
        objects.append("5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>\nendobj\n")

        var xrefOffsets: [Int] = [0]
        var currentOffset = pdf.utf8.count

        for obj in objects {
            xrefOffsets.append(currentOffset)
            pdf += obj
            currentOffset = pdf.utf8.count
        }

        let startXref = currentOffset
        pdf += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
        for offset in xrefOffsets.dropFirst() {
            pdf += String(format: "%010d 00000 n \n", offset)
        }

        pdf += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(startXref)\n%%EOF\n"

        return pdf.data(using: .utf8) ?? Data()
    }
}
