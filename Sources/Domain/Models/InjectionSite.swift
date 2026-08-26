import Foundation

/// Orientation for anatomical body visualization (Anterior / Front or Posterior / Back).
public enum BodyViewOrientation: String, Codable, Sendable, CaseIterable, Identifiable {
    case anterior = "Front"
    case posterior = "Back"

    public var id: String { rawValue }
}

/// Normalized 2D coordinates `[0.0, 1.0]` representing the precise location of an injection site
/// on anatomical front and back vector diagrams.
public struct SiteCoordinates: Codable, Sendable, Hashable {
    /// Normalized horizontal position (0.0 = left edge, 1.0 = right edge from viewer perspective).
    public var x: Double
    /// Normalized vertical position (0.0 = top of head, 1.0 = bottom of feet).
    public var y: Double
    /// Whether this site is located on the front (anterior) or back (posterior) of the body.
    public var view: BodyViewOrientation

    public init(x: Double, y: Double, view: BodyViewOrientation = .anterior) {
        self.x = min(max(x, 0.0), 1.0)
        self.y = min(max(y, 0.0), 1.0)
        self.view = view
    }
}

/// User-selectable rotation strategy patterns for injection site scheduling.
///
/// Non-Medical Policy: The rotation engine purely enforces the user's chosen strategy
/// deterministically based on historical injection logs. It does not provide medical recommendations.
public enum SiteRotationStrategy: String, Codable, Sendable, CaseIterable, Identifiable {
    case bilateralAlternating = "bilateral_alternating"
    case clockwise = "clockwise"
    case counterClockwise = "counter_clockwise"
    case maximumRest = "maximum_rest"
    case leastFrequentlyUsed = "least_frequently_used"
    case sequential = "sequential"
    case regionCycling = "region_cycling"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bilateralAlternating: return "Alternate Sides"
        case .clockwise: return "Clockwise Quadrants"
        case .counterClockwise: return "Counter-Clockwise"
        case .maximumRest: return "Maximum Rest (LRU)"
        case .leastFrequentlyUsed: return "Balanced Usage (LFU)"
        case .sequential: return "Sequential Order"
        case .regionCycling: return "Cycle Body Regions"
        }
    }

    public var descriptionText: String {
        switch self {
        case .bilateralAlternating:
            return "Alternates between Left and Right sides with each administration."
        case .clockwise:
            return "Steps clockwise around quadrants (e.g. Upper Left → Upper Right → Lower Right → Lower Left)."
        case .counterClockwise:
            return "Steps counter-clockwise around quadrants (e.g. Upper Left → Lower Left → Lower Right → Upper Right)."
        case .maximumRest:
            return "Prioritizes the site with the longest elapsed rest time since previous use."
        case .leastFrequentlyUsed:
            return "Prioritizes the site with the lowest lifetime administration count to distribute tissue wear evenly."
        case .sequential:
            return "Cycles deterministically through active injection sites in strict alphabetical/configured order."
        case .regionCycling:
            return "Rotates across anatomical regions (e.g. Abdomen → Thigh → Deltoid → Glute)."
        }
    }

    public var systemImageName: String {
        switch self {
        case .bilateralAlternating: return "arrow.left.and.right"
        case .clockwise: return "arrow.clockwise"
        case .counterClockwise: return "arrow.counterclockwise"
        case .maximumRest: return "bed.double.fill"
        case .leastFrequentlyUsed: return "chart.bar.xaxis"
        case .sequential: return "list.number"
        case .regionCycling: return "arrow.triangle.2.circlepath"
        }
    }
}

/// Represents an anatomical injection site for subcutaneous or intramuscular administration.
public struct InjectionSite: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var name: String
    public var shortName: String
    public var region: BodyRegion
    public var side: BodySide
    public var quadrant: Quadrant?
    public var route: AdministrationRoute
    public var coordinates: SiteCoordinates
    public var isActive: Bool

    public init(
        id: String,
        name: String,
        shortName: String? = nil,
        region: BodyRegion,
        side: BodySide,
        quadrant: Quadrant? = nil,
        route: AdministrationRoute = .subcutaneous,
        coordinates: SiteCoordinates = SiteCoordinates(x: 0.5, y: 0.5, view: .anterior),
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName ?? name
        self.region = region
        self.side = side
        self.quadrant = quadrant
        self.route = route
        self.coordinates = coordinates
        self.isActive = isActive
    }

    /// User-friendly label formatted like "Left abdomen" or "Right deltoid".
    public var conciseDescription: String {
        let sideStr = side.rawValue
        let regionStr = region.conciseName.lowercased()
        if let quad = quadrant {
            return "\(sideStr) \(quad.rawValue.lowercased()) \(regionStr)"
        }
        return "\(sideStr) \(regionStr)"
    }
}

public enum BodyRegion: String, Codable, Sendable, CaseIterable, Identifiable {
    case abdomen = "Abdomen"
    case deltoid = "Deltoid"
    case thigh = "Thigh (Vastus Lateralis)"
    case glute = "Gluteal (Ventrogluteal)"
    case tricep = "Tricep"
    case subscapular = "Subscapular (Upper Back)"

    public var id: String { rawValue }

    public var conciseName: String {
        switch self {
        case .abdomen: return "Abdomen"
        case .deltoid: return "Deltoid"
        case .thigh: return "Thigh"
        case .glute: return "Glute"
        case .tricep: return "Tricep"
        case .subscapular: return "Back"
        }
    }
}

public enum BodySide: String, Codable, Sendable, CaseIterable, Identifiable {
    case left = "Left"
    case right = "Right"
    case center = "Center"

    public var id: String { rawValue }

    public var opposite: BodySide {
        switch self {
        case .left: return .right
        case .right: return .left
        case .center: return .center
        }
    }
}

public enum Quadrant: String, Codable, Sendable, CaseIterable, Identifiable {
    case upperOuter = "Upper Outer"
    case lowerOuter = "Lower Outer"
    case upperInner = "Upper Inner"
    case lowerInner = "Lower Inner"

    public var id: String { rawValue }
}

/// Comprehensive evaluated status of a single anatomical site.
public struct SiteRotationStatus: Identifiable, Sendable, Codable, Hashable {
    public let site: InjectionSite
    public let lastUsedDate: Date?
    public let daysSinceLastUse: Int?
    public let timesUsedTotal: Int
    public let restingScore: Double // 0 (recently used) to 100 (fully rested >= 7 days)
    public let isRecommended: Bool
    public let isLastUsed: Bool
    public let activeReaction: SiteReactionSeverity?
    public let orderIndex: Int

    public var id: String { site.id }

    public init(
        site: InjectionSite,
        lastUsedDate: Date? = nil,
        daysSinceLastUse: Int? = nil,
        timesUsedTotal: Int = 0,
        restingScore: Double = 100.0,
        isRecommended: Bool = false,
        isLastUsed: Bool = false,
        activeReaction: SiteReactionSeverity? = nil,
        orderIndex: Int = 0
    ) {
        self.site = site
        self.lastUsedDate = lastUsedDate
        self.daysSinceLastUse = daysSinceLastUse
        self.timesUsedTotal = timesUsedTotal
        self.restingScore = restingScore
        self.isRecommended = isRecommended
        self.isLastUsed = isLastUsed
        self.activeReaction = activeReaction
        self.orderIndex = orderIndex
    }

    /// Whether this site is considered fully recovered (rested >= 7 days).
    public var isFullyRested: Bool {
        restingScore >= 99.0
    }
}

/// Evaluated outcome of the site rotation calculation.
public struct SiteRotationResult: Sendable, Codable, Hashable {
    /// The most recently injected anatomical site, if available.
    public let lastSite: InjectionSite?
    /// The next recommended target site calculated from the user's rotation strategy.
    public let nextSite: InjectionSite
    /// The ground-truth event associated with the last injection.
    public let lastEvent: InjectionSiteEvent?
    /// Evaluated status for all active anatomical sites.
    public let siteStatuses: [SiteRotationStatus]
    /// The rotation strategy applied during calculation.
    public let enforcedStrategy: SiteRotationStrategy
    /// Human-readable explanation of why this next site was selected based on the user's pattern.
    public let strategyReason: String
    /// Timestamp when this calculation was performed.
    public let evaluatedAt: Date

    public init(
        lastSite: InjectionSite?,
        nextSite: InjectionSite,
        lastEvent: InjectionSiteEvent? = nil,
        siteStatuses: [SiteRotationStatus],
        enforcedStrategy: SiteRotationStrategy,
        strategyReason: String,
        evaluatedAt: Date = Date()
    ) {
        self.lastSite = lastSite
        self.nextSite = nextSite
        self.lastEvent = lastEvent
        self.siteStatuses = siteStatuses
        self.enforcedStrategy = enforcedStrategy
        self.strategyReason = strategyReason
        self.evaluatedAt = evaluatedAt
    }
}

// MARK: - Predefined Standard Anatomical Sites with 2D Visualization Coordinates
public extension InjectionSite {
    /// Standard predefined subcutaneous and intramuscular rotation sites with exact 2D coordinates.
    static let standardSites: [InjectionSite] = [
        // MARK: Abdomen Quadrants (Anterior, SubQ Primary)
        InjectionSite(
            id: "ab_l_uo",
            name: "Abdomen - Left Upper Outer",
            shortName: "Upper Left",
            region: .abdomen,
            side: .left,
            quadrant: .upperOuter,
            route: .subcutaneous,
            coordinates: SiteCoordinates(x: 0.38, y: 0.44, view: .anterior)
        ),
        InjectionSite(
            id: "ab_r_uo",
            name: "Abdomen - Right Upper Outer",
            shortName: "Upper Right",
            region: .abdomen,
            side: .right,
            quadrant: .upperOuter,
            route: .subcutaneous,
            coordinates: SiteCoordinates(x: 0.62, y: 0.44, view: .anterior)
        ),
        InjectionSite(
            id: "ab_r_lo",
            name: "Abdomen - Right Lower Outer",
            shortName: "Lower Right",
            region: .abdomen,
            side: .right,
            quadrant: .lowerOuter,
            route: .subcutaneous,
            coordinates: SiteCoordinates(x: 0.62, y: 0.50, view: .anterior)
        ),
        InjectionSite(
            id: "ab_l_lo",
            name: "Abdomen - Left Lower Outer",
            shortName: "Lower Left",
            region: .abdomen,
            side: .left,
            quadrant: .lowerOuter,
            route: .subcutaneous,
            coordinates: SiteCoordinates(x: 0.38, y: 0.50, view: .anterior)
        ),

        // MARK: Thighs (Vastus Lateralis, Anterior, SubQ/IM)
        InjectionSite(
            id: "thigh_l_outer",
            name: "Left Thigh - Outer Mid",
            shortName: "Left Thigh",
            region: .thigh,
            side: .left,
            quadrant: .upperOuter,
            route: .subcutaneous,
            coordinates: SiteCoordinates(x: 0.35, y: 0.68, view: .anterior)
        ),
        InjectionSite(
            id: "thigh_r_outer",
            name: "Right Thigh - Outer Mid",
            shortName: "Right Thigh",
            region: .thigh,
            side: .right,
            quadrant: .upperOuter,
            route: .subcutaneous,
            coordinates: SiteCoordinates(x: 0.65, y: 0.68, view: .anterior)
        ),

        // MARK: Deltoids (Anterior/Lateral, SubQ/IM)
        InjectionSite(
            id: "delt_l",
            name: "Left Deltoid",
            shortName: "Left Deltoid",
            region: .deltoid,
            side: .left,
            route: .subcutaneous,
            coordinates: SiteCoordinates(x: 0.22, y: 0.26, view: .anterior)
        ),
        InjectionSite(
            id: "delt_r",
            name: "Right Deltoid",
            shortName: "Right Deltoid",
            region: .deltoid,
            side: .right,
            route: .subcutaneous,
            coordinates: SiteCoordinates(x: 0.78, y: 0.26, view: .anterior)
        ),

        // MARK: Glutes (Posterior, Ventrogluteal / Dorsogluteal, IM/SubQ)
        InjectionSite(
            id: "glute_l",
            name: "Left Ventrogluteal",
            shortName: "Left Glute",
            region: .glute,
            side: .left,
            route: .intramuscular,
            coordinates: SiteCoordinates(x: 0.36, y: 0.55, view: .posterior)
        ),
        InjectionSite(
            id: "glute_r",
            name: "Right Ventrogluteal",
            shortName: "Right Glute",
            region: .glute,
            side: .right,
            route: .intramuscular,
            coordinates: SiteCoordinates(x: 0.64, y: 0.55, view: .posterior)
        ),

        // MARK: Triceps (Posterior, SubQ)
        InjectionSite(
            id: "tricep_l",
            name: "Left Tricep",
            shortName: "Left Tricep",
            region: .tricep,
            side: .left,
            route: .subcutaneous,
            coordinates: SiteCoordinates(x: 0.21, y: 0.32, view: .posterior)
        ),
        InjectionSite(
            id: "tricep_r",
            name: "Right Tricep",
            shortName: "Right Tricep",
            region: .tricep,
            side: .right,
            route: .subcutaneous,
            coordinates: SiteCoordinates(x: 0.79, y: 0.32, view: .posterior)
        )
    ]
}
