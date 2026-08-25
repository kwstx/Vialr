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
    public var selectedCategory: String = "All"
    public var isLoading: Bool = false

    private let vialRepo: VialRepositoryProtocol
    private let supplyRepo: SupplyRepositoryProtocol
    private let protocolRepo: ProtocolRepositoryProtocol
    private let depletionCalculator = InventoryDepletionCalculator()

    public init(
        vialRepo: VialRepositoryProtocol = LocalVialRepository(),
        supplyRepo: SupplyRepositoryProtocol = LocalSupplyRepository(),
        protocolRepo: ProtocolRepositoryProtocol = LocalProtocolRepository()
    ) {
        self.vialRepo = vialRepo
        self.supplyRepo = supplyRepo
        self.protocolRepo = protocolRepo
    }

    public func loadInventory() async {
        isLoading = true
        defer { isLoading = false }
        do {
            vials = try await vialRepo.fetchAll()
            supplies = try await supplyRepo.fetchAll()
            let activeProtocols = try await protocolRepo.fetchActive()
            forecasts = depletionCalculator.forecastVials(vials: vials, activeProtocols: activeProtocols)
        } catch {
            print("Failed to load inventory: \(error)")
        }
    }

    public func addVial(_ vial: Vial) async {
        do {
            try await vialRepo.save(vial)
            await loadInventory()
        } catch {
            print("Failed to save vial: \(error)")
        }
    }

    public func updateSupplyQuantity(item: SupplyItem, delta: Int) async {
        var updated = item
        updated.quantityRemaining = max(0, item.quantityRemaining + delta)
        updated.updatedAt = Date()
        do {
            try await supplyRepo.save(updated)
            await loadInventory()
        } catch {
            print("Failed to update supply: \(error)")
        }
    }
}
