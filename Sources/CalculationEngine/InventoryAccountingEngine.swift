import Foundation
import Domain

/// Pure functional deterministic engine executing event-sourced inventory calculations,
/// audit trail evaluations, double-entry volume/mass reconciliation, and point-in-time state replays.
public struct InventoryAccountingEngine: Sendable {

    public init() {}

    // MARK: - 1. Deterministic Vial State Calculation (Ledger Reducer)
    
    /// Reduces the chronological event history of a vial into its current or historical physical & chemical state.
    /// - Parameters:
    ///   - vial: The base vial domain entity.
    ///   - events: All historical inventory events for this vial.
    ///   - targetDate: Optional timestamp ceiling for historical point-in-time replay.
    /// - Returns: The derived, exact `VialAccountingState`.
    public func calculateVialState(
        vial: Vial,
        events: [InventoryEvent],
        upTo targetDate: Date? = nil
    ) -> VialAccountingState {
        // Filter by target vial and ceiling timestamp, sorted chronologically
        let filteredEvents = events
            .filter { $0.vialId == vial.id }
            .filter { event in
                if let ceiling = targetDate {
                    return event.timestamp <= ceiling
                }
                return true
            }
            .sorted(by: { $0.timestamp < $1.timestamp })

        var initialMassMg = vial.totalDryMassMg
        var totalDiluentMl = vial.bacWaterAddedMl ?? 0.0
        var isRecon = vial.isReconstituted
        var concMgMl = vial.concentrationMgMl
        var concMcgMl = vial.concentrationMcgMl
        var doseVolumeConsumedMl: Double = 0.0
        var doseMassConsumedMg: Double = 0.0
        var dosesAdministeredCount: Int = 0
        var reconVolumeAdjustmentMl: Double = 0.0
        var reconMassAdjustmentMg: Double = 0.0
        var reconciliationCount: Int = 0
        
        var currentVolMl: Double = vial.currentVolumeRemainingMl ?? (isRecon ? totalDiluentMl : 0.0)
        var currentMassMg: Double = initialMassMg
        var status: VialStatus = vial.status
        
        var initialDate = vial.purchaseDate ?? vial.createdAt
        var reconDate = vial.reconstitutedDate
        var expDate = vial.expirationDate
        var depDate = vial.depletedDate
        var discDate = vial.discardDate
        var lastTimestamp = vial.createdAt

        // If no events exist, seed defaults from base Vial object
        if filteredEvents.isEmpty {
            if isRecon, let vol = vial.currentVolumeRemainingMl, let conc = concMgMl {
                currentMassMg = vol * conc
            }
        } else {
            // Reset to initial baseline and reduce through event stream
            currentVolMl = 0.0
            currentMassMg = 0.0
            isRecon = false
            concMgMl = nil
            concMcgMl = nil
            status = .unopened

            for event in filteredEvents {
                lastTimestamp = event.timestamp

                switch event.eventType {
                case .initialStock:
                    let mass = event.changeMassMg ?? initialMassMg
                    initialMassMg = mass
                    currentMassMg = mass
                    currentVolMl = 0.0
                    status = .unopened
                    initialDate = event.timestamp

                case .reconstitution:
                    let diluent = event.changeVolumeMl ?? (event.resultingVolumeRemainingMl ?? totalDiluentMl)
                    totalDiluentMl = max(0.0, diluent)
                    isRecon = true
                    currentVolMl = diluent
                    
                    // Mass stays equal to dry powder unless explicitly amended
                    if let resMass = event.resultingMassRemainingMg {
                        currentMassMg = resMass
                    } else if currentMassMg <= 0.0001 {
                        currentMassMg = initialMassMg
                    }
                    
                    let computedConc = totalDiluentMl > 0 ? (currentMassMg / totalDiluentMl) : 0.0
                    concMgMl = event.resultingConcentrationMgMl ?? computedConc
                    concMcgMl = (concMgMl ?? 0.0) * 1000.0
                    reconDate = event.timestamp
                    expDate = Calendar.current.date(byAdding: .day, value: 28, to: event.timestamp)
                    status = .reconstituted

                case .doseConsumption:
                    let consumedVol = abs(event.changeVolumeMl ?? 0.0)
                    let consumedMass = abs(event.changeMassMg ?? 0.0)
                    
                    doseVolumeConsumedMl += consumedVol
                    doseMassConsumedMg += consumedMass
                    dosesAdministeredCount += 1
                    
                    currentVolMl = max(0.0, currentVolMl - consumedVol)
                    currentMassMg = max(0.0, currentMassMg - consumedMass)
                    
                    if currentVolMl <= 0.0001 {
                        status = .depleted
                        depDate = event.timestamp
                    } else {
                        status = .reconstituted
                    }

                case .reconciliation:
                    let deltaVol = event.changeVolumeMl ?? 0.0
                    let deltaMass = event.changeMassMg ?? 0.0
                    
                    reconVolumeAdjustmentMl += deltaVol
                    reconMassAdjustmentMg += deltaMass
                    reconciliationCount += 1
                    
                    currentVolMl = max(0.0, currentVolMl + deltaVol)
                    currentMassMg = max(0.0, currentMassMg + deltaMass)
                    
                    if let resConc = event.resultingConcentrationMgMl {
                        concMgMl = resConc
                        concMcgMl = resConc * 1000.0
                    }
                    
                    if currentVolMl <= 0.0001 {
                        status = .depleted
                        depDate = event.timestamp
                    } else if isRecon {
                        status = .reconstituted
                    }

                case .disposal:
                    status = (event.disposalReason == .depleted) ? .depleted : .discarded
                    discDate = event.timestamp
                    currentVolMl = 0.0
                    currentMassMg = 0.0

                case .quarantine:
                    status = .damaged

                case .restock, .transfer, .other:
                    if let newVol = event.resultingVolumeRemainingMl { currentVolMl = newVol }
                    if let newMass = event.resultingMassRemainingMg { currentMassMg = newMass }
                    if let newStatus = event.resultingStatus { status = newStatus }
                }
            }
        }

        // Compute fractions
        let remFraction: Double
        if isRecon && totalDiluentMl > 0 {
            remFraction = max(0.0, min(1.0, currentVolMl / totalDiluentMl))
        } else if initialMassMg > 0 {
            remFraction = max(0.0, min(1.0, currentMassMg / initialMassMg))
        } else {
            remFraction = status == .depleted || status == .discarded ? 0.0 : 1.0
        }

        return VialAccountingState(
            vialId: vial.id,
            compoundId: vial.compoundId,
            compoundName: vial.compoundName,
            lotNumber: vial.lotNumber,
            initialDryMassMg: initialMassMg,
            totalDiluentVolumeMl: totalDiluentMl,
            isReconstituted: isRecon,
            currentConcentrationMgMl: concMgMl,
            currentConcentrationMcgMl: concMcgMl,
            totalDoseVolumeConsumedMl: doseVolumeConsumedMl,
            totalDoseMassConsumedMg: doseMassConsumedMg,
            totalDosesAdministered: dosesAdministeredCount,
            totalReconciliationVolumeAdjustmentMl: reconVolumeAdjustmentMl,
            totalReconciliationMassAdjustmentMg: reconMassAdjustmentMg,
            reconciliationCount: reconciliationCount,
            currentVolumeRemainingMl: round(currentVolMl * 1000) / 1000.0,
            currentMassRemainingMg: round(currentMassMg * 1000) / 1000.0,
            remainingFraction: remFraction,
            remainingPercentage: remFraction * 100.0,
            status: status,
            initialStockDate: initialDate,
            reconstitutedDate: reconDate,
            expirationDate: expDate,
            depletedDate: depDate,
            discardDate: discDate,
            lastEventTimestamp: lastTimestamp,
            auditTrailCount: max(1, filteredEvents.count)
        )
    }

    // MARK: - 2. Point-in-Time History Replay
    
    /// Replays the historical state of a vial at an exact historical date.
    public func replayHistory(
        vial: Vial,
        events: [InventoryEvent],
        at historicalDate: Date
    ) -> VialAccountingState {
        calculateVialState(vial: vial, events: events, upTo: historicalDate)
    }

    // MARK: - 3. Event Factories with Resulting State Calculation
    
    /// Records initial receipt of a vial and generates initial stock accounting event.
    public func recordInitialStock(
        vial: Vial,
        initialDryMassMg: Double,
        costEventId: UUID? = nil,
        timestamp: Date = Date(),
        notes: String = ""
    ) -> (event: InventoryEvent, state: VialAccountingState) {
        let event = InventoryEvent.initialStock(
            vialId: vial.id,
            compoundId: vial.compoundId,
            compoundName: vial.compoundName,
            initialDryMassMg: initialDryMassMg,
            lotNumber: vial.lotNumber,
            costEventId: costEventId,
            timestamp: timestamp,
            notes: notes
        )
        let state = calculateVialState(vial: vial, events: [event])
        return (event, state)
    }

    /// Records chemical reconstitution, altering the concentration state and liquid volume.
    public func recordReconstitution(
        vial: Vial,
        existingEvents: [InventoryEvent],
        diluentVolumeMl: Double,
        dryMassMg: Double? = nil,
        diluentType: DiluentType = .bacteriostaticWater,
        reconstitutionRecordId: UUID? = nil,
        timestamp: Date = Date(),
        notes: String = ""
    ) -> (event: InventoryEvent, state: VialAccountingState) {
        let currentDerivedState = calculateVialState(vial: vial, events: existingEvents)
        let mass = dryMassMg ?? (currentDerivedState.initialDryMassMg > 0 ? currentDerivedState.initialDryMassMg : vial.totalDryMassMg)
        
        let event = InventoryEvent.reconstitution(
            vialId: vial.id,
            compoundId: vial.compoundId,
            compoundName: vial.compoundName,
            diluentVolumeMl: diluentVolumeMl,
            dryMassMg: mass,
            reconstitutionRecordId: reconstitutionRecordId,
            lotNumber: vial.lotNumber,
            timestamp: timestamp,
            notes: notes.isEmpty ? "Reconstituted with \(diluentVolumeMl) mL \(diluentType.shortName)" : notes
        )
        
        var allEvents = existingEvents
        allEvents.append(event)
        let updatedState = calculateVialState(vial: vial, events: allEvents)
        return (event, updatedState)
    }

    /// Records a dose consumption draw, deducting volume and mass.
    public func recordDoseConsumption(
        vial: Vial,
        existingEvents: [InventoryEvent],
        doseEvent: DoseEvent,
        drawVolumeMl: Double? = nil,
        timestamp: Date = Date(),
        notes: String = ""
    ) -> (event: InventoryEvent, state: VialAccountingState) {
        let currentState = calculateVialState(vial: vial, events: existingEvents)
        
        // Determine dose mass in mg
        let doseMg = (doseEvent.doseUnit == .mg) ? doseEvent.actualDoseAmount : (doseEvent.actualDoseAmount / 1000.0)
        
        // Determine draw volume in mL
        let computedDrawMl: Double
        if let explicitDraw = drawVolumeMl {
            computedDrawMl = explicitDraw
        } else if let conc = currentState.currentConcentrationMgMl, conc > 0 {
            computedDrawMl = doseMg / conc
        } else if let conc = vial.concentrationMgMl, conc > 0 {
            computedDrawMl = doseMg / conc
        } else {
            computedDrawMl = 0.0
        }

        let newVol = max(0.0, currentState.currentVolumeRemainingMl - computedDrawMl)
        let newMass = max(0.0, currentState.currentMassRemainingMg - doseMg)
        let isDepleted = newVol <= 0.0001

        let event = InventoryEvent.doseConsumption(
            vialId: vial.id,
            compoundId: vial.compoundId,
            compoundName: vial.compoundName,
            doseEventId: doseEvent.id,
            consumedVolumeMl: computedDrawMl,
            consumedMassMg: doseMg,
            newVolumeRemainingMl: newVol,
            newMassRemainingMg: newMass,
            concentrationMgMl: currentState.currentConcentrationMgMl ?? vial.concentrationMgMl ?? 0.0,
            isDepleted: isDepleted,
            timestamp: timestamp,
            notes: notes
        )

        var allEvents = existingEvents
        allEvents.append(event)
        let updatedState = calculateVialState(vial: vial, events: allEvents)
        return (event, updatedState)
    }

    /// Performs an audited physical inventory reconciliation.
    /// Computes the discrepancy (variance) between the expected calculated amount and the observed physical amount.
    public func reconcileVial(
        vial: Vial,
        existingEvents: [InventoryEvent],
        observedVolumeRemainingMl: Double,
        reason: ReconciliationReason,
        notes: String = "",
        timestamp: Date = Date()
    ) -> (adjustmentEvent: InventoryEvent, state: VialAccountingState) {
        let currentState = calculateVialState(vial: vial, events: existingEvents)
        let expectedVol = currentState.currentVolumeRemainingMl
        let volumeVariance = observedVolumeRemainingMl - expectedVol
        
        // Calculate corresponding mass variance
        let massVariance: Double
        if let conc = currentState.currentConcentrationMgMl, conc > 0 {
            massVariance = volumeVariance * conc
        } else {
            massVariance = 0.0
        }
        
        let newMass = max(0.0, currentState.currentMassRemainingMg + massVariance)

        let event = InventoryEvent.reconciliation(
            vialId: vial.id,
            compoundId: vial.compoundId,
            compoundName: vial.compoundName,
            volumeVarianceMl: volumeVariance,
            massVarianceMg: massVariance,
            newVolumeRemainingMl: observedVolumeRemainingMl,
            newMassRemainingMg: newMass,
            concentrationMgMl: currentState.currentConcentrationMgMl,
            reason: reason,
            userNotes: notes,
            timestamp: timestamp
        )

        var allEvents = existingEvents
        allEvents.append(event)
        let updatedState = calculateVialState(vial: vial, events: allEvents)
        return (event, updatedState)
    }

    /// Records an audited vial disposal.
    public func recordDisposal(
        vial: Vial,
        existingEvents: [InventoryEvent],
        reason: DisposalReason,
        notes: String = "",
        timestamp: Date = Date()
    ) -> (disposalEvent: InventoryEvent, state: VialAccountingState) {
        let currentState = calculateVialState(vial: vial, events: existingEvents)

        let event = InventoryEvent.disposal(
            vialId: vial.id,
            compoundId: vial.compoundId,
            compoundName: vial.compoundName,
            remainingVolumeBeforeDisposalMl: currentState.currentVolumeRemainingMl,
            remainingMassBeforeDisposalMg: currentState.currentMassRemainingMg,
            reason: reason,
            userNotes: notes,
            timestamp: timestamp
        )

        var allEvents = existingEvents
        allEvents.append(event)
        let updatedState = calculateVialState(vial: vial, events: allEvents)
        return (event, updatedState)
    }

    // MARK: - 4. Ancillary Supplies Accounting
    
    /// Calculates the deterministic stock level and consumption history of an ancillary supply item.
    public func calculateSupplyState(
        item: SupplyItem,
        events: [InventoryEvent],
        upTo targetDate: Date? = nil
    ) -> SupplyAccountingState {
        let supplyEvents = events
            .filter { $0.supplyItemId == item.id }
            .filter { e in
                if let ceiling = targetDate { return e.timestamp <= ceiling }
                return true
            }
            .sorted(by: { $0.timestamp < $1.timestamp })

        var initialQty = item.quantityRemaining
        var consumedCount = 0
        var restockedCount = 0
        var adjustmentCount = 0
        var currentQty = item.quantityRemaining
        var lastTimestamp = item.updatedAt

        if !supplyEvents.isEmpty {
            currentQty = 0
            for e in supplyEvents {
                lastTimestamp = e.timestamp
                let delta = e.changeQuantityCount ?? 0
                if e.eventType == .initialStock {
                    initialQty = delta
                    currentQty = delta
                } else if delta < 0 {
                    consumedCount += abs(delta)
                    currentQty = max(0, currentQty + delta)
                } else if e.eventType == .restock {
                    restockedCount += delta
                    currentQty += delta
                } else if e.eventType == .reconciliation {
                    adjustmentCount += delta
                    currentQty = max(0, currentQty + delta)
                }
            }
        }

        return SupplyAccountingState(
            supplyItemId: item.id,
            name: item.name,
            category: item.category,
            initialQuantity: initialQty,
            totalConsumed: consumedCount,
            totalRestocked: restockedCount,
            totalReconciliationAdjustment: adjustmentCount,
            currentQuantityRemaining: currentQty,
            isLowStock: currentQty <= item.reorderThreshold,
            lastEventTimestamp: lastTimestamp,
            auditTrailCount: max(1, supplyEvents.count)
        )
    }

    /// Reconciles physical count for an ancillary supply item.
    public func reconcileSupply(
        item: SupplyItem,
        existingEvents: [InventoryEvent],
        observedQuantity: Int,
        reason: ReconciliationReason,
        notes: String = "",
        timestamp: Date = Date()
    ) -> (event: InventoryEvent, updatedQuantity: Int) {
        let currentState = calculateSupplyState(item: item, events: existingEvents)
        let variance = observedQuantity - currentState.currentQuantityRemaining

        let event = InventoryEvent(
            supplyItemId: item.id,
            eventType: .reconciliation,
            timestamp: timestamp,
            reason: "Supply reconciliation: \(reason.rawValue) (\(variance >= 0 ? "+\(variance)" : "\(variance)") units)",
            reconciliationReason: reason,
            changeQuantityCount: variance,
            notes: notes
        )

        return (event, observedQuantity)
    }
}
