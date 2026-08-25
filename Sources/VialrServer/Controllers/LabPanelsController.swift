import Vapor
import Fluent

public struct LabPanelsController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let labGroup = routes.grouped("lab-panels")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        labGroup.get(use: listPanels)
        labGroup.post(use: createPanel)
        labGroup.get(":panelId", use: getPanel)
        labGroup.put(":panelId", use: updatePanel)
        labGroup.delete(":panelId", use: deletePanel)
    }

    public func listPanels(req: Request) async throws -> [LabPanelResponseDTO] {
        let payload = try req.auth.require(UserPayload.self)
        let panels = try await LabPanelEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .with(\.$results)
            .sort(\.$collectionDate, .descending)
            .all()

        return panels.map { p in
            let abnormalCount = p.results.filter { $0.flag != "Normal / In Range" }.count
            let resultDTOs = p.results.map { r in
                LabResultItemDTO(
                    id: r.id,
                    biomarkerName: r.biomarkerName,
                    category: r.category,
                    value: r.value,
                    textValue: r.textValue,
                    unit: r.unit,
                    referenceRangeMin: r.referenceRangeMin,
                    referenceRangeMax: r.referenceRangeMax,
                    flag: r.flag,
                    notes: r.notes
                )
            }

            return LabPanelResponseDTO(
                id: p.id ?? UUID(),
                panelName: p.panelName,
                labName: p.labName,
                collectionDate: p.collectionDate,
                resultDate: p.resultDate,
                status: p.status,
                orderingPhysician: nil,
                associatedProtocolId: nil,
                fastingStatus: "Fasting (8–12 hrs)",
                notes: p.notes,
                results: resultDTOs,
                abnormalCount: abnormalCount,
                totalAnalytes: p.results.count,
                createdAt: p.createdAt,
                updatedAt: p.updatedAt
            )
        }
    }

    public func createPanel(req: Request) async throws -> LabPanelResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(LabPanelRequestDTO.self)

        let panelId = dto.id ?? UUID()
        let panel = LabPanelEntity(
            id: panelId,
            userId: payload.userId,
            panelName: dto.panelName,
            labName: dto.labName,
            collectionDate: dto.collectionDate,
            resultDate: dto.resultDate ?? dto.collectionDate,
            status: dto.status ?? "Completed & Final",
            notes: dto.notes ?? "",
            version: 1
        )
        try await panel.save(on: req.db)

        var resultEntities: [LabResultEntity] = []
        for r in dto.results {
            var flag = r.flag ?? "Normal / In Range"
            if r.flag == nil {
                if let min = r.referenceRangeMin, r.value < min {
                    flag = "Low"
                } else if let max = r.referenceRangeMax, r.value > max {
                    flag = "High"
                }
            }

            let resultEntity = LabResultEntity(
                id: r.id ?? UUID(),
                panelId: panelId,
                biomarkerName: r.biomarkerName,
                category: r.category,
                value: r.value,
                textValue: r.textValue,
                unit: r.unit,
                referenceRangeMin: r.referenceRangeMin,
                referenceRangeMax: r.referenceRangeMax,
                flag: flag,
                notes: r.notes ?? ""
            )
            try await resultEntity.save(on: req.db)
            resultEntities.append(resultEntity)

            // Also persist in BiomarkerEntity for longitudinal trending
            let biomarker = BiomarkerEntity(
                id: UUID(),
                userId: payload.userId,
                name: r.biomarkerName,
                value: r.value,
                unit: r.unit,
                referenceRangeMin: r.referenceRangeMin,
                referenceRangeMax: r.referenceRangeMax,
                testDate: dto.collectionDate,
                labName: dto.labName,
                notes: r.notes
            )
            try? await biomarker.save(on: req.db)
        }

        let abnormalCount = resultEntities.filter { $0.flag != "Normal / In Range" }.count
        let resultDTOs = resultEntities.map { r in
            LabResultItemDTO(
                id: r.id,
                biomarkerName: r.biomarkerName,
                category: r.category,
                value: r.value,
                textValue: r.textValue,
                unit: r.unit,
                referenceRangeMin: r.referenceRangeMin,
                referenceRangeMax: r.referenceRangeMax,
                flag: r.flag,
                notes: r.notes
            )
        }

        return LabPanelResponseDTO(
            id: panelId,
            panelName: panel.panelName,
            labName: panel.labName,
            collectionDate: panel.collectionDate,
            resultDate: panel.resultDate,
            status: panel.status,
            orderingPhysician: dto.orderingPhysician,
            associatedProtocolId: dto.associatedProtocolId,
            fastingStatus: dto.fastingStatus ?? "Fasting (8–12 hrs)",
            notes: panel.notes,
            results: resultDTOs,
            abnormalCount: abnormalCount,
            totalAnalytes: resultEntities.count,
            createdAt: panel.createdAt,
            updatedAt: panel.updatedAt
        )
    }

    public func getPanel(req: Request) async throws -> LabPanelResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let panelId = req.parameters.get("panelId", as: UUID.self),
              let p = try await LabPanelEntity.query(on: req.db)
                .filter(\.$id == panelId)
                .filter(\.$user.$id == payload.userId)
                .with(\.$results)
                .first() else {
            throw Abort(.notFound, reason: "Lab panel not found.")
        }

        let abnormalCount = p.results.filter { $0.flag != "Normal / In Range" }.count
        let resultDTOs = p.results.map { r in
            LabResultItemDTO(
                id: r.id,
                biomarkerName: r.biomarkerName,
                category: r.category,
                value: r.value,
                textValue: r.textValue,
                unit: r.unit,
                referenceRangeMin: r.referenceRangeMin,
                referenceRangeMax: r.referenceRangeMax,
                flag: r.flag,
                notes: r.notes
            )
        }

        return LabPanelResponseDTO(
            id: p.id ?? panelId,
            panelName: p.panelName,
            labName: p.labName,
            collectionDate: p.collectionDate,
            resultDate: p.resultDate,
            status: p.status,
            orderingPhysician: nil,
            associatedProtocolId: nil,
            fastingStatus: "Fasting (8–12 hrs)",
            notes: p.notes,
            results: resultDTOs,
            abnormalCount: abnormalCount,
            totalAnalytes: p.results.count,
            createdAt: p.createdAt,
            updatedAt: p.updatedAt
        )
    }

    public func updatePanel(req: Request) async throws -> LabPanelResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let panelId = req.parameters.get("panelId", as: UUID.self),
              let p = try await LabPanelEntity.query(on: req.db)
                .filter(\.$id == panelId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Lab panel not found.")
        }

        let dto = try req.content.decode(LabPanelRequestDTO.self)
        p.panelName = dto.panelName
        p.labName = dto.labName
        p.collectionDate = dto.collectionDate
        p.resultDate = dto.resultDate
        if let s = dto.status { p.status = s }
        if let n = dto.notes { p.notes = n }
        try await p.save(on: req.db)

        return try await getPanel(req: req)
    }

    public func deletePanel(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let panelId = req.parameters.get("panelId", as: UUID.self),
              let p = try await LabPanelEntity.query(on: req.db)
                .filter(\.$id == panelId)
                .filter(\.$user.$id == payload.userId)
                .first() else {
            throw Abort(.notFound, reason: "Lab panel not found.")
        }

        try await p.delete(on: req.db)
        return .noContent
    }
}
