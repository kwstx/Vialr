import Foundation

public protocol CompoundRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Compound]
    func fetch(byId id: UUID) async throws -> Compound?
    func save(_ compound: Compound) async throws
    func delete(byId id: UUID) async throws
}

public protocol ProtocolRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [ProtocolModel]
    func fetchActive() async throws -> [ProtocolModel]
    func fetch(byId id: UUID) async throws -> ProtocolModel?
    func save(_ protocolModel: ProtocolModel) async throws
    func delete(byId id: UUID) async throws
}

public protocol DoseLogRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [DoseLog]
    func fetchRecent(limit: Int) async throws -> [DoseLog]
    func fetchForDateRange(start: Date, end: Date) async throws -> [DoseLog]
    func fetchForCompound(compoundId: UUID) async throws -> [DoseLog]
    func save(_ log: DoseLog) async throws
    func delete(byId id: UUID) async throws
}

public protocol VialRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Vial]
    func fetchActive() async throws -> [Vial]
    func fetch(byId id: UUID) async throws -> Vial?
    func save(_ vial: Vial) async throws
    func delete(byId id: UUID) async throws
}

public protocol SupplyRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [SupplyItem]
    func fetchLowStock() async throws -> [SupplyItem]
    func save(_ item: SupplyItem) async throws
    func delete(byId id: UUID) async throws
}

public protocol BiomarkerRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Biomarker]
    func fetchByCategory(_ category: BiomarkerCategory) async throws -> [Biomarker]
    func fetchForDateRange(start: Date, end: Date) async throws -> [Biomarker]
    func save(_ biomarker: Biomarker) async throws
    func delete(byId id: UUID) async throws
}

public protocol SymptomRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [SymptomLog]
    func fetchRecent(limit: Int) async throws -> [SymptomLog]
    func save(_ symptomLog: SymptomLog) async throws
    func delete(byId id: UUID) async throws
}

public protocol CostRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [CostRecord]
    func fetchForDateRange(start: Date, end: Date) async throws -> [CostRecord]
    func save(_ costRecord: CostRecord) async throws
    func delete(byId id: UUID) async throws
}

public protocol StoredFileRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [StoredFileRecord]
    func fetchByCategory(_ category: StoredFileCategory) async throws -> [StoredFileRecord]
    func fetchForVial(vialId: UUID) async throws -> [StoredFileRecord]
    func fetchForBiomarker(biomarkerId: UUID) async throws -> [StoredFileRecord]
    func fetchForDoseLog(doseLogId: UUID) async throws -> [StoredFileRecord]
    func fetchForProtocol(protocolId: UUID) async throws -> [StoredFileRecord]
    func fetch(byId id: UUID) async throws -> StoredFileRecord?
    func save(_ record: StoredFileRecord) async throws
    func delete(byId id: UUID) async throws
}

