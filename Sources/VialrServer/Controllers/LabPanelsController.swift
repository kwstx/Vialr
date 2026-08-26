import Vapor
import Fluent
import Domain
import CalculationEngine

public struct LabPanelsController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let labGroup = routes.grouped("lab-panels")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        labGroup.get(use: listPanels)
        labGroup.post(use: createPanel)
        labGroup.post("extract-document", use: extractDocument)
        labGroup.post("confirm-candidates", use: confirmCandidates)
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

    // MARK: - Extract Candidate Biomarkers from Uploaded Document
    public func extractDocument(req: Request) async throws -> ExtractLabDocumentResponseDTO {
        _ = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(ExtractLabDocumentRequestDTO.self)

        let parser = LabReportParserEngine()
        let fileName = dto.fileName ?? "Laboratory_Report.pdf"
        let rawText = dto.rawText ?? "QUEST DIAGNOSTICS\nCOLLECTION DATE: 2024-05-15\nFASTING: YES\nORDERED BY: Dr. William Sterling, MD\n\nTESTOSTERONE, TOTAL 845 ng/dL 250-1100\nFREE TESTOSTERONE 24.2 pg/mL 9.0-30.0\nESTRADIOL, SENSITIVE 28.5 pg/mL 8.0-35.0\nIGF-1 268 ng/mL 115-307\nGLUCOSE 88 mg/dL 70-99\nINSULIN, FASTING 3.8 uIU/mL 2.0-6.0\nAPOB 68 mg/dL < 90\nHEMATOCRIT 47.2 % 38.5-50.0\nALT 22 IU/L 9-44\nHS CRP 0.35 mg/L < 1.0"

        let candidateReport = parser.parse(rawText: rawText, fileName: fileName, documentId: dto.documentId)

        let candidateDTOs = candidateReport.candidates.map { c in
            ExtractedCandidateItemDTO(
                id: c.id,
                rawAnalyteName: c.rawAnalyteName,
                matchedCatalogId: c.matchedCatalogId,
                resolvedName: c.resolvedName,
                category: c.category.rawValue,
                extractedValue: c.extractedValue,
                extractedTextValue: c.extractedTextValue,
                extractedUnit: c.extractedUnit,
                referenceRangeMin: c.referenceRangeMin,
                referenceRangeMax: c.referenceRangeMax,
                referenceRangeText: c.referenceRangeText,
                detectedFlag: c.detectedFlag.rawValue,
                confidenceScore: c.confidenceScore,
                confidenceLevel: c.confidenceLevel.rawValue,
                rawSnippet: c.rawSnippet,
                isSelected: c.isSelected
            )
        }

        return ExtractLabDocumentResponseDTO(
            id: candidateReport.id,
            documentId: candidateReport.documentId,
            fileName: candidateReport.fileName,
            detectedLabName: candidateReport.detectedLabName,
            detectedPanelName: candidateReport.detectedPanelName,
            detectedCollectionDate: candidateReport.detectedCollectionDate,
            detectedFastingStatus: candidateReport.detectedFastingStatus.rawValue,
            detectedOrderingPhysician: candidateReport.detectedOrderingPhysician,
            overallConfidence: candidateReport.overallConfidence,
            candidates: candidateDTOs,
            processingWarnings: candidateReport.processingWarnings
        )
    }

    // MARK: - Confirm and Persist Candidate Laboratory Data
    public func confirmCandidates(req: Request) async throws -> LabPanelResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let dto = try req.content.decode(ConfirmLabCandidatesRequestDTO.self)

        let panelId = UUID()
        let panel = LabPanelEntity(
            id: panelId,
            userId: payload.userId,
            panelName: dto.panelName,
            labName: dto.labName,
            collectionDate: dto.collectionDate,
            resultDate: dto.resultDate ?? dto.collectionDate,
            status: "Completed & Final",
            notes: dto.notes ?? "Verified and confirmed from laboratory report.",
            version: 1
        )
        try await panel.save(on: req.db)

        var resultEntities: [LabResultEntity] = []
        for c in dto.confirmedCandidates {
            let flag = c.flag ?? "Normal / In Range"
            let resultEntity = LabResultEntity(
                id: UUID(),
                panelId: panelId,
                biomarkerName: c.biomarkerName,
                category: c.category,
                value: c.value,
                textValue: c.textValue,
                unit: c.unit,
                referenceRangeMin: c.referenceRangeMin,
                referenceRangeMax: c.referenceRangeMax,
                flag: flag,
                notes: c.notes ?? ""
            )
            try await resultEntity.save(on: req.db)
            resultEntities.append(resultEntity)

            // Also persist longitudinal biomarker history
            let biomarker = BiomarkerEntity(
                id: UUID(),
                userId: payload.userId,
                name: c.biomarkerName,
                value: c.value,
                unit: c.unit,
                referenceRangeMin: c.referenceRangeMin,
                referenceRangeMax: c.referenceRangeMax,
                testDate: dto.collectionDate,
                labName: dto.labName,
                notes: c.notes ?? "Extracted from verified lab panel"
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
}
