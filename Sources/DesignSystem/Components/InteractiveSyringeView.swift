import SwiftUI

// MARK: - Syringe Specification & Size Options

/// Standard clinical syringe sizes and calibrations.
public enum SyringeSize: String, CaseIterable, Identifiable, Sendable {
    case point3ml = "0.3 mL (30 Units U-100)"
    case point5ml = "0.5 mL (50 Units U-100)"
    case oneMl = "1.0 mL (100 Units U-100)"
    case u40_halfMl = "0.5 mL (20 Units U-40)"
    case u40_oneMl = "1.0 mL (40 Units U-40)"

    public var id: String { rawValue }

    /// Total units capacity for this syringe.
    public var maxUnits: Double {
        switch self {
        case .point3ml: return 30.0
        case .point5ml: return 50.0
        case .oneMl: return 100.0
        case .u40_halfMl: return 20.0
        case .u40_oneMl: return 40.0
        }
    }

    /// Total liquid volume capacity in Milliliters (mL).
    public var maxVolumeMl: Double {
        switch self {
        case .point3ml: return 0.3
        case .point5ml: return 0.5
        case .oneMl: return 1.0
        case .u40_halfMl: return 0.5
        case .u40_oneMl: return 1.0
        }
    }

    /// Calibration standard (units per 1.0 mL).
    public var unitsPerMl: Double {
        maxUnits / maxVolumeMl
    }

    /// Calibration standard name.
    public var calibrationName: String {
        switch self {
        case .point3ml, .point5ml, .oneMl:
            return "U-100"
        case .u40_halfMl, .u40_oneMl:
            return "U-40"
        }
    }

    /// Major tick interval for printed graduation numbers.
    public var majorTickInterval: Double {
        switch self {
        case .point3ml: return 5.0
        case .point5ml: return 10.0
        case .oneMl: return 10.0
        case .u40_halfMl: return 5.0
        case .u40_oneMl: return 10.0
        }
    }

    /// Minor tick interval between graduations.
    public var minorTickInterval: Double {
        switch self {
        case .point3ml: return 1.0
        case .point5ml: return 1.0
        case .oneMl: return 2.0
        case .u40_halfMl: return 1.0
        case .u40_oneMl: return 1.0
        }
    }

    /// Short display name for headers and badges.
    public var shortName: String {
        switch self {
        case .point3ml: return "0.3 mL (30U)"
        case .point5ml: return "0.5 mL (50U)"
        case .oneMl: return "1.0 mL (100U)"
        case .u40_halfMl: return "0.5 mL (20U U-40)"
        case .u40_oneMl: return "1.0 mL (40U U-40)"
        }
    }
}

// MARK: - Presentation Styles

/// Display presentation styles for the syringe component.
public enum SyringePresentationStyle: Sendable {
    /// Full card layout with hero readout, target pointer callout, visual syringe, and underlying numbers data grid.
    case full
    /// Compact card layout with hero readout and visual syringe (ideal for quick logs, modals, and list rows).
    case compact
    /// Pure graphic canvas without card wrapping or metrics grid (for embedding in custom layouts).
    case graphicOnly
}

// MARK: - Syringe Calculation & Display Model

/// Normalized metrics and values computed for the syringe visualization.
public struct SyringeDisplayMetrics: Sendable, Equatable {
    public let units: Double
    public let syringeSize: SyringeSize
    public let targetVolumeMl: Double
    public let targetVolumeMcl: Double
    public let fillFraction: Double
    public let fillPercentage: Double
    public let isOverCapacity: Bool
    public let remainingUnits: Double
    public let remainingVolumeMl: Double
    public let doseDescription: String
    public let compoundName: String?
    public let concentrationMgMl: Double?

    public init(
        units: Double,
        syringeSize: SyringeSize = .oneMl,
        doseDescription: String = "",
        volumeMl: Double? = nil,
        concentrationMgMl: Double? = nil,
        compoundName: String? = nil
    ) {
        self.units = max(0, units)
        self.syringeSize = syringeSize
        self.doseDescription = doseDescription
        self.compoundName = compoundName
        self.concentrationMgMl = concentrationMgMl

        let computedVolMl = volumeMl ?? (units / syringeSize.unitsPerMl)
        self.targetVolumeMl = max(0, computedVolMl)
        self.targetVolumeMcl = targetVolumeMl * 1000.0

        let maxU = syringeSize.maxUnits
        let rawFraction = maxU > 0 ? (units / maxU) : 0.0
        self.fillFraction = max(0.0, min(1.0, rawFraction))
        self.fillPercentage = rawFraction * 100.0
        self.isOverCapacity = units > maxU

        self.remainingUnits = max(0.0, maxU - units)
        self.remainingVolumeMl = max(0.0, syringeSize.maxVolumeMl - targetVolumeMl)
    }
}

// MARK: - Reusable Interactive Syringe View

/// InteractiveSyringeView: Precision-engineered SwiftUI syringe component.
///
/// Converts target volume supplied by the calculation engine into a normalized visual position.
/// Displays the target fill level with unmistakable visual positioning, pointers, labels,
/// and printed scale numbers without relying on color alone.
/// Always displays the underlying numbers alongside the visual representation.
public struct InteractiveSyringeView: View {
    public let metrics: SyringeDisplayMetrics
    public let presentationStyle: SyringePresentationStyle
    public let showUnderlyingNumbers: Bool
    public let showTargetCallout: Bool
    public let showScaleNumbers: Bool
    public let titleOverride: String?

    // MARK: - Initializers

    /// Primary initializer with primitive values and flexible styling options.
    public init(
        units: Double,
        syringeSize: SyringeSize = .oneMl,
        doseDescription: String = "",
        volumeMl: Double? = nil,
        concentrationMgMl: Double? = nil,
        compoundName: String? = nil,
        presentationStyle: SyringePresentationStyle = .full,
        showUnderlyingNumbers: Bool = true,
        showTargetCallout: Bool = true,
        showScaleNumbers: Bool = true,
        titleOverride: String? = nil
    ) {
        self.metrics = SyringeDisplayMetrics(
            units: units,
            syringeSize: syringeSize,
            doseDescription: doseDescription,
            volumeMl: volumeMl,
            concentrationMgMl: concentrationMgMl,
            compoundName: compoundName
        )
        self.presentationStyle = presentationStyle
        self.showUnderlyingNumbers = showUnderlyingNumbers
        self.showTargetCallout = showTargetCallout
        self.showScaleNumbers = showScaleNumbers
        self.titleOverride = titleOverride
    }

    /// Convenience initializer using pre-computed `SyringeDisplayMetrics`.
    public init(
        metrics: SyringeDisplayMetrics,
        presentationStyle: SyringePresentationStyle = .full,
        showUnderlyingNumbers: Bool = true,
        showTargetCallout: Bool = true,
        showScaleNumbers: Bool = true,
        titleOverride: String? = nil
    ) {
        self.metrics = metrics
        self.presentationStyle = presentationStyle
        self.showUnderlyingNumbers = showUnderlyingNumbers
        self.showTargetCallout = showTargetCallout
        self.showScaleNumbers = showScaleNumbers
        self.titleOverride = titleOverride
    }

    // MARK: - Body

    public var body: some View {
        switch presentationStyle {
        case .full:
            fullCardView
        case .compact:
            compactCardView
        case .graphicOnly:
            syringeCanvasWithScale
        }
    }

    // MARK: - Full Card View

    private var fullCardView: some View {
        VStack(spacing: VialrSpacing.md) {
            // 1. Header with Eyebrow, Numerical Readout, and Dose Badge
            headerSection

            // 2. Visual Syringe Graphic with Callout and Calibrated Scale
            syringeCanvasWithScale
                .padding(.vertical, 4)

            // 3. Underlying Numbers Data Grid
            if showUnderlyingNumbers {
                underlyingNumbersGrid
            }
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Syringe visualization for \(metrics.compoundName ?? "dose")")
        .accessibilityValue(accessibilityDescription)
    }

    // MARK: - Compact Card View

    private var compactCardView: some View {
        VStack(spacing: VialrSpacing.sm) {
            // Compact Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleOverride ?? "DRAW TARGET")
                        .vialrEyebrow()

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", metrics.units))
                            .font(VialrTypography.metricMedium)
                            .foregroundColor(VialrColors.textPrimary)

                        Text("Units (\(metrics.syringeSize.calibrationName))")
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.accentVitality)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.3f mL", metrics.targetVolumeMl))
                        .font(VialrTypography.monoSub)
                        .foregroundColor(VialrColors.textPrimary)

                    if !metrics.doseDescription.isEmpty {
                        Text(metrics.doseDescription)
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textSecondary)
                    }
                }
            }

            // Compact Syringe Canvas
            SyringeCanvasView(
                metrics: metrics,
                showTargetCallout: false,
                showScaleNumbers: true
            )
            .frame(height: 52)
        }
        .padding(VialrSpacing.cardPaddingCompact)
        .vialrCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Compact syringe target")
        .accessibilityValue(accessibilityDescription)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(titleOverride ?? "DRAW MARKING (\(metrics.syringeSize.calibrationName))")
                        .vialrEyebrow()

                    if metrics.isOverCapacity {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text("EXCEEDS CAPACITY")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(VialrColors.accentRose)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VialrColors.accentRose.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", metrics.units))
                        .font(VialrTypography.metricLarge)
                        .foregroundColor(metrics.isOverCapacity ? VialrColors.accentRose : VialrColors.textPrimary)

                    Text("Units")
                        .font(VialrTypography.title3)
                        .foregroundColor(metrics.isOverCapacity ? VialrColors.accentRose : VialrColors.accentVitality)

                    Text("(\(String(format: "%.3f", metrics.targetVolumeMl)) mL)")
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                        .padding(.leading, 4)
                }
            }

            Spacer()

            if !metrics.doseDescription.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    if let compound = metrics.compoundName {
                        Text(compound)
                            .font(VialrTypography.captionBold)
                            .foregroundColor(VialrColors.textPrimary)
                    }

                    Text(metrics.doseDescription)
                        .font(VialrTypography.footnote)
                        .foregroundColor(VialrColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(VialrColors.cardSurfaceElevated)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(VialrColors.glassBorder, lineWidth: 0.8)
                        )
                }
            }
        }
    }

    // MARK: - Syringe Canvas with Scale

    private var syringeCanvasWithScale: some View {
        SyringeCanvasView(
            metrics: metrics,
            showTargetCallout: showTargetCallout,
            showScaleNumbers: showScaleNumbers
        )
        .frame(height: showTargetCallout ? 86 : 64)
    }

    // MARK: - Underlying Numbers Data Grid

    private var underlyingNumbersGrid: some View {
        VStack(spacing: VialrSpacing.xs) {
            Divider()
                .background(VialrColors.glassBorder)
                .padding(.bottom, 4)

            // Primary Metrics Row
            HStack(spacing: VialrSpacing.sm) {
                metricCell(
                    label: "TARGET VOLUME",
                    value: String(format: "%.3f", metrics.targetVolumeMl),
                    unit: "mL",
                    subValue: "\(Int(round(metrics.targetVolumeMcl))) µL",
                    accentColor: VialrColors.accentCyan
                )

                metricCell(
                    label: "DRAW UNITS",
                    value: String(format: "%.1f", metrics.units),
                    unit: "Units",
                    subValue: "\(metrics.syringeSize.calibrationName) Standard",
                    accentColor: VialrColors.accentVitality
                )

                metricCell(
                    label: "BARREL FILL",
                    value: String(format: "%.0f%%", metrics.fillPercentage),
                    unit: "Full",
                    subValue: "of \(String(format: "%.1f", metrics.syringeSize.maxVolumeMl)) mL",
                    accentColor: metrics.isOverCapacity ? VialrColors.accentRose : VialrColors.textPrimary
                )
            }

            // Secondary Metrics Row (Concentration & Headroom)
            if metrics.concentrationMgMl != nil || metrics.remainingUnits > 0 {
                HStack(spacing: VialrSpacing.sm) {
                    if let conc = metrics.concentrationMgMl {
                        metricCell(
                            label: "CONCENTRATION",
                            value: String(format: "%.2f", conc),
                            unit: "mg/mL",
                            subValue: "\(Int(conc * 1000)) mcg/mL",
                            accentColor: VialrColors.textSecondary
                        )
                    }

                    metricCell(
                        label: "SYRINGE CAPACITY",
                        value: "\(Int(metrics.syringeSize.maxUnits))",
                        unit: "Units",
                        subValue: "\(String(format: "%.1f", metrics.syringeSize.maxVolumeMl)) mL Max",
                        accentColor: VialrColors.textTertiary
                    )

                    metricCell(
                        label: "HEADROOM",
                        value: String(format: "%.1f", metrics.remainingUnits),
                        unit: "Units",
                        subValue: "\(String(format: "%.2f", metrics.remainingVolumeMl)) mL Left",
                        accentColor: VialrColors.textTertiary
                    )
                }
                .padding(.top, 4)
            }
        }
    }

    private func metricCell(
        label: String,
        value: String,
        unit: String,
        subValue: String? = nil,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(VialrTypography.eyebrowMono)
                .foregroundColor(VialrColors.textTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(VialrTypography.monoDose)
                    .foregroundColor(accentColor)

                Text(unit)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textSecondary)
            }

            if let subValue = subValue {
                Text(subValue)
                    .font(VialrTypography.caption)
                    .foregroundColor(VialrColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VialrSpacing.xs)
        .background(VialrColors.cardSurfaceElevated.opacity(0.6))
        .cornerRadius(VialrSpacing.radiusSm)
    }

    // MARK: - Accessibility Description

    private var accessibilityDescription: String {
        var desc = "Target volume is \(String(format: "%.3f", metrics.targetVolumeMl)) milliliters, which is \(String(format: "%.1f", metrics.units)) units on a \(metrics.syringeSize.rawValue) syringe. Syringe barrel is \(Int(metrics.fillPercentage)) percent full."
        if metrics.isOverCapacity {
            desc += " Warning: dose exceeds syringe barrel capacity."
        }
        return desc
    }
}

// MARK: - Syringe 2D Canvas View

/// Precision 2D Syringe Graphic Canvas.
///
/// Features:
/// 1. Surgical stainless steel needle cannula and hub collar.
/// 2. Clear polycarbonate barrel with hairline glass border.
/// 3. Normalized liquid fill with vitality gradient and crisp meniscus line.
/// 4. Dual-rib dark graphite rubber plunger stopper aligned to exact fill line.
/// 5. Plunger shaft and thumb push flange.
/// 6. High-precision dynamic tick mark graduations and printed scale numbers.
/// 7. Multi-modal target indicator (arrow pointer, label pill, and target hairline).
public struct SyringeCanvasView: View {
    public let metrics: SyringeDisplayMetrics
    public let showTargetCallout: Bool
    public let showScaleNumbers: Bool

    public init(
        metrics: SyringeDisplayMetrics,
        showTargetCallout: Bool = true,
        showScaleNumbers: Bool = true
    ) {
        self.metrics = metrics
        self.showTargetCallout = showTargetCallout
        self.showScaleNumbers = showScaleNumbers
    }

    public var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let barrelHeight: CGFloat = 38
            let needleWidth: CGFloat = 16
            let hubWidth: CGFloat = 10
            let leftAssemblyWidth = needleWidth + hubWidth // 26 pt
            let plungerTailAllowance: CGFloat = 34
            let barrelWidth = max(60, totalWidth - leftAssemblyWidth - plungerTailAllowance)

            let fillFraction = metrics.fillFraction
            let usableBarrelWidth = barrelWidth - 6
            let fluidWidth = usableBarrelWidth * CGFloat(fillFraction)
            let targetPixelX = leftAssemblyWidth + 3 + fluidWidth

            VStack(spacing: 2) {
                // MARK: - 1. Target Indicator Callout (Floating above barrel)
                if showTargetCallout {
                    ZStack(alignment: .leading) {
                        Color.clear
                            .frame(height: 18)

                        // Target Pointer & Label
                        HStack(spacing: 2) {
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 8))
                                .foregroundColor(metrics.isOverCapacity ? VialrColors.accentRose : VialrColors.accentVitality)

                            Text(metrics.isOverCapacity ? "MAX CAP" : "\(String(format: "%.1f", metrics.units)) U")
                                .font(VialrTypography.eyebrowMono)
                                .foregroundColor(VialrColors.textPrimary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(metrics.isOverCapacity ? VialrColors.accentRose.opacity(0.8) : VialrColors.cardSurfaceSelected)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(metrics.isOverCapacity ? Color.red : VialrColors.accentVitality.opacity(0.8), lineWidth: 0.8)
                                )
                        }
                        // Center pointer on targetPixelX with bounds protection
                        .offset(x: max(leftAssemblyWidth - 10, min(totalWidth - 90, targetPixelX - 22)))
                        .animation(.spring(response: 0.42, dampingFraction: 0.76), value: metrics.units)
                    }
                    .frame(height: 18)
                }

                // MARK: - 2. Syringe Body (Needle, Hub, Barrel, Fluid, Plunger)
                ZStack(alignment: .leading) {
                    // Needle & Hub Assembly (Left)
                    needleAndHubAssembly(needleWidth: needleWidth, hubWidth: hubWidth)
                        .offset(x: 0, y: 0)

                    // Clear Syringe Barrel
                    barrelBody(width: barrelWidth, height: barrelHeight)
                        .offset(x: leftAssemblyWidth)

                    // Liquid Fill Column
                    liquidFill(width: fluidWidth, height: barrelHeight - 6)
                        .offset(x: leftAssemblyWidth + 3)

                    // Target Line Hairline Marker (Non-color reliant visual position)
                    targetMeniscusLine(height: barrelHeight - 2)
                        .offset(x: targetPixelX)
                        .animation(.spring(response: 0.42, dampingFraction: 0.76), value: metrics.units)

                    // Plunger Stopper & Shaft
                    plungerAssembly(
                        fluidWidth: fluidWidth,
                        barrelWidth: barrelWidth,
                        barrelHeight: barrelHeight
                    )
                    .offset(x: leftAssemblyWidth + 3 + fluidWidth)
                    .animation(.spring(response: 0.42, dampingFraction: 0.76), value: metrics.units)

                    // Calibrated Tick Marks Layer
                    tickMarksLayer(barrelWidth: usableBarrelWidth, height: barrelHeight)
                        .offset(x: leftAssemblyWidth + 3)
                }
                .frame(height: barrelHeight)

                // MARK: - 3. Printed Scale Numbers Legend
                if showScaleNumbers {
                    scaleNumbersLegend(barrelWidth: usableBarrelWidth, leftOffset: leftAssemblyWidth + 3)
                        .frame(height: 14)
                        .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Needle & Hub Assembly

    private func needleAndHubAssembly(needleWidth: CGFloat, hubWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Stainless Steel Bevel & Cannula
            ZStack(alignment: .leading) {
                // Cannula Tube
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "94A3B8"), Color.white, Color(hex: "64748B")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: needleWidth - 3, height: 2.2)

                // Bevel Sharp Tip
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 3, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 2.2))
                    path.closeSubpath()
                }
                .fill(Color.white)
            }

            // Plastic Luer Hub Adapter
            ZStack {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(
                        LinearGradient(
                            colors: [VialrColors.accentVitality.opacity(0.85), Color(hex: "0D9488")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: hubWidth, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2.5)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.6)
                    )

                // Hub Grip Ridges
                HStack(spacing: 2) {
                    Rectangle().fill(Color.black.opacity(0.3)).frame(width: 1, height: 12)
                    Rectangle().fill(Color.black.opacity(0.3)).frame(width: 1, height: 12)
                }
            }
        }
    }

    // MARK: - Barrel Body

    private func barrelBody(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .trailing) {
            // Main Glass / Polypropylene Tube
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(VialrColors.glassBorder, lineWidth: 1.2)
                )

            // Barrel Flange (Finger Grip at open plunger end)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.18))
                .frame(width: 3.5, height: height + 10)
                .offset(x: 1.5)
        }
    }

    // MARK: - Liquid Fill Column

    private func liquidFill(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3.5)
            .fill(
                metrics.isOverCapacity
                    ? LinearGradient(colors: [VialrColors.accentRose.opacity(0.85), Color.red], startPoint: .leading, endPoint: .trailing)
                    : VialrColors.syringeFluidGradient
            )
            .frame(width: max(0, width), height: height)
            .overlay(
                // Specular Glass Reflection along the top edge
                VStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 3)
                        .cornerRadius(1.5)
                        .padding(.horizontal, 2)
                        .padding(.top, 2)
                    Spacer()
                }
            )
            .animation(.spring(response: 0.42, dampingFraction: 0.76), value: metrics.units)
    }

    // MARK: - Target Meniscus Hairline Guide

    private func targetMeniscusLine(height: CGFloat) -> some View {
        ZStack {
            // High-contrast dual hairline (black outer, white/vitality inner)
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .frame(width: 2.5, height: height)

            Rectangle()
                .fill(metrics.isOverCapacity ? Color.red : Color.white)
                .frame(width: 1.2, height: height)
        }
    }

    // MARK: - Plunger Stopper & Shaft

    private func plungerAssembly(fluidWidth: CGFloat, barrelWidth: CGFloat, barrelHeight: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            // Dual-Rib Rubber Stopper (Graphite Medical Rubber)
            ZStack {
                // Stopper Base Block
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "2D3748"), Color(hex: "1A202C"), Color(hex: "111827")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 9, height: barrelHeight - 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )

                // Stopper Dual Sealing Rings (Convex Ribs)
                HStack(spacing: 3) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1.5, height: barrelHeight - 8)

                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1.5, height: barrelHeight - 8)
                }
            }

            // Plunger Shaft (Cruciform cross-ribbed shaft)
            ZStack(alignment: .leading) {
                // Main Plunger Stem
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.24), Color.white.opacity(0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 26, height: 7)

                // Shaft Center Rib
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 26, height: 1.5)
            }
            .offset(x: 9)

            // Plunger Thumb Push Flange (End Plate)
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "4A5568"), Color(hex: "2D3748")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3.5, height: 26)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .offset(x: 35)
        }
    }

    // MARK: - Tick Marks Layer

    private func tickMarksLayer(barrelWidth: CGFloat, height: CGFloat) -> some View {
        let size = metrics.syringeSize
        let maxUnits = size.maxUnits
        let majorInterval = size.majorTickInterval
        let minorInterval = size.minorTickInterval
        let totalMinorSteps = Int(round(maxUnits / minorInterval))

        return GeometryReader { _ in
            ForEach(0...totalMinorSteps, id: \.self) { step in
                let unitVal = Double(step) * minorInterval
                let isMajor = unitVal.truncatingRemainder(dividingBy: majorInterval) == 0
                let isMedium = !isMajor && (unitVal.truncatingRemainder(dividingBy: majorInterval / 2.0) == 0)
                let xFraction = unitVal / maxUnits
                let tickX = barrelWidth * CGFloat(xFraction)

                let tickHeight: CGFloat = isMajor ? 10 : (isMedium ? 6.5 : 4)
                let tickOpacity: Double = isMajor ? 0.75 : (isMedium ? 0.45 : 0.22)

                VStack {
                    // Top Tick Mark
                    Rectangle()
                        .fill(Color.white.opacity(tickOpacity))
                        .frame(width: isMajor ? 1.2 : 0.8, height: tickHeight)

                    Spacer()

                    // Bottom Tick Mark
                    Rectangle()
                        .fill(Color.white.opacity(tickOpacity))
                        .frame(width: isMajor ? 1.2 : 0.8, height: tickHeight)
                }
                .frame(height: height - 4)
                .position(x: tickX, y: height / 2.0)
            }
        }
        .frame(width: barrelWidth, height: height)
    }

    // MARK: - Scale Numbers Legend

    private func scaleNumbersLegend(barrelWidth: CGFloat, leftOffset: CGFloat) -> some View {
        let size = metrics.syringeSize
        let maxUnits = size.maxUnits
        let majorInterval = size.majorTickInterval
        let numMajorTicks = Int(round(maxUnits / majorInterval))

        return ZStack(alignment: .leading) {
            ForEach(0...numMajorTicks, id: \.self) { i in
                let val = Int(round(Double(i) * majorInterval))
                let fraction = Double(i) / Double(numMajorTicks)
                let posX = leftOffset + (barrelWidth * CGFloat(fraction))

                Text("\(val)")
                    .font(VialrTypography.monoSub)
                    .foregroundColor(val == 0 || val == Int(maxUnits) ? VialrColors.textSecondary : VialrColors.textTertiary)
                    .position(x: posX, y: 7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
