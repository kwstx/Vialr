import SwiftUI
import Domain
import DesignSystem

public struct SymptomLogSheetView: View {
    public var onSave: (SymptomLog) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var energyLevel: Double = 8
    @State private var sleepQuality: Double = 8
    @State private var recoveryScore: Double = 9
    @State private var moodScore: Double = 8
    @State private var painScore: Double = 1
    @State private var selectedSideEffects: Set<String> = []
    @State private var notes: String = ""

    public init(onSave: @escaping (SymptomLog) -> Void) {
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Rating Sliders Card
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            Text("SUBJECTIVE WELL-BEING (1–10)")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            sliderRow(title: "Energy & Vitality", value: $energyLevel, icon: "bolt.fill", color: VialrColors.accentEmerald)
                            sliderRow(title: "Sleep Quality", value: $sleepQuality, icon: "moon.stars.fill", color: VialrColors.accentViolet)
                            sliderRow(title: "Physical Recovery", value: $recoveryScore, icon: "figure.run", color: VialrColors.accentCyan)
                            sliderRow(title: "Mood & Focus", value: $moodScore, icon: "brain.head.profile", color: VialrColors.accentTeal)
                            sliderRow(title: "Localized Pain / Discomfort", value: $painScore, icon: "cross.fill", color: VialrColors.accentRose)
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        // Side Effects Checklist
                        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
                            Text("SIDE EFFECTS / OBSERVATIONS")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            let sideEffects = [
                                "Injection Site Itch / Redness",
                                "Mild Flushing",
                                "Temporary Water Retention",
                                "Mild Nausea",
                                "Tiredness / Lethargy",
                                "None / Exceptional"
                            ]

                            FlowLayout(spacing: 8) {
                                ForEach(sideEffects, id: \.self) { effect in
                                    let isSelected = selectedSideEffects.contains(effect)
                                    Button {
                                        if isSelected {
                                            selectedSideEffects.remove(effect)
                                        } else {
                                            selectedSideEffects.insert(effect)
                                        }
                                    } label: {
                                        Text(effect)
                                            .font(VialrTypography.footnote)
                                            .foregroundColor(isSelected ? VialrColors.textPrimary : VialrColors.textSecondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(isSelected ? VialrColors.accentTeal.opacity(0.25) : VialrColors.cardSurfaceElevated)
                                            .cornerRadius(VialrSpacing.radiusSm)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                                                    .stroke(isSelected ? VialrColors.accentTeal : VialrColors.glassBorder, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        // Notes
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Daily Journal / Qualitative Notes")
                                .font(VialrTypography.subheadline)
                                .foregroundColor(VialrColors.textSecondary)

                            TextField("Describe training performance, recovery, or symptoms...", text: $notes)
                                .font(VialrTypography.body)
                                .padding(VialrSpacing.md)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusMd)
                        }

                        // Submit
                        VialrButton("Save Subjective Log", icon: "checkmark.circle.fill", style: .primary) {
                            let log = SymptomLog(
                                energyLevel: Int(energyLevel),
                                sleepQuality: Int(sleepQuality),
                                recoveryScore: Int(recoveryScore),
                                moodScore: Int(moodScore),
                                painScore: Int(painScore),
                                sideEffects: Array(selectedSideEffects),
                                notes: notes
                            )
                            onSave(log)
                            dismiss()
                        }
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("Log Symptoms & Outcomes")
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

    private func sliderRow(title: String, value: Binding<Double>, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14))
                Text(title)
                    .font(VialrTypography.subheadline)
                    .foregroundColor(VialrColors.textPrimary)
                Spacer()
                Text("\(Int(value.wrappedValue))/10")
                    .font(VialrTypography.monoDose)
                    .foregroundColor(color)
            }
            Slider(value: value, in: 1...10, step: 1)
                .tint(color)
        }
    }
}

public struct BiomarkerLogSheetView: View {
    public var onSave: (Biomarker) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var biomarkerName: String = "IGF-1"
    @State private var category: BiomarkerCategory = .bloodwork
    @State private var valueString: String = "240"
    @State private var unitString: String = "ng/mL"
    @State private var rangeMinString: String = "115"
    @State private var rangeMaxString: String = "307"
    @State private var testDate: Date = Date()
    @State private var notes: String = ""

    public init(onSave: @escaping (Biomarker) -> Void) {
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            Text("BIOMARKER ENTRY")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            VialrInputField("Biomarker Name", placeholder: "e.g. IGF-1, Fasting Glucose", value: $biomarkerName)
                            
                            HStack {
                                VialrInputField("Measured Value", placeholder: "240", value: $valueString, isNumeric: true)
                                VialrInputField("Unit", placeholder: "ng/mL", value: $unitString)
                            }

                            HStack {
                                VialrInputField("Reference Min", placeholder: "115", value: $rangeMinString, isNumeric: true)
                                VialrInputField("Reference Max", placeholder: "307", value: $rangeMaxString, isNumeric: true)
                            }

                            DatePicker("Test / Blood Draw Date", selection: $testDate, displayedComponents: .date)
                                .padding(VialrSpacing.sm)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusSm)
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        VialrButton("Save Biomarker", icon: "checkmark.circle.fill", style: .primary) {
                            let val = Double(valueString) ?? 0.0
                            let rMin = Double(rangeMinString)
                            let rMax = Double(rangeMaxString)

                            let biomarker = Biomarker(
                                name: biomarkerName,
                                category: category,
                                value: val,
                                unit: unitString,
                                referenceRangeMin: rMin,
                                referenceRangeMax: rMax,
                                dateRecorded: testDate,
                                source: .manualEntry,
                                notes: notes
                            )
                            onSave(biomarker)
                            dismiss()
                        }
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("Add Biomarker / Bloodwork")
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

// Simple Flow layout wrapper
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                height += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
