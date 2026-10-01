import Combine
import Foundation
import DataLayer

// MARK: - FoodLogClipboard

/// In-memory copy/paste for the food log: a single food, a time block
/// (all entries in one hour), or a whole day.
///
/// The clipboard holds plain snapshots (no SwiftData objects) so payloads
/// survive context resets. Pasting is performed by `FoodLogViewModel`,
/// which re-logs through `LogRepository`.
@MainActor
public final class FoodLogClipboard: ObservableObject {
    public static let shared = FoodLogClipboard()

    /// A nutrient snapshot of one entry, enough to re-log it elsewhere.
    public struct EntrySnapshot: Sendable {
        public var foodID: UUID?
        public var foodName: String
        public var grams: Double
        public var mealSlot: MealSlot
        public var note: String?
        public var nutrients: [NutrientKey: Double]

        public init(
            foodID: UUID? = nil,
            foodName: String,
            grams: Double,
            mealSlot: MealSlot = .other,
            note: String? = nil,
            nutrients: [NutrientKey: Double] = [:]
        ) {
            self.foodID = foodID
            self.foodName = foodName
            self.grams = grams
            self.mealSlot = mealSlot
            self.note = note
            self.nutrients = nutrients
        }

        /// Snapshot of a live `LogEntry`.
        public init(entry: LogEntry) {
            var nutrients: [NutrientKey: Double] = [:]
            for key in NutrientKey.allCases { nutrients[key] = entry.snapshot(key) }
            self.init(
                foodID: entry.food?.id,
                foodName: entry.foodName,
                grams: entry.grams,
                mealSlot: entry.mealSlot,
                note: entry.note,
                nutrients: nutrients
            )
        }
    }

    public enum Payload {
        case food(EntrySnapshot)
        case block(label: String, snapshots: [EntrySnapshot])
        case day(sourceDay: Date)
    }

    @Published public private(set) var payload: Payload?

    private init() {}

    public var isEmpty: Bool { payload == nil }

    /// Short label for menus, e.g. "Paste day", "Paste 3 foods".
    public var pasteLabel: String? {
        switch payload {
        case .food: return "Paste food"
        case .block(_, let snapshots): return "Paste \(snapshots.count) foods"
        case .day: return "Paste day"
        case nil: return nil
        }
    }

    public func copyFood(_ entry: LogEntry) {
        payload = .food(EntrySnapshot(entry: entry))
    }

    public func copyFoodItem(_ food: FoodItem, grams: Double) {
        payload = .food(EntrySnapshot(
            foodID: food.id,
            foodName: food.displayName,
            grams: grams,
            nutrients: food.scaledNutrients(grams: grams)
        ))
    }

    public func copyBlock(label: String, entries: [LogEntry]) {
        guard !entries.isEmpty else { return }
        payload = .block(label: label, snapshots: entries.map(EntrySnapshot.init(entry:)))
    }

    public func copyDay(_ dayStart: Date) {
        payload = .day(sourceDay: dayStart)
    }

    public func clear() {
        payload = nil
    }
}
