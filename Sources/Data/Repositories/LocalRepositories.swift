import Foundation
import Domain

// MARK: - Compound Repository
public final class LocalCompoundRepository: CompoundRepositoryProtocol, @unchecked Sendable {
    private let store: LocalStore

    public init(store: LocalStore = .shared) {
        self.store = store
    }

    public func fetchAll() async throws -> [Compound] {
        await store.initializeWithMockDataIfNeeded()
        return await store.getAllCompounds()
    }

    public func fetch(byId id: UUID) async throws -> Compound? {
        await store.initializeWithMockDataIfNeeded()
        let all = await store.getAllCompounds()
        return all.first(where: { $0.id == id })
    }

    public func save(_ compound: Compound) async throws {
        await store.saveCompound(compound)
    }

    public func delete(byId id: UUID) async throws {
        await store.deleteCompound(id: id)
    }
}

// MARK: - Protocol Repository
public final class LocalProtocolRepository: ProtocolRepositoryProtocol, @unchecked Sendable {
    private let store: LocalStore

    public init(store: LocalStore = .shared) {
        self.store = store
    }

    public func fetchAll() async throws -> [ProtocolModel] {
        await store.initializeWithMockDataIfNeeded()
        return await store.getAllProtocols()
    }

    public func fetchActive() async throws -> [ProtocolModel] {
        let all = try await fetchAll()
        return all.filter { $0.status == .active }
    }

    public func fetch(byId id: UUID) async throws -> ProtocolModel? {
        let all = try await fetchAll()
        return all.first(where: { $0.id == id })
    }

    public func save(_ protocolModel: ProtocolModel) async throws {
        await store.saveProtocol(protocolModel)
    }

    public func delete(byId id: UUID) async throws {
        await store.deleteProtocol(id: id)
    }
}

// MARK: - Dose Log Repository
public final class LocalDoseLogRepository: DoseLogRepositoryProtocol, @unchecked Sendable {
    private let store: LocalStore

    public init(store: LocalStore = .shared) {
        self.store = store
    }

    public func fetchAll() async throws -> [DoseLog] {
        await store.initializeWithMockDataIfNeeded()
        return await store.getAllDoseLogs()
    }

    public func fetchRecent(limit: Int) async throws -> [DoseLog] {
        let all = try await fetchAll()
        return Array(
            all.sorted(by: { ($0.loggedDate ?? $0.scheduledDate) > ($1.loggedDate ?? $1.scheduledDate) })
                .prefix(limit)
        )
    }

    public func fetchForDateRange(start: Date, end: Date) async throws -> [DoseLog] {
        let all = try await fetchAll()
        return all.filter { log in
            let d = log.loggedDate ?? log.scheduledDate
            return d >= start && d <= end
        }
    }

    public func fetchForCompound(compoundId: UUID) async throws -> [DoseLog] {
        let all = try await fetchAll()
        return all.filter { $0.compoundId == compoundId }
    }

    public func save(_ log: DoseLog) async throws {
        await store.saveDoseLog(log)
    }

    public func delete(byId id: UUID) async throws {
        await store.deleteDoseLog(id: id)
    }
}

// MARK: - Vial Repository
public final class LocalVialRepository: VialRepositoryProtocol, @unchecked Sendable {
    private let store: LocalStore

    public init(store: LocalStore = .shared) {
        self.store = store
    }

    public func fetchAll() async throws -> [Vial] {
        await store.initializeWithMockDataIfNeeded()
        return await store.getAllVials()
    }

    public func fetchActive() async throws -> [Vial] {
        let all = try await fetchAll()
        return all.filter { $0.status == .reconstituted || $0.status == .unopened }
    }

    public func fetch(byId id: UUID) async throws -> Vial? {
        let all = try await fetchAll()
        return all.first(where: { $0.id == id })
    }

    public func save(_ vial: Vial) async throws {
        await store.saveVial(vial)
    }

    public func delete(byId id: UUID) async throws {
        await store.deleteVial(id: id)
    }
}

// MARK: - Supply Repository
public final class LocalSupplyRepository: SupplyRepositoryProtocol, @unchecked Sendable {
    private let store: LocalStore

    public init(store: LocalStore = .shared) {
        self.store = store
    }

    public func fetchAll() async throws -> [SupplyItem] {
        await store.initializeWithMockDataIfNeeded()
        return await store.getAllSupplies()
    }

    public func fetchLowStock() async throws -> [SupplyItem] {
        let all = try await fetchAll()
        return all.filter { $0.isLowStock }
    }

    public func save(_ item: SupplyItem) async throws {
        await store.saveSupply(item)
    }

    public func delete(byId id: UUID) async throws {
        await store.deleteSupply(id: id)
    }
}

// MARK: - Biomarker Repository
public final class LocalBiomarkerRepository: BiomarkerRepositoryProtocol, @unchecked Sendable {
    private let store: LocalStore

    public init(store: LocalStore = .shared) {
        self.store = store
    }

    public func fetchAll() async throws -> [Biomarker] {
        await store.initializeWithMockDataIfNeeded()
        return await store.getAllBiomarkers()
    }

    public func fetchByCategory(_ category: BiomarkerCategory) async throws -> [Biomarker] {
        let all = try await fetchAll()
        return all.filter { $0.category == category }
    }

    public func fetchForDateRange(start: Date, end: Date) async throws -> [Biomarker] {
        let all = try await fetchAll()
        return all.filter { $0.dateRecorded >= start && $0.dateRecorded <= end }
    }

    public func save(_ biomarker: Biomarker) async throws {
        await store.saveBiomarker(biomarker)
    }

    public func delete(byId id: UUID) async throws {
        await store.deleteBiomarker(id: id)
    }
}

// MARK: - Symptom Repository
public final class LocalSymptomRepository: SymptomRepositoryProtocol, @unchecked Sendable {
    private let store: LocalStore

    public init(store: LocalStore = .shared) {
        self.store = store
    }

    public func fetchAll() async throws -> [SymptomLog] {
        await store.initializeWithMockDataIfNeeded()
        return await store.getAllSymptoms()
    }

    public func fetchRecent(limit: Int) async throws -> [SymptomLog] {
        let all = try await fetchAll()
        return Array(all.sorted(by: { $0.timestamp > $1.timestamp }).prefix(limit))
    }

    public func save(_ symptomLog: SymptomLog) async throws {
        await store.saveSymptom(symptomLog)
    }

    public func delete(byId id: UUID) async throws {
        // Not used
    }
}

// MARK: - Cost Repository
public final class LocalCostRepository: CostRepositoryProtocol, @unchecked Sendable {
    private let store: LocalStore

    public init(store: LocalStore = .shared) {
        self.store = store
    }

    public func fetchAll() async throws -> [CostRecord] {
        await store.initializeWithMockDataIfNeeded()
        return await store.getAllCosts()
    }

    public func fetchForDateRange(start: Date, end: Date) async throws -> [CostRecord] {
        let all = try await fetchAll()
        return all.filter { $0.dateIncurred >= start && $0.dateIncurred <= end }
    }

    public func save(_ costRecord: CostRecord) async throws {
        await store.saveCost(costRecord)
    }

    public func delete(byId id: UUID) async throws {
        // Not used
    }
}

// MARK: - Stored File Repository
public final class LocalStoredFileRepository: StoredFileRepositoryProtocol, @unchecked Sendable {
    private let store: LocalStore

    public init(store: LocalStore = .shared) {
        self.store = store
    }

    public func fetchAll() async throws -> [StoredFileRecord] {
        await store.initializeWithMockDataIfNeeded()
        return await store.getAllStoredFiles()
    }

    public func fetchByCategory(_ category: StoredFileCategory) async throws -> [StoredFileRecord] {
        let all = try await fetchAll()
        return all.filter { $0.category == category }
    }

    public func fetchForVial(vialId: UUID) async throws -> [StoredFileRecord] {
        let all = try await fetchAll()
        return all.filter { $0.vialId == vialId }
    }

    public func fetchForBiomarker(biomarkerId: UUID) async throws -> [StoredFileRecord] {
        let all = try await fetchAll()
        return all.filter { $0.biomarkerId == biomarkerId }
    }

    public func fetchForDoseLog(doseLogId: UUID) async throws -> [StoredFileRecord] {
        let all = try await fetchAll()
        return all.filter { $0.doseLogId == doseLogId }
    }

    public func fetchForProtocol(protocolId: UUID) async throws -> [StoredFileRecord] {
        let all = try await fetchAll()
        return all.filter { $0.protocolId == protocolId }
    }

    public func fetch(byId id: UUID) async throws -> StoredFileRecord? {
        let all = try await fetchAll()
        return all.first(where: { $0.id == id })
    }

    public func save(_ record: StoredFileRecord) async throws {
        await store.saveStoredFile(record)
    }

    public func delete(byId id: UUID) async throws {
        await store.deleteStoredFile(id: id)
    }
}

// MARK: - User Repository
public final class LocalUserRepository: UserRepositoryProtocol, @unchecked Sendable {
    private let store: LocalStore

    public init(store: LocalStore = .shared) {
        self.store = store
    }

    public func fetchCurrentUser() async throws -> User? {
        await store.initializeWithMockDataIfNeeded()
        return await store.getCurrentUser()
    }

    public func saveUser(_ user: User) async throws {
        await store.initializeWithMockDataIfNeeded()
        await store.saveUser(user)
    }

    public func updatePreferences(_ preferences: UserPreferences) async throws {
        await store.initializeWithMockDataIfNeeded()
        await store.updatePreferences(preferences)
    }

    public func updateNotificationPreferences(_ notificationPreferences: NotificationPreferences) async throws {
        await store.initializeWithMockDataIfNeeded()
        await store.updateNotificationPreferences(notificationPreferences)
    }

    public func updatePrivacyPreferences(_ privacyPreferences: PrivacyPreferences) async throws {
        await store.initializeWithMockDataIfNeeded()
        await store.updatePrivacyPreferences(privacyPreferences)
    }

    public func updateUnits(_ units: UnitPreferences) async throws {
        await store.initializeWithMockDataIfNeeded()
        await store.updateUnits(units)
    }

    public func deleteUser(byId id: UUID) async throws {
        await store.initializeWithMockDataIfNeeded()
        await store.deleteUser(id: id)
    }
}


