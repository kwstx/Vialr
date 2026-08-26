import Foundation

// MARK: - Time Series Data Point Protocol

/// Protocol defining a generic timestamped measurement point in a time series.
/// Conformed to by raw measurements, biomarker readings, and interpolated data points.
public protocol TimeSeriesDataPoint: Identifiable, Sendable, Codable, Hashable {
    var id: UUID { get }
    var timestamp: Date { get }
    var value: Double { get }
    var secondaryValue: Double? { get }
    var unit: String { get }
    var source: MeasurementSource { get }
    var notes: String { get }
    var associatedProtocolId: UUID? { get }
}

// MARK: - Generic Concrete Time Series Data Point

/// A standard, lightweight concrete time-series data point.
public struct GenericTimeSeriesPoint: TimeSeriesDataPoint, Codable, Sendable, Hashable {
    public let id: UUID
    public var timestamp: Date
    public var value: Double
    public var secondaryValue: Double?
    public var unit: String
    public var source: MeasurementSource
    public var notes: String
    public var associatedProtocolId: UUID?
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        value: Double,
        secondaryValue: Double? = nil,
        unit: String,
        source: MeasurementSource = .manualEntry,
        notes: String = "",
        associatedProtocolId: UUID? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
        self.secondaryValue = secondaryValue
        self.unit = unit
        self.source = source
        self.notes = notes
        self.associatedProtocolId = associatedProtocolId
        self.metadata = metadata
    }
}

// MARK: - Generic Time Series Collection

/// A strongly-typed, chronologically ordered collection of time-series data points.
/// Provides statistical aggregates, date filtering, resampling, downsampling, and interpolation.
public struct TimeSeries<Point: TimeSeriesDataPoint>: Sendable, Codable, Hashable, Sequence {
    public let points: [Point]

    // MARK: - Initializers
    public init(points: [Point] = []) {
        // Guarantee points are sorted in chronological order
        self.points = points.sorted(by: { $0.timestamp < $1.timestamp })
    }

    public func makeIterator() -> IndexingIterator<[Point]> {
        points.makeIterator()
    }

    // MARK: - Basic Properties
    public var count: Int { points.count }
    public var isEmpty: Bool { points.isEmpty }

    public var startDate: Date? { points.first?.timestamp }
    public var endDate: Date? { points.last?.timestamp }

    public var durationDays: Int {
        guard let start = startDate, let end = endDate else { return 0 }
        let diff = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return max(0, diff)
    }

    public var firstPoint: Point? { points.first }
    public var latestPoint: Point? { points.last }

    public var values: [Double] { points.map(\.value) }

    // MARK: - Statistical Aggregates
    public var minValue: Double? { values.min() }
    public var maxValue: Double? { values.max() }

    public var meanValue: Double? {
        guard !points.isEmpty else { return nil }
        let sum = values.reduce(0.0, +)
        return sum / Double(points.count)
    }

    public var medianValue: Double? {
        guard !points.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        } else {
            return sorted[mid]
        }
    }

    public var variance: Double? {
        guard let mean = meanValue, points.count > 1 else { return nil }
        let sumSquaredDiffs = values.reduce(0.0) { $0 + pow($1 - mean, 2) }
        return sumSquaredDiffs / Double(points.count - 1)
    }

    public var standardDeviation: Double? {
        guard let v = variance else { return nil }
        return sqrt(v)
    }

    public var rangeSpan: Double? {
        guard let min = minValue, let max = maxValue else { return nil }
        return max - min
    }

    public var overallDelta: Double? {
        guard let first = firstPoint?.value, let last = latestPoint?.value else { return nil }
        return last - first
    }

    public var overallPercentageChange: Double? {
        guard let first = firstPoint?.value, let last = latestPoint?.value, first != 0 else { return nil }
        return ((last - first) / abs(first)) * 100.0
    }

    public var weeklyVelocity: Double? {
        guard let delta = overallDelta, let start = startDate, let end = endDate else { return nil }
        let seconds = end.timeIntervalSince(start)
        let weeks = seconds / (86400.0 * 7.0)
        guard weeks > 0.1 else { return nil }
        return delta / weeks
    }

    // MARK: - Filtering & Sub-series
    public func filter(startDate: Date? = nil, endDate: Date? = nil) -> TimeSeries<Point> {
        let filtered = points.filter { point in
            if let start = startDate, point.timestamp < start { return false }
            if let end = endDate, point.timestamp > end { return false }
            return true
        }
        return TimeSeries<Point>(points: filtered)
    }

    public func filter(dateInterval: DateInterval) -> TimeSeries<Point> {
        filter(startDate: dateInterval.start, endDate: dateInterval.end)
    }

    public func filter(protocolId: UUID) -> TimeSeries<Point> {
        let filtered = points.filter { $0.associatedProtocolId == protocolId }
        return TimeSeries<Point>(points: filtered)
    }

    public func subseries(recentDays: Int, relativeTo referenceDate: Date = Date()) -> TimeSeries<Point> {
        let cal = Calendar.current
        guard let threshold = cal.date(byAdding: .day, value: -recentDays, to: referenceDate) else {
            return self
        }
        return filter(startDate: threshold, endDate: referenceDate)
    }

    // MARK: - Daily Bucketing
    public func dailyBuckets(
        calendar: Calendar = .current,
        strategy: BucketAggregationStrategy = .mean
    ) -> [DailyBucket<Point>] {
        guard !points.isEmpty else { return [] }

        var grouped: [Date: [Point]] = [:]
        for point in points {
            let startOfDay = calendar.startOfDay(for: point.timestamp)
            grouped[startOfDay, default: []].append(point)
        }

        let sortedDays = grouped.keys.sorted()
        return sortedDays.compactMap { day in
            guard let dayPoints = grouped[day], !dayPoints.isEmpty else { return nil }
            let aggValue: Double
            switch strategy {
            case .mean:
                aggValue = dayPoints.map(\.value).reduce(0.0, +) / Double(dayPoints.count)
            case .median:
                let s = dayPoints.map(\.value).sorted()
                let mid = s.count / 2
                aggValue = (s.count % 2 == 0) ? ((s[mid - 1] + s[mid]) / 2.0) : s[mid]
            case .min:
                aggValue = dayPoints.map(\.value).min() ?? 0
            case .max:
                aggValue = dayPoints.map(\.value).max() ?? 0
            case .first:
                aggValue = dayPoints.first?.value ?? 0
            case .latest:
                aggValue = dayPoints.last?.value ?? 0
            case .sum:
                aggValue = dayPoints.map(\.value).reduce(0.0, +)
            }

            return DailyBucket(
                date: day,
                aggregatedValue: aggValue,
                points: dayPoints,
                strategy: strategy
            )
        }
    }

    // MARK: - Linear Interpolation
    /// Estimates the value of the metric at any timestamp between the earliest and latest points.
    public func linearInterpolate(at targetDate: Date) -> Double? {
        guard points.count >= 2,
              let first = points.first,
              let last = points.last,
              targetDate >= first.timestamp,
              targetDate <= last.timestamp else {
            return nil
        }

        // Exact match
        if let exact = points.first(where: { $0.timestamp == targetDate }) {
            return exact.value
        }

        // Find surrounding points
        var lowerIndex = 0
        for (i, p) in points.enumerated() {
            if p.timestamp <= targetDate {
                lowerIndex = i
            } else {
                break
            }
        }

        let upperIndex = min(points.count - 1, lowerIndex + 1)
        let p0 = points[lowerIndex]
        let p1 = points[upperIndex]

        let t0 = p0.timestamp.timeIntervalSince1970
        let t1 = p1.timestamp.timeIntervalSince1970
        let tTarget = targetDate.timeIntervalSince1970

        guard t1 > t0 else { return p0.value }

        let fraction = (tTarget - t0) / (t1 - t0)
        return p0.value + fraction * (p1.value - p0.value)
    }

    // MARK: - Resampling & Downsampling
    /// Downsamples a dense time-series into approximately `targetCount` evenly-spaced points.
    public func downsample(targetCount: Int) -> TimeSeries<Point> {
        guard points.count > targetCount, targetCount > 2 else { return self }

        var sampled: [Point] = []
        sampled.append(points[0]) // Always include first

        let bucketSize = Double(points.count - 2) / Double(targetCount - 2)
        for i in 0..<(targetCount - 2) {
            let startIdx = Int(Double(i) * bucketSize) + 1
            let endIdx = min(points.count - 1, Int(Double(i + 1) * bucketSize) + 1)
            let slice = points[startIdx..<endIdx]
            if let rep = slice.first {
                sampled.append(rep)
            }
        }

        sampled.append(points[points.count - 1]) // Always include last
        return TimeSeries<Point>(points: sampled)
    }
}

// MARK: - Supporting Enums & Structs

public enum BucketAggregationStrategy: String, Codable, Sendable, CaseIterable {
    case mean = "Average (Mean)"
    case median = "Median"
    case min = "Minimum"
    case max = "Maximum"
    case first = "First of Day"
    case latest = "Latest of Day"
    case sum = "Sum"
}

public struct DailyBucket<Point: TimeSeriesDataPoint>: Identifiable, Sendable, Codable, Hashable {
    public var id: Date { date }
    public let date: Date
    public let aggregatedValue: Double
    public let points: [Point]
    public let strategy: BucketAggregationStrategy

    public init(
        date: Date,
        aggregatedValue: Double,
        points: [Point],
        strategy: BucketAggregationStrategy
    ) {
        self.date = date
        self.aggregatedValue = aggregatedValue
        self.points = points
        self.strategy = strategy
    }
}
