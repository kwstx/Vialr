import Vapor
import Fluent
import Domain

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

        // 4. Render Report Document Data for Encrypted Object Storage Archive
        let generatedDate = Date()
        let reportJsonPayload: [String: Any] = [
            "reportType": "Clinician Long-Form Report",
            "patientName": requestBody.patientName,
            "clinicianName": requestBody.clinicianName,
            "practiceOrClinic": requestBody.practiceOrClinic,
            "dateRangeStart": requestBody.dateRangeStart.ISO8601Format(),
            "dateRangeEnd": requestBody.dateRangeEnd.ISO8601Format(),
            "generatedAt": generatedDate.ISO8601Format(),
            "adherenceRate": adherence,
            "totalDosesLogged": takenDoses.count,
            "activeProtocols": protocols.map { ["name": $0.name, "compound": $0.compound.name, "frequency": $0.scheduleFrequency] },
            "biomarkers": biomarkers.map { ["name": $0.name, "value": $0.value, "unit": $0.unit, "date": $0.testDate.ISO8601Format()] },
            "clinicalSummary": summary
        ]

        var storedFileId: UUID? = nil
        var downloadUrl: String? = nil

        if let rawReportData = try? JSONSerialization.data(withJSONObject: reportJsonPayload, options: [.prettyPrinted, .sortedKeys]) {
            let fileId = UUID()
            let fileName = "clinician_report_\(fileId.uuidString.prefix(8)).json"
            
            // Upload ciphertext to Object Storage
            if let uploadResult = try? await req.encryptedStorage.upload(
                userId: payload.userId,
                category: .exportedReport,
                fileId: fileId,
                fileName: fileName,
                rawData: rawReportData,
                contentType: "application/json"
            ) {
                // Save metadata row to PostgreSQL
                let fileEntity = StoredFileEntity(
                    id: fileId,
                    userId: payload.userId,
                    category: .exportedReport,
                    fileName: fileName,
                    contentType: "application/json",
                    byteSize: uploadResult.byteSize,
                    sha256Checksum: uploadResult.sha256,
                    storageBucket: uploadResult.bucket,
                    storageKey: uploadResult.storageKey,
                    encryption: uploadResult.encryption
                )
                try? await fileEntity.save(on: req.db)
                storedFileId = fileId
                downloadUrl = "/api/v1/files/\(fileId.uuidString)/download"
            }
        }

        return ClinicianReportResponseDTO(
            generatedAt: generatedDate,
            patientName: requestBody.patientName,
            activeProtocolsCount: protocols.count,
            adherenceRate: adherence,
            dosesLoggedCount: takenDoses.count,
            biomarkersCount: biomarkers.count,
            summaryText: summary,
            storedFileId: storedFileId,
            downloadUrl: downloadUrl
        )
    }
}
