import Fluent
import Vapor

public final class LabPanelEntity: Model, Content, @unchecked Sendable {
    public static let schema = "lab_panels"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserEntity

    @Field(key: "panel_name")
    public var panelName: String

    @Field(key: "lab_name")
    public var labName: String

    @Field(key: "collection_date")
    public var collectionDate: Date

    @Field(key: "result_date")
    public var resultDate: Date?

    @Field(key: "status")
    public var status: String

    @Field(key: "notes")
    public var notes: String

    @Field(key: "version")
    public var version: Int

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userId: UUID,
        panelName: String,
        labName: String = "Quest Diagnostics",
        collectionDate: Date = Date(),
        resultDate: Date? = nil,
        status: String = "Completed",
        notes: String = "",
        version: Int = 1
    ) {
        self.id = id
        self.$user.id = userId
        self.panelName = panelName
        self.labName = labName
        self.collectionDate = collectionDate
        self.resultDate = resultDate
        self.status = status
        self.notes = notes
        self.version = version
    }
}

public final class LabResultEntity: Model, Content, @unchecked Sendable {
    public static let schema = "lab_results"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "panel_id")
    public var panel: LabPanelEntity

    @Field(key: "biomarker_name")
    public var biomarkerName: String

    @Field(key: "category")
    public var category: String

    @Field(key: "value")
    public var value: Double

    @Field(key: "text_value")
    public var textValue: String?

    @Field(key: "unit")
    public var unit: String

    @Field(key: "reference_range_min")
    public var referenceRangeMin: Double?

    @Field(key: "reference_range_max")
    public var referenceRangeMax: Double?

    @Field(key: "flag")
    public var flag: String

    @Field(key: "notes")
    public var notes: String

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        panelId: UUID,
        biomarkerName: String,
        category: String = "Metabolic",
        value: Double,
        textValue: String? = nil,
        unit: String,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        flag: String = "Normal",
        notes: String = ""
    ) {
        self.id = id
        self.$panel.id = panelId
        self.biomarkerName = biomarkerName
        self.category = category
        self.value = value
        self.textValue = textValue
        self.unit = unit
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.flag = flag
        self.notes = notes
    }
}
