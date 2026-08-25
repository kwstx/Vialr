import Vapor
import Fluent

public struct ReportsController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let reportsGroup = routes.grouped("reports")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        reportsGroup.post("generate", use: generateReport)
    }

    public func generateReport(req: Request) async throws -> ClinicianReportResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let requestBody = try req.content.decode(ClinicianReportRequestDTO.self)

        // 1. Fetch active protocols
        let protocols = try await ProtocolEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .filter(\.$status == "active")
            .with(\.$compound)
            .all()

        // 2. Fetch doses in date range
        let doses = try await DoseLogEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .filter(\.$scheduledDate >= requestBody.dateRangeStart)
            .filter(\.$scheduledDate <= requestBody.dateRangeEnd)
            .all()

        let takenDoses = doses.filter { $0.status == "taken" }
        let adherence = doses.isEmpty ? 100.0 : (Double(takenDoses.count) / Double(doses.count)) * 100.0

        // 3. Fetch biomarkers in date range
        let biomarkers = try await BiomarkerEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .filter(\.$testDate >= requestBody.dateRangeStart)
            .filter(\.$testDate <= requestBody.dateRangeEnd)
            .all()

        let compoundNames = protocols.map { $0.compound.name }.joined(separator: ", ")
        let summary = "Clinician summary for \(requestBody.patientName) prepared for \(requestBody.clinicianName) (\(requestBody.practiceOrClinic)). Active protocols (\(protocols.count)): \(compoundNames.isEmpty ? "None" : compoundNames). Dosing adherence: \(String(format: "%.1f", adherence))% across \(doses.count) scheduled doses."

        return ClinicianReportResponseDTO(
            generatedAt: Date(),
            patientName: requestBody.patientName,
            activeProtocolsCount: protocols.count,
            adherenceRate: adherence,
            dosesLoggedCount: takenDoses.count,
            biomarkersCount: biomarkers.count,
            summaryText: summary
        )
    }
}
