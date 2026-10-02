import SwiftUI
import DesignSystem
import DataLayer

// MARK: - StepsSummaryCard

/// Read-only 7-day step summary. Step data is written by HealthKitSync (#9)
/// (or manual entry); this module never writes it.
public struct StepsSummaryCard: View {
    @Environment(TrackingEnvironment.self) private var env

    @State private var days: [(date: Date, steps: Double)] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Steps")
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: MFSpacing.sm) {
                        Text(TrackingFormatting.steps(total))
                            .font(MFFont.statLarge)
                            .monospacedDigit()
                            .foregroundColor(MFColor.textPrimary)
                        Text("this week")
                            .font(MFFont.caption)
                            .foregroundColor(MFColor.textSecondary)
                    }
                }
                Spacer()
                if let latest = days.last, latest.steps > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TrackingFormatting.steps(latest.steps))
                            .font(MFFont.statSmall)
                            .monospacedDigit()
                            .foregroundColor(MFColor.textPrimary)
                        Text("today")
                            .font(MFFont.caption2)
                            .foregroundColor(MFColor.textSecondary)
                    }
                }
            }

            if days.isEmpty {
                Text("No step data yet. Connect Apple Health to see your daily steps here.")
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(days, id: \.date) { day in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(day.steps > 0 ? MFColor.accent : MFColor.surfaceSunken)
                                .frame(height: barHeight(for: day.steps))
                            Text(weekdayLetter(for: day.date))
                                .font(MFFont.caption2)
                                .foregroundColor(MFColor.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(fullWeekday(for: day.date)): \(TrackingFormatting.steps(day.steps)) steps")
                    }
                }
                .frame(height: 110)
            }
        }
        .task { load() }
        .onChange(of: env.revision) { _, _ in load() }
    }

    private var total: Double { days.reduce(0) { $0 + $1.steps } }

    private var maxSteps: Double { max(days.map(\.steps).max() ?? 1, 1) }

    private func barHeight(for steps: Double) -> CGFloat {
        guard steps > 0 else { return 4 }
        return max(8, CGFloat(steps / maxSteps) * 80)
    }

    private func weekdayLetter(for day: Date) -> String {
        let formatter = DateFormatter()
        return String(formatter.shortWeekdaySymbols[Calendar.current.component(.weekday, from: day) - 1].prefix(1))
    }

    private func fullWeekday(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: day)
    }

    private func load() {
        do {
            let today = MFDates.startOfDay(Date())
            let from = Calendar.current.date(byAdding: .day, value: -6, to: today) ?? .distantPast
            let entries = try env.steps.steps(from: from, to: today)
            let byDay = Dictionary(uniqueKeysWithValues: entries.map { ($0.dayStart, $0.steps) })
            days = (0..<7).compactMap { offset in
                Calendar.current.date(byAdding: .day, value: -offset, to: today)
            }.reversed().map { day in
                (day, byDay[MFDates.startOfDay(day)] ?? 0)
            }
        } catch {
            days = []
        }
    }
}

// MARK: - StepsView

/// Steps detail screen: 4-week history and totals. Display only.
public struct StepsView: View {
    @Environment(TrackingEnvironment.self) private var env

    @State private var weeks: [[(date: Date, steps: Double)]] = []

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: MFSpacing.lg) {
                StepsSummaryCard()
                    .mfCard()
                if !weeks.isEmpty {
                    historyCard
                        .mfCard()
                }
            }
            .padding()
        }
        .background(MFColor.background)
        .navigationTitle("Steps")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
        .onChange(of: env.revision) { _, _ in load() }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            Text("Last 4 weeks")
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                let total = week.reduce(0.0) { $0 + $1.steps }
                let avg = week.isEmpty ? 0 : total / Double(week.count)
                HStack {
                    Text(weekLabel(for: week))
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textPrimary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(TrackingFormatting.steps(total)) total")
                            .font(MFFont.bodyBold)
                            .monospacedDigit()
                            .foregroundColor(MFColor.textPrimary)
                        Text("\(TrackingFormatting.steps(avg)) / day avg")
                            .font(MFFont.caption)
                            .monospacedDigit()
                            .foregroundColor(MFColor.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(weekLabel(for: week)): \(TrackingFormatting.steps(total)) total steps, \(TrackingFormatting.steps(avg)) per day average")
            }
            Text("Step counts sync from Apple Health. This screen is display-only.")
                .font(MFFont.caption)
                .foregroundColor(MFColor.textTertiary)
        }
    }

    private func weekLabel(for week: [(date: Date, steps: Double)]) -> String {
        guard let first = week.first?.date, let last = week.last?.date else { return "—" }
        return "\(TrackingFormatting.monthDay.string(from: first)) – \(TrackingFormatting.monthDay.string(from: last))"
    }

    private func load() {
        do {
            let today = MFDates.startOfDay(Date())
            let from = Calendar.current.date(byAdding: .day, value: -27, to: today) ?? .distantPast
            let entries = try env.steps.steps(from: from, to: today)
            let byDay = Dictionary(uniqueKeysWithValues: entries.map { ($0.dayStart, $0.steps) })
            let allDays = (0..<28).compactMap { offset in
                Calendar.current.date(byAdding: .day, value: -offset, to: today)
            }.reversed().map { day in
                (day, byDay[MFDates.startOfDay(day)] ?? 0)
            }
            weeks = Array(stride(from: 0, to: allDays.count, by: 7).map { start in
                Array(allDays[start..<min(start + 7, allDays.count)])
            }.reversed())
        } catch {
            weeks = []
        }
    }
}

#Preview("Steps") {
    withPreviewEnvironment(seed: { env in
        let calendar = Calendar.current
        let today = MFDates.startOfDay(Date())
        for offset in 0..<14 {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                try? env.steps.setSteps(4000 + Double((offset * 7919) % 6000), for: day, source: .manual)
            }
        }
    }) { env in
        NavigationStack {
            StepsView()
        }
        .environment(env)
    }
}
