import SwiftUI
import Domain
import DesignSystem

/// Searchable biomarker selector allowing users to quickly find, filter, and choose standard clinical biomarkers
/// or create custom biomarker definitions.
public struct BiomarkerSelectorView: View {
    public var onSelect: (StandardBiomarkerDefinition) -> Void
    public var onSelectCustom: ((name: String, unit: String, category: LabCategory, min: Double?, max: Double?) -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery: String = ""
    @State private var selectedCategory: LabCategory? = nil
    @State private var isCustomMarkerSheetPresented: Bool = false

    // Custom Marker Sheet State
    @State private var customName: String = ""
    @State private var customUnit: String = "mg/dL"
    @State private var customCategory: LabCategory = .custom
    @State private var customMinStr: String = ""
    @State private var customMaxStr: String = ""

    private let catalog = StandardBiomarkerCatalog.shared

    public init(
        onSelect: @escaping (StandardBiomarkerDefinition) -> Void,
        onSelectCustom: ((name: String, unit: String, category: LabCategory, min: Double?, max: Double?) -> Void)? = nil
    ) {
        self.onSelect = onSelect
        self.onSelectCustom = onSelectCustom
    }

    private var filteredBiomarkers: [StandardBiomarkerDefinition] {
        catalog.search(query: searchQuery, category: selectedCategory)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    searchBarSection
                        .padding(.horizontal, VialrSpacing.md)
                        .padding(.top, VialrSpacing.sm)
                        .padding(.bottom, VialrSpacing.xs)

                    // Category Filter Pills
                    categoryFilterCarousel
                        .padding(.bottom, VialrSpacing.sm)

                    // Biomarkers List
                    if filteredBiomarkers.isEmpty {
                        emptySearchResultsView
                    } else {
                        biomarkersList
                    }
                }
            }
            .navigationTitle("Select Biomarker")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(VialrColors.accentTeal)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        customName = searchQuery
                        isCustomMarkerSheetPresented = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Custom")
                        }
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    }
                }
            }
            .sheet(isPresented: $isCustomMarkerSheetPresented) {
                customMarkerSheet
            }
        }
    }

    // MARK: - Search Bar
    private var searchBarSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(VialrColors.textTertiary)
                .font(.system(size: 16))

            TextField("Search 60+ biomarkers (e.g. Total T, E2, Glucose, ApoB)...", text: $searchQuery)
                .font(VialrTypography.body)
                .foregroundColor(VialrColors.textPrimary)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(VialrColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                .stroke(VialrColors.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Category Filter Carousel
    private var categoryFilterCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" Pill
                categoryPill(title: "All Markers", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(LabCategory.allCases) { cat in
                    categoryPill(title: cat.rawValue, isSelected: selectedCategory == cat) {
                        if selectedCategory == cat {
                            selectedCategory = nil
                        } else {
                            selectedCategory = cat
                        }
                    }
                }
            }
            .padding(.horizontal, VialrSpacing.md)
        }
    }

    private func categoryPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(VialrTypography.caption)
                .foregroundColor(isSelected ? VialrColors.backgroundPrimary : VialrColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? VialrColors.accentTeal : VialrColors.cardSurfaceElevated)
                .cornerRadius(VialrSpacing.radiusPill)
                .overlay(
                    RoundedRectangle(cornerRadius: VialrSpacing.radiusPill)
                        .stroke(isSelected ? VialrColors.accentTeal : VialrColors.glassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Biomarkers List
    private var biomarkersList: some View {
        List {
            ForEach(filteredBiomarkers) { marker in
                Button {
                    onSelect(marker)
                    dismiss()
                } label: {
                    biomarkerRow(marker)
                }
                .listRowBackground(VialrColors.cardBackground)
                .listRowSeparatorTint(VialrColors.glassBorder)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func biomarkerRow(_ marker: StandardBiomarkerDefinition) -> some View {
        HStack(spacing: 12) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(VialrColors.cardSurfaceElevated)
                    .frame(width: 40, height: 40)
                Image(systemName: marker.category.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(VialrColors.accentTeal)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(marker.name)
                        .font(VialrTypography.subheadlineBold)
                        .foregroundColor(VialrColors.textPrimary)

                    if marker.isCommon {
                        Text("POPULAR")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(VialrColors.accentEmerald)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VialrColors.accentEmerald.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                if !marker.aliases.isEmpty {
                    Text(marker.aliases.prefix(2).joined(separator: ", "))
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)
                        .lineLimit(1)
                }

                if let range = marker.referenceRangeText {
                    Text("Ref: \(range)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

            Spacer()

            // Standard Unit Badge
            VStack(alignment: .trailing, spacing: 2) {
                Text(marker.standardUnit)
                    .font(VialrTypography.monoDose)
                    .foregroundColor(VialrColors.accentTeal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VialrColors.accentTeal.opacity(0.15))
                    .cornerRadius(6)

                Text(marker.category.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(VialrColors.textTertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Empty Search State
    private var emptySearchResultsView: some View {
        VStack(spacing: VialrSpacing.md) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(VialrColors.textTertiary)

            Text("No Biomarkers Found")
                .font(VialrTypography.title3)
                .foregroundColor(VialrColors.textPrimary)

            Text("No catalog matches for \"\(searchQuery)\". You can create a custom marker.")
                .font(VialrTypography.subheadline)
                .foregroundColor(VialrColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                customName = searchQuery
                isCustomMarkerSheetPresented = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create \"\(searchQuery.isEmpty ? "Custom Biomarker" : searchQuery)\"")
                }
                .font(VialrTypography.subheadlineBold)
                .foregroundColor(VialrColors.backgroundPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(VialrColors.accentTeal)
                .cornerRadius(VialrSpacing.radiusPill)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Custom Marker Creation Sheet
    private var customMarkerSheet: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        VStack(alignment: .leading, spacing: VialrSpacing.md) {
                            Text("CUSTOM BIOMARKER DETAILS")
                                .font(VialrTypography.captionBold)
                                .foregroundColor(VialrColors.accentTeal)

                            VialrInputField("Biomarker Name", placeholder: "e.g. IGFBP-3, D-Dimer", value: $customName)

                            VialrInputField("Measurement Unit", placeholder: "e.g. ng/mL, mg/L, %", value: $customUnit)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Category")
                                    .font(VialrTypography.subheadline)
                                    .foregroundColor(VialrColors.textSecondary)

                                Picker("Category", selection: $customCategory) {
                                    ForEach(LabCategory.allCases) { cat in
                                        Text(cat.rawValue).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(VialrColors.accentTeal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(VialrSpacing.sm)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusSm)
                            }

                            HStack {
                                VialrInputField("Ref Min (Optional)", placeholder: "e.g. 10.0", value: $customMinStr, isNumeric: true)
                                VialrInputField("Ref Max (Optional)", placeholder: "e.g. 50.0", value: $customMaxStr, isNumeric: true)
                            }
                        }
                        .padding(VialrSpacing.md)
                        .vialrCard()

                        VialrButton("Use Custom Biomarker", icon: "checkmark.circle.fill", style: .primary) {
                            let minVal = Double(customMinStr)
                            let maxVal = Double(customMaxStr)
                            let customDef = StandardBiomarkerDefinition(
                                id: customName.lowercased().replacingOccurrences(of: " ", with: "_"),
                                name: customName,
                                standardUnit: customUnit,
                                category: customCategory,
                                defaultReferenceMin: minVal,
                                defaultReferenceMax: maxVal,
                                referenceRangeText: minVal != nil && maxVal != nil ? "\(minVal!) – \(maxVal!) \(customUnit)" : nil,
                                description: "Custom user-defined biomarker."
                            )

                            if let onCustom = onSelectCustom {
                                onCustom(customName, customUnit, customCategory, minVal, maxVal)
                            }
                            onSelect(customDef)
                            isCustomMarkerSheetPresented = false
                            dismiss()
                        }
                        .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(VialrSpacing.md)
                }
            }
            .navigationTitle("New Custom Biomarker")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isCustomMarkerSheetPresented = false }
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
        }
    }
}
