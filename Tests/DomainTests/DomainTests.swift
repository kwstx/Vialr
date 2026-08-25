import XCTest
@testable import Domain

final class DomainTests: XCTestCase {

    func testCompoundJSONEncodingDecoding() throws {
        let compound = Compound(
            name: "Tirzepatide",
            shortCode: "TRZ",
            category: .glp1Metabolic,
            defaultUnit: .mg,
            typicalDose: 5.0,
            halfLifeHours: 120.0,
            description: "Dual GIP/GLP-1 agonist."
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(compound)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Compound.self, from: data)

        XCTAssertEqual(decoded.id, compound.id)
        XCTAssertEqual(decoded.name, "Tirzepatide")
        XCTAssertEqual(decoded.category, .glp1Metabolic)
        XCTAssertEqual(decoded.typicalDose, 5.0)
        XCTAssertEqual(decoded.halfLifeHours, 120.0)
    }

    func testProtocolItemScheduleRuleDescription() {
        let daily = ScheduleRule.everyDay
        XCTAssertEqual(daily.description, "Daily")

        let cycle = ScheduleRule.cycle(daysOn: 5, daysOff: 2)
        XCTAssertEqual(cycle.description, "5 Days On / 2 Days Off")
    }

    func testVialRemainingFractionCalculation() {
        let vial = Vial(
            compoundId: UUID(),
            compoundName: "BPC-157",
            totalDryMassMg: 5.0,
            bacWaterAddedMl: 2.0,
            currentVolumeRemainingMl: 1.0,
            isReconstituted: true
        )

        XCTAssertEqual(vial.remainingFraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(vial.concentrationMgMl ?? 0, 2.5, accuracy: 0.001)
    }

    func testStoredFileRecordEncodingDecoding() throws {
        let fileId = UUID()
        let userId = UUID()
        let vialId = UUID()
        let record = StoredFileRecord(
            id: fileId,
            userId: userId,
            category: .vialPhoto,
            fileName: "bpc157_batch_402.jpg",
            contentType: "image/jpeg",
            byteSize: 1024 * 500,
            sha256Checksum: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            storageBucket: "vialr-secure-vault",
            storageKey: "vault/users/\(userId.uuidString)/vial-photos/\(fileId.uuidString).enc",
            encryption: StorageEncryptionMetadata(
                algorithm: "AES-256-GCM",
                keyId: "vialr-vault-primary",
                initializationVector: "YWJjZGVmZ2hpams=",
                authenticationTag: "dGFnMTIzNDU2Nzg=",
                isEncrypted: true
            ),
            vialId: vialId,
            metadata: ["width": "1920", "height": "1080"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(record)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StoredFileRecord.self, from: data)

        XCTAssertEqual(decoded.id, fileId)
        XCTAssertEqual(decoded.userId, userId)
        XCTAssertEqual(decoded.category, .vialPhoto)
        XCTAssertEqual(decoded.fileName, "bpc157_batch_402.jpg")
        XCTAssertEqual(decoded.contentType, "image/jpeg")
        XCTAssertEqual(decoded.vialId, vialId)
        XCTAssertEqual(decoded.encryption.algorithm, "AES-256-GCM")
        XCTAssertTrue(decoded.encryption.isEncrypted)
        XCTAssertEqual(decoded.metadata["width"], "1920")
    }

    func testStoredFileCategoryConstraints() {
        XCTAssertEqual(StoredFileCategory.userDocument.defaultFolderPrefix, "documents")
        XCTAssertEqual(StoredFileCategory.labPdf.defaultFolderPrefix, "lab-pdfs")
        XCTAssertEqual(StoredFileCategory.vialPhoto.defaultFolderPrefix, "vial-photos")
        XCTAssertEqual(StoredFileCategory.progressPhoto.defaultFolderPrefix, "progress-photos")
        XCTAssertEqual(StoredFileCategory.exportedReport.defaultFolderPrefix, "reports")

        XCTAssertTrue(StoredFileCategory.labPdf.allowedContentTypes.contains("application/pdf"))
        XCTAssertFalse(StoredFileCategory.labPdf.allowedContentTypes.contains("image/jpeg"))

        XCTAssertTrue(StoredFileCategory.vialPhoto.allowedContentTypes.contains("image/jpeg"))
        XCTAssertTrue(StoredFileCategory.progressPhoto.allowedContentTypes.contains("image/png"))

        XCTAssertGreaterThan(StoredFileCategory.labPdf.maxAllowedSizeBytes, 10 * 1024 * 1024)
        XCTAssertGreaterThan(StoredFileCategory.userDocument.maxAllowedSizeBytes, 10 * 1024 * 1024)
    }
}

