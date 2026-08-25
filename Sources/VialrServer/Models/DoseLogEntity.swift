import Fluent
import Vapor

public final class DoseLogEntity: Model, Content, @unchecked Sendable {
    public static let schema = "dose_logs"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @OptionalParent(key: "protocol_id")
    public var protocolModel: ProtocolEntity?

    @Parent(key: "compound_id")
    public var compound: CompoundEntity

    @Field(key: "scheduled_date")
    public var scheduledDate: Date

    @Field(key: "administered_date")
    public var administeredDate: Date?

    @Field(key: "dose_amount")
    public var doseAmount: Double

    @Field(key: "dose_unit")
    public var doseUnit: String

    @Field(key: "injection_site")
    public var injectionSite: String?

    @Field(key: "status")
    public var status: String

    @Field(key: "notes")
    public var notes: String?

    @Field(key: "pain_score")
    public var painScore: Int?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userId: UUID,
        protocolId: UUID? = nil,
        compoundId: UUID,
        scheduledDate: Date,
        administeredDate: Date? = nil,
        doseAmount: Double,
        doseUnit: String,
        injectionSite: String? = nil,
        status: String = "scheduled",
        notes: String? = nil,
        painScore: Int? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.$protocolModel.id = protocolId
        self.$compound.id = compoundId
        self.scheduledDate = scheduledDate
        self.administeredDate = administeredDate
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.injectionSite = injectionSite
        self.status = status
        self.notes = notes
        self.painScore = painScore
    }
}
