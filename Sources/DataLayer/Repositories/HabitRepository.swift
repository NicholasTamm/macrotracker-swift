//  HabitRepository.swift
//  DataLayer — habit CRUD, completions, and streak computation.

import Foundation
import SwiftData

@MainActor
public protocol HabitRepository {
    @discardableResult
    func createHabit(name: String, kind: HabitKind, targetPerWeek: Int) throws -> Habit
    func habits(activeOnly: Bool) throws -> [Habit]
    func updateHabit(_ habit: Habit) throws
    func deleteHabit(_ habit: Habit) throws
    @discardableResult
    func logCompletion(habit: Habit, dayStart: Date, value: Double = 1, note: String? = nil) throws -> HabitCompletion
    func completions(habit: Habit, from: Date, to: Date) throws -> [HabitCompletion]
    func deleteCompletion(_ completion: HabitCompletion) throws
    /// Consecutive completed log days ending today (or yesterday, so a
    /// streak doesn't break before today's logging).
    func currentStreak(habit: Habit) throws -> Int
    /// Completed days in the trailing 7-day window (for weekly targets).
    func completionsThisWeek(habit: Habit) throws -> Int
}

@MainActor
public final class SwiftDataHabitRepository: HabitRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func createHabit(
        name: String,
        kind: HabitKind = .custom,
        targetPerWeek: Int = 7
    ) throws -> Habit {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MFDataError.invalidInput("Habit name can't be empty.") }
        let habit = Habit(name: trimmed, kind: kind, targetPerWeek: max(1, targetPerWeek))
        context.insert(habit)
        try context.save()
        return habit
    }

    public func habits(activeOnly: Bool = true) throws -> [Habit] {
        let descriptor: FetchDescriptor<Habit>
        if activeOnly {
            descriptor = FetchDescriptor<Habit>(
                predicate: #Predicate { $0.isActive },
                sortBy: [SortDescriptor(\.createdAt)]
            )
        } else {
            descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.createdAt)])
        }
        return try context.fetch(descriptor)
    }

    public func updateHabit(_ habit: Habit) throws {
        try context.save()
    }

    public func deleteHabit(_ habit: Habit) throws {
        context.delete(habit) // completions cascade
        try context.save()
    }

    @discardableResult
    public func logCompletion(
        habit: Habit,
        dayStart: Date,
        value: Double = 1,
        note: String? = nil
    ) throws -> HabitCompletion {
        let start = MFDates.startOfDay(dayStart)
        let habitID = habit.id
        var descriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate { $0.dayStart == start && $0.habit?.id == habitID }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.value = max(existing.value, value)
            existing.note = note ?? existing.note
            try context.save()
            return existing
        }
        let completion = HabitCompletion(dayStart: start, value: value, note: note, habit: habit)
        context.insert(completion)
        try context.save()
        return completion
    }

    public func completions(habit: Habit, from: Date, to: Date) throws -> [HabitCompletion] {
        let habitID = habit.id
        let start = MFDates.startOfDay(from)
        let end = MFDates.startOfDay(to)
        let descriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate {
                $0.habit?.id == habitID && $0.dayStart >= start && $0.dayStart <= end
            },
            sortBy: [SortDescriptor(\.dayStart)]
        )
        return try context.fetch(descriptor)
    }

    public func deleteCompletion(_ completion: HabitCompletion) throws {
        context.delete(completion)
        try context.save()
    }

    public func currentStreak(habit: Habit) throws -> Int {
        let calendar = Calendar.current
        let today = MFDates.startOfDay(Date())
        // Look back up to a year; streaks longer than that are not computed.
        let from = calendar.date(byAdding: .day, value: -365, to: today)!
        let done = Set(
            try completions(habit: habit, from: from, to: today)
                .filter(\.isComplete)
                .map(\.dayStart)
        )
        // A streak stays alive if today isn't logged yet (grace day).
        var cursor = done.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        var streak = 0
        while done.contains(cursor) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return streak
    }

    public func completionsThisWeek(habit: Habit) throws -> Int {
        let today = MFDates.startOfDay(Date())
        let weekAgo = Calendar.current.date(byAdding: .day, value: -6, to: today)!
        return try completions(habit: habit, from: weekAgo, to: today)
            .filter(\.isComplete)
            .count
    }
}
