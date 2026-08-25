import Fluent
import Vapor

public final class ProtocolEntity: Model, Content, @unchecked Sendable {
    public static let schema = "protocols"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Parent(key: "compound_id")
    public var compound: CompoundEntity

    @Field(key: "name")
    public var name: String

    @Field(key: "schedule_frequency")
    public var scheduleFrequency: String

    @Field(key: "dose_amount")
    public var doseAmount: Double

    @Field(key: "dose_unit")
    public var doseUnit: String

    @Field(key: "cycle_duration_weeks")
    public var cycleDurationWeeks: Int

    @Field(key: "start_date")
    public var startDate: Date

    @Field(key: "end_date")
    public var endDate: Date?

    @Field(key: "notes")
    public var notes: String?

    @Field(key: "status")
    public var status: String

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userId: UUID,
        compoundId: UUID,
        name: String,
        scheduleFrequency: String,
        doseAmount: Double,
        doseUnit: String,
        cycleDurationWeeks: Int,
        startDate: Date,
        endDate: Date? = nil,
        notes: String? = nil,
        status: String = "active"
    ) {
        self.id = id
        self.$user.id = userId
        self.$compound.id = compoundId
        self.name = name
        self.scheduleFrequency = scheduleFrequency
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.cycleDurationWeeks = cycleDurationWeeks
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.status = status
    }
}
