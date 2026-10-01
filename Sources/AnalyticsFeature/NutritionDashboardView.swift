import SwiftUI
import Charts
import DesignSystem
import DataLayer

// MARK: - NutritionDashboardView

/// Nutrition dashboard: weekly/monthly/historical averages, macro trend
/// charts, macro-split donut, top contributors for any nutrient, and
/// nutrient-timing insights.
public struct NutritionDashboardView: View {
    private let dependencies: AnalyticsDependencies
    @State private var range: AnalyticsRange = .quarter
    @State private var weekly: [WeeklyNutrition] = []
    @State private var calorieTarget: Double = 0
    @State private var isLoading = true

    // Top contributors
    @State private var contributorKey: NutrientKey = .protein
    @State private var contributors: [NutrientContributor] = []

    // Timing
    @State private var timingKey: NutrientKey = .calories
    @State private var timingBlocks: [TimingBlock] = []
    @State private var timingInsights: [AnalyticsInsight] = []
    @State private var averages: [NutrientKey: Double] = [:]

    public init(dependencies: AnalyticsDependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: MFSpacing.lg) {
                AnalyticsRangePicker(range: $range)
                    .onChange(of: range) { _, _ in Task { await load() } }

                if isLoading {
                    ProgressView("Analyzing nutrition…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if weekly.isEmpty {
                    AnalyticsEmptyState(
                        title: "No nutrition data yet",
                        body: "Log food to see weekly and monthly averages, macro trends, and top contributors.",
                        systemIcon: "chart.bar"
                    )
                    .mfCard()
                } else {
                    calorieChartCard
                    macroTrendCard
                    macroSplitCard
                    contributorsCard
                    timingCard
                }
            }
            .padding()
        }
        .background(MFColor.background)
        .navigationTitle("Nutrition")
        .task { await load() }
    }

    // MARK: - Cards

    private var calorieChartCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            AnalyticsSectionHeader("Average calories", subtitle: "Per week · logged days only")
            Chart(weekly) { week in
                BarMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Calories", week.avgCalories)
                )
                .foregroundStyle(MFColor.calories)
                .cornerRadius(4)
                if calorieTarget > 0 {
                    RuleMark(y: .value("Target", calorieTarget))
                        .foregroundStyle(MFColor.textTertiary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel { Text(MFFormat.kcal(value.as(Double.self) ?? 0)) }
                    AxisGridLine()
                }
            }
            .frame(height: 180)
            .accessibilityLabel("Weekly average calories chart")
        }
        .mfCard()
    }

    private var macroTrendCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            AnalyticsSectionHeader("Macro trends", subtitle: "Weekly averages, grams")
            Chart(weekly) { week in
                LineMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Protein", week.avgProtein),
                    series: .value("Macro", "Protein")
                )
                .foregroundStyle(MFColor.protein)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Fat", week.avgFat),
                    series: .value("Macro", "Fat")
                )
                .foregroundStyle(MFColor.fat)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Carbs", week.avgCarbs),
                    series: .value("Macro", "Carbs")
                )
                .foregroundStyle(MFColor.carbs)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Protein", week.avgProtein),
                    series: .value("Macro", "Protein")
                )
                .foregroundStyle(MFColor.protein)
                .symbolSize(40)
            }
            .chartForegroundStyleScale([
                "Protein": MFColor.protein,
                "Fat": MFColor.fat,
                "Carbs": MFColor.carbs,
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel { Text("\(Int(value.as(Double.self) ?? 0))g") }
                    AxisGridLine()
                }
            }
            .frame(height: 200)
            .accessibilityLabel("Weekly macro trends chart")
            HStack(spacing: MFSpacing.lg) {
                legendDot(color: MFColor.protein, label: "Protein")
                legendDot(color: MFColor.fat, label: "Fat")
                legendDot(color: MFColor.carbs, label: "Carbs")
            }
            .accessibilityHidden(true)
        }
        .mfCard()
    }

    private var macroSplitCard: some View {
        let avgP = weekly.map(\.avgProtein).reduce(0, +) / Double(max(weekly.count, 1))
        let avgF = weekly.map(\.avgFat).reduce(0, +) / Double(max(weekly.count, 1))
        let avgC = weekly.map(\.avgCarbs).reduce(0, +) / Double(max(weekly.count, 1))
        let kcalP = avgP * 4, kcalF = avgF * 9, kcalC = avgC * 4
        let total = kcalP + kcalF + kcalC
        let slices: [(String, Double, Color)] = total > 0
            ? [("Protein", kcalP / total, MFColor.protein),
               ("Fat", kcalF / total, MFColor.fat),
               ("Carbs", kcalC / total, MFColor.carbs)]
            : []
        return VStack(alignment: .leading, spacing: MFSpacing.md) {
            AnalyticsSectionHeader("Macro split", subtitle: "Share of calories, \(range.title.lowercased())")
            if slices.isEmpty {
                Text("Not enough data.")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
            } else {
                HStack(spacing: MFSpacing.xl) {
                    Chart(slices, id: \.0) { slice in
                        SectorMark(
                            angle: .value("Share", slice.1),
                            innerRadius: .ratio(0.62),
                            angularInset: 2
                        )
                        .foregroundStyle(slice.2)
                    }
                    .frame(width: 140, height: 140)
                    .accessibilityLabel("Macro split: protein \(MFAnalyticsFormat.percent(slices[0].1)), fat \(MFAnalyticsFormat.percent(slices[1].1)), carbs \(MFAnalyticsFormat.percent(slices[2].1))")
                    VStack(alignment: .leading, spacing: MFSpacing.sm) {
                        ForEach(slices, id: \.0) { slice in
                            HStack {
                                legendDot(color: slice.2, label: slice.0)
                                Spacer()
                                Text(MFAnalyticsFormat.percent(slice.1))
                                    .font(MFFont.statSmall)
                                    .monospacedDigit()
                                    .foregroundColor(MFColor.textPrimary)
                            }
                        }
                    }
                }
            }
        }
        .mfCard()
    }

    private var contributorsCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            HStack {
                AnalyticsSectionHeader("Top contributors")
                Spacer()
                Picker("Nutrient", selection: $contributorKey) {
                    ForEach(NutrientKey.allCases, id: \.self) { key in
                        Text(key.displayName).tag(key)
                    }
                }
                .pickerStyle(.menu)
                .tint(MFColor.accent)
                .onChange(of: contributorKey) { _, _ in Task { await loadContributors() } }
            }
            if contributors.isEmpty {
                Text("Nothing logged with \(contributorKey.displayName.lowercased()) in this range yet.")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
            } else {
                VStack(spacing: MFSpacing.sm) {
                    ForEach(contributors) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.foodName)
                                    .font(MFFont.body)
                                    .foregroundColor(MFColor.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(MFAnalyticsFormat.amount(item.amount, key: contributorKey)) · \(MFAnalyticsFormat.percent(item.share))")
                                    .font(MFFont.caption)
                                    .monospacedDigit()
                                    .foregroundColor(MFColor.textSecondary)
                            }
                            AnalyticsProgressBar(progress: item.share, color: MFAnalyticsColor.forNutrient(contributorKey))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.foodName): \(MFAnalyticsFormat.amount(item.amount, key: contributorKey)), \(MFAnalyticsFormat.percent(item.share)) of total")
                    }
                }
            }
        }
        .mfCard()
    }

    private var timingCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            HStack {
                AnalyticsSectionHeader("Nutrient timing")
                Spacer()
                Picker("Nutrient", selection: $timingKey) {
                    ForEach([NutrientKey.calories, .protein, .fat, .carbs], id: \.self) { key in
                        Text(key.displayName).tag(key)
                    }
                }
                .pickerStyle(.menu)
                .tint(MFColor.accent)
                .onChange(of: timingKey) { _, _ in Task { await loadTiming() } }
            }
            if timingBlocks.isEmpty {
                Text("Log food to see when your \(timingKey.displayName.lowercased()) lands through the day.")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
            } else {
                Chart(timingBlocks) { block in
                    BarMark(
                        x: .value("Time", block.block.title),
                        y: .value("Share", block.share * 100)
                    )
                    .foregroundStyle(MFAnalyticsColor.forNutrient(timingKey))
                    .cornerRadius(6)
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel { Text("\(Int(value.as(Double.self) ?? 0))%") }
                        AxisGridLine()
                    }
                }
                .frame(height: 160)
                .accessibilityLabel("\(timingKey.displayName) by time of day")
            }
            ForEach(timingInsights) { insight in
                InsightRow(insight: insight)
            }
        }
        .mfCard()
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        do {
            let service = AnalyticsDataService(dependencies: dependencies)
            let weeks = max(1, range.days / 7)
            weekly = try service.weeklyNutrition(weeks: weeks)
            calorieTarget = try dependencies.program.settings().currentCalories
            let (avg, _) = try service.nutrientAverages(last: range.days)
            averages = avg
            await loadContributors()
            await loadTiming()
        } catch {
            weekly = []
        }
        isLoading = false
    }

    private func loadContributors() async {
        do {
            let service = AnalyticsDataService(dependencies: dependencies)
            contributors = try service.topContributors(key: contributorKey, last: range.days)
        } catch {
            contributors = []
        }
    }

    private func loadTiming() async {
        do {
            let service = AnalyticsDataService(dependencies: dependencies)
            timingBlocks = try service.timingBreakdown(key: timingKey, last: range.days)
            timingInsights = InsightGenerator.timingInsights(key: timingKey, blocks: timingBlocks, averages: averages)
        } catch {
            timingBlocks = []
            timingInsights = []
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: MFSpacing.xs) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(MFFont.caption).foregroundColor(MFColor.textSecondary)
        }
    }
}
