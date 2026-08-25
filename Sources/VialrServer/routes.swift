import Vapor

public func routes(_ app: Application) throws {
    // Health check root
    app.get { req async in
        ["status": "ok", "service": "Vialr API", "version": "1.0.0"]
    }

    app.get("health") { req async in
        ["status": "healthy", "timestamp": "\(Date())"]
    }

    // API v1 grouping
    let apiV1 = app.grouped("api", "v1")

    try apiV1.register(collection: AuthController())
    try apiV1.register(collection: ProtocolsController())
    try apiV1.register(collection: DoseLogsController())
    try apiV1.register(collection: VialsController())
    try apiV1.register(collection: BiomarkersController())
    try apiV1.register(collection: SyncController())
    try apiV1.register(collection: ReportsController())
}
