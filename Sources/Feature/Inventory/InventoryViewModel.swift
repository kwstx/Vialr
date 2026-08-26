import SwiftUI
import Observation
import Domain
import CalculationEngine
import Data

@Observable
public final class InventoryViewModel: @unchecked Sendable {
    public var vials: [Vial] = []
    public var supplies: [SupplyItem] = []
    public var forecasts: [InventoryDepletionCalculator.VialDepletionForecast] = []
    public var accountingStates: [UUID: VialAccountingState] = [:]
    public var allEvents: [InventoryEvent] = []
    public var selectedCategory: String = "All"
    public var isLoading: Bool = false
    public var errorMessage: String?

    private let vialRepo: VialRepositoryProtocol
    private let supplyRepo: SupplyRepositoryProtocol
    private let protocolRepo: ProtocolRepositoryProtocol
    private let inventoryEventRepo: InventoryEventRepositoryProtocol
    private let depletionCalculator = InventoryDepletionCalculator()
    private let accountingEngine = InventoryAccountingEngine()

    public init(
        vialRepo: VialRepositoryProtocol = LocalVialRepository(),
        supplyRepo: SupplyRepositoryProtocol = LocalSupplyRepository(),
        protocolRepo: ProtocolRepositoryProtocol = LocalProtocolRepository(),
        inventoryEventRepo: InventoryEventRepositoryProtocol = LocalInventoryEventRepository()
    ) {
        self.vialRepo = vialRepo
        self.supplyRepo = supplyRepo
        self.protocolRepo = protocolRepo
        self.inventoryEventRepo = inventoryEventRepo
    }

    public func loadInventory() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            vials = try await vialRepo.fetchAll()
            supplies = try await supplyRepo.fetchAll()
            allEvents = try await inventoryEventRepo.fetchAll()
            let activeProtocols = try await protocolRepo.fetchActive()
            forecasts = depletionCalculator.forecastVials(vials: vials, activeProtocols: activeProtocols)

            // Calculate exact event-sourced accounting state for every vial
            var states: [UUID: VialAccountingState] = [:]
            for vial in vials {
                let vialEvents = allEvents.filter { $0.vialId == vial.id }
                states[vial.id] = accountingEngine.calculateVialState(vial: vial, events: vialEvents)
            }
            self.accountingStates = states
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load inventory: \(error)")
        }
    }

    public func addVial(_ vial: Vial) async {
        do {
            try await vialRepo.save(vial)

            // 1. Record Initial Stock event in accounting ledger
            let (initialEvent, _) = accountingEngine.recordInitialStock(
                vial: vial,
                initialDryMassMg: vial.totalDryMassMg,
                notes: vial.notes
            )
            try await inventoryEventRepo.save(initialEvent)

            // 2. If vial is pre-reconstituted, record Reconstitution event
            if vial.isReconstituted, let diluentMl = vial.bacWaterAddedMl, diluentMl > 0 {
                let (reconEvent, _) = accountingEngine.recordReconstitution(
                    vial: vial,
                    existingEvents: [initialEvent],
                    diluentVolumeMl: diluentMl,
                    dryMassMg: vial.totalDryMassMg,
                    notes: "Initial reconstitution on vial creation"
                )
                try await inventoryEventRepo.save(reconEvent)
            }

            await loadInventory()
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to save vial: \(error)")
        }
    }

    public func reconcileVial(
        vialId: UUID,
        observedVolumeMl: Double,
        reason: ReconciliationReason,
        notes: String
    ) async {
        guard let vial = vials.first(where: { $0.id == vialId }) else { return }
        do {
            let vialEvents = try await inventoryEventRepo.fetchForVial(vialId: vialId)
            let (adjEvent, updatedState) = accountingEngine.reconcileVial(
                vial: vial,
                existingEvents: vialEvents,
                observedVolumeRemainingMl: observedVolumeMl,
                reason: reason,
                notes: notes,
                timestamp: Date()
            )
            try await inventoryEventRepo.save(adjEvent)

            // Update cached vial entity
            var updatedVial = vial
            updatedVial.currentVolumeRemainingMl = updatedState.currentVolumeRemainingMl
            updatedVial.status = updatedState.status
            updatedVial.updatedAt = Date()
            updatedVial.version += 1
            try await vialRepo.save(updatedVial)

            await loadInventory()
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to reconcile vial: \(error)")
        }
    }

    public func reconstituteVial(
        vialId: UUID,
        diluentVolumeMl: Double,
        dryMassMg: Double? = nil,
        diluentType: DiluentType = .bacteriostaticWater,
        notes: String = ""
    ) async {
        guard let vial = vials.first(where: { $0.id == vialId }) else { return }
        do {
            let vialEvents = try await inventoryEventRepo.fetchForVial(vialId: vialId)
            let (reconEvent, updatedState) = accountingEngine.recordReconstitution(
                vial: vial,
                existingEvents: vialEvents,
                diluentVolumeMl: diluentVolumeMl,
                dryMassMg: dryMassMg,
                diluentType: diluentType,
                timestamp: Date(),
                notes: notes
            )
            try await inventoryEventRepo.save(reconEvent)

            var updatedVial = vial
            updatedVial.isReconstituted = true
            updatedVial.bacWaterAddedMl = diluentVolumeMl
            updatedVial.currentVolumeRemainingMl = updatedState.currentVolumeRemainingMl
            updatedVial.reconstitutedDate = updatedState.reconstitutedDate
            updatedVial.expirationDate = updatedState.expirationDate
            updatedVial.status = updatedState.status
            updatedVial.updatedAt = Date()
            updatedVial.version += 1
            try await vialRepo.save(updatedVial)

            await loadInventory()
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to reconstitute vial: \(error)")
        }
    }

    public func disposeVial(
        vialId: UUID,
        reason: DisposalReason,
        notes: String = ""
    ) async {
        guard let vial = vials.first(where: { $0.id == vialId }) else { return }
        do {
            let vialEvents = try await inventoryEventRepo.fetchForVial(vialId: vialId)
            let (dispEvent, updatedState) = accountingEngine.recordDisposal(
                vial: vial,
                existingEvents: vialEvents,
                reason: reason,
                notes: notes,
                timestamp: Date()
            )
            try await inventoryEventRepo.save(dispEvent)

            var updatedVial = vial
            updatedVial.currentVolumeRemainingMl = 0.0
            updatedVial.status = updatedState.status
            updatedVial.discardDate = updatedState.discardDate
            updatedVial.updatedAt = Date()
            updatedVial.version += 1
            try await vialRepo.save(updatedVial)

            await loadInventory()
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to dispose vial: \(error)")
        }
    }

    public func updateSupplyQuantity(item: SupplyItem, delta: Int, reason: String = "Manual adjustment") async {
        var updated = item
        let newQty = max(0, item.quantityRemaining + delta)
        updated.quantityRemaining = newQty
        updated.updatedAt = Date()
        do {
            try await supplyRepo.save(updated)

            // Record supply inventory event
            let event = InventoryEvent(
                supplyItemId: item.id,
                eventType: delta >= 0 ? .restock : .doseConsumption,
                timestamp: Date(),
                reason: reason,
                changeQuantityCount: delta
            )
            try await inventoryEventRepo.save(event)

            await loadInventory()
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to update supply: \(error)")
        }
    }

    public func getAuditTrail(for vialId: UUID) -> [InventoryEvent] {
        allEvents.filter { $0.vialId == vialId }.sorted(by: { $0.timestamp < $1.timestamp })
    }

    public func getAccountingState(for vialId: UUID) -> VialAccountingState? {
        accountingStates[vialId]
    }
}
