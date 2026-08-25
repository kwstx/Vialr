import XCTest
import Domain
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

final class StorageTests: XCTestCase {

    // Test Encryption Service direct logic
    func testAESGCMEncryptionAndDecryptionRoundTrip() throws {
        let masterSecret = "test-secret-key-vault-minimum-32-chars-2026"
        let symmetricKey = SymmetricKey(data: SHA256.hash(data: Data(masterSecret.utf8)))
        
        let samplePlaintext = "PDF-1.7 Laboratory Bloodwork Panel: IGF-1: 245 ng/mL, Total Testosterone: 850 ng/dL".data(using: .utf8)!
        
        // 1. Encrypt
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(samplePlaintext, using: symmetricKey, nonce: nonce)
        let ciphertext = sealedBox.ciphertext
        let tag = sealedBox.tag

        // Ciphertext should not match plaintext
        XCTAssertNotEqual(ciphertext, samplePlaintext)
        XCTAssertFalse(ciphertext.isEmpty)

        // 2. Decrypt
        let openedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let decryptedData = try AES.GCM.open(openedBox, using: symmetricKey)

        XCTAssertEqual(decryptedData, samplePlaintext)
        
        let shaExpected = SHA256.hash(data: samplePlaintext).map { String(format: "%02x", $0) }.joined()
        let shaDecrypted = SHA256.hash(data: decryptedData).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(shaExpected, shaDecrypted)
    }

    func testTamperedCiphertextThrowsAuthenticationFailure() throws {
        let masterSecret = "test-secret-key-vault-minimum-32-chars-2026"
        let symmetricKey = SymmetricKey(data: SHA256.hash(data: Data(masterSecret.utf8)))
        let samplePlaintext = "Confidential Patient Lab PDF".data(using: .utf8)!

        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(samplePlaintext, using: symmetricKey, nonce: nonce)
        
        // Tamper with ciphertext by flipping byte
        var tamperedCiphertext = sealedBox.ciphertext
        tamperedCiphertext[0] ^= 0xFF

        let tamperedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: tamperedCiphertext, tag: sealedBox.tag)
        
        XCTAssertThrowsError(try AES.GCM.open(tamperedBox, using: symmetricKey))
    }

    func testStoredFileCategoryConstraints() {
        // User Document
        XCTAssertEqual(StoredFileCategory.userDocument.rawValue, "user_document")
        XCTAssertTrue(StoredFileCategory.userDocument.allowedContentTypes.contains("application/pdf"))
        
        // Lab PDF
        XCTAssertEqual(StoredFileCategory.labPdf.rawValue, "lab_pdf")
        XCTAssertTrue(StoredFileCategory.labPdf.allowedContentTypes.contains("application/pdf"))
        XCTAssertFalse(StoredFileCategory.labPdf.allowedContentTypes.contains("image/png"))
        
        // Vial Photo
        XCTAssertEqual(StoredFileCategory.vialPhoto.rawValue, "vial_photo")
        XCTAssertTrue(StoredFileCategory.vialPhoto.allowedContentTypes.contains("image/jpeg"))
        XCTAssertTrue(StoredFileCategory.vialPhoto.allowedContentTypes.contains("image/png"))

        // Progress Photo
        XCTAssertEqual(StoredFileCategory.progressPhoto.rawValue, "progress_photo")
        XCTAssertTrue(StoredFileCategory.progressPhoto.allowedContentTypes.contains("image/jpeg"))

        // Exported Report
        XCTAssertEqual(StoredFileCategory.exportedReport.rawValue, "exported_report")
        XCTAssertTrue(StoredFileCategory.exportedReport.allowedContentTypes.contains("application/json"))
        XCTAssertTrue(StoredFileCategory.exportedReport.allowedContentTypes.contains("application/pdf"))
    }

    func testStoredFileRelationalAssociations() {
        let userId = UUID()
        let vialId = UUID()
        let biomarkerId = UUID()
        let doseLogId = UUID()

        let vialPhoto = StoredFileRecord(
            userId: userId,
            category: .vialPhoto,
            fileName: "vial_label.jpg",
            contentType: "image/jpeg",
            byteSize: 2048,
            sha256Checksum: "checksum-123",
            storageBucket: "vialr-secure-vault",
            storageKey: "vault/users/\(userId)/vial-photos/photo.enc",
            vialId: vialId
        )
        XCTAssertEqual(vialPhoto.vialId, vialId)
        XCTAssertNil(vialPhoto.biomarkerId)

        let labPdf = StoredFileRecord(
            userId: userId,
            category: .labPdf,
            fileName: "bloodwork_panel.pdf",
            contentType: "application/pdf",
            byteSize: 409600,
            sha256Checksum: "checksum-456",
            storageBucket: "vialr-secure-vault",
            storageKey: "vault/users/\(userId)/lab-pdfs/lab.enc",
            biomarkerId: biomarkerId
        )
        XCTAssertEqual(labPdf.biomarkerId, biomarkerId)

        let progressPhoto = StoredFileRecord(
            userId: userId,
            category: .progressPhoto,
            fileName: "injection_site_deltoid.jpg",
            contentType: "image/jpeg",
            byteSize: 102400,
            sha256Checksum: "checksum-789",
            storageBucket: "vialr-secure-vault",
            storageKey: "vault/users/\(userId)/progress-photos/site.enc",
            doseLogId: doseLogId
        )
        XCTAssertEqual(progressPhoto.doseLogId, doseLogId)
    }
}
