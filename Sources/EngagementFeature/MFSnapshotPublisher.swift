//  MFSnapshotPublisher.swift
//  EngagementFeature — builds MFSharedSnapshot from the DataLayer
//  repositories, writes it to the App Group container, and asks WidgetKit
//  to reload timelines (issue #10).
//
//  AppShell wiring: create ONE publisher alongside the DataStore, then call
//  `publishToday()` on launch, after every log mutation (log/edit/delete/
//  quick-add), after weigh-ins, and when targets change. Set `onPublish` to
//  forward the snapshot to the watch bridge (MFWatchBridge.pushSnapshot).

import Foundation
import WidgetKit
import DataLayer

// MARK: - MFSnapshotPublisher

/// Publishes today's nutrition snapshot for widgets + watch.
///
/// Programs to repository protocols only — never to SwiftData directly.
@MainActor
public final class MFSnapshotPublisher {
    private let logs: any LogRepository
    private let program: any ProgramRepository
    private let weights: any WeightRepository

    /// Invoked after every successful publish. AppShell sets this to forward
    /// the snapshot to the watch over WatchConnectivity.
    public var onPublish: ((MFSharedSnapshot) -> Void)?

    public init(
        logs: any LogRepository,
        program: any ProgramRepository,
        weights: any WeightRepository
    ) {
        self.logs = logs
        self.program = program
        self.weights = weights
    }

    // MARK: Publish

    /// Builds today's snapshot, writes it to the shared container, and
    /// reloads all widget timelines. Returns the snapshot, or nil when the
    /// build or write failed (the previous snapshot, if any, stays in
    /// place).
    @discardableResult
    public func publishToday() -> MFSharedSnapshot? {
        do {
            let snapshot = try buildSnapshot()
            try MFSharedSnapshotStore.write(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
            onPublish?(snapshot)
            return snapshot
        } catch {
            // Publishing must never break the logging flow; the last good
            // snapshot remains for widgets/watch until the next publish.
            return nil
        }
    }

    /// Builds the snapshot without writing or reloading (useful for the
    /// watch bridge's snapshot-request replies).
    public func buildSnapshot() throws -> MFSharedSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let today = MFDates.startOfDay(now)

        let totals = try logs.dayTotals(today)
        let settings = try program.settings()
        let logDay = try logs.logDay(for: today)
        let latestWeight = try weights.latestWeight()

        // Targets: today's per-weekday override wins over program defaults.
        var targetCalories = settings.currentCalories
        var targetProtein = settings.currentProteinGrams
        var targetFat = settings.currentFatGrams
        var targetCarbs = settings.currentCarbsGrams
        let weekday = calendar.component(.weekday, from: now) // 1 = Sunday
        if let override = try program.dayOverrides().first(where: { $0.weekday == weekday }) {
            let t = override.macroTargets
            targetCalories = t.calories
            targetProtein = t.proteinGrams
            targetFat = t.fatGrams
            targetCarbs = t.carbsGrams
        }

        return MFSharedSnapshot(
            generatedAt: now,
            dayStart: today,
            calories: totals.calories,
            proteinGrams: totals.protein,
            fatGrams: totals.fat,
            carbsGrams: totals.carbs,
            entryCount: totals.entryCount,
            isDayComplete: logDay?.isMarkedComplete ?? false,
            targetCalories: targetCalories,
            targetProteinGrams: targetProtein,
            targetFatGrams: targetFat,
            targetCarbsGrams: targetCarbs,
            latestWeightKg: latestWeight?.weightKg,
            weightUnitRaw: settings.weightUnit.rawValue,
            logStreakDays: (try? currentLogStreak(today: today)) ?? 0
        )
    }

    // MARK: Streak

    /// Consecutive days (ending today or yesterday) with at least one logged
    /// entry. Looked back at most 370 days.
    private func currentLogStreak(today: Date) throws -> Int {
        let calendar = Calendar.current
        let lookback = 370
        guard
            let start = calendar.date(byAdding: .day, value: -lookback, to: today)
        else { return 0 }
        let loggedDays = Set(
            try logs.entries(from: MFDates.startOfDay(start), to: today)
                .map(\.dayStart)
        )
        // A streak stays alive through today even before anything is logged.
        var streak = 0
        var cursor = today
        if !loggedDays.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  loggedDays.contains(MFDates.startOfDay(yesterday))
            else { return 0 }
            cursor = MFDates.startOfDay(yesterday)
        }
        while loggedDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
