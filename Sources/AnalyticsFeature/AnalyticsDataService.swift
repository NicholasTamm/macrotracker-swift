import Foundation
import DataLayer
import CoachingEngine

// MARK: - Analytics range

/// Standard look-back windows shared by every dashboard.
public enum AnalyticsRange: String, CaseIterable, Identifiable, Sendable {
    case month = "1M"
    case quarter = "3M"
    case halfYear = "6M"
    case year = "1Y"

    public var id: String { rawValue }

    public var days: Int {
        switch self {
        case .month: return 28
        case .quarter: return 90
        case .halfYear: return 180
        case .year: return 365
        }
    }

    public var title: String {
        switch self {
        case .month: return "Last 4 weeks"
        case .quarter: return "Last 3 months"
        case .halfYear: return "Last 6 months"
        case .year: return "Last 12 months"
        }
    }
}

// MARK: - Value types

/// One day of summed nutrients.
public struct DailyNutrition: Identifiable, Sendable {
    public var dayStart: Date
    public var totals: MFDayTotals

    public var id: Date { dayStart }
}

/// Weekly rollup for charting.
public struct WeeklyNutrition: Identifiable, Sendable {
    public var weekStart: Date
    public var avgCalories: Double
    public var avgProtein: Double
    public var avgFat: Double
    public var avgCarbs: Double
    public var loggedDays: Int

    public var id: Date { weekStart }
}

/// One expenditure data point: a rolling estimate ending on `endDate`.
public struct ExpenditurePoint: Identifiable, Sendable {
    public var endDate: Date
    public var estimateKcal: Double
    public var confidence: Double

    public var id: Date { endDate }

    /// Confidence-derived flux band (± kcal).
    public var band: (low: Double, high: Double) {
        let half = (1 - confidence) * 200
        return (estimateKcal - half, estimateKcal + half)
    }
}

/// One weight data point: raw sample + smoothed trend.
public struct WeightPoint: Identifiable, Sendable {
    public var date: Date
    public var sampleKg: Double?
    public var trendKg: Double

    public var id: Date { date }
}

/// A food's contribution to one nutrient over a range.
public struct NutrientContributor: Identifiable, Sendable {
    public var foodName: String
    public var amount: Double
    public var share: Double // 0…1 of the total

    public var id: String { foodName }
}

/// Intake share per time-of-day block.
public struct TimingBlock: Identifiable, Sendable {
    public enum Block: String, CaseIterable {
        case morning // 5:00–10:59
        case midday // 11:00–15:59
        case evening // 16:00–21:59
        case night // 22:00–4:59

        public var title: String {
            switch self {
            case .morning: return "Morning"
            case .midday: return "Midday"
            case .evening: return "Evening"
            case .night: return "Night"
            }
        }
    }

    public var block: Block
    public var amount: Double
    public var share: Double

    public var id: String { block.rawValue }
}

/// One generated insight (original copy, adherence-neutral).
public struct AnalyticsInsight: Identifiable, Sendable {
    public var id = UUID()
    public var title: String
    public var body: String
    public var systemIcon: String
    public var accent: InsightAccent
}

/// Non-color accent choices; views map these to MFColor tokens.
public enum InsightAccent: Sendable {
    case calories, protein, fat, carbs, weight, expenditure, micro, habit
}

/// Habit/adherence snapshot over a range.
public struct HabitSnapshot: Sendable {
    public var loggingStreakDays: Int
    public var loggedDays: Int
    public var totalDays: Int
    public var daysNearCalorieTarget: Int
    public var daysHitProteinTarget: Int
    public var weighInDays: Int
    public var weeksWithWeighIn: Int
    public var totalWeeks: Int
}

// MARK: - AnalyticsDataService

/// Aggregation layer for the analytics dashboards. All queries run against
/// the injected repository protocols; all smoothing/estimation math is
/// delegated to CoachingEngine so the dashboards never re-implement it.
@MainActor
public final class AnalyticsDataService {
    private let deps: AnalyticsDependencies
    private let calendar = Calendar.current

    public init(dependencies: AnalyticsDependencies) {
        self.deps = dependencies
    }

    // MARK: Daily series

    /// Summed nutrients per day over the trailing `days` (today inclusive).
    public func dailyNutrition(last days: Int) throws -> [DailyNutrition] {
        let today = MFDates.startOfDay(Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }
        var result: [DailyNutrition] = []
        var day = start
        while day <= today {
            let totals = try deps.logs.dayTotals(day)
            result.append(DailyNutrition(dayStart: day, totals: totals))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// Average intake per nutrient over the trailing `days`, plus the number
    /// of days that had any logged food (averages divide by logged days, so
    /// skipped days don't drag averages down).
    public func nutrientAverages(last days: Int) throws -> (averages: [NutrientKey: Double], loggedDays: Int) {
        let series = try dailyNutrition(last: days)
        let logged = series.filter { $0.totals.entryCount > 0 }
        var averages: [NutrientKey: Double] = [:]
        guard !logged.isEmpty else { return (averages, 0) }
        for key in NutrientKey.allCases {
            averages[key] = logged.reduce(0) { $0 + $1.totals.total(key) } / Double(logged.count)
        }
        return (averages, logged.count)
    }

    // MARK: Weekly rollups

    /// Weekly average nutrition over `weeks` weeks (oldest first).
    public func weeklyNutrition(weeks: Int) throws -> [WeeklyNutrition] {
        let daily = try dailyNutrition(last: weeks * 7)
        var buckets: [[DailyNutrition]] = Array(repeating: [], count: weeks)
        let today = MFDates.startOfDay(Date())
        for day in daily {
            let diff = calendar.dateComponents([.day], from: day.dayStart, to: today).day ?? 0
            let index = weeks - 1 - diff / 7
            if index >= 0, index < weeks { buckets[index].append(day) }
        }
        return buckets.enumerated().compactMap { index, days in
            let logged = days.filter { $0.totals.entryCount > 0 }
            guard !logged.isEmpty,
                  let weekStart = calendar.date(byAdding: .day, value: -( (weeks - 1 - index) * 7 + 6), to: today)
            else { return nil }
            return WeeklyNutrition(
                weekStart: weekStart,
                avgCalories: logged.reduce(0) { $0 + $1.totals.calories } / Double(logged.count),
                avgProtein: logged.reduce(0) { $0 + $1.totals.protein } / Double(logged.count),
                avgFat: logged.reduce(0) { $0 + $1.totals.fat } / Double(logged.count),
                avgCarbs: logged.reduce(0) { $0 + $1.totals.carbs } / Double(logged.count),
                loggedDays: logged.count
            )
        }
    }

    // MARK: Expenditure series

    /// Rolling expenditure estimates: one per week ending each week over the
    /// range, using CoachingEngine's energy-balance estimator. Points with
    /// no estimate (insufficient data) are skipped.
    public func expenditureSeries(last days: Int) throws -> [ExpenditurePoint] {
        let weeks = max(1, days / 7)
        let today = MFDates.startOfDay(Date())
        let windowDays = ExpenditureEstimator.defaultWindowDays
        guard let earliest = calendar.date(byAdding: .day, value: -(days - 1), to: today),
              let fetchStart = calendar.date(byAdding: .day, value: -(windowDays + 7), to: earliest)
        else { return [] }

        let intake = try deps.logs.intakeDays(from: fetchStart, to: today)
        let weights = try deps.weights.samples(from: fetchStart, to: today)
        let steps = try deps.steps.stepDays(from: fetchStart, to: today)

        var points: [ExpenditurePoint] = []
        for w in 0..<weeks {
            guard let endDate = calendar.date(byAdding: .day, value: -(w * 7), to: today) else { continue }
            if let estimate = ExpenditureEstimator.estimate(
                intake: intake, weights: weights, steps: steps,
                endDate: endDate, windowDays: windowDays
            ) {
                points.append(ExpenditurePoint(
                    endDate: endDate,
                    estimateKcal: estimate.kcalPerDay,
                    confidence: estimate.confidence
                ))
            }
        }
        return points.sorted { $0.endDate < $1.endDate }
    }

    /// The current expenditure estimate (latest rolling window).
    public func currentExpenditure() throws -> ExpenditurePoint? {
        try expenditureSeries(last: ExpenditureEstimator.defaultWindowDays).last
    }

    // MARK: Weight series

    /// Smoothed weight trend + raw samples over the range, via CoachingEngine.
    public func weightSeries(last days: Int) throws -> [WeightPoint] {
        let today = MFDates.startOfDay(Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1 + 14), to: today) else { return [] }
        let samples = try deps.weights.samples(from: start, to: today)
        let series = WeightTrend.trendSeries(samples: samples, endDate: today, windowDays: days)
        return series.map { WeightPoint(date: $0.date, sampleKg: $0.sampleKg, trendKg: $0.trendKg) }
    }

    /// Smoothed rate of change (kg/week) over the range.
    public func weightRate(last days: Int) throws -> Double? {
        let today = MFDates.startOfDay(Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1 + 14), to: today) else { return nil }
        let samples = try deps.weights.samples(from: start, to: today)
        return WeightTrend.summarize(samples: samples, endDate: today, windowDays: days)?.rateKgPerWeek
    }

    // MARK: Top contributors

    /// Top foods by contribution to `key` over the range.
    public func topContributors(key: NutrientKey, last days: Int, limit: Int = 8) throws -> [NutrientContributor] {
        let today = MFDates.startOfDay(Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }
        let entries = try deps.logs.entries(from: start, to: today)
        var byFood: [String: Double] = [:]
        for entry in entries {
            byFood[entry.foodName, default: 0] += entry.snapshot(key)
        }
        let total = byFood.values.reduce(0, +)
        guard total > 0 else { return [] }
        return byFood
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { NutrientContributor(foodName: $0.key, amount: $0.value, share: $0.value / total) }
    }

    // MARK: Nutrient timing

    /// Intake of `key` split by time-of-day block over the range.
    public func timingBreakdown(key: NutrientKey, last days: Int) throws -> [TimingBlock] {
        let today = MFDates.startOfDay(Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }
        let entries = try deps.logs.entries(from: start, to: today)
        var byBlock: [TimingBlock.Block: Double] = [:]
        for entry in entries {
            let hour = calendar.component(.hour, from: entry.timestamp)
            let block: TimingBlock.Block
            switch hour {
            case 5..<11: block = .morning
            case 11..<16: block = .midday
            case 16..<22: block = .evening
            default: block = .night
            }
            byBlock[block, default: 0] += entry.snapshot(key)
        }
        let total = byBlock.values.reduce(0, +)
        guard total > 0 else { return [] }
        return TimingBlock.Block.allCases.compactMap { block in
            guard let amount = byBlock[block], amount > 0 else { return nil }
            return TimingBlock(block: block, amount: amount, share: amount / total)
        }
    }

    // MARK: Habits / adherence

    /// Adherence snapshot over the range: streaks, target-hit rates, weigh-ins.
    public func habitSnapshot(last days: Int) throws -> HabitSnapshot {
        let today = MFDates.startOfDay(Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return HabitSnapshot(loggingStreakDays: 0, loggedDays: 0, totalDays: 0,
                                 daysNearCalorieTarget: 0, daysHitProteinTarget: 0,
                                 weighInDays: 0, weeksWithWeighIn: 0, totalWeeks: 0)
        }
        let settings = try deps.program.settings()
        var loggedDays = 0
        var nearCalorie = 0
        var hitProtein = 0
        var day = start
        while day <= today {
            let totals = try deps.logs.dayTotals(day)
            if totals.entryCount > 0 {
                loggedDays += 1
                if settings.currentCalories > 0 {
                    let ratio = totals.calories / settings.currentCalories
                    if ratio >= 0.9, ratio <= 1.1 { nearCalorie += 1 }
                }
                if settings.currentProteinGrams > 0, totals.protein >= settings.currentProteinGrams * 0.9 {
                    hitProtein += 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        // Logging streak: consecutive days ending today (or yesterday, if
        // today is still unlogged) with at least one entry.
        var streak = 0
        var cursor = today
        if (try deps.logs.dayTotals(cursor)).entryCount == 0 {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while cursor >= start, (try deps.logs.dayTotals(cursor)).entryCount > 0 {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        let weighIns = try deps.weights.weights(from: start, to: today)
        let weighInDays = Set(weighIns.map { MFDates.startOfDay($0.timestamp) }).count
        let totalWeeks = max(1, days / 7)
        var weeksWithWeighIn = 0
        for w in 0..<totalWeeks {
            let weekEnd = calendar.date(byAdding: .day, value: -(w * 7), to: today) ?? today
            let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd
            if weighIns.contains(where: { $0.timestamp >= weekStart && $0.timestamp <= weekEnd }) {
                weeksWithWeighIn += 1
            }
        }

        return HabitSnapshot(
            loggingStreakDays: streak,
            loggedDays: loggedDays,
            totalDays: days,
            daysNearCalorieTarget: nearCalorie,
            daysHitProteinTarget: hitProtein,
            weighInDays: weighInDays,
            weeksWithWeighIn: weeksWithWeighIn,
            totalWeeks: totalWeeks
        )
    }

    // MARK: Targets

    /// All nutrient targets keyed by nutrient (seeded defaults + customs).
    public func allTargets() throws -> [NutrientKey: NutrientTarget] {
        var result: [NutrientKey: NutrientTarget] = [:]
        for target in try deps.program.nutrientTargets() {
            if let key = target.nutrientKey { result[key] = target }
        }
        return result
    }

    /// The effective daily target for a nutrient: custom/stored value when
    /// present, otherwise nil (no goal set).
    public func target(for key: NutrientKey) throws -> NutrientTarget? {
        try deps.program.target(for: key)
    }
}

// MARK: - Insight generation (pure, operates on service outputs)

/// Builds adherence-neutral insights from timing + average data.
/// Pure functions so they stay testable without repositories.
public enum InsightGenerator {
    /// Timing insights for a nutrient (e.g. protein).
    public static func timingInsights(
        key: NutrientKey,
        blocks: [TimingBlock],
        averages: [NutrientKey: Double]
    ) -> [AnalyticsInsight] {
        var insights: [AnalyticsInsight] = []
        guard !blocks.isEmpty else { return insights }
        let total = blocks.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return insights }

        if let evening = blocks.first(where: { $0.block == .evening }),
           let morning = blocks.first(where: { $0.block == .morning }),
           evening.share >= 0.5, morning.share < 0.2 {
            insights.append(AnalyticsInsight(
                title: "Most \(key.displayName.lowercased()) lands in the evening",
                body: "About \(Int(evening.share * 100))% of your \(key.displayName.lowercased()) is logged after 4 PM. Shifting some to earlier in the day can make the rest of the day feel easier.",
                systemIcon: "clock",
                accent: .habit
            ))
        }
        if let night = blocks.first(where: { $0.block == .night }), night.share >= 0.25 {
            insights.append(AnalyticsInsight(
                title: "Late-night logging",
                body: "Roughly \(Int(night.share * 100))% of \(key.displayName.lowercased()) is logged after 10 PM. A slightly earlier last meal often lines up with steadier mornings.",
                systemIcon: "moon",
                accent: .habit
            ))
        }
        if let morning = blocks.first(where: { $0.block == .morning }),
           key == .protein, morning.share >= 0.35 {
            insights.append(AnalyticsInsight(
                title: "Strong protein mornings",
                body: "Over a third of your protein is logged before 11 AM — that pattern lines up well with hitting your daily target.",
                systemIcon: "sunrise",
                accent: .protein
            ))
        }
        if key == .calories, let avg = averages[.calories], avg > 0 {
            let eveningShare = blocks.first(where: { $0.block == .evening })?.share ?? 0
            let morningShare = blocks.first(where: { $0.block == .morning })?.share ?? 0
            if morningShare < 0.15, eveningShare > morningShare * 2 {
                insights.append(AnalyticsInsight(
                    title: "Light mornings, heavy evenings",
                    body: "Mornings average under 15% of the day's calories while evenings run much higher. A bigger breakfast tends to smooth out the day.",
                    systemIcon: "chart.bar",
                    accent: .calories
                ))
            }
        }
        return insights
    }

    /// Coverage insights for micronutrients vs. their targets.
    public static func microCoverageInsights(
        averages: [NutrientKey: Double],
        targets: [NutrientKey: NutrientTarget]
    ) -> [AnalyticsInsight] {
        var insights: [AnalyticsInsight] = []
        let low = NutrientKey.allCases.filter { $0.isMicronutrient }.filter { key in
            guard let avg = averages[key], avg > 0,
                  let target = targets[key], target.targetValue > 0
            else { return false }
            return avg < target.targetValue * 0.67
        }
        for key in low.prefix(3) {
            let avg = averages[key] ?? 0
            let targetValue = targets[key]?.targetValue ?? 0
            insights.append(AnalyticsInsight(
                title: "\(key.displayName) is running low",
                body: "Averaging \(MFFormatNumber(average: avg, unit: key.unit)) vs. a \(MFFormatNumber(average: targetValue, unit: key.unit)) target. The top-contributors list for \(key.displayName) shows which logged foods carry the most of it.",
                systemIcon: "pill.fill",
                accent: .micro
            ))
        }
        return insights
    }

    /// Habit insights from the adherence snapshot.
    public static func habitInsights(_ snapshot: HabitSnapshot) -> [AnalyticsInsight] {
        var insights: [AnalyticsInsight] = []
        if snapshot.loggingStreakDays >= 7 {
            insights.append(AnalyticsInsight(
                title: "\(snapshot.loggingStreakDays)-day logging streak",
                body: "Consistent logging is what makes expenditure estimates reliable — keep the streak going.",
                systemIcon: "flame",
                accent: .habit
            ))
        }
        if snapshot.totalDays >= 14 {
            let hitRate = Double(snapshot.daysNearCalorieTarget) / Double(max(snapshot.loggedDays, 1))
            if hitRate < 0.5, snapshot.loggedDays >= 7 {
                insights.append(AnalyticsInsight(
                    title: "Calorie targets are often missed",
                    body: "About \(Int(hitRate * 100))% of logged days land near your calorie target. If targets feel hard to reach, the Strategy tab can retune them.",
                    systemIcon: "target",
                    accent: .calories
                ))
            }
        }
        if snapshot.totalWeeks >= 2 {
            let weighRate = Double(snapshot.weeksWithWeighIn) / Double(snapshot.totalWeeks)
            if weighRate < 0.75 {
                insights.append(AnalyticsInsight(
                    title: "Weigh in more often",
                    body: "Weeks with at least one weigh-in keep the trend line honest. Even one consistent morning weigh-in per week helps.",
                    systemIcon: "scalemass",
                    accent: .weight
                ))
            }
        }
        return insights
    }

    /// Small number formatting helper without DesignSystem import.
    private static func MFFormatNumber(average: Double, unit: String) -> String {
        let value = average.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(average))
            : String(format: "%.1f", average)
        return "\(value) \(unit)"
    }
}
