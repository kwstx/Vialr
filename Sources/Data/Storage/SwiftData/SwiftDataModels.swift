import Foundation
import Domain

#if canImport(SwiftData)
import SwiftData

// MARK: - SwiftData Dose Event Entity
@Model
public final class SDDoseEvent {
    @Attribute(.unique) public var id: UUID
    public var protocolId: UUID?
    public var protocolCompoundId: UUID?
    public var compoundId: UUID
    public var compoundName: String
    public var scheduledTimestamp: Date
    public var actualTimestamp: Date?
    public var plannedDoseAmount: Double?
    public var actualDoseAmount: Double
    public var doseUnitRaw: String
    public var statusRaw: String
    public var injectionSiteId: String?
    public var injectionSiteName: String?
    public var vialId: UUID?
    public var actualRouteRaw: String
    public var plannedRouteRaw: String?
    public var isPRNOrUnscheduled: Bool
    public var skippedReason: String?
    public var subjectiveEffectScore: Int?
    public var notes: String
    public var loggedByUserId: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var syncStateRaw: String

    public init(
        id: UUID,
        protocolId: UUID? = nil,
        protocolCompoundId: UUID? = nil,
        compoundId: UUID,
        compoundName: String,
        scheduledTimestamp: Date,
        actualTimestamp: Date? = nil,
        plannedDoseAmount: Double? = nil,
        actualDoseAmount: Double,
        doseUnitRaw: String,
        statusRaw: String,
        injectionSiteId: String? = nil,
        injectionSiteName: String? = nil,
        vialId: UUID? = nil,
        actualRouteRaw: String,
        plannedRouteRaw: String? = nil,
        isPRNOrUnscheduled: Bool = false,
        skippedReason: String? = nil,
        subjectiveEffectScore: Int? = nil,
        notes: String = "",
        loggedByUserId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        syncStateRaw: String = SyncState.synced.rawValue
    ) {
        self.id = id
        self.protocolId = protocolId
        self.protocolCompoundId = protocolCompoundId
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.scheduledTimestamp = scheduledTimestamp
        self.actualTimestamp = actualTimestamp
        self.plannedDoseAmount = plannedDoseAmount
        self.actualDoseAmount = actualDoseAmount
        self.doseUnitRaw = doseUnitRaw
        self.statusRaw = statusRaw
        self.injectionSiteId = injectionSiteId
        self.injectionSiteName = injectionSiteName
        self.vialId = vialId
        self.actualRouteRaw = actualRouteRaw
        self.plannedRouteRaw = plannedRouteRaw
        self.isPRNOrUnscheduled = isPRNOrUnscheduled
        self.skippedReason = skippedReason
        self.subjectiveEffectScore = subjectiveEffectScore
        self.notes = notes
        self.loggedByUserId = loggedByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.syncStateRaw = syncStateRaw
    }

    public convenience init(from domain: DoseEvent) {
        self.init(
            id: domain.id,
            protocolId: domain.protocolId,
            protocolCompoundId: domain.protocolCompoundId,
            compoundId: domain.compoundId,
            compoundName: domain.compoundName,
            scheduledTimestamp: domain.scheduledTimestamp,
            actualTimestamp: domain.actualTimestamp,
            plannedDoseAmount: domain.plannedDoseAmount,
            actualDoseAmount: domain.actualDoseAmount,
            doseUnitRaw: domain.doseUnit.rawValue,
            statusRaw: domain.status.rawValue,
            injectionSiteId: domain.injectionSiteId,
            injectionSiteName: domain.injectionSiteName,
            vialId: domain.vialId,
            actualRouteRaw: domain.actualRoute.rawValue,
            plannedRouteRaw: domain.plannedRoute?.rawValue,
            isPRNOrUnscheduled: domain.isPRNOrUnscheduled,
            skippedReason: domain.skippedReason,
            subjectiveEffectScore: domain.subjectiveEffectScore,
            notes: domain.notes,
            loggedByUserId: domain.loggedByUserId,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt,
            version: domain.version,
            syncStateRaw: domain.syncState.rawValue
        )
    }

    public func toDomain() -> DoseEvent {
        DoseEvent(
            id: id,
            protocolId: protocolId,
            protocolCompoundId: protocolCompoundId,
            compoundId: compoundId,
            compoundName: compoundName,
            scheduledTimestamp: scheduledTimestamp,
            actualTimestamp: actualTimestamp,
            plannedDoseAmount: plannedDoseAmount,
            actualDoseAmount: actualDoseAmount,
            doseUnit: DoseUnit(rawValue: doseUnitRaw) ?? .mcg,
            status: DoseEventStatus(rawValue: statusRaw) ?? .scheduled,
            injectionSiteId: injectionSiteId,
            injectionSiteName: injectionSiteName,
            vialId: vialId,
            actualRoute: AdministrationRoute(rawValue: actualRouteRaw) ?? .subcutaneous,
            plannedRoute: plannedRouteRaw.flatMap(AdministrationRoute.init),
            isPRNOrUnscheduled: isPRNOrUnscheduled,
            skippedReason: skippedReason,
            subjectiveEffectScore: subjectiveEffectScore,
            notes: notes,
            loggedByUserId: loggedByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
            syncState: SyncState(rawValue: syncStateRaw) ?? .synced
        )
    }
}

// MARK: - SwiftData Compound Entity
@Model
public final class SDCompound {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var shortCode: String
    public var categoryRaw: String
    public var customCategoryName: String?
    public var isCustom: Bool
    public var sourceRaw: String
    public var createdByUserId: UUID?
    public var defaultUnitRaw: String
    public var typicalDose: Double
    public var doseRangeMin: Double?
    public var doseRangeMax: Double?
    public var halfLifeHours: Double?
    public var administrationRouteRaw: String
    public var storageConditionRaw: String
    public var requiresReconstitution: Bool
    public var compoundDescription: String
    public var instructions: String
    public var tagsJSON: String
    public var aliasesJSON: String
    public var colorHex: String?
    public var iconName: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var syncStateRaw: String

    public init(from domain: Compound) {
        self.id = domain.id
        self.name = domain.name
        self.shortCode = domain.shortCode
        self.categoryRaw = domain.category.rawValue
        self.customCategoryName = domain.customCategoryName
        self.isCustom = domain.isCustom
        self.sourceRaw = domain.source.rawValue
        self.createdByUserId = domain.createdByUserId
        self.defaultUnitRaw = domain.defaultUnit.rawValue
        self.typicalDose = domain.typicalDose
        self.doseRangeMin = domain.doseRangeMin
        self.doseRangeMax = domain.doseRangeMax
        self.halfLifeHours = domain.halfLifeHours
        self.administrationRouteRaw = domain.administrationRoute.rawValue
        self.storageConditionRaw = domain.storageCondition.rawValue
        self.requiresReconstitution = domain.requiresReconstitution
        self.compoundDescription = domain.description
        self.instructions = domain.instructions
        self.tagsJSON = (try? String(data: JSONEncoder().encode(domain.tags), encoding: .utf8)) ?? "[]"
        self.aliasesJSON = (try? String(data: JSONEncoder().encode(domain.aliases), encoding: .utf8)) ?? "[]"
        self.colorHex = domain.colorHex
        self.iconName = domain.iconName
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
        self.version = domain.version
        self.syncStateRaw = domain.syncState.rawValue
    }

    public func toDomain() -> Compound {
        let tags = (try? JSONDecoder().decode([String].self, from: Data(tagsJSON.utf8))) ?? []
        let aliases = (try? JSONDecoder().decode([String].self, from: Data(aliasesJSON.utf8))) ?? []
        return Compound(
            id: id,
            name: name,
            shortCode: shortCode,
            category: CompoundCategory(rawValue: categoryRaw) ?? .supplementOther,
            customCategoryName: customCategoryName,
            isCustom: isCustom,
            source: CompoundSource(rawValue: sourceRaw) ?? .curatedLibrary,
            createdByUserId: createdByUserId,
            defaultUnit: DoseUnit(rawValue: defaultUnitRaw) ?? .mcg,
            typicalDose: typicalDose,
            doseRangeMin: doseRangeMin,
            doseRangeMax: doseRangeMax,
            halfLifeHours: halfLifeHours,
            administrationRoute: AdministrationRoute(rawValue: administrationRouteRaw) ?? .subcutaneous,
            storageCondition: StorageCondition(rawValue: storageConditionRaw) ?? .refrigerated,
            requiresReconstitution: requiresReconstitution,
            description: compoundDescription,
            instructions: instructions,
            tags: tags,
            aliases: aliases,
            colorHex: colorHex,
            iconName: iconName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
            syncState: SyncState(rawValue: syncStateRaw) ?? .synced
        )
    }
}

// MARK: - SwiftData Protocol Entity
@Model
public final class SDProtocol {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var statusRaw: String
    public var startDate: Date
    public var endDate: Date?
    public var notes: String
    public var compoundsJSON: String
    public var goalSummary: String
    public var colorHex: String
    public var userId: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var syncStateRaw: String

    public init(from domain: ProtocolModel) {
        self.id = domain.id
        self.name = domain.name
        self.statusRaw = domain.status.rawValue
        self.startDate = domain.startDate
        self.endDate = domain.endDate
        self.notes = domain.notes
        self.compoundsJSON = (try? String(data: JSONEncoder().encode(domain.compounds), encoding: .utf8)) ?? "[]"
        self.goalSummary = domain.goalSummary
        self.colorHex = domain.colorHex
        self.userId = domain.userId
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
        self.version = domain.version
        self.syncStateRaw = domain.syncState.rawValue
    }

    public func toDomain() -> ProtocolModel {
        let compounds = (try? JSONDecoder().decode([ProtocolCompound].self, from: Data(compoundsJSON.utf8))) ?? []
        return ProtocolModel(
            id: id,
            name: name,
            status: ProtocolStatus(rawValue: statusRaw) ?? .active,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            compounds: compounds,
            goalSummary: goalSummary,
            colorHex: colorHex,
            userId: userId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
            syncState: SyncState(rawValue: syncStateRaw) ?? .synced
        )
    }
}

// MARK: - SwiftData Vial Entity
@Model
public final class SDVial {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID?
    public var compoundId: UUID
    public var compoundName: String
    public var compoundCategoryRaw: String?
    public var lotNumber: String
    public var batchNumber: String?
    public var vendor: String
    public var purityPercentage: Double?
    public var coaReportFileId: UUID?
    public var photoFileId: UUID?
    public var barcodeOrQrCode: String?
    public var totalDryMassMg: Double
    public var bacWaterAddedMl: Double?
    public var currentVolumeRemainingMl: Double?
    public var isReconstituted: Bool
    public var purchaseDate: Date?
    public var receivedDate: Date?
    public var reconstitutedDate: Date?
    public var expirationDate: Date?
    public var openedDate: Date?
    public var depletedDate: Date?
    public var discardDate: Date?
    public var costUsd: Double?
    public var currencyCode: String
    public var storageConditionRaw: String
    public var statusRaw: String
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var syncStateRaw: String

    public init(from domain: Vial) {
        self.id = domain.id
        self.userId = domain.userId
        self.compoundId = domain.compoundId
        self.compoundName = domain.compoundName
        self.compoundCategoryRaw = domain.compoundCategory?.rawValue
        self.lotNumber = domain.lotNumber
        self.batchNumber = domain.batchNumber
        self.vendor = domain.vendor
        self.purityPercentage = domain.purityPercentage
        self.coaReportFileId = domain.coaReportFileId
        self.photoFileId = domain.photoFileId
        self.barcodeOrQrCode = domain.barcodeOrQrCode
        self.totalDryMassMg = domain.totalDryMassMg
        self.bacWaterAddedMl = domain.bacWaterAddedMl
        self.currentVolumeRemainingMl = domain.currentVolumeRemainingMl
        self.isReconstituted = domain.isReconstituted
        self.purchaseDate = domain.purchaseDate
        self.receivedDate = domain.receivedDate
        self.reconstitutedDate = domain.reconstitutedDate
        self.expirationDate = domain.expirationDate
        self.openedDate = domain.openedDate
        self.depletedDate = domain.depletedDate
        self.discardDate = domain.discardDate
        self.costUsd = domain.costUsd
        self.currencyCode = domain.currencyCode
        self.storageConditionRaw = domain.storageCondition.rawValue
        self.statusRaw = domain.status.rawValue
        self.notes = domain.notes
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
        self.version = domain.version
        self.syncStateRaw = domain.syncState.rawValue
    }

    public func toDomain() -> Vial {
        Vial(
            id: id,
            userId: userId,
            compoundId: compoundId,
            compoundName: compoundName,
            compoundCategory: compoundCategoryRaw.flatMap(CompoundCategory.init),
            lotNumber: lotNumber,
            batchNumber: batchNumber,
            vendor: vendor,
            purityPercentage: purityPercentage,
            coaReportFileId: coaReportFileId,
            photoFileId: photoFileId,
            barcodeOrQrCode: barcodeOrQrCode,
            totalDryMassMg: totalDryMassMg,
            bacWaterAddedMl: bacWaterAddedMl,
            currentVolumeRemainingMl: currentVolumeRemainingMl,
            isReconstituted: isReconstituted,
            purchaseDate: purchaseDate,
            receivedDate: receivedDate,
            reconstitutedDate: reconstitutedDate,
            expirationDate: expirationDate,
            openedDate: openedDate,
            depletedDate: depletedDate,
            discardDate: discardDate,
            costUsd: costUsd,
            currencyCode: currencyCode,
            storageCondition: StorageCondition(rawValue: storageConditionRaw) ?? .refrigerated,
            notes: notes,
            status: VialStatus(rawValue: statusRaw) ?? .unopened,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
            syncState: SyncState(rawValue: syncStateRaw) ?? .synced
        )
    }
}

// MARK: - SwiftData Supply Item Entity
@Model
public final class SDSupplyItem {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var categoryRaw: String
    public var quantityRemaining: Int
    public var packageUnit: String
    public var reorderThreshold: Int
    public var costUsd: Double?
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var syncStateRaw: String

    public init(from domain: SupplyItem) {
        self.id = domain.id
        self.name = domain.name
        self.categoryRaw = domain.category.rawValue
        self.quantityRemaining = domain.quantityRemaining
        self.packageUnit = domain.packageUnit
        self.reorderThreshold = domain.reorderThreshold
        self.costUsd = domain.costUsd
        self.notes = domain.notes
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
        self.version = domain.version
        self.syncStateRaw = domain.syncState.rawValue
    }

    public func toDomain() -> SupplyItem {
        SupplyItem(
            id: id,
            name: name,
            category: SupplyCategory(rawValue: categoryRaw) ?? .syringes,
            quantityRemaining: quantityRemaining,
            packageUnit: packageUnit,
            reorderThreshold: reorderThreshold,
            costUsd: costUsd,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
            syncState: SyncState(rawValue: syncStateRaw) ?? .synced
        )
    }
}

// MARK: - SwiftData Biomarker Entity
@Model
public final class SDBiomarker {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var categoryRaw: String
    public var value: Double
    public var unit: String
    public var referenceRangeMin: Double?
    public var referenceRangeMax: Double?
    public var dateRecorded: Date
    public var sourceRaw: String
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var syncStateRaw: String

    public init(from domain: Biomarker) {
        self.id = domain.id
        self.name = domain.name
        self.categoryRaw = domain.category.rawValue
        self.value = domain.value
        self.unit = domain.unit
        self.referenceRangeMin = domain.referenceRangeMin
        self.referenceRangeMax = domain.referenceRangeMax
        self.dateRecorded = domain.dateRecorded
        self.sourceRaw = domain.source.rawValue
        self.notes = domain.notes
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
        self.version = domain.version
        self.syncStateRaw = domain.syncState.rawValue
    }

    public func toDomain() -> Biomarker {
        Biomarker(
            id: id,
            name: name,
            category: BiomarkerCategory(rawValue: categoryRaw) ?? .bloodwork,
            value: value,
            unit: unit,
            referenceRangeMin: referenceRangeMin,
            referenceRangeMax: referenceRangeMax,
            dateRecorded: dateRecorded,
            source: MeasurementSource(rawValue: sourceRaw) ?? .manualEntry,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
            syncState: SyncState(rawValue: syncStateRaw) ?? .synced
        )
    }
}

// MARK: - SwiftData Measurement Entity
@Model
public final class SDMeasurement {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID?
    public var name: String
    public var typeRaw: String
    public var categoryRaw: String
    public var value: Double
    public var secondaryValue: Double?
    public var unit: String
    public var dateRecorded: Date
    public var sourceRaw: String
    public var referenceRangeMin: Double?
    public var referenceRangeMax: Double?
    public var associatedProtocolId: UUID?
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var syncStateRaw: String

    public init(from domain: Measurement) {
        self.id = domain.id
        self.userId = domain.userId
        self.name = domain.name
        self.typeRaw = domain.type.rawValue
        self.categoryRaw = domain.category.rawValue
        self.value = domain.value
        self.secondaryValue = domain.secondaryValue
        self.unit = domain.unit
        self.dateRecorded = domain.dateRecorded
        self.sourceRaw = domain.source.rawValue
        self.referenceRangeMin = domain.referenceRangeMin
        self.referenceRangeMax = domain.referenceRangeMax
        self.associatedProtocolId = domain.associatedProtocolId
        self.notes = domain.notes
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
        self.version = domain.version
        self.syncStateRaw = domain.syncState.rawValue
    }

    public func toDomain() -> Measurement {
        Measurement(
            id: id,
            userId: userId,
            name: name,
            type: MeasurementType(rawValue: typeRaw) ?? .custom,
            category: MeasurementCategory(rawValue: categoryRaw) ?? .bodyComposition,
            value: value,
            secondaryValue: secondaryValue,
            unit: unit,
            dateRecorded: dateRecorded,
            source: MeasurementSource(rawValue: sourceRaw) ?? .manualEntry,
            referenceRangeMin: referenceRangeMin,
            referenceRangeMax: referenceRangeMax,
            associatedProtocolId: associatedProtocolId,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
            syncState: SyncState(rawValue: syncStateRaw) ?? .synced
        )
    }
}

// MARK: - SwiftData Sync Queue Entity
@Model
public final class SDSyncQueueItem {
    @Attribute(.unique) public var id: UUID
    public var entityType: String
    public var entityId: UUID
    public var actionRaw: String
    public var payloadJSON: String?
    public var version: Int
    public var queuedAt: Date
    public var attempts: Int
    public var maxAttempts: Int
    public var lastError: String?
    public var statusRaw: String
    public var nextRetryAt: Date?

    public init(from domain: SyncQueueItem) {
        self.id = domain.id
        self.entityType = domain.entityType
        self.entityId = domain.entityId
        self.actionRaw = domain.action.rawValue
        self.payloadJSON = domain.payloadJSON
        self.version = domain.version
        self.queuedAt = domain.queuedAt
        self.attempts = domain.attempts
        self.maxAttempts = domain.maxAttempts
        self.lastError = domain.lastError
        self.statusRaw = domain.status.rawValue
        self.nextRetryAt = domain.nextRetryAt
    }

    public func toDomain() -> SyncQueueItem {
        SyncQueueItem(
            id: id,
            entityType: entityType,
            entityId: entityId,
            action: SyncAction(rawValue: actionRaw) ?? .create,
            payloadJSON: payloadJSON,
            version: version,
            queuedAt: queuedAt,
            attempts: attempts,
            maxAttempts: maxAttempts,
            lastError: lastError,
            status: SyncQueueStatus(rawValue: statusRaw) ?? .pending,
            nextRetryAt: nextRetryAt
        )
    }
}

// MARK: - SwiftData Inventory Event Entity
@Model
public final class SDInventoryEvent {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID?
    public var vialId: UUID?
    public var supplyItemId: UUID?
    public var compoundId: UUID?
    public var compoundName: String?
    public var eventTypeRaw: String
    public var timestamp: Date
    public var reason: String
    public var reconciliationReasonRaw: String?
    public var disposalReasonRaw: String?
    public var changeMassMg: Double?
    public var changeVolumeMl: Double?
    public var changeQuantityCount: Int?
    public var resultingVolumeRemainingMl: Double?
    public var resultingMassRemainingMg: Double?
    public var resultingConcentrationMgMl: Double?
    public var resultingStatusRaw: String?
    public var doseEventId: UUID?
    public var reconstitutionRecordId: UUID?
    public var costEventId: UUID?
    public var lotNumber: String?
    public var performedByUserId: UUID?
    public var notes: String
    public var metadataJSON: String
    public var createdAt: Date
    public var updatedAt: Date
    public var version: Int
    public var syncStateRaw: String

    public init(from domain: InventoryEvent) {
        self.id = domain.id
        self.userId = domain.userId
        self.vialId = domain.vialId
        self.supplyItemId = domain.supplyItemId
        self.compoundId = domain.compoundId
        self.compoundName = domain.compoundName
        self.eventTypeRaw = domain.eventType.rawValue
        self.timestamp = domain.timestamp
        self.reason = domain.reason
        self.reconciliationReasonRaw = domain.reconciliationReason?.rawValue
        self.disposalReasonRaw = domain.disposalReason?.rawValue
        self.changeMassMg = domain.changeMassMg
        self.changeVolumeMl = domain.changeVolumeMl
        self.changeQuantityCount = domain.changeQuantityCount
        self.resultingVolumeRemainingMl = domain.resultingVolumeRemainingMl
        self.resultingMassRemainingMg = domain.resultingMassRemainingMg
        self.resultingConcentrationMgMl = domain.resultingConcentrationMgMl
        self.resultingStatusRaw = domain.resultingStatus?.rawValue
        self.doseEventId = domain.doseEventId
        self.reconstitutionRecordId = domain.reconstitutionRecordId
        self.costEventId = domain.costEventId
        self.lotNumber = domain.lotNumber
        self.performedByUserId = domain.performedByUserId
        self.notes = domain.notes
        self.metadataJSON = (try? String(data: JSONEncoder().encode(domain.metadata), encoding: .utf8)) ?? "{}"
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
        self.version = domain.version
        self.syncStateRaw = domain.syncState.rawValue
    }

    public func toDomain() -> InventoryEvent {
        let meta = (try? JSONDecoder().decode([String: String].self, from: Data(metadataJSON.utf8))) ?? [:]
        return InventoryEvent(
            id: id,
            userId: userId,
            vialId: vialId,
            supplyItemId: supplyItemId,
            compoundId: compoundId,
            compoundName: compoundName,
            eventType: InventoryEventType(rawValue: eventTypeRaw) ?? .other,
            timestamp: timestamp,
            reason: reason,
            reconciliationReason: reconciliationReasonRaw.flatMap(ReconciliationReason.init),
            disposalReason: disposalReasonRaw.flatMap(DisposalReason.init),
            changeMassMg: changeMassMg,
            changeVolumeMl: changeVolumeMl,
            changeQuantityCount: changeQuantityCount,
            resultingVolumeRemainingMl: resultingVolumeRemainingMl,
            resultingMassRemainingMg: resultingMassRemainingMg,
            resultingConcentrationMgMl: resultingConcentrationMgMl,
            resultingStatus: resultingStatusRaw.flatMap(VialStatus.init),
            doseEventId: doseEventId,
            reconstitutionRecordId: reconstitutionRecordId,
            costEventId: costEventId,
            lotNumber: lotNumber,
            performedByUserId: performedByUserId,
            notes: notes,
            metadata: meta,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
            syncState: SyncState(rawValue: syncStateRaw) ?? .synced
        )
    }
}

#endif
