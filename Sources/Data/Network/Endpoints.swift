import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public enum Endpoint: Sendable {
    // Auth
    case register
    case login
    case userProfile

    // Compounds & Protocols
    case listCompounds
    case createCompound
    case listProtocols
    case createProtocol
    case updateProtocol(id: UUID)
    case deleteProtocol(id: UUID)

    // Dose Logs
    case listDoses
    case logDose
    case updateDose(id: UUID)

    // Vials & Inventory
    case listVials
    case createVial
    case updateVial(id: UUID)

    // Biomarkers
    case listBiomarkers
    case logBiomarker

    // Offline Delta Sync
    case syncPush
    case syncPull(since: Date?)

    // Reports
    case generateReport

    public var path: String {
        switch self {
        case .register: return "/api/v1/auth/register"
        case .login: return "/api/v1/auth/login"
        case .userProfile: return "/api/v1/auth/profile"

        case .listCompounds: return "/api/v1/compounds"
        case .createCompound: return "/api/v1/compounds"

        case .listProtocols: return "/api/v1/protocols"
        case .createProtocol: return "/api/v1/protocols"
        case .updateProtocol(let id): return "/api/v1/protocols/\(id.uuidString)"
        case .deleteProtocol(let id): return "/api/v1/protocols/\(id.uuidString)"

        case .listDoses: return "/api/v1/doses"
        case .logDose: return "/api/v1/doses"
        case .updateDose(let id): return "/api/v1/doses/\(id.uuidString)"

        case .listVials: return "/api/v1/vials"
        case .createVial: return "/api/v1/vials"
        case .updateVial(let id): return "/api/v1/vials/\(id.uuidString)"

        case .listBiomarkers: return "/api/v1/biomarkers"
        case .logBiomarker: return "/api/v1/biomarkers"

        case .syncPush: return "/api/v1/sync/push"
        case .syncPull: return "/api/v1/sync/pull"

        case .generateReport: return "/api/v1/reports/generate"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .listCompounds, .listProtocols, .listDoses, .listVials, .listBiomarkers, .syncPull, .userProfile:
            return .get
        case .register, .login, .createCompound, .createProtocol, .logDose, .createVial, .logBiomarker, .syncPush, .generateReport:
            return .post
        case .updateProtocol, .updateDose, .updateVial:
            return .put
        case .deleteProtocol:
            return .delete
        }
    }
}
