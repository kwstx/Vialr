import Fluent
import Vapor

public final class CompoundEntity: Model, Content, @unchecked Sendable {
    public static let schema = "compounds"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Field(key: "name")
    public var name: String

    @Field(key: "category")
    public var category: String

    @Field(key: "default_dose")
    public var defaultDose: Double

    @Field(key: "default_unit")
    public var defaultUnit: String

    @Field(key: "half_life_hours")
    public var halfLifeHours: Double

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
        defaultDose: Double,
        defaultUnit: String,
        halfLifeHours: Double,
        notes: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.name = name
        self.category = category
        self.defaultDose = defaultDose
        self.defaultUnit = defaultUnit
        self.halfLifeHours = halfLifeHours
        self.notes = notes
    }
}
