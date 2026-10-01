import SwiftUI
import Charts
import DesignSystem
import DataLayer
import CoachingEngine

// MARK: - ExpenditureDashboardView

/// Expenditure dashboard: rolling energy-balance estimates over time with
/// confidence flux bands (orange), built on CoachingEngine output.
public struct ExpenditureDashboardView: View {
    private let dependencies: AnalyticsDependencies
    @State private var range: AnalyticsRange = .quarter
    @State private var points: [ExpenditurePoint] = []
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
                    ProgressView("Estimating expenditure…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if points.isEmpty {
                    AnalyticsEmptyState(
                        title: "No estimate yet",
                        body: "Expenditure is back-calculated from your logged intake and weight trend. Log food and weigh in for at least a week to see your first estimate.",
                        systemIcon: "flame"
                    )
                    .mfCard()
                } else {
                    headerCard
                    chartCard
                    explainerCard
                }
            }
            .padding()
        }
        .background(MFColor.background)
        .navigationTitle("Expenditure")
        .task { await load() }
    }

    private var latest: ExpenditurePoint? { points.last }

    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current estimate")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: MFSpacing.sm) {
                    Text(MFFormat.kcal(latest?.estimateKcal ?? 0))
                        .font(MFFont.statLarge)
                        .monospacedDigit()
                        .foregroundColor(MFColor.textPrimary)
                    Text("kcal/day")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }
                if let latest {
                    Text(confidenceCopy(latest.confidence))
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundColor(MFColor.expenditure)
                .frame(width: 56, height: 56)
                .background(MFColor.expenditure.opacity(0.14))
                .clipShape(Circle())
                .accessibilityHidden(true)
        }
        .mfCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current expenditure estimate: \(MFFormat.kcal(latest?.estimateKcal ?? 0)) calories per day")
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            AnalyticsSectionHeader("Estimate history", subtitle: range.title)
            Chart(points) { point in
                AreaMark(
                    x: .value("Date", point.endDate),
                    yStart: .value("Low", point.band.low),
                    yEnd: .value("High", point.band.high)
                )
                .foregroundStyle(MFColor.expenditure.opacity(0.16))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", point.endDate),
                    y: .value("Estimate", point.estimateKcal)
                )
                .foregroundStyle(MFColor.expenditure)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.endDate),
                    y: .value("Estimate", point.estimateKcal)
                )
                .foregroundStyle(MFColor.expenditure)
                .symbolSize(60)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel { Text(MFFormat.kcal(value.as(Double.self) ?? 0)) }
                    AxisGridLine()
                }
            }
            .frame(height: 220)
            .accessibilityLabel("Expenditure estimate history, \(range.title)")
        }
        .mfCard()
    }

    private var explainerCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            AnalyticsSectionHeader("How it's estimated")
            Text("Your expenditure is back-calculated from average logged intake minus the energy stored or released as your weight trend changes. The shaded band shows the confidence range — it narrows as logging and weigh-ins get more consistent. Smartwatch calorie estimates are never used.")
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textSecondary)
        }
        .mfCard()
    }

    private func confidenceCopy(_ confidence: Double) -> String {
        switch confidence {
        case ..<0.4: return "Low confidence — log and weigh in more consistently"
        case ..<0.75: return "Moderate confidence"
        default: return "High confidence"
        }
    }

    private func load() async {
        isLoading = true
        do {
            let service = AnalyticsDataService(dependencies: dependencies)
            points = try service.expenditureSeries(last: range.days)
        } catch {
            points = []
        }
        isLoading = false
    }
}

// MARK: - WeightTrendDashboardView

/// Weight-trend dashboard: raw weigh-ins (dots) + smoothed trend line
/// (purple), rate chip, and weigh-in consistency stats.
public struct WeightTrendDashboardView: View {
    private let dependencies: AnalyticsDependencies
    @State private var range: AnalyticsRange = .quarter
    @State private var points: [WeightPoint] = []
    @State private var rateKgPerWeek: Double?
    @State private var weightUnit: WeightUnit = .pounds
    @State private var goalType: GoalType = .maintain
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
                    ProgressView("Loading weight trend…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if points.isEmpty {
                    AnalyticsEmptyState(
                        title: "No weigh-ins yet",
                        body: "Log your first weigh-in to start the trend line. One consistent morning weigh-in per week is enough for a useful trend.",
                        systemIcon: "scalemass"
                    )
                    .mfCard()
                } else {
                    headerCard
                    chartCard
                    consistencyCard
                }
            }
            .padding()
        }
        .background(MFColor.background)
        .navigationTitle("Weight trend")
        .task { await load() }
    }

    private var unitLabel: String { weightUnit == .pounds ? "lb" : "kg" }

    private var currentTrend: Double {
        weightUnit.fromKilograms(points.last?.trendKg ?? 0)
    }

    private var rateDisplay: Double? {
        rateKgPerWeek.map { weightUnit.fromKilograms($0) }
    }

    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trend weight")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: MFSpacing.sm) {
                    Text(String(format: "%.1f", currentTrend))
                        .font(MFFont.statLarge)
                        .monospacedDigit()
                        .foregroundColor(MFColor.textPrimary)
                    Text(unitLabel)
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }
                if let rate = rateDisplay {
                    Text("\(MFAnalyticsFormat.signedChange(rate, unit: "\(unitLabel)/wk")) trend")
                        .font(MFFont.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(rateIsGood(rate) ? MFColor.success : MFColor.warning)
                }
            }
            Spacer()
            Image(systemName: "scalemass.fill")
                .font(.title)
                .foregroundColor(MFColor.weightTrend)
                .frame(width: 56, height: 56)
                .background(MFColor.weightTrend.opacity(0.14))
                .clipShape(Circle())
                .accessibilityHidden(true)
        }
        .mfCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trend weight: \(String(format: "%.1f", currentTrend)) \(unitLabel)")
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            AnalyticsSectionHeader("Trend", subtitle: "\(range.title) · dots are weigh-ins")
            Chart {
                // Smoothed trend area + line (one mark per point; Charts
                // connects them into a continuous series).
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Trend", weightUnit.fromKilograms(point.trendKg))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [MFColor.weightTrend.opacity(0.28), MFColor.weightTrend.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                ForEach(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Trend", weightUnit.fromKilograms(point.trendKg))
                    )
                    .foregroundStyle(MFColor.weightTrend)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }
                // Raw weigh-ins as dots.
                ForEach(points.filter { $0.sampleKg != nil }) { point in
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weigh-in", weightUnit.fromKilograms(point.sampleKg ?? 0))
                    )
                    .foregroundStyle(MFColor.weightTrend)
                    .symbolSize(50)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel { Text(String(format: "%.0f", value.as(Double.self) ?? 0)) }
                    AxisGridLine()
                }
            }
            .frame(height: 220)
            .accessibilityLabel("Weight trend chart, \(range.title)")
        }
        .mfCard()
    }

    private var consistencyCard: some View {
        let sampledDays = points.filter { $0.sampleKg != nil }.count
        return VStack(alignment: .leading, spacing: MFSpacing.sm) {
            AnalyticsSectionHeader("Weigh-in consistency")
            HStack {
                Text("\(sampledDays) weigh-ins")
                    .font(MFFont.statMedium)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textPrimary)
                Spacer()
                Text("over \(range.title.lowercased())")
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            }
            AnalyticsProgressBar(progress: Double(sampledDays) / Double(max(points.count, 1)), color: MFColor.weightTrend)
            Text("Smoothed with an exponential moving average — single-day fluctuations don't move the trend much.")
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
        }
        .mfCard()
    }

    private func rateIsGood(_ rate: Double) -> Bool {
        switch goalType {
        case .cut: return rate <= 0
        case .bulk: return rate >= 0
        case .maintain: return abs(rate) < 0.25
        }
    }

    private func load() async {
        isLoading = true
        do {
            let service = AnalyticsDataService(dependencies: dependencies)
            points = try service.weightSeries(last: range.days)
            rateKgPerWeek = try service.weightRate(last: range.days)
            let settings = try dependencies.program.settings()
            weightUnit = settings.weightUnit
            goalType = settings.goalType
        } catch {
            points = []
            rateKgPerWeek = nil
        }
        isLoading = false
    }
}
