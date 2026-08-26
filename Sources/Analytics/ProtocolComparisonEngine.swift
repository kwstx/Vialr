import Foundation
import Domain
import CalculationEngine

/// Sophisticated time-series comparison engine for protocol and date range analytics.
///
/// Features:
/// 1. Slices and analyzes longitudinal time-series across two date ranges or protocols.
/// 2. Calculates rigorous descriptive statistics (mean, median, variance, std dev, IQR, velocities, effect sizes).
/// 3. Compares weight, physical measurements, adherence, symptom scores, lab biomarkers, financial costs, and custom metrics.
/// 4. Strictly separates empirical `ObservedChange` (factual numbers) from `ComparisonInterpretation` (observational narrative).
/// 5. Strictly avoids presenting observational correlations as proof of causation by integrating explicit non-causality frameworks and confounder discovery.
public struct ProtocolComparisonEngine: Sendable {

    public init() {}

    // MARK: - 1. Core Descriptive Statistics

    /// Computes full descriptive statistics for any time-series data points within an observation period.
    public func computeDescriptiveStatistics<P: TimeSeriesDataPoint>(
        points: [P],
        periodStart: Date,
        periodEnd: Date
    ) -> DescriptiveStatistics {
        let inWindow = points
            .filter { $0.timestamp >= periodStart && $0.timestamp <= periodEnd }
            .sorted(by: { $0.timestamp < $1.timestamp })

        let durationSeconds = max(86400.0, periodEnd.timeIntervalSince(periodStart))
        let durationDays = max(1, Int(ceil(durationSeconds / 86400.0)))
        let durationWeeks = Double(durationDays) / 7.0

        guard !inWindow.isEmpty else {
            return DescriptiveStatistics(
                sampleCount: 0,
                startDate: periodStart,
                endDate: periodEnd,
                durationDays: durationDays,
                firstValue: 0.0,
                lastValue: 0.0,
                minValue: 0.0,
                maxValue: 0.0,
                meanValue: 0.0,
                medianValue: 0.0,
                standardDeviation: 0.0,
                variance: 0.0,
                q1: 0.0,
                q3: 0.0,
                iqr: 0.0,
                netChange: 0.0,
                percentageChange: 0.0,
                ratePerDay: 0.0,
                weeklyVelocity: 0.0,
                loggingFrequencyPerWeek: 0.0
            )
        }

        let first = inWindow.first!
        let last = inWindow.last!
        let values = inWindow.map(\.value)
        let count = values.count

        // Mean
        let sum = values.reduce(0.0, +)
        let mean = sum / Double(count)

        // Sorted for quantiles and median
        let sortedValues = values.sorted()
        let median: Double
        if count % 2 == 0 {
            median = (sortedValues[count / 2 - 1] + sortedValues[count / 2]) / 2.0
        } else {
            median = sortedValues[count / 2]
        }

        // Q1 and Q3
        let q1 = quantile(sortedValues, p: 0.25)
        let q3 = quantile(sortedValues, p: 0.75)
        let iqr = q3 - q1

        // Min, Max
        let minVal = sortedValues.first ?? 0.0
        let maxVal = sortedValues.last ?? 0.0

        // Variance & Standard Deviation (Bessel's correction N-1)
        var variance = 0.0
        var stdDev = 0.0
        if count > 1 {
            let sumSq = values.reduce(0.0) { $0 + pow($1 - mean, 2) }
            variance = sumSq / Double(count - 1)
            stdDev = sqrt(max(0.0, variance))
        }

        // Net Change & Percentage Change
        let net = last.value - first.value
        let pct = first.value != 0 ? ((net / abs(first.value)) * 100.0) : 0.0

        // Velocity
        let ratePerDay = net / Double(durationDays)
        let weeklyVelocity = durationWeeks > 0 ? (net / durationWeeks) : 0.0
        let logFreq = (Double(count) / Double(durationDays)) * 7.0

        return DescriptiveStatistics(
            sampleCount: count,
            startDate: first.timestamp,
            endDate: last.timestamp,
            durationDays: durationDays,
            firstValue: first.value,
            lastValue: last.value,
            minValue: minVal,
            maxValue: maxVal,
            meanValue: mean,
            medianValue: median,
            standardDeviation: stdDev,
            variance: variance,
            q1: q1,
            q3: q3,
            iqr: iqr,
            netChange: net,
            percentageChange: pct,
            ratePerDay: ratePerDay,
            weeklyVelocity: weeklyVelocity,
            loggingFrequencyPerWeek: logFreq
        )
    }

    // MARK: - 2. Generic Time-Series Comparator

    /// Compares two time-series datasets over respective periods, cleanly separating observed empirical change from qualitative interpretation.
    public func compareTimeSeries<P: TimeSeriesDataPoint>(
        seriesA: [P],
        seriesB: [P],
        rangeA: DateInterval,
        rangeB: DateInterval,
        metric: MetricDefinition,
        nameA: String = "Period A",
        nameB: String = "Period B",
        compoundNamesA: [String] = [],
        compoundNamesB: [String] = []
    ) -> MetricComparisonResult {
        let statsA = computeDescriptiveStatistics(points: seriesA, periodStart: rangeA.start, periodEnd: rangeA.end)
        let statsB = computeDescriptiveStatistics(points: seriesB, periodStart: rangeB.start, periodEnd: rangeB.end)

        // 1. Calculate Empirical Observed Change (Strict Math Only)
        let meanDiff = statsB.meanValue - statsA.meanValue
        let meanPctDiff = statsA.meanValue != 0 ? ((meanDiff / abs(statsA.meanValue)) * 100.0) : 0.0
        let netDiff = statsB.netChange - statsA.netChange
        let velDiff = statsB.weeklyVelocity - statsA.weeklyVelocity

        // Standardized Effect Size: Cohen's d
        var cohenD: Double? = nil
        let nA = Double(statsA.sampleCount)
        let nB = Double(statsB.sampleCount)
        if nA > 1 && nB > 1 {
            let pooledVar = (((nA - 1.0) * statsA.variance) + ((nB - 1.0) * statsB.variance)) / (nA + nB - 2.0)
            let pooledSD = sqrt(max(0.00001, pooledVar))
            if pooledSD > 0.0001 {
                cohenD = abs(meanDiff) / pooledSD
            }
        }

        // Welch's Two-Sample t-statistic
        var tStat: Double? = nil
        var approxP: Double? = nil
        if statsA.sampleCount >= 2 && statsB.sampleCount >= 2 {
            let seA = statsA.variance / nA
            let seB = statsB.variance / nB
            let standardError = sqrt(seA + seB)
            if standardError > 0.0001 {
                let t = (statsB.meanValue - statsA.meanValue) / standardError
                tStat = t
                // Approximate two-tailed p-value via normal approximation
                approxP = 2.0 * (1.0 - normalCDF(abs(t)))
            }
        }

        // Variance Ratio (F-Ratio)
        var fRatio: Double? = nil
        if statsA.variance > 0.0001 && statsB.variance > 0.0001 {
            fRatio = statsB.variance / statsA.variance
        }

        let observedChange = ObservedChange(
            metricCode: metric.code,
            metricName: metric.name,
            unit: metric.defaultUnit,
            periodAStats: statsA,
            periodBStats: statsB,
            meanDifference: meanDiff,
            meanPercentageDifference: meanPctDiff,
            netChangeDifference: netDiff,
            velocityDifferencePerWeek: velDiff,
            cohensDEffectSize: cohenD,
            tStatistic: tStat,
            approximatePValue: approxP,
            varianceRatio: fRatio
        )

        // 2. Generate Qualitative Interpretation (Explicit Non-Causal Framework)
        let interpretation = generateInterpretation(
            metric: metric,
            statsA: statsA,
            statsB: statsB,
            nameA: nameA,
            nameB: nameB,
            cohenD: cohenD,
            velDiff: velDiff,
            compoundNamesA: compoundNamesA,
            compoundNamesB: compoundNamesB
        )

        return MetricComparisonResult(
            metricDefinition: metric,
            observedChange: observedChange,
            interpretation: interpretation,
            targetDirection: metric.targetDirection
        )
    }

    // MARK: - 3. Domain-Specific Comparators

    /// Compares weight change and body composition dynamics across two periods.
    public func compareWeight(
        measurements: [Measurement],
        rangeA: DateInterval,
        rangeB: DateInterval,
        nameA: String = "Period A",
        nameB: String = "Period B",
        compoundNamesA: [String] = [],
        compoundNamesB: [String] = []
    ) -> MetricComparisonResult? {
        let weightPoints = measurements.filter { $0.type == .weight }
        guard !weightPoints.isEmpty else { return nil }

        let metricDef = MetricDefinition.builtIn(for: .weight)
        return compareTimeSeries(
            seriesA: weightPoints,
            seriesB: weightPoints,
            rangeA: rangeA,
            rangeB: rangeB,
            metric: metricDef,
            nameA: nameA,
            nameB: nameB,
            compoundNamesA: compoundNamesA,
            compoundNamesB: compoundNamesB
        )
    }

    /// Compares physical measurements, cardiovascular vitals, and health metrics.
    public func compareMeasurements(
        measurements: [Measurement],
        metricTypes: [MeasurementType] = [.waist, .bloodPressure, .restingHeartRate, .hrv, .bloodGlucose, .sleep, .bodyFat],
        rangeA: DateInterval,
        rangeB: DateInterval,
        nameA: String = "Period A",
        nameB: String = "Period B",
        compoundNamesA: [String] = [],
        compoundNamesB: [String] = []
    ) -> [MetricComparisonResult] {
        var results: [MetricComparisonResult] = []

        for type in metricTypes {
            let filtered = measurements.filter { $0.type == type }
            guard !filtered.isEmpty else { continue }

            let hasDataA = filtered.contains { $0.timestamp >= rangeA.start && $0.timestamp <= rangeA.end }
            let hasDataB = filtered.contains { $0.timestamp >= rangeB.start && $0.timestamp <= rangeB.end }
            guard hasDataA || hasDataB else { continue }

            let metricDef = MetricDefinition.builtIn(for: type)
            let comp = compareTimeSeries(
                seriesA: filtered,
                seriesB: filtered,
                rangeA: rangeA,
                rangeB: rangeB,
                metric: metricDef,
                nameA: nameA,
                nameB: nameB,
                compoundNamesA: compoundNamesA,
                compoundNamesB: compoundNamesB
            )
            results.append(comp)
        }

        return results
    }

    /// Compares protocol dose adherence and compliance consistency between two periods.
    public func compareAdherence(
        doseLogs: [DoseLog],
        rangeA: DateInterval,
        rangeB: DateInterval,
        nameA: String = "Period A",
        nameB: String = "Period B"
    ) -> AdherenceComparisonResult {
        let dosesA = doseLogs.filter {
            let dt = $0.loggedDate ?? $0.scheduledDate
            return dt >= rangeA.start && dt <= rangeA.end
        }
        let dosesB = doseLogs.filter {
            let dt = $0.loggedDate ?? $0.scheduledDate
            return dt >= rangeB.start && dt <= rangeB.end
        }

        let statsA = computeAdherencePeriodStats(doses: dosesA, interval: rangeA)
        let statsB = computeAdherencePeriodStats(doses: dosesB, interval: rangeB)

        let rateDiff = statsB.adherencePercentage - statsA.adherencePercentage
        let missDiff = statsB.missedDoses - statsA.missedDoses
        let streakDiff = statsB.activeStreakDays - statsA.activeStreakDays

        let observedChange = ObservedAdherenceChange(
            periodAStats: statsA,
            periodBStats: statsB,
            adherenceRateDifference: rateDiff,
            missedDoseDifference: missDiff,
            streakDifferenceDays: streakDiff
        )

        // Confounders
        var confounders: [String] = [
            "Logging compliance may introduce reporting bias (unlogged doses might have been taken or missed).",
            "Dose administration schedules with different frequencies (e.g. daily vs weekly) impact adherence opportunity counts."
        ]
        if statsA.totalScheduledDoses != statsB.totalScheduledDoses {
            confounders.append("Differing total dose counts (\(statsA.totalScheduledDoses) in \(nameA) vs \(statsB.totalScheduledDoses) in \(nameB)).")
        }

        let narrative: String
        let impact: String
        if abs(rateDiff) <= 3.0 {
            narrative = "Protocol compliance remained stable across both periods (\(String(format: "%.1f", statsA.adherencePercentage))% in \(nameA) vs \(String(format: "%.1f", statsB.adherencePercentage))% in \(nameB))."
            impact = "Consistent adherence provides a steady baseline for observational tracking."
        } else if rateDiff > 0 {
            narrative = "Observed protocol adherence was +\(String(format: "%.1f", rateDiff))% higher during \(nameB) (\(String(format: "%.1f", statsB.adherencePercentage))%) compared to \(nameA) (\(String(format: "%.1f", statsA.adherencePercentage))%)."
            impact = "Higher compliance in \(nameB) may be associated with more consistent physiological exposure."
        } else {
            narrative = "Observed protocol adherence was \(String(format: "%.1f", abs(rateDiff)))% lower during \(nameB) (\(String(format: "%.1f", statsB.adherencePercentage))%) compared to \(nameA) (\(String(format: "%.1f", statsA.adherencePercentage))%)."
            impact = "Missed doses during \(nameB) may have created variable compound clearance cycles."
        }

        let interpretation = AdherenceInterpretation(
            narrativeSummary: narrative,
            complianceImpactAssessment: impact,
            potentialConfounders: confounders
        )

        return AdherenceComparisonResult(
            observedChange: observedChange,
            interpretation: interpretation
        )
    }

    /// Compares subjective symptoms, recovery scores, and reported side effects between two periods.
    public func compareSymptoms(
        symptomLogs: [SymptomLog],
        rangeA: DateInterval,
        rangeB: DateInterval,
        nameA: String = "Period A",
        nameB: String = "Period B"
    ) -> SymptomComparisonResult {
        let logsA = symptomLogs.filter { $0.timestamp >= rangeA.start && $0.timestamp <= rangeA.end }
        let logsB = symptomLogs.filter { $0.timestamp >= rangeB.start && $0.timestamp <= rangeB.end }

        // Extract sub-domain points
        func points(from logs: [SymptomLog], keyPath: KeyPath<SymptomLog, Int>) -> [GenericTimeSeriesPoint] {
            logs.map { GenericTimeSeriesPoint(timestamp: $0.timestamp, value: Double($0[keyPath: keyPath]), unit: "/10") }
        }

        let energyA = points(from: logsA, keyPath: \.energyLevel)
        let energyB = points(from: logsB, keyPath: \.energyLevel)
        let sleepA = points(from: logsA, keyPath: \.sleepQuality)
        let sleepB = points(from: logsB, keyPath: \.sleepQuality)
        let recoveryA = points(from: logsA, keyPath: \.recoveryScore)
        let recoveryB = points(from: logsB, keyPath: \.recoveryScore)
        let moodA = points(from: logsA, keyPath: \.moodScore)
        let moodB = points(from: logsB, keyPath: \.moodScore)

        let compositeA = logsA.map { GenericTimeSeriesPoint(timestamp: $0.timestamp, value: $0.overallWellbeingScore, unit: "/100") }
        let compositeB = logsB.map { GenericTimeSeriesPoint(timestamp: $0.timestamp, value: $0.overallWellbeingScore, unit: "/100") }

        var domainA: [String: DescriptiveStatistics] = [:]
        var domainB: [String: DescriptiveStatistics] = [:]

        domainA["Energy"] = computeDescriptiveStatistics(points: energyA, periodStart: rangeA.start, periodEnd: rangeA.end)
        domainB["Energy"] = computeDescriptiveStatistics(points: energyB, periodStart: rangeB.start, periodEnd: rangeB.end)
        domainA["Sleep Quality"] = computeDescriptiveStatistics(points: sleepA, periodStart: rangeA.start, periodEnd: rangeA.end)
        domainB["Sleep Quality"] = computeDescriptiveStatistics(points: sleepB, periodStart: rangeB.start, periodEnd: rangeB.end)
        domainA["Recovery"] = computeDescriptiveStatistics(points: recoveryA, periodStart: rangeA.start, periodEnd: rangeA.end)
        domainB["Recovery"] = computeDescriptiveStatistics(points: recoveryB, periodStart: rangeB.start, periodEnd: rangeB.end)
        domainA["Mood"] = computeDescriptiveStatistics(points: moodA, periodStart: rangeA.start, periodEnd: rangeA.end)
        domainB["Mood"] = computeDescriptiveStatistics(points: moodB, periodStart: rangeB.start, periodEnd: rangeB.end)
        domainA["Composite Well-Being"] = computeDescriptiveStatistics(points: compositeA, periodStart: rangeA.start, periodEnd: rangeA.end)
        domainB["Composite Well-Being"] = computeDescriptiveStatistics(points: compositeB, periodStart: rangeB.start, periodEnd: rangeB.end)

        // Side Effects
        let sideEffectsA = logsA.flatMap(\.sideEffects)
        let sideEffectsB = logsB.flatMap(\.sideEffects)

        let compDiff = (domainB["Composite Well-Being"]?.meanValue ?? 0) - (domainA["Composite Well-Being"]?.meanValue ?? 0)

        let observedChange = ObservedSymptomChange(
            domainStatsA: domainA,
            domainStatsB: domainB,
            compositeScoreDifference: compDiff,
            sideEffectOccurrencesA: sideEffectsA.count,
            sideEffectOccurrencesB: sideEffectsB.count,
            sideEffectsReportedA: Array(Set(sideEffectsA)),
            sideEffectsReportedB: Array(Set(sideEffectsB))
        )

        // Trajectory
        let trajectory: TrajectoryAssessment
        if abs(compDiff) <= 3.0 {
            trajectory = .comparable
        } else if compDiff > 0 {
            trajectory = .superiorPeriodB
        } else {
            trajectory = .superiorPeriodA
        }

        let confidence: ComparisonConfidence
        let minSamples = min(logsA.count, logsB.count)
        if minSamples >= 10 { confidence = .high }
        else if minSamples >= 4 { confidence = .moderate }
        else if minSamples >= 1 { confidence = .preliminary }
        else { confidence = .insufficientData }

        let narrative = "Composite subjective well-being averaged \(String(format: "%.1f", domainA["Composite Well-Being"]?.meanValue ?? 0))/100 during \(nameA) and \(String(format: "%.1f", domainB["Composite Well-Being"]?.meanValue ?? 0))/100 during \(nameB) (\(compDiff >= 0 ? "+" : "")\(String(format: "%.1f", compDiff)) pts). Side effect logs recorded \(sideEffectsA.count) events in \(nameA) vs \(sideEffectsB.count) in \(nameB)."

        let confounders: [String] = [
            "Subjective scoring is susceptible to placebo effects, psychological expectations, and day-to-day life stress.",
            "Workload, seasonal changes, sleep schedule irregularities, and acute illnesses influence symptom ratings independently of protocols."
        ]

        let interpretation = SymptomInterpretation(
            narrativeSummary: narrative,
            wellbeingTrajectory: trajectory,
            confidenceLevel: confidence,
            potentialConfounders: confounders
        )

        return SymptomComparisonResult(
            observedChange: observedChange,
            interpretation: interpretation
        )
    }

    // MARK: - 4. Lab & Biomarker Comparator

    /// Compares clinical bloodwork and biomarker shifts across two periods.
    public func compareBiomarkers(
        biomarkers: [Biomarker],
        rangeA: DateInterval,
        rangeB: DateInterval,
        nameA: String = "Period A",
        nameB: String = "Period B"
    ) -> [BiomarkerComparisonResult] {
        let markersA = biomarkers.filter { $0.dateRecorded >= rangeA.start && $0.dateRecorded <= rangeA.end }
        let markersB = biomarkers.filter { $0.dateRecorded >= rangeB.start && $0.dateRecorded <= rangeB.end }

        let allNames = Array(Set((markersA + markersB).map(\.name))).sorted()
        var results: [BiomarkerComparisonResult] = []

        for markerName in allNames {
            let ptsA = markersA.filter { $0.name == markerName }.map {
                GenericTimeSeriesPoint(timestamp: $0.dateRecorded, value: $0.value, unit: $0.unit)
            }
            let ptsB = markersB.filter { $0.name == markerName }.map {
                GenericTimeSeriesPoint(timestamp: $0.dateRecorded, value: $0.value, unit: $0.unit)
            }

            guard !ptsA.isEmpty || !ptsB.isEmpty else { continue }

            let sample = (markersA + markersB).first { $0.name == markerName }!
            let statsA = computeDescriptiveStatistics(points: ptsA, periodStart: rangeA.start, periodEnd: rangeA.end)
            let statsB = computeDescriptiveStatistics(points: ptsB, periodStart: rangeB.start, periodEnd: rangeB.end)

            let shift = statsB.lastValue - statsA.lastValue
            let pctShift = statsA.lastValue != 0 ? ((shift / abs(statsA.lastValue)) * 100.0) : 0.0

            let statusA = sampleStatus(value: statsA.lastValue, min: sample.referenceRangeMin, max: sample.referenceRangeMax)
            let statusB = sampleStatus(value: statsB.lastValue, min: sample.referenceRangeMin, max: sample.referenceRangeMax)

            let transDesc = "\(statusA.rawValue) → \(statusB.rawValue)"

            let observedChange = ObservedBiomarkerChange(
                biomarkerName: markerName,
                category: sample.category,
                unit: sample.unit,
                referenceRangeMin: sample.referenceRangeMin,
                referenceRangeMax: sample.referenceRangeMax,
                periodAStats: statsA,
                periodBStats: statsB,
                absoluteShift: shift,
                percentageShift: pctShift,
                statusA: statusA,
                statusB: statusB,
                statusTransitionDescription: transDesc
            )

            let sign = shift >= 0 ? "+" : ""
            let clinicalContext = "\(markerName) shifted by \(sign)\(String(format: "%.1f", shift)) \(sample.unit) (\(sign)\(String(format: "%.1f", pctShift))%) from \(nameA) (\(String(format: "%.1f", statsA.lastValue)) \(sample.unit)) to \(nameB) (\(String(format: "%.1f", statsB.lastValue)) \(sample.unit)). Reference transition: \(transDesc)."

            let confounders: [String] = [
                "Blood biomarker values are sensitive to time-of-day of draw, fasting status, hydration, acute training fatigue, and assay laboratory calibrations.",
                "Clinical biomarker changes reflect systemic physiology and cannot be definitively isolated to a single compound without controlled trials."
            ]

            let interpretation = BiomarkerInterpretation(
                clinicalContext: clinicalContext,
                statusAssessment: statusB == .inRange ? "Biomarker is within physiological reference range." : "Biomarker is outside standard reference intervals.",
                potentialConfounders: confounders
            )

            results.append(
                BiomarkerComparisonResult(
                    observedChange: observedChange,
                    interpretation: interpretation
                )
            )
        }

        return results
    }

    // MARK: - 5. Cost & Financial Comparator

    /// Compares financial expenditure, burn rates, and financial efficiency between two periods.
    public func compareCosts(
        costEvents: [CostEvent],
        completedDoses: [DoseEvent] = [],
        rangeA: DateInterval,
        rangeB: DateInterval,
        nameA: String = "Period A",
        nameB: String = "Period B",
        protocolAId: UUID? = nil,
        protocolBId: UUID? = nil,
        primaryOutcomeDeltaA: Double? = nil,
        primaryOutcomeDeltaB: Double? = nil
    ) -> CostComparisonResult {
        let costsA = costEvents.filter {
            if let pId = protocolAId, $0.protocolId == pId { return true }
            return $0.dateIncurred >= rangeA.start && $0.dateIncurred <= rangeA.end
        }
        let costsB = costEvents.filter {
            if let pId = protocolBId, $0.protocolId == pId { return true }
            return $0.dateIncurred >= rangeB.start && $0.dateIncurred <= rangeB.end
        }

        let totalA = costsA.reduce(0.0) { $0 + $1.amount }
        let totalB = costsB.reduce(0.0) { $0 + $1.amount }

        let daysA = max(1.0, ceil(rangeA.duration / 86400.0))
        let daysB = max(1.0, ceil(rangeB.duration / 86400.0))

        let costPerDayA = totalA / daysA
        let costPerDayB = totalB / daysB

        let dosesCountA = max(1, completedDoses.filter {
            if let pId = protocolAId { return $0.protocolId == pId && $0.status == .taken }
            return $0.administeredDate >= rangeA.start && $0.administeredDate <= rangeA.end && $0.status == .taken
        }.count)

        let dosesCountB = max(1, completedDoses.filter {
            if let pId = protocolBId { return $0.protocolId == pId && $0.status == .taken }
            return $0.administeredDate >= rangeB.start && $0.administeredDate <= rangeB.end && $0.status == .taken
        }.count)

        let costPerDoseA = totalA / Double(dosesCountA)
        let costPerDoseB = totalB / Double(dosesCountB)

        var mapA: [CostCategory: Double] = [:]
        var mapB: [CostCategory: Double] = [:]
        for c in costsA { mapA[c.category, default: 0.0] += c.amount }
        for c in costsB { mapB[c.category, default: 0.0] += c.amount }

        var costEffRatio: Double? = nil
        if let d = primaryOutcomeDeltaB, abs(d) > 0.001 {
            costEffRatio = totalB / abs(d)
        }

        let observedChange = ObservedCostChange(
            totalCostA: totalA,
            totalCostB: totalB,
            costPerDayA: costPerDayA,
            costPerDayB: costPerDayB,
            costPerDoseA: costPerDoseA,
            costPerDoseB: costPerDoseB,
            categoryBreakdownA: mapA,
            categoryBreakdownB: mapB,
            costDeltaTotal: totalB - totalA,
            costDeltaPerDay: costPerDayB - costPerDayA,
            costEffectivenessRatio: costEffRatio
        )

        let summary = "Total financial spend was $\(String(format: "%.2f", totalA)) ($\(String(format: "%.2f", costPerDayA))/day) for \(nameA) vs $\(String(format: "%.2f", totalB)) ($\(String(format: "%.2f", costPerDayB))/day) for \(nameB)."
        let monthlyB = costPerDayB * 30.4375
        let projection = "Projected 30-day recurring expenditure based on \(nameB) is $\(String(format: "%.2f", monthlyB))."

        let confounders: [String] = [
            "Bulk purchasing, shipping thresholds, and upfront multi-vial investments may skew short-term cost allocation.",
            "Supplies and lab testing costs may be amortized unevenly across protocols."
        ]

        let interpretation = CostInterpretation(
            financialEfficiencySummary: summary,
            budgetaryProjection: projection,
            potentialConfounders: confounders
        )

        return CostComparisonResult(
            observedChange: observedChange,
            interpretation: interpretation
        )
    }

    // MARK: - 6. Comprehensive Master Comparison Report Generator

    /// Generates a complete non-causal Protocol Comparison Report across all tracking streams.
    public func generateComparisonReport(
        periodA: ProtocolComparisonPeriod,
        periodB: ProtocolComparisonPeriod,
        measurements: [Measurement] = [],
        doseLogs: [DoseLog] = [],
        completedDoses: [DoseEvent] = [],
        symptomLogs: [SymptomLog] = [],
        biomarkers: [Biomarker] = [],
        costEvents: [CostEvent] = [],
        customMetrics: [MetricDefinition] = []
    ) -> ProtocolComparisonReport {
        let compoundsA = periodA.compounds.map(\.compoundName)
        let compoundsB = periodB.compounds.map(\.compoundName)

        // 1. Weight Comparison
        let weightComp = compareWeight(
            measurements: measurements,
            rangeA: periodA.interval,
            rangeB: periodB.interval,
            nameA: periodA.name,
            nameB: periodB.name,
            compoundNamesA: compoundsA,
            compoundNamesB: compoundsB
        )

        // 2. Physical & Vital Measurements
        let measurementComps = compareMeasurements(
            measurements: measurements,
            rangeA: periodA.interval,
            rangeB: periodB.interval,
            nameA: periodA.name,
            nameB: periodB.name,
            compoundNamesA: compoundsA,
            compoundNamesB: compoundsB
        )

        // 3. Adherence Comparison
        let adherenceComp = compareAdherence(
            doseLogs: doseLogs,
            rangeA: periodA.interval,
            rangeB: periodB.interval,
            nameA: periodA.name,
            nameB: periodB.name
        )

        // 4. Symptoms & Well-being
        let symptomComp = compareSymptoms(
            symptomLogs: symptomLogs,
            rangeA: periodA.interval,
            rangeB: periodB.interval,
            nameA: periodA.name,
            nameB: periodB.name
        )

        // 5. Blood Biomarkers
        let biomarkerComps = compareBiomarkers(
            biomarkers: biomarkers,
            rangeA: periodA.interval,
            rangeB: periodB.interval,
            nameA: periodA.name,
            nameB: periodB.name
        )

        // 6. Financial Costs
        let primaryDeltaA = weightComp?.observedChange.periodAStats.netChange
        let primaryDeltaB = weightComp?.observedChange.periodBStats.netChange
        let costComp = compareCosts(
            costEvents: costEvents,
            completedDoses: completedDoses,
            rangeA: periodA.interval,
            rangeB: periodB.interval,
            nameA: periodA.name,
            nameB: periodB.name,
            protocolAId: periodA.protocolId,
            protocolBId: periodB.protocolId,
            primaryOutcomeDeltaA: primaryDeltaA,
            primaryOutcomeDeltaB: primaryDeltaB
        )

        // 7. Custom User-Selected Metrics
        var customComps: [MetricComparisonResult] = []
        for customMetric in customMetrics {
            let customPoints = measurements.filter { $0.customMetricCode == customMetric.code || $0.name == customMetric.name }
            if !customPoints.isEmpty {
                let comp = compareTimeSeries(
                    seriesA: customPoints,
                    seriesB: customPoints,
                    rangeA: periodA.interval,
                    rangeB: periodB.interval,
                    metric: customMetric,
                    nameA: periodA.name,
                    nameB: periodB.name,
                    compoundNamesA: compoundsA,
                    compoundNamesB: compoundsB
                )
                customComps.append(comp)
            }
        }

        // Confounders synthesis
        var detectedConfounders: [String] = []
        if abs(periodA.durationDays - periodB.durationDays) >= 7 {
            detectedConfounders.append("Observation period duration asymmetry: \(periodA.name) (\(periodA.durationDays) days) vs \(periodB.name) (\(periodB.durationDays) days).")
        }
        let diffCompounds = Set(compoundsB).subtracting(Set(compoundsA))
        if !diffCompounds.isEmpty {
            detectedConfounders.append("Protocol regimen variation: \(periodB.name) included [\(diffCompounds.joined(separator: ", "))] not present in \(periodA.name).")
        }
        detectedConfounders.append("Uncontrolled lifestyle variables (dietary intake, sleep quality, training frequency, recovery, hydration).")
        detectedConfounders.append("Observational real-world data collection without placebo control or blinding.")

        // Executive summary
        let execSummary = buildExecutiveSummary(
            periodA: periodA,
            periodB: periodB,
            weightComp: weightComp,
            adherenceComp: adherenceComp,
            symptomComp: symptomComp,
            costComp: costComp
        )

        return ProtocolComparisonReport(
            periodA: periodA,
            periodB: periodB,
            weightComparison: weightComp,
            measurementComparisons: measurementComps,
            adherenceComparison: adherenceComp,
            symptomComparison: symptomComp,
            biomarkerComparisons: biomarkerComps,
            costComparison: costComp,
            customMetricComparisons: customComps,
            executiveSummary: execSummary,
            identifiedConfounders: detectedConfounders
        )
    }

    // MARK: - 7. Helper & Mathematical Functions

    private func computeAdherencePeriodStats(doses: [DoseLog], interval: DateInterval) -> AdherencePeriodStats {
        let days = max(1, Int(ceil(interval.duration / 86400.0)))
        guard !doses.isEmpty else {
            return AdherencePeriodStats(
                totalScheduledDoses: 0,
                takenDoses: 0,
                missedDoses: 0,
                adherencePercentage: 0.0,
                activeStreakDays: 0,
                loggedDaysCount: days
            )
        }

        let taken = doses.filter { $0.status == .taken }.count
        let missed = doses.filter { $0.status == .missed }.count
        let total = max(1, taken + missed)
        let rate = (Double(taken) / Double(total)) * 100.0

        // Streak calculation
        let sorted = doses.sorted(by: { ($0.loggedDate ?? $0.scheduledDate) < ($1.loggedDate ?? $1.scheduledDate) })
        var streak = 0
        var maxStreak = 0
        for d in sorted {
            if d.status == .taken {
                streak += 1
                maxStreak = max(maxStreak, streak)
            } else {
                streak = 0
            }
        }

        return AdherencePeriodStats(
            totalScheduledDoses: total,
            takenDoses: taken,
            missedDoses: missed,
            adherencePercentage: rate,
            activeStreakDays: maxStreak,
            loggedDaysCount: days
        )
    }

    private func generateInterpretation(
        metric: MetricDefinition,
        statsA: DescriptiveStatistics,
        statsB: DescriptiveStatistics,
        nameA: String,
        nameB: String,
        cohenD: Double?,
        velDiff: Double,
        compoundNamesA: [String],
        compoundNamesB: [String]
    ) -> ComparisonInterpretation {
        // Confounders
        var confounders: [String] = []
        if abs(statsA.durationDays - statsB.durationDays) >= 7 {
            confounders.append("Duration asymmetry (\(statsA.durationDays) days in \(nameA) vs \(statsB.durationDays) days in \(nameB)).")
        }
        if abs(statsA.loggingFrequencyPerWeek - statsB.loggingFrequencyPerWeek) >= 2.0 {
            confounders.append("Logging frequency disparity (\(String(format: "%.1f", statsA.loggingFrequencyPerWeek)) logs/wk in \(nameA) vs \(String(format: "%.1f", statsB.loggingFrequencyPerWeek)) logs/wk in \(nameB)).")
        }
        let diffRegimens = Set(compoundNamesB).subtracting(Set(compoundNamesA))
        if !diffRegimens.isEmpty {
            confounders.append("Co-administered compound differences ([\(diffRegimens.joined(separator: ", "))]).")
        }
        confounders.append("Unmeasured dietary, physical exercise, and circadian rhythm variations.")

        // Trajectory Assessment
        let trajectory: TrajectoryAssessment
        switch metric.targetDirection {
        case .decrease:
            if statsB.netChange < statsA.netChange {
                trajectory = .superiorPeriodB
            } else if statsA.netChange < statsB.netChange {
                trajectory = .superiorPeriodA
            } else {
                trajectory = .comparable
            }
        case .increase:
            if statsB.netChange > statsA.netChange {
                trajectory = .superiorPeriodB
            } else if statsA.netChange > statsB.netChange {
                trajectory = .superiorPeriodA
            } else {
                trajectory = .comparable
            }
        case .maintain:
            let devA = abs(statsA.netChange)
            let devB = abs(statsB.netChange)
            if abs(devA - devB) <= 0.5 {
                trajectory = .comparable
            } else {
                trajectory = devB < devA ? .superiorPeriodB : .superiorPeriodA
            }
        }

        // Confidence
        let minCount = min(statsA.sampleCount, statsB.sampleCount)
        let confidence: ComparisonConfidence
        if minCount >= 10 { confidence = .high }
        else if minCount >= 4 { confidence = .moderate }
        else if minCount >= 1 { confidence = .preliminary }
        else { confidence = .insufficientData }

        // Narrative
        let effectDesc: String
        if let d = cohenD {
            if d >= 0.8 { effectDesc = "large effect size (d = \(String(format: "%.2f", d)))" }
            else if d >= 0.5 { effectDesc = "moderate effect size (d = \(String(format: "%.2f", d)))" }
            else { effectDesc = "small effect size (d = \(String(format: "%.2f", d)))" }
        } else {
            effectDesc = "observational differential"
        }

        let narrative: String
        switch trajectory {
        case .superiorPeriodB:
            narrative = "During \(nameB), \(metric.name) demonstrated a favorable trajectory relative to \(nameA), exhibiting a weekly velocity difference of \(String(format: "%.2f", abs(velDiff))) \(metric.defaultUnit)/wk with a \(effectDesc)."
        case .superiorPeriodA:
            narrative = "During \(nameA), \(metric.name) demonstrated a favorable trajectory relative to \(nameB), exhibiting a weekly velocity difference of \(String(format: "%.2f", abs(velDiff))) \(metric.defaultUnit)/wk with a \(effectDesc)."
        case .comparable:
            narrative = "Both periods exhibited comparable trajectories for \(metric.name) (mean delta: \(String(format: "%.2f", statsB.meanValue - statsA.meanValue)) \(metric.defaultUnit))."
        case .divergent, .inconclusive:
            narrative = "Data points across \(nameA) and \(nameB) were insufficient or exhibited divergent patterns without a distinct directional trend."
        }

        return ComparisonInterpretation(
            narrativeSummary: narrative,
            trajectoryAssessment: trajectory,
            confidenceLevel: confidence,
            potentialConfounders: confounders,
            recommendedFollowUp: [
                "Maintain consistent measurement timing (e.g., fasted morning measurements).",
                "Log potential lifestyle confounders (caloric intake, sleep quality, stress levels)."
            ]
        )
    }

    private func buildExecutiveSummary(
        periodA: ProtocolComparisonPeriod,
        periodB: ProtocolComparisonPeriod,
        weightComp: MetricComparisonResult?,
        adherenceComp: AdherenceComparisonResult?,
        symptomComp: SymptomComparisonResult?,
        costComp: CostComparisonResult?
    ) -> String {
        var parts: [String] = []
        parts.append("Longitudinal time-series comparison between \(periodA.name) (\(periodA.durationDays) days) and \(periodB.name) (\(periodB.durationDays) days).")

        if let w = weightComp {
            let velA = String(format: "%.2f", w.observedChange.periodAStats.weeklyVelocity)
            let velB = String(format: "%.2f", w.observedChange.periodBStats.weeklyVelocity)
            parts.append("Weight velocity was \(velA) \(w.metricDefinition.defaultUnit)/wk in \(periodA.name) vs \(velB) \(w.metricDefinition.defaultUnit)/wk in \(periodB.name).")
        }

        if let adh = adherenceComp {
            parts.append("Dose adherence recorded \(Int(adh.observedChange.periodAStats.adherencePercentage))% in \(periodA.name) vs \(Int(adh.observedChange.periodBStats.adherencePercentage))% in \(periodB.name).")
        }

        if let cost = costComp {
            parts.append("Financial spend rate was $\(String(format: "%.2f", cost.observedChange.costPerDayA))/day vs $\(String(format: "%.2f", cost.observedChange.costPerDayB))/day.")
        }

        return parts.joined(separator: " ")
    }

    private func sampleStatus(value: Double, min: Double?, max: Double?) -> BiomarkerStatus {
        if let mn = min, value < mn { return .low }
        if let mx = max, value > mx { return .high }
        return .inRange
    }

    private func quantile(_ sortedValues: [Double], p: Double) -> Double {
        guard !sortedValues.isEmpty else { return 0.0 }
        let index = Double(sortedValues.count - 1) * p
        let lower = Int(floor(index))
        let upper = Int(ceil(index))
        let weight = index - Double(lower)
        return sortedValues[lower] * (1.0 - weight) + sortedValues[upper] * weight
    }

    private func normalCDF(_ x: Double) -> Double {
        // Standard normal cumulative distribution approximation (Abramowitz & Stegun formula)
        let b1 = 0.319381530
        let b2 = -0.356563782
        let b3 = 1.781477937
        let b4 = -1.821255978
        let b5 = 1.330274429
        let p = 0.2316419
        let c = 0.39894228

        if x >= 0.0 {
            let t = 1.0 / (1.0 + p * x)
            return 1.0 - c * exp(-x * x / 2.0) * t * (t * (t * (t * (t * b5 + b4) + b3) + b2) + b1)
        } else {
            let t = 1.0 / (1.0 - p * x)
            return c * exp(-x * x / 2.0) * t * (t * (t * (t * (t * b5 + b4) + b3) + b2) + b1)
        }
    }
}
