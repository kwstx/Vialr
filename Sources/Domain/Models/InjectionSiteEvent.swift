import Foundation

/// Records where an injection was administered, connecting that anatomical location directly to a `DoseEvent`.
/// Tracks anatomical site specifics, needle parameters, localized tissue reactions, and recovery timestamps.
public struct InjectionSiteEvent: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var doseEventId: UUID
    public var siteId: String
    public var siteName: String
    public var region: BodyRegion
    public var side: BodySide
    public var quadrant: Quadrant?
    public var route: AdministrationRoute
    public var timestamp: Date
    public var compoundId: UUID
    public var compoundName: String
    public var doseAmount: Double
    public var doseUnit: DoseUnit
    public var needleGauge: String?
    public var needleLength: String?
    public var reaction: SiteReactionSeverity
    public var painScore: Int? // 0-10
    public var photoFileId: UUID?
    public var notes: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        doseEventId: UUID,
        siteId: String,
        siteName: String,
        region: BodyRegion = .abdomen,
        side: BodySide = .left,
        quadrant: Quadrant? = nil,
        route: AdministrationRoute = .subcutaneous,
        timestamp: Date = Date(),
        compoundId: UUID,
        compoundName: String,
        doseAmount: Double,
        doseUnit: DoseUnit = .mcg,
        needleGauge: String? = "31G",
        needleLength: String? = "5/16\"",
        reaction: SiteReactionSeverity = .none,
        painScore: Int? = 0,
        photoFileId: UUID? = nil,
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.doseEventId = doseEventId
        self.siteId = siteId
        self.siteName = siteName
        self.region = region
        self.side = side
        self.quadrant = quadrant
        self.route = route
        self.timestamp = timestamp
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.needleGauge = needleGauge
        self.needleLength = needleLength
        self.reaction = reaction
        self.painScore = painScore
        self.photoFileId = photoFileId
        self.notes = notes
        self.createdAt = createdAt
    }

    /// Convenience initializer linking directly from an `InjectionSite` and `DoseEvent`.
    public init(
        site: InjectionSite,
        doseEvent: DoseEvent,
        needleGauge: String? = "31G",
        needleLength: String? = "5/16\"",
        reaction: SiteReactionSeverity = .none,
        painScore: Int? = 0,
        photoFileId: UUID? = nil,
        notes: String = ""
    ) {
        self.init(
            id: UUID(),
            doseEventId: doseEvent.id,
            siteId: site.id,
            siteName: site.name,
            region: site.region,
            side: site.side,
            quadrant: site.quadrant,
            route: doseEvent.actualRoute,
            timestamp: doseEvent.actualTimestamp ?? doseEvent.scheduledTimestamp,
            compoundId: doseEvent.compoundId,
            compoundName: doseEvent.compoundName,
            doseAmount: doseEvent.actualDoseAmount,
            doseUnit: doseEvent.doseUnit,
            needleGauge: needleGauge,
            needleLength: needleLength,
            reaction: reaction,
            painScore: painScore,
            photoFileId: photoFileId,
            notes: notes,
            createdAt: Date()
        )
    }

    /// Days elapsed since this injection was administered.
    public var daysSinceAdministration: Int {
        let calendar = Calendar.current
        let diff = calendar.dateComponents([.day], from: timestamp, to: Date()).day ?? 0
        return max(0, diff)
    }

    /// Whether this site has reached the minimum standard rest period (7 days).
    public var isFullyRested: Bool {
        daysSinceAdministration >= 7
    }
}

// MARK: - Site Reaction Severity
public enum SiteReactionSeverity: String, Codable, Sendable, CaseIterable, Identifiable {
    case none = "None / Normal"
    case mildRedness = "Mild Redness (Erythema)"
    case itching = "Itching / Pruritus"
    case bruising = "Bruising (Hematoma)"
    case swelling = "Localized Swelling / Edema"
    case induration = "Subcutaneous Lump (Induration)"
    case significantPain = "Moderate / Severe Pain"

    public var id: String { rawValue }

    public var requiresRest: Bool {
        switch self {
        case .none: return false
        case .mildRedness, .itching: return false
        case .bruising, .swelling, .induration, .significantPain: return true
        }
    }

    public var iconName: String {
        switch self {
        case .none: return "checkmark.circle.fill"
        case .mildRedness: return "circle.fill"
        case .itching: return "hand.tap.fill"
        case .bruising: return "drop.fill"
        case .swelling: return "arrow.up.and.down.and.arrow.left.and.right"
        case .induration: return "circle.grid.cross.fill"
        case .significantPain: return "exclamationmark.triangle.fill"
        }
    }
}
