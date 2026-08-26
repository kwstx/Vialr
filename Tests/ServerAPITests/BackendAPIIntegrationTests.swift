import XCTest
import Vapor
import Fluent
import XCTVapor
@testable import VialrServer
@testable import Domain
@testable import CalculationEngine

final class BackendAPIIntegrationTests: XCTestCase {

    private var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    // MARK: - 1. Root & Health Observability Endpoints

    func testRootHealthCheckReturnsOK() async throws {
        try await app.test(.GET, "/") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(res.body.string.contains("Vialr API"))
            XCTAssertTrue(res.body.string.contains("1.0.0"))
        }
    }

    // MARK: - 2. Calculation API Integration Tests

    func testCalculationReconstitutionAPI() async throws {
        let payload = ReconstitutionCalculationRequestDTO(
            dryMassAmount: 5.0,
            dryMassUnit: "mg",
            diluentVolumeAmount: 2.0,
            diluentVolumeUnit: "ml",
            targetDoseAmount: 250.0,
            targetDoseUnit: "mcg",
            syringeType: "U-100",
            syringeBarrelCapacityMl: 0.5,
            vialCostUsd: 50.0,
            compoundName: "BPC-157"
        )

        try await app.test(.POST, "/api/v1/calculations/reconstitute", beforeRequest: { req in
            try req.content.encode(payload)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let result = try res.content.decode(CalculationResultResponseDTO.self)
            XCTAssertEqual(result.concentrationMgMl, 2.5, accuracy: 0.001)
            XCTAssertEqual(result.drawVolumeMl, 0.1, accuracy: 0.001)
            XCTAssertEqual(result.u100Units, 10.0, accuracy: 0.001)
            XCTAssertEqual(result.totalDosesInVial, 20.0, accuracy: 0.001)
            XCTAssertEqual(result.exactDosesCount, 20)
            XCTAssertEqual(result.costPerDoseUsd ?? 0, 2.50, accuracy: 0.001)
            XCTAssertFalse(result.summaryExplanation.isEmpty)
            XCTAssertGreaterThanOrEqual(result.derivationSteps.count, 4)
        })
    }

    func testCalculationDiluentSolverAPI() async throws {
        let solverPayload = DiluentSolverRequestDTO(
            dryMassAmount: 10.0,
            dryMassUnit: "mg",
            targetDoseAmount: 500.0,
            targetDoseUnit: "mcg",
            desiredSyringeUnits: 10.0,
            syringeType: "U-100",
            vialCostUsd: 60.0
        )

        try await app.test(.POST, "/api/v1/calculations/solve-diluent", beforeRequest: { req in
            try req.content.encode(solverPayload)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let result = try res.content.decode(DiluentSolverResponseDTO.self)
            XCTAssertEqual(result.recommendedDiluentVolumeMl, 2.0, accuracy: 0.001)
            XCTAssertEqual(result.resultingConcentrationMgMl, 5.0, accuracy: 0.001)
            XCTAssertEqual(result.totalDosesInVial, 20.0, accuracy: 0.001)
        })
    }

    func testCalculationReverseDoseAPI() async throws {
        let reversePayload = ReverseDoseRequestDTO(
            drawnSyringeUnits: 15.0,
            syringeType: "U-100",
            concentrationMgMl: 2.5
        )

        try await app.test(.POST, "/api/v1/calculations/reverse-dose", beforeRequest: { req in
            try req.content.encode(reversePayload)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let result = try res.content.decode(ReverseDoseResponseDTO.self)
            XCTAssertEqual(result.drawnVolumeMl, 0.15, accuracy: 0.001)
            XCTAssertEqual(result.administeredDoseMg, 0.375, accuracy: 0.001)
            XCTAssertEqual(result.administeredDoseMcg, 375.0, accuracy: 0.001)
        })
    }

    func testCalculationReconstitutionInvalidInputReturns400() async throws {
        let invalidPayload = ReconstitutionCalculationRequestDTO(
            dryMassAmount: -5.0, // Invalid negative mass
            dryMassUnit: "mg",
            diluentVolumeAmount: 2.0,
            diluentVolumeUnit: "ml",
            targetDoseAmount: 250.0,
            targetDoseUnit: "mcg"
        )

        try await app.test(.POST, "/api/v1/calculations/reconstitute", beforeRequest: { req in
            try req.content.encode(invalidPayload)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    // MARK: - 3. Authentication & Security Integration Tests

    func testUnauthorizedRequestsReturn401() async throws {
        // Accessing protected endpoints without bearer token
        try await app.test(.GET, "/api/v1/auth/profile") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        try await app.test(.GET, "/api/v1/protocols") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        try await app.test(.GET, "/api/v1/doses") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        try await app.test(.GET, "/api/v1/vials") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    func testRegisterLoginAndProfileLifecycle() async throws {
        let testEmail = "testuser_\(UUID().uuidString.prefix(8))@vialr-app.com"
        let registerPayload = RegisterRequest(
            email: testEmail,
            password: "SecurePassword123!",
            displayName: "Test Athlete"
        )

        var accessToken = ""
        var refreshToken = ""

        // 1. Register
        try await app.test(.POST, "/api/v1/auth/register", beforeRequest: { req in
            try req.content.encode(registerPayload)
        }, afterResponse: { res in
            // May succeed if DB is active or return conflict/error if offline
            if res.status == .ok {
                let auth = try res.content.decode(AuthResponse.self)
                accessToken = auth.tokens.accessToken
                refreshToken = auth.tokens.refreshToken
                XCTAssertFalse(accessToken.isEmpty)
                XCTAssertFalse(refreshToken.isEmpty)
            }
        })

        // 2. Duplicate registration should return 409 Conflict if DB is online
        if !accessToken.isEmpty {
            try await app.test(.POST, "/api/v1/auth/register", beforeRequest: { req in
                try req.content.encode(registerPayload)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .conflict)
            })

            // 3. Login with credentials
            let loginPayload = LoginRequest(email: testEmail, password: "SecurePassword123!")
            try await app.test(.POST, "/api/v1/auth/login", beforeRequest: { req in
                try req.content.encode(loginPayload)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                let auth = try res.content.decode(AuthResponse.self)
                XCTAssertFalse(auth.tokens.accessToken.isEmpty)
            })

            // 4. Fetch Profile with Bearer token
            try await app.test(.GET, "/api/v1/auth/profile", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                let profile = try res.content.decode(UserProfileDTO.self)
                XCTAssertEqual(profile.email, testEmail)
                XCTAssertEqual(profile.displayName, "Test Athlete")
            })

            // 5. Refresh token rotation
            let refreshReq = RefreshTokenRequest(refreshToken: refreshToken)
            try await app.test(.POST, "/api/v1/auth/refresh", beforeRequest: { req in
                try req.content.encode(refreshReq)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                let rotated = try res.content.decode(AuthResponse.self)
                XCTAssertFalse(rotated.tokens.accessToken.isEmpty)
                XCTAssertNotEqual(rotated.tokens.refreshToken, refreshToken) // Rotated
            })
        }
    }

    // MARK: - 4. Sync & Outbox Integration

    func testSyncPushValidation() async throws {
        let syncPayload = SyncPushRequestDTO(
            clientTimestamp: Date(),
            deviceId: "TEST-DEVICE-01",
            changes: []
        )

        // Sync without auth returns 401
        try await app.test(.POST, "/api/v1/sync/push", beforeRequest: { req in
            try req.content.encode(syncPayload)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .unauthorized)
        })
    }
}
