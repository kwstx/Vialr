import Vapor

public func routes(_ app: Application) throws {
    // Health check root
    app.get { req async in
        ["status": "ok", "service": "Vialr API", "version": "1.0.0"]
    }

    app.get("health") { req async in
        ["status": "healthy", "timestamp": "\(Date())"]
    }

    // Versioned API grouping: /api/v1
    let apiV1 = app.grouped("api", "v1")

    // 1. Authentication
    try apiV1.register(collection: AuthController())

    // 2. Users & Preferences
    try apiV1.register(collection: UsersController())

    // 3. Compounds
    try apiV1.register(collection: CompoundsController())

    // 4. Protocols & Revisions
    try apiV1.register(collection: ProtocolsController())

    // 5. Doses & Batch Logging
    try apiV1.register(collection: DoseLogsController())

    // 6. Inventory: Vials & Ancillary Supplies
    try apiV1.register(collection: VialsController())
    try apiV1.register(collection: SuppliesController())

    // 7. Reconstitution Records
    try apiV1.register(collection: ReconstitutionController())

    // 8. Injection Sites & Rotation Mapping
    try apiV1.register(collection: InjectionSitesController())

    // 9. Measurements, Vitals & Subjective Scores
    try apiV1.register(collection: MeasurementsController())

    // 10. Laboratory Panels & Biomarkers
    try apiV1.register(collection: LabPanelsController())
    try apiV1.register(collection: BiomarkersController())

    // 11. Documents & Encrypted Object Storage Vault
    try apiV1.register(collection: StoredFilesController())

    // 12. Reports & Clinical Summaries
    try apiV1.register(collection: ReportsController())

    // 13. Push Notifications & APNs Device Tokens
    try apiV1.register(collection: NotificationsController())

    // 14. Delta Synchronization & Outbox Conflict Engine
    try apiV1.register(collection: SyncController())

    // 15. Server-Side Calculations & Verification Engine
    try apiV1.register(collection: CalculationController())
}
