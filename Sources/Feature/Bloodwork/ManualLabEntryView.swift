import SwiftUI
import Domain
import DesignSystem

/// Manual entry form for laboratory results allowing users to select standard biomarkers,
/// input values, units, collection dates, and laboratory reference ranges.
public struct ManualLabEntryView: View {
    public var onSave: (LabPanel) -> Void
    @Environment(\.dismiss) private var dismiss

    // Panel Header State
    @State private var panelName: String = "Comprehensive Bloodwork Panel"
    @State private var labName: String = "Quest Diagnostics"
    @State private var customLabName: String = ""
    @State private var collectionDate: Date = Date()
    @State private var fastingStatus: LabFastingStatus = .fasted
    @State private var orderingPhysician: String = ""
    @State private var notes: String = ""

    // Analyte Items State
    @State private var analytes: [DraftAnalyte] = []
    @State private var isBiomarkerSelectorPresented: Bool = false
    @State private var activeEditingAnalyteId: UUID? = nil

    private let commonLabs = [
        "Quest Diagnostics",
        "Labcorp",
        "BioReference Laboratories",
        "Life Extension",
        "Everlywell",
        "Mayo Clinic Laboratories",
        "Other / Hospital Lab"
    ]

    public init(
        initialBiomarker: StandardBiomarkerDefinition? = nil,
        onSave: @escaping (LabPanel) -> Void
    ) {
        self.onSave = onSave
        if let initial = initialBiomarker {
            _analytes = State(initialValue: [
                DraftAnalyte(
                    biomarkerName: initial.name,
                    category: initial.category,
                    valueString: "",
                    unit: initial.standardUnit,
                    rangeMinString: initial.defaultReferenceMin != nil ? String(format: "%.1f", initial.defaultReferenceMin!) : "",
                    rangeMaxString: initial.defaultReferenceMax != nil ? String(format: "%.1f", initial.defaultReferenceMax!) : "",
                    referenceText: initial.referenceRangeText
                )
            ])
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Panel Information Section
                        panelHeaderCard

                        // Analytes Section
                        analytesSection

                        // Notes Section
                        notesCard

                        // Save Button
                        VialrButton("Save Structured Laboratory Record", icon: "checkmark.circle.fill", style: .primary) {
                            savePanel()
                        }
                        .disabled(validAnalytesCount == 0)
                        .padding(.top, VialrSpacing.sm)
                    }
                    .padding(VialrSpacing.md)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Manual Lab Entry")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
            .sheet(isPresented: $isBiomarkerSelectorPresented) {
                BiomarkerSelectorView { selectedMarker in
                    addAnalyte(from: selectedMarker)
                }
            }
        }
    }

    // MARK: - Panel Header Card
    private var panelHeaderCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            Text("LABORATORY & DRAW DETAILS")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            VialrInputField("Panel Title", placeholder: "e.g. Comprehensive Hormone & Metabolic Panel", value: $panelName)

            // Lab Provider Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Diagnostic Laboratory")
                    .font(VialrTypography.subheadline)
                    .foregroundColor(VialrColors.textSecondary)

                Picker("Diagnostic Laboratory", selection: $labName) {
                    ForEach(commonLabs, id: \.self) { lab in
                        Text(lab).tag(lab)
                    }
                }
                .pickerStyle(.menu)
                .tint(VialrColors.accentTeal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(VialrSpacing.sm)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusSm)

                if labName == "Other / Hospital Lab" {
                    VialrInputField("Custom Laboratory Name", placeholder: "Enter clinical facility", value: $customLabName)
                }
            }

            // Collection Date & Fasting
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blood Draw Date")
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

            VialrInputField("Ordering Physician (Optional)", placeholder: "e.g. Dr. William Sterling, MD", value: $orderingPhysician)
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Analytes Section
    private var analytesSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BIOMARKERS & ANALYTES")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text("\(analytes.count) marker\(analytes.count == 1 ? "" : "s") added")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                }

                Spacer()

                Button {
                    isBiomarkerSelectorPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Marker")
                    }
                    .font(VialrTypography.subheadlineBold)
                    .foregroundColor(VialrColors.backgroundPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(VialrColors.accentTeal)
                    .cornerRadius(VialrSpacing.radiusPill)
                }
                .buttonStyle(.plain)
            }

            if analytes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cross.vial.fill")
                        .font(.system(size: 32))
                        .foregroundColor(VialrColors.textTertiary)
                    Text("No Biomarkers Added Yet")
                        .font(VialrTypography.subheadlineBold)
                        .foregroundColor(VialrColors.textSecondary)
                    Text("Tap \"Add Marker\" to search over 60+ clinical biomarkers and record laboratory values.")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(VialrColors.cardSurfaceElevated.opacity(0.5))
                .cornerRadius(VialrSpacing.radiusMd)
            } else {
                ForEach($analytes) { $analyte in
                    analyteCard(analyte: $analyte)
                }
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Individual Analyte Card
    private func analyteCard(analyte: Binding<DraftAnalyte>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: analyte.wrappedValue.category.iconName)
                    .foregroundColor(VialrColors.accentTeal)
                    .font(.system(size: 14))

                Text(analyte.wrappedValue.biomarkerName)
                    .font(VialrTypography.subheadlineBold)
                    .foregroundColor(VialrColors.textPrimary)

                Spacer()

                // Flag Badge
                let flag = analyte.wrappedValue.computedFlag
                Text(flag.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: flag.badgeColorHex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: flag.badgeColorHex).opacity(0.15))
                    .cornerRadius(4)

                // Delete Button
                Button {
                    analytes.removeAll(where: { $0.id == analyte.wrappedValue.id })
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(VialrColors.accentRose)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                VialrInputField("Value", placeholder: "e.g. 845", value: analyte.valueString, isNumeric: true)
                    .frame(maxWidth: .infinity)

                VialrInputField("Unit", placeholder: "ng/dL", value: analyte.unit)
                    .frame(width: 100)
            }

            // Reference Range Row
            HStack(spacing: 10) {
                VialrInputField("Ref Min", placeholder: "Min", value: analyte.rangeMinString, isNumeric: true)
                VialrInputField("Ref Max", placeholder: "Max", value: analyte.rangeMaxString, isNumeric: true)
            }
        }
        .padding(VialrSpacing.md)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                .stroke(VialrColors.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Clinical Notes / Fasting Protocols")
                .font(VialrTypography.subheadline)
                .foregroundColor(VialrColors.textSecondary)

            TextField("e.g. Blood drawn 36 hours post-injection, 12h water-only fast...", text: $notes)
                .font(VialrTypography.body)
                .padding(VialrSpacing.md)
                .background(VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusMd)
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Actions & Helpers
    private var validAnalytesCount: Int {
        analytes.filter { Double($0.valueString) != nil }.count
    }

    private func addAnalyte(from marker: StandardBiomarkerDefinition) {
        let draft = DraftAnalyte(
            biomarkerName: marker.name,
            category: marker.category,
            valueString: "",
            unit: marker.standardUnit,
            rangeMinString: marker.defaultReferenceMin != nil ? String(format: "%.1f", marker.defaultReferenceMin!) : "",
            rangeMaxString: marker.defaultReferenceMax != nil ? String(format: "%.1f", marker.defaultReferenceMax!) : "",
            referenceText: marker.referenceRangeText
        )
        analytes.append(draft)
    }

    private func savePanel() {
        let finalLab = labName == "Other / Hospital Lab" && !customLabName.isEmpty ? customLabName : labName
        let panelId = UUID()

        let results: [LabResult] = analytes.compactMap { a in
            guard let val = Double(a.valueString) else { return nil }
            let minVal = Double(a.rangeMinString)
            let maxVal = Double(a.rangeMaxString)

            return LabResult(
                id: UUID(),
                panelId: panelId,
                biomarkerName: a.biomarkerName,
                category: a.category,
                value: val,
                unit: a.unit.isEmpty ? "units" : a.unit,
                referenceRangeMin: minVal,
                referenceRangeMax: maxVal,
                referenceRangeText: a.referenceText,
                flag: a.computedFlag,
                notes: "Manually entered."
            )
        }

        let panel = LabPanel(
            id: panelId,
            panelName: panelName.isEmpty ? "Diagnostic Lab Panel" : panelName,
            labName: finalLab,
            collectionDate: collectionDate,
            resultDate: collectionDate,
            status: .completed,
            results: results,
            orderingPhysician: orderingPhysician.isEmpty ? nil : orderingPhysician,
            fastingStatus: fastingStatus,
            notes: notes
        )

        onSave(panel)
        dismiss()
    }
}

// MARK: - Draft Analyte Model
public struct DraftAnalyte: Identifiable, Sendable {
    public let id: UUID = UUID()
    public var biomarkerName: String
    public var category: LabCategory
    public var valueString: String
    public var unit: String
    public var rangeMinString: String
    public var rangeMaxString: String
    public var referenceText: String?

    public var computedFlag: LabResultFlag {
        guard let val = Double(valueString) else { return .inRange }
        let minVal = Double(rangeMinString)
        let maxVal = Double(rangeMaxString)

        if let min = minVal, val < min {
            if val < min * 0.5 { return .criticalLow }
            return .low
        }
        if let max = maxVal, val > max {
            if val > max * 1.5 { return .criticalHigh }
            return .high
        }
        return .inRange
    }
}
