import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public enum Endpoint: Sendable {
    // MARK: - 1. Auth
    case register
    case login
    case appleSignIn
    case refreshToken
    case changePassword
    case userProfile
    case logout
    case revokeToken

    // MARK: - 2. Users
    case getMe
    case updateProfile
    case updatePreferences
    case updateUnits
    case updateNotifications
    case exportUserData
    case deleteAccount

    // MARK: - 3. Compounds
    case listCompounds
    case createCompound
    case getCompound(id: UUID)
    case updateCompound(id: UUID)
    case deleteCompound(id: UUID)

    // MARK: - 4. Protocols
    case listProtocols
    case createProtocol
    case getProtocol(id: UUID)
    case updateProtocol(id: UUID)
    case deleteProtocol(id: UUID)
    case listProtocolRevisions(id: UUID)
    case listProtocolOccurrences(id: UUID, days: Int? = nil)

    // MARK: - 5. Dose Logs & Events
    case listDoses
    case logDose
    case batchLogDoses
    case getDose(id: UUID)
    case updateDose(id: UUID)
    case deleteDose(id: UUID)

    // MARK: - 6. Inventory (Vials & Supplies)
    case listVials
    case createVial
    case getVial(id: UUID)
    case updateVial(id: UUID)
    case deleteVial(id: UUID)
    case depleteVial(id: UUID)
    case discardVial(id: UUID)
    case listSupplies
    case createSupply
    case getSupply(id: UUID)
    case updateSupply(id: UUID)
    case deleteSupply(id: UUID)
    case adjustSupply(id: UUID)
    case listLowStockSupplies

    // MARK: - 7. Reconstitution
    case listReconstitutionRecords
    case createReconstitutionRecord
    case getReconstitutionRecord(id: UUID)
    case reviseReconstitutionRecord(id: UUID)

    // MARK: - 8. Injection Sites
    case listInjectionSites
    case getSiteRecommendation
    case listSiteEvents
    case logSiteEvent

    // MARK: - 9. Measurements
    case listMeasurements(type: String? = nil)
    case createMeasurement
    case getMeasurement(id: UUID)
    case updateMeasurement(id: UUID)
    case deleteMeasurement(id: UUID)
    case measurementTrends(type: String)

    // MARK: - 10. Laboratory Panels & Biomarkers
    case listLabPanels
    case createLabPanel
    case getLabPanel(id: UUID)
    case updateLabPanel(id: UUID)
    case deleteLabPanel(id: UUID)
    case listBiomarkers
    case logBiomarker
    case getBiomarkerHistory(name: String)
    case deleteBiomarker(id: UUID)

    // MARK: - 11. Documents & Encrypted Object Storage
    case listFiles(category: String? = nil, vialId: UUID? = nil, biomarkerId: UUID? = nil, doseLogId: UUID? = nil)
    case getFileMetadata(id: UUID)
    case downloadFile(id: UUID)
    case uploadFile
    case requestUploadAuthorization
    case confirmUpload
    case processFile(id: UUID)
    case directFileUpload(url: String)
    case relateFile(id: UUID)
    case deleteFile(id: UUID)

    // MARK: - 12. Reports
    case generateReport
    case generatePdfReport

    // MARK: - 13. Notifications
    case listNotifications
    case registerDeviceToken
    case sendTestNotification
    case markNotificationRead(id: UUID)
    case deleteNotification(id: UUID)

    // MARK: - 14. Synchronization
    case syncPush
    case syncPull(since: Date? = nil)
    case syncOutbox

    // MARK: - 15. Background Processing Jobs
    case listBackgroundJobs(status: String? = nil, type: String? = nil)
    case getBackgroundJob(id: UUID)
    case submitBackgroundJob
    case cancelBackgroundJob(id: UUID)
    case retryBackgroundJob(id: UUID)
    case generateReportAsync
    case exportDataAsync
    case calculateAnalyticsAsync
    case prepareNotificationsAsync
    case runSyncJobAsync

    public var path: String {
        switch self {
        // Auth
        case .register: return "/api/v1/auth/register"
        case .login: return "/api/v1/auth/login"
        case .appleSignIn: return "/api/v1/auth/apple"
        case .refreshToken: return "/api/v1/auth/refresh"
        case .changePassword: return "/api/v1/auth/password"
        case .userProfile: return "/api/v1/auth/profile"
        case .logout: return "/api/v1/auth/logout"
        case .revokeToken: return "/api/v1/auth/revoke"

        // Users
        case .getMe: return "/api/v1/users/me"
        case .updateProfile: return "/api/v1/users/profile"
        case .updatePreferences: return "/api/v1/users/preferences"
        case .updateUnits: return "/api/v1/users/units"
        case .updateNotifications: return "/api/v1/users/notifications"
        case .exportUserData: return "/api/v1/users/export"
        case .deleteAccount: return "/api/v1/users/account"

        // Compounds
        case .listCompounds: return "/api/v1/compounds"
        case .createCompound: return "/api/v1/compounds"
        case .getCompound(let id): return "/api/v1/compounds/\(id.uuidString)"
        case .updateCompound(let id): return "/api/v1/compounds/\(id.uuidString)"
        case .deleteCompound(let id): return "/api/v1/compounds/\(id.uuidString)"

        // Protocols
        case .listProtocols: return "/api/v1/protocols"
        case .createProtocol: return "/api/v1/protocols"
        case .getProtocol(let id): return "/api/v1/protocols/\(id.uuidString)"
        case .updateProtocol(let id): return "/api/v1/protocols/\(id.uuidString)"
        case .deleteProtocol(let id): return "/api/v1/protocols/\(id.uuidString)"
        case .listProtocolRevisions(let id): return "/api/v1/protocols/\(id.uuidString)/revisions"
        case .listProtocolOccurrences(let id, _): return "/api/v1/protocols/\(id.uuidString)/occurrences"

        // Doses
        case .listDoses: return "/api/v1/doses"
        case .logDose: return "/api/v1/doses"
        case .batchLogDoses: return "/api/v1/doses/batch"
        case .getDose(let id): return "/api/v1/doses/\(id.uuidString)"
        case .updateDose(let id): return "/api/v1/doses/\(id.uuidString)"
        case .deleteDose(let id): return "/api/v1/doses/\(id.uuidString)"

        // Inventory
        case .listVials: return "/api/v1/vials"
        case .createVial: return "/api/v1/vials"
        case .getVial(let id): return "/api/v1/vials/\(id.uuidString)"
        case .updateVial(let id): return "/api/v1/vials/\(id.uuidString)"
        case .deleteVial(let id): return "/api/v1/vials/\(id.uuidString)"
        case .depleteVial(let id): return "/api/v1/vials/\(id.uuidString)/deplete"
        case .discardVial(let id): return "/api/v1/vials/\(id.uuidString)/discard"

        case .listSupplies: return "/api/v1/supplies"
        case .createSupply: return "/api/v1/supplies"
        case .getSupply(let id): return "/api/v1/supplies/\(id.uuidString)"
        case .updateSupply(let id): return "/api/v1/supplies/\(id.uuidString)"
        case .deleteSupply(let id): return "/api/v1/supplies/\(id.uuidString)"
        case .adjustSupply(let id): return "/api/v1/supplies/\(id.uuidString)/adjust"
        case .listLowStockSupplies: return "/api/v1/supplies/low-stock"

        // Reconstitution
        case .listReconstitutionRecords: return "/api/v1/reconstitution"
        case .createReconstitutionRecord: return "/api/v1/reconstitution"
        case .getReconstitutionRecord(let id): return "/api/v1/reconstitution/\(id.uuidString)"
        case .reviseReconstitutionRecord(let id): return "/api/v1/reconstitution/\(id.uuidString)/revise"

        // Injection Sites
        case .listInjectionSites: return "/api/v1/injection-sites"
        case .getSiteRecommendation: return "/api/v1/injection-sites/recommendation"
        case .listSiteEvents: return "/api/v1/injection-sites/events"
        case .logSiteEvent: return "/api/v1/injection-sites/events"

        // Measurements
        case .listMeasurements(let type):
            if let t = type, let encoded = t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                return "/api/v1/measurements?type=\(encoded)"
            }
            return "/api/v1/measurements"
        case .createMeasurement: return "/api/v1/measurements"
        case .getMeasurement(let id): return "/api/v1/measurements/\(id.uuidString)"
        case .updateMeasurement(let id): return "/api/v1/measurements/\(id.uuidString)"
        case .deleteMeasurement(let id): return "/api/v1/measurements/\(id.uuidString)"
        case .measurementTrends(let type):
            let encoded = type.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? type
            return "/api/v1/measurements/trends?type=\(encoded)"

        // Lab Panels & Biomarkers
        case .listLabPanels: return "/api/v1/lab-panels"
        case .createLabPanel: return "/api/v1/lab-panels"
        case .getLabPanel(let id): return "/api/v1/lab-panels/\(id.uuidString)"
        case .updateLabPanel(let id): return "/api/v1/lab-panels/\(id.uuidString)"
        case .deleteLabPanel(let id): return "/api/v1/lab-panels/\(id.uuidString)"

        case .listBiomarkers: return "/api/v1/biomarkers"
        case .logBiomarker: return "/api/v1/biomarkers"
        case .getBiomarkerHistory(let name):
            let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            return "/api/v1/biomarkers/\(encoded)/history"
        case .deleteBiomarker(let id): return "/api/v1/biomarkers/\(id.uuidString)"

        // Files / Documents
        case .listFiles(let category, let vialId, let biomarkerId, let doseLogId):
            var queryParts: [String] = []
            if let c = category { queryParts.append("category=\(c)") }
            if let v = vialId { queryParts.append("vialId=\(v.uuidString)") }
            if let b = biomarkerId { queryParts.append("biomarkerId=\(b.uuidString)") }
            if let d = doseLogId { queryParts.append("doseLogId=\(d.uuidString)") }
            let queryString = queryParts.isEmpty ? "" : "?\(queryParts.joined(separator: "&"))"
            return "/api/v1/files\(queryString)"

        case .getFileMetadata(let id): return "/api/v1/files/\(id.uuidString)"
        case .downloadFile(let id): return "/api/v1/files/\(id.uuidString)/download"
        case .uploadFile: return "/api/v1/files/upload"
        case .requestUploadAuthorization: return "/api/v1/files/upload-authorization"
        case .confirmUpload: return "/api/v1/files/confirm-upload"
        case .processFile(let id): return "/api/v1/files/\(id.uuidString)/process"
        case .directFileUpload(let url): return url
        case .relateFile(let id): return "/api/v1/files/\(id.uuidString)/relate"
        case .deleteFile(let id): return "/api/v1/files/\(id.uuidString)"

        // Reports
        case .generateReport: return "/api/v1/reports/generate"
        case .generatePdfReport: return "/api/v1/reports/pdf"

        // Notifications
        case .listNotifications: return "/api/v1/notifications"
        case .registerDeviceToken: return "/api/v1/notifications/devices"
        case .sendTestNotification: return "/api/v1/notifications/test"
        case .markNotificationRead(let id): return "/api/v1/notifications/\(id.uuidString)/read"
        case .deleteNotification(let id): return "/api/v1/notifications/\(id.uuidString)"

        // Sync
        case .syncPush: return "/api/v1/sync/push"
        case .syncPull: return "/api/v1/sync/pull"
        case .syncOutbox: return "/api/v1/sync/outbox"

        // Background Jobs
        case .listBackgroundJobs(let status, let type):
            var parts: [String] = []
            if let s = status { parts.append("status=\(s)") }
            if let t = type { parts.append("jobType=\(t)") }
            let query = parts.isEmpty ? "" : "?\(parts.joined(separator: "&"))"
            return "/api/v1/jobs\(query)"

        case .getBackgroundJob(let id): return "/api/v1/jobs/\(id.uuidString)"
        case .submitBackgroundJob: return "/api/v1/jobs"
        case .cancelBackgroundJob(let id): return "/api/v1/jobs/\(id.uuidString)/cancel"
        case .retryBackgroundJob(let id): return "/api/v1/jobs/\(id.uuidString)/retry"
        case .generateReportAsync: return "/api/v1/jobs/reports/generate-async"
        case .exportDataAsync: return "/api/v1/jobs/export-async"
        case .calculateAnalyticsAsync: return "/api/v1/jobs/analytics/calculate-async"
        case .prepareNotificationsAsync: return "/api/v1/jobs/notifications/prepare-async"
        case .runSyncJobAsync: return "/api/v1/jobs/sync/run-async"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .listCompounds, .getCompound, .listProtocols, .getProtocol, .listProtocolRevisions,
             .listDoses, .getDose, .listVials, .getVial, .listSupplies, .getSupply, .listLowStockSupplies,
             .listReconstitutionRecords, .getReconstitutionRecord, .listInjectionSites, .getSiteRecommendation, .listSiteEvents,
             .listMeasurements, .getMeasurement, .measurementTrends, .listLabPanels, .getLabPanel,
             .listBiomarkers, .getBiomarkerHistory, .listFiles, .getFileMetadata, .downloadFile,
             .listNotifications, .syncPull, .userProfile, .getMe,
             .listBackgroundJobs, .getBackgroundJob:
            return .get

        case .register, .login, .appleSignIn, .refreshToken, .changePassword, .logout, .revokeToken,
             .createCompound, .createProtocol, .logDose, .batchLogDoses,
             .createVial, .depleteVial, .discardVial, .createSupply, .adjustSupply,
             .createReconstitutionRecord, .reviseReconstitutionRecord, .logSiteEvent,
             .createMeasurement, .createLabPanel, .logBiomarker, .uploadFile,
             .requestUploadAuthorization, .confirmUpload, .processFile, .directFileUpload,
             .generateReport, .generatePdfReport, .registerDeviceToken, .sendTestNotification, .syncPush, .syncOutbox,
             .submitBackgroundJob, .cancelBackgroundJob, .retryBackgroundJob,
             .generateReportAsync, .exportDataAsync, .calculateAnalyticsAsync, .prepareNotificationsAsync, .runSyncJobAsync,
             .exportUserData:
            return .post

        case .updateProfile, .updatePreferences, .updateUnits, .updateNotifications,
             .updateCompound, .updateProtocol, .updateDose, .updateVial, .updateSupply,
             .updateMeasurement, .updateLabPanel:
            return .put

        case .relateFile, .markNotificationRead:
            return .patch

        case .deleteAccount, .deleteCompound, .deleteProtocol, .deleteDose, .deleteVial,
             .deleteSupply, .deleteMeasurement, .deleteLabPanel, .deleteBiomarker,
             .deleteFile, .deleteNotification:
            return .delete
        }
    }
}
