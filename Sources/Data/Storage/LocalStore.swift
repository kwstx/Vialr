import Foundation
import Domain

/// Thread-safe in-memory and local persistent store using Swift actor.
public actor LocalStore {
    public static let shared = LocalStore()

    public var compounds: [Compound] = []
    public var protocols: [ProtocolModel] = []
    public var doseLogs: [DoseLog] = []
    public var vials: [Vial] = []
    public var supplies: [SupplyItem] = []
    public var biomarkers: [Biomarker] = []
    public var symptomLogs: [SymptomLog] = []
    public var costs: [CostRecord] = []

    private var isInitialized = false

    public init() {}

    public func initializeWithMockDataIfNeeded() {
        guard !isInitialized else { return }
        let mock = MockDataFactory()
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

    // MARK: - Compounds
    public func getAllCompounds() -> [Compound] { compounds }
    public func saveCompound(_ compound: Compound) {
        if let idx = compounds.firstIndex(where: { $0.id == compound.id }) {
            compounds[idx] = compound
        } else {
            compounds.append(compound)
        }
    }
    public func deleteCompound(id: UUID) {
        compounds.removeAll { $0.id == id }
    }

    // MARK: - Protocols
    public func getAllProtocols() -> [ProtocolModel] { protocols }
    public func saveProtocol(_ proto: ProtocolModel) {
        if let idx = protocols.firstIndex(where: { $0.id == proto.id }) {
            protocols[idx] = proto
        } else {
            protocols.append(proto)
        }
    }
    public func deleteProtocol(id: UUID) {
        protocols.removeAll { $0.id == id }
    }

    // MARK: - Dose Logs
    public func getAllDoseLogs() -> [DoseLog] { doseLogs }
    public func saveDoseLog(_ log: DoseLog) {
        if let idx = doseLogs.firstIndex(where: { $0.id == log.id }) {
            doseLogs[idx] = log
        } else {
            doseLogs.append(log)
        }
        
        // If dose was taken and associated with a vial, deduct volume
        if log.status == .taken, let vId = log.vialId, let vIdx = vials.firstIndex(where: { $0.id == vId }) {
            var v = vials[vIdx]
            if let conc = v.concentrationMgMl, conc > 0, let rem = v.currentVolumeRemainingMl {
                let doseMg = log.doseUnit == .mg ? log.doseAmount : (log.doseAmount / 1000.0)
                let volMl = doseMg / conc
                v.currentVolumeRemainingMl = max(0.0, rem - volMl)
                if v.currentVolumeRemainingMl == 0 {
                    v.status = .depleted
                }
                vials[vIdx] = v
            }
        }
    }
    public func deleteDoseLog(id: UUID) {
        doseLogs.removeAll { $0.id == id }
    }

    // MARK: - Vials
    public func getAllVials() -> [Vial] { vials }
    public func saveVial(_ vial: Vial) {
        if let idx = vials.firstIndex(where: { $0.id == vial.id }) {
            vials[idx] = vial
        } else {
            vials.append(vial)
        }
    }
    public func deleteVial(id: UUID) {
        vials.removeAll { $0.id == id }
    }

    // MARK: - Supplies
    public func getAllSupplies() -> [SupplyItem] { supplies }
    public func saveSupply(_ item: SupplyItem) {
        if let idx = supplies.firstIndex(where: { $0.id == item.id }) {
            supplies[idx] = item
        } else {
            supplies.append(item)
        }
    }
    public func deleteSupply(id: UUID) {
        supplies.removeAll { $0.id == id }
    }

    // MARK: - Biomarkers
    public func getAllBiomarkers() -> [Biomarker] { biomarkers }
    public func saveBiomarker(_ b: Biomarker) {
        if let idx = biomarkers.firstIndex(where: { $0.id == b.id }) {
            biomarkers[idx] = b
        } else {
            biomarkers.append(b)
        }
    }
    public func deleteBiomarker(id: UUID) {
        biomarkers.removeAll { $0.id == id }
    }

    // MARK: - Symptoms
    public func getAllSymptoms() -> [SymptomLog] { symptomLogs }
    public func saveSymptom(_ s: SymptomLog) {
        if let idx = symptomLogs.firstIndex(where: { $0.id == s.id }) {
            symptomLogs[idx] = s
        } else {
            symptomLogs.append(s)
        }
    }

    // MARK: - Costs
    public func getAllCosts() -> [CostRecord] { costs }
    public func saveCost(_ c: CostRecord) {
        if let idx = costs.firstIndex(where: { $0.id == c.id }) {
            costs[idx] = c
        } else {
            costs.append(c)
        }
    }
}
