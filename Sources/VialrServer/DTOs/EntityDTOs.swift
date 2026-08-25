import Vapor
import Foundation

// MARK: - ==========================================
// MARK: 1. User & Preferences DTOs
// MARK: - ==========================================

public struct UserProfileDTO: Content, Sendable {
    public let id: UUID
    public let email: String
    public let displayName: String
    public let avatarUrl: String?
    public let phoneNumber: String?
    public let tier: String
    public let status: String
    public let timezone: String
    public let preferences: UserPreferencesDTO?
    public let notificationPreferences: NotificationPreferencesDTO?
    public let unitPreferences: UnitPreferencesDTO?
    public let createdAt: Date?

    public init(
        id: UUID,
        email: String,
        displayName: String,
        avatarUrl: String? = nil,
        phoneNumber: String? = nil,
        tier: String = "free",
        status: String = "active",
        timezone: String = "UTC",
        preferences: UserPreferencesDTO? = nil,
        notificationPreferences: NotificationPreferencesDTO? = nil,
        unitPreferences: UnitPreferencesDTO? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.phoneNumber = phoneNumber
        self.tier = tier
        self.status = status
        self.timezone = timezone
        self.preferences = preferences
        self.notificationPreferences = notificationPreferences
        self.unitPreferences = unitPreferences
        self.createdAt = createdAt
    }
}

public struct UpdateUserProfileRequestDTO: Content, Sendable {
    public let displayName: String?
    public let avatarUrl: String?
    public let phoneNumber: String?
    public let timezone: String?

    public init(displayName: String? = nil, avatarUrl: String? = nil, phoneNumber: String? = nil, timezone: String? = nil) {
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.phoneNumber = phoneNumber
        self.timezone = timezone
    }
}

public struct UserPreferencesDTO: Content, Sendable {
    public var appearanceMode: String
    public var enableHapticFeedback: Bool
    public var enableSoundEffects: Bool
    public var weekStartsOn: String
    public var defaultDoseTimeOfDay: String
    public var autoRotateInjectionSites: Bool
    public var syncWithAppleHealth: Bool
    public var showSafetyWarnings: Bool

    public init(
        appearanceMode: String = "dark",
        enableHapticFeedback: Bool = true,
        enableSoundEffects: Bool = true,
        weekStartsOn: String = "monday",
        defaultDoseTimeOfDay: String = "morning",
        autoRotateInjectionSites: Bool = true,
        syncWithAppleHealth: Bool = true,
        showSafetyWarnings: Bool = true
    ) {
        self.appearanceMode = appearanceMode
        self.enableHapticFeedback = enableHapticFeedback
        self.enableSoundEffects = enableSoundEffects
        self.weekStartsOn = weekStartsOn
        self.defaultDoseTimeOfDay = defaultDoseTimeOfDay
        self.autoRotateInjectionSites = autoRotateInjectionSites
        self.syncWithAppleHealth = syncWithAppleHealth
        self.showSafetyWarnings = showSafetyWarnings
    }
}

public struct UnitPreferencesDTO: Content, Sendable {
    public var massUnit: String
    public var weightUnit: String
    public var heightUnit: String
    public var bloodGlucoseUnit: String
    public var temperatureUnit: String
    public var liquidVolumeUnit: String

    public init(
        massUnit: String = "mcg",
        weightUnit: String = "lbs",
        heightUnit: String = "in",
        bloodGlucoseUnit: String = "mg/dL",
        temperatureUnit: String = "fahrenheit",
        liquidVolumeUnit: String = "mL"
    ) {
        self.massUnit = massUnit
        self.weightUnit = weightUnit
        self.heightUnit = heightUnit
        self.bloodGlucoseUnit = bloodGlucoseUnit
        self.temperatureUnit = temperatureUnit
        self.liquidVolumeUnit = liquidVolumeUnit
    }
}

public struct NotificationPreferencesDTO: Content, Sendable {
    public var enableDoseReminders: Bool
    public var doseReminderLeadTimeMinutes: Int
    public var enableRestockAlerts: Bool
    public var enableStreakCelebrations: Bool
    public var enableDailyMorningSummary: Bool
    public var morningSummaryTime: String
    public var enableQuietHours: Bool
    public var quietHoursStart: String?
    public var quietHoursEnd: String?
    public var criticalAlertsEnabled: Bool

    public init(
        enableDoseReminders: Bool = true,
        doseReminderLeadTimeMinutes: Int = 15,
        enableRestockAlerts: Bool = true,
        enableStreakCelebrations: Bool = true,
        enableDailyMorningSummary: Bool = true,
        morningSummaryTime: String = "08:00",
        enableQuietHours: Bool = false,
        quietHoursStart: String? = "22:00",
        quietHoursEnd: String? = "07:00",
        criticalAlertsEnabled: Bool = false
    ) {
        self.enableDoseReminders = enableDoseReminders
        self.doseReminderLeadTimeMinutes = doseReminderLeadTimeMinutes
        self.enableRestockAlerts = enableRestockAlerts
        self.enableStreakCelebrations = enableStreakCelebrations
        self.enableDailyMorningSummary = enableDailyMorningSummary
        self.morningSummaryTime = morningSummaryTime
        self.enableQuietHours = enableQuietHours
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.criticalAlertsEnabled = criticalAlertsEnabled
    }
}

// MARK: - ==========================================
// MARK: 2. Compound DTOs
// MARK: - ==========================================

public struct CompoundRequestDTO: Content, Sendable {
    public let name: String
    public let shortCode: String?
    public let category: String
    public let customCategoryName: String?
    public let defaultDose: Double
    public let defaultUnit: String
    public let halfLifeHours: Double
    public let administrationRoute: String?
    public let storageCondition: String?
    public let requiresReconstitution: Bool?
    public let description: String?
    public let instructions: String?
    public let notes: String?
    public let tags: [String]?
    public let aliases: [String]?

    public init(
        name: String,
        shortCode: String? = nil,
        category: String = "Supplements & Other",
        customCategoryName: String? = nil,
        defaultDose: Double,
        defaultUnit: String = "mcg",
        halfLifeHours: Double = 24.0,
        administrationRoute: String? = "Subcutaneous (SubQ)",
        storageCondition: String? = "Refrigerated (2–8°C)",
        requiresReconstitution: Bool? = false,
        description: String? = nil,
        instructions: String? = nil,
        notes: String? = nil,
        tags: [String]? = nil,
        aliases: [String]? = nil
    ) {
        self.name = name
        self.shortCode = shortCode
        self.category = category
        self.customCategoryName = customCategoryName
        self.defaultDose = defaultDose
        self.defaultUnit = defaultUnit
        self.halfLifeHours = halfLifeHours
        self.administrationRoute = administrationRoute
        self.storageCondition = storageCondition
        self.requiresReconstitution = requiresReconstitution
        self.description = description
        self.instructions = instructions
        self.notes = notes
        self.tags = tags
        self.aliases = aliases
    }
}

public struct CompoundResponseDTO: Content, Sendable {
    public let id: UUID
    public let name: String
    public let shortCode: String
    public let category: String
    public let customCategoryName: String?
    public let defaultDose: Double
    public let defaultUnit: String
    public let halfLifeHours: Double
    public let administrationRoute: String
    public let storageCondition: String
    public let requiresReconstitution: Bool
    public let description: String?
    public let instructions: String?
    public let notes: String?
    public let isCustom: Bool
    public let tags: [String]
    public let aliases: [String]
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        name: String,
        shortCode: String,
        category: String,
        customCategoryName: String? = nil,
        defaultDose: Double,
        defaultUnit: String,
        halfLifeHours: Double,
        administrationRoute: String = "Subcutaneous (SubQ)",
        storageCondition: String = "Refrigerated (2–8°C)",
        requiresReconstitution: Bool = false,
        description: String? = nil,
        instructions: String? = nil,
        notes: String? = nil,
        isCustom: Bool = false,
        tags: [String] = [],
        aliases: [String] = [],
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.shortCode = shortCode
        self.category = category
        self.customCategoryName = customCategoryName
        self.defaultDose = defaultDose
        self.defaultUnit = defaultUnit
        self.halfLifeHours = halfLifeHours
        self.administrationRoute = administrationRoute
        self.storageCondition = storageCondition
        self.requiresReconstitution = requiresReconstitution
        self.description = description
        self.instructions = instructions
        self.notes = notes
        self.isCustom = isCustom
        self.tags = tags
        self.aliases = aliases
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public typealias CompoundDTO = CompoundResponseDTO

// MARK: - ==========================================
// MARK: 3. Protocol DTOs & Revisions
// MARK: - ==========================================

public struct ProtocolRequestDTO: Content, Sendable {
    public let id: UUID?
    public let compoundId: UUID
    public let name: String
    public let scheduleFrequency: String
    public let doseAmount: Double
    public let doseUnit: String
    public let cycleDurationWeeks: Int
    public let startDate: Date
    public let endDate: Date?
    public let notes: String?
    public let status: String?

    public init(
        id: UUID? = nil,
        compoundId: UUID,
        name: String,
        scheduleFrequency: String,
        doseAmount: Double,
        doseUnit: String,
        cycleDurationWeeks: Int = 12,
        startDate: Date = Date(),
        endDate: Date? = nil,
        notes: String? = nil,
        status: String? = "active"
    ) {
        self.id = id
        self.compoundId = compoundId
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

public struct ProtocolResponseDTO: Content, Sendable {
    public let id: UUID
    public let compoundId: UUID
    public let compoundName: String?
    public let name: String
    public let scheduleFrequency: String
    public let doseAmount: Double
    public let doseUnit: String
    public let cycleDurationWeeks: Int
    public let startDate: Date
    public let endDate: Date?
    public let notes: String?
    public let status: String
    public let version: Int
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        compoundId: UUID,
        compoundName: String? = nil,
        name: String,
        scheduleFrequency: String,
        doseAmount: Double,
        doseUnit: String,
        cycleDurationWeeks: Int,
        startDate: Date,
        endDate: Date? = nil,
        notes: String? = nil,
        status: String = "active",
        version: Int = 1,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.name = name
        self.scheduleFrequency = scheduleFrequency
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.cycleDurationWeeks = cycleDurationWeeks
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.status = status
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public typealias ProtocolDTO = ProtocolResponseDTO

public struct ProtocolRevisionDTO: Content, Sendable {
    public let id: UUID
    public let protocolId: UUID
    public let revisionNumber: Int
    public let previousRevisionId: UUID?
    public let name: String
    public let compoundsJson: String
    public let reasonForChange: String
    public let effectiveDate: Date
    public let createdAt: Date?

    public init(
        id: UUID,
        protocolId: UUID,
        revisionNumber: Int,
        previousRevisionId: UUID? = nil,
        name: String,
        compoundsJson: String,
        reasonForChange: String,
        effectiveDate: Date,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.protocolId = protocolId
        self.revisionNumber = revisionNumber
        self.previousRevisionId = previousRevisionId
        self.name = name
        self.compoundsJson = compoundsJson
        self.reasonForChange = reasonForChange
        self.effectiveDate = effectiveDate
        self.createdAt = createdAt
    }
}

// MARK: - ==========================================
// MARK: 4. Dose Event & Log DTOs
// MARK: - ==========================================

public struct DoseLogRequestDTO: Content, Sendable {
    public let id: UUID?
    public let protocolId: UUID?
    public let compoundId: UUID
    public let vialId: UUID?
    public let scheduledDate: Date
    public let administeredDate: Date?
    public let doseAmount: Double
    public let doseUnit: String
    public let injectionSite: String?
    public let injectionSiteId: String?
    public let administrationRoute: String?
    public let status: String
    public let skippedReason: String?
    public let notes: String?
    public let painScore: Int?

    public init(
        id: UUID? = nil,
        protocolId: UUID? = nil,
        compoundId: UUID,
        vialId: UUID? = nil,
        scheduledDate: Date = Date(),
        administeredDate: Date? = nil,
        doseAmount: Double,
        doseUnit: String = "mcg",
        injectionSite: String? = nil,
        injectionSiteId: String? = nil,
        administrationRoute: String? = nil,
        status: String = "taken",
        skippedReason: String? = nil,
        notes: String? = nil,
        painScore: Int? = nil
    ) {
        self.id = id
        self.protocolId = protocolId
        self.compoundId = compoundId
        self.vialId = vialId
        self.scheduledDate = scheduledDate
        self.administeredDate = administeredDate
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.injectionSite = injectionSite
        self.injectionSiteId = injectionSiteId
        self.administrationRoute = administrationRoute
        self.status = status
        self.skippedReason = skippedReason
        self.notes = notes
        self.painScore = painScore
    }
}

public struct DoseLogResponseDTO: Content, Sendable {
    public let id: UUID
    public let protocolId: UUID?
    public let protocolName: String?
    public let compoundId: UUID
    public let compoundName: String?
    public let vialId: UUID?
    public let scheduledDate: Date
    public let administeredDate: Date?
    public let doseAmount: Double
    public let doseUnit: String
    public let injectionSite: String?
    public let injectionSiteId: String?
    public let administrationRoute: String?
    public let status: String
    public let skippedReason: String?
    public let notes: String?
    public let painScore: Int?
    public let vialRemainingVolumeMl: Double?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        protocolId: UUID? = nil,
        protocolName: String? = nil,
        compoundId: UUID,
        compoundName: String? = nil,
        vialId: UUID? = nil,
        scheduledDate: Date,
        administeredDate: Date? = nil,
        doseAmount: Double,
        doseUnit: String,
        injectionSite: String? = nil,
        injectionSiteId: String? = nil,
        administrationRoute: String? = nil,
        status: String,
        skippedReason: String? = nil,
        notes: String? = nil,
        painScore: Int? = nil,
        vialRemainingVolumeMl: Double? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.protocolId = protocolId
        self.protocolName = protocolName
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.vialId = vialId
        self.scheduledDate = scheduledDate
        self.administeredDate = administeredDate
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.injectionSite = injectionSite
        self.injectionSiteId = injectionSiteId
        self.administrationRoute = administrationRoute
        self.status = status
        self.skippedReason = skippedReason
        self.notes = notes
        self.painScore = painScore
        self.vialRemainingVolumeMl = vialRemainingVolumeMl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public typealias DoseLogDTO = DoseLogResponseDTO

public struct BatchDoseLogRequestDTO: Content, Sendable {
    public let doses: [DoseLogRequestDTO]

    public init(doses: [DoseLogRequestDTO]) {
        self.doses = doses
    }
}

public struct BatchDoseLogResponseDTO: Content, Sendable {
    public let processedCount: Int
    public let results: [DoseLogResponseDTO]

    public init(processedCount: Int, results: [DoseLogResponseDTO]) {
        self.processedCount = processedCount
        self.results = results
    }
}

// MARK: - ==========================================
// MARK: 5. Inventory (Vials & Supplies) DTOs
// MARK: - ==========================================

public struct VialRequestDTO: Content, Sendable {
    public let id: UUID?
    public let compoundId: UUID
    public let lotNumber: String?
    public let batchNumber: String?
    public let vendor: String?
    public let purityPercentage: Double?
    public let dryMassMg: Double
    public let diluentVolumeMl: Double?
    public let currentVolumeRemainingMl: Double?
    public let purchaseDate: Date?
    public let receivedDate: Date?
    public let reconstitutedDate: Date?
    public let expirationDate: Date?
    public let costUsd: Double?
    public let currencyCode: String?
    public let storageCondition: String?
    public let status: String?
    public let notes: String?

    public init(
        id: UUID? = nil,
        compoundId: UUID,
        lotNumber: String? = nil,
        batchNumber: String? = nil,
        vendor: String? = nil,
        purityPercentage: Double? = nil,
        dryMassMg: Double,
        diluentVolumeMl: Double? = nil,
        currentVolumeRemainingMl: Double? = nil,
        purchaseDate: Date? = nil,
        receivedDate: Date? = nil,
        reconstitutedDate: Date? = nil,
        expirationDate: Date? = nil,
        costUsd: Double? = nil,
        currencyCode: String? = "USD",
        storageCondition: String? = "Refrigerated (2–8°C)",
        status: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.compoundId = compoundId
        self.lotNumber = lotNumber
        self.batchNumber = batchNumber
        self.vendor = vendor
        self.purityPercentage = purityPercentage
        self.dryMassMg = dryMassMg
        self.diluentVolumeMl = diluentVolumeMl
        self.currentVolumeRemainingMl = currentVolumeRemainingMl
        self.purchaseDate = purchaseDate
        self.receivedDate = receivedDate
        self.reconstitutedDate = reconstitutedDate
        self.expirationDate = expirationDate
        self.costUsd = costUsd
        self.currencyCode = currencyCode
        self.storageCondition = storageCondition
        self.status = status
        self.notes = notes
    }
}

public struct VialResponseDTO: Content, Sendable {
    public let id: UUID
    public let compoundId: UUID
    public let compoundName: String?
    public let lotNumber: String?
    public let batchNumber: String?
    public let vendor: String?
    public let purityPercentage: Double?
    public let dryMassMg: Double
    public let diluentVolumeMl: Double?
    public let concentrationMgMl: Double?
    public let concentrationMcgMl: Double?
    public let currentVolumeRemainingMl: Double?
    public let remainingPercentage: Double?
    public let isReconstituted: Bool
    public let purchaseDate: Date?
    public let receivedDate: Date?
    public let reconstitutedDate: Date?
    public let expirationDate: Date?
    public let costUsd: Double?
    public let currencyCode: String
    public let storageCondition: String
    public let status: String
    public let isExpired: Bool
    public let notes: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        compoundId: UUID,
        compoundName: String? = nil,
        lotNumber: String? = nil,
        batchNumber: String? = nil,
        vendor: String? = nil,
        purityPercentage: Double? = nil,
        dryMassMg: Double,
        diluentVolumeMl: Double? = nil,
        concentrationMgMl: Double? = nil,
        concentrationMcgMl: Double? = nil,
        currentVolumeRemainingMl: Double? = nil,
        remainingPercentage: Double? = nil,
        isReconstituted: Bool = false,
        purchaseDate: Date? = nil,
        receivedDate: Date? = nil,
        reconstitutedDate: Date? = nil,
        expirationDate: Date? = nil,
        costUsd: Double? = nil,
        currencyCode: String = "USD",
        storageCondition: String = "Refrigerated (2–8°C)",
        status: String = "unopened",
        isExpired: Bool = false,
        notes: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.lotNumber = lotNumber
        self.batchNumber = batchNumber
        self.vendor = vendor
        self.purityPercentage = purityPercentage
        self.dryMassMg = dryMassMg
        self.diluentVolumeMl = diluentVolumeMl
        self.concentrationMgMl = concentrationMgMl
        self.concentrationMcgMl = concentrationMcgMl
        self.currentVolumeRemainingMl = currentVolumeRemainingMl
        self.remainingPercentage = remainingPercentage
        self.isReconstituted = isReconstituted
        self.purchaseDate = purchaseDate
        self.receivedDate = receivedDate
        self.reconstitutedDate = reconstitutedDate
        self.expirationDate = expirationDate
        self.costUsd = costUsd
        self.currencyCode = currencyCode
        self.storageCondition = storageCondition
        self.status = status
        self.isExpired = isExpired
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public typealias VialDTO = VialResponseDTO

public struct SupplyItemRequestDTO: Content, Sendable {
    public let id: UUID?
    public let name: String
    public let category: String
    public let quantityRemaining: Int
    public let packageUnit: String
    public let reorderThreshold: Int
    public let costUsd: Double?
    public let notes: String?

    public init(
        id: UUID? = nil,
        name: String,
        category: String,
        quantityRemaining: Int,
        packageUnit: String = "pieces",
        reorderThreshold: Int = 10,
        costUsd: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.quantityRemaining = quantityRemaining
        self.packageUnit = packageUnit
        self.reorderThreshold = reorderThreshold
        self.costUsd = costUsd
        self.notes = notes
    }
}

public struct SupplyItemResponseDTO: Content, Sendable {
    public let id: UUID
    public let name: String
    public let category: String
    public let quantityRemaining: Int
    public let packageUnit: String
    public let reorderThreshold: Int
    public let isLowStock: Bool
    public let costUsd: Double?
    public let notes: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        name: String,
        category: String,
        quantityRemaining: Int,
        packageUnit: String,
        reorderThreshold: Int,
        isLowStock: Bool,
        costUsd: Double? = nil,
        notes: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.quantityRemaining = quantityRemaining
        self.packageUnit = packageUnit
        self.reorderThreshold = reorderThreshold
        self.isLowStock = isLowStock
        self.costUsd = costUsd
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AdjustSupplyQuantityRequestDTO: Content, Sendable {
    public let delta: Int
    public let reason: String?

    public init(delta: Int, reason: String? = nil) {
        self.delta = delta
        self.reason = reason
    }
}

// MARK: - ==========================================
// MARK: 6. Reconstitution Record DTOs
// MARK: - ==========================================

public struct ReconstitutionRequestDTO: Content, Sendable {
    public let id: UUID?
    public let vialId: UUID
    public let compoundId: UUID
    public let dryMassMg: Double
    public let diluentVolumeMl: Double
    public let diluentType: String?
    public let diluentLotNumber: String?
    public let diluentBrand: String?
    public let reconstitutedAt: Date?
    public let storageCondition: String?
    public let expectedShelfLifeDays: Int?
    public let solutionClarity: String?
    public let notes: String?

    public init(
        id: UUID? = nil,
        vialId: UUID,
        compoundId: UUID,
        dryMassMg: Double,
        diluentVolumeMl: Double,
        diluentType: String? = "Bacteriostatic Water (0.9% Benzyl Alcohol)",
        diluentLotNumber: String? = nil,
        diluentBrand: String? = nil,
        reconstitutedAt: Date? = nil,
        storageCondition: String? = "Refrigerated (2–8°C)",
        expectedShelfLifeDays: Int? = 30,
        solutionClarity: String? = "Clear & Colorless (Optimal)",
        notes: String? = nil
    ) {
        self.id = id
        self.vialId = vialId
        self.compoundId = compoundId
        self.dryMassMg = dryMassMg
        self.diluentVolumeMl = diluentVolumeMl
        self.diluentType = diluentType
        self.diluentLotNumber = diluentLotNumber
        self.diluentBrand = diluentBrand
        self.reconstitutedAt = reconstitutedAt
        self.storageCondition = storageCondition
        self.expectedShelfLifeDays = expectedShelfLifeDays
        self.solutionClarity = solutionClarity
        self.notes = notes
    }
}

public struct ReconstitutionResponseDTO: Content, Sendable {
    public let id: UUID
    public let vialId: UUID
    public let compoundId: UUID
    public let compoundName: String?
    public let dryMassMg: Double
    public let diluentVolumeMl: Double
    public let diluentType: String
    public let diluentLotNumber: String?
    public let diluentBrand: String?
    public let reconstitutedAt: Date
    public let concentrationMgMl: Double
    public let concentrationMcgMl: Double
    public let totalLiquidVolumeMl: Double
    public let storageCondition: String
    public let expectedShelfLifeDays: Int
    public let expirationDate: Date?
    public let isConfirmed: Bool
    public let version: Int
    public let isCurrentActiveRevision: Bool
    public let previousRecordId: UUID?
    public let supersededByRecordId: UUID?
    public let revisionReason: String?
    public let solutionClarity: String
    public let notes: String?
    public let createdAt: Date?

    public init(
        id: UUID,
        vialId: UUID,
        compoundId: UUID,
        compoundName: String? = nil,
        dryMassMg: Double,
        diluentVolumeMl: Double,
        diluentType: String,
        diluentLotNumber: String? = nil,
        diluentBrand: String? = nil,
        reconstitutedAt: Date,
        concentrationMgMl: Double,
        concentrationMcgMl: Double,
        totalLiquidVolumeMl: Double,
        storageCondition: String,
        expectedShelfLifeDays: Int,
        expirationDate: Date? = nil,
        isConfirmed: Bool = true,
        version: Int = 1,
        isCurrentActiveRevision: Bool = true,
        previousRecordId: UUID? = nil,
        supersededByRecordId: UUID? = nil,
        revisionReason: String? = nil,
        solutionClarity: String = "Clear & Colorless (Optimal)",
        notes: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.vialId = vialId
        self.compoundId = compoundId
        self.compoundName = compoundName
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
        self.createdAt = createdAt
    }
}

public struct ReconstitutionRevisionRequestDTO: Content, Sendable {
    public let newDiluentVolumeMl: Double
    public let newDryMassMg: Double?
    public let diluentType: String?
    public let revisionReason: String

    public init(
        newDiluentVolumeMl: Double,
        newDryMassMg: Double? = nil,
        diluentType: String? = nil,
        revisionReason: String
    ) {
        self.newDiluentVolumeMl = newDiluentVolumeMl
        self.newDryMassMg = newDryMassMg
        self.diluentType = diluentType
        self.revisionReason = revisionReason
    }
}

// MARK: - ==========================================
// MARK: 7. Injection Site & Rotation DTOs
// MARK: - ==========================================

public struct InjectionSiteDTO: Content, Sendable {
    public let id: String
    public let name: String
    public let region: String
    public let side: String
    public let quadrant: String?
    public let route: String

    public init(
        id: String,
        name: String,
        region: String,
        side: String,
        quadrant: String? = nil,
        route: String = "Subcutaneous (SubQ)"
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.side = side
        self.quadrant = quadrant
        self.route = route
    }
}

public struct InjectionSiteEventRequestDTO: Content, Sendable {
    public let siteId: String
    public let doseLogId: UUID?
    public let administeredAt: Date?
    public let painScore: Int?
    public let notes: String?

    public init(
        siteId: String,
        doseLogId: UUID? = nil,
        administeredAt: Date? = nil,
        painScore: Int? = nil,
        notes: String? = nil
    ) {
        self.siteId = siteId
        self.doseLogId = doseLogId
        self.administeredAt = administeredAt
        self.painScore = painScore
        self.notes = notes
    }
}

public struct InjectionSiteEventResponseDTO: Content, Sendable {
    public let id: UUID
    public let siteId: String
    public let siteName: String
    public let region: String
    public let side: String
    public let doseLogId: UUID?
    public let administeredAt: Date
    public let daysSinceLastUse: Int?
    public let painScore: Int?
    public let notes: String?

    public init(
        id: UUID,
        siteId: String,
        siteName: String,
        region: String,
        side: String,
        doseLogId: UUID? = nil,
        administeredAt: Date,
        daysSinceLastUse: Int? = nil,
        painScore: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.siteId = siteId
        self.siteName = siteName
        self.region = region
        self.side = side
        self.doseLogId = doseLogId
        self.administeredAt = administeredAt
        self.daysSinceLastUse = daysSinceLastUse
        self.painScore = painScore
        self.notes = notes
    }
}

public struct SiteRotationRecommendationDTO: Content, Sendable {
    public let recommendedSite: InjectionSiteDTO
    public let daysSinceLastUsed: Int?
    public let reason: String
    public let alternativeSites: [InjectionSiteDTO]

    public init(
        recommendedSite: InjectionSiteDTO,
        daysSinceLastUsed: Int? = nil,
        reason: String,
        alternativeSites: [InjectionSiteDTO] = []
    ) {
        self.recommendedSite = recommendedSite
        self.daysSinceLastUsed = daysSinceLastUsed
        self.reason = reason
        self.alternativeSites = alternativeSites
    }
}

// MARK: - ==========================================
// MARK: 8. Measurement DTOs
// MARK: - ==========================================

public struct MeasurementRequestDTO: Content, Sendable {
    public let id: UUID?
    public let name: String
    public let type: String
    public let category: String
    public let value: Double
    public let secondaryValue: Double?
    public let unit: String
    public let dateRecorded: Date
    public let source: String?
    public let referenceRangeMin: Double?
    public let referenceRangeMax: Double?
    public let associatedProtocolId: UUID?
    public let notes: String?

    public init(
        id: UUID? = nil,
        name: String,
        type: String = "Custom Metric",
        category: String = "Body Composition",
        value: Double,
        secondaryValue: Double? = nil,
        unit: String,
        dateRecorded: Date = Date(),
        source: String? = "Manual Entry",
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        associatedProtocolId: UUID? = nil,
        notes: String? = nil
    ) {
        self.id = id
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
        self.associatedProtocolId = associatedProtocolId
        self.notes = notes
    }
}

public struct MeasurementResponseDTO: Content, Sendable {
    public let id: UUID
    public let name: String
    public let type: String
    public let category: String
    public let value: Double
    public let secondaryValue: Double?
    public let formattedValue: String
    public let unit: String
    public let dateRecorded: Date
    public let source: String
    public let referenceRangeMin: Double?
    public let referenceRangeMax: Double?
    public let status: String
    public let associatedProtocolId: UUID?
    public let notes: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        name: String,
        type: String,
        category: String,
        value: Double,
        secondaryValue: Double? = nil,
        formattedValue: String,
        unit: String,
        dateRecorded: Date,
        source: String,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        status: String = "Optimal / Normal",
        associatedProtocolId: UUID? = nil,
        notes: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.category = category
        self.value = value
        self.secondaryValue = secondaryValue
        self.formattedValue = formattedValue
        self.unit = unit
        self.dateRecorded = dateRecorded
        self.source = source
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.status = status
        self.associatedProtocolId = associatedProtocolId
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct MeasurementTrendDTO: Content, Sendable {
    public let type: String
    public let name: String
    public let unit: String
    public let count: Int
    public let latestValue: Double
    public let changeOverPeriod: Double
    public let averageValue: Double
    public let minValue: Double
    public let maxValue: Double
    public let entries: [MeasurementResponseDTO]

    public init(
        type: String,
        name: String,
        unit: String,
        count: Int,
        latestValue: Double,
        changeOverPeriod: Double,
        averageValue: Double,
        minValue: Double,
        maxValue: Double,
        entries: [MeasurementResponseDTO]
    ) {
        self.type = type
        self.name = name
        self.unit = unit
        self.count = count
        self.latestValue = latestValue
        self.changeOverPeriod = changeOverPeriod
        self.averageValue = averageValue
        self.minValue = minValue
        self.maxValue = maxValue
        self.entries = entries
    }
}

// MARK: - ==========================================
// MARK: 9. Lab Panels & Biomarkers DTOs
// MARK: - ==========================================

public struct LabResultItemDTO: Content, Sendable {
    public let id: UUID?
    public let biomarkerName: String
    public let category: String
    public let value: Double
    public let textValue: String?
    public let unit: String
    public let referenceRangeMin: Double?
    public let referenceRangeMax: Double?
    public let flag: String?
    public let notes: String?

    public init(
        id: UUID? = nil,
        biomarkerName: String,
        category: String = "Metabolic & Glucose",
        value: Double,
        textValue: String? = nil,
        unit: String,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        flag: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
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

public struct LabPanelRequestDTO: Content, Sendable {
    public let id: UUID?
    public let panelName: String
    public let labName: String
    public let collectionDate: Date
    public let resultDate: Date?
    public let status: String?
    public let orderingPhysician: String?
    public let associatedProtocolId: UUID?
    public let fastingStatus: String?
    public let notes: String?
    public let results: [LabResultItemDTO]

    public init(
        id: UUID? = nil,
        panelName: String,
        labName: String = "Quest Diagnostics",
        collectionDate: Date = Date(),
        resultDate: Date? = nil,
        status: String? = "Completed & Final",
        orderingPhysician: String? = nil,
        associatedProtocolId: UUID? = nil,
        fastingStatus: String? = "Fasting (8–12 hrs)",
        notes: String? = nil,
        results: [LabResultItemDTO] = []
    ) {
        self.id = id
        self.panelName = panelName
        self.labName = labName
        self.collectionDate = collectionDate
        self.resultDate = resultDate
        self.status = status
        self.orderingPhysician = orderingPhysician
        self.associatedProtocolId = associatedProtocolId
        self.fastingStatus = fastingStatus
        self.notes = notes
        self.results = results
    }
}

public struct LabPanelResponseDTO: Content, Sendable {
    public let id: UUID
    public let panelName: String
    public let labName: String
    public let collectionDate: Date
    public let resultDate: Date?
    public let status: String
    public let orderingPhysician: String?
    public let associatedProtocolId: UUID?
    public let fastingStatus: String
    public let notes: String?
    public let results: [LabResultItemDTO]
    public let abnormalCount: Int
    public let totalAnalytes: Int
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        panelName: String,
        labName: String,
        collectionDate: Date,
        resultDate: Date? = nil,
        status: String,
        orderingPhysician: String? = nil,
        associatedProtocolId: UUID? = nil,
        fastingStatus: String = "Fasting (8–12 hrs)",
        notes: String? = nil,
        results: [LabResultItemDTO],
        abnormalCount: Int,
        totalAnalytes: Int,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.panelName = panelName
        self.labName = labName
        self.collectionDate = collectionDate
        self.resultDate = resultDate
        self.status = status
        self.orderingPhysician = orderingPhysician
        self.associatedProtocolId = associatedProtocolId
        self.fastingStatus = fastingStatus
        self.notes = notes
        self.results = results
        self.abnormalCount = abnormalCount
        self.totalAnalytes = totalAnalytes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct BiomarkerDTO: Content, Sendable {
    public let id: UUID?
    public let name: String
    public let value: Double
    public let unit: String
    public let referenceRangeMin: Double?
    public let referenceRangeMax: Double?
    public let testDate: Date
    public let labName: String?
    public let notes: String?

    public init(
        id: UUID? = nil,
        name: String,
        value: Double,
        unit: String,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        testDate: Date = Date(),
        labName: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
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

public struct BiomarkerHistoryTrendDTO: Content, Sendable {
    public let biomarkerName: String
    public let unit: String
    public let referenceRangeMin: Double?
    public let referenceRangeMax: Double?
    public let dataPoints: [BiomarkerDTO]

    public init(
        biomarkerName: String,
        unit: String,
        referenceRangeMin: Double? = nil,
        referenceRangeMax: Double? = nil,
        dataPoints: [BiomarkerDTO]
    ) {
        self.biomarkerName = biomarkerName
        self.unit = unit
        self.referenceRangeMin = referenceRangeMin
        self.referenceRangeMax = referenceRangeMax
        self.dataPoints = dataPoints
    }
}

// MARK: - ==========================================
// MARK: 10. Reports DTOs
// MARK: - ==========================================

public struct ClinicianReportRequestDTO: Content, Sendable {
    public let dateRangeStart: Date
    public let dateRangeEnd: Date
    public let patientName: String
    public let dateOfBirth: String
    public let clinicianName: String
    public let practiceOrClinic: String

    public init(
        dateRangeStart: Date,
        dateRangeEnd: Date,
        patientName: String,
        dateOfBirth: String,
        clinicianName: String,
        practiceOrClinic: String
    ) {
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.patientName = patientName
        self.dateOfBirth = dateOfBirth
        self.clinicianName = clinicianName
        self.practiceOrClinic = practiceOrClinic
    }
}

public struct ClinicianReportResponseDTO: Content, Sendable {
    public let generatedAt: Date
    public let patientName: String
    public let activeProtocolsCount: Int
    public let adherenceRate: Double
    public let dosesLoggedCount: Int
    public let biomarkersCount: Int
    public let summaryText: String
    public let storedFileId: UUID?
    public let downloadUrl: String?

    public init(
        generatedAt: Date,
        patientName: String,
        activeProtocolsCount: Int,
        adherenceRate: Double,
        dosesLoggedCount: Int,
        biomarkersCount: Int,
        summaryText: String,
        storedFileId: UUID? = nil,
        downloadUrl: String? = nil
    ) {
        self.generatedAt = generatedAt
        self.patientName = patientName
        self.activeProtocolsCount = activeProtocolsCount
        self.adherenceRate = adherenceRate
        self.dosesLoggedCount = dosesLoggedCount
        self.biomarkersCount = biomarkersCount
        self.summaryText = summaryText
        self.storedFileId = storedFileId
        self.downloadUrl = downloadUrl
    }
}

// MARK: - ==========================================
// MARK: 11. Notification & APNs Device Token DTOs
// MARK: - ==========================================

public struct DeviceTokenRegistrationDTO: Content, Sendable {
    public let deviceToken: String
    public let platform: String
    public let appVersion: String?

    public init(deviceToken: String, platform: String = "iOS", appVersion: String? = nil) {
        self.deviceToken = deviceToken
        self.platform = platform
        self.appVersion = appVersion
    }
}

public struct NotificationRecordDTO: Content, Sendable {
    public let id: UUID
    public let title: String
    public let body: String
    public let category: String
    public let scheduledDate: Date
    public let isRead: Bool
    public let deepLinkUri: String?
    public let createdAt: Date?

    public init(
        id: UUID,
        title: String,
        body: String,
        category: String,
        scheduledDate: Date,
        isRead: Bool = false,
        deepLinkUri: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
        self.scheduledDate = scheduledDate
        self.isRead = isRead
        self.deepLinkUri = deepLinkUri
        self.createdAt = createdAt
    }
}

public struct TestNotificationRequestDTO: Content, Sendable {
    public let title: String
    public let body: String
    public let category: String?

    public init(title: String, body: String, category: String? = "reminder") {
        self.title = title
        self.body = body
        self.category = category
    }
}

// MARK: - ==========================================
// MARK: 12. Offline Synchronization DTOs
// MARK: - ==========================================

public struct SyncDeltaItemDTO: Content, Sendable {
    public let id: UUID
    public let entityType: String
    public let entityId: UUID
    public let operation: String // "create", "update", "delete"
    public let payloadJson: String?
    public let timestamp: Date

    public init(id: UUID, entityType: String, entityId: UUID, operation: String, payloadJson: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.payloadJson = payloadJson
        self.timestamp = timestamp
    }
}

public struct SyncPushRequestDTO: Content, Sendable {
    public let changes: [SyncDeltaItemDTO]

    public init(changes: [SyncDeltaItemDTO]) {
        self.changes = changes
    }
}

public struct SyncPullResponseDTO: Content, Sendable {
    public let serverTimestamp: Date
    public let changes: [SyncDeltaItemDTO]

    public init(serverTimestamp: Date, changes: [SyncDeltaItemDTO]) {
        self.serverTimestamp = serverTimestamp
        self.changes = changes
    }
}
