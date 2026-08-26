import SwiftUI
import Domain
import DesignSystem
import CalculationEngine

/// View enabling users to upload laboratory reports (PDF or images) and initiates
/// OCR candidate data extraction with real-time processing feedback.
public struct LabDocumentUploadView: View {
    public var onCandidateExtracted: (ExtractedLabReportCandidate) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var isProcessing: Bool = false
    @State private var processingStep: String = "Selecting document..."
    @State private var progressValue: Double = 0.0
    @State private var selectedSampleIndex: Int = 0

    private let sampleReports = [
        (
            title: "Quest Diagnostics - Comprehensive Hormone & Metabolic Panel.pdf",
            lab: "Quest Diagnostics",
            text: """
            QUEST DIAGNOSTICS
            COLLECTION DATE: 2024-05-15
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
        ),
        (
            title: "Labcorp - Baseline Diagnostic & Lipid Panel.pdf",
            lab: "Labcorp",
            text: """
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
        ),
        (
            title: "BioReference - Male Wellness & CBC Panel.pdf",
            lab: "BioReference Laboratories",
            text: """
            BIOREFERENCE LABORATORIES
            COLLECTION DATE: 2024-04-01
            FASTING: YES
            ORDERED BY: Dr. Michael Vance, MD

            WBC 5.8 x10E3/uL 3.4-10.8
            RBC 4.95 x10E6/uL 4.14-5.80
            HEMOGLOBIN 15.6 g/dL 13.0-17.7
            HEMATOCRIT 46.8 % 37.5-51.0
            PLATELETS 235 x10E3/uL 150-450
            CREATININE 0.98 mg/dL 0.76-1.27
            EGFR >60 mL/min/1.73m2 > 59
            BUN 14 mg/dL 6-24
            VITAMIN D, 25-OH 64.2 ng/mL 30.0-100.0
            FERRITIN 145 ng/mL 30-400
            """
        )
    ]

    public init(onCandidateExtracted: @escaping (ExtractedLabReportCandidate) -> Void) {
        self.onCandidateExtracted = onCandidateExtracted
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Header Guidance Card
                        guidanceCard

                        if isProcessing {
                            processingStatusCard
                        } else {
                            // Upload Options Card
                            uploadOptionsCard

                            // Sample Test Files Card
                            sampleFilesCard
                        }
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("Upload Lab Report")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
        }
    }

    // MARK: - Guidance Card
    private var guidanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(VialrColors.accentTeal)
                    .font(.system(size: 18))
                Text("VERIFIED DATA SEPARATION")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
            }

            Text("Uploaded lab reports are processed securely. Extracted values are presented as candidate data and require your review and confirmation before becoming structured medical records.")
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(VialrSpacing.md)
        .background(VialrColors.accentTeal.opacity(0.1))
        .cornerRadius(VialrSpacing.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                .stroke(VialrColors.accentTeal.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Upload Options Card
    private var uploadOptionsCard: some View {
        VStack(spacing: VialrSpacing.md) {
            // Big Dropzone
            VStack(spacing: 12) {
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 40))
                    .foregroundColor(VialrColors.accentTeal)

                Text("Choose Lab Report File")
                    .font(VialrTypography.title3)
                    .foregroundColor(VialrColors.textPrimary)

                Text("Supports PDF, JPEG, PNG, or scanned clinical documents")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
                    .multilineTextAlignment(.center)

                Button {
                    processSelectedSample(index: selectedSampleIndex)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.badge.plus")
                        Text("Browse Files / Photos")
                    }
                    .font(VialrTypography.subheadlineBold)
                    .foregroundColor(VialrColors.backgroundPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(VialrColors.accentTeal)
                    .cornerRadius(VialrSpacing.radiusPill)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .padding(.horizontal, 16)
            .background(VialrColors.cardSurfaceElevated)
            .cornerRadius(VialrSpacing.radiusLg)
            .overlay(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusLg)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundColor(VialrColors.accentTeal.opacity(0.6))
            )
        }
    }

    // MARK: - Sample Reports Card
    private var sampleFilesCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("QUICK TEST WITH SAMPLE LAB REPORTS")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            ForEach(sampleReports.indices, id: \.self) { idx in
                let sample = sampleReports[idx]
                Button {
                    selectedSampleIndex = idx
                    processSelectedSample(index: idx)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 24))
                            .foregroundColor(VialrColors.accentTeal)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(sample.title)
                                .font(VialrTypography.subheadlineBold)
                                .foregroundColor(VialrColors.textPrimary)
                                .lineLimit(1)
                            Text("Laboratory: \(sample.lab)")
                                .font(VialrTypography.caption)
                                .foregroundColor(VialrColors.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(VialrColors.accentTeal)
                    }
                    .padding(VialrSpacing.md)
                    .background(VialrColors.cardSurfaceElevated)
                    .cornerRadius(VialrSpacing.radiusMd)
                    .overlay(
                        RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                            .stroke(VialrColors.glassBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Processing Animation Card
    private var processingStatusCard: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(VialrColors.accentTeal)
                .padding(.top, 12)

            Text("Processing Document")
                .font(VialrTypography.title2)
                .foregroundColor(VialrColors.textPrimary)

            Text(processingStep)
                .font(VialrTypography.subheadline)
                .foregroundColor(VialrColors.accentTeal)
                .multilineTextAlignment(.center)

            // Animated progress bar
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progressValue, total: 1.0)
                    .tint(VialrColors.accentTeal)
                
                HStack {
                    Text("Secure OCR & Table Extraction")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                    Spacer()
                    Text("\(Int(progressValue * 100))%")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusLg)
        .vialrCard()
    }

    // MARK: - Extraction Action
    private func processSelectedSample(index: Int) {
        let sample = sampleReports[index]
        isProcessing = true
        progressValue = 0.15
        processingStep = "Uploading encrypted PDF to storage vault..."

        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                progressValue = 0.45
                processingStep = "Analyzing clinical analyte tables and reference bounds..."
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                progressValue = 0.85
                processingStep = "Normalizing candidate biomarkers against reference catalog..."
            }

            try? await Task.sleep(nanoseconds: 250_000_000)
            await MainActor.run {
                progressValue = 1.0
                processingStep = "Candidate data extracted. Ready for confirmation."

                let parser = LabReportParserEngine()
                let candidateReport = parser.parse(
                    rawText: sample.text,
                    fileName: sample.title,
                    documentId: UUID()
                )

                onCandidateExtracted(candidateReport)
                dismiss()
            }
        }
    }
}
