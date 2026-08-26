import XCTest
@testable import Data
@testable import Domain

final class DataPrivacyCoordinatorTests: XCTestCase {

    override func setUp() async throws {
        await LocalStore.shared.clearAllData()
    }

    func testDataExportBundleGenerationAndChecksum() async throws {
        let store = LocalStore.shared
        let user = MockDataFactory().defaultUser
        await store.saveCurrentUser(user)

        let compound = MockDataFactory().compounds[0]
        await store.saveCompound(compound)

        let coordinator = DataPrivacyCoordinator.shared
        let bundle = try await coordinator.generateUserDataExportBundle()

        XCTAssertEqual(bundle.manifest.schemaVersion, "vialr.export.v1")
        XCTAssertFalse(bundle.manifest.sha256Checksum.isEmpty)
        XCTAssertGreaterThanOrEqual(bundle.manifest.totalRecordCount, 1)
        XCTAssertEqual(bundle.accountProfile.email, user.accountInfo.email)
    }

    func testExportUserDataAsJSON() async throws {
        let store = LocalStore.shared
        let user = MockDataFactory().defaultUser
        await store.saveCurrentUser(user)

        let coordinator = DataPrivacyCoordinator.shared
        let jsonData = try await coordinator.exportUserDataAsJSON(prettyPrinted: true)

        XCTAssertFalse(jsonData.isEmpty)
        let jsonString = String(data: jsonData, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("vialr.export.v1"))
        XCTAssertTrue(jsonString!.contains("manifest"))
    }

    func testExportUserDataAsCSV() async throws {
        let store = LocalStore.shared
        let user = MockDataFactory().defaultUser
        await store.saveCurrentUser(user)

        let coordinator = DataPrivacyCoordinator.shared
        let csvString = try await coordinator.exportUserDataAsCSV()

        XCTAssertTrue(csvString.contains("Vialr Personal Protocol & Health Data Export"))
        XCTAssertTrue(csvString.contains("=== DOSE LOGS ==="))
        XCTAssertTrue(csvString.contains("=== MEASUREMENTS & VITALS ==="))
        XCTAssertTrue(csvString.contains("=== LABORATORY BIOMARKERS ==="))
        XCTAssertTrue(csvString.contains("=== VIAL & SUPPLY INVENTORY ==="))
    }

    func testAtomicLocalDataErasure() async throws {
        let store = LocalStore.shared
        let user = MockDataFactory().defaultUser
        await store.saveCurrentUser(user)
        await store.saveCompound(MockDataFactory().compounds[0])

        let coordinator = DataPrivacyCoordinator.shared
        let manifest = try await coordinator.eraseAllLocalData()

        XCTAssertTrue(manifest.localStoreWiped)
        XCTAssertTrue(manifest.keychainCredentialsCleared)
        XCTAssertTrue(manifest.localNotificationsCancelled)

        // Verify LocalStore is completely empty
        let currentUser = await store.getCurrentUser()
        XCTAssertNil(currentUser)
        let compounds = await store.getAllCompounds()
        XCTAssertTrue(compounds.isEmpty)
    }
}
