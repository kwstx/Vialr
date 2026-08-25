import Fluent
import Vapor

public final class SupplyItemEntity: Model, Content, @unchecked Sendable {
    public static let schema = "supply_items"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Field(key: "name")
    public var name: String

    @Field(key: "category")
    public var category: String

    @Field(key: "quantity_remaining")
    public var quantityRemaining: Int

    @Field(key: "package_unit")
    public var packageUnit: String

    @Field(key: "reorder_threshold")
    public var reorderThreshold: Int

    @Field(key: "cost_usd")
    public var costUsd: Double?

    @Field(key: "notes")
    public var notes: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userId: UUID,
        name: String,
        category: String,
        quantityRemaining: Int,
        packageUnit: String = "pieces",
        reorderThreshold: Int = 10,
        costUsd: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.name = name
        self.category = category
        self.quantityRemaining = quantityRemaining
        self.packageUnit = packageUnit
        self.reorderThreshold = reorderThreshold
        self.costUsd = costUsd
        self.notes = notes
    }
}
