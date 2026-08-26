import Foundation
import Domain

/// High-performance, thread-safe scheduling engine for protocols and stacks.
/// Converts protocol recurrence rules into individual expected dose occurrences dynamically across
/// requested calendar windows without persisting an infinite number of database records.
public struct ProtocolSchedulingEngine: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public init(timeZone: TimeZone) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        self.calendar = cal
    }


    // MARK: - Occurrence Generation Across Date Range
    /// Generates expected dose occurrences for a single protocol over a given date range.
    public func generateOccurrences(
        for protocolModel: ProtocolModel,
        in dateRange: ClosedRange<Date>,
        loggedEvents: [DoseEvent] = []
    ) -> [ExpectedDoseOccurrence] {
        guard protocolModel.status == .active || protocolModel.status == .paused else {
            return []
        }

        var occurrences: [ExpectedDoseOccurrence] = []
        let rangeStartDay = calendar.startOfDay(for: dateRange.lowerBound)
        let rangeEndDay = calendar.startOfDay(for: dateRange.upperBound)

        // Protocol bounds
        let protoStartDay = calendar.startOfDay(for: protocolModel.startDate)
        let protoEndDay = protocolModel.endDate.map { calendar.startOfDay(for: $0) }

        // Iterate calendar days
        var currentDay = rangeStartDay
        while currentDay <= rangeEndDay {
            // Check protocol level date boundary
            if currentDay >= protoStartDay && (protoEndDay == nil || currentDay <= protoEndDay!) {
                for compound in protocolModel.compounds where compound.isActive {
                    // Check compound level date boundary
                    let compStartDay = compound.startDate.map { calendar.startOfDay(for: $0) } ?? protoStartDay
                    let compEndDay = compound.endDate.map { calendar.startOfDay(for: $0) } ?? protoEndDay

                    if currentDay >= compStartDay && (compEndDay == nil || currentDay <= (compEndDay ?? Date.distantFuture)) {
                        if compound.isScheduled(on: currentDay, protocolStart: protocolModel.startDate) {
                            let dayOccurrences = createOccurrencesForDay(
                                protocolModel: protocolModel,
                                compound: compound,
                                day: currentDay,
                                loggedEvents: loggedEvents
                            )
                            occurrences.append(contentsOf: dayOccurrences)
                        }
                    }
                }
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }

        return occurrences.sorted { $0.scheduledTimestamp < $1.scheduledTimestamp }
    }

    /// Generates expected dose occurrences across multiple protocols over a given date range.
    public func generateOccurrences(
        for protocols: [ProtocolModel],
        in dateRange: ClosedRange<Date>,
        loggedEvents: [DoseEvent] = []
    ) -> [ExpectedDoseOccurrence] {
        protocols.flatMap { proto in
            generateOccurrences(for: proto, in: dateRange, loggedEvents: loggedEvents)
        }.sorted { $0.scheduledTimestamp < $1.scheduledTimestamp }
    }

    /// Generates today's occurrences for all active protocols.
    public func occurrencesForDate(
        _ targetDate: Date,
        protocols: [ProtocolModel],
        loggedEvents: [DoseEvent] = []
    ) -> [ExpectedDoseOccurrence] {
        let startOfDay = calendar.startOfDay(for: targetDate)
        guard let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: targetDate) else {
            return []
        }
        return generateOccurrences(for: protocols, in: startOfDay...endOfDay, loggedEvents: loggedEvents)
    }

    /// Generates the next N upcoming occurrences from a reference date.
    public func upcomingOccurrences(
        for protocols: [ProtocolModel],
        limit: Int = 10,
        from referenceDate: Date = Date(),
        horizonDays: Int = 60,
        loggedEvents: [DoseEvent] = []
    ) -> [ExpectedDoseOccurrence] {
        let startDate = calendar.startOfDay(for: referenceDate)
        guard let endDate = calendar.date(byAdding: .day, value: horizonDays, to: startDate) else {
            return []
        }

        let all = generateOccurrences(for: protocols, in: startDate...endDate, loggedEvents: loggedEvents)
        let filtered = all.filter { $0.scheduledTimestamp >= referenceDate || ($0.isToday && !$0.isTaken) }
        return Array(filtered.prefix(limit))
    }

    /// Returns the immediate next expected occurrence for a specific protocol or compound.
    public func nextExpectedOccurrence(
        for protocolModel: ProtocolModel,
        compoundId: UUID? = nil,
        from referenceDate: Date = Date(),
        loggedEvents: [DoseEvent] = []
    ) -> ExpectedDoseOccurrence? {
        let upcoming = upcomingOccurrences(for: [protocolModel], limit: 20, from: referenceDate, loggedEvents: loggedEvents)
        if let targetCompoundId = compoundId {
            return upcoming.first { $0.compoundId == targetCompoundId && !$0.isTaken }
        }
        return upcoming.first { !$0.isTaken }
    }

    // MARK: - Internal Day Occurrence Factory
    private func createOccurrencesForDay(
        protocolModel: ProtocolModel,
        compound: ProtocolCompound,
        day: Date,
        loggedEvents: [DoseEvent]
    ) -> [ExpectedDoseOccurrence] {
        let effectiveDose = compound.effectiveDoseAmount(on: day, relativeTo: protocolModel.startDate)
        let timesCount = max(1, compound.timesPerDay)
        var occurrences: [ExpectedDoseOccurrence] = []

        for index in 0..<timesCount {
            let scheduledTime = computeScheduledTime(
                forDay: day,
                timeSlotIndex: index,
                totalTimes: timesCount,
                preferredTime: compound.preferredTimeOfDay,
                reminderTime: compound.reminderTime
            )

            // Deterministic UUID based on protocol + compound + day + slot index
            let deterministicId = generateOccurrenceId(
                protocolId: protocolModel.id,
                compoundId: compound.compoundId,
                timestamp: scheduledTime,
                slot: index
            )

            // Check if ground-truth DoseEvent exists
            let matchingLog = findMatchingDoseEvent(
                protocolId: protocolModel.id,
                compoundId: compound.compoundId,
                scheduledTime: scheduledTime,
                in: loggedEvents
            )

            let status: DoseEventStatus
            if let log = matchingLog {
                status = log.status
            } else if scheduledTime < Date().addingTimeInterval(-3600 * 2) {
                // More than 2 hours in the past and not logged -> Missed or Scheduled
                status = .scheduled
            } else {
                status = .scheduled
            }

            let occurrence = ExpectedDoseOccurrence(
                id: deterministicId,
                protocolId: protocolModel.id,
                protocolName: protocolModel.name,
                protocolCompoundId: compound.id,
                compoundId: compound.compoundId,
                compoundName: compound.compoundName,
                scheduledTimestamp: scheduledTime,
                plannedDoseAmount: effectiveDose,
                doseUnit: compound.doseUnit,
                route: compound.route,
                preferredTimeOfDay: compound.preferredTimeOfDay,
                foodRequirement: compound.foodRequirement,
                reminderTime: compound.reminderTime,
                reminderEnabled: compound.reminderEnabled,
                reminderLeadTimeMinutes: compound.reminderLeadTimeMinutes,
                attachedVialId: compound.attachedVialId,
                status: status,
                associatedDoseLogId: matchingLog?.id,
                actualTimestamp: matchingLog?.actualTimestamp,
                actualDoseAmount: matchingLog?.actualDoseAmount,
                injectionSiteName: matchingLog?.injectionSiteName,
                notes: compound.notes
            )

            occurrences.append(occurrence)
        }

        return occurrences
    }

    // MARK: - Time Calculations
    private func computeScheduledTime(
        forDay day: Date,
        timeSlotIndex: Int,
        totalTimes: Int,
        preferredTime: TimeOfDay,
        reminderTime: Date?
    ) -> Date {
        var hour = 8
        var minute = 0

        if let customReminder = reminderTime {
            hour = calendar.component(.hour, from: customReminder)
            minute = calendar.component(.minute, from: customReminder)
        } else {
            switch preferredTime {
            case .morning:
                hour = 8
                minute = 0
            case .preWorkout:
                hour = 11
                minute = 30
            case .postWorkout:
                hour = 13
                minute = 30
            case .afternoon:
                hour = 15
                minute = 0
            case .evening:
                hour = 21
                minute = 0
            case .custom:
                hour = 9
                minute = 0
            }
        }

        // Space out multiple times per day (e.g. 2x -> morning + evening)
        if totalTimes > 1 && timeSlotIndex > 0 {
            let offsetHours = (12 / max(1, totalTimes - 1)) * timeSlotIndex
            hour = min(23, hour + offsetHours)
        }

        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    // MARK: - Ground-Truth Event Matching
    private func findMatchingDoseEvent(
        protocolId: UUID,
        compoundId: UUID,
        scheduledTime: Date,
        in loggedEvents: [DoseEvent]
    ) -> DoseEvent? {
        let dayStart = calendar.startOfDay(for: scheduledTime)
        guard let dayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: scheduledTime) else {
            return nil
        }

        return loggedEvents.first { event in
            guard event.compoundId == compoundId else { return false }
            if let eventProtoId = event.protocolId, eventProtoId != protocolId { return false }

            let eventDate = event.actualTimestamp ?? event.scheduledTimestamp
            return eventDate >= dayStart && eventDate <= dayEnd
        }
    }

    // MARK: - Deterministic ID Generator
    private func generateOccurrenceId(
        protocolId: UUID,
        compoundId: UUID,
        timestamp: Date,
        slot: Int
    ) -> UUID {
        let timeKey = Int(timestamp.timeIntervalSince1970)
        let rawString = "\(protocolId.uuidString)_\(compoundId.uuidString)_\(timeKey)_\(slot)"
        var hash = 5381
        for byte in rawString.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        
        let pBytes = protocolId.uuidString.replacingOccurrences(of: "-", with: "")
        let prefix = String(pBytes.prefix(16))
        let suffix = String(format: "%016llx", UInt64(bitPattern: Int64(hash)))
        let formatted = "\(prefix.prefix(8))-\(prefix.dropFirst(8).prefix(4))-4\(prefix.dropFirst(12).prefix(3))-a\(suffix.prefix(3))-\(suffix.dropFirst(4).prefix(12))"
        return UUID(uuidString: formatted) ?? UUID()
    }

    // MARK: - Vial Depletion Forecast
    /// Forecasts the exact date an attached vial will be depleted based on the protocol's planned recurrence.
    public func calculateVialDepletion(
        vial: Vial,
        protocolModel: ProtocolModel,
        compound: ProtocolCompound,
        from startDate: Date = Date()
    ) -> VialDepletionProjection {
        guard let remVolume = vial.currentVolumeRemainingMl, remVolume > 0,
              let conc = vial.concentrationMgMl, conc > 0 else {
            // Dry vial fallback using dry mass
            let doseMg = (compound.doseUnit == .mg) ? compound.doseAmount : (compound.doseAmount / 1000.0)
            guard doseMg > 0 else {
                return VialDepletionProjection(totalPlannedDosesRemaining: 0, projectedDepletionDate: nil, daysRemaining: 0, isDepleted: true, summary: "No valid dose amount")
            }
            let doses = Int(vial.totalDryMassMg / doseMg)
            return VialDepletionProjection(
                totalPlannedDosesRemaining: doses,
                projectedDepletionDate: nil,
                daysRemaining: nil,
                isDepleted: false,
                summary: "Unreconstituted dry vial (\(doses) doses capacity)"
            )
        }

        guard let drawMl = vial.drawVolumeMl(for: compound.doseAmount, unit: compound.doseUnit), drawMl > 0 else {
            return VialDepletionProjection(totalPlannedDosesRemaining: 0, projectedDepletionDate: nil, daysRemaining: 0, isDepleted: true, summary: "Invalid concentration calculation")
        }

        let totalDosesRemaining = Int(remVolume / drawMl)
        guard totalDosesRemaining > 0 else {
            return VialDepletionProjection(totalPlannedDosesRemaining: 0, projectedDepletionDate: startDate, daysRemaining: 0, isDepleted: true, summary: "Vial depleted")
        }

        // Project upcoming occurrences until doses are exhausted
        let horizon = max(180, totalDosesRemaining * 7)
        guard let endDate = calendar.date(byAdding: .day, value: horizon, to: startDate) else {
            return VialDepletionProjection(totalPlannedDosesRemaining: totalDosesRemaining, projectedDepletionDate: nil, daysRemaining: nil, isDepleted: false, summary: "\(totalDosesRemaining) doses remaining")
        }

        let occurrences = generateOccurrences(for: protocolModel, in: startDate...endDate)
            .filter { $0.compoundId == compound.compoundId && $0.scheduledTimestamp >= startDate }

        if occurrences.count >= totalDosesRemaining {
            let depletionOccurrence = occurrences[totalDosesRemaining - 1]
            let days = calendar.dateComponents([.day], from: startDate, to: depletionOccurrence.scheduledTimestamp).day ?? 0
            return VialDepletionProjection(
                totalPlannedDosesRemaining: totalDosesRemaining,
                projectedDepletionDate: depletionOccurrence.scheduledTimestamp,
                daysRemaining: max(1, days),
                isDepleted: false,
                summary: "Estimated \(totalDosesRemaining) doses remaining (\(max(1, days)) days)"
            )
        } else {
            return VialDepletionProjection(
                totalPlannedDosesRemaining: totalDosesRemaining,
                projectedDepletionDate: nil,
                daysRemaining: nil,
                isDepleted: false,
                summary: "Sufficient supply for current scheduled cycle (\(totalDosesRemaining) doses left)"
            )
        }
    }

    // MARK: - Adherence Analytics Projection
    /// Computes overall adherence and compliance projections across a date range.
    public func calculateProjectedAdherence(
        protocols: [ProtocolModel],
        loggedEvents: [DoseEvent],
        dateRange: ClosedRange<Date>
    ) -> ProtocolAdherenceProjection {
        let occurrences = generateOccurrences(for: protocols, in: dateRange, loggedEvents: loggedEvents)
        let totalExpected = occurrences.count
        let totalTaken = occurrences.filter { $0.isTaken }.count
        let totalMissed = occurrences.filter { $0.status == .missed }.count
        let totalScheduled = occurrences.filter { $0.status == .scheduled }.count

        let rate = totalExpected > 0 ? (Double(totalTaken) / Double(totalExpected)) * 100.0 : 100.0

        return ProtocolAdherenceProjection(
            totalExpectedDoses: totalExpected,
            totalTakenDoses: totalTaken,
            totalMissedDoses: totalMissed,
            totalPendingDoses: totalScheduled,
            adherencePercentage: rate
        )
    }
}

// MARK: - Supporting Analytics Models
public struct VialDepletionProjection: Sendable, Hashable {
    public let totalPlannedDosesRemaining: Int
    public let projectedDepletionDate: Date?
    public let daysRemaining: Int?
    public let isDepleted: Bool
    public let summary: String

    public init(
        totalPlannedDosesRemaining: Int,
        projectedDepletionDate: Date?,
        daysRemaining: Int?,
        isDepleted: Bool,
        summary: String
    ) {
        self.totalPlannedDosesRemaining = totalPlannedDosesRemaining
        self.projectedDepletionDate = projectedDepletionDate
        self.daysRemaining = daysRemaining
        self.isDepleted = isDepleted
        self.summary = summary
    }
}

public struct ProtocolAdherenceProjection: Sendable, Hashable {
    public let totalExpectedDoses: Int
    public let totalTakenDoses: Int
    public let totalMissedDoses: Int
    public let totalPendingDoses: Int
    public let adherencePercentage: Double

    public init(
        totalExpectedDoses: Int,
        totalTakenDoses: Int,
        totalMissedDoses: Int,
        totalPendingDoses: Int,
        adherencePercentage: Double
    ) {
        self.totalExpectedDoses = totalExpectedDoses
        self.totalTakenDoses = totalTakenDoses
        self.totalMissedDoses = totalMissedDoses
        self.totalPendingDoses = totalPendingDoses
        self.adherencePercentage = adherencePercentage
    }
}
