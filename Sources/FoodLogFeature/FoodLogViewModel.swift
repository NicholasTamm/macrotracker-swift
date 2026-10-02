import Foundation
import DataLayer

// MARK: - MFDayMacroGoals

/// Daily energy + macro targets for one log day (value type local to
/// FoodLogFeature — DataLayer/CoachingEngine stay out of the UI layer).
public struct MFDayMacroGoals: Equatable, Sendable {
    public var calories: Double
    public var protein: Double
    public var fat: Double
    public var carbs: Double

    public init(calories: Double, protein: Double, fat: Double, carbs: Double) {
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
    }

    public static let empty = MFDayMacroGoals(calories: 0, protein: 0, fat: 0, carbs: 0)
}

// MARK: - FoodLogViewModel

/// Owns the Food Log tab's day state: entries, totals, targets, and the
/// day actions (copy/paste, complete, note, clear).
@MainActor
@Observable
public final class FoodLogViewModel {
    private let logs: any LogRepository
    private let foods: any FoodRepository
    private let program: any ProgramRepository

    /// Start of the selected log day (device calendar).
    public var selectedDay: Date

    public private(set) var entries: [LogEntry] = []
    public private(set) var totals: MFDayTotals = MFDayTotals()
    public private(set) var goals: MFDayMacroGoals = .empty
    public private(set) var isDayComplete: Bool = false
    public private(set) var dayNote: String?
    /// Days in the visible week that have logged food (for the day pills).
    public private(set) var weekLoggedDays: Set<Date> = []
    public private(set) var lastError: String?
    /// Second summary-strip page: (nutrient, target) for key micros.
    public private(set) var microGoals: [(key: NutrientKey, target: Double)] = []

    /// Hook fired when food is successfully logged for **today** (log,
    /// plate, quick add, paste). FoodLogFeature must not import
    /// TrackingFeature (MODULE_MAP rule 1), so AppShell wires this to
    /// `trackingEnv.logTodayCompletion(kind: .foodLogging)` — mirroring
    /// how `WeighInSheet` feeds weigh-in streaks — keeping the "Log food"
    /// habit streak accurate.
    public var onFoodLogged: (() -> Void)?

    public var clipboard: FoodLogClipboard { FoodLogClipboard.shared }

    public init(
        logs: any LogRepository,
        foods: any FoodRepository,
        program: any ProgramRepository,
        selectedDay: Date = MFDates.startOfDay(Date())
    ) {
        self.logs = logs
        self.foods = foods
        self.program = program
        self.selectedDay = MFDates.startOfDay(selectedDay)
    }

    // MARK: Loading

    public func reload() {
        do {
            entries = try logs.entries(forDay: selectedDay)
            totals = try logs.dayTotals(selectedDay)
            goals = try resolveGoals(for: selectedDay)
            let record = try logs.logDay(for: selectedDay)
            isDayComplete = record?.isMarkedComplete ?? false
            dayNote = record?.note
            weekLoggedDays = try loggedDays(inWeekOf: selectedDay)
            microGoals = try loadMicroGoals()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func resolveGoals(for day: Date) throws -> MFDayMacroGoals {
        let settings = try program.settings()
        let weekday = MFDates.weekday(of: day)
        if let override = try program.dayOverrides().first(where: { $0.weekday == weekday }) {
            return MFDayMacroGoals(
                calories: override.calories,
                protein: override.proteinGrams,
                fat: override.fatGrams,
                carbs: override.carbsGrams
            )
        }
        return MFDayMacroGoals(
            calories: settings.currentCalories,
            protein: settings.currentProteinGrams,
            fat: settings.currentFatGrams,
            carbs: settings.currentCarbsGrams
        )
    }

    private func loggedDays(inWeekOf day: Date) throws -> Set<Date> {
        let week = Self.weekDays(containing: day)
        guard let first = week.first, let last = week.last else { return [] }
        let days = try logs.entries(from: first, to: last)
        return Set(days.map { MFDates.startOfDay($0.dayStart) })
    }

    /// Targets for the summary strip's micronutrient page.
    private func loadMicroGoals() throws -> [(key: NutrientKey, target: Double)] {
        let keys: [NutrientKey] = [.fiber, .sugar, .sodium, .potassium]
        return try keys.map { key in
            let target = try program.target(for: key)?.targetValue ?? 0
            return (key, target)
        }
    }

    // MARK: Day navigation

    public func selectDay(_ day: Date) {
        selectedDay = MFDates.startOfDay(day)
        reload()
    }

    public func shiftDay(by days: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: selectedDay) else { return }
        selectDay(next)
    }

    // MARK: Logging

    @discardableResult
    public func logFood(_ food: FoodItem, grams: Double, mealSlot: MealSlot, timestamp: Date, note: String?) -> Bool {
        do {
            try logs.logFood(food, grams: grams, mealSlot: mealSlot, timestamp: timestamp, note: note, source: .manualSearch)
            reload()
            noteFoodLogged(at: timestamp)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    public func logPlate(_ items: [PlateItem], timestamp: Date) -> Bool {
        do {
            for item in items {
                try logs.logFood(
                    item.food,
                    grams: item.grams,
                    mealSlot: item.mealSlot,
                    timestamp: timestamp,
                    note: item.note,
                    source: .manualSearch
                )
            }
            reload()
            noteFoodLogged(at: timestamp)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    public func updateEntry(_ entry: LogEntry, grams: Double, mealSlot: MealSlot, timestamp: Date, note: String?) {
        do {
            try logs.updateEntry(entry, grams: grams, mealSlot: mealSlot, timestamp: timestamp, note: note)
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Quick-add: calories/macros without a food record.
    @discardableResult
    public func quickAdd(
        calories: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        mealSlot: MealSlot,
        timestamp: Date = Date(),
        note: String? = nil
    ) -> Bool {
        do {
            try logs.quickAdd(
                calories: calories,
                proteinGrams: protein,
                fatGrams: fat,
                carbsGrams: carbs,
                mealSlot: mealSlot,
                timestamp: timestamp,
                note: note
            )
            reload()
            noteFoodLogged(at: timestamp)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    public func deleteEntry(_ entry: LogEntry) {
        do {
            try logs.deleteEntry(entry)
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Day actions

    public func toggleDayComplete() {
        do {
            try logs.markDayComplete(selectedDay, complete: !isDayComplete)
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func setDayNote(_ note: String?) {
        do {
            try logs.setDayNote(selectedDay, note: note?.isEmpty == true ? nil : note)
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func clearDay() {
        do {
            try logs.clearDay(selectedDay)
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func copyCurrentDay() {
        clipboard.copyDay(selectedDay)
    }

    /// Pastes the clipboard payload into the selected day. Returns the
    /// number of entries created.
    @discardableResult
    public func pasteIntoSelectedDay() -> Int {
        guard let payload = clipboard.payload else { return 0 }
        do {
            switch payload {
            case .food(let snapshot):
                try pasteSnapshot(snapshot, at: Date())
                reload()
                noteFoodLogged(at: Date())
                return 1
            case .block(_, let snapshots):
                let now = Date()
                for snapshot in snapshots { try pasteSnapshot(snapshot, at: now) }
                reload()
                noteFoodLogged(at: now)
                return snapshots.count
            case .day(let sourceDay):
                let copies = try logs.copyDay(from: sourceDay, to: selectedDay)
                reload()
                if !copies.isEmpty { noteFoodLogged(at: selectedDay) }
                return copies.count
            }
        } catch {
            lastError = error.localizedDescription
            return 0
        }
    }

    /// Fires `onFoodLogged` only when the written timestamp falls on the
    /// device's current day — backfilling a past day must not feed today's
    /// streak. No-ops when no hook is wired.
    private func noteFoodLogged(at timestamp: Date) {
        guard Calendar.current.isDateInToday(timestamp) else { return }
        onFoodLogged?()
    }

    private func pasteSnapshot(_ snapshot: FoodLogClipboard.EntrySnapshot, at date: Date) throws {
        if let foodID = snapshot.foodID, let food = try foods.food(id: foodID) {
            try logs.logFood(
                food,
                grams: snapshot.grams,
                mealSlot: snapshot.mealSlot,
                timestamp: date,
                note: snapshot.note,
                source: .copied
            )
        } else {
            // Foodless snapshot (e.g. quick-add): re-log the macro values.
            try logs.quickAdd(
                calories: snapshot.nutrients[.calories] ?? 0,
                proteinGrams: snapshot.nutrients[.protein] ?? 0,
                fatGrams: snapshot.nutrients[.fat] ?? 0,
                carbsGrams: snapshot.nutrients[.carbs] ?? 0,
                mealSlot: snapshot.mealSlot,
                timestamp: date,
                note: snapshot.note
            )
        }
    }

    // MARK: Week math

    /// The 7 day-starts of the Monday-start week containing `day`.
    public static func weekDays(containing day: Date, calendar: Calendar = .current) -> [Date] {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2 // Monday
        let startOfDay = MFDates.startOfDay(day, calendar: calendar)
        let interval = mondayCalendar.dateInterval(of: .weekOfYear, for: startOfDay)
        guard let weekStart = interval?.start else { return [startOfDay] }
        return (0..<7).compactMap { mondayCalendar.date(byAdding: .day, value: $0, to: weekStart) }
    }
}

// MARK: - PlateItem

/// One food staged on the plate before logging.
public struct PlateItem: Identifiable {
    public var id: UUID
    public var food: FoodItem
    public var grams: Double
    public var mealSlot: MealSlot
    public var note: String?

    public init(id: UUID = UUID(), food: FoodItem, grams: Double, mealSlot: MealSlot = .other, note: String? = nil) {
        self.id = id
        self.food = food
        self.grams = grams
        self.mealSlot = mealSlot
        self.note = note
    }

    public var nutrients: [NutrientKey: Double] { food.scaledNutrients(grams: grams) }
}
