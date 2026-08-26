import Vapor
import Logging

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        
        let logLevelString = Environment.get("LOG_LEVEL")?.lowercased() ?? (env == .production ? "info" : "debug")
        let logLevel = Logger.Level(rawValue: logLevelString) ?? .info
        let serviceName = Environment.get("SERVICE_NAME") ?? "vialr-api"
        let environmentName = env.name

        LoggingSystem.bootstrap { label in
            StructuredLogHandler(
                label: label,
                logLevel: logLevel,
                service: serviceName,
                environment: environmentName
            )
        }

        let app = try await Application.make(env)

        do {
            try await configure(app)
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }

        try await app.asyncShutdown()
    }
}
