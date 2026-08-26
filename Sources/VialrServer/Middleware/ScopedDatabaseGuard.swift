import Vapor
import Fluent

/// Protocol adopted by database entities that belong to a specific user.
public protocol UserOwnedModel: Model {
    static var userKeyPath: KeyPath<Self, Parent<UserEntity>> { get }
}

// MARK: - Standard User-Owned Entity Conformances

extension CompoundEntity: UserOwnedModel {
    public static var userKeyPath: KeyPath<CompoundEntity, Parent<UserEntity>> { \.$user }
}

extension ProtocolEntity: UserOwnedModel {
    public static var userKeyPath: KeyPath<ProtocolEntity, Parent<UserEntity>> { \.$user }
}

extension DoseLogEntity: UserOwnedModel {
    public static var userKeyPath: KeyPath<DoseLogEntity, Parent<UserEntity>> { \.$user }
}

extension VialEntity: UserOwnedModel {
    public static var userKeyPath: KeyPath<VialEntity, Parent<UserEntity>> { \.$user }
}

extension StoredFileEntity: UserOwnedModel {
    public static var userKeyPath: KeyPath<StoredFileEntity, Parent<UserEntity>> { \.$user }
}

extension MeasurementEntity: UserOwnedModel {
    public static var userKeyPath: KeyPath<MeasurementEntity, Parent<UserEntity>> { \.$user }
}

extension SupplyItemEntity: UserOwnedModel {
    public static var userKeyPath: KeyPath<SupplyItemEntity, Parent<UserEntity>> { \.$user }
}

extension ReconstitutionRecordEntity: UserOwnedModel {
    public static var userKeyPath: KeyPath<ReconstitutionRecordEntity, Parent<UserEntity>> { \.$user }
}

extension BiomarkerEntity: UserOwnedModel {
    public static var userKeyPath: KeyPath<BiomarkerEntity, Parent<UserEntity>> { \.$user }
}

extension LabPanelEntity: UserOwnedModel {
    public static var userKeyPath: KeyPath<LabPanelEntity, Parent<UserEntity>> { \.$user }
}

extension SymptomLogEntity: UserOwnedModel {
    public static var userKeyPath: KeyPath<SymptomLogEntity, Parent<UserEntity>> { \.$user }
}

extension InjectionSiteEventEntity: UserOwnedModel {
    public static var userKeyPath: KeyPath<InjectionSiteEventEntity, Parent<UserEntity>> { \.$user }
}

extension BackgroundJobEntity: UserOwnedModel {
    public static var userKeyPath: KeyPath<BackgroundJobEntity, Parent<UserEntity>> { \.$user }
}

// MARK: - QueryBuilder User Scoping Extensions

public extension QueryBuilder where Model: UserOwnedModel {
    /// Strictly scopes the database query to the specified user identifier.
    /// Eliminates cross-tenant data leakage by enforcing relational user ownership filter at the SQL query level.
    @discardableResult
    func scoped(to userId: UUID) -> Self {
        return self.filter(Model.userKeyPath, \.$id == userId)
    }

    /// Automatically extracts the authenticated user's ID from the request token
    /// and scopes the query exclusively to that user.
    @discardableResult
    func scoped(to req: Request) throws -> Self {
        let userId = try req.authenticatedUserId
        return self.scoped(to: userId)
    }
}

// MARK: - Request Scoped Query Helpers

public extension Request {
    /// Creates a Fluent QueryBuilder for the given UserOwnedModel strictly scoped to the authenticated caller.
    func scopedQuery<M: UserOwnedModel>(_ modelType: M.Type) throws -> QueryBuilder<M> {
        let userId = try self.authenticatedUserId
        return M.query(on: self.db).scoped(to: userId)
    }

    /// Safely finds a user-owned entity by its primary ID, guaranteeing it belongs exclusively to the caller.
    /// Returns nil (or 404) if the record does not exist OR if it belongs to another user.
    func findUserOwned<M: UserOwnedModel>(_ modelType: M.Type, id: UUID) async throws -> M? {
        let userId = try self.authenticatedUserId
        guard let entity = try await M.find(id, on: self.db) else {
            return nil
        }
        guard entity[keyPath: M.userKeyPath].id == userId else {
            return nil
        }
        return entity
    }

    /// Finds a user-owned entity by its primary ID, throwing 404 Not Found if missing or unowned.
    func requireUserOwned<M: UserOwnedModel>(_ modelType: M.Type, id: UUID, notFoundReason: String = "\(M.schema) not found.") async throws -> M {
        guard let entity = try await findUserOwned(modelType, id: id) else {
            throw Abort(.notFound, reason: notFoundReason)
        }
        return entity
    }
}
