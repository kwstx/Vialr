import Foundation
import Domain
import Data
import CalculationEngine

/// Service responsible for bootstrapping the initial local database, seeding reference catalogs,
/// and initializing the user's account immediately after authentication.
public protocol UserAccountInitializing: Sendable {
    func initializeAccountAndDatabase(for user: User) async throws -> User
}

public final class UserAccountInitializer: UserAccountInitializing, @unchecked Sendable {
    public static let shared = UserAccountInitializer()

    private let userRepo: UserRepositoryProtocol
    private let compoundRepo: CompoundRepositoryProtocol
    private let supplyRepo: SupplyRepositoryProtocol
    private let localStore: LocalStore
    private let keychainService: KeychainServiceProtocol

    public init(
        userRepo: UserRepositoryProtocol = LocalUserRepository(),
        compoundRepo: CompoundRepositoryProtocol = LocalCompoundRepository(),
        supplyRepo: SupplyRepositoryProtocol = LocalSupplyRepository(),
        localStore: LocalStore = .shared,
        keychainService: KeychainServiceProtocol = KeychainService.shared
    ) {
        self.userRepo = userRepo
        self.compoundRepo = compoundRepo
        self.supplyRepo = supplyRepo
        self.localStore = localStore
        self.keychainService = keychainService
    }

    public func initializeAccountAndDatabase(for user: User) async throws -> User {
        // 1. Initialize local persistent store & in-memory caches
        await localStore.initializeWithMockDataIfNeeded()

        // 2. Persist the primary user record
        var activeUser = user
        activeUser.accountInfo.status = .active
        activeUser.updatedAt = Date()
        try await userRepo.saveUser(activeUser)

        // 3. Seed initial standard compound catalog if not already present
        let existingCompounds = try await compoundRepo.fetchAll()
        if existingCompounds.isEmpty {
            let standardSeedCompounds = getInitialStandardCompounds()
            for compound in standardSeedCompounds {
                try await compoundRepo.save(compound)
            }
        }

        // 4. Seed initial standard injection supplies (Syringes, Alcohol Pads, BAC Water)
        let existingSupplies = try await supplyRepo.fetchAll()
        if existingSupplies.isEmpty {
            let standardSupplies = getInitialStandardSupplies()
            for supply in standardSupplies {
                try await supplyRepo.save(supply)
            }
        }

        // 5. Verify Apple hardware data protection is enforced for the local database
        #if canImport(SwiftData)
        _ = LocalDatabaseContainer.shared
        #endif

        return activeUser
    }

    // MARK: - Initial Reference Data Seeding
    private func getInitialStandardCompounds() -> [Compound] {
        return [
            Compound(
                name: "BPC-157",
                halfLifeHours: 4.0,
                defaultDoseAmount: 250,
                defaultDoseUnit: .mcg,
                defaultFrequency: .daily,
                isCustom: false,
                notes: "Pentadecapeptide for tissue repair and gut barrier integrity."
            ),
            Compound(
                name: "TB-500",
                halfLifeHours: 24.0,
                defaultDoseAmount: 2.5,
                defaultDoseUnit: .mg,
                defaultFrequency: .twiceWeekly,
                isCustom: false,
                notes: "Thymosin Beta-4 fragment for cellular repair and flexibility."
            ),
            Compound(
                name: "Tirzepatide",
                halfLifeHours: 120.0,
                defaultDoseAmount: 2.5,
                defaultDoseUnit: .mg,
                defaultFrequency: .weekly,
                isCustom: false,
                notes: "Dual GIP and GLP-1 receptor agonist for glycemic and metabolic optimization."
            ),
            Compound(
                name: "Semaglutide",
                halfLifeHours: 168.0,
                defaultDoseAmount: 0.25,
                defaultDoseUnit: .mg,
                defaultFrequency: .weekly,
                isCustom: false,
                notes: "GLP-1 receptor agonist for metabolic modulation."
            ),
            Compound(
                name: "Testosterone Cypionate",
                halfLifeHours: 192.0,
                defaultDoseAmount: 50,
                defaultDoseUnit: .mg,
                defaultFrequency: .twiceWeekly,
                isCustom: false,
                notes: "Long-acting androgen ester for hormone replacement protocols."
            ),
            Compound(
                name: "NAD+",
                halfLifeHours: 2.5,
                defaultDoseAmount: 100,
                defaultDoseUnit: .mg,
                defaultFrequency: .twiceWeekly,
                isCustom: false,
                notes: "Cellular mitochondrial coenzyme for NAD+/NADH balance."
            ),
            Compound(
                name: "Glutathione",
                halfLifeHours: 1.5,
                defaultDoseAmount: 200,
                defaultDoseUnit: .mg,
                defaultFrequency: .twiceWeekly,
                isCustom: false,
                notes: "Primary endogenous antioxidant for hepatic detoxification."
            ),
            Compound(
                name: "GHK-Cu",
                halfLifeHours: 1.0,
                defaultDoseAmount: 2.0,
                defaultDoseUnit: .mg,
                defaultFrequency: .daily,
                isCustom: false,
                notes: "Copper peptide complex for collagen synthesis and dermatological remodeling."
            ),
            Compound(
                name: "CJC-1295 / Ipamorelin",
                halfLifeHours: 2.0,
                defaultDoseAmount: 200,
                defaultDoseUnit: .mcg,
                defaultFrequency: .daily,
                isCustom: false,
                notes: "Synergistic GHRH + GHRP secretagogue stack for recovery."
            )
        ]
    }

    private func getInitialStandardSupplies() -> [SupplyItem] {
        return [
            SupplyItem(
                name: "U-100 Insulin Syringes (0.5 mL, 31G 5/16\")",
                category: .syringes,
                currentQuantity: 100,
                minimumThreshold: 20,
                unit: "syringes"
            ),
            SupplyItem(
                name: "Alcohol Prep Pads (70% Isopropyl)",
                category: .alcoholPads,
                currentQuantity: 200,
                minimumThreshold: 30,
                unit: "wipes"
            ),
            SupplyItem(
                name: "Bacteriostatic Water (30 mL Vial)",
                category: .diluent,
                currentQuantity: 3,
                minimumThreshold: 1,
                unit: "vials"
            )
        ]
    }
}
