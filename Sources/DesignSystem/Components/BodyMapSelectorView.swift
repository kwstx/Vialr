import SwiftUI
import Domain

/// Lightweight display item representing a site for selection and rendering.
public struct SiteSelectionItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let shortLabel: String
    public let region: BodyRegion
    public let side: BodySide
    public let coordinates: SiteCoordinates
    public let daysSinceLastUse: Int?
    public let isRecommended: Bool
    public let isLastUsed: Bool
    public let restingScore: Double

    public init(
        id: String,
        name: String,
        shortLabel: String,
        region: BodyRegion = .abdomen,
        side: BodySide = .left,
        coordinates: SiteCoordinates = SiteCoordinates(x: 0.5, y: 0.5, view: .anterior),
        daysSinceLastUse: Int? = nil,
        isRecommended: Bool = false,
        isLastUsed: Bool = false,
        restingScore: Double = 100.0
    ) {
        self.id = id
        self.name = name
        self.shortLabel = shortLabel
        self.region = region
        self.side = side
        self.coordinates = coordinates
        self.daysSinceLastUse = daysSinceLastUse
        self.isRecommended = isRecommended
        self.isLastUsed = isLastUsed
        self.restingScore = restingScore
    }
}

/// BodyMapSelectorView: Interactive anatomical body-map visualization with 2D coordinate markers,
/// front/back orientation toggles, and rested tissue status indicators.
public struct BodyMapSelectorView: View {
    public let sites: [SiteSelectionItem]
    @Binding public var selectedSiteId: String?
    public var lastSiteId: String?
    public var nextSiteId: String?
    public var onSelect: ((SiteSelectionItem) -> Void)?

    @State private var viewOrientation: BodyViewOrientation = .anterior
    @State private var showVisualMap: Bool = true

    public init(
        sites: [SiteSelectionItem],
        selectedSiteId: Binding<String?>,
        lastSiteId: String? = nil,
        nextSiteId: String? = nil,
        onSelect: ((SiteSelectionItem) -> Void)? = nil
    ) {
        self.sites = sites
        self._selectedSiteId = selectedSiteId
        self.lastSiteId = lastSiteId
        self.nextSiteId = nextSiteId
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: VialrSpacing.md) {
            // Header with Orientation Picker
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ANATOMICAL ROTATION MAP")
                        .vialrEyebrow()
                    Text("Target Injection Site")
                        .font(VialrTypography.title3)
                        .foregroundColor(VialrColors.textPrimary)
                }

                Spacer()

                // Front / Back Toggle
                Picker("Body View", selection: $viewOrientation) {
                    ForEach(BodyViewOrientation.allCases) { orientation in
                        Text(orientation.rawValue).tag(orientation)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            // Interactive Body Map Canvas
            bodyMapCanvas
                .frame(height: 280)
                .padding(.vertical, 4)

            // Status Legend
            statusLegend

            // Anatomical Quick Selector Grid
            anatomicalGrid
        }
        .padding(VialrSpacing.cardPadding)
        .vialrCard()
    }

    // MARK: - 1. Body Map Graphical Canvas

    private var bodyMapCanvas: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height

            ZStack {
                // Background Card Canvas
                RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous)
                    .fill(VialrColors.cardSurfaceSubtle)
                    .overlay(
                        RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous)
                            .stroke(VialrColors.glassBorder, lineWidth: 1)
                    )

                // Anatomical Silhouette Vector Path
                BodySilhouetteShape(orientation: viewOrientation)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#1E293B").opacity(0.85),
                                Color(hex: "#0F172A").opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        BodySilhouetteShape(orientation: viewOrientation)
                            .stroke(VialrColors.accentTeal.opacity(0.25), lineWidth: 1.5)
                    )
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)

                // Anatomical Region Guide Lines
                regionGuides(width: w, height: h)

                // Site Coordinate Nodes
                let visibleSites = sites.filter { $0.coordinates.view == viewOrientation }
                ForEach(visibleSites) { item in
                    let posX = item.coordinates.x * w
                    let posY = item.coordinates.y * h

                    siteNode(for: item)
                        .position(x: posX, y: posY)
                }
            }
        }
    }

    // MARK: - 2. Site Node Marker

    @ViewBuilder
    private func siteNode(for item: SiteSelectionItem) -> some View {
        let isSelected = selectedSiteId == item.id
        let isNext = nextSiteId == item.id || item.isRecommended
        let isLast = lastSiteId == item.id || item.isLastUsed

        Button {
            selectedSiteId = item.id
            onSelect?(item)
            VialrHaptics.lightImpact()
        } label: {
            ZStack {
                // Pulsing Target Glow for Next Target Site
                if isNext {
                    Circle()
                        .fill(VialrColors.accentVitality.opacity(0.35))
                        .frame(width: 32, height: 32)
                }

                // Outer Selection Ring
                Circle()
                    .stroke(
                        isSelected ? VialrColors.accentVitality :
                        (isNext ? VialrColors.accentTeal :
                         (isLast ? VialrColors.accentAmber : Color.clear)),
                        lineWidth: isSelected ? 2.5 : 1.5
                    )
                    .frame(width: 22, height: 22)

                // Main Node Dot
                Circle()
                    .fill(nodeColor(for: item, isNext: isNext, isLast: isLast))
                    .frame(width: 14, height: 14)
                    .shadow(color: nodeColor(for: item, isNext: isNext, isLast: isLast).opacity(0.6), radius: 4)

                // Next / Last Badge Overlay
                if isNext {
                    Text("NEXT")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(Color.black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(VialrColors.accentVitality)
                        .clipShape(Capsule())
                        .offset(y: -18)
                } else if isLast {
                    Text("LAST")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(Color.black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(VialrColors.accentAmber)
                        .clipShape(Capsule())
                        .offset(y: -18)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func nodeColor(for item: SiteSelectionItem, isNext: Bool, isLast: Bool) -> Color {
        if isNext { return VialrColors.accentVitality }
        if isLast { return VialrColors.accentAmber }
        guard let days = item.daysSinceLastUse else { return VialrColors.accentEmerald }
        if days >= 7 { return VialrColors.accentEmerald }
        if days >= 3 { return VialrColors.accentAmber }
        return VialrColors.accentRose
    }

    // MARK: - 3. Region Guides

    @ViewBuilder
    private func regionGuides(width: Double, height: Double) -> some View {
        if viewOrientation == .anterior {
            // Subtle dotted center guideline
            Path { p in
                p.move(to: CGPoint(x: width * 0.5, y: height * 0.15))
                p.addLine(to: CGPoint(x: width * 0.5, y: height * 0.85))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundColor(VialrColors.textTertiary.opacity(0.2))
        }
    }

    // MARK: - 4. Status Legend

    private var statusLegend: some View {
        HStack(spacing: 12) {
            legendItem(color: VialrColors.accentVitality, label: "Next Target")
            legendItem(color: VialrColors.accentAmber, label: "Last Injected")
            legendItem(color: VialrColors.accentEmerald, label: "Rested (≥7d)")
            legendItem(color: VialrColors.accentRose, label: "Recent (<3d)")
        }
        .font(VialrTypography.caption)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(VialrTypography.caption)
                .foregroundColor(VialrColors.textSecondary)
        }
    }

    // MARK: - 5. Anatomical Quick Grid

    private var anatomicalGrid: some View {
        VStack(spacing: VialrSpacing.sm) {
            if viewOrientation == .anterior {
                // Deltoids
                HStack(spacing: VialrSpacing.sm) {
                    siteButton(for: "delt_l", defaultTitle: "Left Deltoid")
                    siteButton(for: "delt_r", defaultTitle: "Right Deltoid")
                }

                // Abdomen Quadrants (SubQ Core)
                VStack(spacing: 6) {
                    Text("Abdomen (SubQ Core)")
                        .font(VialrTypography.caption)
                        .foregroundColor(VialrColors.textTertiary)

                    HStack(spacing: 6) {
                        siteButton(for: "ab_l_uo", defaultTitle: "Upper Left")
                        siteButton(for: "ab_r_uo", defaultTitle: "Upper Right")
                    }
                    HStack(spacing: 6) {
                        siteButton(for: "ab_l_lo", defaultTitle: "Lower Left")
                        siteButton(for: "ab_r_lo", defaultTitle: "Lower Right")
                    }
                }
                .padding(8)
                .background(VialrColors.cardSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous))

                // Thighs
                HStack(spacing: VialrSpacing.sm) {
                    siteButton(for: "thigh_l_outer", defaultTitle: "Left Thigh")
                    siteButton(for: "thigh_r_outer", defaultTitle: "Right Thigh")
                }
            } else {
                // Triceps
                HStack(spacing: VialrSpacing.sm) {
                    siteButton(for: "tricep_l", defaultTitle: "Left Tricep")
                    siteButton(for: "tricep_r", defaultTitle: "Right Tricep")
                }

                // Glutes
                HStack(spacing: VialrSpacing.sm) {
                    siteButton(for: "glute_l", defaultTitle: "Left Ventrogluteal")
                    siteButton(for: "glute_r", defaultTitle: "Right Ventrogluteal")
                }
            }
        }
    }

    @ViewBuilder
    private func siteButton(for siteId: String, defaultTitle: String) -> some View {
        let item = sites.first(where: { $0.id == siteId }) ?? SiteSelectionItem(id: siteId, name: defaultTitle, shortLabel: defaultTitle)
        let isSelected = selectedSiteId == siteId
        let isNext = nextSiteId == siteId || item.isRecommended
        let isLast = lastSiteId == siteId || item.isLastUsed

        Button {
            selectedSiteId = siteId
            onSelect?(item)
            VialrHaptics.lightImpact()
        } label: {
            HStack(spacing: 8) {
                // Status indicator
                Circle()
                    .fill(nodeColor(for: item, isNext: isNext, isLast: isLast))
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(item.shortLabel)
                            .font(VialrTypography.bodyMedium)
                            .foregroundColor(isSelected ? VialrColors.textPrimary : VialrColors.textSecondary)

                        if isNext {
                            Text("NEXT")
                                .font(.system(size: 8, weight: .black))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(VialrColors.accentVitality.opacity(0.25))
                                .foregroundColor(VialrColors.accentVitality)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        } else if isLast {
                            Text("LAST")
                                .font(.system(size: 8, weight: .black))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(VialrColors.accentAmber.opacity(0.25))
                                .foregroundColor(VialrColors.accentAmber)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    if let days = item.daysSinceLastUse {
                        Text(days == 0 ? "Used today" : "\(days)d rested (\(Int(item.restingScore))%)")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.textTertiary)
                    } else {
                        Text("Never used (100% rested)")
                            .font(VialrTypography.caption)
                            .foregroundColor(VialrColors.accentEmerald)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(VialrColors.accentVitality)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? VialrColors.cardSurfaceSelected : VialrColors.cardSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VialrSpacing.radiusMd, style: .continuous)
                    .stroke(isSelected ? VialrColors.accentVitality : VialrColors.glassBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Anatomical Body Silhouette Vector Shape

public struct BodySilhouetteShape: Shape {
    public var orientation: BodyViewOrientation

    public init(orientation: BodyViewOrientation = .anterior) {
        self.orientation = orientation
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = rect.midX

        // Head (Oval)
        let headRadius = w * 0.10
        let headCenterY = rect.minY + h * 0.09
        path.addEllipse(in: CGRect(x: cx - headRadius, y: headCenterY - headRadius, width: headRadius * 2, height: headRadius * 2.2))

        // Neck & Shoulders & Torso & Legs
        path.move(to: CGPoint(x: cx - w * 0.05, y: h * 0.18))

        // Left Neck to Shoulder
        path.addQuadCurve(
            to: CGPoint(x: cx - w * 0.34, y: h * 0.24),
            control: CGPoint(x: cx - w * 0.16, y: h * 0.19)
        )

        // Left Deltoid & Arm
        path.addQuadCurve(
            to: CGPoint(x: cx - w * 0.38, y: h * 0.38),
            control: CGPoint(x: cx - w * 0.40, y: h * 0.30)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx - w * 0.24, y: h * 0.38),
            control: CGPoint(x: cx - w * 0.30, y: h * 0.38)
        )

        // Left Torso & Waist
        path.addQuadCurve(
            to: CGPoint(x: cx - w * 0.18, y: h * 0.48),
            control: CGPoint(x: cx - w * 0.22, y: h * 0.42)
        )

        // Left Hip & Thigh
        path.addQuadCurve(
            to: CGPoint(x: cx - w * 0.22, y: h * 0.60),
            control: CGPoint(x: cx - w * 0.23, y: h * 0.54)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx - w * 0.14, y: h * 0.88),
            control: CGPoint(x: cx - w * 0.20, y: h * 0.74)
        )

        // Crotch / Inseam
        path.addLine(to: CGPoint(x: cx - w * 0.04, y: h * 0.88))
        path.addLine(to: CGPoint(x: cx, y: h * 0.56))
        path.addLine(to: CGPoint(x: cx + w * 0.04, y: h * 0.88))

        // Right Leg & Thigh
        path.addLine(to: CGPoint(x: cx + w * 0.14, y: h * 0.88))
        path.addQuadCurve(
            to: CGPoint(x: cx + w * 0.22, y: h * 0.60),
            control: CGPoint(x: cx + w * 0.20, y: h * 0.74)
        )

        // Right Hip & Waist
        path.addQuadCurve(
            to: CGPoint(x: cx + w * 0.18, y: h * 0.48),
            control: CGPoint(x: cx + w * 0.23, y: h * 0.54)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx + w * 0.24, y: h * 0.38),
            control: CGPoint(x: cx + w * 0.22, y: h * 0.42)
        )

        // Right Arm & Deltoid
        path.addQuadCurve(
            to: CGPoint(x: cx + w * 0.38, y: h * 0.38),
            control: CGPoint(x: cx + w * 0.30, y: h * 0.38)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx + w * 0.34, y: h * 0.24),
            control: CGPoint(x: cx + w * 0.40, y: h * 0.30)
        )

        // Right Shoulder to Neck
        path.addQuadCurve(
            to: CGPoint(x: cx + w * 0.05, y: h * 0.18),
            control: CGPoint(x: cx + w * 0.16, y: h * 0.19)
        )

        path.closeSubpath()
        return path
    }
}

