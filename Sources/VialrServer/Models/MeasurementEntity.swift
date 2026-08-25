import Fluent
import Vapor

public final class MeasurementEntity: Model, Content, @unchecked Sendable {
    public static let schema = "measurements"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @OptionalParent(key: "protocol_id")
    public var associatedProtocol: ProtocolEntity?

    @Field(key: "name")
    public var name: String

    @Field(key: "type")
    public var type: String

    @Field(key: "category")
    public var category: String

    @Field(key: "value")
    public var value: Double

    @Field(key: "secondary_value")
    public var secondaryValue: Double?

    @Field(key: "unit")
    public var unit: String

    @Field(key: "date_recorded")
    public var dateRecorded: Date

    @Field(key: "source")
    public var source: String

    @Field(key: "reference_range_min")
    public var referenceRangeMin: Double?

    @Field(key: "reference_range_max")
    public var referenceRangeMax: Double?

    @Field(key: "status")
    public var status: String

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
        associatedProtocolId: UUID? = nil,
        name: String,
        type: String,
        category: String,
        value: Double,
        secondaryValue: Double? = nil,
        unit: String,
        dateRecorded: Date = Date(),
        source: String = "Manual Entry",
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        status: String = "Optimal / Normal",
        notes: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.$associatedProtocol.id = associatedProtocolId
        self.name = name
        self.type = type
        self.category = category
        self.value = value
        self.secondaryValue = secondaryValue
        self.unit = unit
        self.dateRecorded = dateRecorded
        self.source = source
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.status = status
        self.notes = notes
    }
}
