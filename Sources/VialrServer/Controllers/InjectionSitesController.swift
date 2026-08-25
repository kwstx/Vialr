import Vapor
import Fluent
import Domain

public struct InjectionSitesController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let sitesGroup = routes.grouped("injection-sites")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        sitesGroup.get(use: listSites)
        sitesGroup.get("recommendation", use: getRecommendation)
        sitesGroup.get("events", use: listEvents)
        sitesGroup.post("events", use: logEvent)
    }

    public func listSites(req: Request) async throws -> [InjectionSiteDTO] {
        return InjectionSite.standardSites.map { s in
            InjectionSiteDTO(
                id: s.id,
                name: s.name,
                region: s.region.rawValue,
                side: s.side.rawValue,
                quadrant: s.quadrant?.rawValue,
                route: s.route.rawValue
            )
        }
    }

    public func getRecommendation(req: Request) async throws -> SiteRotationRecommendationDTO {
        let payload = try req.auth.require(UserPayload.self)
        let standardSites = InjectionSite.standardSites

        // Fetch recent site events
        let events = try await InjectionSiteEventEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .sort(\.$administeredAt, .descending)
            .all()

        var siteLastUsedMap: [String: Date] = [:]
        for ev in events {
            if siteLastUsedMap[ev.siteId] == nil {
                siteLastUsedMap[ev.siteId] = ev.administeredAt
            }
        }

        // Rank sites by least recently used (most rested)
        let ranked = standardSites.map { site -> (site: InjectionSite, lastUsed: Date?, daysRested: Int) in
            let lastDate = siteLastUsedMap[site.id]
            let days: Int
            if let d = lastDate {
                days = Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0
            } else {
                days = 999 // Never used
            }
            return (site: site, lastUsed: lastDate, daysRested: days)
        }.sorted { $0.daysRested > $1.daysRested }

        guard let topPick = ranked.first else {
            let defaultSite = standardSites[0]
            return SiteRotationRecommendationDTO(
                recommendedSite: InjectionSiteDTO(id: defaultSite.id, name: defaultSite.name, region: defaultSite.region.rawValue, side: defaultSite.side.rawValue, quadrant: defaultSite.quadrant?.rawValue),
                daysSinceLastUsed: nil,
                reason: "Standard starting site for subcutaneous administration."
            )
        }

        let primaryDTO = InjectionSiteDTO(
            id: topPick.site.id,
            name: topPick.site.name,
            region: topPick.site.region.rawValue,
            side: topPick.site.side.rawValue,
            quadrant: topPick.site.quadrant?.rawValue,
            route: topPick.site.route.rawValue
        )

        let reason = topPick.daysRested >= 999
            ? "Site has not been used yet; optimal for fresh tissue absorption."
            : "Most rested site (\(topPick.daysRested) days since last injection) to prevent lipohypertrophy."

        let alternatives = ranked.dropFirst().prefix(3).map { item in
            InjectionSiteDTO(
                id: item.site.id,
                name: item.site.name,
                region: item.site.region.rawValue,
                side: item.site.side.rawValue,
                quadrant: item.site.quadrant?.rawValue,
                route: item.site.route.rawValue
            )
        }

        return SiteRotationRecommendationDTO(
            recommendedSite: primaryDTO,
            daysSinceLastUsed: topPick.daysRested >= 999 ? nil : topPick.daysRested,
            reason: reason,
            alternativeSites: Array(alternatives)
        )
    }

    public func listEvents(req: Request) async throws -> [InjectionSiteEventResponseDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let events = try await InjectionSiteEventEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .sort(\.$administeredAt, .descending)
            .all()

        return events.map { ev in
            let days = Calendar.current.dateComponents([.day], from: ev.administeredAt, to: Date()).day ?? 0
            return InjectionSiteEventResponseDTO(
                id: ev.id ?? UUID(),
                siteId: ev.siteId,
                siteName: ev.siteName,
                region: ev.region,
                side: ev.side,
                doseLogId: ev.$doseLog.id,
                administeredAt: ev.administeredAt,
                daysSinceLastUse: days,
                painScore: ev.painScore,
                notes: ev.notes
            )
        }
    }

    public func logEvent(req: Request) async throws -> InjectionSiteEventResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(InjectionSiteEventRequestDTO.self)

        let siteName = InjectionSite.standardSites.first(where: { $0.id == dto.siteId })?.name ?? dto.siteId
        let region = InjectionSite.standardSites.first(where: { $0.id == dto.siteId })?.region.rawValue ?? "Abdomen"
        let side = InjectionSite.standardSites.first(where: { $0.id == dto.siteId })?.side.rawValue ?? "Left"

        let entityId = UUID()
        let adminDate = dto.administeredAt ?? Date()
        let entity = InjectionSiteEventEntity(
            id: entityId,
            userId: payload.userId,
            doseLogId: dto.doseLogId,
            siteId: dto.siteId,
            siteName: siteName,
            region: region,
            side: side,
            administeredAt: adminDate,
            painScore: dto.painScore,
            notes: dto.notes
        )
        try await entity.save(on: req.db)

        return InjectionSiteEventResponseDTO(
            id: entityId,
            siteId: entity.siteId,
            siteName: entity.siteName,
            region: entity.region,
            side: entity.side,
            doseLogId: entity.$doseLog.id,
            administeredAt: entity.administeredAt,
            daysSinceLastUse: 0,
            painScore: entity.painScore,
            notes: entity.notes
        )
    }
}
