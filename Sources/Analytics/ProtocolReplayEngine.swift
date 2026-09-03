import Foundation
import Domain
import CalculationEngine

public typealias Measurement = Domain.Measurement

/// High-performance analytics engine for the Protocol Replay feature.
///
/// Collects, aligns, and normalizes all historical events associated with a protocol
/// (doses, measurements, diagnostic bloodwork labs, protocol modifications/revisions, and symptom logs),
/// sorts them chronologically, computes frame-by-frame cumulative state snapshots, generates editorial
/// commentary, and produces chapter bookmarks for seamless longitudinal playback and timeline scrubbing.
public struct ProtocolReplayEngine: Sendable {

    public init() {}

    // MARK: - Primary Sequence Builder

    /// Compiles a complete chronological `ProtocolReplaySequence` for an individual protocol.
    public func buildReplaySequence(
        for protocolModel: ProtocolModel,
        doses: [DoseLog] = [],
        measurements: [Measurement] = [],
        labPanels: [LabPanel] = [],
        protocolRevisions: [ProtocolRevision] = [],
        symptomLogs: [SymptomLog] = [],
        injectionSiteEvents: [InjectionSiteEvent] = [],
        calendar: Calendar = .current
    ) -> ProtocolReplaySequence {
        // 1. Filter events associated with or overlapping this protocol
        let associatedDoses = filterAssociatedDoses(doses, for: protocolModel)
        let associatedMeasurements = filterAssociatedMeasurements(measurements, for: protocolModel)
        let associatedLabPanels = filterAssociatedLabs(labPanels, for: protocolModel)
        let associatedRevisions = protocolRevisions.filter { $0.protocolId == protocolModel.id }
        let associatedSymptoms = filterAssociatedSymptoms(symptomLogs, for: protocolModel)
        let siteEventMap = Dictionary(grouping: injectionSiteEvents, by: { $0.doseEventId })

        // 2. Baseline reference caches for delta calculations
        let baselineMeasurements = resolveBaselineMeasurements(associatedMeasurements, protocolStartDate: protocolModel.startDate)
        let baselineLabResults = resolveBaselineLabResults(associatedLabPanels, protocolStartDate: protocolModel.startDate)

        // 3. Normalize all candidate items into unindexed ProtocolReplayEvents
        var rawEvents: [ProtocolReplayEvent] = []

        // 3a. Initial Protocol Launch Milestone
        let startEvent = createProtocolStartMilestone(for: protocolModel)
        rawEvents.append(startEvent)

        // 3b. Reconstitution & Protocol Revisions
        for rev in associatedRevisions {
            let revEvent = createRevisionEvent(from: rev, protocolStartDate: protocolModel.startDate, calendar: calendar)
            rawEvents.append(revEvent)
        }

        // 3c. Doses
        for dose in associatedDoses {
            let site = dose.injectionSiteId.flatMap { siteId in
                injectionSiteEvents.first(where: { $0.siteId == siteId })
            } ?? siteEventMap[dose.id]?.first
            let doseEvent = createDoseEvent(from: dose, injectionSite: site, protocolStartDate: protocolModel.startDate, calendar: calendar)
            rawEvents.append(doseEvent)
        }

        // 3d. Measurements
        for m in associatedMeasurements {
            let mEvent = createMeasurementEvent(
                from: m,
                baselineMeasurement: baselineMeasurements[m.type.rawValue] ?? baselineMeasurements[m.name],
                protocolStartDate: protocolModel.startDate,
                calendar: calendar
            )
            rawEvents.append(mEvent)
        }

        // 3e. Lab Panels
        for lab in associatedLabPanels {
            let labEvent = createLabEvent(
                from: lab,
                baselineResults: baselineLabResults,
                protocolStartDate: protocolModel.startDate,
                calendar: calendar
            )
            rawEvents.append(labEvent)
        }

        // 3f. Symptom Logs
        for symptom in associatedSymptoms {
            let sEvent = createSymptomEvent(from: symptom, protocolStartDate: protocolModel.startDate, calendar: calendar)
            rawEvents.append(sEvent)
        }

        // 3g. Protocol Completion Milestone (if completed or ended)
        if let end = protocolModel.endDate, end <= Date() || protocolModel.status == .completed {
            let completionEvent = createProtocolEndMilestone(for: protocolModel)
            rawEvents.append(completionEvent)
        }

        // 4. Sort strictly chronologically with deterministic tie-breaking
        let sortedEvents = sortChronologically(rawEvents)

        // 5. Compute sequential running cumulative state & commentary for each frame
        let populatedEvents = computeCumulativeStates(
            events: sortedEvents,
            protocolModel: protocolModel,
            calendar: calendar
        )

        // 6. Generate chapter bookmarks for quick scrubbing
        let chapters = generateChapters(
            for: populatedEvents,
            protocolModel: protocolModel
        )

        // 7. Baseline and Latest Metric Summaries
        let baselineSummary = formatBaselineSummary(measurements: baselineMeasurements, labResults: baselineLabResults)
        let latestSummary = formatLatestSummary(from: populatedEvents.last?.cumulativeState)

        // 8. Overall adherence calculation
        let takenDoses = associatedDoses.filter { $0.status == .taken }.count
        let totalDoses = associatedDoses.count
        let adherence = totalDoses > 0 ? (Double(takenDoses) / Double(totalDoses)) * 100.0 : nil

        return ProtocolReplaySequence(
            protocolId: protocolModel.id,
            protocolName: protocolModel.name,
            startDate: protocolModel.startDate,
            endDate: protocolModel.endDate,
            goalSummary: protocolModel.goalSummary,
            colorHex: protocolModel.colorHex,
            events: populatedEvents,
            chapters: chapters,
            totalDosesCount: associatedDoses.count,
            totalMeasurementsCount: associatedMeasurements.count,
            totalLabDrawsCount: associatedLabPanels.count,
            totalRevisionsCount: associatedRevisions.count,
            overallAdherenceRate: adherence,
            baselineMetricsSummary: baselineSummary,
            latestMetricsSummary: latestSummary
        )
    }

    // MARK: - Event Filtering Helpers

    private func filterAssociatedDoses(_ doses: [DoseLog], for proto: ProtocolModel) -> [DoseLog] {
        doses.filter { dose in
            if let pid = dose.associatedProtocolId, pid == proto.id { return true }
            if let pid = dose.protocolId, pid == proto.id { return true }

            let d = dose.loggedDate ?? dose.scheduledDate
            let start = proto.startDate.addingTimeInterval(-86400) // 1 day buffer
            let end = proto.endDate ?? Date().addingTimeInterval(86400 * 365)
            let withinDate = d >= start && d <= end

            let compoundMatch = proto.items.contains(where: { $0.compoundId == dose.compoundId || $0.compoundName.localizedCaseInsensitiveCompare(dose.compoundName) == .orderedSame })
            return withinDate && compoundMatch
        }
    }

    private func filterAssociatedMeasurements(_ measurements: [Measurement], for proto: ProtocolModel) -> [Measurement] {
        measurements.filter { m in
            if let pid = m.associatedProtocolId, pid == proto.id { return true }
            let start = proto.startDate.addingTimeInterval(-86400 * 30) // Up to 30 days pre-protocol baseline
            let end = proto.endDate ?? Date().addingTimeInterval(86400 * 30)
            return m.dateRecorded >= start && m.dateRecorded <= end
        }
    }

    private func filterAssociatedLabs(_ labs: [LabPanel], for proto: ProtocolModel) -> [LabPanel] {
        labs.filter { lab in
            if let pid = lab.associatedProtocolId, pid == proto.id { return true }
            let start = proto.startDate.addingTimeInterval(-86400 * 45) // Up to 45 days baseline
            let end = proto.endDate?.addingTimeInterval(86400 * 30) ?? Date().addingTimeInterval(86400 * 30)
            return lab.collectionDate >= start && lab.collectionDate <= end
        }
    }

    private func filterAssociatedSymptoms(_ symptoms: [SymptomLog], for proto: ProtocolModel) -> [SymptomLog] {
        symptoms.filter { s in
            let start = proto.startDate.addingTimeInterval(-86400 * 7)
            let end = proto.endDate ?? Date().addingTimeInterval(86400 * 7)
            return s.timestamp >= start && s.timestamp <= end
        }
    }

    // MARK: - Baseline Resolvers

    private func resolveBaselineMeasurements(_ measurements: [Measurement], protocolStartDate: Date) -> [String: Measurement] {
        var dict: [String: Measurement] = [:]
        let preOrKickoff = measurements.filter { $0.dateRecorded <= protocolStartDate.addingTimeInterval(86400 * 2) }
            .sorted(by: { $0.dateRecorded < $1.dateRecorded })

        for m in preOrKickoff {
            if dict[m.type.rawValue] == nil {
                dict[m.type.rawValue] = m
            }
            if dict[m.name] == nil {
                dict[m.name] = m
            }
        }
        return dict
    }

    private func resolveBaselineLabResults(_ labs: [LabPanel], protocolStartDate: Date) -> [String: LabResult] {
        var dict: [String: LabResult] = [:]
        let baselinePanels = labs.filter { $0.collectionDate <= protocolStartDate.addingTimeInterval(86400 * 3) }
            .sorted(by: { $0.collectionDate < $1.collectionDate })

        for panel in baselinePanels {
            for result in panel.results {
                if dict[result.biomarkerName] == nil {
                    dict[result.biomarkerName] = result
                }
            }
        }
        return dict
    }

    // MARK: - Event Factories

    private func createProtocolStartMilestone(for proto: ProtocolModel) -> ProtocolReplayEvent {
        let compoundsSummary = proto.items.map { "\($0.compoundName) (\(String(format: "%.0f", $0.doseAmount))\($0.doseUnit.rawValue))" }.joined(separator: " + ")
        return ProtocolReplayEvent(
            timestamp: proto.startDate,
            protocolDay: 1,
            category: .milestone,
            title: "Protocol Initiated",
            subtitle: proto.name,
            detailText: compoundsSummary.isEmpty ? proto.goalSummary : compoundsSummary,
            badgeText: "Launch",
            badgeColorHex: proto.colorHex,
            iconName: "play.circle.fill",
            isHighlighted: true,
            milestonePayload: ReplayMilestonePayload(
                title: "Protocol Initiated",
                subtitle: proto.name,
                milestoneType: "Launch"
            ),
            narrativeCommentary: "Protocol '\(proto.name)' officially initiated with \(proto.items.count) compound\(proto.items.count == 1 ? "" : "s")."
        )
    }

    private func createProtocolEndMilestone(for proto: ProtocolModel) -> ProtocolReplayEvent {
        let end = proto.endDate ?? Date()
        let day = max(1, Calendar.current.dateComponents([.day], from: proto.startDate, to: end).day ?? 1)
        return ProtocolReplayEvent(
            timestamp: end,
            protocolDay: day,
            category: .milestone,
            title: "Protocol Completed",
            subtitle: "\(proto.name) • Day \(day)",
            detailText: proto.notes.isEmpty ? "All protocol phases completed." : proto.notes,
            badgeText: "Completed",
            badgeColorHex: "#8B5CF6",
            iconName: "flag.checkered",
            isHighlighted: true,
            milestonePayload: ReplayMilestonePayload(
                title: "Protocol Completed",
                subtitle: "Finished after \(day) days",
                milestoneType: "Completion"
            ),
            narrativeCommentary: "Protocol successfully concluded after \(day) days of administration."
        )
    }

    private func createRevisionEvent(from rev: ProtocolRevision, protocolStartDate: Date, calendar: Calendar) -> ProtocolReplayEvent {
        let day = calculateProtocolDay(date: rev.effectiveDate, startDate: protocolStartDate, calendar: calendar)
        let adj = rev.compounds.map { c in
            ReplayDoseAdjustment(
                compoundName: c.compoundName,
                previousDose: c.doseAmount,
                newDose: c.doseAmount,
                doseUnit: c.doseUnit,
                previousSchedule: c.scheduleRule.description,
                newSchedule: c.scheduleRule.description
            )
        }

        let changeSummary = rev.reasonForChange.isEmpty ? "Protocol parameter titration & revision." : rev.reasonForChange
        return ProtocolReplayEvent(
            timestamp: rev.effectiveDate,
            protocolDay: day,
            category: .protocolRevision,
            title: "Protocol Modification (v\(rev.revisionNumber))",
            subtitle: changeSummary,
            detailText: rev.compounds.map { "\($0.compoundName): \(String(format: "%.0f", $0.doseAmount))\($0.doseUnit.rawValue)" }.joined(separator: " • "),
            badgeText: "v\(rev.revisionNumber)",
            badgeColorHex: "#F59E0B",
            iconName: "arrow.triangle.swap",
            isHighlighted: true,
            revisionPayload: ReplayRevisionPayload(
                revisionId: rev.id,
                revisionNumber: rev.revisionNumber,
                reasonForChange: rev.reasonForChange,
                doseAdjustments: adj,
                compoundsAdded: [],
                compoundsRemoved: [],
                effectiveDate: rev.effectiveDate
            ),
            narrativeCommentary: "Protocol parameters adjusted: \(changeSummary)"
        )
    }

    private func createDoseEvent(from dose: DoseLog, injectionSite: InjectionSiteEvent?, protocolStartDate: Date, calendar: Calendar) -> ProtocolReplayEvent {
        let time = dose.loggedDate ?? dose.scheduledDate
        let day = calculateProtocolDay(date: time, startDate: protocolStartDate, calendar: calendar)
        let amtStr = dose.doseAmount.truncatingRemainder(dividingBy: 1) == 0 ?
            String(format: "%.0f", dose.doseAmount) : String(format: "%.1f", dose.doseAmount)

        var siteName = dose.injectionSiteName
        if siteName == nil, let s = injectionSite {
            siteName = s.siteName
        }

        var sub = "\(amtStr) \(dose.doseUnit.rawValue) • \(dose.administrationRoute.rawValue)"
        if let s = siteName {
            sub += " • \(s)"
        }

        let isTaken = dose.status == .taken
        let commentary = isTaken ?
            "Administered \(amtStr) \(dose.doseUnit.rawValue) \(dose.compoundName)\(siteName != nil ? " to \(siteName!)" : "")." :
            "Scheduled \(dose.compoundName) dose: \(dose.status.rawValue)."

        return ProtocolReplayEvent(
            timestamp: time,
            protocolDay: day,
            category: .dose,
            title: "\(dose.compoundName) Dose",
            subtitle: sub,
            detailText: dose.skippedReason ?? (dose.notes.isEmpty ? nil : dose.notes),
            badgeText: dose.status.rawValue,
            badgeColorHex: dose.status.badgeColorHex,
            iconName: dose.status.iconName,
            isHighlighted: dose.status == .missed,
            dosePayload: ReplayDosePayload(
                compoundId: dose.compoundId,
                compoundName: dose.compoundName,
                doseAmount: dose.doseAmount,
                doseUnit: dose.doseUnit,
                route: dose.administrationRoute,
                status: dose.status,
                injectionSiteId: dose.injectionSiteId,
                injectionSiteName: siteName,
                vialLotNumber: nil,
                notes: dose.notes.isEmpty ? nil : dose.notes,
                isPRN: dose.associatedProtocolId == nil && dose.protocolId == nil
            ),
            narrativeCommentary: commentary
        )
    }

    private func createMeasurementEvent(
        from m: Measurement,
        baselineMeasurement: Measurement?,
        protocolStartDate: Date,
        calendar: Calendar
    ) -> ProtocolReplayEvent {
        let day = calculateProtocolDay(date: m.dateRecorded, startDate: protocolStartDate, calendar: calendar)
        let isBaseline = m.dateRecorded <= protocolStartDate.addingTimeInterval(86400 * 2)

        var deltaFromBaseline: Double? = nil
        if let base = baselineMeasurement, base.id != m.id {
            deltaFromBaseline = m.value - base.value
        }

        var sub = m.formattedValue
        if let delta = deltaFromBaseline {
            let sign = delta > 0 ? "+" : ""
            let deltaStr = String(format: delta.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", delta)
            sub += " (\(sign)\(deltaStr) \(m.unit) from Day 1)"
        }

        let deltaComment = deltaFromBaseline.map { d in
            let sign = d > 0 ? "+" : ""
            let dStr = String(format: d.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", d)
            return " (\(sign)\(dStr) \(m.unit) vs baseline)"
        } ?? ""

        return ProtocolReplayEvent(
            timestamp: m.dateRecorded,
            protocolDay: day,
            category: .measurement,
            title: m.name,
            subtitle: sub,
            detailText: m.notes.isEmpty ? nil : m.notes,
            badgeText: isBaseline ? "Baseline" : (m.status == .inRange ? nil : m.status.rawValue),
            badgeColorHex: isBaseline ? "#6366F1" : m.status.colorHex,
            iconName: m.type.iconName,
            isHighlighted: m.status != .inRange,
            measurementPayload: ReplayMeasurementPayload(
                measurementId: m.id,
                name: m.name,
                type: m.type,
                category: m.category,
                value: m.value,
                secondaryValue: m.secondaryValue,
                unit: m.unit,
                deltaFromBaseline: deltaFromBaseline,
                deltaFromPrevious: nil,
                status: m.status,
                isBaseline: isBaseline,
                notes: m.notes.isEmpty ? nil : m.notes
            ),
            narrativeCommentary: "\(m.name) recorded at \(m.formattedValue)\(deltaComment)."
        )
    }

    private func createLabEvent(
        from lab: LabPanel,
        baselineResults: [String: LabResult],
        protocolStartDate: Date,
        calendar: Calendar
    ) -> ProtocolReplayEvent {
        let day = calculateProtocolDay(date: lab.collectionDate, startDate: protocolStartDate, calendar: calendar)
        let isBaseline = lab.collectionDate <= protocolStartDate.addingTimeInterval(86400 * 2)

        let analytes: [ReplayBiomarkerAnalyte] = lab.results.prefix(8).map { res in
            let base = baselineResults[res.biomarkerName]
            let delta = (base != nil && base!.id != res.id) ? (res.value - base!.value) : nil
            return ReplayBiomarkerAnalyte(
                id: res.id,
                name: res.biomarkerName,
                value: res.value,
                unit: res.unit,
                flag: res.flag,
                referenceRangeText: res.referenceRangeText,
                deltaFromBaseline: delta
            )
        }

        let abnormalCount = lab.abnormalResults.count
        let sub = isBaseline ?
            "\(lab.labName) • Baseline Diagnostic Panel (\(lab.resultCount) biomarkers)" :
            (abnormalCount == 0 ? "\(lab.labName) • All \(lab.resultCount) biomarkers optimal" : "\(lab.labName) • \(abnormalCount) out of range")

        return ProtocolReplayEvent(
            timestamp: lab.collectionDate,
            protocolDay: day,
            category: .labPanel,
            title: lab.panelName,
            subtitle: sub,
            detailText: lab.notes.isEmpty ? nil : lab.notes,
            badgeText: isBaseline ? "Baseline Lab" : lab.status.rawValue,
            badgeColorHex: isBaseline ? "#6366F1" : lab.status.badgeColorHex,
            iconName: "testtube.2",
            isHighlighted: lab.hasAbnormalResults,
            labPayload: ReplayLabPayload(
                panelId: lab.id,
                panelName: lab.panelName,
                labName: lab.labName,
                totalAnalytesCount: lab.resultCount,
                abnormalCount: abnormalCount,
                highlightedAnalytes: analytes,
                physicianNotes: lab.orderingPhysician,
                isBaselineDraw: isBaseline
            ),
            narrativeCommentary: isBaseline ?
                "Baseline diagnostic blood draw completed at \(lab.labName)." :
                "Follow-up blood panel: \(lab.resultCount) biomarkers evaluated (\(abnormalCount == 0 ? "all within optimal limits" : "\(abnormalCount) flagged"))."
        )
    }

    private func createSymptomEvent(from s: SymptomLog, protocolStartDate: Date, calendar: Calendar) -> ProtocolReplayEvent {
        let day = calculateProtocolDay(date: s.timestamp, startDate: protocolStartDate, calendar: calendar)
        var metricsParts: [String] = []
        if let e = s.energyLevel { metricsParts.append("Energy: \(e)/10") }
        if let sl = s.sleepQuality { metricsParts.append("Sleep: \(sl)/10") }
        if let rec = s.recoveryScore { metricsParts.append("Recovery: \(rec)/10") }
        if let p = s.painScore { metricsParts.append("Pain: \(p)/10") }

        return ProtocolReplayEvent(
            timestamp: s.timestamp,
            protocolDay: day,
            category: .symptom,
            title: "Symptom & Well-Being Log",
            subtitle: metricsParts.joined(separator: " • "),
            detailText: s.notes.isEmpty ? nil : s.notes,
            badgeText: "Subjective",
            badgeColorHex: "#EC4899",
            iconName: "heart.text.square.fill",
            isHighlighted: (s.painScore ?? 0) >= 6,
            symptomPayload: ReplaySymptomPayload(
                energyLevel: s.energyLevel,
                sleepQuality: s.sleepQuality,
                recoveryScore: s.recoveryScore,
                moodScore: s.moodScore,
                painScore: s.painScore,
                notes: s.notes.isEmpty ? nil : s.notes
            ),
            narrativeCommentary: "Subjective check-in: \(metricsParts.joined(separator: ", ")).\(s.notes.isEmpty ? "" : " Notes: \(s.notes)")"
        )
    }

    // MARK: - Sorting & Cumulative Computation

    private func sortChronologically(_ events: [ProtocolReplayEvent]) -> [ProtocolReplayEvent] {
        events.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp < rhs.timestamp
            }
            // Tie-break precedence
            return categoryPriority(lhs.category) < categoryPriority(rhs.category)
        }
    }

    private func categoryPriority(_ cat: ReplayEventCategory) -> Int {
        switch cat {
        case .milestone: return 0
        case .protocolRevision: return 1
        case .dose: return 2
        case .measurement: return 3
        case .labPanel: return 4
        case .symptom: return 5
        }
    }

    private func computeCumulativeStates(
        events: [ProtocolReplayEvent],
        protocolModel: ProtocolModel,
        calendar: Calendar
    ) -> [ProtocolReplayEvent] {
        var cumDoses: [String: Double] = [:]
        var cumUnits: [String: String] = [:]
        var totalAdministered = 0
        var totalScheduledOrLogged = 0
        var latestMeasurements: [String: Measurement] = [:]
        var latestBiomarkers: [String: LabResult] = [:]
        var activeCompounds: [ProtocolCompound] = protocolModel.items

        var updatedEvents: [ProtocolReplayEvent] = []

        for event in events {
            var mutableEvent = event
            let day = calculateProtocolDay(date: event.timestamp, startDate: protocolModel.startDate, calendar: calendar)
            mutableEvent.protocolDay = day

            // Update cumulative state components
            if let dose = event.dosePayload {
                totalScheduledOrLogged += 1
                if dose.status == .taken {
                    totalAdministered += 1
                    cumDoses[dose.compoundName, default: 0.0] += dose.doseAmount
                    cumUnits[dose.compoundName] = dose.doseUnit.rawValue
                }
            }

            if let rev = event.revisionPayload {
                // If revision contains compounds, update active compounds
                if !rev.doseAdjustments.isEmpty {
                    // Update active compound dose amounts
                    for adj in rev.doseAdjustments {
                        if let idx = activeCompounds.firstIndex(where: { $0.compoundName == adj.compoundName }) {
                            activeCompounds[idx].doseAmount = adj.newDose
                        }
                    }
                }
            }

            if let m = event.measurementPayload {
                let syntheticMeasurement = Measurement(
                    id: m.measurementId,
                    name: m.name,
                    type: m.type,
                    category: m.category,
                    value: m.value,
                    secondaryValue: m.secondaryValue,
                    unit: m.unit,
                    dateRecorded: event.timestamp,
                    associatedProtocolId: protocolModel.id
                )
                latestMeasurements[m.type.rawValue] = syntheticMeasurement
                latestMeasurements[m.name] = syntheticMeasurement
            }

            if let lab = event.labPayload {
                for analyte in lab.highlightedAnalytes {
                    let syntheticResult = LabResult(
                        id: analyte.id,
                        panelId: lab.panelId,
                        biomarkerName: analyte.name,
                        value: analyte.value,
                        unit: analyte.unit,
                        flag: analyte.flag
                    )
                    latestBiomarkers[analyte.name] = syntheticResult
                }
            }

            let adherence = totalScheduledOrLogged > 0 ? (Double(totalAdministered) / Double(totalScheduledOrLogged)) * 100.0 : nil
            let elapsedDays = max(0, calendar.dateComponents([.day], from: protocolModel.startDate, to: event.timestamp).day ?? 0)
            let totalDays = protocolModel.totalPlannedDays
            let progress = totalDays.map { min(100.0, max(0.0, (Double(elapsedDays) / Double($0)) * 100.0)) }

            let snapshot = ReplayCumulativeState(
                protocolDay: day,
                elapsedDays: elapsedDays,
                totalPlannedDays: totalDays,
                progressPercentage: progress,
                cumulativeDosesByCompound: cumDoses,
                cumulativeUnitsByCompound: cumUnits,
                totalDosesAdministered: totalAdministered,
                adherencePercentage: adherence,
                latestMeasurements: latestMeasurements,
                latestBiomarkers: latestBiomarkers,
                activeCompounds: activeCompounds
            )

            mutableEvent.cumulativeState = snapshot
            updatedEvents.append(mutableEvent)
        }

        return updatedEvents
    }

    // MARK: - Chapters Generation

    private func generateChapters(
        for events: [ProtocolReplayEvent],
        protocolModel: ProtocolModel
    ) -> [ReplayChapter] {
        var chapters: [ReplayChapter] = []

        for (idx, event) in events.enumerated() {
            // Milestone events
            if event.category == .milestone {
                chapters.append(
                    ReplayChapter(
                        eventIndex: idx,
                        title: event.title,
                        subtitle: "Day \(event.protocolDay)",
                        protocolDay: event.protocolDay,
                        timestamp: event.timestamp,
                        iconName: event.iconName,
                        colorHex: event.badgeColorHex
                    )
                )
                continue
            }

            // Protocol Revisions / Titrations
            if event.category == .protocolRevision {
                chapters.append(
                    ReplayChapter(
                        eventIndex: idx,
                        title: event.title,
                        subtitle: "Day \(event.protocolDay) Titration",
                        protocolDay: event.protocolDay,
                        timestamp: event.timestamp,
                        iconName: "arrow.triangle.swap",
                        colorHex: "#F59E0B"
                    )
                )
                continue
            }

            // Lab Diagnostic Draws
            if event.category == .labPanel {
                let isBase = event.labPayload?.isBaselineDraw == true
                chapters.append(
                    ReplayChapter(
                        eventIndex: idx,
                        title: isBase ? "Baseline Labs" : "Bloodwork Draw",
                        subtitle: event.title,
                        protocolDay: event.protocolDay,
                        timestamp: event.timestamp,
                        iconName: "testtube.2",
                        colorHex: "#10B981"
                    )
                )
                continue
            }

            // Week milestone marks (every 7 days if a dose or measurement occurs)
            if idx > 0 && event.protocolDay > 1 && event.protocolDay % 7 == 0 {
                let previousWasSameDay = events[idx - 1].protocolDay == event.protocolDay
                if !previousWasSameDay && !chapters.contains(where: { $0.protocolDay == event.protocolDay }) {
                    chapters.append(
                        ReplayChapter(
                            eventIndex: idx,
                            title: "Week \(event.protocolDay / 7) Checkpoint",
                            subtitle: "Day \(event.protocolDay)",
                            protocolDay: event.protocolDay,
                            timestamp: event.timestamp,
                            iconName: "calendar.badge.clock",
                            colorHex: "#06B6D4"
                        )
                    )
                }
            }
        }

        return chapters.sorted(by: { $0.eventIndex < $1.eventIndex })
    }

    // MARK: - Metric Summaries

    private func formatBaselineSummary(measurements: [String: Measurement], labResults: [String: LabResult]) -> [String: String] {
        var summary: [String: String] = [:]
        for (key, m) in measurements {
            summary[key] = m.formattedValue
        }
        for (key, lab) in labResults {
            summary[key] = lab.formattedValue
        }
        return summary
    }

    private func formatLatestSummary(from state: ReplayCumulativeState?) -> [String: String] {
        guard let s = state else { return [:] }
        var summary: [String: String] = [:]
        for (key, m) in s.latestMeasurements {
            summary[key] = m.formattedValue
        }
        for (key, lab) in s.latestBiomarkers {
            summary[key] = lab.formattedValue
        }
        return summary
    }

    private func calculateProtocolDay(date: Date, startDate: Date, calendar: Calendar) -> Int {
        if date < startDate {
            return 0 // Baseline
        }
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: date)).day ?? 0
        return max(1, diff + 1)
    }
}
