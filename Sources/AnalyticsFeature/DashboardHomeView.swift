import SwiftUI
import Charts
import DesignSystem
import DataLayer
import CoachingEngine

// MARK: - DashboardHomeView

/// The Dashboard tab: today's macro ring, expenditure + weight cards,
/// nutrition averages, micronutrient snapshot, and links to every
/// analytics dashboard.
struct DashboardHomeView: View {
    private let dependencies: AnalyticsDependencies
    @State private var isLoading = true

    // Today
    @State private var todayTotals = MFDayTotals()
    @State private var calorieTarget: Double = 0
    @State private var proteinTarget: Double = 0
    @State private var fatTarget: Double = 0
    @State private var carbsTarget: Double = 0

    // Expenditure + weight cards
    @State private var expenditurePoints: [ExpenditurePoint] = []
    @State private var weightPoints: [WeightPoint] = []
    @State private var weightUnit: WeightUnit = .pounds
    @State private var goalType: GoalType = .maintain

    // Nutrition averages (8 weeks) + micros preview
    @State private var weeklyAverages: [WeeklyNutrition] = []
    @State private var lowMicros: [(key: NutrientKey, average: Double, target: Double)] = []
    @State private var hasAnyData = false

    init(dependencies: AnalyticsDependencies) {
        self.dependencies = dependencies
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading dashboard…")
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .padding(.top, MFSpacing.xxl)
            } else if !hasAnyData {
                AnalyticsEmptyState(
                    title: "No data yet",
                    body: "Log food and weigh in to unlock your dashboards. Charts, insights, and micronutrient tracking appear here once there's history to analyze.",
                    systemIcon: "chart.line.uptrend.xyaxis"
                )
                .padding()
            } else {
                VStack(spacing: MFSpacing.lg) {
                    todayRingCard
                    expenditureCardLink
                    weightCardLink
                    averagesCardLink
                    microsCardLink
                    insightsLink
                }
                .padding()
            }
        }
        .background(MFColor.background)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Sections

    private var todayRingCard: some View {
        VStack(spacing: MFSpacing.md) {
            HStack {
                Text("Today")
                    .font(MFFont.headline)
                    .foregroundColor(MFColor.textPrimary)
                Spacer()
            }
            MFMacroRing(
                caloriesEaten: todayTotals.calories,
                calorieTarget: calorieTarget,
                macros: [
                    .init(name: "Protein", eaten: todayTotals.protein, target: proteinTarget, kcalPerGram: 4, color: MFColor.protein),
                    .init(name: "Carbs", eaten: todayTotals.carbs, target: carbsTarget, kcalPerGram: 4, color: MFColor.carbs),
                    .init(name: "Fat", eaten: todayTotals.fat, target: fatTarget, kcalPerGram: 9, color: MFColor.fat),
                ],
                diameter: 190
            )
        }
        .mfCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today: \(MFFormat.kcal(todayTotals.calories)) of \(MFFormat.kcal(calorieTarget)) calories")
    }

    private var expenditureCardLink: some View {
        NavigationLink {
            ExpenditureDashboardView(dependencies: dependencies)
        } label: {
            VStack(alignment: .leading, spacing: MFSpacing.sm) {
                HStack {
                    Text("Expenditure")
                        .font(MFFont.headline)
                        .foregroundColor(MFColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(MFColor.textTertiary)
                        .accessibilityHidden(true)
                }
                if expenditurePoints.isEmpty {
                    Text("Not enough data for an estimate yet — keep logging and weighing in.")
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textSecondary)
                } else {
                    MFExpenditureChartCard(
                        points: expenditurePoints.map(\.estimateKcal),
                        band: expenditurePoints.map(\.band),
                        average: expenditurePoints.map(\.estimateKcal).reduce(0, +) / Double(max(expenditurePoints.count, 1))
                    )
                }
            }
            .mfCard()
        }
        .buttonStyle(.plain)
    }

    private var weightCardLink: some View {
        NavigationLink {
            WeightTrendDashboardView(dependencies: dependencies)
        } label: {
            VStack(alignment: .leading, spacing: MFSpacing.sm) {
                HStack {
                    Text("Weight")
                        .font(MFFont.headline)
                        .foregroundColor(MFColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(MFColor.textTertiary)
                        .accessibilityHidden(true)
                }
                if weightPoints.isEmpty {
                    Text("Weigh in to start your trend line — one consistent morning weigh-in a week is enough.")
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textSecondary)
                } else {
                    let display = weightPoints.map { weightUnit.fromKilograms($0.trendKg) }
                    let current = display.last ?? 0
                    let delta = current - (display.first ?? current)
                    MFWeightTrendChartCard(
                        points: display,
                        unit: weightUnit == .pounds ? "lb" : "kg",
                        current: current,
                        delta: delta,
                        deltaIsGood: deltaIsGood(delta)
                    )
                }
            }
            .mfCard()
        }
        .buttonStyle(.plain)
    }

    private var averagesCardLink: some View {
        NavigationLink {
            NutritionDashboardView(dependencies: dependencies)
        } label: {
            VStack(alignment: .leading, spacing: MFSpacing.md) {
                HStack {
                    Text("Nutrition averages")
                        .font(MFFont.headline)
                        .foregroundColor(MFColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(MFColor.textTertiary)
                        .accessibilityHidden(true)
                }
                if weeklyAverages.isEmpty {
                    Text("Log food for a few days to see weekly averages.")
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textSecondary)
                } else {
                    Chart(weeklyAverages) { week in
                        BarMark(
                            x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Calories", week.avgCalories)
                        )
                        .foregroundStyle(MFColor.calories)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel { Text("\(MFFormat.kcal(value.as(Double.self) ?? 0))") }
                            AxisGridLine()
                        }
                    }
                    .frame(height: 150)
                    .accessibilityLabel("Weekly average calories chart")
                }
            }
            .mfCard()
        }
        .buttonStyle(.plain)
    }

    private var microsCardLink: some View {
        NavigationLink {
            MicronutrientDashboardView(dependencies: dependencies)
        } label: {
            VStack(alignment: .leading, spacing: MFSpacing.md) {
                HStack {
                    Text("Micronutrients")
                        .font(MFFont.headline)
                        .foregroundColor(MFColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(MFColor.textTertiary)
                        .accessibilityHidden(true)
                }
                if lowMicros.isEmpty {
                    Text("Micronutrient coverage looks on track — open the full list to edit custom targets.")
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textSecondary)
                } else {
                    VStack(spacing: MFSpacing.sm) {
                        ForEach(lowMicros, id: \.key) { item in
                            HStack(spacing: MFSpacing.md) {
                                Image(systemName: "pill.fill")
                                    .font(.body)
                                    .foregroundColor(MFColor.micro)
                                    .frame(width: 36, height: 36)
                                    .background(MFColor.micro.opacity(0.14))
                                    .clipShape(Circle())
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.key.displayName)
                                        .font(MFFont.body)
                                        .foregroundColor(MFColor.textPrimary)
                                    Text("avg \(MFAnalyticsFormat.amount(item.average, key: item.key)) · target \(MFAnalyticsFormat.amount(item.target, key: item.key))")
                                        .font(MFFont.caption)
                                        .monospacedDigit()
                                        .foregroundColor(MFColor.textSecondary)
                                }
                                Spacer()
                                Text(MFAnalyticsFormat.percent(item.target > 0 ? item.average / item.target : 0))
                                    .font(MFFont.statSmall)
                                    .monospacedDigit()
                                    .foregroundColor(MFColor.micro)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(item.key.displayName): averaging \(MFAnalyticsFormat.amount(item.average, key: item.key)) of \(MFAnalyticsFormat.amount(item.target, key: item.key)) target")
                        }
                    }
                }
            }
            .mfCard()
        }
        .buttonStyle(.plain)
    }

    private var insightsLink: some View {
        NavigationLink {
            InsightsDashboardView(dependencies: dependencies)
        } label: {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.body)
                    .foregroundColor(MFColor.accent)
                    .frame(width: 36, height: 36)
                    .background(MFColor.accentSoft)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Insights & habits")
                        .font(MFFont.bodyBold)
                        .foregroundColor(MFColor.textPrimary)
                    Text("Nutrient timing, streaks, and adherence")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(MFColor.textTertiary)
                    .accessibilityHidden(true)
            }
            .mfCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading

    private func load() async {
        let svc = AnalyticsDataService(dependencies: dependencies)
        do {
            let today = MFDates.startOfDay(Date())
            todayTotals = try dependencies.logs.dayTotals(today)
            let settings = try dependencies.program.settings()
            calorieTarget = settings.currentCalories
            proteinTarget = settings.currentProteinGrams
            fatTarget = settings.currentFatGrams
            carbsTarget = settings.currentCarbsGrams
            weightUnit = settings.weightUnit
            goalType = settings.goalType

            expenditurePoints = try svc.expenditureSeries(last: 84)
            weightPoints = try svc.weightSeries(last: 28)
            weeklyAverages = try svc.weeklyNutrition(weeks: 8)

            // Lowest-coverage micros over the last 28 days.
            let (averages, loggedDays) = try svc.nutrientAverages(last: 28)
            let targets = try svc.allTargets()
            lowMicros = NutrientKey.allCases
                .filter { $0.isMicronutrient }
                .compactMap { key -> (NutrientKey, Double, Double)? in
                    guard let avg = averages[key], avg > 0,
                          let target = targets[key], target.targetValue > 0,
                          avg < target.targetValue
                    else { return nil }
                    return (key, avg, target.targetValue)
                }
                .sorted { ($0.1 / $0.2) < ($1.1 / $1.2) }
                .prefix(3)
                .map { (key: $0.0, average: $0.1, target: $0.2) }

            hasAnyData = loggedDays > 0 || !weightPoints.isEmpty
        } catch {
            hasAnyData = false
        }
        isLoading = false
    }

    private func deltaIsGood(_ delta: Double) -> Bool {
        switch goalType {
        case .cut: return delta <= 0
        case .bulk: return delta >= 0
        case .maintain: return abs(delta) < 0.5
        }
    }
}
