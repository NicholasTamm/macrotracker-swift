import SwiftUI
import DesignSystem
import DataLayer

// MARK: - HabitsView

/// Habit tracking: streak flames, weekly progress, completion logging, and
/// habit management.
///
/// Streak math lives in the data layer (`HabitRepository.currentStreak`):
/// day-bucketing uses the device calendar via `MFDates.startOfDay`, and
/// today counts as a grace day so a streak doesn't break before today's
/// logging. This view keeps the same convention for its week dots.
public struct HabitsView: View {
    @Environment(TrackingEnvironment.self) private var env

    @State private var habits: [Habit] = []
    @State private var streaks: [UUID: Int] = [:]
    @State private var weekCompletions: [UUID: Set<Date>] = [:]
    @State private var showingEditor = false
    @State private var editing: Habit?
    @State private var error: String?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: MFSpacing.lg) {
                if habits.isEmpty {
                    MFEmptyState(
                        icon: "flame",
                        title: "No habits yet",
                        message: "Build streaks for logging, weighing in, photos, or anything else you want to stay consistent with.",
                        actionTitle: "Create habit",
                        onAction: { showingEditor = true }
                    )
                    .mfCard()
                } else {
                    streakHeader
                        .mfCard()
                    ForEach(habits, id: \.id) { habit in
                        habitCard(habit)
                            .mfCard()
                    }
                }
            }
            .padding()
        }
        .background(MFColor.background)
        .navigationTitle("Habits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = nil
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create habit")
            }
        }
        .sheet(isPresented: $showingEditor) {
            HabitEditorSheet(editing: editing)
        }
        .alert("Couldn't load habits", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
        .task {
            env.ensureSystemHabits()
            load()
        }
        .onChange(of: env.revision) { _, _ in load() }
    }

    // MARK: Streak header

    /// Combined flame header: the longest active streak across habits.
    private var streakHeader: some View {
        let best = habits.compactMap { streaks[$0.id] }.max() ?? 0
        let bestHabit = habits.first { streaks[$0.id] == best }
        return HStack(spacing: MFSpacing.lg) {
            MFFlameGlyph(size: 30, color: MFColor.fat)
                .frame(width: 64, height: 64)
                .background(MFColor.fat.opacity(0.14))
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: MFSpacing.xs) {
                    Text("\(best)")
                        .font(MFFont.statLarge)
                        .monospacedDigit()
                        .foregroundColor(MFColor.textPrimary)
                    Text(best == 1 ? "day" : "days")
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textSecondary)
                }
                Text(bestHabit.map { "Best streak · \($0.name)" } ?? "Log a habit to start a streak")
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Best streak: \(best) days\(bestHabit.map { ", \($0.name)" } ?? "")")
    }

    // MARK: Habit cards

    private func habitCard(_ habit: Habit) -> some View {
        let streak = streaks[habit.id] ?? 0
        let week = weekCompletions[habit.id] ?? []
        let today = MFDates.startOfDay(Date())
        let doneToday = week.contains(today)
        return VStack(alignment: .leading, spacing: MFSpacing.md) {
            HStack {
                MFFlameGlyph(size: 18, color: streak > 0 ? MFColor.fat : MFColor.textTertiary)
                    .accessibilityHidden(true)
                Text(habit.name)
                    .font(MFFont.headline)
                    .foregroundColor(MFColor.textPrimary)
                Spacer()
                Text("\(streak)")
                    .font(MFFont.statMedium)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textPrimary)
                    .accessibilityLabel("\(streak) day streak")
                Menu {
                    Button {
                        editing = habit
                        showingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        delete(habit)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(MFColor.textTertiary)
                }
                .accessibilityLabel("Habit options")
            }

            // Trailing 7-day dots, device-calendar bucketed like the data layer.
            HStack(spacing: MFSpacing.sm) {
                ForEach(last7Days, id: \.self) { day in
                    let done = week.contains(day)
                    VStack(spacing: 4) {
                        Circle()
                            .fill(done ? MFColor.fat : MFColor.surfaceSunken)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if done {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(MFColor.textOnAccent)
                                }
                            }
                        Text(weekdayLetter(for: day))
                            .font(MFFont.caption2)
                            .foregroundColor(MFColor.textTertiary)
                    }
                    .accessibilityLabel("\(fullWeekday(for: day)): \(done ? "done" : "not done")")
                }
                Spacer()
                Text("\(week.count)/\(habit.targetPerWeek)")
                    .font(MFFont.caption)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textSecondary)
                    .accessibilityLabel("\(week.count) of \(habit.targetPerWeek) weekly target")
            }

            MFButton(doneToday ? "Done for today" : "Mark today done", style: doneToday ? .secondary : .primary, size: .medium) {
                toggleToday(habit, doneToday: doneToday)
            }
            .accessibilityHint(doneToday ? "Tap to undo today's completion" : "Tap to log today's completion")
        }
    }

    private var last7Days: [Date] {
        let calendar = Calendar.current
        let today = MFDates.startOfDay(Date())
        return Array((0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed())
    }

    private func weekdayLetter(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return String(formatter.shortWeekdaySymbols[Calendar.current.component(.weekday, from: day) - 1].prefix(1))
    }

    private func fullWeekday(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: day)
    }

    // MARK: Data

    private func load() {
        do {
            habits = try env.habits.habits(activeOnly: true)
            var newStreaks: [UUID: Int] = [:]
            var newWeeks: [UUID: Set<Date>] = [:]
            let today = MFDates.startOfDay(Date())
            let weekAgo = Calendar.current.date(byAdding: .day, value: -6, to: today)!
            for habit in habits {
                newStreaks[habit.id] = (try? env.habits.currentStreak(habit: habit)) ?? 0
                let completions = (try? env.habits.completions(habit: habit, from: weekAgo, to: today)) ?? []
                newWeeks[habit.id] = Set(completions.filter(\.isComplete).map(\.dayStart))
            }
            streaks = newStreaks
            weekCompletions = newWeeks
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func toggleToday(_ habit: Habit, doneToday: Bool) {
        do {
            if doneToday {
                // Undo: remove today's completion.
                let today = MFDates.startOfDay(Date())
                let completions = try env.habits.completions(habit: habit, from: today, to: today)
                for completion in completions {
                    try env.habits.deleteCompletion(completion)
                }
            } else {
                try env.habits.logCompletion(habit: habit, dayStart: Date(), value: 1, note: nil)
            }
            env.noteMutation()
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ habit: Habit) {
        do {
            try env.habits.deleteHabit(habit)
            env.noteMutation()
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - HabitEditorSheet

/// Create or edit a habit.
struct HabitEditorSheet: View {
    @Environment(TrackingEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let editing: Habit?

    @State private var name: String = ""
    @State private var kind: HabitKind = .custom
    @State private var targetPerWeek: Double = 7
    @State private var isActive: Bool = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Habit name", text: $name)
                        .accessibilityLabel("Habit name")
                }
                Section("Type") {
                    Picker("Type", selection: $kind) {
                        ForEach(HabitKind.allCases, id: \.self) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section("Weekly target") {
                    MFStepper(
                        value: $targetPerWeek,
                        step: 1,
                        range: 1...7,
                        unit: "days",
                        label: "Weekly target"
                    )
                }
                if editing != nil {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    }
                }
                if let error {
                    Section {
                        MFBanner(kind: .danger, title: "Couldn't save", message: error)
                    }
                }
            }
            .navigationTitle(editing == nil ? "New habit" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { seed() }
        }
    }

    private func seed() {
        guard let editing else { return }
        name = editing.name
        kind = editing.kind
        targetPerWeek = Double(editing.targetPerWeek)
        isActive = editing.isActive
    }

    private func save() {
        error = nil
        do {
            if let editing {
                editing.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                editing.kind = kind
                editing.targetPerWeek = Int(targetPerWeek)
                editing.isActive = isActive
                try env.habits.updateHabit(editing)
            } else {
                _ = try env.habits.createHabit(
                    name: name,
                    kind: kind,
                    targetPerWeek: Int(targetPerWeek)
                )
            }
            env.noteMutation()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview("Habits") {
    withPreviewEnvironment(seed: { env in
        env.ensureSystemHabits()
    }) { env in
        NavigationStack {
            HabitsView()
        }
        .environment(env)
    }
}
