import SwiftUI
import Charts
import DesignSystem
import DataLayer

// MARK: - Micro sections

private enum MicroSection: String, CaseIterable {
    case headline = "Energy & macros"
    case minerals = "Minerals"
    case vitamins = "Vitamins"
    case other = "Other nutrients"

    var keys: [NutrientKey] {
        switch self {
        case .headline:
            return [.calories, .protein, .fat, .carbs]
        case .minerals:
            return [.sodium, .potassium, .calcium, .iron, .magnesium, .phosphorus,
                    .zinc, .copper, .manganese, .selenium, .iodine]
        case .vitamins:
            return [.vitaminA, .vitaminC, .vitaminD, .vitaminE, .vitaminK,
                    .thiamin, .riboflavin, .niacin, .vitaminB6, .folate, .vitaminB12]
        case .other:
            return [.fiber, .sugar, .saturatedFat, .transFat, .cholesterol, .alcohol, .caffeine]
        }
    }
}

// MARK: - MicronutrientDashboardView

/// Full micronutrient tracking: every nutrient in the `NutrientKey` catalog
/// with 28-day averages, progress vs. targets, and custom target editing.
/// Nutrient identity always comes from DataLayer — never a hardcoded list.
public struct MicronutrientDashboardView: View {
    private let dependencies: AnalyticsDependencies
    @State private var averages: [NutrientKey: Double] = [:]
    @State private var targets: [NutrientKey: NutrientTarget] = [:]
    @State private var loggedDays = 0
    @State private var searchText = ""
    @State private var isLoading = true

    public init(dependencies: AnalyticsDependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: MFSpacing.lg) {
                if isLoading {
                    ProgressView("Loading nutrients…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    summaryCard
                    ForEach(MicroSection.allCases, id: \.self) { section in
                        sectionCard(section)
                    }
                }
            }
            .padding()
        }
        .background(MFColor.background)
        .navigationTitle("Micronutrients")
        .searchable(text: $searchText, prompt: "Search nutrients")
        .task { await load() }
        .refreshable { await load() }
    }

    private var filteredKeys: [MicroSection: [NutrientKey]] {
        var result: [MicroSection: [NutrientKey]] = [:]
        for section in MicroSection.allCases {
            let keys = section.keys.filter { key in
                searchText.isEmpty ||
                    key.displayName.localizedCaseInsensitiveContains(searchText)
            }
            if !keys.isEmpty { result[section] = keys }
        }
        return result
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            AnalyticsSectionHeader(
                "Coverage",
                subtitle: loggedDays > 0
                    ? "28-day averages over \(loggedDays) logged days"
                    : "Log food to see coverage"
            )
            if loggedDays > 0 {
                let covered = NutrientKey.allCases.filter { $0.isMicronutrient }.filter { key in
                    guard let avg = averages[key], let target = targets[key], target.targetValue > 0
                    else { return false }
                    return avg >= target.targetValue * 0.67
                }.count
                let total = NutrientKey.allCases.filter(\.isMicronutrient).count
                HStack {
                    Text("\(covered) of \(total)")
                        .font(MFFont.statMedium)
                        .monospacedDigit()
                        .foregroundColor(MFColor.textPrimary)
                    Text("micronutrients at ⅔+ of target")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                    Spacer()
                }
                AnalyticsProgressBar(progress: Double(covered) / Double(max(total, 1)), color: MFColor.micro)
            }
        }
        .mfCard()
        .accessibilityElement(children: .combine)
    }

    private func sectionCard(_ section: MicroSection) -> some View {
        guard let keys = filteredKeys[section] else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: MFSpacing.xs) {
                Text(section.rawValue)
                    .font(MFFont.headline)
                    .foregroundColor(MFColor.textPrimary)
                    .padding(.bottom, MFSpacing.xs)
                ForEach(keys, id: \.self) { key in
                    NavigationLink {
                        MicroDetailView(dependencies: dependencies, key: key)
                    } label: {
                        microRow(key)
                    }
                    .buttonStyle(.plain)
                    if key != keys.last {
                        Divider().background(MFColor.separator)
                    }
                }
            }
            .mfCard()
        )
    }

    private func microRow(_ key: NutrientKey) -> some View {
        let color = MFAnalyticsColor.forNutrient(key)
        let avg = averages[key] ?? 0
        let target = targets[key]
        let targetValue = target?.targetValue ?? 0
        let progress = targetValue > 0 ? avg / targetValue : 0
        return HStack(spacing: MFSpacing.md) {
            Image(systemName: MFAnalyticsColor.symbol(for: key))
                .font(.body)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.14))
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(key.displayName)
                        .font(MFFont.body)
                        .foregroundColor(MFColor.textPrimary)
                    if target?.isCustom == true {
                        Text("custom")
                            .font(MFFont.caption2.weight(.semibold))
                            .foregroundColor(MFColor.micro)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MFColor.micro.opacity(0.14))
                            .clipShape(Capsule())
                            .accessibilityLabel("Custom target")
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(MFColor.textTertiary)
                        .accessibilityHidden(true)
                }
                HStack {
                    Text(targetValue > 0
                        ? "\(MFAnalyticsFormat.amount(avg, key: key)) of \(MFAnalyticsFormat.amount(targetValue, key: key))"
                        : "\(MFAnalyticsFormat.amount(avg, key: key)) · no target set")
                        .font(MFFont.caption)
                        .monospacedDigit()
                        .foregroundColor(MFColor.textSecondary)
                    Spacer()
                    if targetValue > 0 {
                        Text(MFAnalyticsFormat.percent(min(progress, 9.99)))
                            .font(MFFont.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundColor(progress >= 1 ? MFColor.success : color)
                    }
                }
                AnalyticsProgressBar(progress: progress, color: color)
            }
        }
        .padding(.vertical, MFSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(key.displayName): averaging \(MFAnalyticsFormat.amount(avg, key: key))\(targetValue > 0 ? " of \(MFAnalyticsFormat.amount(targetValue, key: key)) target" : "")")
    }

    private func load() async {
        isLoading = true
        do {
            let service = AnalyticsDataService(dependencies: dependencies)
            let (avg, days) = try service.nutrientAverages(last: 28)
            averages = avg
            loggedDays = days
            targets = try service.allTargets()
        } catch {
            averages = [:]
        }
        isLoading = false
    }
}

// MARK: - MicroDetailView

/// One nutrient's detail: 28-day daily chart vs. target, top contributors,
/// and custom target editing.
public struct MicroDetailView: View {
    private let dependencies: AnalyticsDependencies
    private let key: NutrientKey

    @State private var daily: [DailyNutrition] = []
    @State private var target: NutrientTarget?
    @State private var contributors: [NutrientContributor] = []
    @State private var showingTargetEditor = false
    @State private var isLoading = true

    public init(dependencies: AnalyticsDependencies, key: NutrientKey) {
        self.dependencies = dependencies
        self.key = key
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: MFSpacing.lg) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    averageCard
                    chartCard
                    targetCard
                    contributorsCard
                }
            }
            .padding()
        }
        .background(MFColor.background)
        .navigationTitle(key.displayName)
        .task { await load() }
        .sheet(isPresented: $showingTargetEditor) {
            MicroTargetEditorSheet(key: key, currentValue: target?.targetValue) { newValue in
                try? dependencies.program.setTarget(key, value: newValue, isCustom: true)
                Task { await load() }
            }
            .presentationDetents([.medium])
        }
    }

    private var color: Color { MFAnalyticsColor.forNutrient(key) }
    private var targetValue: Double { target?.targetValue ?? 0 }

    private var averageCard: some View {
        let logged = daily.filter { $0.totals.entryCount > 0 }
        let avg = logged.isEmpty ? 0 : logged.reduce(0) { $0 + $1.totals.total(key) } / Double(logged.count)
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("28-day average")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
                Text(MFAnalyticsFormat.amount(avg, key: key))
                    .font(MFFont.statLarge)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textPrimary)
                if targetValue > 0 {
                    Text("of \(MFAnalyticsFormat.amount(targetValue, key: key)) target · \(MFAnalyticsFormat.percent(avg / targetValue))")
                        .font(MFFont.caption)
                        .monospacedDigit()
                        .foregroundColor(MFColor.textSecondary)
                }
            }
            Spacer()
            Image(systemName: MFAnalyticsColor.symbol(for: key))
                .font(.title)
                .foregroundColor(color)
                .frame(width: 56, height: 56)
                .background(color.opacity(0.14))
                .clipShape(Circle())
                .accessibilityHidden(true)
        }
        .mfCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(key.displayName), 28-day average: \(MFAnalyticsFormat.amount(avg, key: key))")
    }

    private var chartCard: some View {
        let logged = daily.filter { $0.totals.entryCount > 0 }
        return VStack(alignment: .leading, spacing: MFSpacing.md) {
            AnalyticsSectionHeader("Daily intake", subtitle: "Last 28 days")
            if logged.isEmpty {
                Text("No logged days in the last 28 days.")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
            } else {
                Chart(logged) { day in
                    BarMark(
                        x: .value("Day", day.dayStart, unit: .day),
                        y: .value("Amount", day.totals.total(key))
                    )
                    .foregroundStyle(color)
                    .cornerRadius(3)
                    if targetValue > 0 {
                        RuleMark(y: .value("Target", targetValue))
                            .foregroundStyle(MFColor.textTertiary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            Text(key == .calories
                                ? MFFormat.kcal(value.as(Double.self) ?? 0)
                                : MFFormat.grams(value.as(Double.self) ?? 0))
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 180)
                .accessibilityLabel("\(key.displayName) daily intake chart")
            }
        }
        .mfCard()
    }

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            HStack {
                AnalyticsSectionHeader("Daily target")
                Spacer()
                Button("Edit") { showingTargetEditor = true }
                    .font(MFFont.subheadline.weight(.semibold))
                    .foregroundColor(MFColor.accent)
            }
            if targetValue > 0 {
                HStack {
                    Text(MFAnalyticsFormat.amount(targetValue, key: key))
                        .font(MFFont.statMedium)
                        .monospacedDigit()
                        .foregroundColor(MFColor.textPrimary)
                    if target?.isCustom == true {
                        Text("custom")
                            .font(MFFont.caption2.weight(.semibold))
                            .foregroundColor(MFColor.micro)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MFColor.micro.opacity(0.14))
                            .clipShape(Capsule())
                    } else {
                        Text("default")
                            .font(MFFont.caption2.weight(.semibold))
                            .foregroundColor(MFColor.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MFColor.surfaceSunken)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
                Text("Targets are yours to change — editing one here updates every dashboard and the food-log header.")
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            } else {
                Text("No target set. Add one to track progress.")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
            }
        }
        .mfCard()
    }

    private var contributorsCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            AnalyticsSectionHeader("Top contributors", subtitle: "Last 28 days")
            if contributors.isEmpty {
                Text("Nothing logged with \(key.displayName.lowercased()) in the last 28 days.")
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
                                Text("\(MFAnalyticsFormat.amount(item.amount, key: key)) · \(MFAnalyticsFormat.percent(item.share))")
                                    .font(MFFont.caption)
                                    .monospacedDigit()
                                    .foregroundColor(MFColor.textSecondary)
                            }
                            AnalyticsProgressBar(progress: item.share, color: color)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.foodName): \(MFAnalyticsFormat.amount(item.amount, key: key))")
                    }
                }
            }
        }
        .mfCard()
    }

    private func load() async {
        isLoading = true
        do {
            let service = AnalyticsDataService(dependencies: dependencies)
            daily = try service.dailyNutrition(last: 28)
            target = try service.target(for: key)
            contributors = try service.topContributors(key: key, last: 28)
        } catch {
            daily = []
        }
        isLoading = false
    }
}

// MARK: - MicroTargetEditorSheet

/// Sheet for editing a nutrient's daily target (custom or default).
struct MicroTargetEditorSheet: View {
    private let key: NutrientKey
    private let onSave: (Double) -> Void

    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(key: NutrientKey, currentValue: Double?, onSave: @escaping (Double) -> Void) {
        self.key = key
        self.onSave = onSave
        self._text = State(initialValue: currentValue.map { String(format: "%.1f", $0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: MFSpacing.lg) {
                HStack {
                    Image(systemName: MFAnalyticsColor.symbol(for: key))
                        .font(.title2)
                        .foregroundColor(MFAnalyticsColor.forNutrient(key))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text(key.displayName)
                            .font(MFFont.headline)
                            .foregroundColor(MFColor.textPrimary)
                        Text("Daily target in \(key.unit)")
                            .font(MFFont.caption)
                            .foregroundColor(MFColor.textSecondary)
                    }
                    Spacer()
                }
                TextField("Target", text: $text)
                    .keyboardType(.decimalPad)
                    .font(MFFont.statMedium)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(MFColor.surfaceSunken)
                    .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
                    .accessibilityLabel("\(key.displayName) target in \(key.unit)")
                MFButton("Save target", style: .primary) {
                    if let value = Double(text), value >= 0 {
                        onSave(value)
                        dismiss()
                    }
                }
                .disabled(Double(text) == nil)
                Spacer()
            }
            .padding()
            .background(MFColor.background)
            .navigationTitle("Edit target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
