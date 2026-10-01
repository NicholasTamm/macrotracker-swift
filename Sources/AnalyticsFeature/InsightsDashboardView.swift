import SwiftUI
import Charts
import DesignSystem
import DataLayer

// MARK: - InsightsDashboardView

/// Insights + habit views: nutrient-timing analysis, adherence stats,
/// streaks, weigh-in frequency, and generated insight cards.
/// All copy is original and adherence-neutral.
public struct InsightsDashboardView: View {
    private let dependencies: AnalyticsDependencies
    @State private var range: AnalyticsRange = .quarter
    @State private var insights: [AnalyticsInsight] = []
    @State private var snapshot: HabitSnapshot?
    @State private var weeklyLoggedDays: [(weekStart: Date, days: Int)] = []
    @State private var isLoading = true

    public init(dependencies: AnalyticsDependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: MFSpacing.lg) {
                AnalyticsRangePicker(range: $range)
                    .onChange(of: range) { _, _ in Task { await load() } }

                if isLoading {
                    ProgressView("Finding insights…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let snapshot {
                    habitSummaryCard(snapshot)
                    if insights.isEmpty {
                        AnalyticsEmptyState(
                            title: "Nothing to flag",
                            body: "No patterns stand out right now — that's a good sign. Keep logging and check back after a few more weeks of data.",
                            systemIcon: "checkmark.circle"
                        )
                        .mfCard()
                    } else {
                        insightsCard
                    }
                    loggingChartCard
                } else {
                    AnalyticsEmptyState(
                        title: "No data yet",
                        body: "Log food and weigh in to unlock insights about your timing, habits, and patterns.",
                        systemIcon: "lightbulb"
                    )
                    .mfCard()
                }
            }
            .padding()
        }
        .background(MFColor.background)
        .navigationTitle("Insights")
        .task { await load() }
    }

    // MARK: - Cards

    private func habitSummaryCard(_ snapshot: HabitSnapshot) -> some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            AnalyticsSectionHeader("Habits", subtitle: range.title)
            HStack(spacing: MFSpacing.md) {
                MFStreakCell(days: snapshot.loggingStreakDays, caption: "day logging streak")
                    .mfCard()
                VStack(spacing: MFSpacing.sm) {
                    habitStat(
                        value: snapshot.loggedDays,
                        total: snapshot.totalDays,
                        label: "days logged"
                    )
                    Divider().background(MFColor.separator)
                    habitStat(
                        value: snapshot.weeksWithWeighIn,
                        total: snapshot.totalWeeks,
                        label: "weeks with weigh-in"
                    )
                }
                .mfCard()
            }
            HStack(spacing: MFSpacing.md) {
                adherenceStat(
                    title: "Near calorie target",
                    days: snapshot.daysNearCalorieTarget,
                    logged: snapshot.loggedDays,
                    color: MFColor.calories
                )
                .mfCard()
                adherenceStat(
                    title: "Hit protein target",
                    days: snapshot.daysHitProteinTarget,
                    logged: snapshot.loggedDays,
                    color: MFColor.protein
                )
                .mfCard()
            }
        }
    }

    private func habitStat(value: Int, total: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)/\(total)")
                .font(MFFont.statMedium)
                .monospacedDigit()
                .foregroundColor(MFColor.textPrimary)
            Text(label)
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MFSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) of \(total) \(label)")
    }

    private func adherenceStat(title: String, days: Int, logged: Int, color: Color) -> some View {
        let rate = logged > 0 ? Double(days) / Double(logged) : 0
        return VStack(alignment: .leading, spacing: MFSpacing.xs) {
            Text(title)
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
            Text("\(days) days")
                .font(MFFont.statSmall)
                .monospacedDigit()
                .foregroundColor(MFColor.textPrimary)
            AnalyticsProgressBar(progress: rate, color: color)
            Text("\(MFAnalyticsFormat.percent(rate)) of logged days")
                .font(MFFont.caption2)
                .foregroundColor(MFColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(days) days, \(MFAnalyticsFormat.percent(rate)) of logged days")
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            AnalyticsSectionHeader("What we notice", subtitle: "\(insights.count) insights from your data")
            VStack(spacing: MFSpacing.sm) {
                ForEach(insights) { insight in
                    InsightRow(insight: insight)
                }
            }
        }
        .mfCard()
    }

    private var loggingChartCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            AnalyticsSectionHeader("Logging consistency", subtitle: "Logged days per week")
            if weeklyLoggedDays.isEmpty {
                Text("Log food to see your consistency over time.")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
            } else {
                Chart(weeklyLoggedDays, id: \.weekStart) { week in
                    BarMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Days", week.days)
                    )
                    .foregroundStyle(MFColor.accent)
                    .cornerRadius(4)
                }
                .chartYScale(domain: 0...7)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 2, 4, 6, 7]) { value in
                        AxisValueLabel { Text("\(Int(value.as(Double.self) ?? 0))") }
                        AxisGridLine()
                    }
                }
                .frame(height: 160)
                .accessibilityLabel("Logged days per week chart")
            }
        }
        .mfCard()
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        do {
            let service = AnalyticsDataService(dependencies: dependencies)
            let snap = try service.habitSnapshot(last: range.days)
            snapshot = snap
            guard snap.loggedDays > 0 else {
                snapshot = nil
                insights = []
                weeklyLoggedDays = []
                isLoading = false
                return
            }

            var generated: [AnalyticsInsight] = []
            let (averages, _) = try service.nutrientAverages(last: range.days)

            for key in [NutrientKey.calories, .protein] {
                let blocks = try service.timingBreakdown(key: key, last: range.days)
                generated += InsightGenerator.timingInsights(key: key, blocks: blocks, averages: averages)
            }
            generated += InsightGenerator.microCoverageInsights(
                averages: averages,
                targets: try service.allTargets()
            )
            generated += InsightGenerator.habitInsights(snap)
            insights = generated

            let daily = try service.dailyNutrition(last: range.days)
            var weeks: [Date: Int] = [:]
            let calendar = Calendar.current
            for day in daily where day.totals.entryCount > 0 {
                let weekStart = calendar.date(
                    from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day.dayStart)
                ) ?? day.dayStart
                weeks[weekStart, default: 0] += 1
            }
            weeklyLoggedDays = weeks
                .sorted { $0.key < $1.key }
                .map { (weekStart: $0.key, days: $0.value) }
        } catch {
            snapshot = nil
            insights = []
            weeklyLoggedDays = []
        }
        isLoading = false
    }
}

// MARK: - InsightRow

/// One generated insight: tinted icon well + title + body.
public struct InsightRow: View {
    private let insight: AnalyticsInsight

    public init(insight: AnalyticsInsight) {
        self.insight = insight
    }

    public var body: some View {
        let accent = MFAnalyticsColor.forAccent(insight.accent)
        return HStack(alignment: .top, spacing: MFSpacing.md) {
            Image(systemName: insight.systemIcon)
                .font(.body)
                .foregroundColor(accent)
                .frame(width: 36, height: 36)
                .background(accent.opacity(0.14))
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(MFFont.bodyBold)
                    .foregroundColor(MFColor.textPrimary)
                Text(insight.body)
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
            }
        }
        .padding(.vertical, MFSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title). \(insight.body)")
    }
}
