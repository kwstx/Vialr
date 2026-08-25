import Foundation

/// Represents an anatomical injection site for subcutaneous or intramuscular administration.
public struct InjectionSite: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var name: String
    public var region: BodyRegion
    public var side: BodySide
    public var quadrant: Quadrant?
    public var route: AdministrationRoute

    public init(
        id: String,
        name: String,
        region: BodyRegion,
        side: BodySide,
        quadrant: Quadrant? = nil,
        route: AdministrationRoute = .subcutaneous
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.side = side
        self.quadrant = quadrant
        self.route = route
    }
}

public enum BodyRegion: String, Codable, Sendable, CaseIterable, Identifiable {
    case abdomen = "Abdomen"
    case deltoid = "Deltoid"
    case thigh = "Thigh (Vastus Lateralis)"
    case glute = "Gluteal (Ventrogluteal)"
    case tricep = "Tricep"

    public var id: String { rawValue }
}

public enum BodySide: String, Codable, Sendable, CaseIterable, Identifiable {
    case left = "Left"
    case right = "Right"
    case center = "Center"

    public var id: String { rawValue }
}

public enum Quadrant: String, Codable, Sendable, CaseIterable, Identifiable {
    case upperOuter = "Upper Outer"
    case lowerOuter = "Lower Outer"
    case upperInner = "Upper Inner"
    case lowerInner = "Lower Inner"

    public var id: String { rawValue }
}

public extension InjectionSite {
    /// Standard predefined subcutaneous and intramuscular rotation sites.
    static let standardSites: [InjectionSite] = [
        // Abdomen (SubQ primary)
        InjectionSite(id: "ab_l_uo", name: "Abdomen - Left Upper Outer", region: .abdomen, side: .left, quadrant: .upperOuter),
        InjectionSite(id: "ab_l_lo", name: "Abdomen - Left Lower Outer", region: .abdomen, side: .left, quadrant: .lowerOuter),
        InjectionSite(id: "ab_r_uo", name: "Abdomen - Right Upper Outer", region: .abdomen, side: .right, quadrant: .upperOuter),
        InjectionSite(id: "ab_r_lo", name: "Abdomen - Right Lower Outer", region: .abdomen, side: .right, quadrant: .lowerOuter),
        
        // Thighs (SubQ / IM)
        InjectionSite(id: "thigh_l_outer", name: "Left Thigh - Outer Mid", region: .thigh, side: .left, quadrant: .upperOuter),
        InjectionSite(id: "thigh_r_outer", name: "Right Thigh - Outer Mid", region: .thigh, side: .right, quadrant: .upperOuter),
        
        // Deltoids (SubQ / IM)
        InjectionSite(id: "delt_l", name: "Left Deltoid", region: .deltoid, side: .left),
        InjectionSite(id: "delt_r", name: "Right Deltoid", region: .deltoid, side: .right),
        
        // Glutes (IM / SubQ)
        InjectionSite(id: "glute_l", name: "Left Ventrogluteal", region: .glute, side: .left),
        InjectionSite(id: "glute_r", name: "Right Ventrogluteal", region: .glute, side: .right)
    ]
}
