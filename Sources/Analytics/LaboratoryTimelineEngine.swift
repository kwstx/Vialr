import Foundation
import Domain
import CalculationEngine

public typealias Measurement = Domain.Measurement

/// High-performance analytics engine for Event Alignment and Laboratory Timeline correlation.
///
/// Places every laboratory result, dose event, protocol transition, and biometric measurement
/// onto a single unified chronological time axis, computing protocol phase overlays and
/// longitudinal biomarker trajectories across phases (Baseline → Protocol A → Titration → Protocol B → Follow-up).
public struct LaboratoryTimelineEngine: Sendable {

    public init() {}

    // MARK: - 1. Full Laboratory Timeline Generation

    /// Generates a comprehensive `LaboratoryTimelineAnalysis` aligning all health events and lab time-series points.
    public func generateAnalysis(
        labPanels: [LabPanel] = [],
        biomarkers: [Biomarker] = [],
        protocols: [ProtocolModel] = [],
        protocolRevisions: [ProtocolRevision] = [],
        doseLogs: [DoseLog] = [],
        measurements: [Measurement] = [],
        selectedBiomarkerName: String? = nil,
        calendar: Calendar = .current
    ) -> LaboratoryTimelineAnalysis {
        // 1. Build Protocol Period Overlays
        let overlays = buildProtocolOverlays(
            protocols: protocols,
            revisions: protocolRevisions,
            doseLogs: doseLogs,
            labPanels: labPanels,
            measurements: measurements,
            calendar: calendar
        )

        // 2. Extract and align Biomarker Time Series points
        let biomarkerSeries = buildBiomarkerTimeSeries(
            labPanels: labPanels,
            biomarkers: biomarkers,
            overlays: overlays,
            doseLogs: doseLogs,
            calendar: calendar
        )

        // 3. Collect available biomarker names
        let availableNames = Array(biomarkerSeries.keys).sorted()

        // 4. Resolve active selected biomarker (default to most frequent or key biomarker)
        let resolvedBiomarkerName = resolveSelectedBiomarker(
            selected: selectedBiomarkerName,
            available: availableNames,
            seriesMap: biomarkerSeries
        )

        // 5. Build Unified Aligned Event Stream
        let alignedEvents = alignAllEvents(
            labPanels: labPanels,
            biomarkers: biomarkers,
            protocols: protocols,
            protocolRevisions: protocolRevisions,
            doseLogs: doseLogs,
            measurements: measurements,
            overlays: overlays,
            calendar: calendar
        )

        // 6. Build Phase Journey Milestones for the active biomarker
        let activePoints = resolvedBiomarkerName != nil ? (biomarkerSeries[resolvedBiomarkerName!] ?? []) : []
        let phaseMilestones = buildPhaseJourney(
            overlays: overlays,
            labPoints: activePoints,
            revisions: protocolRevisions,
            calendar: calendar
        )

        // 7. Calculate Pairwise Phase Deltas for the active biomarker
        let phaseDeltas = calculatePhaseDeltas(
            milestones: phaseMilestones,
            biomarkerName: resolvedBiomarkerName ?? "Biomarker"
        )

        // 8. Determine global date boundaries
        let allDates = alignedEvents.map(\.timestamp) + activePoints.map(\.timestamp)
        let startDate = allDates.min()
        let endDate = allDates.max()

        // 9. Generate Clinical Summary Text
        let summaryText = generateSummaryInsights(
            selectedBiomarker: resolvedBiomarkerName,
            activePoints: activePoints,
            milestones: phaseMilestones,
            deltas: phaseDeltas,
            overlays: overlays
        )

        let totalDoses = doseLogs.filter { $0.status == .taken }.count
        let totalChanges = protocols.count + protocolRevisions.count

        return LaboratoryTimelineAnalysis(
            selectedBiomarkerName: resolvedBiomarkerName,
            biomarkerTimeSeries: biomarkerSeries,
            availableBiomarkers: availableNames,
            alignedEvents: alignedEvents,
            protocolOverlays: overlays,
            phaseMilestones: phaseMilestones,
            phaseDeltas: phaseDeltas,
            startDate: startDate,
            endDate: endDate,
            totalLabDraws: labPanels.count,
            totalDosesAligned: totalDoses,
            totalProtocolChanges: totalChanges,
            overallSummaryText: summaryText
        )
    }

    // MARK: - 2. Protocol Period Overlays Generation

    /// Synthesizes complete protocol period overlays, including baseline phases, active intervals,
    /// titrations/revisions, washout periods, and follow-up phases.
    public func buildProtocolOverlays(
        protocols: [ProtocolModel],
        revisions: [ProtocolRevision] = [],
        doseLogs: [DoseLog] = [],
        labPanels: [LabPanel] = [],
        measurements: [Measurement] = [],
        calendar: Calendar = .current
    ) -> [ProtocolPeriodOverlay] {
        guard !protocols.isEmpty else {
            // If no protocols exist but lab panels do, synthesize a baseline phase
            if let firstLab = labPanels.map(\.collectionDate).min() {
                return [
                    ProtocolPeriodOverlay(
                        name: "Baseline Observation",
                        phaseType: .baseline,
                        startDate: firstLab,
                        endDate: nil,
                        colorHex: ProtocolPhaseType.baseline.badgeColorHex,
                        compoundsSummary: "No Active Compounds",
                        notes: "Pre-protocol diagnostic tracking",
                        isOngoing: true
                    )
                ]
            }
            return []
        }

        var overlays: [ProtocolPeriodOverlay] = []
        let sortedProtocols = protocols.sorted(by: { $0.startDate < $1.startDate })
        guard let earliestProtocolStart = sortedProtocols.first?.startDate else { return [] }

        // 1. Check for Pre-Protocol Baseline Data
        let preProtocolLabDates = labPanels.map(\.collectionDate).filter { $0 < earliestProtocolStart }
        let preProtocolMeasurementDates = measurements.map(\.dateRecorded).filter { $0 < earliestProtocolStart }
        let allPreDates = preProtocolLabDates + preProtocolMeasurementDates

        if let earliestPre = allPreDates.min() {
            let baselineOverlay = ProtocolPeriodOverlay(
                name: "Baseline Period",
                phaseType: .baseline,
                startDate: earliestPre,
                endDate: earliestProtocolStart.addingTimeInterval(-1),
                colorHex: ProtocolPhaseType.baseline.badgeColorHex,
                compoundsSummary: "Pre-Protocol Baseline",
                totalDosesAdministered: 0,
                notes: "Initial physiological markers prior to intervention."
            )
            overlays.append(baselineOverlay)
        }

        // 2. Build Overlays for each Protocol (and its revisions)
        for proto in sortedProtocols {
            let protoDoses = doseLogs.filter { log in
                if let pid = log.associatedProtocolId, pid == proto.id { return true }
                let d = log.loggedDate ?? log.scheduledDate
                return d >= proto.startDate && (proto.endDate == nil || d <= proto.endDate!)
            }

            let takenCount = protoDoses.filter { $0.status == .taken }.count
            let adherencePct = protoDoses.isEmpty ? nil : (Double(takenCount) / Double(protoDoses.count)) * 100.0

            let compoundsDesc = proto.compounds.map { c in
                let amtStr = String(format: c.dosageAmount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", c.dosageAmount)
                return "\(c.compoundName) \(amtStr)\(c.unit.rawValue)"
            }.joined(separator: " + ")

            // Check if protocol has explicit revisions
            let matchingRevisions = revisions.filter { $0.protocolId == proto.id }.sorted(by: { $0.effectiveDate < $1.effectiveDate })

            if matchingRevisions.isEmpty {
                // Single unsegmented protocol overlay
                overlays.append(
                    ProtocolPeriodOverlay(
                        protocolId: proto.id,
                        name: proto.name,
                        phaseType: .activeProtocol,
                        startDate: proto.startDate,
                        endDate: proto.endDate,
                        colorHex: proto.colorHex.isEmpty ? "#10B981" : proto.colorHex,
                        compoundsSummary: compoundsDesc.isEmpty ? proto.name : compoundsDesc,
                        totalDosesAdministered: takenCount,
                        adherencePercentage: adherencePct,
                        notes: proto.notes,
                        isOngoing: proto.endDate == nil && proto.status == .active
                    )
                )
            } else {
                // Segment protocol into revisions
                var currentStart = proto.startDate
                for (idx, rev) in matchingRevisions.enumerated() {
                    let revEnd = (idx + 1 < matchingRevisions.count) ? matchingRevisions[idx + 1].effectiveDate : proto.endDate
                    let revCompDesc = rev.compounds.map { c in
                        let amtStr = String(format: c.dosageAmount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", c.dosageAmount)
                        return "\(c.compoundName) \(amtStr)\(c.unit.rawValue)"
                    }.joined(separator: " + ")

                    let phaseType: ProtocolPhaseType = idx == 0 ? .activeProtocol : .titration
                    let revName = idx == 0 ? "\(proto.name) (Initial)" : "\(proto.name) (v\(rev.revisionNumber): \(rev.reasonForChange))"

                    overlays.append(
                        ProtocolPeriodOverlay(
                            protocolId: proto.id,
                            name: revName,
                            phaseType: phaseType,
                            startDate: currentStart,
                            endDate: revEnd,
                            colorHex: idx == 0 ? proto.colorHex : ProtocolPhaseType.titration.badgeColorHex,
                            compoundsSummary: revCompDesc.isEmpty ? compoundsDesc : revCompDesc,
                            totalDosesAdministered: takenCount,
                            adherencePercentage: adherencePct,
                            notes: rev.reasonForChange,
                            isOngoing: revEnd == nil && proto.status == .active
                        )
                    )
                    currentStart = rev.effectiveDate
                }
            }
        }

        // 3. Insert Washout / Rest periods between protocols if gap > 3 days
        var finalOverlays: [ProtocolPeriodOverlay] = []
        for i in 0..<overlays.count {
            finalOverlays.append(overlays[i])
            if i + 1 < overlays.count {
                let current = overlays[i]
                let next = overlays[i + 1]
                if let currentEnd = current.endDate, currentEnd < next.startDate {
                    let gapDays = calendar.dateComponents([.day], from: currentEnd, to: next.startDate).day ?? 0
                    if gapDays >= 3 {
                        finalOverlays.append(
                            ProtocolPeriodOverlay(
                                name: "Washout Period (\(gapDays)d)",
                                phaseType: .washout,
                                startDate: currentEnd.addingTimeInterval(1),
                                endDate: next.startDate.addingTimeInterval(-1),
                                colorHex: ProtocolPhaseType.washout.badgeColorHex,
                                compoundsSummary: "No Active Administration",
                                totalDosesAdministered: 0,
                                notes: "Elimination and clearance rest interval."
                            )
                        )
                    }
                }
            }
        }

        // 4. Check for Post-Protocol Follow-Up Data
        if let latestProtocolEnd = sortedProtocols.compactMap(\.endDate).max(),
           sortedProtocols.allSatisfy({ $0.status == .completed || $0.status == .paused }) {
            let postLabDates = labPanels.map(\.collectionDate).filter { $0 > latestProtocolEnd }
            let postMeasurementDates = measurements.map(\.dateRecorded).filter { $0 > latestProtocolEnd }
            let allPostDates = postLabDates + postMeasurementDates

            if let latestPost = allPostDates.max() {
                finalOverlays.append(
                    ProtocolPeriodOverlay(
                        name: "Follow-Up Phase",
                        phaseType: .followUp,
                        startDate: latestProtocolEnd.addingTimeInterval(1),
                        endDate: latestPost,
                        colorHex: ProtocolPhaseType.followUp.badgeColorHex,
                        compoundsSummary: "Post-Protocol Monitoring",
                        totalDosesAdministered: 0,
                        notes: "Longitudinal post-cycle diagnostic retention."
                    )
                )
            }
        }

        return finalOverlays.sorted(by: { $0.startDate < $1.startDate })
    }

    // MARK: - 3. Biomarker Time Series Extraction

    /// Converts raw lab panels and biomarkers into structured, protocol-aligned `LabTimeSeriesPoint` collections.
    public func buildBiomarkerTimeSeries(
        labPanels: [LabPanel],
        biomarkers: [Biomarker] = [],
        overlays: [ProtocolPeriodOverlay],
        doseLogs: [DoseLog] = [],
        calendar: Calendar = .current
    ) -> [String: [LabTimeSeriesPoint]] {
        var seriesMap: [String: [LabTimeSeriesPoint]] = [:]

        // 1. Process structured LabPanel records
        for panel in labPanels {
            let matchingOverlay = overlays.first(where: { $0.contains(date: panel.collectionDate) })
            let protocolPhase = matchingOverlay?.phaseType ?? (overlays.isEmpty ? .baseline : .unassigned)

            // Calculate elapsed days from matching protocol start
            var daysOnProto: Int? = nil
            if let overlay = matchingOverlay {
                daysOnProto = max(0, calendar.dateComponents([.day], from: overlay.startDate, to: panel.collectionDate).day ?? 0)
            }

            // Calculate cumulative dose received prior to this lab draw
            let priorDoses = doseLogs.filter { log in
                let d = log.loggedDate ?? log.scheduledDate
                return d <= panel.collectionDate && log.status == .taken
            }
            let cumulativeDoseAmount = priorDoses.map(\.doseAmount).reduce(0.0, +)
            let doseUnit = priorDoses.first?.doseUnit.rawValue ?? "mcg"

            for result in panel.results {
                let canonicalName = canonicalBiomarkerName(result.biomarkerName)
                let point = LabTimeSeriesPoint(
                    id: result.id,
                    timestamp: panel.collectionDate,
                    value: result.value,
                    unit: result.unit,
                    source: .labImport,
                    notes: result.notes.isEmpty ? panel.notes : result.notes,
                    associatedProtocolId: matchingOverlay?.protocolId ?? panel.associatedProtocolId,
                    biomarkerName: canonicalName,
                    category: result.category,
                    referenceRangeMin: result.referenceRangeMin,
                    referenceRangeMax: result.referenceRangeMax,
                    referenceRangeText: result.referenceRangeText,
                    flag: result.flag,
                    panelId: panel.id,
                    panelName: panel.panelName,
                    labName: panel.labName,
                    protocolName: matchingOverlay?.name,
                    protocolPhase: protocolPhase,
                    daysOnProtocolAtDraw: daysOnProto,
                    cumulativeDosePriorToDraw: cumulativeDoseAmount > 0 ? cumulativeDoseAmount : nil,
                    cumulativeDoseUnit: cumulativeDoseAmount > 0 ? doseUnit : nil
                )

                seriesMap[canonicalName, default: []].append(point)
            }
        }

        // 2. Process standalone Biomarker records (e.g. from manual logs or Apple Health)
        for marker in biomarkers {
            let canonicalName = canonicalBiomarkerName(marker.name)
            // Skip if already captured from panel
            if let existing = seriesMap[canonicalName], existing.contains(where: { calendar.isDate($0.timestamp, equalTo: marker.dateRecorded, toGranularity: .hour) }) {
                continue
            }

            let matchingOverlay = overlays.first(where: { $0.contains(date: marker.dateRecorded) })
            let protocolPhase = matchingOverlay?.phaseType ?? (overlays.isEmpty ? .baseline : .unassigned)

            var daysOnProto: Int? = nil
            if let overlay = matchingOverlay {
                daysOnProto = max(0, calendar.dateComponents([.day], from: overlay.startDate, to: marker.dateRecorded).day ?? 0)
            }

            let point = LabTimeSeriesPoint(
                id: marker.id,
                timestamp: marker.dateRecorded,
                value: marker.value,
                unit: marker.unit,
                source: marker.source,
                notes: marker.notes,
                associatedProtocolId: matchingOverlay?.protocolId,
                biomarkerName: canonicalName,
                category: labCategory(from: marker.category),
                referenceRangeMin: marker.referenceRangeMin,
                referenceRangeMax: marker.referenceRangeMax,
                flag: labFlag(from: marker.status),
                panelId: UUID(),
                panelName: "Diagnostic Log",
                labName: marker.source.rawValue,
                protocolName: matchingOverlay?.name,
                protocolPhase: protocolPhase,
                daysOnProtocolAtDraw: daysOnProto
            )

            seriesMap[canonicalName, default: []].append(point)
        }

        // Sort all time series chronologically
        for (key, points) in seriesMap {
            seriesMap[key] = points.sorted(by: { $0.timestamp < $1.timestamp })
        }

        return seriesMap
    }

    // MARK: - 4. Unified Event Alignment Pipeline

    /// Aligns all doses, protocol transitions, measurements, lab results, and milestones on one chronological axis.
    public func alignAllEvents(
        labPanels: [LabPanel],
        biomarkers: [Biomarker] = [],
        protocols: [ProtocolModel] = [],
        protocolRevisions: [ProtocolRevision] = [],
        doseLogs: [DoseLog] = [],
        measurements: [Measurement] = [],
        overlays: [ProtocolPeriodOverlay],
        calendar: Calendar = .current
    ) -> [AlignedTimelineItem] {
        var items: [AlignedTimelineItem] = []

        // 1. Protocol Start and End Milestones
        for proto in protocols {
            let startItem = AlignedTimelineItem(
                id: UUID(),
                timestamp: proto.startDate,
                type: .protocolStart,
                title: "Started \(proto.name)",
                subtitle: proto.compounds.map(\.compoundName).joined(separator: ", "),
                detail: proto.notes.isEmpty ? nil : proto.notes,
                badgeText: "PROTOCOL START",
                badgeColorHex: ProtocolPhaseType.activeProtocol.badgeColorHex,
                associatedEntityId: proto.id,
                associatedProtocolId: proto.id,
                protocolName: proto.name,
                phaseType: .activeProtocol,
                isHighlighted: true
            )
            items.append(startItem)

            if let end = proto.endDate {
                let endItem = AlignedTimelineItem(
                    id: UUID(),
                    timestamp: end,
                    type: .protocolEnd,
                    title: "Completed \(proto.name)",
                    subtitle: "Protocol cycle concluded",
                    detail: proto.goalSummary.isEmpty ? nil : proto.goalSummary,
                    badgeText: "CYCLE COMPLETE",
                    badgeColorHex: ProtocolPhaseType.washout.badgeColorHex,
                    associatedEntityId: proto.id,
                    associatedProtocolId: proto.id,
                    protocolName: proto.name,
                    phaseType: .washout,
                    isHighlighted: true
                )
                items.append(endItem)
            }
        }

        // 2. Protocol Revisions & Dose Changes
        for rev in protocolRevisions {
            let revItem = AlignedTimelineItem(
                id: UUID(),
                timestamp: rev.effectiveDate,
                type: .doseChange,
                title: "Dose / Protocol Adjustment (v\(rev.revisionNumber))",
                subtitle: rev.reasonForChange,
                detail: rev.compounds.map { "\($0.compoundName): \($0.dosageAmount)\($0.unit.rawValue)" }.joined(separator: " • "),
                badgeText: "TITRATION",
                badgeColorHex: ProtocolPhaseType.titration.badgeColorHex,
                associatedEntityId: rev.id,
                associatedProtocolId: rev.protocolId,
                protocolName: rev.name,
                phaseType: .titration,
                isHighlighted: true
            )
            items.append(revItem)
        }

        // 3. Laboratory Diagnostics & Bloodwork
        let earliestProtoDate = protocols.map(\.startDate).min()
        let latestProtoDate = protocols.compactMap(\.endDate).max()

        for panel in labPanels {
            let isBaseline = earliestProtoDate != nil && panel.collectionDate < earliestProtoDate!
            let isFollowUp = latestProtoDate != nil && panel.collectionDate > latestProtoDate!
            let phase: ProtocolPhaseType = isBaseline ? .baseline : (isFollowUp ? .followUp : .activeProtocol)
            let eventType: AlignedEventType = isBaseline ? .baselineDraw : (isFollowUp ? .followUpLab : .labResult)

            let abnormalCount = panel.abnormalResults.count
            let summarySub = abnormalCount == 0 ? "\(panel.resultCount) biomarkers • All optimal" : "\(panel.resultCount) biomarkers • \(abnormalCount) out of bounds"

            let matchingOverlay = overlays.first(where: { $0.contains(date: panel.collectionDate) })

            let labItem = AlignedTimelineItem(
                id: panel.id,
                timestamp: panel.collectionDate,
                type: eventType,
                title: "\(panel.labName): \(panel.panelName)",
                subtitle: summarySub,
                detail: panel.notes.isEmpty ? nil : panel.notes,
                valueString: "\(panel.resultCount) Analytes",
                badgeText: isBaseline ? "BASELINE LAB" : (isFollowUp ? "FOLLOW-UP LAB" : "LAB DIAGNOSTIC"),
                badgeColorHex: eventType.badgeColorHex,
                associatedEntityId: panel.id,
                associatedProtocolId: matchingOverlay?.protocolId ?? panel.associatedProtocolId,
                protocolName: matchingOverlay?.name,
                phaseType: phase,
                isHighlighted: panel.hasAbnormalResults || isBaseline || isFollowUp
            )
            items.append(labItem)
        }

        // 4. Dose Events / Logs
        for dose in doseLogs {
            let isTaken = dose.status == .taken
            let time = dose.loggedDate ?? dose.scheduledDate
            let matchingOverlay = overlays.first(where: { $0.contains(date: time) })
            let amtStr = String(format: dose.doseAmount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", dose.doseAmount)

            let doseItem = AlignedTimelineItem(
                id: dose.id,
                timestamp: time,
                type: isTaken ? .doseAdministered : .doseMissed,
                title: "\(dose.compoundName) Dose",
                subtitle: isTaken ? "\(amtStr) \(dose.doseUnit.rawValue) • \(dose.administrationRoute.rawValue)" : "Missed Scheduled Dose",
                detail: dose.notes.isEmpty ? nil : dose.notes,
                valueString: "\(amtStr) \(dose.doseUnit.rawValue)",
                badgeText: isTaken ? "ADMINISTERED" : "MISSED",
                badgeColorHex: isTaken ? AlignedEventType.doseAdministered.badgeColorHex : AlignedEventType.doseMissed.badgeColorHex,
                associatedEntityId: dose.id,
                associatedProtocolId: matchingOverlay?.protocolId ?? dose.associatedProtocolId,
                protocolName: matchingOverlay?.name,
                phaseType: matchingOverlay?.phaseType ?? .activeProtocol,
                isHighlighted: !isTaken
            )
            items.append(doseItem)
        }

        // 5. Health Measurements & Vitals
        for m in measurements {
            let matchingOverlay = overlays.first(where: { $0.contains(date: m.dateRecorded) })
            let mItem = AlignedTimelineItem(
                id: m.id,
                timestamp: m.dateRecorded,
                type: .measurement,
                title: m.name,
                subtitle: m.formattedValue,
                detail: m.notes.isEmpty ? nil : m.notes,
                valueString: m.formattedValue,
                badgeText: m.status == .inRange ? nil : m.status.rawValue,
                badgeColorHex: m.status.colorHex,
                associatedEntityId: m.id,
                associatedProtocolId: matchingOverlay?.protocolId ?? m.associatedProtocolId,
                protocolName: matchingOverlay?.name,
                phaseType: matchingOverlay?.phaseType ?? .unassigned,
                isHighlighted: m.status != .inRange
            )
            items.append(mItem)
        }

        // Sort all items in strict chronological order
        return items.sorted(by: { $0.timestamp < $1.timestamp })
    }

    // MARK: - 5. Phase Transition Journey Stepper

    /// Constructs sequential milestone nodes: Baseline → Protocol A → Dose Change → Protocol B → Follow-up Lab.
    public func buildPhaseJourney(
        overlays: [ProtocolPeriodOverlay],
        labPoints: [LabTimeSeriesPoint],
        revisions: [ProtocolRevision] = [],
        calendar: Calendar = .current
    ) -> [PhaseTransitionMilestone] {
        guard !overlays.isEmpty else {
            // If only lab points exist, build milestone for each lab point
            return labPoints.enumerated().map { (idx, pt) in
                PhaseTransitionMilestone(
                    phaseName: pt.panelName,
                    phaseType: .baseline,
                    date: pt.timestamp,
                    analyteValue: pt.value,
                    analyteUnit: pt.unit,
                    analyteFlag: pt.flag,
                    protocolName: "Observation",
                    notes: pt.formattedValue
                )
            }
        }

        var milestones: [PhaseTransitionMilestone] = []
        var baselinePoint: LabTimeSeriesPoint? = nil

        for overlay in overlays {
            // Find lab points falling inside or closest to this overlay window
            let pointsInOverlay = labPoints.filter { overlay.contains(date: $0.timestamp) }
            let representativePoint = pointsInOverlay.last ?? pointsInOverlay.first

            if overlay.phaseType == .baseline && baselinePoint == nil {
                baselinePoint = representativePoint
            }

            var deltaPrev: Double? = nil
            var pctDeltaPrev: Double? = nil
            var deltaBase: Double? = nil
            var pctDeltaBase: Double? = nil

            if let curVal = representativePoint?.value {
                // Delta from previous milestone
                if let lastMilestone = milestones.last, let prevVal = lastMilestone.analyteValue {
                    deltaPrev = curVal - prevVal
                    if prevVal != 0 {
                        pctDeltaPrev = ((curVal - prevVal) / abs(prevVal)) * 100.0
                    }
                }

                // Delta from baseline
                if let baseVal = baselinePoint?.value {
                    deltaBase = curVal - baseVal
                    if baseVal != 0 {
                        pctDeltaBase = ((curVal - baseVal) / abs(baseVal)) * 100.0
                    }
                }
            }

            let milestone = PhaseTransitionMilestone(
                id: overlay.id,
                phaseName: overlay.name,
                phaseType: overlay.phaseType,
                date: overlay.startDate,
                durationDays: overlay.durationDays,
                analyteValue: representativePoint?.value,
                analyteUnit: representativePoint?.unit,
                analyteFlag: representativePoint?.flag,
                deltaFromPrevious: deltaPrev,
                percentageDeltaFromPrevious: pctDeltaPrev,
                deltaFromBaseline: deltaBase,
                percentageDeltaFromBaseline: pctDeltaBase,
                protocolName: overlay.compoundsSummary.isEmpty ? overlay.name : overlay.compoundsSummary,
                notes: overlay.notes
            )
            milestones.append(milestone)
        }

        return milestones
    }

    // MARK: - 6. Pairwise Phase Deltas

    /// Computes statistical biomarker differentials across sequential protocol phases.
    public func calculatePhaseDeltas(
        milestones: [PhaseTransitionMilestone],
        biomarkerName: String
    ) -> [BiomarkerPhaseDelta] {
        var deltas: [BiomarkerPhaseDelta] = []
        guard milestones.count >= 2 else { return [] }

        for i in 0..<(milestones.count - 1) {
            let mFrom = milestones[i]
            let mTo = milestones[i + 1]

            guard let valFrom = mFrom.analyteValue,
                  let valTo = mTo.analyteValue,
                  let unit = mTo.analyteUnit ?? mFrom.analyteUnit else {
                continue
            }

            let absDelta = valTo - valFrom
            let pctChange = valFrom != 0 ? ((valTo - valFrom) / abs(valFrom)) * 100.0 : 0.0

            let days = max(1.0, mTo.date.timeIntervalSince(mFrom.date) / 86400.0)
            let weeks = days / 7.0
            let rate = absDelta / weeks

            let sign = absDelta > 0 ? "+" : ""
            let valStr = String(format: "%.1f", absDelta)
            let pctStr = String(format: "%.1f%%", pctChange)
            let clinicalText = "\(biomarkerName) shifted by \(sign)\(valStr) \(unit) (\(sign)\(pctStr)) from \(mFrom.phaseName) to \(mTo.phaseName)."

            let delta = BiomarkerPhaseDelta(
                biomarkerName: biomarkerName,
                unit: unit,
                fromPhaseName: mFrom.phaseName,
                toPhaseName: mTo.phaseName,
                fromValue: valFrom,
                toValue: valTo,
                fromDate: mFrom.date,
                toDate: mTo.date,
                absoluteDelta: absDelta,
                percentageChange: pctChange,
                ratePerWeek: rate,
                isImprovement: nil, // Direction evaluated at UI or Catalog level
                clinicalInterpretation: clinicalText
            )
            deltas.append(delta)
        }

        return deltas
    }

    // MARK: - 7. Helper Utilities

    private func resolveSelectedBiomarker(
        selected: String?,
        available: [String],
        seriesMap: [String: [LabTimeSeriesPoint]]
    ) -> String? {
        if let sel = selected, available.contains(sel) {
            return sel
        }
        // Priority defaults
        let preferred = ["Total Testosterone", "Free Testosterone", "IGF-1", "Fasting Glucose", "Apolipoprotein B", "ALT", "hs-CRP"]
        for p in preferred {
            if let match = available.first(where: { $0.localizedCaseInsensitiveContains(p) }) {
                return match
            }
        }
        // Return biomarker with the most time-series points
        return available.max(by: { (seriesMap[$0]?.count ?? 0) < (seriesMap[$1]?.count ?? 0) }) ?? available.first
    }

    private func canonicalBiomarkerName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.localizedCaseInsensitiveContains("Testosterone, Total") || trimmed.localizedCaseInsensitiveContains("Total Testosterone") {
            return "Total Testosterone"
        }
        if trimmed.localizedCaseInsensitiveContains("Testosterone, Free") || trimmed.localizedCaseInsensitiveContains("Free Testosterone") {
            return "Free Testosterone"
        }
        if trimmed.localizedCaseInsensitiveContains("Somatomedin") || trimmed.localizedCaseInsensitiveContains("IGF-1") || trimmed.localizedCaseInsensitiveContains("IGF1") {
            return "IGF-1 (Somatomedin C)"
        }
        if trimmed.localizedCaseInsensitiveContains("Glucose") {
            return "Fasting Blood Glucose"
        }
        if trimmed.localizedCaseInsensitiveContains("ApoB") || trimmed.localizedCaseInsensitiveContains("Apolipoprotein B") {
            return "Apolipoprotein B (ApoB)"
        }
        if trimmed.localizedCaseInsensitiveContains("ALT") || trimmed.localizedCaseInsensitiveContains("Alanine Aminotransferase") {
            return "ALT (Alanine Aminotransferase)"
        }
        if trimmed.localizedCaseInsensitiveContains("AST") || trimmed.localizedCaseInsensitiveContains("Aspartate Aminotransferase") {
            return "AST (Aspartate Aminotransferase)"
        }
        return trimmed
    }

    private func generateSummaryInsights(
        selectedBiomarker: String?,
        activePoints: [LabTimeSeriesPoint],
        milestones: [PhaseTransitionMilestone],
        deltas: [BiomarkerPhaseDelta],
        overlays: [ProtocolPeriodOverlay]
    ) -> String {
        guard let markerName = selectedBiomarker, activePoints.count >= 2 else {
            return "Log additional diagnostic draws across protocol cycles to calculate longitudinal trajectory and phase alignment."
        }

        let first = activePoints.first!
        let latest = activePoints.last!
        let totalDelta = latest.value - first.value
        let pct = first.value != 0 ? ((totalDelta) / abs(first.value)) * 100.0 : 0.0
        let sign = totalDelta > 0 ? "+" : ""
        let valStr = String(format: "%.1f", totalDelta)
        let pctStr = String(format: "%.1f%%", pct)

        var summary = "\(markerName) moved \(sign)\(valStr) \(latest.unit) (\(sign)\(pctStr)) from \(first.formattedValue) to \(latest.formattedValue) across \(activePoints.count) laboratory draws."

        if let firstDelta = deltas.first {
            summary += " Initial response during \(firstDelta.toPhaseName) showed a \(String(format: "%.1f%%", firstDelta.percentageChange)) change."
        }

        return summary
    }

    private func labCategory(from bioCat: BiomarkerCategory) -> LabCategory {
        switch bioCat {
        case .bloodwork: return .hormones
        case .bodyComposition: return .custom
        case .cardiovascular: return .lipids
        case .metabolic: return .metabolic
        case .sleepRecovery: return .custom
        }
    }

    private func labFlag(from status: BiomarkerStatus) -> LabResultFlag {
        switch status {
        case .low: return .low
        case .inRange: return .inRange
        case .high: return .high
        }
    }
}
