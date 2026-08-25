import Fluent
import Vapor

public final class ReconstitutionRecordEntity: Model, Content, @unchecked Sendable {
    public static let schema = "reconstitution_records"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Parent(key: "vial_id")
    public var vial: VialEntity

    @Parent(key: "compound_id")
    public var compound: CompoundEntity

    @Field(key: "dry_mass_mg")
    public var dryMassMg: Double

    @Field(key: "diluent_volume_ml")
    public var diluentVolumeMl: Double

    @Field(key: "diluent_type")
    public var diluentType: String

    @Field(key: "diluent_lot_number")
    public var diluentLotNumber: String?

    @Field(key: "diluent_brand")
    public var diluentBrand: String?

    @Field(key: "reconstituted_at")
    public var reconstitutedAt: Date

    @Field(key: "concentration_mg_ml")
    public var concentrationMgMl: Double

    @Field(key: "concentration_mcg_ml")
    public var concentrationMcgMl: Double

    @Field(key: "total_liquid_volume_ml")
    public var totalLiquidVolumeMl: Double

    @Field(key: "storage_condition")
    public var storageCondition: String

    @Field(key: "expected_shelf_life_days")
    public var expectedShelfLifeDays: Int

    @Field(key: "expiration_date")
    public var expirationDate: Date?

    @Field(key: "is_confirmed")
    public var isConfirmed: Bool

    @Field(key: "version")
    public var version: Int

    @Field(key: "is_current_active_revision")
    public var isCurrentActiveRevision: Bool

    @Field(key: "previous_record_id")
    public var previousRecordId: UUID?

    @Field(key: "superseded_by_record_id")
    public var supersededByRecordId: UUID?

    @Field(key: "revision_reason")
    public var revisionReason: String?

    @Field(key: "solution_clarity")
    public var solutionClarity: String

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
        vialId: UUID,
        compoundId: UUID,
        dryMassMg: Double,
        diluentVolumeMl: Double,
        diluentType: String = "Bacteriostatic Water",
        diluentLotNumber: String? = nil,
        diluentBrand: String? = nil,
        reconstitutedAt: Date = Date(),
        concentrationMgMl: Double,
        concentrationMcgMl: Double,
        totalLiquidVolumeMl: Double,
        storageCondition: String = "Refrigerated (2–8°C)",
        expectedShelfLifeDays: Int = 30,
        expirationDate: Date? = nil,
        isConfirmed: Bool = true,
        version: Int = 1,
        isCurrentActiveRevision: Bool = true,
        previousRecordId: UUID? = nil,
        supersededByRecordId: UUID? = nil,
        revisionReason: String? = nil,
        solutionClarity: String = "Clear & Colorless (Optimal)",
        notes: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.$vial.id = vialId
        self.$compound.id = compoundId
        self.dryMassMg = dryMassMg
        self.diluentVolumeMl = diluentVolumeMl
        self.diluentType = diluentType
        self.diluentLotNumber = diluentLotNumber
        self.diluentBrand = diluentBrand
        self.reconstitutedAt = reconstitutedAt
        self.concentrationMgMl = concentrationMgMl
        self.concentrationMcgMl = concentrationMcgMl
        self.totalLiquidVolumeMl = totalLiquidVolumeMl
        self.storageCondition = storageCondition
        self.expectedShelfLifeDays = expectedShelfLifeDays
        self.expirationDate = expirationDate
        self.isConfirmed = isConfirmed
        self.version = version
        self.isCurrentActiveRevision = isCurrentActiveRevision
        self.previousRecordId = previousRecordId
        self.supersededByRecordId = supersededByRecordId
        self.revisionReason = revisionReason
        self.solutionClarity = solutionClarity
        self.notes = notes
    }
}
