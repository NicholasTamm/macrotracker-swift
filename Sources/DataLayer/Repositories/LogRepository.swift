//  LogRepository.swift
//  DataLayer — CRUD for LogEntry + LogDay, day totals, copy/paste, and the
//  coaching-engine mapping (IntakeDay).

import Foundation
import SwiftData
import CoachingEngine

@MainActor
public protocol LogRepository {
    // MARK: Logging
    @discardableResult
    func logFood(
        _ food: FoodItem,
        grams: Double,
        mealSlot: MealSlot = .other,
        timestamp: Date = Date(),
        note: String? = nil,
        source: EntrySource = .manualSearch
    ) throws -> LogEntry
    /// Quick-add: calories/macros without a food record.
    @discardableResult
    func quickAdd(
        calories: Double,
        proteinGrams: Double,
        fatGrams: Double,
        carbsGrams: Double,
        mealSlot: MealSlot = .other,
        timestamp: Date = Date(),
        note: String? = nil
    ) throws -> LogEntry
    func updateEntry(
        _ entry: LogEntry,
        grams: Double,
        mealSlot: MealSlot,
        timestamp: Date,
        note: String?
    ) throws
    func deleteEntry(_ entry: LogEntry) throws

    // MARK: Reads
    func entries(forDay dayStart: Date) throws -> [LogEntry]
    func entries(from: Date, to: Date) throws -> [LogEntry]
    func dayTotals(_ dayStart: Date) throws -> MFDayTotals
    func logDay(for dayStart: Date) throws -> LogDay?

    // MARK: Day operations
    func markDayComplete(_ dayStart: Date, complete: Bool) throws
    func setDayNote(_ dayStart: Date, note: String?) throws
    /// Copies all entries from one day to another (new timestamps, same
    /// meal slots and grams). Used by "copy day".
    func copyDay(from sourceDay: Date, to targetDay: Date) throws -> [LogEntry]
    /// Deletes every entry on a day (keeps the LogDay record).
    func clearDay(_ dayStart: Date) throws

    // MARK: Coaching mapping
    /// Per-day intake rollups for the expenditure estimator / check-in.
    /// `isComplete` comes from LogDay.isMarkedComplete.
    func intakeDays(from: Date, to: Date) throws -> [IntakeDay]
}

// MARK: - SwiftData implementation

@MainActor
public final class SwiftDataLogRepository: LogRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: Logging

    @discardableResult
    public func logFood(
        _ food: FoodItem,
        grams: Double,
        mealSlot: MealSlot = .other,
        timestamp: Date = Date(),
        note: String? = nil,
        source: EntrySource = .manualSearch
    ) throws -> LogEntry {
        guard grams > 0 else { throw MFDataError.invalidInput("Amount must be positive.") }
        let entry = LogEntry(
            timestamp: timestamp,
            dayStart: MFDates.startOfDay(timestamp),
            mealSlot: mealSlot,
            source: source,
            food: food,
            foodName: food.displayName,
            grams: grams,
            nutrients: food.scaledNutrients(grams: grams),
            note: note
        )
        context.insert(entry)
        try context.save()
        return entry
    }

    @discardableResult
    public func quickAdd(
        calories: Double,
        proteinGrams: Double,
        fatGrams: Double,
        carbsGrams: Double,
        mealSlot: MealSlot = .other,
        timestamp: Date = Date(),
        note: String? = nil
    ) throws -> LogEntry {
        guard calories >= 0 else { throw MFDataError.invalidInput("Calories can't be negative.") }
        let entry = LogEntry(
            timestamp: timestamp,
            dayStart: MFDates.startOfDay(timestamp),
            mealSlot: mealSlot,
            source: .quickAdd,
            food: nil,
            foodName: "Quick add",
            grams: 0,
            nutrients: [
                .calories: calories,
                .protein: proteinGrams,
                .fat: fatGrams,
                .carbs: carbsGrams,
            ],
            note: note
        )
        context.insert(entry)
        try context.save()
        return entry
    }

    public func updateEntry(
        _ entry: LogEntry,
        grams: Double,
        mealSlot: MealSlot,
        timestamp: Date,
        note: String?
    ) throws {
        guard grams >= 0 else { throw MFDataError.invalidInput("Amount can't be negative.") }
        entry.grams = grams
        entry.mealSlot = mealSlot
        entry.timestamp = timestamp
        entry.dayStart = MFDates.startOfDay(timestamp)
        entry.note = note
        if let food = entry.food {
            entry.applySnapshot(food.scaledNutrients(grams: grams))
        }
        try context.save()
    }

    public func deleteEntry(_ entry: LogEntry) throws {
        context.delete(entry)
        try context.save()
    }

    // MARK: Reads

    public func entries(forDay dayStart: Date) throws -> [LogEntry] {
        try entries(from: dayStart, to: dayStart)
    }

    public func entries(from: Date, to: Date) throws -> [LogEntry] {
        // `from`/`to` are day starts (inclusive).
        let start = MFDates.startOfDay(from)
        let end = MFDates.startOfDay(to)
        let descriptor = FetchDescriptor<LogEntry>(
            predicate: #Predicate { $0.dayStart >= start && $0.dayStart <= end },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try context.fetch(descriptor)
    }

    public func dayTotals(_ dayStart: Date) throws -> MFDayTotals {
        MFDayTotals.summing(try entries(forDay: dayStart))
    }

    public func logDay(for dayStart: Date) throws -> LogDay? {
        let start = MFDates.startOfDay(dayStart)
        var descriptor = FetchDescriptor<LogDay>(predicate: #Predicate { $0.dayStart == start })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: Day operations

    private func getOrCreateLogDay(_ dayStart: Date) throws -> LogDay {
        let start = MFDates.startOfDay(dayStart)
        if let existing = try logDay(for: start) { return existing }
        let day = LogDay(dayStart: start)
        context.insert(day)
        return day
    }

    public func markDayComplete(_ dayStart: Date, complete: Bool) throws {
        let day = try getOrCreateLogDay(dayStart)
        day.isMarkedComplete = complete
        day.updatedAt = Date()
        try context.save()
    }

    public func setDayNote(_ dayStart: Date, note: String?) throws {
        let day = try getOrCreateLogDay(dayStart)
        day.note = note
        day.updatedAt = Date()
        try context.save()
    }

    public func copyDay(from sourceDay: Date, to targetDay: Date) throws -> [LogEntry] {
        let source = MFDates.startOfDay(sourceDay)
        let target = MFDates.startOfDay(targetDay)
        guard source != target else { return [] }
        var copies: [LogEntry] = []
        // Preserve time-of-day so meal ordering carries over.
        let calendar = Calendar.current
        for entry in try entries(forDay: source) {
            let time = calendar.dateComponents([.hour, .minute, .second], from: entry.timestamp)
            let newTimestamp = calendar.date(bySettingHour: time.hour ?? 12,
                                             minute: time.minute ?? 0,
                                             second: time.second ?? 0,
                                             of: target) ?? target
            var nutrients: [NutrientKey: Double] = [:]
            for key in NutrientKey.allCases { nutrients[key] = entry.snapshot(key) }
            let copy = LogEntry(
                timestamp: newTimestamp,
                dayStart: target,
                mealSlot: entry.mealSlot,
                source: .copied,
                food: entry.food,
                foodName: entry.foodName,
                grams: entry.grams,
                nutrients: nutrients,
                note: entry.note
            )
            context.insert(copy)
            copies.append(copy)
        }
        try context.save()
        return copies
    }

    public func clearDay(_ dayStart: Date) throws {
        for entry in try entries(forDay: dayStart) {
            context.delete(entry)
        }
        try context.save()
    }

    // MARK: Coaching mapping

    public func intakeDays(from: Date, to: Date) throws -> [IntakeDay] {
        let start = MFDates.startOfDay(from)
        let end = MFDates.startOfDay(to)
        let entries = try entries(from: start, to: end)

        var completeDays = Set<Date>()
        let dayDescriptor = FetchDescriptor<LogDay>(
            predicate: #Predicate { $0.dayStart >= start && $0.dayStart <= end }
        )
        for day in try context.fetch(dayDescriptor) where day.isMarkedComplete {
            completeDays.insert(day.dayStart)
        }

        var byDay: [Date: [LogEntry]] = [:]
        for entry in entries {
            byDay[entry.dayStart, default: []].append(entry)
        }
        return byDay.map { (dayStart, dayEntries) in
            let totals = MFDayTotals.summing(dayEntries)
            return IntakeDay(
                date: dayStart,
                calories: totals.calories,
                proteinGrams: totals.protein,
                fatGrams: totals.fat,
                carbsGrams: totals.carbs,
                isComplete: completeDays.contains(dayStart)
            )
        }
        .sorted { $0.date < $1.date }
    }
}
