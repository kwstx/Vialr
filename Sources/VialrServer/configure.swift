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

    // 5. Configure Encrypted Object Storage Subsystem
    app.routes.defaultMaxBodySize = "55mb"
    let storageBackendType = Environment.get("STORAGE_BACKEND") ?? "filesystem"
    let vaultKeySecret = Environment.get("VAULT_ENCRYPTION_KEY") ?? "vialr-master-vault-encryption-secret-key-32-chars"
    let storageBucket = Environment.get("STORAGE_BUCKET") ?? Environment.get("S3_BUCKET") ?? "vialr-secure-vault"
    let encryptionService = StorageEncryptionService(keyId: "vialr-vault-primary", secretKeyString: vaultKeySecret)

    let storageBackend: ObjectStorageProtocol
    if storageBackendType.lowercased() == "s3",
       let accessKey = Environment.get("S3_ACCESS_KEY"),
       let secretKey = Environment.get("S3_SECRET_KEY") {
        let endpointString = Environment.get("S3_ENDPOINT") ?? "https://s3.amazonaws.com"
        let endpointURL = URL(string: endpointString) ?? URL(string: "https://s3.amazonaws.com")!
        let region = Environment.get("S3_REGION") ?? "us-east-1"
        storageBackend = S3CompatibleObjectStorageService(
            endpointURL: endpointURL,
            region: region,
            accessKey: accessKey,
            secretKey: secretKey,
            forcePathStyle: Environment.get("S3_FORCE_PATH_STYLE").flatMap(Bool.init) ?? true
        )
    } else {
        let localDirString = Environment.get("STORAGE_LOCAL_PATH") ?? (NSTemporaryDirectory() + "vialr-object-store")
        let localDirURL = URL(fileURLWithPath: localDirString)
        let baseURL = URL(string: "http://\(app.http.server.configuration.hostname):\(app.http.server.configuration.port)")!
        storageBackend = FileSystemObjectStorageService(rootDirectoryURL: localDirURL, baseURL: baseURL)
    }

    app.encryptedStorage = EncryptedObjectStorageService(
        bucket: storageBucket,
        storageBackend: storageBackend,
        encryptionService: encryptionService
    )

    // 6. Register Migrations
    app.migrations.add(CreateUsersMigration())
    app.migrations.add(CreateCompoundsMigration())
    app.migrations.add(CreateProtocolsMigration())
    app.migrations.add(CreateProtocolRevisionsMigration())
    app.migrations.add(CreateDoseLogsMigration())
    app.migrations.add(CreateVialsMigration())
    app.migrations.add(CreateBiomarkersMigration())
    app.migrations.add(CreateLabPanelsMigration())
    app.migrations.add(CreateSymptomLogsMigration())
    app.migrations.add(CreateSyncChangesMigration())
    app.migrations.add(CreateSyncConflictsMigration())
    app.migrations.add(CreateStoredFilesMigration())
    app.migrations.add(CreateReconstitutionRecordsMigration())
    app.migrations.add(CreateSupplyItemsMigration())
    app.migrations.add(CreateInjectionSiteEventsMigration())
    app.migrations.add(CreateMeasurementsMigration())
    app.migrations.add(CreateNotificationsAndTokensMigration())

    // Auto-migrate if flag is passed
    if app.environment != .testing {
        try await app.autoMigrate()
    }

    // 7. Register Routes
    try routes(app)
}
