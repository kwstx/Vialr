import Foundation
import Domain

public typealias Measurement = Domain.Measurement

// MARK: - Validation Engine Protocol

/// Architectural boundary defining domain-wide validation rules across all user and system inputs.
/// Classifies issues strictly into Informational notices, Warnings (explaining what is unusual neutrally),
/// and Blocking Errors.
public protocol ValidationEngineProtocol: Sendable {

    // MARK: 1. Dose & Administration Inputs
    func validateDoseEntry(
        candidate: DoseLog,
        compound: Compound?,
        recentLogs: [DoseLog],
        attachedVial: Vial?,
        activeProtocol: ProtocolModel?,
        recentSiteEvents: [InjectionSiteEvent]?,
        referenceDate: Date
    ) -> ValidationResult

    func validateDoseConfirmationRequest(
        request: DoseConfirmationRequest,
        compound: Compound?,
        vial: Vial?,
        protocolModel: ProtocolModel?,
        recentLogs: [DoseLog],
        recentSiteEvents: [InjectionSiteEvent]?,
        referenceDate: Date
    ) -> ValidationResult

    func validateDoseEvent(
        doseEvent: DoseEvent,
        compound: Compound?,
        vial: Vial?,
        protocolModel: ProtocolModel?,
        recentLogs: [DoseLog],
        recentSiteEvents: [InjectionSiteEvent]?,
        referenceDate: Date
    ) -> ValidationResult

    // MARK: 2. Protocol & Schedule Configuration
    func validateProtocol(
        protocolModel: ProtocolModel,
        existingProtocols: [ProtocolModel]
    ) -> ValidationResult

    func validateProtocolCompound(
        item: ProtocolCompound,
        parentProtocolStartDate: Date?
    ) -> ValidationResult

    // MARK: 3. Inventory Vials & Supplies
    func validateVial(
        vial: Vial,
        associatedCompound: Compound?,
        referenceDate: Date
    ) -> ValidationResult

    func validateSupplyItem(
        item: SupplyItem
    ) -> ValidationResult

    // MARK: 4. Reconstitution & Solution Dynamics
    func validateReconstitution(
        dryMassMg: Double,
        diluentVolumeMl: Double,
        diluentType: DiluentType,
        targetDoseAmount: Double,
        targetDoseUnit: DoseUnit,
        syringeSpecification: SyringeSpecification?,
        compoundActivityRatio: CompoundActivityRatio?,
        referenceDate: Date
    ) -> ValidationResult

    func validateReconstitutionRecord(
        record: ReconstitutionRecord,
        referenceDate: Date
    ) -> ValidationResult

    func validateReconstitutionInput(
        _ input: ReconstitutionInput
    ) -> ValidationResult

    // MARK: 5. Measurements, Vitals & Biomarkers
    func validateMeasurement(
        measurement: Measurement,
        recentMeasurements: [Measurement],
        referenceDate: Date
    ) -> ValidationResult

    // MARK: 6. Lab Panels & Bloodwork Analytes
    func validateLabPanel(
        panel: LabPanel,
        referenceDate: Date
    ) -> ValidationResult

    func validateLabResult(
        result: LabResult,
        panelCollectionDate: Date?
    ) -> ValidationResult

    // MARK: 7. Inventory Events & Ledger
    func validateInventoryEvent(
        event: InventoryEvent,
        vialState: VialAccountingState?
    ) -> ValidationResult

    // MARK: 8. Symptom Logs & Outcomes
    func validateSymptomLog(
        log: SymptomLog,
        referenceDate: Date
    ) -> ValidationResult

    // MARK: 9. Injection Site Rotation
    func validateInjectionSiteEvent(
        event: InjectionSiteEvent,
        recentSiteEvents: [InjectionSiteEvent]
    ) -> ValidationResult
}

// MARK: - Validation Engine Implementation

/// Unified domain validation engine enforcing safety, data integrity, unit consistency,
/// temporal sanity, and inventory bounds.
public struct ValidationEngine: ValidationEngineProtocol, Sendable {

    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: - 1. Dose Entry & Administration Validation

    public func validateDoseEntry(
        candidate: DoseLog,
        compound: Compound? = nil,
        recentLogs: [DoseLog] = [],
        attachedVial: Vial? = nil,
        activeProtocol: ProtocolModel? = nil,
        recentSiteEvents: [InjectionSiteEvent]? = nil,
        referenceDate: Date = Date()
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        let candidateDate = candidate.loggedDate ?? candidate.scheduledDate

        // 1.1 Required Fields & Basic Structural Checks
        if candidate.compoundName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "compoundName",
                    title: "Missing Compound Name",
                    explanation: "Every dose record must specify a valid compound name.",
                    suggestedFix: "Select a compound from the library or provide a custom name."
                )
            )
        }

        if !candidate.doseAmount.isFinite || candidate.doseAmount.isNaN {
            issues.append(
                .blockingError(
                    category: .dataIntegrity,
                    field: "doseAmount",
                    title: "Invalid Dose Amount",
                    explanation: "Dose amount must be a finite numerical value.",
                    suggestedFix: "Enter a valid positive number."
                )
            )
        } else if candidate.doseAmount <= 0 {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "doseAmount",
                    title: "Non-Positive Dose Amount",
                    explanation: "Dose amount must be strictly greater than zero.",
                    suggestedFix: "Enter a positive dose quantity (e.g., 250 mcg)."
                )
            )
        }

        // 1.2 Unit Consistency & Dimension Checks
        if let targetCompound = compound {
            // Compound ID mismatch
            if targetCompound.id != candidate.compoundId {
                issues.append(
                    .warning(
                        category: .inconsistentUnits,
                        field: "compoundId",
                        title: "Compound Identifier Mismatch",
                        explanation: "Candidate dose references compound ID '\(candidate.compoundId)', but was evaluated against compound '\(targetCompound.name)' (\(targetCompound.id)).",
                        suggestedFix: "Ensure candidate dose references the correct compound entity."
                    )
                )
            }

            // Dimension compatibility check
            let isMassUnit = candidate.doseUnit == .mg || candidate.doseUnit == .mcg
            let isVolumeUnit = candidate.doseUnit == .ml
            let isBiologicalUnit = candidate.doseUnit == .iu

            let compoundDefaultIsMass = targetCompound.defaultUnit == .mg || targetCompound.defaultUnit == .mcg
            let compoundDefaultIsVolume = targetCompound.defaultUnit == .ml
            let compoundDefaultIsIU = targetCompound.defaultUnit == .iu

            if compoundDefaultIsMass && isVolumeUnit && attachedVial == nil && !targetCompound.requiresReconstitution {
                issues.append(
                    .warning(
                        category: .inconsistentUnits,
                        field: "doseUnit",
                        title: "Unit Dimension Mismatch",
                        explanation: "The compound '\(targetCompound.name)' defaults to mass units (\(targetCompound.defaultUnit.rawValue)), but the dose was entered in liquid volume (\(candidate.doseUnit.rawValue)) without an attached concentration.",
                        suggestedFix: "Enter the dose in \(targetCompound.defaultUnit.rawValue) or attach a reconstituted vial with defined concentration."
                    )
                )
            } else if compoundDefaultIsIU && !isBiologicalUnit {
                issues.append(
                    .info(
                        category: .inconsistentUnits,
                        field: "doseUnit",
                        title: "Dosing Unit Variation",
                        explanation: "The compound '\(targetCompound.name)' standard default unit is IU, but this dose was entered in \(candidate.doseUnit.rawValue).",
                        suggestedFix: "Verify that unit conversion between mass and biological activity (IU) was intended."
                    )
                )
            }

            // Magnitude conversion check (e.g. entered 250 mg instead of 250 mcg for a peptide)
            if targetCompound.defaultUnit == .mcg && candidate.doseUnit == .mg && candidate.doseAmount >= 10.0 {
                issues.append(
                    .warning(
                        category: .inconsistentUnits,
                        field: "doseUnit",
                        title: "Potential Unit Scale Disparity",
                        explanation: "You entered \(candidate.doseAmount) mg. For \(targetCompound.name), doses are typically measured in micrograms (mcg). 1 mg = 1,000 mcg.",
                        suggestedFix: "Double-check if \(candidate.doseAmount) mcg was intended instead of \(candidate.doseAmount) mg."
                    )
                )
            }

            // 1.3 Outlier Dose Checks (>3x, >10x, or <0.01x typical dose)
            if targetCompound.typicalDose > 0 {
                let candidateInCanonicalMg: Double
                switch candidate.doseUnit {
                case .mg: candidateInCanonicalMg = candidate.doseAmount
                case .mcg: candidateInCanonicalMg = candidate.doseAmount / 1000.0
                case .ml: candidateInCanonicalMg = candidate.doseAmount // Normalized proxy
                case .iu: candidateInCanonicalMg = candidate.doseAmount / 3.0 // Standard fallback proxy
                }

                let typicalInCanonicalMg: Double
                switch targetCompound.defaultUnit {
                case .mg: typicalInCanonicalMg = targetCompound.typicalDose
                case .mcg: typicalInCanonicalMg = targetCompound.typicalDose / 1000.0
                case .ml: typicalInCanonicalMg = targetCompound.typicalDose
                case .iu: typicalInCanonicalMg = targetCompound.typicalDose / 3.0
                }

                if typicalInCanonicalMg > 0 {
                    let ratio = candidateInCanonicalMg / typicalInCanonicalMg

                    if ratio >= 10.0 {
                        issues.append(
                            .warning(
                                category: .outlierDose,
                                field: "doseAmount",
                                title: "Unusually High Dose Outlier (10x+)",
                                explanation: "The entered dose of \(candidate.doseAmount) \(candidate.doseUnit.rawValue) is \(String(format: "%.1f", ratio))x higher than the reference typical dose of \(targetCompound.typicalDose) \(targetCompound.defaultUnit.rawValue) for \(targetCompound.name).",
                                suggestedFix: "Verify syringe calibration and decimal point placement before proceeding."
                            )
                        )
                    } else if ratio >= 3.0 {
                        issues.append(
                            .warning(
                                category: .outlierDose,
                                field: "doseAmount",
                                title: "Unusually High Dose Detected (3x+)",
                                explanation: "The entered dose of \(candidate.doseAmount) \(candidate.doseUnit.rawValue) is more than 3x the standard reference dose of \(targetCompound.typicalDose) \(targetCompound.defaultUnit.rawValue).",
                                suggestedFix: "Confirm your syringe unit markings and dilution calculation."
                            )
                        )
                    } else if ratio <= 0.01 && ratio > 0.0 {
                        issues.append(
                            .info(
                                category: .outlierDose,
                                field: "doseAmount",
                                title: "Unusually Low Dose (<1%)",
                                explanation: "The entered dose of \(candidate.doseAmount) \(candidate.doseUnit.rawValue) is less than 1% of the standard reference dose of \(targetCompound.typicalDose) \(targetCompound.defaultUnit.rawValue).",
                                suggestedFix: "Check if micro-dosing or titration was intended."
                            )
                        )
                    }
                }
            }

            // Min/Max configured range check
            if let minDose = targetCompound.doseRangeMin, targetCompound.defaultUnit == candidate.doseUnit, candidate.doseAmount < minDose {
                issues.append(
                    .info(
                        category: .outlierDose,
                        field: "doseAmount",
                        title: "Dose Below Reference Range Minimum",
                        explanation: "The entered dose (\(candidate.doseAmount) \(candidate.doseUnit.rawValue)) is below the configured reference minimum (\(minDose) \(candidate.doseUnit.rawValue)).",
                        suggestedFix: "Verify if a sub-therapeutic dose was intended."
                    )
                )
            }

            if let maxDose = targetCompound.doseRangeMax, targetCompound.defaultUnit == candidate.doseUnit, candidate.doseAmount > maxDose {
                issues.append(
                    .warning(
                        category: .outlierDose,
                        field: "doseAmount",
                        title: "Dose Exceeds Reference Range Maximum",
                        explanation: "The entered dose (\(candidate.doseAmount) \(candidate.doseUnit.rawValue)) exceeds the configured reference maximum (\(maxDose) \(candidate.doseUnit.rawValue)).",
                        suggestedFix: "Check whether titration or an elevated protocol step was intended."
                    )
                )
            }
        }

        // 1.4 Unexpected Duplicate Events & Rapid Re-dosing Interval
        let sameCompoundLogs = recentLogs
            .filter { $0.compoundId == candidate.compoundId && $0.id != candidate.id && $0.status == .taken }
            .sorted(by: { ($0.loggedDate ?? $0.scheduledDate) > ($1.loggedDate ?? $1.scheduledDate) })

        if let lastDose = sameCompoundLogs.first {
            let lastDate = lastDose.loggedDate ?? lastDose.scheduledDate
            let intervalHours = abs(candidateDate.timeIntervalSince(lastDate)) / 3600.0
            let intervalMinutes = intervalHours * 60.0

            if intervalMinutes < 5.0 && abs(lastDose.actualDoseAmount - candidate.actualDoseAmount) < 0.001 {
                issues.append(
                    .warning(
                        category: .unexpectedDuplicate,
                        field: "actualTimestamp",
                        title: "Potential Duplicate Submission",
                        explanation: "An identical dose of \(candidate.compoundName) (\(candidate.actualDoseAmount) \(candidate.doseUnit.rawValue)) was already recorded \(String(format: "%.0f", intervalMinutes)) minutes ago.",
                        suggestedFix: "Verify that this is not an unintentional double tap or redundant sync record."
                    )
                )
            } else if intervalHours < 4.0 {
                issues.append(
                    .warning(
                        category: .unexpectedDuplicate,
                        field: "actualTimestamp",
                        title: "Short Dosing Interval Detected",
                        explanation: "A dose of \(candidate.compoundName) was logged \(String(format: "%.1f", intervalHours)) hours ago. Standard schedules typically space administrations further apart.",
                        suggestedFix: "Ensure you are not accidentally logging an unintended repeat dose."
                    )
                )
            }
        }

        // 1.5 Inventory Discrepancy & Vial State
        if let vial = attachedVial {
            // Compound match check
            if vial.compoundId != candidate.compoundId && !vial.compoundName.localizedCaseInsensitiveContains(candidate.compoundName) {
                issues.append(
                    .blockingError(
                        category: .inventoryDiscrepancy,
                        field: "vialId",
                        title: "Vial Compound Mismatch",
                        explanation: "The selected inventory vial is cataloged as '\(vial.compoundName)', but the dose is being recorded for '\(candidate.compoundName)'.",
                        suggestedFix: "Attach an inventory vial containing \(candidate.compoundName)."
                    )
                )
            }

            // Status check
            if vial.status == .depleted {
                issues.append(
                    .blockingError(
                        category: .inventoryDiscrepancy,
                        field: "vialId",
                        title: "Vial Status Is Depleted",
                        explanation: "Cannot draw dose from vial '\(vial.lotNumber.isEmpty ? vial.id.uuidString : vial.lotNumber)' because its status is marked as Depleted (0 mL remaining).",
                        suggestedFix: "Select an active vial with available liquid volume or reconstitute a new vial."
                    )
                )
            } else if vial.status == .discarded || vial.status == .damaged {
                issues.append(
                    .blockingError(
                        category: .inventoryDiscrepancy,
                        field: "vialId",
                        title: "Vial Unavailable / Inactive",
                        explanation: "The attached vial is marked as \(vial.status.rawValue) and is not available for active dosing.",
                        suggestedFix: "Select an active in-use vial from inventory."
                    )
                )
            } else if vial.status == .unopened && !vial.isReconstituted && (compound?.requiresReconstitution ?? true) {
                issues.append(
                    .blockingError(
                        category: .inventoryDiscrepancy,
                        field: "vialId",
                        title: "Vial Not Yet Reconstituted",
                        explanation: "The attached vial is still recorded as unopened dry powder. Diluent must be added before liquid doses can be drawn.",
                        suggestedFix: "Reconstitute the vial in the Inventory tab before confirming dose administration."
                    )
                )
            }

            // Volume overdraw check
            if let conc = vial.concentrationMgMl, conc > 0 {
                let doseMg = (candidate.doseUnit == .mg) ? candidate.actualDoseAmount : (candidate.actualDoseAmount / 1000.0)
                let requiredDrawMl = doseMg / conc
                let availableVolMl = vial.currentVolumeRemainingMl ?? (vial.bacWaterAddedMl ?? 0.0)

                if requiredDrawMl > (availableVolMl + 0.001) {
                    issues.append(
                        .blockingError(
                            category: .inventoryDiscrepancy,
                            field: "doseAmount",
                            title: "Insufficient Vial Volume",
                            explanation: "This dose requires drawing \(String(format: "%.3f", requiredDrawMl)) mL, but only \(String(format: "%.3f", availableVolMl)) mL remains in the attached vial.",
                            suggestedFix: "Adjust the dose amount or record a new reconstituted vial."
                        )
                    )
                } else if (availableVolMl - requiredDrawMl) <= 0.02 {
                    issues.append(
                        .info(
                            category: .inventoryDiscrepancy,
                            field: "vialId",
                            title: "Vial Reaching Depletion",
                            explanation: "Drawing this dose will leave approximately \(String(format: "%.3f", max(0.0, availableVolMl - requiredDrawMl))) mL in the vial.",
                            suggestedFix: "Prepare a backup vial for upcoming scheduled doses."
                        )
                    )
                }
            }

            // 1.6 Expired Records & Freshness Window
            if let expDate = vial.expirationDate, candidateDate > expDate {
                let formattedExp = expDate.formatted(date: .abbreviated, time: .omitted)
                issues.append(
                    .warning(
                        category: .expiredRecord,
                        field: "vialId",
                        title: "Vial Expiration Date Passed",
                        explanation: "The attached vial has an expiration date of \(formattedExp), which is prior to the dose timestamp.",
                        suggestedFix: "Verify the vial packaging expiration date or update vial records."
                    )
                )
            }

            if let reconDate = vial.reconstitutedDate {
                let daysOld = calendar.dateComponents([.day], from: reconDate, to: candidateDate).day ?? 0
                if daysOld > 30 {
                    issues.append(
                        .warning(
                            category: .expiredRecord,
                            field: "vialId",
                            title: "Reconstitution Freshness Window Exceeded",
                            explanation: "The attached solution was reconstituted \(daysOld) days ago. Reconstituted peptide solutions are generally recommended to be used within 28–30 days.",
                            suggestedFix: "Inspect solution clarity and consider reconstituting a fresh vial."
                        )
                    )
                }
            }
        }

        // 1.7 Schedule Conflicts
        if let proto = activeProtocol {
            if proto.status == .paused {
                issues.append(
                    .warning(
                        category: .scheduleConflict,
                        field: "protocolId",
                        title: "Protocol Is Paused",
                        explanation: "The associated protocol '\(proto.name)' is currently marked as Paused.",
                        suggestedFix: "Resume the protocol if regular administrations are restarting."
                    )
                )
            } else if proto.status == .completed || proto.status == .archived {
                issues.append(
                    .warning(
                        category: .scheduleConflict,
                        field: "protocolId",
                        title: "Protocol Has Ended",
                        explanation: "The associated protocol '\(proto.name)' is marked as \(proto.status.rawValue).",
                        suggestedFix: "Link the dose to an active protocol or log as an unscheduled dose."
                    )
                )
            }

            if let end = proto.endDate, candidateDate > end {
                issues.append(
                    .info(
                        category: .scheduleConflict,
                        field: "scheduledTimestamp",
                        title: "Dose After Protocol Planned End Date",
                        explanation: "The dose timestamp is after the scheduled protocol end date of \(end.formatted(date: .abbreviated, time: .omitted)).",
                        suggestedFix: "Extend the protocol duration if continuing therapy."
                    )
                )
            }

            // Schedule rule adherence check
            if let protoCompound = proto.compounds.first(where: { $0.compoundId == candidate.compoundId }) {
                let isScheduled = protoCompound.isScheduled(on: candidateDate, protocolStart: proto.startDate)
                if !isScheduled && candidate.isPRNOrUnscheduled == false && protoCompound.scheduleRule != .asNeeded {
                    issues.append(
                        .warning(
                            category: .scheduleConflict,
                            field: "scheduledTimestamp",
                            title: "Dose on Unscheduled Rest Day",
                            explanation: "According to the '\(proto.name)' schedule rule (\(protoCompound.scheduleRule.description)), no dose was planned for this date.",
                            suggestedFix: "Confirm if an off-schedule or PRN dose was intentionally administered."
                        )
                    )
                }
            }
        }

        // 1.8 Anatomical Route & Site Repetition
        let isInjectionRoute = candidate.actualRoute == .subcutaneous || candidate.actualRoute == .intramuscular || candidate.actualRoute == .intravenous
        if !isInjectionRoute && candidate.injectionSiteId != nil {
            issues.append(
                .warning(
                    category: .anatomicalRouteMismatch,
                    field: "injectionSiteId",
                    title: "Injection Site Specified for Non-Injectable Route",
                    explanation: "An injection site was specified, but the administration route is \(candidate.actualRoute.rawValue).",
                    suggestedFix: "Clear the injection site selection for oral, nasal, or topical routes."
                )
            )
        }

        if let siteEvents = recentSiteEvents, let currentSiteId = candidate.injectionSiteId {
            let sortedEvents = siteEvents.sorted(by: { $0.timestamp > $1.timestamp })
            let consecutiveUses = sortedEvents.prefix(while: { $0.siteId == currentSiteId }).count
            if consecutiveUses >= 2 {
                issues.append(
                    .warning(
                        category: .anatomicalRouteMismatch,
                        field: "injectionSiteId",
                        title: "Consecutive Injection Site Overuse",
                        explanation: "Site '\(candidate.injectionSiteName ?? currentSiteId)' was used for the last \(consecutiveUses) consecutive doses. Rotating anatomical quadrants is standard practice to rest tissue.",
                        suggestedFix: "Select an alternate injection site quadrant (e.g. opposite side or region)."
                    )
                )
            }
        }

        return ValidationResult(issues: issues)
    }

    public func validateDoseConfirmationRequest(
        request: DoseConfirmationRequest,
        compound: Compound? = nil,
        vial: Vial? = nil,
        protocolModel: ProtocolModel? = nil,
        recentLogs: [DoseLog] = [],
        recentSiteEvents: [InjectionSiteEvent]? = nil,
        referenceDate: Date = Date()
    ) -> ValidationResult {
        let dummyLog = DoseLog(
            id: request.doseEventId ?? UUID(),
            protocolId: request.protocolId,
            protocolItemId: request.protocolCompoundId,
            compoundId: request.compoundId,
            compoundName: request.compoundName,
            scheduledDate: request.scheduledTimestamp ?? request.actualTimestamp,
            loggedDate: request.actualTimestamp,
            doseAmount: request.actualDoseAmount,
            doseUnit: request.doseUnit,
            status: .taken,
            injectionSiteId: request.injectionSiteId,
            injectionSiteName: request.injectionSiteName,
            vialId: request.vialId,
            administrationRoute: request.actualRoute,
            notes: request.notes
        )

        return validateDoseEntry(
            candidate: dummyLog,
            compound: compound,
            recentLogs: recentLogs,
            attachedVial: vial,
            activeProtocol: protocolModel,
            recentSiteEvents: recentSiteEvents,
            referenceDate: referenceDate
        )
    }

    public func validateDoseEvent(
        doseEvent: DoseEvent,
        compound: Compound? = nil,
        vial: Vial? = nil,
        protocolModel: ProtocolModel? = nil,
        recentLogs: [DoseLog] = [],
        recentSiteEvents: [InjectionSiteEvent]? = nil,
        referenceDate: Date = Date()
    ) -> ValidationResult {
        validateDoseEntry(
            candidate: doseEvent,
            compound: compound,
            recentLogs: recentLogs,
            attachedVial: vial,
            activeProtocol: protocolModel,
            recentSiteEvents: recentSiteEvents,
            referenceDate: referenceDate
        )
    }

    // MARK: - 2. Protocol & Schedule Validation

    public func validateProtocol(
        protocolModel: ProtocolModel,
        existingProtocols: [ProtocolModel] = []
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        // Required Name
        if protocolModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "name",
                    title: "Missing Protocol Name",
                    explanation: "A protocol name is required to organize tracking data.",
                    suggestedFix: "Provide a descriptive protocol name (e.g., 'Recovery Protocol 2026')."
                )
            )
        }

        // Required Compounds
        if protocolModel.compounds.isEmpty {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "compounds",
                    title: "No Compounds Assigned",
                    explanation: "A protocol must track at least one compound.",
                    suggestedFix: "Add at least one compound to the protocol stack."
                )
            )
        }

        // Date Range Sanity
        if let end = protocolModel.endDate {
            if protocolModel.startDate > end {
                issues.append(
                    .blockingError(
                        category: .scheduleConflict,
                        field: "endDate",
                        title: "Inverted Protocol Date Range",
                        explanation: "The protocol start date (\(protocolModel.startDate.formatted(date: .abbreviated, time: .omitted))) cannot be after the end date (\(end.formatted(date: .abbreviated, time: .omitted))).",
                        suggestedFix: "Set an end date that occurs after the start date."
                    )
                )
            }
        }

        // Validate Individual Compounds in Protocol
        for (index, compoundItem) in protocolModel.compounds.enumerated() {
            let compoundResult = validateProtocolCompound(item: compoundItem, parentProtocolStartDate: protocolModel.startDate)
            for issue in compoundResult.issues {
                let contextKey = "compounds[\(index)].\(issue.field ?? "field")"
                issues.append(
                    ValidationIssue(
                        id: issue.id,
                        severity: issue.severity,
                        category: issue.category,
                        field: contextKey,
                        title: "\(compoundItem.compoundName): \(issue.title)",
                        explanation: issue.explanation,
                        suggestedFix: issue.suggestedFix,
                        contextData: issue.contextData
                    )
                )
            }
        }

        // Check for concurrent duplicate active compounds across protocols
        if protocolModel.status == .active {
            let activeOtherProtocols = existingProtocols.filter { $0.id != protocolModel.id && $0.status == .active }
            for compoundItem in protocolModel.compounds {
                for otherProto in activeOtherProtocols {
                    if otherProto.compounds.contains(where: { $0.compoundId == compoundItem.compoundId }) {
                        issues.append(
                            .warning(
                                category: .scheduleConflict,
                                field: "compounds",
                                title: "Concurrent Active Compound Overlap",
                                explanation: "Compound '\(compoundItem.compoundName)' is also actively scheduled in '\(otherProto.name)'.",
                                suggestedFix: "Verify that managing two separate active protocols with the same compound is intentional."
                            )
                        )
                    }
                }
            }
        }

        return ValidationResult(issues: issues)
    }

    public func validateProtocolCompound(
        item: ProtocolCompound,
        parentProtocolStartDate: Date? = nil
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        // Dose Amount
        if !item.doseAmount.isFinite || item.doseAmount.isNaN {
            issues.append(
                .blockingError(
                    category: .dataIntegrity,
                    field: "doseAmount",
                    title: "Invalid Dose Amount",
                    explanation: "Dose amount must be a valid numerical value.",
                    suggestedFix: "Enter a positive number."
                )
            )
        } else if item.doseAmount <= 0 {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "doseAmount",
                    title: "Non-Positive Dose Amount",
                    explanation: "Protocol dose amount must be strictly greater than zero.",
                    suggestedFix: "Specify a planned dose greater than 0."
                )
            )
        }

        // Dose Range Min / Max
        if let min = item.doseRangeMin, let max = item.doseRangeMax {
            if min > max {
                issues.append(
                    .blockingError(
                        category: .scheduleConflict,
                        field: "doseRangeMax",
                        title: "Inverted Dose Range",
                        explanation: "Configured minimum dose (\(min)) cannot exceed the maximum dose (\(max)).",
                        suggestedFix: "Ensure minimum dose is less than or equal to maximum dose."
                    )
                )
            }
        }

        // Schedule Rule Specifics
        switch item.scheduleRule {
        case .cycle(let daysOn, let daysOff):
            if daysOn <= 0 {
                issues.append(
                    .blockingError(
                        category: .scheduleConflict,
                        field: "scheduleRule",
                        title: "Invalid Cycle Days On",
                        explanation: "Cycle 'Days On' must be at least 1 day.",
                        suggestedFix: "Set Days On to 1 or greater (e.g. 5 Days On / 2 Days Off)."
                    )
                )
            }
            if daysOff < 0 {
                issues.append(
                    .blockingError(
                        category: .scheduleConflict,
                        field: "scheduleRule",
                        title: "Negative Cycle Days Off",
                        explanation: "Cycle 'Days Off' cannot be negative.",
                        suggestedFix: "Set Days Off to 0 or greater."
                    )
                )
            }
        case .everyNDays(let n):
            if n <= 0 {
                issues.append(
                    .blockingError(
                        category: .scheduleConflict,
                        field: "scheduleRule",
                        title: "Invalid Recurrence Interval",
                        explanation: "Interval 'Every N Days' must be 1 or greater.",
                        suggestedFix: "Set interval to at least 1 day."
                    )
                )
            }
        case .daysOfWeek(let days):
            if days.isEmpty {
                issues.append(
                    .blockingError(
                        category: .scheduleConflict,
                        field: "scheduleRule",
                        title: "No Weekdays Selected",
                        explanation: "Specific weekday schedule requires selecting at least one day.",
                        suggestedFix: "Select one or more days of the week."
                    )
                )
            } else if days.contains(where: { $0 < 1 || $0 > 7 }) {
                issues.append(
                    .blockingError(
                        category: .scheduleConflict,
                        field: "scheduleRule",
                        title: "Invalid Weekday Values",
                        explanation: "Selected weekdays must be between 1 (Sunday) and 7 (Saturday).",
                        suggestedFix: "Select valid weekday options."
                    )
                )
            }
        case .customInterval(let hours):
            if hours <= 0 {
                issues.append(
                    .blockingError(
                        category: .scheduleConflict,
                        field: "scheduleRule",
                        title: "Invalid Hourly Interval",
                        explanation: "Interval hours must be strictly greater than zero.",
                        suggestedFix: "Specify an hourly interval greater than 0 (e.g. 8 hours)."
                    )
                )
            }
        default:
            break
        }

        // Times Per Day
        if item.timesPerDay < 1 {
            issues.append(
                .blockingError(
                    category: .scheduleConflict,
                    field: "timesPerDay",
                    title: "Invalid Frequency Count",
                    explanation: "Times per day must be at least 1.",
                    suggestedFix: "Set times per day to 1 or higher."
                )
            )
        }

        // Titration Step Rule
        if let titration = item.titrationStep {
            if titration.stepIntervalDays <= 0 {
                issues.append(
                    .blockingError(
                        category: .scheduleConflict,
                        field: "titrationStep",
                        title: "Invalid Titration Interval",
                        explanation: "Titration step interval must be at least 1 day.",
                        suggestedFix: "Set titration step interval to 1 day or greater (e.g. 7 days)."
                    )
                )
            }
            if titration.startDose <= 0 || titration.targetDose <= 0 {
                issues.append(
                    .blockingError(
                        category: .scheduleConflict,
                        field: "titrationStep",
                        title: "Non-Positive Titration Doses",
                        explanation: "Titration start dose and target dose must both be positive numbers.",
                        suggestedFix: "Specify positive start and target doses."
                    )
                )
            }
            if titration.startDose < titration.targetDose && titration.stepAmount <= 0 {
                issues.append(
                    .blockingError(
                        category: .scheduleConflict,
                        field: "titrationStep",
                        title: "Titration Step Sign Mismatch",
                        explanation: "Target dose (\(titration.targetDose)) is higher than start dose (\(titration.startDose)), but step amount is \(titration.stepAmount).",
                        suggestedFix: "Set a positive step amount to increase dose over time."
                    )
                )
            } else if titration.startDose > titration.targetDose && titration.stepAmount >= 0 {
                issues.append(
                    .blockingError(
                        category: .scheduleConflict,
                        field: "titrationStep",
                        title: "Taper Step Sign Mismatch",
                        explanation: "Target dose (\(titration.targetDose)) is lower than start dose (\(titration.startDose)), but step amount is \(titration.stepAmount).",
                        suggestedFix: "Set a negative step amount to taper dose downward over time."
                    )
                )
            }
        }

        // Reminders Check
        if item.reminderEnabled && item.reminderTime == nil {
            issues.append(
                .info(
                    category: .missingRequiredField,
                    field: "reminderTime",
                    title: "Reminder Enabled Without Explicit Time",
                    explanation: "Smart reminders are enabled, but no specific reminder time was specified.",
                    suggestedFix: "Set a preferred reminder time (e.g. 8:00 AM)."
                )
            )
        }

        return ValidationResult(issues: issues)
    }

    // MARK: - 3. Inventory Vials & Supplies Validation

    public func validateVial(
        vial: Vial,
        associatedCompound: Compound? = nil,
        referenceDate: Date = Date()
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        // Total Dry Mass
        if !vial.totalDryMassMg.isFinite || vial.totalDryMassMg.isNaN {
            issues.append(
                .blockingError(
                    category: .dataIntegrity,
                    field: "totalDryMassMg",
                    title: "Invalid Dry Mass",
                    explanation: "Total dry mass must be a valid numerical value.",
                    suggestedFix: "Enter a positive number (e.g., 5.0 mg)."
                )
            )
        } else if vial.totalDryMassMg <= 0 {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "totalDryMassMg",
                    title: "Non-Positive Dry Mass",
                    explanation: "Vial initial dry mass must be strictly greater than zero.",
                    suggestedFix: "Enter the quantity of compound contained in the vial (e.g. 5 mg, 10 mg)."
                )
            )
        }

        // Reconstituted Vial State Checks
        if vial.isReconstituted {
            if let bacWater = vial.bacWaterAddedMl {
                if bacWater <= 0 {
                    issues.append(
                        .blockingError(
                            category: .missingRequiredField,
                            field: "bacWaterAddedMl",
                            title: "Non-Positive Diluent Volume",
                            explanation: "Reconstituted vial must have diluent volume strictly greater than 0 mL.",
                            suggestedFix: "Specify the volume of diluent added (e.g., 2.0 mL)."
                        )
                    )
                }

                if let currentVol = vial.currentVolumeRemainingMl {
                    if currentVol > (bacWater + 0.001) {
                        issues.append(
                            .blockingError(
                                category: .inventoryDiscrepancy,
                                field: "currentVolumeRemainingMl",
                                title: "Remaining Volume Exceeds Diluent Added",
                                explanation: "Recorded remaining volume (\(currentVol) mL) exceeds the initial diluent added (\(bacWater) mL).",
                                suggestedFix: "Correct remaining volume or log an audited reconstitution adjustment."
                            )
                        )
                    }
                    if currentVol < 0 {
                        issues.append(
                            .blockingError(
                                category: .inventoryDiscrepancy,
                                field: "currentVolumeRemainingMl",
                                title: "Negative Remaining Volume",
                                explanation: "Remaining volume in vial cannot be negative (\(currentVol) mL).",
                                suggestedFix: "Set remaining volume to 0 mL or reconcile stock."
                            )
                        )
                    }
                }
            } else {
                issues.append(
                    .blockingError(
                        category: .missingRequiredField,
                        field: "bacWaterAddedMl",
                        title: "Missing Diluent Volume for Reconstituted Vial",
                        explanation: "Reconstituted vials must record the volume of diluent added.",
                        suggestedFix: "Enter the diluent volume (in mL)."
                    )
                )
            }
        }

        // Dates Consistency
        if let purchase = vial.purchaseDate, let received = vial.receivedDate {
            if purchase > received {
                issues.append(
                    .warning(
                        category: .expiredRecord,
                        field: "receivedDate",
                        title: "Received Date Prior to Purchase Date",
                        explanation: "The received date (\(received.formatted(date: .abbreviated, time: .omitted))) is earlier than the purchase date (\(purchase.formatted(date: .abbreviated, time: .omitted))).",
                        suggestedFix: "Verify the recorded calendar dates."
                    )
                )
            }
        }

        if let received = vial.receivedDate, let exp = vial.expirationDate {
            if received > exp {
                issues.append(
                    .warning(
                        category: .expiredRecord,
                        field: "expirationDate",
                        title: "Vial Expired Before Received Date",
                        explanation: "The expiration date is earlier than the date the vial was received in inventory.",
                        suggestedFix: "Check the manufacturer expiration date label."
                    )
                )
            }
        }

        if let exp = vial.expirationDate, referenceDate > exp {
            issues.append(
                .warning(
                    category: .expiredRecord,
                    field: "expirationDate",
                    title: "Vial Expiration Date Has Passed",
                    explanation: "This vial reached its manufacturer expiration date on \(exp.formatted(date: .abbreviated, time: .omitted)).",
                    suggestedFix: "Consider replacing with a fresh unexpired vial."
                )
            )
        }

        // Purity Range Check
        if let purity = vial.purityPercentage {
            if purity < 0.0 || purity > 100.0 {
                issues.append(
                    .blockingError(
                        category: .dataIntegrity,
                        field: "purityPercentage",
                        title: "Purity Percentage Out of Bounds",
                        explanation: "Purity percentage must be between 0.0% and 100.0%.",
                        suggestedFix: "Enter a percentage from 0 to 100 (e.g. 99.2)."
                    )
                )
            }
        }

        // Cost Non-Negative
        if let cost = vial.costUsd, cost < 0 {
            issues.append(
                .blockingError(
                    category: .dataIntegrity,
                    field: "costUsd",
                    title: "Negative Vial Cost",
                    explanation: "Financial cost cannot be a negative amount.",
                    suggestedFix: "Enter a positive cost or 0."
                )
            )
        }

        // Informational Completeness
        if vial.lotNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                .info(
                    category: .missingRequiredField,
                    field: "lotNumber",
                    title: "Lot Number Not Recorded",
                    explanation: "Recording manufacturer lot numbers facilitates supply batch tracking and quality verification.",
                    suggestedFix: "Enter the lot number printed on the vial label."
                )
            )
        }

        return ValidationResult(issues: issues)
    }

    public func validateSupplyItem(
        item: SupplyItem
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "name",
                    title: "Missing Supply Item Name",
                    explanation: "Supply items must have a recognizable name (e.g., 'Insulin Syringes 31G 1.0mL').",
                    suggestedFix: "Provide a name for the supply item."
                )
            )
        }

        if item.quantityRemaining < 0 {
            issues.append(
                .blockingError(
                    category: .inventoryDiscrepancy,
                    field: "quantityRemaining",
                    title: "Negative Stock Quantity",
                    explanation: "Supply quantity cannot be negative (\(item.quantityRemaining)).",
                    suggestedFix: "Set quantity to 0 or update current inventory count."
                )
            )
        }

        if item.reorderThreshold < 0 {
            issues.append(
                .blockingError(
                    category: .dataIntegrity,
                    field: "reorderThreshold",
                    title: "Negative Reorder Threshold",
                    explanation: "Reorder threshold cannot be negative.",
                    suggestedFix: "Set reorder threshold to 0 or higher."
                )
            )
        }

        if item.isLowStock {
            issues.append(
                .info(
                    category: .inventoryDiscrepancy,
                    field: "quantityRemaining",
                    title: "Low Supply Stock Notice",
                    explanation: "\(item.name) stock level (\(item.quantityRemaining) \(item.packageUnit)) is at or below the reorder threshold of \(item.reorderThreshold).",
                    suggestedFix: "Consider re-ordering supplies."
                )
            )
        }

        return ValidationResult(issues: issues)
    }

    // MARK: - 4. Reconstitution & Solution Dynamics Validation

    public func validateReconstitution(
        dryMassMg: Double,
        diluentVolumeMl: Double,
        diluentType: DiluentType = .bacteriostaticWater,
        targetDoseAmount: Double,
        targetDoseUnit: DoseUnit,
        syringeSpecification: SyringeSpecification? = nil,
        compoundActivityRatio: CompoundActivityRatio? = nil,
        referenceDate: Date = Date()
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        // Dry Mass
        if !dryMassMg.isFinite || dryMassMg.isNaN || dryMassMg <= 0 {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "dryMassMg",
                    title: "Invalid Dry Mass",
                    explanation: "Dry compound mass must be a positive numerical value.",
                    suggestedFix: "Enter the mass in mg (e.g. 5.0 mg, 10.0 mg)."
                )
            )
        }

        // Diluent Volume
        if !diluentVolumeMl.isFinite || diluentVolumeMl.isNaN || diluentVolumeMl <= 0 {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "diluentVolumeMl",
                    title: "Invalid Diluent Volume",
                    explanation: "Diluent volume must be a positive numerical value.",
                    suggestedFix: "Enter the volume of diluent to add (e.g. 2.0 mL)."
                )
            )
        } else if diluentVolumeMl > 100.0 {
            issues.append(
                .blockingError(
                    category: .dataIntegrity,
                    field: "diluentVolumeMl",
                    title: "Unrealistic Diluent Volume",
                    explanation: "Diluent volume of \(diluentVolumeMl) mL exceeds standard vial physical capacity (<=100 mL).",
                    suggestedFix: "Enter a standard volume (typically 1.0 to 10.0 mL)."
                )
            )
        }

        // Target Dose
        if !targetDoseAmount.isFinite || targetDoseAmount.isNaN || targetDoseAmount <= 0 {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "targetDoseAmount",
                    title: "Invalid Target Dose Amount",
                    explanation: "Target dose amount must be strictly greater than zero.",
                    suggestedFix: "Specify a positive target dose."
                )
            )
        }

        // Biological Activity Ratio Requirement
        if targetDoseUnit == .iu && (compoundActivityRatio == nil || (compoundActivityRatio?.iuPerMg ?? 0) <= 0) {
            issues.append(
                .blockingError(
                    category: .inconsistentUnits,
                    field: "targetDoseUnit",
                    title: "Missing Biological Activity Conversion Ratio",
                    explanation: "Target dose is specified in International Units (IU), but no biological activity ratio (IU per mg) is provided.",
                    suggestedFix: "Provide a compound activity conversion ratio (e.g. 1 mg = 3.0 IU for Somatropin GH)."
                )
            )
        }

        // Concentration Sanity Checks
        if dryMassMg > 0 && diluentVolumeMl > 0 {
            let concentration = dryMassMg / diluentVolumeMl

            if concentration > 500.0 {
                issues.append(
                    .warning(
                        category: .dataIntegrity,
                        field: "diluentVolumeMl",
                        title: "Extremely High Resulting Concentration",
                        explanation: "Resulting concentration would be \(String(format: "%.1f", concentration)) mg/mL (\(String(format: "%.0f", concentration * 1000.0)) mcg/mL), which is unusually concentrated for standard peptide solutions.",
                        suggestedFix: "Verify that diluent volume was not entered in microliters instead of milliliters."
                    )
                )
            } else if concentration < 0.01 {
                issues.append(
                    .warning(
                        category: .dataIntegrity,
                        field: "dryMassMg",
                        title: "Extremely Dilute Resulting Concentration",
                        explanation: "Resulting concentration would be \(String(format: "%.4f", concentration)) mg/mL (\(String(format: "%.1f", concentration * 1000.0)) mcg/mL).",
                        suggestedFix: "Confirm that dry mass was not entered in micrograms instead of milligrams."
                    )
                )
            }

            // Syringe Capacity Checks
            if let syringe = syringeSpecification, targetDoseAmount > 0 {
                let doseMg: Double
                switch targetDoseUnit {
                case .mg: doseMg = targetDoseAmount
                case .mcg: doseMg = targetDoseAmount / 1000.0
                case .ml: doseMg = targetDoseAmount * concentration
                case .iu: doseMg = targetDoseAmount / (compoundActivityRatio?.iuPerMg ?? 3.0)
                }

                let drawMl = doseMg / concentration
                if drawMl > syringe.barrelCapacityMl {
                    issues.append(
                        .warning(
                            category: .anatomicalRouteMismatch,
                            field: "syringeSpecification",
                            title: "Required Draw Exceeds Syringe Barrel Capacity",
                            explanation: "Target dose requires drawing \(String(format: "%.2f", drawMl)) mL, which exceeds the selected syringe capacity of \(syringe.barrelCapacityMl) mL.",
                            suggestedFix: "Select a larger capacity syringe or use less diluent to increase concentration."
                        )
                    )
                } else if drawMl < 0.01 && syringe.type == .u100 {
                    issues.append(
                        .info(
                            category: .anatomicalRouteMismatch,
                            field: "syringeSpecification",
                            title: "Very Small Draw Volume (<1 Unit)",
                            explanation: "Target draw is \(String(format: "%.3f", drawMl)) mL (less than 1 unit on a U-100 syringe), which may be difficult to measure with precision.",
                            suggestedFix: "Consider using more diluent to increase draw volume for easier measuring."
                        )
                    )
                }
            }
        }

        return ValidationResult(issues: issues)
    }

    public func validateReconstitutionRecord(
        record: ReconstitutionRecord,
        referenceDate: Date = Date()
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        let reconResult = validateReconstitution(
            dryMassMg: record.dryMassMg,
            diluentVolumeMl: record.diluentVolumeMl,
            diluentType: record.diluentType,
            targetDoseAmount: 100.0, // Default reference probe
            targetDoseUnit: .mcg,
            referenceDate: referenceDate
        )
        issues.append(contentsOf: reconResult.issues)

        // Solution Clarity Check
        if record.solutionClarity == .particulateVisible || record.solutionClarity == .discolored {
            issues.append(
                .warning(
                    category: .inventoryDiscrepancy,
                    field: "solutionClarity",
                    title: "Visual Clarity Anomaly",
                    explanation: "Solution clarity is recorded as '\(record.solutionClarity.rawValue)'. Reconstituted solutions containing precipitate or discoloration should generally not be administered.",
                    suggestedFix: "Inspect vial under clean light and consult guidance on safe disposal."
                )
            )
        }

        // Expiration & Freshness
        if let exp = record.expirationDate, referenceDate > exp {
            issues.append(
                .warning(
                    category: .expiredRecord,
                    field: "expirationDate",
                    title: "Solution Past Calculated Shelf Life",
                    explanation: "This reconstitution record surpassed its expected \(record.expectedShelfLifeDays)-day shelf life on \(exp.formatted(date: .abbreviated, time: .omitted)).",
                    suggestedFix: "Reconstitute a new vial for optimal potency."
                )
            )
        }

        return ValidationResult(issues: issues)
    }

    public func validateReconstitutionInput(_ input: ReconstitutionInput) -> ValidationResult {
        let dryMg = input.dryMass.mg
        let volMl = input.diluentVolume.ml
        let doseUnit: DoseUnit
        let doseAmount: Double

        switch input.targetDose {
        case .mass(let m):
            doseAmount = m.value
            doseUnit = (m.unit == .mg) ? .mg : .mcg
        case .volume(let v):
            doseAmount = v.ml
            doseUnit = .ml
        case .biologicalActivity(let iu):
            doseAmount = iu
            doseUnit = .iu
        case .syringeUnits(let units, _):
            doseAmount = units
            doseUnit = .ml
        }

        return validateReconstitution(
            dryMassMg: dryMg,
            diluentVolumeMl: volMl,
            targetDoseAmount: doseAmount,
            targetDoseUnit: doseUnit,
            syringeSpecification: input.syringeSpecification,
            compoundActivityRatio: input.compoundActivity
        )
    }

    // MARK: - 5. Measurements, Vitals & Biomarkers Validation

    public func validateMeasurement(
        measurement: Measurement,
        recentMeasurements: [Measurement] = [],
        referenceDate: Date = Date()
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        // Finite Check
        if !measurement.value.isFinite || measurement.value.isNaN {
            issues.append(
                .blockingError(
                    category: .dataIntegrity,
                    field: "value",
                    title: "Invalid Numeric Value",
                    explanation: "Measurement value must be a valid, finite number.",
                    suggestedFix: "Enter a valid numeric value."
                )
            )
            return ValidationResult(issues: issues)
        }

        if let secondary = measurement.secondaryValue, (!secondary.isFinite || secondary.isNaN) {
            issues.append(
                .blockingError(
                    category: .dataIntegrity,
                    field: "secondaryValue",
                    title: "Invalid Secondary Value",
                    explanation: "Secondary measurement value must be a valid, finite number.",
                    suggestedFix: "Enter a valid numeric secondary value."
                )
            )
        }

        // Future Timestamp Check
        if measurement.dateRecorded > referenceDate.addingTimeInterval(300) { // 5 min clock drift tolerance
            issues.append(
                .warning(
                    category: .expiredRecord,
                    field: "dateRecorded",
                    title: "Future Timestamp Recorded",
                    explanation: "The measurement timestamp (\(measurement.dateRecorded.formatted(date: .abbreviated, time: .shortened))) is set in the future.",
                    suggestedFix: "Set the timestamp to the current or historical recording time."
                )
            )
        }

        // Physiological Range Anomaly Rules by Measurement Type
        let val = measurement.value

        switch measurement.type {
        case .weight:
            if val <= 0 {
                issues.append(
                    .blockingError(
                        category: .physiologicalRange,
                        field: "value",
                        title: "Non-Positive Body Weight",
                        explanation: "Body weight must be strictly greater than zero.",
                        suggestedFix: "Enter a positive body weight."
                    )
                )
            } else if val < 15.0 || val > 1000.0 {
                issues.append(
                    .warning(
                        category: .physiologicalRange,
                        field: "value",
                        title: "Weight Out of Standard Range",
                        explanation: "The recorded weight of \(val) \(measurement.unit) falls outside standard physiological recording bounds (15–1000).",
                        suggestedFix: "Verify that the unit (lbs vs kg) and decimal place are correct."
                    )
                )
            }

        case .bloodPressure:
            let systolic = val
            let diastolic = measurement.secondaryValue

            if systolic < 40.0 || systolic > 300.0 {
                issues.append(
                    .warning(
                        category: .physiologicalRange,
                        field: "value",
                        title: "Systolic Blood Pressure Out of Standard Range",
                        explanation: "Systolic blood pressure of \(Int(systolic)) mmHg falls outside standard physiological bounds (40–300 mmHg).",
                        suggestedFix: "Confirm blood pressure monitor reading."
                    )
                )
            }

            if let dia = diastolic {
                if dia < 20.0 || dia > 200.0 {
                    issues.append(
                        .warning(
                            category: .physiologicalRange,
                            field: "secondaryValue",
                            title: "Diastolic Blood Pressure Out of Standard Range",
                            explanation: "Diastolic blood pressure of \(Int(dia)) mmHg falls outside standard bounds (20–200 mmHg).",
                            suggestedFix: "Confirm reading on blood pressure monitor."
                        )
                    )
                }

                if dia >= systolic {
                    issues.append(
                        .blockingError(
                            category: .physiologicalRange,
                            field: "secondaryValue",
                            title: "Diastolic Exceeds Systolic Pressure",
                            explanation: "Systolic pressure (\(Int(systolic)) mmHg) must be higher than diastolic pressure (\(Int(dia)) mmHg).",
                            suggestedFix: "Invert the values to format as Systolic / Diastolic (e.g. 120 / 80)."
                        )
                    )
                }
            } else {
                issues.append(
                    .info(
                        category: .missingRequiredField,
                        field: "secondaryValue",
                        title: "Missing Diastolic Value",
                        explanation: "Blood pressure is standardly recorded as both systolic and diastolic values.",
                        suggestedFix: "Enter diastolic pressure (e.g. 80 mmHg)."
                    )
                )
            }

        case .bloodGlucose:
            if val <= 0 {
                issues.append(
                    .blockingError(
                        category: .physiologicalRange,
                        field: "value",
                        title: "Non-Positive Blood Glucose",
                        explanation: "Blood glucose must be greater than zero.",
                        suggestedFix: "Enter a positive glucose reading."
                    )
                )
            } else if val < 20.0 || val > 1000.0 {
                issues.append(
                    .warning(
                        category: .physiologicalRange,
                        field: "value",
                        title: "Blood Glucose Value Extreme",
                        explanation: "Blood glucose reading of \(val) mg/dL is outside standard operational ranges (20–1000 mg/dL).",
                        suggestedFix: "Re-test with glucometer or verify entered units (mg/dL vs mmol/L)."
                    )
                )
            }

        case .restingHeartRate:
            if val < 20.0 || val > 260.0 {
                issues.append(
                    .warning(
                        category: .physiologicalRange,
                        field: "value",
                        title: "Heart Rate Value Unusual",
                        explanation: "Resting heart rate of \(Int(val)) bpm is outside standard bounds (20–260 bpm).",
                        suggestedFix: "Verify heart rate reading."
                    )
                )
            }

        case .hrv:
            if val < 0.0 || val > 400.0 {
                issues.append(
                    .warning(
                        category: .physiologicalRange,
                        field: "value",
                        title: "HRV Value Out of Range",
                        explanation: "HRV SDNN value of \(val) ms is outside standard limits (0–400 ms).",
                        suggestedFix: "Confirm HRV sensor reading."
                    )
                )
            }

        case .sleep:
            if val < 0 {
                issues.append(
                    .blockingError(
                        category: .physiologicalRange,
                        field: "value",
                        title: "Negative Sleep Duration",
                        explanation: "Sleep duration cannot be negative.",
                        suggestedFix: "Enter a positive number of hours."
                    )
                )
            } else if val > 24.0 {
                issues.append(
                    .blockingError(
                        category: .physiologicalRange,
                        field: "value",
                        title: "Sleep Duration Exceeds 24 Hours",
                        explanation: "Sleep duration of \(val) hours exceeds the total hours available in a single calendar day.",
                        suggestedFix: "Enter a duration between 0.0 and 24.0 hours."
                    )
                )
            }

        case .bodyFat:
            if val < 0.0 || val > 100.0 {
                issues.append(
                    .blockingError(
                        category: .physiologicalRange,
                        field: "value",
                        title: "Body Fat Percentage Out of Range",
                        explanation: "Body fat percentage must be between 0.0% and 100.0%.",
                        suggestedFix: "Enter a valid percentage."
                    )
                )
            }

        case .oxygenSaturation:
            if val < 0.0 || val > 100.0 {
                issues.append(
                    .blockingError(
                        category: .physiologicalRange,
                        field: "value",
                        title: "SpO2 Percentage Out of Range",
                        explanation: "Oxygen saturation must be between 0% and 100%.",
                        suggestedFix: "Enter a reading from 0 to 100."
                    )
                )
            } else if val < 60.0 {
                issues.append(
                    .warning(
                        category: .physiologicalRange,
                        field: "value",
                        title: "Unusually Low Oxygen Saturation",
                        explanation: "SpO2 reading of \(val)% is unusually low.",
                        suggestedFix: "Confirm sensor placement on finger."
                    )
                )
            }

        case .energy, .appetite, .pain, .mood:
            if val < 0.0 || val > 10.0 {
                issues.append(
                    .blockingError(
                        category: .physiologicalRange,
                        field: "value",
                        title: "Subjective Score Out of Range",
                        explanation: "Subjective ratings must be scored on a 0 to 10 scale (entered: \(val)).",
                        suggestedFix: "Enter a score between 0 and 10."
                    )
                )
            }

        default:
            break
        }

        // Duplicate Measurement Entry Check
        let sameTypeRecent = recentMeasurements.filter {
            $0.type == measurement.type &&
            $0.id != measurement.id &&
            abs($0.dateRecorded.timeIntervalSince(measurement.dateRecorded)) < 60.0
        }

        if let duplicate = sameTypeRecent.first {
            if abs(duplicate.value - measurement.value) < 0.001 {
                issues.append(
                    .info(
                        category: .unexpectedDuplicate,
                        field: "dateRecorded",
                        title: "Duplicate Measurement Logged",
                        explanation: "An identical \(measurement.type.rawValue) reading was already recorded at this timestamp.",
                        suggestedFix: "Avoid logging duplicate entries for the same metric time."
                    )
                )
            } else {
                issues.append(
                    .warning(
                        category: .unexpectedDuplicate,
                        field: "value",
                        title: "Conflicting Concurrent Measurements",
                        explanation: "Two different \(measurement.type.rawValue) values (\(duplicate.value) vs \(measurement.value)) were logged within 1 minute of each other.",
                        suggestedFix: "Keep the most accurate reading and remove the duplicate."
                    )
                )
            }
        }

        return ValidationResult(issues: issues)
    }

    // MARK: - 6. Lab Panels & Bloodwork Validation

    public func validateLabPanel(
        panel: LabPanel,
        referenceDate: Date = Date()
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        if panel.panelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "panelName",
                    title: "Missing Lab Panel Name",
                    explanation: "Every lab panel must have a title or descriptive name (e.g. 'Comprehensive Metabolic Panel').",
                    suggestedFix: "Enter a panel name."
                )
            )
        }

        if panel.results.isEmpty {
            issues.append(
                .warning(
                    category: .missingRequiredField,
                    field: "results",
                    title: "Empty Lab Results List",
                    explanation: "This diagnostic panel has no biomarker analytes or results attached.",
                    suggestedFix: "Add at least one biomarker result to the panel."
                )
            )
        }

        if let resDate = panel.resultDate, resDate < panel.collectionDate {
            issues.append(
                .blockingError(
                    category: .expiredRecord,
                    field: "resultDate",
                    title: "Inverted Diagnostic Dates",
                    explanation: "The lab report result date (\(resDate.formatted(date: .abbreviated, time: .omitted))) cannot be earlier than specimen collection date (\(panel.collectionDate.formatted(date: .abbreviated, time: .omitted))).",
                    suggestedFix: "Ensure result date is equal to or later than the collection date."
                )
            )
        }

        if panel.collectionDate > referenceDate.addingTimeInterval(86400) {
            issues.append(
                .warning(
                    category: .expiredRecord,
                    field: "collectionDate",
                    title: "Future Specimen Collection Date",
                    explanation: "Specimen collection date is recorded more than 24 hours in the future.",
                    suggestedFix: "Confirm blood draw date."
                )
            )
        }

        // Validate Individual Results
        for (index, result) in panel.results.enumerated() {
            let resResult = validateLabResult(result: result, panelCollectionDate: panel.collectionDate)
            for issue in resResult.issues {
                issues.append(
                    ValidationIssue(
                        id: issue.id,
                        severity: issue.severity,
                        category: issue.category,
                        field: "results[\(index)].\(issue.field ?? "field")",
                        title: "\(result.biomarkerName): \(issue.title)",
                        explanation: issue.explanation,
                        suggestedFix: issue.suggestedFix,
                        contextData: issue.contextData
                    )
                )
            }
        }

        return ValidationResult(issues: issues)
    }

    public func validateLabResult(
        result: LabResult,
        panelCollectionDate: Date? = nil
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        if result.biomarkerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "biomarkerName",
                    title: "Missing Biomarker Name",
                    explanation: "Biomarker result must include an analyte name (e.g. 'IGF-1', 'Free Testosterone').",
                    suggestedFix: "Provide a biomarker name."
                )
            )
        }

        if !result.value.isFinite || result.value.isNaN {
            issues.append(
                .blockingError(
                    category: .dataIntegrity,
                    field: "value",
                    title: "Invalid Biomarker Numerical Value",
                    explanation: "Biomarker numeric value must be a valid finite number.",
                    suggestedFix: "Enter a numeric result value."
                )
            )
        }

        if let min = result.referenceRangeMin, let max = result.referenceRangeMax {
            if min > max {
                issues.append(
                    .blockingError(
                        category: .dataIntegrity,
                        field: "referenceRangeMax",
                        title: "Inverted Reference Range",
                        explanation: "Biomarker reference range minimum (\(min)) cannot be greater than reference maximum (\(max)).",
                        suggestedFix: "Set reference minimum to be less than or equal to maximum."
                    )
                )
            }
        }

        return ValidationResult(issues: issues)
    }

    // MARK: - 7. Inventory Events & Ledger Validation

    public func validateInventoryEvent(
        event: InventoryEvent,
        vialState: VialAccountingState? = nil
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        if event.eventType == .doseConsumption {
            if let vol = event.changeVolumeMl, vol > 0.0001 {
                issues.append(
                    .warning(
                        category: .inventoryDiscrepancy,
                        field: "changeVolumeMl",
                        title: "Positive Volume Change for Dose Consumption",
                        explanation: "Dose consumption events should record negative volume changes to deduct from stock.",
                        suggestedFix: "Ensure changeVolumeMl is negative for consumption."
                    )
                )
            }
        }

        if let newVol = event.resultingVolumeRemainingMl, newVol < 0 {
            issues.append(
                .blockingError(
                    category: .inventoryDiscrepancy,
                    field: "resultingVolumeRemainingMl",
                    title: "Negative Resulting Volume",
                    explanation: "An inventory event cannot leave a vial with negative volume (\(newVol) mL).",
                    suggestedFix: "Reconcile volume to 0 mL."
                )
            )
        }

        if let newMass = event.resultingMassRemainingMg, newMass < 0 {
            issues.append(
                .blockingError(
                    category: .inventoryDiscrepancy,
                    field: "resultingMassRemainingMg",
                    title: "Negative Resulting Mass",
                    explanation: "An inventory event cannot leave a vial with negative mass (\(newMass) mg).",
                    suggestedFix: "Reconcile remaining mass to 0 mg."
                )
            )
        }

        return ValidationResult(issues: issues)
    }

    // MARK: - 8. Symptom Logs & Outcomes Validation

    public func validateSymptomLog(
        log: SymptomLog,
        referenceDate: Date = Date()
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        if log.symptomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "symptomName",
                    title: "Missing Symptom Name",
                    explanation: "Symptom logs must identify the symptom or side effect observed.",
                    suggestedFix: "Specify the symptom (e.g., 'Headache', 'Injection Site Redness')."
                )
            )
        }

        if log.severityScore < 1 || log.severityScore > 10 {
            issues.append(
                .blockingError(
                    category: .physiologicalRange,
                    field: "severityScore",
                    title: "Symptom Severity Score Out of Range",
                    explanation: "Severity score must be an integer between 1 (Mild) and 10 (Severe).",
                    suggestedFix: "Set severity score between 1 and 10."
                )
            )
        }

        if log.timestamp > referenceDate.addingTimeInterval(300) {
            issues.append(
                .warning(
                    category: .expiredRecord,
                    field: "timestamp",
                    title: "Future Symptom Timestamp",
                    explanation: "The symptom log timestamp is set in the future.",
                    suggestedFix: "Set timestamp to current or past occurrence time."
                )
            )
        }

        return ValidationResult(issues: issues)
    }

    // MARK: - 9. Injection Site Rotation Validation

    public func validateInjectionSiteEvent(
        event: InjectionSiteEvent,
        recentSiteEvents: [InjectionSiteEvent] = []
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        if event.siteId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "siteId",
                    title: "Missing Injection Site Identifier",
                    explanation: "Injection site event requires an anatomical location identifier.",
                    suggestedFix: "Select an injection site quadrant."
                )
            )
        }

        if event.doseAmount <= 0 {
            issues.append(
                .blockingError(
                    category: .missingRequiredField,
                    field: "doseAmount",
                    title: "Non-Positive Dose Amount at Site",
                    explanation: "Dose amount administered at site must be greater than zero.",
                    suggestedFix: "Specify positive dose amount."
                )
            )
        }

        if let pain = event.painScore, (pain < 0 || pain > 10) {
            issues.append(
                .blockingError(
                    category: .physiologicalRange,
                    field: "painScore",
                    title: "Pain Score Out of Range",
                    explanation: "Injection pain score must be on a 0 to 10 scale.",
                    suggestedFix: "Enter a pain score between 0 and 10."
                )
            )
        }

        // Check for 2+ consecutive uses of the exact same quadrant
        let sortedHistory = recentSiteEvents.sorted(by: { $0.timestamp > $1.timestamp })
        let consecutiveUses = sortedHistory.prefix(while: { $0.siteId == event.siteId }).count
        if consecutiveUses >= 2 {
            issues.append(
                .warning(
                    category: .anatomicalRouteMismatch,
                    field: "siteId",
                    title: "Anatomical Site Overuse Notice",
                    explanation: "The site '\(event.siteName)' has been used for the last \(consecutiveUses) consecutive administrations.",
                    suggestedFix: "Rotate to an alternate body quadrant to rest tissue and maintain skin health."
                )
            )
        }

        return ValidationResult(issues: issues)
    }
}
