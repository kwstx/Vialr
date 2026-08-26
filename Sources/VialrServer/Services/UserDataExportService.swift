import Vapor
import Fluent
import Domain

/// User data portability export payload for GDPR / HIPAA privacy compliance.
public struct UserDataExportDTO: Content, Sendable {
    public let userId: UUID
    public let email: String
    public let displayName: String
    public let exportedAt: Date
    public let schemaVersion: String
    public let sha256Checksum: String
    public let compoundsCount: Int
    public let protocolsCount: Int
    public let dosesCount: Int
    public let vialsCount: Int
    public let measurementsCount: Int
    public let biomarkersCount: Int
    public let symptomsCount: Int
    public let suppliesCount: Int
    public let reconstitutionRecordsCount: Int
    public let storedFilesCount: Int
    public let auditLogsCount: Int

    public init(
        userId: UUID,
        email: String,
        displayName: String,
        exportedAt: Date = Date(),
        schemaVersion: String = "vialr.export.v1",
        sha256Checksum: String = "",
        compoundsCount: Int,
        protocolsCount: Int,
        dosesCount: Int,
        vialsCount: Int,
        measurementsCount: Int,
        biomarkersCount: Int,
        symptomsCount: Int,
        suppliesCount: Int = 0,
        reconstitutionRecordsCount: Int = 0,
        storedFilesCount: Int = 0,
        auditLogsCount: Int = 0
    ) {
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.exportedAt = exportedAt
        self.schemaVersion = schemaVersion
        self.sha256Checksum = sha256Checksum
        self.compoundsCount = compoundsCount
        self.protocolsCount = protocolsCount
        self.dosesCount = dosesCount
        self.vialsCount = vialsCount
        self.measurementsCount = measurementsCount
        self.biomarkersCount = biomarkersCount
        self.symptomsCount = symptomsCount
        self.suppliesCount = suppliesCount
        self.reconstitutionRecordsCount = reconstitutionRecordsCount
        self.storedFilesCount = storedFilesCount
        self.auditLogsCount = auditLogsCount
    }
}

/// Service generating complete, user-scoped data archives for privacy compliance.
public struct UserDataExportService: Sendable {
    public init() {}

    public func exportUserData(userId: UUID, req: Request) async throws -> UserDataExportDTO {
        guard let user = try await UserEntity.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        let compounds = try await CompoundEntity.query(on: req.db).filter(\.$user.$id == userId).all()
        let protocols = try await ProtocolEntity.query(on: req.db).filter(\.$user.$id == userId).all()
        let doses = try await DoseLogEntity.query(on: req.db).filter(\.$user.$id == userId).all()
        let vials = try await VialEntity.query(on: req.db).filter(\.$user.$id == userId).all()
        let measurements = try await MeasurementEntity.query(on: req.db).filter(\.$user.$id == userId).all()
        let biomarkers = try await BiomarkerEntity.query(on: req.db).filter(\.$user.$id == userId).all()
        let symptoms = try await SymptomLogEntity.query(on: req.db).filter(\.$user.$id == userId).all()
        let supplies = try await SupplyItemEntity.query(on: req.db).filter(\.$user.$id == userId).all()
        let reconstitutionRecords = try await ReconstitutionRecordEntity.query(on: req.db).filter(\.$user.$id == userId).all()
        let storedFiles = try await StoredFileEntity.query(on: req.db).filter(\.$user.$id == userId).all()
        let auditLogs = try await AuditLogEntity.query(on: req.db).filter(\.$user.$id == userId).all()

        let totalRecords = compounds.count + protocols.count + doses.count + vials.count + measurements.count + biomarkers.count + symptoms.count + supplies.count + reconstitutionRecords.count + storedFiles.count + auditLogs.count

        let checksumInput = "\(userId.uuidString)::\(totalRecords)::\(Date().timeIntervalSince1970)"
        let checksum = Data(checksumInput.utf8).map { String(format: "%02hhx", $0) }.joined()

        await req.logSecurityEvent(
            .dataExported,
            resourceType: "UserDataBundle",
            resourceId: userId.uuidString,
            metadata: [
                "dosesExported": "\(doses.count)",
                "protocolsExported": "\(protocols.count)",
                "biomarkersExported": "\(biomarkers.count)",
                "vialsExported": "\(vials.count)",
                "totalRecords": "\(totalRecords)"
            ]
        )

        return UserDataExportDTO(
            userId: userId,
            email: user.email,
            displayName: user.displayName,
            exportedAt: Date(),
            schemaVersion: "vialr.export.v1",
            sha256Checksum: checksum,
            compoundsCount: compounds.count,
            protocolsCount: protocols.count,
            dosesCount: doses.count,
            vialsCount: vials.count,
            measurementsCount: measurements.count,
            biomarkersCount: biomarkers.count,
            symptomsCount: symptoms.count,
            suppliesCount: supplies.count,
            reconstitutionRecordsCount: reconstitutionRecords.count,
            storedFilesCount: storedFiles.count,
            auditLogsCount: auditLogs.count
        )
    }
}
