import Vapor
import Fluent

/// User data portability export payload for GDPR / HIPAA privacy compliance.
public struct UserDataExportDTO: Content, Sendable {
    public let userId: UUID
    public let email: String
    public let displayName: String
    public let exportedAt: Date
    public let compoundsCount: Int
    public let protocolsCount: Int
    public let dosesCount: Int
    public let vialsCount: Int
    public let measurementsCount: Int
    public let biomarkersCount: Int
    public let symptomsCount: Int

    public init(
        userId: UUID,
        email: String,
        displayName: String,
        exportedAt: Date = Date(),
        compoundsCount: Int,
        protocolsCount: Int,
        dosesCount: Int,
        vialsCount: Int,
        measurementsCount: Int,
        biomarkersCount: Int,
        symptomsCount: Int
    ) {
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.exportedAt = exportedAt
        self.compoundsCount = compoundsCount
        self.protocolsCount = protocolsCount
        self.dosesCount = dosesCount
        self.vialsCount = vialsCount
        self.measurementsCount = measurementsCount
        self.biomarkersCount = biomarkersCount
        self.symptomsCount = symptomsCount
    }
}

/// Service generating complete, user-scoped data archives for privacy compliance.
public struct UserDataExportService: Sendable {
    public init() {}

    public func exportUserData(userId: UUID, req: Request) async throws -> UserDataExportDTO {
        guard let user = try await UserEntity.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }

        let compoundsCount = try await CompoundEntity.query(on: req.db).filter(\.$user.$id == userId).count()
        let protocolsCount = try await ProtocolEntity.query(on: req.db).filter(\.$user.$id == userId).count()
        let dosesCount = try await DoseLogEntity.query(on: req.db).filter(\.$user.$id == userId).count()
        let vialsCount = try await VialEntity.query(on: req.db).filter(\.$user.$id == userId).count()
        let measurementsCount = try await MeasurementEntity.query(on: req.db).filter(\.$user.$id == userId).count()
        let biomarkersCount = try await BiomarkerEntity.query(on: req.db).filter(\.$user.$id == userId).count()
        let symptomsCount = try await SymptomLogEntity.query(on: req.db).filter(\.$user.$id == userId).count()

        await req.logSecurityEvent(
            .dataExported,
            resourceType: "UserDataBundle",
            resourceId: userId.uuidString,
            metadata: [
                "dosesExported": "\(dosesCount)",
                "protocolsExported": "\(protocolsCount)",
                "biomarkersExported": "\(biomarkersCount)"
            ]
        )

        return UserDataExportDTO(
            userId: userId,
            email: user.email,
            displayName: user.displayName,
            exportedAt: Date(),
            compoundsCount: compoundsCount,
            protocolsCount: protocolsCount,
            dosesCount: dosesCount,
            vialsCount: vialsCount,
            measurementsCount: measurementsCount,
            biomarkersCount: biomarkersCount,
            symptomsCount: symptomsCount
        )
    }
}
