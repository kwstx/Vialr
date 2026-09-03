import Foundation
import Domain
import CalculationEngine
import Data

public typealias Measurement = Domain.Measurement

/// High-performance local-first analytics engine that synthesizes longitudinal patient data
/// into a structured clinical protocol report for medical professionals.
public struct ClinicianReportGenerator: Sendable {
    private let protocolRepo: ProtocolRepositoryProtocol
    private let doseRepo: DoseLogRepositoryProtocol
    private let biomarkerRepo: BiomarkerRepositoryProtocol
    private let labPanelRepo: LabPanelRepositoryProtocol
    private let measurementRepo: MeasurementRepositoryProtocol
    private let symptomRepo: SymptomRepositoryProtocol
    private let userRepo: UserRepositoryProtocol
    private let adherenceCalculator: AdherenceCalculator

    public init(
        protocolRepo: ProtocolRepositoryProtocol = LocalProtocolRepository(),
        doseRepo: DoseLogRepositoryProtocol = LocalDoseLogRepository(),
        biomarkerRepo: BiomarkerRepositoryProtocol = LocalBiomarkerRepository(),
        labPanelRepo: LabPanelRepositoryProtocol = LocalLabPanelRepository(),
        measurementRepo: MeasurementRepositoryProtocol = LocalMeasurementRepository(),
        symptomRepo: SymptomRepositoryProtocol = LocalSymptomRepository(),
        userRepo: UserRepositoryProtocol = LocalUserRepository(),
        adherenceCalculator: AdherenceCalculator = AdherenceCalculator()
    ) {
        self.protocolRepo = protocolRepo
        self.doseRepo = doseRepo
        self.biomarkerRepo = biomarkerRepo
        self.labPanelRepo = labPanelRepo
        self.measurementRepo = measurementRepo
        self.symptomRepo = symptomRepo
        self.userRepo = userRepo
        self.adherenceCalculator = adherenceCalculator
    }

    /// Generates a complete structured ClinicianReport using local-first storage repositories.
    public func generateReport(configuration: ClinicianReportConfiguration) async throws -> ClinicianReport {
        let interval = configuration.effectiveDateInterval
        let startDate = interval.start
        let endDate = interval.end

        // 1. Fetch User Profile
        let currentUser = try? await userRepo.fetchCurrentUser()
        let resolvedPatientName = configuration.patientName.isEmpty || configuration.patientName == "Patient / Self"
            ? (currentUser?.displayName ?? "Patient / Self-Managed")
            : configuration.patientName

        // 2. Protocols
        var activeProtocols: [ProtocolModel] = []
        var historicalProtocols: [ProtocolModel] = []

        if configuration.includeProtocols {
            let allProtocols = (try? await protocolRepo.fetchAll()) ?? []
            for proto in allProtocols {
                if proto.status == .active {
                    activeProtocols.append(proto)
                } else {
                    historicalProtocols.append(proto)
                }
            }
        }

        // 3. Doses in Date Range
        var doses: [DoseLog] = []
        if configuration.includeDoses {
            doses = (try? await doseRepo.fetchForDateRange(start: startDate, end: endDate)) ?? []
        }

        let adhReport = adherenceCalculator.calculateAdherence(logs: doses)
        let takenDoses = doses.filter { $0.status == .taken }
        let missedDoses = doses.filter { $0.status == .missed }
        let skippedDoses = doses.filter { $0.status == .skipped }

        // Compound Dose Summaries
        var compSummaries: [CompoundDoseSummary] = []
        var compGroups: [String: [DoseLog]] = [:]
        for d in takenDoses {
            compGroups[d.compoundName, default: []].append(d)
        }

        for (name, items) in compGroups {
            let total = items.reduce(0.0) { $0 + $1.doseAmount }
            let avg = items.isEmpty ? 0.0 : total / Double(items.count)
            let unit = items.first?.doseUnit ?? .mcg
            let route = items.first?.administrationRoute.rawValue ?? "Subcutaneous (SubQ)"
            let siteCounts = items.compactMap(\.injectionSite).reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
            let frequentSite = siteCounts.max(by: { $0.value < $1.value })?.key ?? "Abdomen (SubQ)"
            let compPct = adhReport.compoundBreakdown[name] ?? adhReport.overallPercentage

            compSummaries.append(
                CompoundDoseSummary(
                    compoundName: name,
                    totalDoseDelivered: total,
                    unit: unit,
                    averageDose: avg,
                    numberOfInjections: items.count,
                    mostFrequentSite: frequentSite,
                    route: route,
                    compliancePercentage: compPct
                )
            )
        }

        // 4. Lab Panels & Biomarkers
        var labPanelSummaries: [BiomarkerPanelSummary] = []
        var standaloneBiomarkers: [Biomarker] = []

        if configuration.includeLabs {
            let panels = (try? await labPanelRepo.fetchForDateRange(start: startDate, end: endDate)) ?? []
            for panel in panels {
                let results = panel.results.map { res in
                    let isAbnormal = res.flag != .inRange && res.flag != .optimal
                    return BiomarkerResultSummary(
                        id: res.id,
                        biomarkerName: res.biomarkerName,
                        category: res.category.rawValue,
                        value: res.value,
                        textValue: res.textValue,
                        unit: res.unit,
                        referenceRangeMin: res.referenceRangeMin,
                        referenceRangeMax: res.referenceRangeMax,
                        referenceRangeText: res.referenceRangeText,
                        flag: res.flag.rawValue,
                        isAbnormal: isAbnormal
                    )
                }

                labPanelSummaries.append(
                    BiomarkerPanelSummary(
                        panelId: panel.id,
                        panelName: panel.panelName,
                        labName: panel.labName,
                        collectionDate: panel.collectionDate,
                        notes: panel.notes,
                        results: results
                    )
                )
            }

            standaloneBiomarkers = (try? await biomarkerRepo.fetchForDateRange(start: startDate, end: endDate)) ?? []
        }

        // 5. Measurements & Vitals
        var measurementSummaries: [MeasurementMetricSummary] = []
        var rawMeasurements: [Measurement] = []

        if configuration.includeMeasurements {
            rawMeasurements = (try? await measurementRepo.fetchForDateRange(start: startDate, end: endDate)) ?? []
            var metricGroups: [String: [Measurement]] = [:]
            for m in rawMeasurements {
                metricGroups[m.name, default: []].append(m)
            }

            for (name, items) in metricGroups {
                let sortedItems = items.sorted(by: { $0.dateRecorded < $1.dateRecorded })
                guard let latest = sortedItems.last else { continue }
                let values = sortedItems.map(\.value)
                let avg = values.reduce(0.0, +) / Double(values.count)
                let minVal = values.min()
                let maxVal = values.max()

                measurementSummaries.append(
                    MeasurementMetricSummary(
                        category: latest.category.rawValue,
                        metricName: name,
                        latestValue: latest.value,
                        formattedValue: latest.formattedValue,
                        unit: latest.unit,
                        status: latest.status.rawValue,
                        dateRecorded: latest.dateRecorded,
                        entryCount: sortedItems.count,
                        minValue: minVal,
                        maxValue: maxVal,
                        averageValue: avg,
                        referenceRangeText: latest.referenceRangeMin != nil && latest.referenceRangeMax != nil
                            ? "\(latest.referenceRangeMin!) – \(latest.referenceRangeMax!) \(latest.unit)"
                            : nil
                    )
                )
            }
        }

        // 6. Symptoms & Quality of Life
        var symptomSummary: SymptomQualitySummary? = nil
        var rawSymptoms: [SymptomLog] = []

        if configuration.includeSymptoms {
            let allSymptoms = (try? await symptomRepo.fetchAll()) ?? []
            rawSymptoms = allSymptoms.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }

            if !rawSymptoms.isEmpty {
                let energies = rawSymptoms.map { Double($0.energyLevel) }
                let sleeps = rawSymptoms.map { Double($0.sleepQuality) }
                let recoveries = rawSymptoms.map { Double($0.recoveryScore) }
                let moods = rawSymptoms.map { Double($0.moodScore) }
                let pains = rawSymptoms.compactMap { $0.painScore.map(Double.init) }

                let avgEnergy = energies.reduce(0.0, +) / Double(energies.count)
                let avgSleep = sleeps.reduce(0.0, +) / Double(sleeps.count)
                let avgRecovery = recoveries.reduce(0.0, +) / Double(recoveries.count)
                let avgMood = moods.reduce(0.0, +) / Double(moods.count)
                let avgPain = pains.isEmpty ? nil : pains.reduce(0.0, +) / Double(pains.count)
                let avgWellbeing = rawSymptoms.map(\.overallWellbeingScore).reduce(0.0, +) / Double(rawSymptoms.count)

                let sideEffects = Array(Set(rawSymptoms.flatMap(\.sideEffects)))
                let notes = rawSymptoms.map(\.notes).filter { !$0.isEmpty }

                symptomSummary = SymptomQualitySummary(
                    averageEnergy: avgEnergy,
                    averageSleepQuality: avgSleep,
                    averageRecovery: avgRecovery,
                    averageMood: avgMood,
                    averagePain: avgPain,
                    averageWellbeingScore: avgWellbeing,
                    totalLogsCount: rawSymptoms.count,
                    reportedSideEffects: sideEffects,
                    frequentNotes: notes
                )
            }
        }

        // 7. Unified Chronological Clinical Ledger
        var ledger: [ClinicianLedgerItem] = []

        // Doses
        for d in doses {
            let isTaken = d.status == .taken
            let isSkipped = d.status == .skipped
            let amtStr = String(format: d.doseAmount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", d.doseAmount)
            let cat: ClinicianLedgerCategory = isTaken ? .doseAdministered : (isSkipped ? .doseSkipped : .doseMissed)

            ledger.append(
                ClinicianLedgerItem(
                    id: d.id,
                    timestamp: d.loggedDate ?? d.scheduledDate,
                    category: cat,
                    title: "\(d.compoundName) Dose",
                    subtitle: isTaken
                        ? "\(amtStr) \(d.doseUnit.rawValue) • \(d.injectionSite ?? "SubQ")"
                        : (isSkipped ? "Skipped (\(d.skippedReason ?? "User paused"))" : "Missed scheduled dose"),
                    detail: d.notes.isEmpty ? nil : d.notes,
                    metricsSummary: "\(amtStr) \(d.doseUnit.rawValue)",
                    statusOrFlag: isTaken ? "Delivered" : d.status.rawValue.capitalized,
                    statusColorHex: cat.defaultColorHex,
                    associatedProtocolName: d.compoundName,
                    isHighlighted: !isTaken
                )
            )
        }

        // Protocol Transitions
        for proto in activeProtocols + historicalProtocols {
            if proto.startDate >= startDate && proto.startDate <= endDate {
                let compDesc = proto.compounds.map { "\($0.compoundName) \($0.dosageAmount)\($0.unit.rawValue)" }.joined(separator: " + ")
                ledger.append(
                    ClinicianLedgerItem(
                        id: UUID(),
                        timestamp: proto.startDate,
                        category: .protocolStart,
                        title: "Protocol Initiated: \(proto.name)",
                        subtitle: compDesc.isEmpty ? proto.name : compDesc,
                        detail: proto.notes.isEmpty ? nil : proto.notes,
                        metricsSummary: "\(proto.cycleDurationWeeks) wks",
                        statusOrFlag: "Active",
                        statusColorHex: ClinicianLedgerCategory.protocolStart.defaultColorHex,
                        associatedProtocolName: proto.name,
                        isHighlighted: true
                    )
                )
            }
            if let end = proto.endDate, end >= startDate && end <= endDate {
                ledger.append(
                    ClinicianLedgerItem(
                        id: UUID(),
                        timestamp: end,
                        category: .protocolEnd,
                        title: "Protocol Concluded: \(proto.name)",
                        subtitle: "Planned duration completed",
                        detail: proto.goalSummary.isEmpty ? nil : proto.goalSummary,
                        metricsSummary: "Completed",
                        statusOrFlag: "Concluded",
                        statusColorHex: ClinicianLedgerCategory.protocolEnd.defaultColorHex,
                        associatedProtocolName: proto.name,
                        isHighlighted: true
                    )
                )
            }
        }

        // Labs
        for panel in labPanelSummaries {
            let abnormalCount = panel.results.filter(\.isAbnormal).count
            ledger.append(
                ClinicianLedgerItem(
                    id: panel.panelId,
                    timestamp: panel.collectionDate,
                    category: .labDiagnostic,
                    title: "\(panel.labName): \(panel.panelName)",
                    subtitle: "\(panel.results.count) analytes measured • \(abnormalCount) out of reference range",
                    detail: panel.notes.isEmpty ? nil : panel.notes,
                    metricsSummary: "\(panel.results.count) Analytes",
                    statusOrFlag: abnormalCount > 0 ? "\(abnormalCount) Flags" : "Optimal",
                    statusColorHex: abnormalCount > 0 ? "#EF4444" : "#10B981",
                    associatedProtocolName: nil,
                    isHighlighted: abnormalCount > 0
                )
            )
        }

        // Measurements
        for m in rawMeasurements {
            ledger.append(
                ClinicianLedgerItem(
                    id: m.id,
                    timestamp: m.dateRecorded,
                    category: .vitalMeasurement,
                    title: m.name,
                    subtitle: "\(m.formattedValue) [\(m.category.rawValue)]",
                    detail: m.notes.isEmpty ? nil : m.notes,
                    metricsSummary: m.formattedValue,
                    statusOrFlag: m.status.rawValue,
                    statusColorHex: m.status.colorHex,
                    associatedProtocolName: nil,
                    isHighlighted: m.status != .inRange
                )
            )
        }

        // Symptoms
        for sym in rawSymptoms {
            ledger.append(
                ClinicianLedgerItem(
                    id: sym.id,
                    timestamp: sym.timestamp,
                    category: .symptomLog,
                    title: "Symptom Check-in: Recovery \(sym.recoveryScore)/10",
                    subtitle: "Energy: \(sym.energyLevel)/10, Sleep: \(sym.sleepQuality)/10, Mood: \(sym.moodScore)/10",
                    detail: sym.notes.isEmpty ? (sym.sideEffects.isEmpty ? nil : "Reported side effects: \(sym.sideEffects.joined(separator: ", "))") : sym.notes,
                    metricsSummary: "\(Int(sym.overallWellbeingScore))/100",
                    statusOrFlag: sym.overallWellbeingScore >= 70 ? "Good" : "Sub-optimal",
                    statusColorHex: sym.overallWellbeingScore >= 70 ? "#10B981" : "#F59E0B",
                    associatedProtocolName: nil,
                    isHighlighted: sym.overallWellbeingScore < 60
                )
            )
        }

        // Sort ledger strictly chronologically
        ledger.sort(by: { $0.timestamp < $1.timestamp })

        // 8. Construct Summary Text
        let activeNames = activeProtocols.map(\.name).joined(separator: ", ")
        let summaryText = "Longitudinal clinician summary for \(resolvedPatientName) covering \(startDate.formatted(date: .abbreviated, time: .omitted)) to \(endDate.formatted(date: .abbreviated, time: .omitted)). Active protocols (\(activeProtocols.count)): \(activeNames.isEmpty ? "None Active" : activeNames). Protocol adherence: \(Int(adhReport.overallPercentage))% across \(doses.count) scheduled doses (\(takenDoses.count) taken, \(missedDoses.count) missed). Recorded \(labPanelSummaries.count) laboratory panels, \(measurementSummaries.count) biometric metrics, and \(rawSymptoms.count) subjective symptom check-ins."

        return ClinicianReport(
            id: UUID(),
            patientIdentifier: resolvedPatientName,
            patientDateOfBirth: configuration.patientDateOfBirth.isEmpty ? nil : configuration.patientDateOfBirth,
            clinicianName: configuration.clinicianName,
            practiceOrClinic: configuration.practiceOrClinic,
            generatedDate: Date(),
            dateRangeStart: startDate,
            dateRangeEnd: endDate,
            activeProtocols: activeProtocols,
            historicalProtocols: historicalProtocols,
            doseSummary: compSummaries,
            adherencePercentage: adhReport.overallPercentage,
            totalDosesScheduled: doses.count,
            totalDosesAdministered: takenDoses.count,
            totalDosesMissed: missedDoses.count,
            totalDosesSkipped: skippedDoses.count,
            latestBiomarkers: standaloneBiomarkers,
            labPanels: labPanelSummaries,
            measurementSummaries: measurementSummaries,
            symptomSummary: symptomSummary,
            chronologicalLedger: ledger,
            subjectiveTrendsSummary: symptomSummary != nil ? "Composite wellbeing score: \(Int(symptomSummary!.averageWellbeingScore))/100 across \(rawSymptoms.count) subjective observations." : "No adverse subjective trends logged.",
            clinicalNotes: summaryText,
            patientObservations: configuration.patientNotes
        )
    }
}
