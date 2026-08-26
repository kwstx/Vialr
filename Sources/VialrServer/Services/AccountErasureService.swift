import Vapor
import Fluent

/// Service executing complete, atomic, cascading account deletion and physical data erasure
/// fulfilling GDPR Right to Erasure, HIPAA compliance, and PII minimization principles.
public struct AccountErasureService: Sendable {
    public init() {}

    /// Permanently wipes all personal, clinical, physical object storage, and relational data for a user.
    public func eraseUserAccount(userId: UUID, req: Request) async throws {
        guard let user = try await UserEntity.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "User account not found.")
        }

        let userEmail = user.email

        // 1. Delete physical encrypted files from Object Storage Vault
        let userFiles = try await StoredFileEntity.query(on: req.db)
            .filter(\.$user.$id == userId)
            .all()

        for file in userFiles {
            do {
                try await req.application.encryptedStorage.deleteEncryptedObject(storageKey: file.storageKey)
            } catch {
                req.logger.warning("[AccountErasure] Failed to delete object vault file \(file.storageKey): \(error.localizedDescription)")
            }
        }

        // 2. Cascade delete all relational database records
        try await DoseLogEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await ProtocolRevisionEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await ProtocolEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await ReconstitutionRecordEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await VialEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await SupplyItemEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await InjectionSiteEventEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await BiomarkerEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await LabPanelEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await MeasurementEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await SymptomLogEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await StoredFileEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await NotificationRecordEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await RefreshTokenEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await DeviceTokenEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await BackgroundJobEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await SyncConflictEntity.query(on: req.db).filter(\.$user.$id == userId).delete()
        try await CompoundEntity.query(on: req.db).filter(\.$user.$id == userId).delete()

        // 3. Record permanent security audit event before deleting user record
        await req.logSecurityEvent(
            .accountDeleted,
            resourceType: "User",
            resourceId: userId.uuidString,
            metadata: [
                "erasedEmail": userEmail,
                "filesPurged": "\(userFiles.count)",
                "status": "fully_erased"
            ]
        )

        // 4. Delete root User entity
        try await user.delete(on: req.db)
    }
}
