import SwiftUI
import Domain
import DesignSystem
import Data
import Analytics

#if canImport(PDFKit)
import PDFKit
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

public struct ClinicianReportView: View {
    @State private var configuration = ClinicianReportConfiguration()
    @State private var report: ClinicianReport?
    @State private var pdfData: Data?
    #if canImport(PDFKit)
    @State private var pdfDocument: PDFDocument?
    #endif
    @State private var selectedTab: ReportViewTab = .ledger
    @State private var isCustomizing: Bool = false
    @State private var isGenerating: Bool = false
    @State private var exportedPdfUrl: URL?
    @State private var showShareSheet: Bool = false
    @Environment(\.dismiss) private var dismiss

    private let reportGenerator = ClinicianReportGenerator()
    private let pdfRenderer = ClinicianPDFRenderer.shared

    public enum ReportViewTab: String, CaseIterable, Identifiable {
        case ledger = "Clinical Ledger"
        case pdf = "PDF Preview"

        public var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Date Preset Selector
                    datePresetBar
                        .padding(.vertical, 8)
                        .background(VialrColors.backgroundSecondary)

                    // View Mode Switcher
                    Picker("View Mode", selection: $selectedTab) {
                        ForEach(ReportViewTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, VialrSpacing.md)
                    .padding(.vertical, 8)

                    // Main Content
                    if isGenerating {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(VialrColors.accentTeal)
                            Text("Compiling longitudinal protocol record...")
                                .font(VialrTypography.footnote)
                                .foregroundColor(VialrColors.textSecondary)
                        }
                        Spacer()
                    } else if let report = report {
                        switch selectedTab {
                        case .ledger:
                            ledgerScrollView(report)
                        case .pdf:
                            pdfPreviewView(report)
                        }
                    } else {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(VialrColors.textTertiary)
                            Text("No report data available for this range.")
                                .font(VialrTypography.footnote)
                                .foregroundColor(VialrColors.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Clinician Report")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(VialrColors.accentTeal)
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        isCustomizing = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(VialrColors.accentTeal)
                    }

                    if let url = exportedPdfUrl {
                        ShareLink(item: url, preview: SharePreview("Vialr Medical Protocol Report", image: Image(systemName: "doc.text.fill"))) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(VialrColors.accentTeal)
                        }
                    } else if let data = pdfData {
                        Button {
                            prepareAndShowShareSheet(data: data)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(VialrColors.accentTeal)
                        }
                    }
                }
            }
            .sheet(isPresented: $isCustomizing) {
                configurationSheet
            }
            #if os(iOS)
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedPdfUrl {
                    ActivityView(activityItems: [url])
                }
            }
            #endif
            .task {
                await generateReport()
            }
        }
    }

    // MARK: - Date Range Preset Bar
    private var datePresetBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DateRangePreset.allCases) { preset in
                    Button {
                        configuration.preset = preset
                        Task { await generateReport() }
                    } label: {
                        Text(preset.rawValue)
                            .font(VialrTypography.captionBold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                configuration.preset == preset
                                    ? VialrColors.accentTeal
                                    : VialrColors.backgroundTertiary
                            )
                            .foregroundColor(
                                configuration.preset == preset
                                    ? Color.black
                                    : VialrColors.textSecondary
                            )
                            .cornerRadius(14)
                    }
                }
            }
            .padding(.horizontal, VialrSpacing.md)
        }
    }

    // MARK: - Clinical Ledger Scroll View
    private func ledgerScrollView(_ report: ClinicianReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VialrSpacing.lg) {
                // Demographics & Medical Header Card
                medicalHeaderCard(report)

                // Compliance & Executive Stats Grid
                complianceStatsGrid(report)

                // Active & Historical Protocols
                if !report.activeProtocols.isEmpty || !report.historicalProtocols.isEmpty {
                    protocolsCard(report)
                }

                // Administered Compound Exposure Summary
                if !report.doseSummary.isEmpty {
                    compoundsSummaryCard(report)
                }

                // Objective Laboratory Biomarkers
                if !report.labPanels.isEmpty || !report.latestBiomarkers.isEmpty {
                    laboratoryCard(report)
                }

                // Longitudinal Vitals & Physical Measurements
                if !report.measurementSummaries.isEmpty {
                    measurementsCard(report)
                }

                // Subjective Tolerability & Quality of Life
                if let sym = report.symptomSummary {
                    symptomsCard(sym)
                }

                // Longitudinal Chronological Clinical Ledger
                if !report.chronologicalLedger.isEmpty {
                    chronologicalLedgerCard(report)
                }

                // Observations & Notes
                if !report.patientObservations.isEmpty || !report.clinicalNotes.isEmpty {
                    notesCard(report)
                }
            }
            .padding(VialrSpacing.md)
        }
    }

    // MARK: - PDF Preview Tab View
    private func pdfPreviewView(_ report: ClinicianReport) -> some View {
        VStack(spacing: 0) {
            #if canImport(PDFKit)
            if let doc = pdfDocument {
                PDFKitViewRepresentable(pdfDocument: doc)
                    .background(Color(white: 0.15))
            } else {
                ProgressView()
                    .padding(40)
            }
            #else
            ScrollView {
                Text(report.clinicalNotes)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(VialrColors.textPrimary)
                    .padding()
            }
            #endif

            // Export Actions Footer
            HStack(spacing: VialrSpacing.md) {
                if let url = exportedPdfUrl {
                    ShareLink(item: url, preview: SharePreview("Vialr Clinician Summary.pdf", image: Image(systemName: "doc.text.fill"))) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export PDF Document")
                                .font(VialrTypography.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(VialrColors.accentTeal)
                        .foregroundColor(Color.black)
                        .cornerRadius(12)
                    }
                } else if let data = pdfData {
                    Button {
                        prepareAndShowShareSheet(data: data)
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export PDF Document")
                                .font(VialrTypography.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(VialrColors.accentTeal)
                        .foregroundColor(Color.black)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(VialrSpacing.md)
            .background(VialrColors.backgroundSecondary)
        }
    }

    // MARK: - Section Cards

    private func medicalHeaderCard(_ report: ClinicianReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CLINICAL PROTOCOL RECORD")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Spacer()
                Text("CONFIDENTIAL")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(VialrColors.backgroundTertiary)
                    .cornerRadius(4)
            }

            Text(report.patientIdentifier)
                .font(VialrTypography.title1)
                .foregroundColor(VialrColors.textPrimary)

            Text("Attending: \(report.clinicianName) • \(report.practiceOrClinic)")
                .font(VialrTypography.subheadline)
                .foregroundColor(VialrColors.textSecondary)

            Divider()
                .background(VialrColors.cardBorder)
                .padding(.vertical, 2)

            HStack {
                Text("Date Interval: \(report.dateRangeStart.formatted(date: .abbreviated, time: .omitted)) – \(report.dateRangeEnd.formatted(date: .abbreviated, time: .omitted))")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textSecondary)
                Spacer()
                Text("Total Events: \(report.totalLedgerCount)")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textTertiary)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func complianceStatsGrid(_ report: ClinicianReport) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("EXECUTIVE PROTOCOL METRICS")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.textTertiary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statBox(title: "ADHERENCE RATE", value: "\(Int(report.adherencePercentage))%", color: report.adherencePercentage >= 85 ? VialrColors.accentEmerald : VialrColors.accentAmber)
                statBox(title: "DELIVERED DOSES", value: "\(report.totalDosesAdministered)", color: VialrColors.accentTeal)
                statBox(title: "MISSED / SKIPPED", value: "\(report.totalDosesMissed + report.totalDosesSkipped)", color: report.totalDosesMissed == 0 ? VialrColors.textSecondary : VialrColors.accentRose)
                statBox(title: "LABS EVALUATED", value: "\(report.labPanels.count) panels", color: VialrColors.accentCyan)
            }
        }
    }

    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.textTertiary)
            Text(value)
                .font(VialrTypography.title2)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .vialrCard()
    }

    private func protocolsCard(_ report: ClinicianReport) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("PROTOCOL REGIMENS")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            ForEach(report.activeProtocols) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name)
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)
                        let comp = p.compounds.map { "\($0.compoundName) \($0.dosageAmount)\($0.unit.rawValue)" }.joined(separator: ", ")
                        Text(comp)
                            .font(VialrTypography.footnote)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(p.status.rawValue.uppercased())
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentEmerald)
                        Text("\(p.cycleDurationWeeks) wks cycle")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }
                }
                .padding(.vertical, 4)
                if p.id != report.activeProtocols.last?.id {
                    Divider().background(VialrColors.cardBorder)
                }
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func compoundsSummaryCard(_ report: ClinicianReport) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("ADMINISTERED COMPOUNDS & DOSAGE")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            ForEach(report.doseSummary) { s in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.compoundName)
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)
                        Text("\(s.numberOfInjections) doses • \(s.mostFrequentSite)")
                            .font(VialrTypography.footnote)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(String(format: "%.0f", s.totalDoseDelivered)) \(s.unit.rawValue)")
                            .font(VialrTypography.monoDose)
                            .foregroundColor(VialrColors.accentEmerald)
                        Text("\(Int(s.compliancePercentage))% compliance")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }
                }
                .padding(.vertical, 4)
                if s.id != report.doseSummary.last?.id {
                    Divider().background(VialrColors.cardBorder)
                }
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func laboratoryCard(_ report: ClinicianReport) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("LABORATORY BIOMARKERS & BLOODWORK")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Spacer()
                if report.abnormalBiomarkersCount > 0 {
                    Text("\(report.abnormalBiomarkersCount) OUT OF BOUNDS")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentRose)
                }
            }

            ForEach(report.labPanels) { panel in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(panel.panelName)
                            .font(VialrTypography.headline)
                            .foregroundColor(VialrColors.textPrimary)
                        Spacer()
                        Text(panel.collectionDate.formatted(date: .abbreviated, time: .omitted))
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }

                    ForEach(panel.results) { r in
                        HStack {
                            Text(r.biomarkerName)
                                .font(VialrTypography.bodyMedium)
                                .foregroundColor(VialrColors.textPrimary)
                            Spacer()
                            Text(r.formattedValue)
                                .font(VialrTypography.monoDose)
                                .foregroundColor(r.isAbnormal ? VialrColors.accentRose : VialrColors.accentEmerald)
                            Text(r.isAbnormal ? r.flag.uppercased() : "NORMAL")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(r.isAbnormal ? VialrColors.accentRose : VialrColors.accentEmerald)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(r.isAbnormal ? VialrColors.accentRose.opacity(0.15) : VialrColors.accentEmerald.opacity(0.15))
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(10)
                .background(VialrColors.backgroundTertiary)
                .cornerRadius(10)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func measurementsCard(_ report: ClinicianReport) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("LONGITUDINAL VITALS & MEASUREMENTS")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            ForEach(report.measurementSummaries) { m in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.metricName)
                            .font(VialrTypography.bodyMedium)
                            .foregroundColor(VialrColors.textPrimary)
                        Text("\(m.entryCount) readings • \(m.category)")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    }
                    Spacer()
                    Text(m.formattedValue)
                        .font(VialrTypography.monoDose)
                        .foregroundColor(VialrColors.textPrimary)
                }
                .padding(.vertical, 3)
                if m.id != report.measurementSummaries.last?.id {
                    Divider().background(VialrColors.cardBorder)
                }
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func symptomsCard(_ sym: SymptomQualitySummary) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("SUBJECTIVE WELL-BEING & TOLERABILITY")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ENERGY")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.textTertiary)
                    Text("\(String(format: "%.1f", sym.averageEnergy))/10")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("SLEEP")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.textTertiary)
                    Text("\(String(format: "%.1f", sym.averageSleepQuality))/10")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("RECOVERY")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.textTertiary)
                    Text("\(String(format: "%.1f", sym.averageRecovery))/10")
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textPrimary)
                }
            }

            if !sym.reportedSideEffects.isEmpty {
                Text("Reported Side Effects: \(sym.reportedSideEffects.joined(separator: ", "))")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.accentAmber)
                    .padding(.top, 4)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func chronologicalLedgerCard(_ report: ClinicianReport) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("CHRONOLOGICAL CLINICAL LEDGER")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Spacer()
                Text("\(report.chronologicalLedger.count) entries")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            ForEach(report.chronologicalLedger.prefix(30)) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: item.category.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: item.statusColorHex ?? item.category.defaultColorHex))
                        .frame(width: 20)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(item.title)
                                .font(VialrTypography.bodyMedium)
                                .foregroundColor(VialrColors.textPrimary)
                            Spacer()
                            Text(item.timestamp.formatted(date: .numeric, time: .shortened))
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                        }
                        Text(item.subtitle)
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)

                        if let detail = item.detail, !detail.isEmpty {
                            Text(detail)
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                                .padding(.top, 1)
                        }
                    }
                }
                .padding(.vertical, 4)
                if item.id != report.chronologicalLedger.prefix(30).last?.id {
                    Divider().background(VialrColors.cardBorder)
                }
            }

            if report.chronologicalLedger.count > 30 {
                Text("+ \(report.chronologicalLedger.count - 30) older chronological events in complete report")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.accentTeal)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func notesCard(_ report: ClinicianReport) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            Text("CLINICAL NOTES & OBSERVATIONS")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            let notes = !report.patientObservations.isEmpty ? report.patientObservations : report.clinicalNotes
            Text(notes)
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Configuration Sheet
    private var configurationSheet: some View {
        NavigationStack {
            Form {
                Section("Clinician & Patient Details") {
                    TextField("Patient Name", text: $configuration.patientName)
                    TextField("Patient Date of Birth", text: $configuration.patientDateOfBirth)
                    TextField("Attending Clinician", text: $configuration.clinicianName)
                    TextField("Clinic / Practice", text: $configuration.practiceOrClinic)
                }

                Section("Evaluation Date Range") {
                    Picker("Preset", selection: $configuration.preset) {
                        ForEach(DateRangePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }

                    if configuration.preset == .custom {
                        DatePicker("Start Date", selection: $configuration.customStartDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $configuration.customEndDate, displayedComponents: .date)
                    }
                }

                Section("Include Sections") {
                    Toggle("Protocol Regimens", isOn: $configuration.includeProtocols)
                    Toggle("Administered Doses", isOn: $configuration.includeDoses)
                    Toggle("Biomarkers & Bloodwork", isOn: $configuration.includeLabs)
                    Toggle("Vitals & Measurements", isOn: $configuration.includeMeasurements)
                    Toggle("Symptoms & Tolerability", isOn: $configuration.includeSymptoms)
                    Toggle("Practitioner Notes", isOn: $configuration.includeNotes)
                }

                Section("Notes / Concerns for Physician") {
                    TextEditor(text: $configuration.patientNotes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Report Options")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isCustomizing = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        isCustomizing = false
                        Task { await generateReport() }
                    }
                    .foregroundColor(VialrColors.accentTeal)
                }
            }
        }
    }

    // MARK: - Report & PDF Generation Logic
    private func generateReport() async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            let generated = try await reportGenerator.generateReport(configuration: configuration)
            self.report = generated

            let pdfBytes = pdfRenderer.renderPDFData(from: generated)
            self.pdfData = pdfBytes

            #if canImport(PDFKit)
            self.pdfDocument = PDFDocument(data: pdfBytes)
            #endif

            // Prepare exportable file
            self.exportedPdfUrl = preparePdfFile(data: pdfBytes, patientName: generated.patientIdentifier)
        } catch {
            print("Failed to generate clinician report: \(error)")
        }
    }

    private func preparePdfFile(data: Data, patientName: String) -> URL? {
        let safeName = patientName.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
        let dateStr = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
        let fileName = "Vialr_Clinician_Report_\(safeName)_\(dateStr).pdf"
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempUrl)
        return tempUrl
    }

    private func prepareAndShowShareSheet(data: Data) {
        if exportedPdfUrl == nil {
            exportedPdfUrl = preparePdfFile(data: data, patientName: configuration.patientName)
        }
        showShareSheet = true
    }
}

// MARK: - PDFKit Representable View
#if canImport(PDFKit) && canImport(UIKit)
public struct PDFKitViewRepresentable: UIViewRepresentable {
    public let pdfDocument: PDFDocument

    public init(pdfDocument: PDFDocument) {
        self.pdfDocument = pdfDocument
    }

    public func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = pdfDocument
        return pdfView
    }

    public func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document != pdfDocument {
            uiView.document = pdfDocument
        }
    }
}
#elseif canImport(PDFKit) && canImport(AppKit) && !targetEnvironment(macCatalyst)
public struct PDFKitViewRepresentable: NSViewRepresentable {
    public let pdfDocument: PDFDocument

    public init(pdfDocument: PDFDocument) {
        self.pdfDocument = pdfDocument
    }

    public func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = pdfDocument
        return pdfView
    }

    public func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document != pdfDocument {
            nsView.document = pdfDocument
        }
    }
}
#endif

#if os(iOS)
public struct ActivityView: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]? = nil

    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
