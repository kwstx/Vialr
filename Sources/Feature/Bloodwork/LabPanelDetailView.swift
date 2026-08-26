import SwiftUI
import Domain
import DesignSystem

/// Detail view for inspecting a complete structured laboratory bloodwork panel,
/// with category groupings, visual reference range gauges, and abnormal flag indicators.
public struct LabPanelDetailView: View {
    public let panel: LabPanel
    public var onDelete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategoryFilter: LabCategory? = nil
    @State private var isDeleteConfirmationPresented: Bool = false

    public init(panel: LabPanel, onDelete: (() -> Void)? = nil) {
        self.panel = panel
        self.onDelete = onDelete
    }

    private var groupedResults: [LabCategory: [LabResult]] {
        Dictionary(grouping: panel.results, by: { $0.category })
    }

    private var filteredCategories: [LabCategory] {
        let allCategories = Array(groupedResults.keys).sorted(by: { $0.rawValue < $1.rawValue })
        if let sel = selectedCategoryFilter {
            return allCategories.filter { $0 == sel }
        }
        return allCategories
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VialrSpacing.lg) {
                        // Hero Header Card
                        panelHeroCard

                        // Category Filter Carousel
                        if groupedResults.keys.count > 1 {
                            categoryFilterPills
                        }

                        // Grouped Results Sections
                        ForEach(filteredCategories, id: \.self) { category in
                            if let results = groupedResults[category] {
                                categorySection(category: category, results: results)
                            }
                        }

                        // Clinical Notes
                        if !panel.notes.isEmpty {
                            notesSection
                        }

                        // Delete Panel Option
                        if onDelete != nil {
                            Button(role: .destructive) {
                                isDeleteConfirmationPresented = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Lab Record")
                                }
                                .font(VialrTypography.subheadlineBold)
                                .foregroundColor(VialrColors.accentRose)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(VialrColors.cardSurfaceElevated)
                                .cornerRadius(VialrSpacing.radiusMd)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, VialrSpacing.md)
                        }
                    }
                    .padding(VialrSpacing.md)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle(panel.panelName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
            .confirmationDialog("Delete Lab Record?", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
                Button("Delete Record", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this laboratory panel? This action cannot be undone.")
            }
        }
    }

    // MARK: - Panel Hero Card
    private var panelHeroCard: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(panel.labName.uppercased())
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)

                    Text(panel.panelName)
                        .font(VialrTypography.title2)
                        .foregroundColor(VialrColors.textPrimary)
                }

                Spacer()

                // Status Badge
                Text(panel.status.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: panel.status.badgeColorHex))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: panel.status.badgeColorHex).opacity(0.15))
                    .cornerRadius(VialrSpacing.radiusPill)
            }

            Divider().background(VialrColors.glassBorder)

            // Metadata Grid
            HStack(spacing: 16) {
                metadataItem(title: "COLLECTION DATE", value: formatDate(panel.collectionDate), icon: "calendar")
                metadataItem(title: "FASTING", value: panel.fastingStatus.rawValue, icon: "clock.badge.checkmark")
                if let doc = panel.orderingPhysician {
                    metadataItem(title: "PHYSICIAN", value: doc, icon: "stethoscope")
                }
            }

            Divider().background(VialrColors.glassBorder)

            // Quick Stats
            HStack(spacing: 12) {
                statBox(title: "Total Analytes", value: "\(panel.resultCount)", color: VialrColors.textPrimary)
                statBox(title: "In Optimal Range", value: "\(panel.results.count - panel.abnormalResults.count)", color: VialrColors.accentEmerald)
                statBox(title: "Out of Bounds", value: "\(panel.abnormalResults.count)", color: panel.hasAbnormalResults ? VialrColors.accentRose : VialrColors.textTertiary)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func metadataItem(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(VialrTypography.caption)
                .foregroundColor(VialrColors.textTertiary)
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(VialrColors.accentTeal)
                Text(value)
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(VialrTypography.title3)
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(VialrColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusSm)
    }

    // MARK: - Category Filter Carousel
    private var categoryFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(title: "All Categories (\(panel.resultCount))", isSelected: selectedCategoryFilter == nil) {
                    selectedCategoryFilter = nil
                }

                ForEach(Array(groupedResults.keys).sorted(by: { $0.rawValue < $1.rawValue })) { cat in
                    let count = groupedResults[cat]?.count ?? 0
                    filterPill(title: "\(cat.rawValue) (\(count))", isSelected: selectedCategoryFilter == cat) {
                        selectedCategoryFilter = (selectedCategoryFilter == cat) ? nil : cat
                    }
                }
            }
        }
    }

    private func filterPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

    // MARK: - Category Section
    private func categorySection(category: LabCategory, results: [LabResult]) -> some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                Image(systemName: category.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(VialrColors.accentTeal)

                Text(category.rawValue.uppercased())
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)

                Spacer()

                Text("\(results.count) analytes")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            ForEach(results) { result in
                analyteResultCard(result)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    // MARK: - Individual Analyte Result Card with Visual Range Meter
    private func analyteResultCard(_ result: LabResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.biomarkerName)
                    .font(VialrTypography.subheadlineBold)
                    .foregroundColor(VialrColors.textPrimary)

                Spacer()

                // Flag Badge
                Text(result.flag.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: result.flag.badgeColorHex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: result.flag.badgeColorHex).opacity(0.15))
                    .cornerRadius(4)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(result.formattedValue)
                    .font(VialrTypography.monoDose)
                    .foregroundColor(result.flag == .inRange ? VialrColors.accentTeal : Color(hex: result.flag.badgeColorHex))

                Spacer()

                if let rangeText = result.referenceRangeText {
                    Text("Ref: \(rangeText)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(VialrColors.textSecondary)
                } else if let min = result.referenceRangeMin, let max = result.referenceRangeMax {
                    Text("Ref: \(formatNum(min)) – \(formatNum(max)) \(result.unit)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

            // Visual Reference Range Meter Gauge
            if let min = result.referenceRangeMin, let max = result.referenceRangeMax, max > min {
                visualRangeMeter(value: result.value, min: min, max: max, flag: result.flag)
            }

            if !result.notes.isEmpty && result.notes != "Manually entered." {
                Text(result.notes)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
                    .padding(.top, 2)
            }
        }
        .padding(VialrSpacing.md)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusMd)
                .stroke(result.flag == .inRange ? VialrColors.glassBorder : Color(hex: result.flag.badgeColorHex).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Visual Range Meter
    private func visualRangeMeter(value: Double, min: Double, max: Double, flag: LabResultFlag) -> some View {
        let totalSpan = max - min
        let displayMin = min - (totalSpan * 0.25)
        let displayMax = max + (totalSpan * 0.25)
        let displaySpan = displayMax - displayMin

        let clampedVal = Swift.max(displayMin, Swift.min(displayMax, value))
        let relativePosition = (clampedVal - displayMin) / displaySpan

        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(VialrColors.cardBackground)
                        .frame(height: 6)

                    // Normal Zone Bar
                    let normalStart = (min - displayMin) / displaySpan * geo.size.width
                    let normalWidth = (totalSpan / displaySpan) * geo.size.width

                    RoundedRectangle(cornerRadius: 3)
                        .fill(VialrColors.accentEmerald.opacity(0.4))
                        .frame(width: max(0, normalWidth), height: 6)
                        .offset(x: normalStart)

                    // User's Value Pointer Pin
                    Circle()
                        .fill(Color(hex: flag.badgeColorHex))
                        .frame(width: 12, height: 12)
                        .shadow(color: Color(hex: flag.badgeColorHex).opacity(0.6), radius: 4)
                        .offset(x: max(0, min(geo.size.width - 12, relativePosition * geo.size.width - 6)), y: -3)
                }
            }
            .frame(height: 12)

            HStack {
                Text(formatNum(min))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(VialrColors.textTertiary)
                Spacer()
                Text("OPTIMAL")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(VialrColors.accentEmerald)
                Spacer()
                Text(formatNum(max))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(VialrColors.textTertiary)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CLINICAL PROTOCOL NOTES")
                .font(VialrTypography.captionBold)
                .foregroundColor(VialrColors.accentTeal)

            Text(panel.notes)
                .font(VialrTypography.body)
                .foregroundColor(VialrColors.textSecondary)
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private func formatNum(_ val: Double) -> String {
        val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(format: "%.1f", val)
    }
}
