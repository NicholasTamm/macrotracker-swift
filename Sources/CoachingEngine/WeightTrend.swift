//  WeightTrend.swift
//  CoachingEngine — weight-trend smoothing (pure functions).

import Foundation

/// A smoothed weight-trend data point: one device-calendar day with its trend value.
public struct TrendPoint: Equatable, Sendable {
    public var date: Date
    /// Smoothed weight in kg for this day.
    public var trendKg: Double
    /// The raw sample this point was updated from, if one existed that day.
    public var sampleKg: Double?

    public init(date: Date, trendKg: Double, sampleKg: Double?) {
        self.date = date
        self.trendKg = trendKg
        self.sampleKg = sampleKg
    }
}

/// Summary of a weight trend over a window.
public struct WeightTrendSummary: Equatable, Sendable {
    /// Trend value (kg) at the start of the window.
    public var startTrendKg: Double
    /// Trend value (kg) at the end of the window.
    public var endTrendKg: Double
    /// Number of days in the window.
    public var days: Int
    /// Number of days that had at least one weight sample.
    public var sampledDays: Int

    /// Smoothed rate of weight change (kg/week). Negative = losing.
    public var rateKgPerWeek: Double {
        guard days > 0 else { return 0 }
        return (endTrendKg - startTrendKg) / Double(days) * 7.0
    }

    /// Total smoothed weight change (kg) over the window.
    public var totalChangeKg: Double { endTrendKg - startTrendKg }

    /// Fraction of window days with a sample; drives estimator confidence.
    public var samplingCompleteness: Double {
        guard days > 0 else { return 0 }
        return Double(sampledDays) / Double(days)
    }
}

/// Weight-trend smoothing. Exponentially weighted moving average anchored to
/// calendar days: each day with a sample updates the trend as
/// `trend = alpha * sample + (1 - alpha) * previousTrend`; days without a
/// sample carry the previous trend forward unchanged. If several samples land
/// on the same day their mean is used.
public enum WeightTrend {

    /// Smoothing factor. Larger values follow raw samples more closely.
    public static let defaultAlpha: Double = 0.2

    /// Compute the daily trend series ending on `endDate` (inclusive),
    /// covering `windowDays` days. The series is anchored at local midnight
    /// (device calendar).
    ///
    /// - Parameters:
    ///   - samples: Raw weight samples (any order; duplicates per day averaged).
    ///   - endDate: Last day of the window (inclusive).
    ///   - windowDays: Length of the window in days.
    ///   - alpha: Smoothing factor in (0, 1).
    /// - Returns: One ``TrendPoint`` per day, oldest first. Returns an empty
    ///   array when no usable samples exist in or before the window.
    public static func trendSeries(
        samples: [WeightSample],
        endDate: Date,
        windowDays: Int,
        alpha: Double = defaultAlpha
    ) -> [TrendPoint] {
        guard windowDays > 0, alpha > 0, alpha < 1 else { return [] }

        let calendar = CoachingEngine.deviceCalendar
        let endDay = CoachingEngine.startOfDay(endDate)
        guard let startDay = calendar.date(byAdding: .day, value: -(windowDays - 1), to: endDay) else {
            return []
        }

        // Bucket samples by day; average duplicates.
        var byDay: [Date: [Double]] = [:]
        for sample in samples {
            let day = CoachingEngine.startOfDay(sample.date)
            byDay[day, default: []].append(sample.weightKg)
        }
        let dailyMean: [Date: Double] = byDay.mapValues { values in
            values.reduce(0, +) / Double(values.count)
        }

        // Seed: most recent sample on or before the window start. Without a
        // seed there is nothing to smooth from.
        var seedKg: Double?
        var seedDay: Date?
        for (day, mean) in dailyMean where day <= startDay {
            if seedDay == nil || day > seedDay! {
                seedDay = day
                seedKg = mean
            }
        }
        guard let seed = seedKg else { return [] }

        var points: [TrendPoint] = []
        var trend = seed
        var day = startDay
        while day <= endDay {
            if let mean = dailyMean[day] {
                trend = alpha * mean + (1 - alpha) * trend
                points.append(TrendPoint(date: day, trendKg: trend, sampleKg: mean))
            } else {
                points.append(TrendPoint(date: day, trendKg: trend, sampleKg: nil))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return points
    }

    /// Summarize the trend over the window ending on `endDate`.
    public static func summarize(
        samples: [WeightSample],
        endDate: Date,
        windowDays: Int,
        alpha: Double = defaultAlpha
    ) -> WeightTrendSummary? {
        let series = trendSeries(samples: samples, endDate: endDate, windowDays: windowDays, alpha: alpha)
        guard let first = series.first, let last = series.last else { return nil }
        return WeightTrendSummary(
            startTrendKg: first.trendKg,
            endTrendKg: last.trendKg,
            days: series.count,
            sampledDays: series.filter { $0.sampleKg != nil }.count
        )
    }

    /// Current trend weight (kg) as of `date`: the last trend value of a
    /// trailing window. Returns nil when no samples exist.
    public static func currentTrendKg(
        samples: [WeightSample],
        asOf date: Date = Date(),
        windowDays: Int = 21,
        alpha: Double = defaultAlpha
    ) -> Double? {
        summarize(samples: samples, endDate: date, windowDays: windowDays, alpha: alpha)?.endTrendKg
    }
}
