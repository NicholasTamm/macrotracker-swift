import SwiftUI
import DesignSystem
import DataLayer
import CoachingEngine

// MARK: - WeightTrendView

/// Weight-trend screen: the smoothed trend chart plus weigh-in history.
///
/// The chart is driven by the **same** smoothing behavior as the coaching
/// engine: `WeightTrend.trendSeries` (exponentially weighted moving average,
/// `alpha = 0.2`, one point per calendar day, missing days carried forward,
/// duplicate same-day samples averaged). The plotted points are the
/// *smoothed* trend values, so what you see here is exactly what #6's
/// expenditure estimator and weekly check-in reason about.
///
/// Note: `trendSeries` buckets days in UTC (deterministic, per #6's
/// contract), while weigh-in timestamps themselves are absolute instants.
/// Day grouping here matches the coaching engine, not the device calendar.
public struct WeightTrendView: View {
    @Environment(TrackingEnvironment.self) private var env

    /// Chart window in days. Matches the card's "4 wks ago → Today" axis.
    private let windowDays = 28

    @State private var trendKg: [Double] = []
    @State private var summary: WeightTrendSummary?
    @State private var history: [WeightEntry] = []
    @State private var goalType: GoalType = .maintain
    @State private var showingWeighIn = false
    @State private var error: String?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: MFSpacing.lg) {
                if let summary {
                    trendCard(summary: summary)
                        .mfCard()
                } else {
                    MFEmptyState(
                        icon: "scalemass",
                        title: "No weigh-ins yet",
                        message: "Log your first weigh-in and your smoothed weight trend will appear here.",
                        actionTitle: "Log weight",
                        onAction: { showingWeighIn = true }
                    )
                    .mfCard()
                }

                if !history.isEmpty {
                    historyCard
                        .mfCard()
                }
            }
            .padding()
        }
        .background(MFColor.background)
        .navigationTitle("Weight trend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingWeighIn = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Log weight")
            }
        }
        .sheet(isPresented: $showingWeighIn) {
            WeighInSheet()
        }
        .alert("Couldn't load weights", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
        .task { load() }
        .onChange(of: env.revision) { _, _ in load() }
    }

    // MARK: Chart card

    private func trendCard(summary: WeightTrendSummary) -> some View {
        let unit = env.weightUnit
        let points = trendKg.map { unit.fromKilograms($0) }
        let current = unit.fromKilograms(summary.endTrendKg)
        let delta = unit.fromKilograms(summary.totalChangeKg)
        return MFWeightTrendChartCard(
            points: points,
            unit: unit == .pounds ? "lb" : "kg",
            current: current,
            delta: delta,
            deltaIsGood: TrackingFormatting.deltaIsGood(summary.totalChangeKg, goalType: goalType)
        )
    }

    // MARK: History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            HStack {
                Text("Weigh-ins")
                    .font(MFFont.headline)
                    .foregroundColor(MFColor.textPrimary)
                Spacer()
                if let latest = history.first {
                    Text(TrackingFormatting.weight(latest.weightKg, unit: env.weightUnit))
                        .font(MFFont.statSmall)
                        .monospacedDigit()
                        .foregroundColor(MFColor.textSecondary)
                }
            }
            Divider().background(MFColor.separator)
            ForEach(history.prefix(30), id: \.id) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TrackingFormatting.weight(entry.weightKg, unit: env.weightUnit))
                            .font(MFFont.bodyBold)
                            .monospacedDigit()
                            .foregroundColor(MFColor.textPrimary)
                        if let note = entry.note, !note.isEmpty {
                            Text(note)
                                .font(MFFont.caption)
                                .foregroundColor(MFColor.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(TrackingFormatting.shortDateTime.string(from: entry.timestamp))
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textTertiary)
                    if entry.source == .healthKit {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(MFColor.textTertiary)
                            .accessibilityLabel("Synced from HealthKit")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        delete(entry)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: Data

    private func load() {
        do {
            env.refreshWeightUnit()
            goalType = (try? env.program.settings().goalType) ?? .maintain
            let end = Date()
            // Fetch well beyond the window so the EWMA has a seed sample on
            // or before the window start (see WeightTrend.trendSeries).
            let seedFrom = Calendar.current.date(byAdding: .day, value: -120, to: end) ?? .distantPast
            let samples = try env.weights.samples(from: seedFrom, to: end)
            let series = WeightTrend.trendSeries(samples: samples, endDate: end, windowDays: windowDays)
            trendKg = series.map(\.trendKg)
            summary = WeightTrend.summarize(samples: samples, endDate: end, windowDays: windowDays)
            history = Array(try env.weights.weights(from: seedFrom, to: end).reversed())
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ entry: WeightEntry) {
        do {
            try env.weights.deleteWeight(entry)
            env.noteMutation()
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview("Weight trend") {
    withPreviewEnvironment(seed: { env in
        // Seed a plausible 6-week downward trend.
        let calendar = Calendar.current
        for day in 0..<42 {
            let date = calendar.date(byAdding: .day, value: -day, to: Date())!
            let kg = 82.0 - Double(42 - day) * 0.06 + Double((day * 37) % 11) * 0.02
            try? env.weights.logWeight(kg, timestamp: date, note: nil, source: .manual)
        }
    }) { env in
        NavigationStack {
            WeightTrendView()
        }
        .environment(env)
    }
}
