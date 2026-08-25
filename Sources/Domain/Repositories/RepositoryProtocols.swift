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

public typealias DoseEventRepositoryProtocol = DoseLogRepositoryProtocol

public protocol InjectionSiteEventRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [InjectionSiteEvent]
    func fetchRecent(limit: Int) async throws -> [InjectionSiteEvent]
    func fetchForDoseEvent(doseEventId: UUID) async throws -> InjectionSiteEvent?
    func fetchForSite(siteId: String) async throws -> [InjectionSiteEvent]
    func save(_ event: InjectionSiteEvent) async throws
    func delete(byId id: UUID) async throws
}


public protocol VialRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Vial]
    func fetchActive() async throws -> [Vial]
    func fetch(byId id: UUID) async throws -> Vial?
    func save(_ vial: Vial) async throws
    func delete(byId id: UUID) async throws
}

public protocol ReconstitutionRecordRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [ReconstitutionRecord]
    func fetch(byId id: UUID) async throws -> ReconstitutionRecord?
    func fetchForVial(vialId: UUID) async throws -> [ReconstitutionRecord]
    func fetchActiveRecord(forVial vialId: UUID) async throws -> ReconstitutionRecord?
    func save(_ record: ReconstitutionRecord) async throws
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

public protocol MeasurementRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Measurement]
    func fetchByType(_ type: MeasurementType) async throws -> [Measurement]
    func fetchByCategory(_ category: MeasurementCategory) async throws -> [Measurement]
    func fetchForDateRange(start: Date, end: Date) async throws -> [Measurement]
    func fetch(byId id: UUID) async throws -> Measurement?
    func save(_ measurement: Measurement) async throws
    func delete(byId id: UUID) async throws
}

public protocol LabPanelRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [LabPanel]
    func fetchRecent(limit: Int) async throws -> [LabPanel]
    func fetchForDateRange(start: Date, end: Date) async throws -> [LabPanel]
    func fetchForProtocol(protocolId: UUID) async throws -> [LabPanel]
    func fetch(byId id: UUID) async throws -> LabPanel?
    func save(_ panel: LabPanel) async throws
    func delete(byId id: UUID) async throws
}

public protocol DocumentRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Document]
    func fetchByCategory(_ category: DocumentCategory) async throws -> [Document]
    func fetchForLabPanel(labPanelId: UUID) async throws -> [Document]
    func fetchForProtocol(protocolId: UUID) async throws -> [Document]
    func fetchForVial(vialId: UUID) async throws -> [Document]
    func fetch(byId id: UUID) async throws -> Document?
    func save(_ document: Document) async throws
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

public protocol UserRepositoryProtocol: Sendable {
    func fetchCurrentUser() async throws -> User?
    func saveUser(_ user: User) async throws
    func updatePreferences(_ preferences: UserPreferences) async throws
    func updateNotificationPreferences(_ notificationPreferences: NotificationPreferences) async throws
    func updatePrivacyPreferences(_ privacyPreferences: PrivacyPreferences) async throws
    func updateUnits(_ units: UnitPreferences) async throws
    func deleteUser(byId id: UUID) async throws
}


