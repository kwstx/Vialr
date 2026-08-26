import SwiftUI
import Domain
import DesignSystem

/// Core confirmation view implementing the clinical separation guarantee:
/// Document → extracted candidate data → user confirmation → structured laboratory record.
public struct LabCandidateConfirmationView: View {
    @State public var candidateReport: ExtractedLabReportCandidate
    public var onConfirm: (LabPanel) -> Void
    @Environment(\.dismiss) private var dismiss

    // Editable Header State
    @State private var panelName: String
    @State private var labName: String
    @State private var collectionDate: Date
    @State private var fastingStatus: LabFastingStatus
    @State private var orderingPhysician: String
    @State private var notes: String

    // Candidate Editing State
    @State private var editingCandidate: ExtractedLabCandidate? = nil
    @State private var isAddMissingMarkerPresented: Bool = false

    public init(
        candidateReport: ExtractedLabReportCandidate,
        onConfirm: @escaping (LabPanel) -> Void
    ) {
        self._candidateReport = State(initialValue: candidateReport)
        self._panelName = State(initialValue: candidateReport.detectedPanelName)
        self._labName = State(initialValue: candidateReport.detectedLabName)
        self._collectionDate = State(initialValue: candidateReport.detectedCollectionDate)
        self._fastingStatus = State(initialValue: candidateReport.detectedFastingStatus)
        self._orderingPhysician = State(initialValue: candidateReport.detectedOrderingPhysician ?? "")
        self._notes = State(initialValue: "Extracted from \(candidateReport.fileName) and clinically verified.")
        self.onConfirm = onConfirm
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Data Integrity Verification Banner
                        integrityBanner

                        // Detected Metadata Review Card
                        detectedMetadataCard

                        // Extracted Candidate Analytes List
                        candidatesListSection

                        // Confirm Button
                        VialrButton("Confirm & Save Structured Medical Record", icon: "checkmark.seal.fill", style: .primary) {
                            confirmAndSave()
                        }
                        .disabled(candidateReport.selectedCandidatesCount == 0)
                        .padding(.top, VialrSpacing.sm)
                    }
                    .padding(VialrSpacing.md)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Verify Lab Extraction")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { dismiss() }
                        .foregroundColor(VialrColors.accentRose)
                }
            }
            .sheet(item: $editingCandidate) { candidate in
                CandidateEditSheet(candidate: candidate) { updated in
                    if let idx = candidateReport.candidates.firstIndex(where: { $0.id == updated.id }) {
                        candidateReport.candidates[idx] = updated
                    }
                }
            }
            .sheet(isPresented: $isAddMissingMarkerPresented) {
                BiomarkerSelectorView { selectedDef in
                    let newCandidate = ExtractedLabCandidate(
                        rawAnalyteName: selectedDef.name,
                        matchedCatalogId: selectedDef.id,
                        resolvedName: selectedDef.name,
                        category: selectedDef.category,
                        extractedValue: selectedDef.defaultReferenceMin ?? 0.0,
                        extractedUnit: selectedDef.standardUnit,
                        referenceRangeMin: selectedDef.defaultReferenceMin,
                        referenceRangeMax: selectedDef.defaultReferenceMax,
                        referenceRangeText: selectedDef.referenceRangeText,
                        confidenceScore: 1.0,
                        rawSnippet: "Manually added during candidate review",
                        isSelected: true,
                        isEdited: true
                    )
                    candidateReport.candidates.append(newCandidate)
                }
            }
        }
    }

    // MARK: - Data Integrity Banner
    private var integrityBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(VialrColors.accentAmber)
                    .font(.system(size: 16))
                Text("CANDIDATE DATA CONFIRMATION REQUIRED")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentAmber)
            }

            Text("The values below were extracted automatically via OCR from \(candidateReport.fileName). To prevent OCR misreads from polluting your longitudinal records, please review, adjust, or exclude any markers before saving.")
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(VialrSpacing.md)
        .background(VialrColors.accentAmber.opacity(0.12))
        .cornerRadius(VialrSpacing.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                .stroke(VialrColors.accentAmber.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Detected Metadata Card
    private var detectedMetadataCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                Text("DETECTED LAB REPORT DETAILS")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Spacer()
                Text("\(Int(candidateReport.overallConfidence * 100))% OCR Confidence")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(VialrColors.accentEmerald)
            }

            VialrInputField("Panel Name", placeholder: "e.g. Comprehensive Hormone Panel", value: $panelName)
            VialrInputField("Laboratory Facility", placeholder: "e.g. Quest Diagnostics", value: $labName)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Collection Date")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)

                    DatePicker("", selection: $collectionDate, displayedComponents: .date)
                        .labelsHidden()
                        .padding(8)
                        .background(VialrColors.cardSurfaceElevated)
                        .cornerRadius(VialrSpacing.radiusSm)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Fasting Status")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textSecondary)

                    Picker("Fasting Status", selection: $fastingStatus) {
                        ForEach(LabFastingStatus.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(VialrColors.accentTeal)
                    .padding(8)
                    .background(VialrColors.cardSurfaceElevated)
                    .cornerRadius(VialrSpacing.radiusSm)
                }
            }

            VialrInputField("Ordering Physician", placeholder: "e.g. Dr. William Sterling, MD", value: $orderingPhysician)
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Candidate Analytes List Section
    private var candidatesListSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EXTRACTED CANDIDATE ANALYTES")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text("\(candidateReport.selectedCandidatesCount) of \(candidateReport.candidates.count) selected for import")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                }

                Spacer()

                Button {
                    isAddMissingMarkerPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Missing")
                    }
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(VialrColors.cardSurfaceElevated)
                    .cornerRadius(VialrSpacing.radiusPill)
                }
                .buttonStyle(.plain)
            }

            // Quick Select / Deselect All
            HStack {
                Button("Select All") {
                    for i in candidateReport.candidates.indices {
                        candidateReport.candidates[i].isSelected = true
                    }
                }
                .font(VialrTypography.caption)
                .foregroundColor(VialrColors.accentTeal)

                Text("•")
                    .foregroundColor(VialrColors.textTertiary)

                Button("Deselect All") {
                    for i in candidateReport.candidates.indices {
                        candidateReport.candidates[i].isSelected = false
                    }
                }
                .font(VialrTypography.caption)
                .foregroundColor(VialrColors.textSecondary)

                Spacer()
            }

            ForEach($candidateReport.candidates) { $candidate in
                candidateRow(candidate: $candidate)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Individual Candidate Row
    private func candidateRow(candidate: Binding<ExtractedLabCandidate>) -> some View {
        HStack(spacing: 12) {
            // Inclusion Toggle Checkbox
            Button {
                candidate.wrappedValue.isSelected.toggle()
            } label: {
                Image(systemName: candidate.wrappedValue.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(candidate.wrappedValue.isSelected ? VialrColors.accentTeal : VialrColors.textTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(candidate.wrappedValue.resolvedName)
                        .font(VialrTypography.subheadlineBold)
                        .foregroundColor(candidate.wrappedValue.isSelected ? VialrColors.textPrimary : VialrColors.textTertiary)

                    if candidate.wrappedValue.isEdited {
                        Text("EDITED")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(VialrColors.accentCyan)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(VialrColors.accentCyan.opacity(0.15))
                            .cornerRadius(3)
                    }

                    Spacer()

                    // OCR Confidence Badge
                    let conf = candidate.wrappedValue.confidenceLevel
                    HStack(spacing: 3) {
                        Image(systemName: conf.iconName)
                            .font(.system(size: 9))
                        Text(conf.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: conf.badgeColorHex))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: conf.badgeColorHex).opacity(0.12))
                    .cornerRadius(4)
                }

                HStack {
                    // Measured Value & Unit
                    Text(candidate.wrappedValue.formattedValue)
                        .font(VialrTypography.monoDose)
                        .foregroundColor(VialrColors.accentTeal)

                    Spacer()

                    // Flag Badge
                    let flag = candidate.wrappedValue.detectedFlag
                    Text(flag.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: flag.badgeColorHex))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: flag.badgeColorHex).opacity(0.15))
                        .cornerRadius(4)
                }

                if let rangeText = candidate.wrappedValue.referenceRangeText {
                    Text("Ref: \(rangeText)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(VialrColors.textTertiary)
                }
            }

            // Edit Button
            Button {
                editingCandidate = candidate.wrappedValue
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(VialrColors.accentTeal)
            }
            .buttonStyle(.plain)
        }
        .padding(VialrSpacing.md)
        .background(VialrColors.cardSurfaceElevated.opacity(candidate.wrappedValue.isSelected ? 1.0 : 0.4))
        .cornerRadius(VialrSpacing.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                .stroke(candidate.wrappedValue.isSelected ? VialrColors.glassBorder : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Confirmation Action
    private func confirmAndSave() {
        let confirmedPanel = candidateReport.createConfirmedLabPanel(
            panelName: panelName,
            labName: labName,
            collectionDate: collectionDate,
            fastingStatus: fastingStatus,
            orderingPhysician: orderingPhysician.isEmpty ? nil : orderingPhysician,
            notes: notes
        )

        onConfirm(confirmedPanel)
        dismiss()
    }
}

// MARK: - Candidate Quick Edit Sheet
public struct CandidateEditSheet: View {
    @State public var candidate: ExtractedLabCandidate
    public var onSave: (ExtractedLabCandidate) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var valueStr: String
    @State private var unit: String
    @State private var minStr: String
    @State private var maxStr: String
    @State private var flag: LabResultFlag

    public init(candidate: ExtractedLabCandidate, onSave: @escaping (ExtractedLabCandidate) -> Void) {
        self.candidate = candidate
        self.onSave = onSave
        self._name = State(initialValue: candidate.resolvedName)
        self._valueStr = State(initialValue: String(format: candidate.extractedValue.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", candidate.extractedValue))
        self._unit = State(initialValue: candidate.extractedUnit)
        self._minStr = State(initialValue: candidate.referenceRangeMin != nil ? String(format: "%.1f", candidate.referenceRangeMin!) : "")
        self._maxStr = State(initialValue: candidate.referenceRangeMax != nil ? String(format: "%.1f", candidate.referenceRangeMax!) : "")
        self._flag = State(initialValue: candidate.detectedFlag)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            Text("EDIT CANDIDATE ANALYTE")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            VialrInputField("Analyte Name", placeholder: "Biomarker Name", value: $name)

                            HStack {
                                VialrInputField("Extracted Value", placeholder: "Value", value: $valueStr, isNumeric: true)
                                VialrInputField("Unit", placeholder: "Unit", value: $unit)
                            }

                            HStack {
                                VialrInputField("Ref Min", placeholder: "Min", value: $minStr, isNumeric: true)
                                VialrInputField("Ref Max", placeholder: "Max", value: $maxStr, isNumeric: true)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Flag")
                                    .font(VialrTypography.subheadline)
                                    .foregroundColor(VialrColors.textSecondary)

                                Picker("Flag", selection: $flag) {
                                    ForEach(LabResultFlag.allCases) { f in
                                        Text(f.rawValue).tag(f)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(VialrColors.accentTeal)
                                .padding(8)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusSm)
                            }
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        if !candidate.rawSnippet.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("RAW OCR TEXT SNIPPET")
                                    .font(VialrTypography.captionBold)
                                    .foregroundColor(VialrColors.textTertiary)
                                Text(candidate.rawSnippet)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(VialrColors.textSecondary)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(VialrColors.cardSurfaceElevated)
                                    .cornerRadius(6)
                            }
                            .padding(VialrSpacing.md)
                            .vialrCard()
                        }

                        VialrButton("Save Changes", icon: "checkmark.circle.fill", style: .primary) {
                            var updated = candidate
                            updated.resolvedName = name
                            if let val = Double(valueStr) { updated.extractedValue = val }
                            updated.extractedUnit = unit
                            updated.referenceRangeMin = Double(minStr)
                            updated.referenceRangeMax = Double(maxStr)
                            updated.detectedFlag = flag
                            updated.isEdited = true
                            onSave(updated)
                            dismiss()
                        }
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("Edit Analyte")
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
}
