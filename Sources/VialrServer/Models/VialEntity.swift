import Fluent
import Vapor

public final class VialEntity: Model, Content, @unchecked Sendable {
    public static let schema = "vials"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Parent(key: "compound_id")
    public var compound: CompoundEntity

    @Field(key: "lot_number")
    public var lotNumber: String?

    @Field(key: "dry_mass_mg")
    public var dryMassMg: Double

    @Field(key: "diluent_volume_ml")
    public var diluentVolumeMl: Double?

    @Field(key: "concentration_mg_ml")
    public var concentrationMgMl: Double?

    @Field(key: "current_volume_remaining_ml")
    public var currentVolumeRemainingMl: Double?

    @Field(key: "expiration_date")
    public var expirationDate: Date?

    @Field(key: "cost_usd")
    public var costUsd: Double?

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
        compoundId: UUID,
        lotNumber: String? = nil,
        dryMassMg: Double,
        diluentVolumeMl: Double? = nil,
        concentrationMgMl: Double? = nil,
        currentVolumeRemainingMl: Double? = nil,
        expirationDate: Date? = nil,
        costUsd: Double? = nil,
        status: String = "unreconstituted",
        notes: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.$compound.id = compoundId
        self.lotNumber = lotNumber
        self.dryMassMg = dryMassMg
        self.diluentVolumeMl = diluentVolumeMl
        self.concentrationMgMl = concentrationMgMl
        self.currentVolumeRemainingMl = currentVolumeRemainingMl
        self.expirationDate = expirationDate
        self.costUsd = costUsd
        self.status = status
        self.notes = notes
    }
}
