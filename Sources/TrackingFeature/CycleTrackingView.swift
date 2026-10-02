import SwiftUI
import DesignSystem
import DataLayer

// MARK: - CycleTrackingView

/// Period tracking: month calendar with flow markers, per-day logging, and
/// cycle statistics (average length, predicted next period).
///
/// One `CycleEntry` per log day (upsert semantics in the data layer). All
/// day bucketing uses the device calendar via `MFDates`, consistent with
/// the rest of the tracking module.
public struct CycleTrackingView: View {
    @Environment(TrackingEnvironment.self) private var env

    @State private var month: Date = MFDates.startOfDay(Date())
    @State private var entries: [Date: CycleEntry] = [:]
    @State private var selectedDay: Date?
    @State private var error: String?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: MFSpacing.lg) {
                statsCard
                    .mfCard()
                calendarCard
                    .mfCard()
            }
            .padding()
        }
        .background(MFColor.background)
        .navigationTitle("Cycle")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { selectedDay != nil },
            set: { if !$0 { selectedDay = nil } }
        )) {
            if let day = selectedDay {
                CycleDaySheet(day: day, existing: entries[day]) { _ in
                    load()
                }
            }
        }
        .alert("Couldn't load cycle data", isPresented: Binding(
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

    // MARK: Stats

    private var statsCard: some View {
        let stats = CycleStats.compute(from: Array(entries.values))
        return VStack(alignment: .leading, spacing: MFSpacing.md) {
            Text("Overview")
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            HStack(spacing: MFSpacing.lg) {
                statCell(value: stats.averageCycleLength.map { "\($0)d" } ?? "—", label: "Avg cycle")
                statCell(value: stats.averagePeriodLength.map { "\($0)d" } ?? "—", label: "Avg period")
                statCell(
                    value: stats.predictedNextStart.map { daysLabel(until: $0) } ?? "—",
                    label: "Next period"
                )
            }
            if let next = stats.predictedNextStart {
                Text("Predicted to start \(TrackingFormatting.shortDate.string(from: next)). Predictions improve as you log more cycles.")
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            } else {
                Text("Log at least two periods to see cycle predictions.")
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cycle overview. Average cycle: \(stats.averageCycleLength.map { "\($0) days" } ?? "unknown").")
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(MFFont.statMedium)
                .monospacedDigit()
                .foregroundColor(MFColor.textPrimary)
            Text(label)
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func daysLabel(until date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: MFDates.startOfDay(Date()), to: MFDates.startOfDay(date)).day ?? 0
        if days <= 0 { return "now" }
        return "in \(days)d"
    }

    // MARK: Calendar

    private var calendarCard: some View {
        VStack(spacing: MFSpacing.md) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(MFColor.textPrimary)
                }
                .accessibilityLabel("Previous month")
                Spacer()
                Text(monthTitle)
                    .font(MFFont.headline)
                    .foregroundColor(MFColor.textPrimary)
                Spacer()
                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(MFColor.textPrimary)
                }
                .accessibilityLabel("Next month")
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
                ForEach(weekdayHeaders, id: \.self) { header in
                    Text(header)
                        .font(MFFont.caption2)
                        .foregroundColor(MFColor.textTertiary)
                }
                ForEach(monthCells, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    private var weekdayHeaders: [String] {
        let formatter = DateFormatter()
        var calendar = Calendar.current
        // Start headers on the calendar's first weekday.
        let symbols = formatter.shortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let first = calendar.firstWeekday - 1
        return (0..<7).map { String(symbols[(first + $0) % 7].prefix(1)) }
    }

    /// Dates to render: leading blanks (as distantPast placeholders) then the month's days.
    private var monthCells: [Date] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }
        let leading = (calendar.component(.weekday, from: firstOfMonth) - calendar.firstWeekday + 7) % 7
        let blanks = Array(repeating: Date.distantPast, count: leading)
        let days = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstOfMonth) }
        return blanks + days
    }

    private func dayCell(_ day: Date) -> some View {
        guard day != .distantPast else {
            return AnyView(Color.clear.frame(height: 40))
        }
        let entry = entries[MFDates.startOfDay(day)]
        let isToday = Calendar.current.isDateInToday(day)
        let isFuture = MFDates.startOfDay(day) > MFDates.startOfDay(Date())
        return AnyView(
            Button {
                selectedDay = MFDates.startOfDay(day)
            } label: {
                VStack(spacing: 3) {
                    Text("\(Calendar.current.component(.day, from: day))")
                        .font(MFFont.subheadline)
                        .monospacedDigit()
                        .foregroundColor(isFuture ? MFColor.textTertiary : MFColor.textPrimary)
                    if let entry {
                        Circle()
                            .fill(flowColor(entry.flow))
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(isToday ? MFColor.accentSoft : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: MFRadii.sm))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(TrackingFormatting.shortDate.string(from: day))\(entry.map { ", \($0.flow.displayName) flow" } ?? "")")
        )
    }

    private func flowColor(_ flow: FlowIntensity) -> Color {
        switch flow {
        case .spotting: MFColor.micro.opacity(0.45)
        case .light: MFColor.micro.opacity(0.65)
        case .medium: MFColor.micro
        case .heavy: MFColor.danger
        }
    }

    private func shiftMonth(by delta: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: delta, to: month) {
            month = next
        }
    }

    // MARK: Data

    private func load() {
        do {
            let from = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? .distantPast
            let list = try env.cycles.entries(from: from, to: Date())
            entries = Dictionary(uniqueKeysWithValues: list.map { ($0.dayStart, $0) })
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - CycleDaySheet

/// Log or clear the flow for one day.
struct CycleDaySheet: View {
    @Environment(TrackingEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let day: Date
    let existing: CycleEntry?
    let onSaved: (CycleEntry?) -> Void

    @State private var flow: FlowIntensity = .medium
    @State private var notes: String = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(TrackingFormatting.shortDate.string(from: day))
                        .font(MFFont.headline)
                        .foregroundColor(MFColor.textPrimary)
                }
                Section("Flow") {
                    Picker("Flow", selection: $flow) {
                        ForEach(FlowIntensity.allCases, id: \.self) { flow in
                            Text(flow.displayName).tag(flow)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                }
                if let error {
                    Section {
                        MFBanner(kind: .danger, title: "Couldn't save", message: error)
                    }
                }
                if existing != nil {
                    Section {
                        Button(role: .destructive) { clear() } label: {
                            Text("Clear this day")
                        }
                    }
                }
            }
            .navigationTitle("Log day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let existing {
                    flow = existing.flow
                    notes = existing.notes ?? ""
                }
            }
        }
    }

    private func save() {
        error = nil
        do {
            let entry = try env.cycles.logEntry(
                dayStart: day,
                flow: flow,
                notes: notes.isEmpty ? nil : notes
            )
            env.noteMutation()
            onSaved(entry)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func clear() {
        guard let existing else { return }
        do {
            try env.cycles.deleteEntry(existing)
            env.noteMutation()
            onSaved(nil)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - CycleStats

/// Pure cycle statistics computed from logged entries.
struct CycleStats {
    /// Mean days between consecutive period starts (nil with < 2 periods).
    var averageCycleLength: Int?
    /// Mean period duration in days.
    var averagePeriodLength: Int?
    /// Predicted next period start (last start + average cycle length).
    var predictedNextStart: Date?

    /// Group consecutive logged days into periods (a gap of 2+ unlogged
    /// days starts a new period), then average the gaps between starts.
    static func compute(from entries: [CycleEntry]) -> CycleStats {
        let calendar = Calendar.current
        let days = entries.map { MFDates.startOfDay($0.dayStart) }.sorted()
        guard !days.isEmpty else { return CycleStats() }

        // Group into periods: a new period starts after a 2+ day gap.
        var periods: [[Date]] = []
        for day in days {
            if let last = periods.last?.last,
               let gap = calendar.dateComponents([.day], from: last, to: day).day,
               gap <= 2 {
                periods[periods.count - 1].append(day)
            } else {
                periods.append([day])
            }
        }

        let avgPeriod: Int? = periods.isEmpty ? nil : Int(
            (Double(periods.map(\.count).reduce(0, +)) / Double(periods.count)).rounded()
        )
        guard periods.count >= 2 else {
            return CycleStats(averageCycleLength: nil, averagePeriodLength: avgPeriod, predictedNextStart: nil)
        }
        let starts = periods.map { $0.first! }
        let gaps = zip(starts, starts.dropFirst()).compactMap { first, second in
            calendar.dateComponents([.day], from: first, to: second).day
        }.filter { $0 > 0 }
        // Use the last 6 cycles at most, like common period trackers.
        let recent = Array(gaps.suffix(6))
        guard !recent.isEmpty else {
            return CycleStats(averageCycleLength: nil, averagePeriodLength: avgPeriod, predictedNextStart: nil)
        }
        let avg = Int((Double(recent.reduce(0, +)) / Double(recent.count)).rounded())
        let predicted = calendar.date(byAdding: .day, value: avg, to: starts.last!)
        return CycleStats(averageCycleLength: avg, averagePeriodLength: avgPeriod, predictedNextStart: predicted)
    }
}

#Preview("Cycle") {
    withPreviewEnvironment(seed: { env in
        // Seed two recent periods, 28 days apart.
        let calendar = Calendar.current
        let today = MFDates.startOfDay(Date())
        for offset in [56, 57, 58, 59, 28, 29, 30, 31] {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                try? env.cycles.logEntry(dayStart: day, flow: .medium, notes: nil)
            }
        }
    }) { env in
        NavigationStack {
            CycleTrackingView()
        }
        .environment(env)
    }
}
