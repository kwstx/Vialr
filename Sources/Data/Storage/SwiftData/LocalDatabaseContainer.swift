import Foundation
import Domain

#if canImport(SwiftData)
import SwiftData

/// Thread-safe SwiftData database container manager for Vialr.
/// Provides configuration for production persistent SQLite storage, in-memory testing, and model context isolation.
public final class LocalDatabaseContainer: @unchecked Sendable {
    public static let shared = LocalDatabaseContainer()

    public let container: ModelContainer?
    public let isInMemory: Bool

    public init(inMemory: Bool = false) {
        self.isInMemory = inMemory
        do {
            let schema = Schema([
                SDDoseEvent.self,
                SDCompound.self,
                SDProtocol.self,
                SDVial.self,
                SDSupplyItem.self,
                SDBiomarker.self,
                SDMeasurement.self,
                SDSyncQueueItem.self
            ])

            let configuration: ModelConfiguration
            if inMemory {
                configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            } else {
                let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
                let dbURL = appSupportURL.appendingPathComponent("Vialr").appendingPathComponent("vialr_local.sqlite")
                
                // Ensure parent directory exists
                try? FileManager.default.createDirectory(at: dbURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                configuration = ModelConfiguration(schema: schema, url: dbURL)
            }

            self.container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("[LocalDatabaseContainer] Warning: Failed to initialize SwiftData ModelContainer: \(error). Falling back to in-memory store.")
            self.container = try? ModelContainer(for: Schema([
                SDDoseEvent.self,
                SDCompound.self,
                SDProtocol.self,
                SDVial.self,
                SDSupplyItem.self,
                SDBiomarker.self,
                SDMeasurement.self,
                SDSyncQueueItem.self
            ]), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        }
    }

    /// Creates a dedicated background ModelContext for thread-safe worker execution.
    @MainActor
    public var mainContext: ModelContext? {
        container?.mainContext
    }
}
#endif
