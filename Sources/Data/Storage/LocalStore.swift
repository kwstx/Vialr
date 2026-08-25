import Foundation
import Domain

#if canImport(SwiftData)
import SwiftData
#endif

/// Thread-safe local-first persistent and in-memory store using Swift actor.
/// Handles instant local writes with zero perceived latency, local inventory deductions,
/// optimistic version tracking, and automated synchronization queue management.
public actor LocalStore {
    public static let shared = LocalStore()

    // MARK: - In-Memory Cache (0ms Instant Reads & UI Updates)
    public var compounds: [Compound] = []
    public var protocols: [ProtocolModel] = []
    public var doseLogs: [DoseLog] = []
    public var vials: [Vial] = []
    public var supplies: [SupplyItem] = []
    public var biomarkers: [Biomarker] = []
    public var symptomLogs: [SymptomLog] = []
    public var costs: [CostRecord] = []
    public var currentUser: User?
    public var injectionSiteEvents: [InjectionSiteEvent] = []
    public var reconstitutionRecords: [ReconstitutionRecord] = []
    public var measurements: [Measurement] = []
    public var labPanels: [LabPanel] = []
    public var documents: [Document] = []
    public var outcomeMetrics: [OutcomeMetric] = []
    public var storedFiles: [StoredFileRecord] = []
    public var syncQueue: [SyncQueueItem] = []

    private var isInitialized = false

    public init() {}

    public func initializeWithMockDataIfNeeded() {
        guard !isInitialized else { return }
        let mock = MockDataFactory()
        self.currentUser = mock.defaultUser
        self.compounds = mock.defaultCompounds
        self.protocols = mock.defaultProtocols
        self.doseLogs = mock.defaultDoseLogs
        self.vials = mock.defaultVials
        self.supplies = mock.defaultSupplies
        self.biomarkers = mock.defaultBiomarkers
        self.symptomLogs = mock.defaultSymptomLogs
        self.costs = mock.defaultCosts
        self.isInitialized = true
    }

    // MARK: - Dose Logs (Core Zero-Latency Logging with Local Inventory Deduction)
    public func getAllDoseLogs() -> [DoseLog] { doseLogs }

    public func saveDoseLog(_ inputLog: DoseLog) {
        var log = inputLog
        log.updatedAt = Date()
        
        let isNew = !doseLogs.contains(where: { $0.id == log.id })
        if isNew {
            if log.syncState == .synced {
                log.syncState = .pendingCreation
            }
        } else {
            if log.syncState == .synced {
                log.syncState = .pendingUpdate
            }
            log.version += 1
        }

        if let idx = doseLogs.firstIndex(where: { $0.id == log.id }) {
            doseLogs[idx] = log
        } else {
            doseLogs.append(log)
        }

        // Instant local inventory volume deduction:
        // When a dose is taken and linked to a vial, deduct liquid volume immediately
        if log.status == .taken, let vId = log.vialId, let vIdx = vials.firstIndex(where: { $0.id == vId }) {
            var v = vials[vIdx]
            if let conc = v.concentrationMgMl, conc > 0, let rem = v.currentVolumeRemainingMl {
                let doseMg = log.doseUnit == .mg ? log.doseAmount : (log.doseAmount / 1000.0)
                let volMl = doseMg / conc
                v.currentVolumeRemainingMl = max(0.0, rem - volMl)
                if (v.currentVolumeRemainingMl ?? 0) <= 0.001 {
                    v.status = .depleted
                    v.depletedDate = log.actualTimestamp ?? Date()
                }
                v.updatedAt = Date()
                v.version += 1
                if v.syncState == .synced {
                    v.syncState = .pendingUpdate
                }
                vials[vIdx] = v
                
                // Enqueue vial update in sync queue
                enqueueSyncMutation(
                    entityType: "vial",
                    entityId: v.id,
                    action: .update,
                    entity: v,
                    version: v.version
                )
            }
        }

        // Automatically enqueue in the synchronization queue
        enqueueSyncMutation(
            entityType: "doseEvent",
            entityId: log.id,
            action: isNew ? .create : .update,
            entity: log,
            version: log.version
        )
    }

    public func deleteDoseLog(id: UUID) {
        if let idx = doseLogs.firstIndex(where: { $0.id == id }) {
            var deleted = doseLogs.remove(at: idx)
            deleted.syncState = .pendingDeletion
            deleted.updatedAt = Date()
            enqueueSyncMutation(
                entityType: "doseEvent",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - Compounds
    public func getAllCompounds() -> [Compound] { compounds }

    public func saveCompound(_ inputCompound: Compound) {
        var compound = inputCompound
        compound.updatedAt = Date()
        let isNew = !compounds.contains(where: { $0.id == compound.id })
        if isNew {
            if compound.syncState == .synced { compound.syncState = .pendingCreation }
        } else {
            if compound.syncState == .synced { compound.syncState = .pendingUpdate }
            compound.version += 1
        }

        if let idx = compounds.firstIndex(where: { $0.id == compound.id }) {
            compounds[idx] = compound
        } else {
            compounds.append(compound)
        }

        enqueueSyncMutation(
            entityType: "compound",
            entityId: compound.id,
            action: isNew ? .create : .update,
            entity: compound,
            version: compound.version
        )
    }

    public func deleteCompound(id: UUID) {
        if let idx = compounds.firstIndex(where: { $0.id == id }) {
            var deleted = compounds.remove(at: idx)
            deleted.syncState = .pendingDeletion
            enqueueSyncMutation(
                entityType: "compound",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - Protocols
    public func getAllProtocols() -> [ProtocolModel] { protocols }

    public func saveProtocol(_ inputProto: ProtocolModel) {
        var proto = inputProto
        proto.updatedAt = Date()
        let isNew = !protocols.contains(where: { $0.id == proto.id })
        if isNew {
            if proto.syncState == .synced { proto.syncState = .pendingCreation }
        } else {
            if proto.syncState == .synced { proto.syncState = .pendingUpdate }
            proto.version += 1
        }

        if let idx = protocols.firstIndex(where: { $0.id == proto.id }) {
            protocols[idx] = proto
        } else {
            protocols.append(proto)
        }

        enqueueSyncMutation(
            entityType: "protocol",
            entityId: proto.id,
            action: isNew ? .create : .update,
            entity: proto,
            version: proto.version
        )
    }

    public func deleteProtocol(id: UUID) {
        if let idx = protocols.firstIndex(where: { $0.id == id }) {
            var deleted = protocols.remove(at: idx)
            deleted.syncState = .pendingDeletion
            enqueueSyncMutation(
                entityType: "protocol",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - Vials
    public func getAllVials() -> [Vial] { vials }

    public func saveVial(_ inputVial: Vial) {
        var vial = inputVial
        vial.updatedAt = Date()
        let isNew = !vials.contains(where: { $0.id == vial.id })
        if isNew {
            if vial.syncState == .synced { vial.syncState = .pendingCreation }
        } else {
            if vial.syncState == .synced { vial.syncState = .pendingUpdate }
            vial.version += 1
        }

        if let idx = vials.firstIndex(where: { $0.id == vial.id }) {
            vials[idx] = vial
        } else {
            vials.append(vial)
        }

        enqueueSyncMutation(
            entityType: "vial",
            entityId: vial.id,
            action: isNew ? .create : .update,
            entity: vial,
            version: vial.version
        )
    }

    public func deleteVial(id: UUID) {
        if let idx = vials.firstIndex(where: { $0.id == id }) {
            var deleted = vials.remove(at: idx)
            deleted.syncState = .pendingDeletion
            enqueueSyncMutation(
                entityType: "vial",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - Supplies
    public func getAllSupplies() -> [SupplyItem] { supplies }

    public func saveSupply(_ inputItem: SupplyItem) {
        var item = inputItem
        item.updatedAt = Date()
        let isNew = !supplies.contains(where: { $0.id == item.id })
        if isNew {
            if item.syncState == .synced { item.syncState = .pendingCreation }
        } else {
            if item.syncState == .synced { item.syncState = .pendingUpdate }
            item.version += 1
        }

        if let idx = supplies.firstIndex(where: { $0.id == item.id }) {
            supplies[idx] = item
        } else {
            supplies.append(item)
        }

        enqueueSyncMutation(
            entityType: "supply",
            entityId: item.id,
            action: isNew ? .create : .update,
            entity: item,
            version: item.version
        )
    }

    public func deleteSupply(id: UUID) {
        if let idx = supplies.firstIndex(where: { $0.id == id }) {
            var deleted = supplies.remove(at: idx)
            deleted.syncState = .pendingDeletion
            enqueueSyncMutation(
                entityType: "supply",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - Biomarkers
    public func getAllBiomarkers() -> [Biomarker] { biomarkers }

    public func saveBiomarker(_ inputB: Biomarker) {
        var b = inputB
        b.updatedAt = Date()
        let isNew = !biomarkers.contains(where: { $0.id == b.id })
        if isNew {
            if b.syncState == .synced { b.syncState = .pendingCreation }
        } else {
            if b.syncState == .synced { b.syncState = .pendingUpdate }
            b.version += 1
        }

        if let idx = biomarkers.firstIndex(where: { $0.id == b.id }) {
            biomarkers[idx] = b
        } else {
            biomarkers.append(b)
        }

        enqueueSyncMutation(
            entityType: "biomarker",
            entityId: b.id,
            action: isNew ? .create : .update,
            entity: b,
            version: b.version
        )
    }

    public func deleteBiomarker(id: UUID) {
        if let idx = biomarkers.firstIndex(where: { $0.id == id }) {
            var deleted = biomarkers.remove(at: idx)
            deleted.syncState = .pendingDeletion
            enqueueSyncMutation(
                entityType: "biomarker",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - Symptoms
    public func getAllSymptoms() -> [SymptomLog] { symptomLogs }

    public func saveSymptom(_ inputS: SymptomLog) {
        var s = inputS
        s.updatedAt = Date()
        let isNew = !symptomLogs.contains(where: { $0.id == s.id })
        if isNew {
            if s.syncState == .synced { s.syncState = .pendingCreation }
        } else {
            if s.syncState == .synced { s.syncState = .pendingUpdate }
            s.version += 1
        }

        if let idx = symptomLogs.firstIndex(where: { $0.id == s.id }) {
            symptomLogs[idx] = s
        } else {
            symptomLogs.append(s)
        }

        enqueueSyncMutation(
            entityType: "symptomLog",
            entityId: s.id,
            action: isNew ? .create : .update,
            entity: s,
            version: s.version
        )
    }

    // MARK: - Costs
    public func getAllCosts() -> [CostRecord] { costs }

    public func saveCost(_ inputC: CostRecord) {
        var c = inputC
        c.updatedAt = Date()
        let isNew = !costs.contains(where: { $0.id == c.id })
        if isNew {
            if c.syncState == .synced { c.syncState = .pendingCreation }
        } else {
            if c.syncState == .synced { c.syncState = .pendingUpdate }
            c.version += 1
        }

        if let idx = costs.firstIndex(where: { $0.id == c.id }) {
            costs[idx] = c
        } else {
            costs.append(c)
        }

        enqueueSyncMutation(
            entityType: "costEvent",
            entityId: c.id,
            action: isNew ? .create : .update,
            entity: c,
            version: c.version
        )
    }

    public func deleteCost(id: UUID) {
        if let idx = costs.firstIndex(where: { $0.id == id }) {
            var deleted = costs.remove(at: idx)
            deleted.syncState = .pendingDeletion
            enqueueSyncMutation(
                entityType: "costEvent",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - Stored Files
    public func getAllStoredFiles() -> [StoredFileRecord] { storedFiles }

    public func saveStoredFile(_ inputFile: StoredFileRecord) {
        var file = inputFile
        file.updatedAt = Date()
        let isNew = !storedFiles.contains(where: { $0.id == file.id })
        if isNew {
            if file.syncState == .synced { file.syncState = .pendingCreation }
        } else {
            if file.syncState == .synced { file.syncState = .pendingUpdate }
            file.version += 1
        }

        if let idx = storedFiles.firstIndex(where: { $0.id == file.id }) {
            storedFiles[idx] = file
        } else {
            storedFiles.append(file)
        }

        enqueueSyncMutation(
            entityType: "storedFile",
            entityId: file.id,
            action: isNew ? .create : .update,
            entity: file,
            version: file.version
        )
    }

    public func deleteStoredFile(id: UUID) {
        if let idx = storedFiles.firstIndex(where: { $0.id == id }) {
            var deleted = storedFiles.remove(at: idx)
            deleted.syncState = .pendingDeletion
            enqueueSyncMutation(
                entityType: "storedFile",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - User
    public func getCurrentUser() -> User? { currentUser }

    public func saveUser(_ inputUser: User) {
        var user = inputUser
        user.updatedAt = Date()
        user.version += 1
        user.syncState = .pendingUpdate
        self.currentUser = user

        enqueueSyncMutation(
            entityType: "user",
            entityId: user.id,
            action: .update,
            entity: user,
            version: user.version
        )
    }

    public func updatePreferences(_ preferences: UserPreferences) {
        if var user = currentUser {
            user.preferences = preferences
            user.updatedAt = Date()
            user.version += 1
            user.syncState = .pendingUpdate
            self.currentUser = user
            enqueueSyncMutation(entityType: "user", entityId: user.id, action: .update, entity: user, version: user.version)
        }
    }

    public func updateNotificationPreferences(_ notificationPreferences: NotificationPreferences) {
        if var user = currentUser {
            user.notificationPreferences = notificationPreferences
            user.updatedAt = Date()
            user.version += 1
            user.syncState = .pendingUpdate
            self.currentUser = user
            enqueueSyncMutation(entityType: "user", entityId: user.id, action: .update, entity: user, version: user.version)
        }
    }

    public func updatePrivacyPreferences(_ privacyPreferences: PrivacyPreferences) {
        if var user = currentUser {
            user.privacyPreferences = privacyPreferences
            user.updatedAt = Date()
            user.version += 1
            user.syncState = .pendingUpdate
            self.currentUser = user
            enqueueSyncMutation(entityType: "user", entityId: user.id, action: .update, entity: user, version: user.version)
        }
    }

    public func updateUnits(_ units: UnitPreferences) {
        if var user = currentUser {
            user.units = units
            user.updatedAt = Date()
            user.version += 1
            user.syncState = .pendingUpdate
            self.currentUser = user
            enqueueSyncMutation(entityType: "user", entityId: user.id, action: .update, entity: user, version: user.version)
        }
    }

    public func deleteUser(id: UUID) {
        if currentUser?.id == id {
            currentUser = nil
        }
    }

    // MARK: - Injection Site Events
    public func getAllInjectionSiteEvents() -> [InjectionSiteEvent] { injectionSiteEvents }

    public func saveInjectionSiteEvent(_ inputEvent: InjectionSiteEvent) {
        var event = inputEvent
        event.updatedAt = Date()
        let isNew = !injectionSiteEvents.contains(where: { $0.id == event.id })
        if isNew {
            if event.syncState == .synced { event.syncState = .pendingCreation }
        } else {
            if event.syncState == .synced { event.syncState = .pendingUpdate }
            event.version += 1
        }

        if let idx = injectionSiteEvents.firstIndex(where: { $0.id == event.id }) {
            injectionSiteEvents[idx] = event
        } else {
            injectionSiteEvents.append(event)
        }

        enqueueSyncMutation(
            entityType: "injectionSiteEvent",
            entityId: event.id,
            action: isNew ? .create : .update,
            entity: event,
            version: event.version
        )
    }

    public func deleteInjectionSiteEvent(id: UUID) {
        if let idx = injectionSiteEvents.firstIndex(where: { $0.id == id }) {
            var deleted = injectionSiteEvents.remove(at: idx)
            deleted.syncState = .pendingDeletion
            enqueueSyncMutation(
                entityType: "injectionSiteEvent",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - Reconstitution Records
    public func getAllReconstitutionRecords() -> [ReconstitutionRecord] { reconstitutionRecords }

    public func saveReconstitutionRecord(_ inputRecord: ReconstitutionRecord) {
        var record = inputRecord
        record.updatedAt = Date()
        let isNew = !reconstitutionRecords.contains(where: { $0.id == record.id })
        if isNew {
            if record.syncState == .synced { record.syncState = .pendingCreation }
        } else {
            if record.syncState == .synced { record.syncState = .pendingUpdate }
            record.version += 1
        }

        if let idx = reconstitutionRecords.firstIndex(where: { $0.id == record.id }) {
            reconstitutionRecords[idx] = record
        } else {
            reconstitutionRecords.append(record)
        }

        enqueueSyncMutation(
            entityType: "reconstitutionRecord",
            entityId: record.id,
            action: isNew ? .create : .update,
            entity: record,
            version: record.version
        )
    }

    public func deleteReconstitutionRecord(id: UUID) {
        if let idx = reconstitutionRecords.firstIndex(where: { $0.id == id }) {
            var deleted = reconstitutionRecords.remove(at: idx)
            deleted.syncState = .pendingDeletion
            enqueueSyncMutation(
                entityType: "reconstitutionRecord",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - Measurements
    public func getAllMeasurements() -> [Measurement] { measurements }

    public func saveMeasurement(_ inputMeasurement: Measurement) {
        var measurement = inputMeasurement
        measurement.updatedAt = Date()
        let isNew = !measurements.contains(where: { $0.id == measurement.id })
        if isNew {
            if measurement.syncState == .synced { measurement.syncState = .pendingCreation }
        } else {
            if measurement.syncState == .synced { measurement.syncState = .pendingUpdate }
            measurement.version += 1
        }

        if let idx = measurements.firstIndex(where: { $0.id == measurement.id }) {
            measurements[idx] = measurement
        } else {
            measurements.append(measurement)
        }

        enqueueSyncMutation(
            entityType: "measurement",
            entityId: measurement.id,
            action: isNew ? .create : .update,
            entity: measurement,
            version: measurement.version
        )
    }

    public func deleteMeasurement(id: UUID) {
        if let idx = measurements.firstIndex(where: { $0.id == id }) {
            var deleted = measurements.remove(at: idx)
            deleted.syncState = .pendingDeletion
            enqueueSyncMutation(
                entityType: "measurement",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - Lab Panels
    public func getAllLabPanels() -> [LabPanel] { labPanels }

    public func saveLabPanel(_ inputPanel: LabPanel) {
        var panel = inputPanel
        panel.updatedAt = Date()
        let isNew = !labPanels.contains(where: { $0.id == panel.id })
        if isNew {
            if panel.syncState == .synced { panel.syncState = .pendingCreation }
        } else {
            if panel.syncState == .synced { panel.syncState = .pendingUpdate }
            panel.version += 1
        }

        if let idx = labPanels.firstIndex(where: { $0.id == panel.id }) {
            labPanels[idx] = panel
        } else {
            labPanels.append(panel)
        }

        enqueueSyncMutation(
            entityType: "labPanel",
            entityId: panel.id,
            action: isNew ? .create : .update,
            entity: panel,
            version: panel.version
        )
    }

    public func deleteLabPanel(id: UUID) {
        if let idx = labPanels.firstIndex(where: { $0.id == id }) {
            var deleted = labPanels.remove(at: idx)
            deleted.syncState = .pendingDeletion
            enqueueSyncMutation(
                entityType: "labPanel",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - Documents
    public func getAllDocuments() -> [Document] { documents }

    public func saveDocument(_ inputDoc: Document) {
        var doc = inputDoc
        doc.updatedAt = Date()
        let isNew = !documents.contains(where: { $0.id == doc.id })
        if isNew {
            if doc.syncState == .synced { doc.syncState = .pendingCreation }
        } else {
            if doc.syncState == .synced { doc.syncState = .pendingUpdate }
            doc.version += 1
        }

        if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
            documents[idx] = doc
        } else {
            documents.append(doc)
        }

        enqueueSyncMutation(
            entityType: "document",
            entityId: doc.id,
            action: isNew ? .create : .update,
            entity: doc,
            version: doc.version
        )
    }

    public func deleteDocument(id: UUID) {
        if let idx = documents.firstIndex(where: { $0.id == id }) {
            var deleted = documents.remove(at: idx)
            deleted.syncState = .pendingDeletion
            enqueueSyncMutation(
                entityType: "document",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - Outcome Metrics
    public func getAllOutcomeMetrics() -> [OutcomeMetric] { outcomeMetrics }

    public func saveOutcomeMetric(_ inputMetric: OutcomeMetric) {
        var metric = inputMetric
        metric.updatedAt = Date()
        let isNew = !outcomeMetrics.contains(where: { $0.id == metric.id })
        if isNew {
            if metric.syncState == .synced { metric.syncState = .pendingCreation }
        } else {
            if metric.syncState == .synced { metric.syncState = .pendingUpdate }
            metric.version += 1
        }

        if let idx = outcomeMetrics.firstIndex(where: { $0.id == metric.id }) {
            outcomeMetrics[idx] = metric
        } else {
            outcomeMetrics.append(metric)
        }

        enqueueSyncMutation(
            entityType: "outcomeMetric",
            entityId: metric.id,
            action: isNew ? .create : .update,
            entity: metric,
            version: metric.version
        )
    }

    public func deleteOutcomeMetric(id: UUID) {
        if let idx = outcomeMetrics.firstIndex(where: { $0.id == id }) {
            var deleted = outcomeMetrics.remove(at: idx)
            deleted.syncState = .pendingDeletion
            enqueueSyncMutation(
                entityType: "outcomeMetric",
                entityId: id,
                action: .delete,
                entity: deleted,
                version: deleted.version + 1
            )
        }
    }

    // MARK: - Synchronization Queue Operations
    public func enqueueSyncMutation<T: Encodable>(
        entityType: String,
        entityId: UUID,
        action: SyncAction,
        entity: T,
        version: Int = 1
    ) {
        let item = SyncQueueItem.create(
            entityType: entityType,
            entityId: entityId,
            action: action,
            entity: entity,
            version: version
        )
        syncQueue.append(item)
    }

    public func getPendingSyncQueue(limit: Int? = nil) -> [SyncQueueItem] {
        let pending = syncQueue.filter { $0.status == .pending || ($0.status == .failed && ($0.nextRetryAt ?? Date()) <= Date()) }
        if let limit = limit {
            return Array(pending.prefix(limit))
        }
        return pending
    }

    public func markSyncItemInFlight(id: UUID) {
        if let idx = syncQueue.firstIndex(where: { $0.id == id }) {
            syncQueue[idx].status = .inFlight
            syncQueue[idx].attempts += 1
        }
    }

    public func markSyncItemCompleted(id: UUID) {
        if let idx = syncQueue.firstIndex(where: { $0.id == id }) {
            let item = syncQueue[idx]
            syncQueue[idx].status = .completed
            
            // Mark matching entity in memory as .synced
            markEntitySynced(type: item.entityType, id: item.entityId)
        }
    }

    public func markSyncItemFailed(id: UUID, error: String, retryable: Bool) {
        if let idx = syncQueue.firstIndex(where: { $0.id == id }) {
            syncQueue[idx].lastError = error
            if retryable && syncQueue[idx].attempts < syncQueue[idx].maxAttempts {
                syncQueue[idx].status = .pending
                syncQueue[idx].nextRetryAt = Date().addingTimeInterval(syncQueue[idx].backoffDelaySeconds)
            } else {
                syncQueue[idx].status = .failed
                markEntitySyncFailed(type: syncQueue[idx].entityType, id: syncQueue[idx].entityId)
            }
        }
    }

    public func purgeCompletedSync() {
        syncQueue.removeAll { $0.status == .completed }
    }

    public func countPendingSync() -> Int {
        syncQueue.filter { $0.status == .pending || $0.status == .inFlight }.count
    }

    public func clearAllSyncQueue() {
        syncQueue.removeAll()
    }

    // MARK: - Internal Sync State Mutators
    private func markEntitySynced(type: String, id: UUID) {
        switch type {
        case "doseEvent":
            if let idx = doseLogs.firstIndex(where: { $0.id == id }) {
                doseLogs[idx].syncState = .synced
            }
        case "compound":
            if let idx = compounds.firstIndex(where: { $0.id == id }) {
                compounds[idx].syncState = .synced
            }
        case "protocol":
            if let idx = protocols.firstIndex(where: { $0.id == id }) {
                protocols[idx].syncState = .synced
            }
        case "vial":
            if let idx = vials.firstIndex(where: { $0.id == id }) {
                vials[idx].syncState = .synced
            }
        case "supply":
            if let idx = supplies.firstIndex(where: { $0.id == id }) {
                supplies[idx].syncState = .synced
            }
        case "biomarker":
            if let idx = biomarkers.firstIndex(where: { $0.id == id }) {
                biomarkers[idx].syncState = .synced
            }
        case "measurement":
            if let idx = measurements.firstIndex(where: { $0.id == id }) {
                measurements[idx].syncState = .synced
            }
        default:
            break
        }
    }

    private func markEntitySyncFailed(type: String, id: UUID) {
        switch type {
        case "doseEvent":
            if let idx = doseLogs.firstIndex(where: { $0.id == id }) {
                doseLogs[idx].syncState = .syncFailed
            }
        case "vial":
            if let idx = vials.firstIndex(where: { $0.id == id }) {
                vials[idx].syncState = .syncFailed
            }
        default:
            break
        }
    }
}
