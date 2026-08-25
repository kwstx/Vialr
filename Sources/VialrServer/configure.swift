import Vapor
import Fluent
import FluentPostgresDriver
import JWT

public func configure(_ app: Application) async throws {
    // 1. Configure Port & Host
    let port = Environment.get("PORT").flatMap(Int.init) ?? 8080
    app.http.server.configuration.port = port
    app.http.server.configuration.hostname = Environment.get("HOST") ?? "0.0.0.0"

    // 2. Configure CORS Middleware
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)

    // 3. Configure JWT Signer
    let jwtSecret = Environment.get("JWT_SECRET") ?? "vialr-secret-jwt-key-minimum-32-chars-long-2026"
    app.jwt.signers.use(.hs256(key: jwtSecret))

    // 4. Configure PostgreSQL Database with Fluent
    if let databaseURL = Environment.get("DATABASE_URL"), let postgresConfig = SQLPostgresConfiguration(url: databaseURL) {
        app.databases.use(.postgres(configuration: postgresConfig), as: .psql)
    } else {
        let hostname = Environment.get("DATABASE_HOST") ?? "localhost"
        let port = Environment.get("DATABASE_PORT").flatMap(Int.init) ?? SQLPostgresConfiguration.ianaPortNumber
        let username = Environment.get("DATABASE_USERNAME") ?? "postgres"
        let password = Environment.get("DATABASE_PASSWORD") ?? "postgres"
        let database = Environment.get("DATABASE_NAME") ?? "vialr"

        app.databases.use(.postgres(
            configuration: .init(
                hostname: hostname,
                port: port,
                username: username,
                password: password,
                database: database,
                tls: .prefer(try .init(configuration: .clientDefault))
            )
        ), as: .psql)
    }

    // 5. Register Migrations
    app.migrations.add(CreateUsersMigration())
    app.migrations.add(CreateCompoundsMigration())
    app.migrations.add(CreateProtocolsMigration())
    app.migrations.add(CreateDoseLogsMigration())
    app.migrations.add(CreateVialsMigration())
    app.migrations.add(CreateBiomarkersMigration())
    app.migrations.add(CreateSymptomLogsMigration())
    app.migrations.add(CreateSyncChangesMigration())

    // Auto-migrate if flag is passed
    if app.environment != .testing {
        try await app.autoMigrate()
    }

    // 6. Register Routes
    try routes(app)
}
