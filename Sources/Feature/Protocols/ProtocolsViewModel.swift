import SwiftUI
import Observation
import Domain
import Data

@Observable
public final class ProtocolsViewModel: @unchecked Sendable {
    public var allProtocols: [ProtocolModel] = []
    public var selectedFilter: ProtocolFilter = .active
    public var isLoading: Bool = false
    public var selectedProtocolForDetail: ProtocolModel?

    private let protocolRepo: ProtocolRepositoryProtocol

    public init(protocolRepo: ProtocolRepositoryProtocol = LocalProtocolRepository()) {
        self.protocolRepo = protocolRepo
    }

    public func loadProtocols() async {
        isLoading = true
        defer { isLoading = false }
        do {
            allProtocols = try await protocolRepo.fetchAll()
        } catch {
            print("Failed to load protocols: \(error)")
        }
    }

    public var filteredProtocols: [ProtocolModel] {
        switch selectedFilter {
        case .all:
            return allProtocols
        case .active:
            return allProtocols.filter { $0.status == .active }
        case .paused:
            return allProtocols.filter { $0.status == .paused }
        case .completed:
            return allProtocols.filter { $0.status == .completed }
        }
    }

    public func saveProtocol(_ model: ProtocolModel) async {
        do {
            try await protocolRepo.save(model)
            await loadProtocols()
        } catch {
            print("Failed to save protocol: \(error)")
        }
    }

    public func deleteProtocol(id: UUID) async {
        do {
            try await protocolRepo.delete(byId: id)
            await loadProtocols()
        } catch {
            print("Failed to delete protocol: \(error)")
        }
    }
}

public enum ProtocolFilter: String, CaseIterable, Identifiable, CustomStringConvertible {
    case active = "Active"
    case all = "All"
    case paused = "Paused"
    case completed = "History"

    public var id: String { rawValue }
    public var description: String { rawValue }
}
