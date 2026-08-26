import XCTest
import Vapor
import Fluent
import XCTVapor
import JWT
@testable import VialrServer
@testable import Domain
@testable import CalculationEngine

final class BackendSecurityModelTests: XCTestCase {

    private var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    // MARK: - Helper Methods

    private func registerUser(email: String, name: String = "Test User", role: String = "user") async throws -> (token: String, user: UserEntity) {
        let passwordHash = try app.password.hash("SecurePassword123!")
        let user = UserEntity(
            email: email.lowercased(),
            passwordHash: passwordHash,
            displayName: name,
            role: role
        )
        try await user.save(on: app.db)

        let payload = UserPayload(userId: try user.requireID(), email: user.email, role: user.role)
        let token = try app.jwt.sign(payload)
        return (token, user)
    }

    // MARK: - 1. Mandatory Authentication Across All API Endpoints

    func testUnauthenticatedRequestsToProtectedAPIsReturn401() async throws {
        // Protected Compound endpoints
        try await app.test(.GET, "/api/v1/compounds") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        // Protected Protocol endpoints
        try await app.test(.GET, "/api/v1/protocols") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        // Protected Dose logging endpoints
        try await app.test(.GET, "/api/v1/doses") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        // Protected Calculation engine endpoints
        try await app.test(.POST, "/api/v1/calculations/reconstitute") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        // Protected User Profile endpoints
        try await app.test(.GET, "/api/v1/users/me") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        // Protected Admin endpoints
        try await app.test(.GET, "/api/v1/admin/users") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        // Protected Deep Observability endpoints
        try await app.test(.GET, "/api/v1/observability/status") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    func testPublicEndpointsDoNotRequireAuthentication() async throws {
        // Root health
        try await app.test(.GET, "/") { res in
            XCTAssertEqual(res.status, .ok)
        }

        // Liveness probe
        try await app.test(.GET, "/health") { res in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testInvalidOrTamperedJWTIsRejectedWith401() async throws {
        let tamperedToken = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.invalidpayload.invalidsignature"
        try await app.test(.GET, "/api/v1/users/me", beforeRequest: { req in
            req.headers.replaceOrAdd(name: .authorization, value: tamperedToken)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .unauthorized)
        })
    }

    // MARK: - 2. Strict User-Scoped Database Isolation (Tenant Isolation)

    func testDatabaseQueriesAreScopedToAuthenticatedUserOnly() async throws {
        // Setup User A and User B
        let userA = try await registerUser(email: "usera@example.com", name: "User A")
        let userB = try await registerUser(email: "userb@example.com", name: "User B")

        // User A creates a compound
        let compoundA = CompoundEntity(
            userId: try userA.user.requireID(),
            name: "BPC-157",
            category: "Peptide",
            defaultDose: 250,
            defaultUnit: "mcg",
            halfLifeHours: 4.0
        )
        try await compoundA.save(on: app.db)
        let compoundAId = try compoundA.requireID()

        // 1. User A can retrieve their compound
        try await app.test(.GET, "/api/v1/compounds/\(compoundAId)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: userA.token)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let dto = try res.content.decode(CompoundResponseDTO.self)
            XCTAssertEqual(dto.name, "BPC-157")
        })

        // 2. User B CANNOT retrieve User A's compound (returns 404 Not Found)
        try await app.test(.GET, "/api/v1/compounds/\(compoundAId)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: userB.token)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })

        // 3. User B CANNOT delete User A's compound
        try await app.test(.DELETE, "/api/v1/compounds/\(compoundAId)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: userB.token)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })

        // Verify compound still exists in database for User A
        let checkCompound = try await CompoundEntity.find(compoundAId, on: app.db)
        XCTAssertNotNil(checkCompound)
    }

    func testClientSuppliedUserIdInQueryOrBodyIsIgnoredForIdentityDerivation() async throws {
        let userA = try await registerUser(email: "victim@example.com", name: "Victim User")
        let userB = try await registerUser(email: "attacker@example.com", name: "Attacker User")

        let attackerToken = userB.token
        let victimId = try userA.user.requireID()

        // Attacker attempts to list compounds appending ?userId=<victimId>
        try await app.test(.GET, "/api/v1/compounds?userId=\(victimId)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: attackerToken)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let compounds = try res.content.decode([CompoundResponseDTO].self)
            // Should be empty because Attacker has no compounds
            XCTAssertEqual(compounds.count, 0)
        })
    }

    // MARK: - 3. Encryption in Transit & Security Headers

    func testSecurityHeadersAndHSTSAreInjectedOnAllResponses() async throws {
        try await app.test(.GET, "/") { res in
            // Strict Transport Security (HSTS)
            XCTAssertTrue(res.headers.contains(name: "Strict-Transport-Security"))
            let hsts = res.headers.first(name: "Strict-Transport-Security") ?? ""
            XCTAssertTrue(hsts.contains("max-age="))
            XCTAssertTrue(hsts.contains("includeSubDomains"))

            // Zero-Trust Security Headers
            XCTAssertEqual(res.headers.first(name: "X-Content-Type-Options"), "nosniff")
            XCTAssertEqual(res.headers.first(name: "X-Frame-Options"), "DENY")
            XCTAssertEqual(res.headers.first(name: "X-XSS-Protection"), "1; mode=block")
            XCTAssertEqual(res.headers.first(name: "Referrer-Policy"), "strict-origin-when-cross-origin")
            XCTAssertTrue(res.headers.contains(name: "Content-Security-Policy"))
        }
    }

    func testAntiCachingHeadersAppliedToApiEndpoints() async throws {
        let user = try await registerUser(email: "cachetest@example.com")
        try await app.test(.GET, "/api/v1/users/me", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: user.token)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let cacheControl = res.headers.first(name: "Cache-Control") ?? ""
            XCTAssertTrue(cacheControl.contains("no-store"))
            XCTAssertTrue(cacheControl.contains("no-cache"))
            XCTAssertTrue(cacheControl.contains("private"))
        })
    }

    // MARK: - 4. Encryption at Rest (Field-Level AES-256-GCM Envelope)

    func testAtRestFieldLevelEncryptionAndDecryptionRoundtrip() throws {
        let encryptionService = AtRestDataEncryptionService(
            keyIdentifier: "test-vault-v2",
            secretKeyString: "super-secret-master-key-32-chars-length"
        )

        let sensitiveClinicalNote = "Patient exhibits elevated IGF-1 levels. Dosage adjusted to 100mcg daily."
        let encryptedEnvelope = try encryptionService.encryptField(sensitiveClinicalNote)

        // Envelope structure validation: enc:v2:<keyId>:<iv>:<tag>:<ciphertext>
        XCTAssertTrue(encryptedEnvelope.starts(with: "enc:v2:test-vault-v2:"))
        let parts = encryptedEnvelope.split(separator: ":")
        XCTAssertEqual(parts.count, 6)

        // Decryption roundtrip
        let decrypted = try encryptionService.decryptField(encryptedEnvelope)
        XCTAssertEqual(decrypted, sensitiveClinicalNote)
    }

    func testAtRestCodableEncryptionAndDecryption() throws {
        struct SensitivePatientRecord: Codable, Equatable {
            let patientId: String
            let peptide: String
            let doseMcg: Double
            let notes: String
        }

        let record = SensitivePatientRecord(
            patientId: "PAT-9821",
            peptide: "Semaglutide",
            doseMcg: 500.0,
            notes: "SubQ injection administered in lower left abdomen."
        )

        let encryptionService = AtRestDataEncryptionService()
        let envelope = try encryptionService.encryptCodable(record)
        XCTAssertTrue(encryptionService.isEncrypted(envelope))

        let decrypted = try encryptionService.decryptCodable(envelope, as: SensitivePatientRecord.self)
        XCTAssertEqual(decrypted, record)
    }

    // MARK: - 5. Administrative Access Control & RBAC

    func testStandardUserCannotAccessAdminEndpoints() async throws {
        let standardUser = try await registerUser(email: "standard@example.com", role: "user")

        // 1. Admin Users List -> 403 Forbidden
        try await app.test(.GET, "/api/v1/admin/users", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: standardUser.token)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .forbidden)
        })

        // 2. Admin Audit Logs -> 403 Forbidden
        try await app.test(.GET, "/api/v1/admin/audit-logs", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: standardUser.token)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .forbidden)
        })

        // 3. Admin Observability Diagnostics -> 403 Forbidden
        try await app.test(.GET, "/api/v1/observability/status", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: standardUser.token)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .forbidden)
        })
    }

    func testAdminUserCanAccessAdminEndpoints() async throws {
        let adminUser = try await registerUser(email: "admin@example.com", role: "admin")

        // 1. Admin Users List -> 200 OK
        try await app.test(.GET, "/api/v1/admin/users", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminUser.token)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let users = try res.content.decode([AdminUserListItemDTO].self)
            XCTAssertGreaterThanOrEqual(users.count, 1)
        })

        // 2. Admin System Security Status -> 200 OK
        try await app.test(.GET, "/api/v1/admin/system-security", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminUser.token)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let status = try res.content.decode(SystemSecurityStatusDTO.self)
            XCTAssertEqual(status.securityStatus, "operational")
            XCTAssertTrue(status.encryptionInTransitEnforced)
        })
    }

    // MARK: - 6. Immutable Security Audit Logging

    func testSensitiveOperationsGenerateAuditLogRecords() async throws {
        let email = "audited_user_\(UUID().uuidString.prefix(8))@example.com"
        let registerReq = RegisterRequest(email: email, password: "SecurePassword123!", displayName: "Audit Member")

        // 1. Register User via API
        try await app.test(.POST, "/api/v1/auth/register", beforeRequest: { req in
            try req.content.encode(registerReq)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
        })

        // 2. Query Audit Logs in PostgreSQL
        let auditEntries = try await AuditLogEntity.query(on: app.db)
            .filter(\.$action == AuditEventType.userRegistered.rawValue)
            .all()

        XCTAssertFalse(auditEntries.isEmpty)
        let latest = auditEntries.last
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.action, "USER_REGISTERED")
        XCTAssertEqual(latest?.resourceType, "User")
        XCTAssertEqual(latest?.status, "success")
    }

    // MARK: - 7. PII Minimization & Complete Account Erasure

    func testAccountErasureCascadesAndPurgesAllUserData() async throws {
        let userTuple = try await registerUser(email: "eraseme@example.com", name: "Erasable User")
        let userId = try userTuple.user.requireID()

        // Create user records
        let compound = CompoundEntity(userId: userId, name: "CJC-1295", category: "Peptide", defaultDose: 100, defaultUnit: "mcg", halfLifeHours: 0.5)
        try await compound.save(on: app.db)

        let dose = DoseLogEntity(userId: userId, compoundId: try compound.requireID(), scheduledDate: Date(), doseAmount: 100, doseUnit: "mcg", status: "taken")
        try await dose.save(on: app.db)

        // Execute Account Erasure via DELETE /api/v1/users/account
        try await app.test(.DELETE, "/api/v1/users/account", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: userTuple.token)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .noContent)
        })

        // Verify relational cascade purge
        let userAfter = try await UserEntity.find(userId, on: app.db)
        XCTAssertNil(userAfter)

        let compoundsAfter = try await CompoundEntity.query(on: app.db).filter(\.$user.$id == userId).all()
        XCTAssertEqual(compoundsAfter.count, 0)

        let dosesAfter = try await DoseLogEntity.query(on: app.db).filter(\.$user.$id == userId).all()
        XCTAssertEqual(dosesAfter.count, 0)

        // Verify audit log recorded the erasure
        let audit = try await AuditLogEntity.query(on: app.db)
            .filter(\.$action == AuditEventType.accountDeleted.rawValue)
            .filter(\.$resourceId == userId.uuidString)
            .first()
        XCTAssertNotNil(audit)
    }

    // MARK: - 8. Zero-Health-Leakage Analytics Privacy Guard

    func testAnalyticsPrivacyGuardStripsProtectedHealthInformation() {
        let analyticsService = PrivacyPreservingAnalyticsService()
        let userId = UUID()

        // Raw input containing prohibited medical data
        let unsafeAttributes: [String: String] = [
            "platform": "iOS",
            "app_version": "1.0.0",
            "compound_name": "BPC-157", // PHI - Should be stripped!
            "dose_amount": "250 mcg",   // PHI - Should be stripped!
            "biomarker_name": "Testosterone", // PHI - Should be stripped!
            "lab_result_value": "750 ng/dL",  // PHI - Should be stripped!
            "notes": "Patient experiencing slight injection site soreness." // PHI - Should be stripped!
        ]

        let safeEvent = analyticsService.dispatchEvent(
            name: "dose_logged",
            userId: userId,
            rawAttributes: unsafeAttributes
        )

        // 1. User ID is pseudonymized (not raw UUID)
        XCTAssertNotEqual(safeEvent.anonymizedUserId, userId.uuidString)
        XCTAssertEqual(safeEvent.anonymizedUserId.count, 16)

        // 2. Safe attributes contain ONLY allowed coarse metadata
        XCTAssertEqual(safeEvent.safeAttributes["platform"], "iOS")
        XCTAssertEqual(safeEvent.safeAttributes["app_version"], "1.0.0")

        // 3. Prohibited health data is completely omitted
        XCTAssertNil(safeEvent.safeAttributes["compound_name"])
        XCTAssertNil(safeEvent.safeAttributes["dose_amount"])
        XCTAssertNil(safeEvent.safeAttributes["biomarker_name"])
        XCTAssertNil(safeEvent.safeAttributes["lab_result_value"])
        XCTAssertNil(safeEvent.safeAttributes["notes"])

        // 4. Zero-leakage validator passes
        XCTAssertTrue(analyticsService.verifyZeroHealthLeakage(in: safeEvent.safeAttributes))
    }
}
