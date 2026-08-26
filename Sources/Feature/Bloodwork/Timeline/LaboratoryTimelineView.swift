import SwiftUI
import Charts
import Domain
import DesignSystem
import Analytics

/// Interactive Laboratory Timeline View featuring event alignment across doses,
/// protocol changes, biometric measurements, and diagnostic bloodwork.
public struct LaboratoryTimelineView: View {
    @Bindable public var viewModel: LaboratoryTimelineViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: LaboratoryTimelineViewModel = LaboratoryTimelineViewModel()) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.cachedPanels.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(VialrColors.accentTeal)
                        Text("Aligning Longitudinal Timeline...")
                            .font(VialrTypography.footnote)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: VialrSpacing.lg) {
                            // Header Controls & Title
                            headerSection

                            // Biomarker Selector Carousel
                            biomarkerSelectorBar

                            // Active Biomarker Hero KPI Summary Card
                            if let activeMarker = viewModel.selectedBiomarker {
                                heroBiomarkerCard(activeMarker)
                            }

                            // Interactive Swift Charts Laboratory Timeline
                            interactiveChartSection

                            // Phase Transition Journey Stepper
                            if !viewModel.analysis.phaseMilestones.isEmpty {
                                phaseJourneyStepperSection
                            }

                            // Protocol Period Impact Cards
                            if viewModel.isProtocolOverlayEnabled && !viewModel.analysis.protocolOverlays.isEmpty {
                                protocolPeriodsImpactSection
                            }

                            // Chronological Aligned Event Stream Ledger
                            alignedEventStreamSection
                        }
                        .padding(.horizontal, VialrSpacing.md)
                        .padding(.top, VialrSpacing.sm)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Laboratory Timeline")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(VialrColors.accentTeal)
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Toggle("Protocol Overlays", isOn: $viewModel.isProtocolOverlayEnabled)
                        Toggle("Reference Ranges", isOn: $viewModel.isReferenceRangeVisible)
                        Toggle("Dose Density", isOn: $viewModel.isDoseDensityVisible)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(VialrColors.accentTeal)
                    }
                }
            }
            .task {
                await viewModel.loadTimelineData()
            }
            .sheet(item: $viewModel.selectedAlignedItem) { item in
                eventDetailSheet(item)
            }
        }
    }

    // MARK: - 1. Header Section
    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("EVENT ALIGNMENT & TRAJECTORY")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Text("Timeline Analytics")
                    .font(VialrTypography.largeHero)
                    .foregroundColor(VialrColors.textPrimary)
            }

            Spacer()

            // Time Range Segmented Picker
            HStack(spacing: 2) {
                ForEach(TimelineTimeRange.allCases) { range in
                    let isSel = viewModel.selectedTimeRange == range
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectTimeRange(range)
                        }
                    } label: {
                        Text(range.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isSel ? VialrColors.backgroundPrimary : VialrColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(isSel ? VialrColors.accentTeal : Color.clear)
                            .cornerRadius(6)
                    }
                }
            }
            .padding(2)
            .background(VialrColors.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(VialrColors.glassBorder, lineWidth: 1)
            )
        }
        .padding(.top, VialrSpacing.xs)
    }

    // MARK: - 2. Biomarker Selector Bar
    private var biomarkerSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.analysis.availableBiomarkers, id: \.self) { name in
                    let isSelected = viewModel.selectedBiomarker == name
                    let points = viewModel.analysis.biomarkerTimeSeries[name] ?? []
                    let latestPoint = points.last

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.selectBiomarker(name)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let flag = latestPoint?.flag {
                                Circle()
                                    .fill(Color(hex: flag.badgeColorHex))
                                    .frame(width: 7, height: 7)
                            }

                            Text(name)
                                .font(VialrTypography.captionBold)
                                .foregroundColor(isSelected ? VialrColors.backgroundPrimary : VialrColors.textPrimary)

                            if let latest = latestPoint {
                                Text(latest.formattedValue)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(isSelected ? VialrColors.backgroundPrimary.opacity(0.8) : VialrColors.textTertiary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? VialrColors.accentTeal : VialrColors.cardBackground)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isSelected ? Color.clear : VialrColors.glassBorder, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - 3. Hero Biomarker Summary Card
    private func heroBiomarkerCard(_ markerName: String) -> some View {
        let points = viewModel.filteredActivePoints
        let first = points.first
        let latest = points.last
        let totalDelta = (latest != nil && first != nil) ? (latest!.value - first!.value) : nil
        let pctChange = (totalDelta != nil && first != nil && first!.value != 0) ? (totalDelta! / abs(first!.value)) * 100.0 : nil

        return VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SELECTED BIOMARKER")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text(markerName)
                        .font(VialrTypography.title2)
                        .foregroundColor(VialrColors.textPrimary)
                }

                Spacer()

                if let flag = latest?.flag {
                    MetricBadge(.custom(
                        title: flag.rawValue,
                        color: Color(hex: flag.badgeColorHex),
                        icon: nil
                    ))
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                if let latestVal = latest {
                    let valStr = latestVal.value.truncatingRemainder(dividingBy: 1) == 0 ?
                        String(format: "%.0f", latestVal.value) : String(format: "%.1f", latestVal.value)

                    Text(valStr)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(VialrColors.textPrimary)

                    Text(latestVal.unit)
                        .font(VialrTypography.headline)
                        .foregroundColor(VialrColors.textSecondary)
                } else {
                    Text("—")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(VialrColors.textTertiary)
                }

                Spacer()

                if let delta = totalDelta, let pct = pctChange, let unit = latest?.unit {
                    let sign = delta > 0 ? "+" : ""
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("FROM BASELINE")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textTertiary)
                        Text("\(sign)\(String(format: "%.1f", delta)) \(unit) (\(sign)\(String(format: "%.1f", pct))%)")
                            .font(VialrTypography.bodyBold)
                            .foregroundColor(delta >= 0 ? VialrColors.accentEmerald : VialrColors.accentRose)
                    }
                }
            }

            Divider().background(VialrColors.glassBorder)

            // Multi-Phase Alignment Stats
            HStack(spacing: 12) {
                statBox(title: "TOTAL DRAWS", value: "\(points.count)", sub: "Aligned on timeline")
                Spacer()
                if let ref = latest?.formattedReferenceRange {
                    statBox(title: "REF RANGE", value: ref, sub: "Normal biological limits")
                }
                Spacer()
                if let activeProto = latest?.protocolName {
                    statBox(title: "CURRENT PHASE", value: activeProto, sub: latest?.protocolPhase.shortName ?? "Active")
                }
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func statBox(title: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(VialrColors.textTertiary)
            Text(value)
                .font(VialrTypography.footnoteBold)
                .foregroundColor(VialrColors.textPrimary)
                .lineLimit(1)
            Text(sub)
                .font(.system(size: 9))
                .foregroundColor(VialrColors.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - 4. Interactive Swift Charts Timeline
    private var interactiveChartSection: some View {
        let points = viewModel.filteredActivePoints
        let overlays = viewModel.analysis.protocolOverlays
        let refMin = points.compactMap(\.referenceRangeMin).first
        let refMax = points.compactMap(\.referenceRangeMax).first

        return VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LONGITUDINAL EVENT-ALIGNED AXIS")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text("Protocol Overlays & Lab Points")
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                }

                Spacer()

                if let selected = viewModel.selectedLabPoint {
                    Button("Reset Selection") {
                        withAnimation { viewModel.selectedLabPoint = nil }
                    }
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                }
            }

            if !points.isEmpty {
                Chart {
                    // 1. Reference Range Shaded Region
                    if viewModel.isReferenceRangeVisible, let minV = refMin, let maxV = refMax, let start = points.first?.timestamp, let end = points.last?.timestamp {
                        let extendedStart = start.addingTimeInterval(-86400 * 2)
                        let extendedEnd = end.addingTimeInterval(86400 * 2)

                        // Shaded Range Rectangle
                        RectangleMark(
                            xStart: .value("Range Start", extendedStart),
                            xEnd: .value("Range End", extendedEnd),
                            yStart: .value("Ref Min", minV),
                            yEnd: .value("Ref Max", maxV)
                        )
                        .foregroundStyle(VialrColors.accentEmerald.opacity(0.08))

                        // Upper & Lower Ref Limits
                        RuleMark(y: .value("Max Ref", maxV))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(VialrColors.textTertiary.opacity(0.6))

                        RuleMark(y: .value("Min Ref", minV))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(VialrColors.textTertiary.opacity(0.6))
                    }

                    // 2. Protocol Period Overlays (Vertical Period Bands)
                    if viewModel.isProtocolOverlayEnabled {
                        ForEach(overlays) { overlay in
                            let oEnd = overlay.endDate ?? Date()
                            RectangleMark(
                                xStart: .value("Protocol Start", overlay.startDate),
                                xEnd: .value("Protocol End", oEnd)
                            )
                            .foregroundStyle(Color(hex: overlay.colorHex).opacity(0.12))

                            RuleMark(x: .value("Phase Start", overlay.startDate))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                                .foregroundStyle(Color(hex: overlay.colorHex).opacity(0.5))
                                .annotation(position: .top, alignment: .leading) {
                                    Text(overlay.phaseType.shortName)
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(Color(hex: overlay.colorHex))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(VialrColors.cardBackground.opacity(0.9))
                                        .cornerRadius(3)
                                }
                        }
                    }

                    // 3. Biomarker Continuous Trajectory Line
                    ForEach(points) { pt in
                        LineMark(
                            x: .value("Date", pt.timestamp),
                            y: .value("Value", pt.value)
                        )
                        .foregroundStyle(VialrColors.accentTeal)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                    }

                    // 4. Lab Result Point Markers
                    ForEach(points) { pt in
                        PointMark(
                            x: .value("Date", pt.timestamp),
                            y: .value("Value", pt.value)
                        )
                        .symbol {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: pt.flag.badgeColorHex))
                                    .frame(width: viewModel.selectedLabPoint?.id == pt.id ? 14 : 10, height: viewModel.selectedLabPoint?.id == pt.id ? 14 : 10)

                                Circle()
                                    .stroke(VialrColors.backgroundPrimary, lineWidth: 2)
                                    .frame(width: viewModel.selectedLabPoint?.id == pt.id ? 14 : 10, height: viewModel.selectedLabPoint?.id == pt.id ? 14 : 10)
                            }
                        }
                    }

                    // 5. Selected Inspection Marker
                    if let sel = viewModel.selectedLabPoint {
                        RuleMark(x: .value("Selected Date", sel.timestamp))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .foregroundStyle(VialrColors.accentTeal)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { val in
                        AxisGridLine().foregroundStyle(VialrColors.glassBorder)
                        AxisValueLabel {
                            if let num = val.as(Double.self) {
                                Text("\(Int(num))")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(VialrColors.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(VialrColors.glassBorder)
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(.system(size: 9))
                            .foregroundStyle(VialrColors.textTertiary)
                    }
                }
                .frame(height: 220)
                .padding(.top, 8)

                // Chart Legend
                chartLegendView(refMin: refMin, refMax: refMax)

                // Selected Point Inspection Inspector Card
                if let selected = viewModel.selectedLabPoint ?? points.last {
                    selectedPointInspectorCard(selected)
                }
            } else {
                VialrEmptyStateView(
                    iconName: "waveform.path.ecg",
                    title: "No Aligned Data Points",
                    message: "Log laboratory results and activate protocols to view the chronological timeline."
                )
                .frame(height: 180)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func chartLegendView(refMin: Double?, refMax: Double?) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Circle().fill(VialrColors.accentTeal).frame(width: 6, height: 6)
                Text("Lab Result")
                    .font(.system(size: 9))
                    .foregroundColor(VialrColors.textSecondary)
            }

            if viewModel.isProtocolOverlayEnabled {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(VialrColors.accentEmerald.opacity(0.3))
                        .frame(width: 10, height: 6)
                    Text("Protocol Period")
                        .font(.system(size: 9))
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

            if viewModel.isReferenceRangeVisible, refMin != nil {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(VialrColors.accentEmerald.opacity(0.15))
                        .frame(width: 10, height: 6)
                    Text("Optimal Ref Zone")
                        .font(.system(size: 9))
                        .foregroundColor(VialrColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    private func selectedPointInspectorCard(_ pt: LabTimeSeriesPoint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "cross.vial.fill")
                    .font(.system(size: 12))
                    .foregroundColor(VialrColors.accentTeal)

                Text(formatDateFull(pt.timestamp))
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textPrimary)

                Spacer()

                Text(pt.protocolPhase.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: pt.protocolPhase.badgeColorHex))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: pt.protocolPhase.badgeColorHex).opacity(0.15))
                    .cornerRadius(4)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("RESULT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(VialrColors.textTertiary)
                    Text(pt.formattedValue)
                        .font(VialrTypography.subheadlineBold)
                        .foregroundColor(Color(hex: pt.flag.badgeColorHex))
                }

                if let days = pt.daysOnProtocolAtDraw {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("PROTOCOL DURATION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(VialrColors.textTertiary)
                        Text("Day \(days)")
                            .font(VialrTypography.subheadlineBold)
                            .foregroundColor(VialrColors.textPrimary)
                    }
                }

                if let cum = pt.cumulativeDosePriorToDraw, let unit = pt.cumulativeDoseUnit {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("CUMULATIVE DOSE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(VialrColors.textTertiary)
                        Text("\(Int(cum)) \(unit)")
                            .font(VialrTypography.subheadlineBold)
                            .foregroundColor(VialrColors.accentCyan)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("LAB")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(VialrColors.textTertiary)
                    Text(pt.labName)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                }
            }
        }
        .padding(10)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusSm)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                .stroke(VialrColors.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - 5. Phase Transition Journey Stepper
    private var phaseJourneyStepperSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.sm) {
            HStack {
                Text("PHASE TRANSITION JOURNEY")
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.accentTeal)
                Spacer()
                Text("Baseline → Protocol → Follow-Up")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(viewModel.analysis.phaseMilestones.enumerated()), id: \.element.id) { idx, milestone in
                        HStack(spacing: 0) {
                            phaseMilestoneNode(milestone, index: idx)

                            if idx + 1 < viewModel.analysis.phaseMilestones.count {
                                phaseConnectorArrow(from: milestone, to: viewModel.analysis.phaseMilestones[idx + 1])
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func phaseMilestoneNode(_ milestone: PhaseTransitionMilestone, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: milestone.phaseType.iconName)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: milestone.phaseType.badgeColorHex))

                Text(milestone.phaseName)
                    .font(VialrTypography.captionBold)
                    .foregroundColor(VialrColors.textPrimary)
                    .lineLimit(1)
            }

            if let val = milestone.formattedValue {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(val)
                        .font(VialrTypography.monoDose)
                        .foregroundColor(milestone.analyteFlag != nil ? Color(hex: milestone.analyteFlag!.badgeColorHex) : VialrColors.textPrimary)

                    if let pct = milestone.percentageDeltaFromPrevious, index > 0 {
                        let sign = pct > 0 ? "+" : ""
                        Text("(\(sign)\(String(format: "%.1f%%", pct)))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(pct >= 0 ? VialrColors.accentEmerald : VialrColors.accentRose)
                    }
                }
            } else {
                Text(milestone.protocolName ?? "Active Phase")
                    .font(.system(size: 11))
                    .foregroundColor(VialrColors.textSecondary)
                    .lineLimit(1)
            }

            HStack {
                Text(formatShortDate(milestone.date))
                    .font(.system(size: 9))
                    .foregroundColor(VialrColors.textTertiary)

                if let dur = milestone.durationDays {
                    Text("• \(dur) days")
                        .font(.system(size: 9))
                        .foregroundColor(VialrColors.textTertiary)
                }
            }
        }
        .frame(width: 170)
        .padding(10)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusSm)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                .stroke(Color(hex: milestone.phaseType.badgeColorHex).opacity(0.4), lineWidth: 1)
        )
    }

    private func phaseConnectorArrow(from: PhaseTransitionMilestone, to: PhaseTransitionMilestone) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(VialrColors.accentTeal)

            if let pct = to.percentageDeltaFromPrevious {
                let sign = pct > 0 ? "+" : ""
                Text("\(sign)\(String(format: "%.0f%%", pct))")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(pct >= 0 ? VialrColors.accentEmerald : VialrColors.accentRose)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - 6. Protocol Periods Impact Section
    private var protocolPeriodsImpactSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PROTOCOL PERIOD OVERLAYS")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text("Period-Over-Period Outcomes")
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                }
                Spacer()
                Text("\(viewModel.analysis.protocolOverlays.count) Periods")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            ForEach(viewModel.analysis.protocolOverlays) { overlay in
                protocolOverlayCard(overlay)
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func protocolOverlayCard(_ overlay: ProtocolPeriodOverlay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(hex: overlay.colorHex))
                    .frame(width: 8, height: 8)

                Text(overlay.name)
                    .font(VialrTypography.subheadlineBold)
                    .foregroundColor(VialrColors.textPrimary)

                Spacer()

                Text(overlay.phaseType.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: overlay.colorHex))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: overlay.colorHex).opacity(0.15))
                    .cornerRadius(4)
            }

            Text(overlay.compoundsSummary)
                .font(VialrTypography.footnote)
                .foregroundColor(VialrColors.textSecondary)

            Divider().background(VialrColors.glassBorder)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(VialrColors.textTertiary)
                    Text("\(formatShortDate(overlay.startDate)) – \(overlay.endDate != nil ? formatShortDate(overlay.endDate!) : "Ongoing")")
                        .font(.system(size: 10))
                        .foregroundColor(VialrColors.textTertiary)
                }

                Spacer()

                if overlay.totalDosesAdministered > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "syringe.fill")
                            .font(.system(size: 10))
                            .foregroundColor(VialrColors.accentCyan)
                        Text("\(overlay.totalDosesAdministered) Doses")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(VialrColors.accentCyan)
                    }
                }

                if let adh = overlay.adherencePercentage {
                    Text("\(Int(adh))% Adherence")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(VialrColors.accentEmerald)
                        .padding(.leading, 8)
                }
            }
        }
        .padding(VialrSpacing.sm)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusSm)
        .overlay(
            RoundedRectangle(cornerRadius: VialrSpacing.radiusSm)
                .stroke(VialrColors.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - 7. Chronological Aligned Event Stream Ledger
    private var alignedEventStreamSection: some View {
        VStack(alignment: .leading, spacing: VialrSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("UNIFIED CHRONOLOGICAL AXIS")
                        .font(VialrTypography.captionBold)
                        .foregroundColor(VialrColors.accentTeal)
                    Text("Aligned Event Stream")
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                }

                Spacer()

                Text("\(viewModel.filteredAlignedEvents.count) Events")
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }

            // Filter Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(EventStreamFilter.allCases) { filter in
                        let isSel = viewModel.selectedEventFilter == filter
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.selectedEventFilter = filter
                            }
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isSel ? VialrColors.backgroundPrimary : VialrColors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isSel ? VialrColors.accentTeal : VialrColors.cardBackground)
                                .cornerRadius(6)
                        }
                    }
                }
            }

            if viewModel.filteredAlignedEvents.isEmpty {
                Text("No aligned events in this filter interval.")
                    .font(VialrTypography.footnote)
                    .foregroundColor(VialrColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.filteredAlignedEvents.prefix(20)) { item in
                    Button {
                        viewModel.selectedAlignedItem = item
                    } label: {
                        alignedEventRow(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(VialrSpacing.md)
        .vialrCard()
    }

    private func alignedEventRow(_ item: AlignedTimelineItem) -> some View {
        HStack(spacing: 12) {
            // Icon & Timeline connector
            ZStack {
                Circle()
                    .fill(Color(hex: item.badgeColorHex).opacity(0.18))
                    .frame(width: 32, height: 32)

                Image(systemName: item.type.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: item.badgeColorHex))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(VialrTypography.footnoteBold)
                        .foregroundColor(VialrColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(formatShortDate(item.timestamp))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(VialrColors.textTertiary)
                }

                HStack {
                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(VialrColors.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    if let val = item.valueString {
                        Text(val)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: item.badgeColorHex))
                    }
                }
            }
        }
        .padding(8)
        .background(VialrColors.cardSurfaceElevated)
        .cornerRadius(VialrSpacing.radiusSm)
    }

    // MARK: - 8. Event Detail Sheet
    private func eventDetailSheet(_ item: AlignedTimelineItem) -> some View {
        NavigationStack {
            ZStack {
                VialrColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: item.type.iconName)
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: item.badgeColorHex))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.type.rawValue)
                                .font(VialrTypography.captionBold)
                                .foregroundColor(Color(hex: item.badgeColorHex))
                            Text(item.title)
                                .font(VialrTypography.title2)
                                .foregroundColor(VialrColors.textPrimary)
                        }
                    }

                    Divider().background(VialrColors.glassBorder)

                    VStack(alignment: .leading, spacing: 10) {
                        detailRow(title: "Timestamp", value: formatDateFull(item.timestamp))
                        if let proto = item.protocolName {
                            detailRow(title: "Aligned Protocol", value: proto)
                        }
                        detailRow(title: "Phase Classification", value: item.phaseType.rawValue)
                        if let sub = item.detail ?? (item.subtitle.isEmpty ? nil : item.subtitle) {
                            detailRow(title: "Details & Notes", value: sub)
                        }
                    }

                    Spacer()
                }
                .padding(VialrSpacing.md)
            }
            .navigationTitle("Event Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { viewModel.selectedAlignedItem = nil }
                        .foregroundColor(VialrColors.accentTeal)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(VialrColors.textTertiary)
            Text(value)
                .font(VialrTypography.bodyMedium)
                .foregroundColor(VialrColors.textPrimary)
        }
    }

    // MARK: - Date Formatters
    private func formatShortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func formatDateFull(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
