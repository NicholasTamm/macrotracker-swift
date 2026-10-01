import SwiftUI
import DesignSystem
import DataLayer
import CoachingEngine

// MARK: - TrackingFeature (issue #7)
//
// Weight trend, body measurements, progress photos, habit streaks, period
// tracking, and steps display.
//
// OWNER: issue #7 worker. This file is the module entry: the namespace and
// the environment object AppShell injects into every tracking view.
//
// Expected public surface (see issues/07-tracking.md):
// - `WeighInSheet` — replaces `WeighInPlaceholderSheet` in AppShell; the
//   `mfclone://weighin` deep link should present this.
// - `TrackingHubView` — the tracking home screen.
// - `WeightTrendView`, `MeasurementsView`, `ProgressPhotosView`,
//   `HabitsView`, `CycleTrackingView`, `StepsView` — detail screens.
///
/// Wiring (AppShell, issue #2):
///     let env = TrackingEnvironment(store: try DataStore())
///     TrackingHubView()
///         .environment(env)

/// Namespace for the tracking feature module (issue #7).
public enum TrackingFeature {
    public static let ownerIssue = "#7"
}

// MARK: - TrackingEnvironment

/// Dependency-injection root for every tracking view.
///
/// Holds the repository **protocols** (never SwiftData types) plus shared
/// session state such as the display weight unit. `revision` is a simple
/// change counter: views reload their data in `.task` and on
/// `.onChange(of: env.revision)`, and every mutation helper below bumps it
/// so sibling screens stay fresh.
@MainActor
@Observable
public final class TrackingEnvironment {
    public var weights: any WeightRepository
    public var measurements: any MeasurementRepository
    public var habits: any HabitRepository
    public var steps: any StepRepository
    public var cycles: any CycleRepository
    public var program: any ProgramRepository

    /// Incremented after every mutation so views can reload.
    public var revision: Int = 0

    /// The user's chosen weight display unit, mirrored from
    /// `ProgramSettings` (storage is always kilograms).
    public var weightUnit: WeightUnit = .pounds

    /// Hook invoked after a **manual** weigh-in is saved (weightKg, timestamp).
    /// AppShell sets this to write the weigh-in back to HealthKit via
    /// `MFHealthKitStore.shared.writeWeighIn(weightKg:date:)` (issue #9).
    /// The hook keeps the module graph acyclic: TrackingFeature never imports
    /// HealthKitSync directly (MODULE_MAP rule 1). Never throws; AppShell is
    /// expected to swallow HealthKit errors (`try?`) so a Health failure
    /// can never break the local save.
    public var onManualWeighIn: (@Sendable (Double, Date) -> Void)?

    public init(
        weights: any WeightRepository,
        measurements: any MeasurementRepository,
        habits: any HabitRepository,
        steps: any StepRepository,
        cycles: any CycleRepository,
        program: any ProgramRepository
    ) {
        self.weights = weights
        self.measurements = measurements
        self.habits = habits
        self.steps = steps
        self.cycles = cycles
        self.program = program
    }

    /// Convenience: build straight from a `DataStore`.
    public convenience init(store: DataStore) {
        self.init(
            weights: store.weights,
            measurements: store.measurements,
            habits: store.habits,
            steps: store.steps,
            cycles: store.cycles,
            program: store.program
        )
    }

    /// Pull the stored weight-unit preference (best effort; keeps the
    /// previous value when the settings row can't be read).
    public func refreshWeightUnit() {
        if let settings = try? program.settings() {
            weightUnit = settings.weightUnit
        }
    }

    /// Bump the revision counter after a mutation.
    public func noteMutation() {
        revision += 1
    }

    // MARK: Habit streak helpers (timezone-safe)

    /// Consecutive completed log days for a habit, using the data layer's
    /// device-calendar day bucketing (`MFDates.startOfDay`) with a grace day
    /// for today — see `SwiftDataHabitRepository.currentStreak`.
    public func streak(for habit: Habit) -> Int {
        (try? habits.currentStreak(habit: habit)) ?? 0
    }

    /// Log today's completion for the built-in habit of `kind`, if it exists.
    /// Used so weigh-ins (and later, food logging) feed streaks automatically.
    public func logTodayCompletion(kind: HabitKind, value: Double = 1) {
        guard let habit = (try? habits.habits(activeOnly: true))?.first(where: { $0.kind == kind }) else { return }
        try? habits.logCompletion(habit: habit, dayStart: Date(), value: value)
        noteMutation()
    }

    /// Create the built-in system habits (log food, weigh in, progress photo)
    /// once, so streak tracking has something to attach to out of the box.
    /// Manual habits are untouched. Returns whether anything was created.
    @discardableResult
    public func ensureSystemHabits() -> Bool {
        let existing = (try? habits.habits(activeOnly: false)) ?? []
        let defaults: [(String, HabitKind)] = [
            ("Log food", .foodLogging),
            ("Weigh in", .weighIn),
            ("Progress photo", .progressPhoto),
        ]
        var created = false
        for (name, kind) in defaults where !existing.contains(where: { $0.kind == kind }) {
            try? habits.createHabit(name: name, kind: kind, targetPerWeek: kind == .progressPhoto ? 1 : 7)
            created = true
        }
        if created { noteMutation() }
        return created
    }
}
