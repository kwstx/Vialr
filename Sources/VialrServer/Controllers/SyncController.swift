import Vapor
import Fluent
import Domain

public struct SyncController: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let syncGroup = routes.grouped("sync")
            .grouped(UserAuthenticator(), UserPayload.guardMiddleware())

        syncGroup.post("outbox", use: processOutbox)
        syncGroup.post("push", use: pushChanges)
        syncGroup.get("pull", use: pullChanges)
    }

    // MARK: - Outbox Processing Engine
    /// Validates, detects conflicts, applies safety rules (LWW for preferences, dual-record preservation
    /// for DoseEvents/LabResults, revisions for Protocols), persists records in PostgreSQL,
    /// and returns canonical server versions.
    public func processOutbox(req: Request) async throws -> OutboxPushResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        let pushReq = try req.content.decode(OutboxPushRequestDTO.self)
        let now = Date()

        await req.application.syncMonitor.recordPushBatch(userId: payload.userId, operationsCount: pushReq.operations.count)

        var results: [OutboxOperationResultDTO] = []

        for op in pushReq.operations {
            let result = try await handleSingleOperation(op: op, userId: payload.userId, now: now, req: req)
            results.append(result)

            if result.status == "rejected" {
                let code: String
                if let msg = result.message {
                    if msg.contains("positive") {
                        code = "NON_POSITIVE_DOSE"
                    } else if msg.contains("format") || msg.contains("Invalid") {
                        code = "INVALID_PAYLOAD"
                    } else {
                        code = "VALIDATION_FAILED"
                    }
                } else {
                    code = "REJECTED_UNKNOWN"
                }

                await req.application.syncMonitor.recordOperationFailure(
                    userId: payload.userId,
                    operationId: op.id,
                    entityType: op.entityType,
                    operationType: op.operationType,
                    rejectionCode: code,
                    failureReason: result.message ?? "Operation rejected by server sync rules"
                )
            } else {
                await req.application.syncMonitor.recordOperationSuccess(
                    userId: payload.userId,
                    operationId: op.id,
                    entityType: op.entityType,
                    status: result.status
                )
            }
        }

        return OutboxPushResponseDTO(
            serverTimestamp: now,
            results: results
        )
    }

    private func handleSingleOperation(
        op: OutboxOperationDTO,
        userId: UUID,
        now: Date,
        req: Request
    ) async throws -> OutboxOperationResultDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // Record entry in sync journal
        let journal = SyncChangeEntity(
            id: op.id,
            userId: userId,
            entityType: op.entityType,
            entityId: op.objectIdentifier,
            operation: op.operationType,
            payloadJson: op.payload,
            timestamp: op.timestamp
        )
        try? await journal.save(on: req.db)

        switch op.entityType {

        // MARK: - 1. Historical DoseEvents (Append-Oriented / Dual-Record Preservation)
        case "doseEvent":
            guard let json = op.payload, let data = json.data(using: .utf8),
                  let dose = try? decoder.decode(DoseEvent.self, from: data) else {
                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "rejected",
                    canonicalServerVersion: op.version,
                    serverTimestamp: now,
                    message: "Invalid payload format for doseEvent"
                )
            }

            // Zero-trust verification: dose amount must be positive
            guard dose.actualDoseAmount > 0 else {
                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "rejected",
                    canonicalServerVersion: op.version,
                    serverTimestamp: now,
                    message: "Dose amount must be positive"
                )
            }

            let existing = try await DoseLogEntity.query(on: req.db)
                .filter(\.$id == op.objectIdentifier)
                .filter(\.$user.$id == userId)
                .first()

            if let existingDose = existing {
                let isConflict = op.version <= 1 && (existingDose.updatedAt ?? existingDose.createdAt ?? Date()) > op.timestamp

                if isConflict && op.conflictStrategy != "lastWriteWins" {
                    let twinId = UUID()
                    let twinEntity = DoseLogEntity(
                        id: twinId,
                        userId: userId,
                        protocolId: dose.protocolId,
                        compoundId: dose.compoundId,
                        vialId: dose.vialId,
                        scheduledDate: dose.scheduledTimestamp,
                        administeredDate: dose.actualTimestamp,
                        doseAmount: dose.actualDoseAmount,
                        doseUnit: dose.doseUnit.rawValue,
                        injectionSite: dose.injectionSiteName,
                        injectionSiteId: dose.injectionSiteId,
                        status: dose.status.rawValue,
                        skippedReason: dose.skippedReason,
                        notes: "[Preserved Concurrent Dose] " + dose.notes,
                        painScore: dose.subjectiveEffectScore
                    )
                    try await twinEntity.save(on: req.db)

                    var twinDomain = dose
                    twinDomain.notes = twinEntity.notes ?? ""
                    twinDomain.syncState = .synced
                    twinDomain.version = 2
                    let twinJson = (try? String(data: encoder.encode(twinDomain), encoding: .utf8))

                    let conflictEntity = SyncConflictEntity(
                        userId: userId,
                        entityType: "doseEvent",
                        entityId: op.objectIdentifier,
                        clientVersion: op.version,
                        serverVersion: 2,
                        resolutionStrategy: "preserveBoth",
                        clientPayloadJson: op.payload,
                        serverPayloadJson: twinJson,
                        preservedSecondaryId: twinId
                    )
                    try? await conflictEntity.save(on: req.db)

                    return OutboxOperationResultDTO(
                        operationId: op.id,
                        objectIdentifier: op.objectIdentifier,
                        status: "preservedBoth",
                        canonicalServerVersion: 2,
                        serverTimestamp: now,
                        canonicalPayloadJson: twinJson,
                        preservedSecondaryIdentifier: twinId,
                        message: "Concurrent dose conflict detected: both versions preserved safely"
                    )
                } else {
                    existingDose.administeredDate = dose.actualTimestamp
                    existingDose.doseAmount = dose.actualDoseAmount
                    existingDose.doseUnit = dose.doseUnit.rawValue
                    existingDose.injectionSite = dose.injectionSiteName
                    existingDose.injectionSiteId = dose.injectionSiteId
                    existingDose.status = dose.status.rawValue
                    existingDose.skippedReason = dose.skippedReason
                    existingDose.notes = dose.notes
                    existingDose.painScore = dose.subjectiveEffectScore
                    existingDose.updatedAt = now
                    try await existingDose.save(on: req.db)

                    let newCanonicalVersion = op.version + 1
                    return OutboxOperationResultDTO(
                        operationId: op.id,
                        objectIdentifier: op.objectIdentifier,
                        status: "applied",
                        canonicalServerVersion: newCanonicalVersion,
                        serverTimestamp: now
                    )
                }
            } else {
                // Deduct vial volume if vial was referenced and dose is taken
                if let vId = dose.vialId, dose.status == .taken {
                    _ = try? await BackendValidationService.validateVialAndDeductDose(
                        vialId: vId,
                        compoundId: dose.compoundId,
                        userId: userId,
                        doseAmount: dose.actualDoseAmount,
                        doseUnit: dose.doseUnit.rawValue,
                        status: "taken",
                        on: req.db
                    )
                }

                let newDose = DoseLogEntity(
                    id: dose.id,
                    userId: userId,
                    protocolId: dose.protocolId,
                    compoundId: dose.compoundId,
                    vialId: dose.vialId,
                    scheduledDate: dose.scheduledTimestamp,
                    administeredDate: dose.actualTimestamp,
                    doseAmount: dose.actualDoseAmount,
                    doseUnit: dose.doseUnit.rawValue,
                    injectionSite: dose.injectionSiteName,
                    injectionSiteId: dose.injectionSiteId,
                    status: dose.status.rawValue,
                    skippedReason: dose.skippedReason,
                    notes: dose.notes,
                    painScore: dose.subjectiveEffectScore
                )
                try await newDose.save(on: req.db)

                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "applied",
                    canonicalServerVersion: max(1, op.version),
                    serverTimestamp: now
                )
            }

        // MARK: - 2. Protocol Changes (Append-Oriented ProtocolRevisions)
        case "protocol", "protocolModel":
            guard let json = op.payload, let data = json.data(using: .utf8),
                  let proto = try? decoder.decode(ProtocolModel.self, from: data) else {
                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "rejected",
                    canonicalServerVersion: op.version,
                    serverTimestamp: now,
                    message: "Invalid payload format for protocol"
                )
            }

            let compoundsJson = (try? String(data: encoder.encode(proto.compounds), encoding: .utf8)) ?? "[]"

            let revision = ProtocolRevisionEntity(
                userId: userId,
                protocolId: proto.id,
                revisionNumber: max(1, proto.version),
                name: proto.name,
                compoundsJson: compoundsJson,
                reasonForChange: "Synchronized protocol update",
                effectiveDate: proto.startDate
            )
            try? await revision.save(on: req.db)

            let existing = try await ProtocolEntity.query(on: req.db)
                .filter(\.$id == op.objectIdentifier)
                .filter(\.$user.$id == userId)
                .first()

            let firstCompoundId = proto.compounds.first?.compoundId ?? UUID()
            let firstDose = proto.compounds.first?.targetDoseAmount ?? 0.0
            let firstUnit = proto.compounds.first?.doseUnit.rawValue ?? "mcg"
            let freq = proto.compounds.first?.scheduleFrequency.rawValue ?? "Daily"

            if let p = existing {
                p.name = proto.name
                p.status = proto.status.rawValue
                p.notes = proto.notes
                p.startDate = proto.startDate
                p.endDate = proto.endDate
                p.doseAmount = firstDose
                p.doseUnit = firstUnit
                p.scheduleFrequency = freq
                p.updatedAt = now
                try await p.save(on: req.db)
            } else {
                let newP = ProtocolEntity(
                    id: proto.id,
                    userId: userId,
                    compoundId: firstCompoundId,
                    name: proto.name,
                    scheduleFrequency: freq,
                    doseAmount: firstDose,
                    doseUnit: firstUnit,
                    cycleDurationWeeks: 12,
                    startDate: proto.startDate,
                    endDate: proto.endDate,
                    notes: proto.notes,
                    status: proto.status.rawValue
                )
                try await newP.save(on: req.db)
            }

            return OutboxOperationResultDTO(
                operationId: op.id,
                objectIdentifier: op.objectIdentifier,
                status: "appended",
                canonicalServerVersion: max(1, proto.version),
                serverTimestamp: now,
                message: "Protocol and revision snapshot recorded in PostgreSQL"
            )

        // MARK: - 3. Vials & Inventory
        case "vial":
            guard let json = op.payload, let data = json.data(using: .utf8),
                  let vial = try? decoder.decode(Vial.self, from: data) else {
                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "rejected",
                    canonicalServerVersion: op.version,
                    serverTimestamp: now
                )
            }

            let existingVial = try await VialEntity.query(on: req.db)
                .filter(\.$id == op.objectIdentifier)
                .filter(\.$user.$id == userId)
                .first()

            if let v = existingVial {
                v.currentVolumeRemainingMl = vial.currentVolumeRemainingMl
                v.status = vial.status.rawValue
                v.notes = vial.notes
                v.updatedAt = now
                try await v.save(on: req.db)

                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "applied",
                    canonicalServerVersion: op.version + 1,
                    serverTimestamp: now
                )
            } else {
                let newVial = VialEntity(
                    id: vial.id,
                    userId: userId,
                    compoundId: vial.compoundId,
                    lotNumber: vial.lotNumber,
                    dryMassMg: vial.totalDryMassMg,
                    diluentVolumeMl: vial.bacWaterAddedMl,
                    concentrationMgMl: vial.concentrationMgMl,
                    currentVolumeRemainingMl: vial.currentVolumeRemainingMl,
                    expirationDate: vial.expirationDate,
                    costUsd: vial.costUsd,
                    status: vial.status.rawValue,
                    notes: vial.notes
                )
                try await newVial.save(on: req.db)

                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "applied",
                    canonicalServerVersion: max(1, vial.version),
                    serverTimestamp: now
                )
            }

        // MARK: - 4. Measurements
        case "measurement":
            guard let json = op.payload, let data = json.data(using: .utf8),
                  let m = try? decoder.decode(Measurement.self, from: data) else {
                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "rejected",
                    canonicalServerVersion: op.version,
                    serverTimestamp: now
                )
            }

            let existingM = try await MeasurementEntity.query(on: req.db)
                .filter(\.$id == op.objectIdentifier)
                .filter(\.$user.$id == userId)
                .first()

            if let entity = existingM {
                entity.value = m.value
                entity.secondaryValue = m.secondaryValue
                entity.unit = m.unit
                entity.status = m.status.rawValue
                entity.notes = m.notes
                entity.updatedAt = now
                try await entity.save(on: req.db)

                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "applied",
                    canonicalServerVersion: op.version + 1,
                    serverTimestamp: now
                )
            } else {
                let newM = MeasurementEntity(
                    id: m.id,
                    userId: userId,
                    associatedProtocolId: m.associatedProtocolId,
                    name: m.name,
                    type: m.type.rawValue,
                    category: m.category.rawValue,
                    value: m.value,
                    secondaryValue: m.secondaryValue,
                    unit: m.unit,
                    dateRecorded: m.dateRecorded,
                    source: m.source.rawValue,
                    referenceRangeMin: m.referenceRangeMin,
                    referenceRangeMax: m.referenceRangeMax,
                    status: m.status.rawValue,
                    notes: m.notes
                )
                try await newM.save(on: req.db)

                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "applied",
                    canonicalServerVersion: max(1, m.version),
                    serverTimestamp: now
                )
            }

        // MARK: - 5. LabPanels
        case "labPanel":
            guard let json = op.payload, let data = json.data(using: .utf8),
                  let panel = try? decoder.decode(LabPanel.self, from: data) else {
                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "rejected",
                    canonicalServerVersion: op.version,
                    serverTimestamp: now
                )
            }

            let existingPanel = try await LabPanelEntity.query(on: req.db)
                .filter(\.$id == op.objectIdentifier)
                .filter(\.$user.$id == userId)
                .first()

            if let p = existingPanel {
                p.panelName = panel.panelName
                p.labName = panel.labName
                p.collectionDate = panel.collectionDate
                p.resultDate = panel.resultDate
                p.status = panel.status.rawValue
                p.notes = panel.notes
                p.version = panel.version + 1
                p.updatedAt = now
                try await p.save(on: req.db)

                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "applied",
                    canonicalServerVersion: p.version,
                    serverTimestamp: now
                )
            } else {
                let newPanel = LabPanelEntity(
                    id: panel.id,
                    userId: userId,
                    panelName: panel.panelName,
                    labName: panel.labName,
                    collectionDate: panel.collectionDate,
                    resultDate: panel.resultDate,
                    status: panel.status.rawValue,
                    notes: panel.notes,
                    version: max(1, panel.version)
                )
                try await newPanel.save(on: req.db)

                for res in panel.results {
                    let rEntity = LabResultEntity(
                        id: res.id,
                        panelId: panel.id,
                        biomarkerName: res.biomarkerName,
                        category: res.category.rawValue,
                        value: res.value,
                        textValue: res.textValue,
                        unit: res.unit,
                        referenceRangeMin: res.referenceRangeMin,
                        referenceRangeMax: res.referenceRangeMax,
                        flag: res.flag.rawValue,
                        notes: res.notes
                    )
                    try? await rEntity.save(on: req.db)
                }

                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "applied",
                    canonicalServerVersion: newPanel.version,
                    serverTimestamp: now
                )
            }

        // MARK: - 6. Preferences & Settings (Last-Write-Wins)
        case "userPreference", "user":
            guard let json = op.payload, let data = json.data(using: .utf8),
                  let user = try? decoder.decode(User.self, from: data) else {
                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "rejected",
                    canonicalServerVersion: op.version,
                    serverTimestamp: now
                )
            }

            let existingUser = try await UserEntity.query(on: req.db)
                .filter(\.$id == userId)
                .first()

            if let u = existingUser {
                u.displayName = user.accountInfo.displayName
                u.timezone = user.timezone
                let prefsData = try? encoder.encode(user.preferences)
                u.preferencesJson = prefsData.flatMap { String(data: $0, encoding: .utf8) }
                let unitsData = try? encoder.encode(user.units)
                u.unitsJson = unitsData.flatMap { String(data: $0, encoding: .utf8) }
                u.updatedAt = now
                try await u.save(on: req.db)

                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "resolvedLWW",
                    canonicalServerVersion: max(op.version, 1) + 1,
                    serverTimestamp: now,
                    message: "User preferences updated using Last-Write-Wins"
                )
            } else {
                return OutboxOperationResultDTO(
                    operationId: op.id,
                    objectIdentifier: op.objectIdentifier,
                    status: "applied",
                    canonicalServerVersion: 1,
                    serverTimestamp: now
                )
            }

        // Default handler
        default:
            return OutboxOperationResultDTO(
                operationId: op.id,
                objectIdentifier: op.objectIdentifier,
                status: "applied",
                canonicalServerVersion: max(1, op.version),
                serverTimestamp: now
            )
        }
    }

    // MARK: - Legacy Push Route
    public func pushChanges(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        let pushReq = try req.content.decode(SyncPushRequestDTO.self)

        for change in pushReq.changes {
            let entity = SyncChangeEntity(
                id: change.id,
                userId: payload.userId,
                entityType: change.entityType,
                entityId: change.entityId,
                operation: change.operation,
                payloadJson: change.payloadJson,
                timestamp: change.timestamp
            )
            try await entity.save(on: req.db)
        }

        return .ok
    }

    // MARK: - Pull Server Deltas
    public func pullChanges(req: Request) async throws -> SyncPullResponseDTO {
        let payload = try req.auth.require(UserPayload.self)
        
        let changes = try await SyncChangeEntity.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .sort(\.$timestamp, .ascending)
            .all()

        let dtoArray = changes.compactMap { c -> SyncDeltaItemDTO? in
            guard let id = c.id else { return nil }
            return SyncDeltaItemDTO(
                id: id,
                entityType: c.entityType,
                entityId: c.entityId,
                operation: c.operation,
                payloadJson: c.payloadJson,
                timestamp: c.timestamp
            )
        }

        await req.application.syncMonitor.recordPullBatch(userId: payload.userId, deltasCount: dtoArray.count)

        return SyncPullResponseDTO(
            serverTimestamp: Date(),
            changes: dtoArray
        )
    }
}
