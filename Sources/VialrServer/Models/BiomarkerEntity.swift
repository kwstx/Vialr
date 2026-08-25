import Fluent
import Vapor

public final class BiomarkerEntity: Model, Content, @unchecked Sendable {
    public static let schema = "biomarkers"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Field(key: "name")
    public var name: String

    @Field(key: "value")
    public var value: Double

    @Field(key: "unit")
    public var unit: String

    @Field(key: "reference_range_min")
    public var referenceRangeMin: Double?

    @Field(key: "reference_range_max")
    public var referenceRangeMax: Double?

    @Field(key: "test_date")
    public var testDate: Date

    @Field(key: "lab_name")
    public var labName: String?

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
        value: Double,
        unit: String,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        testDate: Date,
        labName: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.name = name
        self.value = value
        self.unit = unit
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.testDate = testDate
        self.labName = labName
        self.notes = notes
    }
}
