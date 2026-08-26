import Vapor
import Fluent
import Domain

public struct ReportsController: RouteCollection {
    private let generatorService = ClinicianReportGeneratorService()

    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let reportsGroup = routes.grouped("reports")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        reportsGroup.post("generate", use: generateReport)
        reportsGroup.post("pdf", use: generatePdfReport)
    }

    /// Generates structured clinician report with summary, metrics, and encrypted stored file download URL.
    public func generateReport(req: Request) async throws -> ClinicianReportResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let requestBody = try req.content.decode(ClinicianReportRequestDTO.self)

        let result = try await generatorService.generateReport(
            req: req,
            userId: payload.userId,
            request: requestBody
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let reportJsonString = (try? encoder.encode(result.report)).flatMap { String(data: $0, encoding: .utf8) }

        return ClinicianReportResponseDTO(
            id: result.report.id,
            generatedAt: result.report.generatedDate,
            patientName: result.report.patientIdentifier,
            dateRangeStart: result.report.dateRangeStart,
            dateRangeEnd: result.report.dateRangeEnd,
            activeProtocolsCount: result.report.activeProtocols.count,
            adherenceRate: result.report.adherencePercentage,
            dosesLoggedCount: result.report.totalDosesAdministered,
            biomarkersCount: result.report.labPanels.reduce(0) { $0 + $1.results.count } + result.report.latestBiomarkers.count,
            abnormalBiomarkersCount: result.report.abnormalBiomarkersCount,
            measurementsCount: result.report.measurementSummaries.count,
            symptomsCount: result.report.symptomSummary?.totalLogsCount ?? 0,
            totalLedgerItemsCount: result.report.totalLedgerCount,
            summaryText: result.report.clinicalNotes,
            storedFileId: result.storedFileId,
            downloadUrl: result.downloadUrl,
            reportDataJson: reportJsonString
        )
    }

    /// Directly renders and streams the PDF document binary.
    public func generatePdfReport(req: Request) async throws -> Response {
        let payload = try req.auth.require(UserPayload.self)
        let requestBody = try req.content.decode(ClinicianReportRequestDTO.self)

        let result = try await generatorService.generateReport(
            req: req,
            userId: payload.userId,
            request: requestBody
        )

        var headers = HTTPHeaders()
        headers.contentType = HTTPMediaType(type: "application", subType: "pdf")
        headers.add(name: .contentDisposition, value: "attachment; filename=\"clinician_report.pdf\"")

        return Response(status: .ok, headers: headers, body: .init(data: result.pdfData))
    }
}
