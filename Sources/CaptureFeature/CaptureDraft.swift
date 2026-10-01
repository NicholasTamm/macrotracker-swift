import Foundation
import DataLayer

// MARK: - CaptureDraft

/// One editable food candidate produced by a capture flow (barcode, label
/// OCR, photo estimate, voice, recipe import). The user reviews and edits
/// the draft, then either saves it to the food database, or saves it and
/// logs an entry in one step.
///
/// All nutrients are per 100 g, matching `FoodItem`'s storage convention.
public struct CaptureDraft: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var brand: String
    public var barcode: String?
    /// Human serving description, e.g. "1 bar (45 g)".
    public var servingDescription: String
    /// Grams per serving; nutrient math always goes through per-100-g values.
    public var servingSizeGrams: Double
    /// Grams the user wants to log (defaults to one serving).
    public var gramsToLog: Double
    public var mealSlot: MealSlot
    /// Per-100-g nutrients.
    public var nutrientsPer100g: [NutrientKey: Double]
    public var source: FoodSource
    public var entrySource: EntrySource
    /// 0...1 confidence for AI-produced estimates (photo/voice). Nil for
    /// deterministic flows (barcode, label OCR, recipe import).
    public var confidence: Double?
    public var note: String?

    public init(
        id: UUID = UUID(),
        name: String = "",
        brand: String = "",
        barcode: String? = nil,
        servingDescription: String = "",
        servingSizeGrams: Double = 100,
        gramsToLog: Double? = nil,
        mealSlot: MealSlot = .other,
        nutrientsPer100g: [NutrientKey: Double] = [:],
        source: FoodSource = .custom,
        entrySource: EntrySource = .manualSearch,
        confidence: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.servingDescription = servingDescription
        self.servingSizeGrams = servingSizeGrams
        self.gramsToLog = gramsToLog ?? servingSizeGrams
        self.mealSlot = mealSlot
        self.nutrientsPer100g = nutrientsPer100g
        self.source = source
        self.entrySource = entrySource
        self.confidence = confidence
        self.note = note
    }

    /// Absolute nutrient amounts for `gramsToLog`.
    public var scaledNutrients: [NutrientKey: Double] {
        let factor = gramsToLog / 100.0
        var out: [NutrientKey: Double] = [:]
        for key in NutrientKey.allCases {
            out[key] = (nutrientsPer100g[key] ?? 0) * factor
        }
        return out
    }

    public var scaledCalories: Double { scaledNutrients[.calories] ?? 0 }
    public var scaledProtein: Double { scaledNutrients[.protein] ?? 0 }
    public var scaledFat: Double { scaledNutrients[.fat] ?? 0 }
    public var scaledCarbs: Double { scaledNutrients[.carbs] ?? 0 }

    /// The draft can be saved when it has a name and positive amounts.
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && servingSizeGrams > 0
            && gramsToLog > 0
    }

    // MARK: Persistence

    /// Persists the draft as a `FoodItem` (via `FoodRepository.saveFood`).
    @MainActor
    @discardableResult
    public func saveFood(using deps: CaptureDependencies) throws -> FoodItem {
        try deps.foods.saveFood(
            name: name,
            brand: brand,
            barcode: barcode,
            servingDescription: servingDescription,
            servingSizeGrams: servingSizeGrams,
            nutrientsPer100g: nutrientsPer100g,
            source: source
        )
    }

    /// Persists the draft and logs `gramsToLog` in one step. Callers fire
    /// `deps.noteFoodLogged()` once per user action after this succeeds
    /// (see the capture flows); this helper stays hook-free so multi-item
    /// loops don't fire it per entry.
    @MainActor
    @discardableResult
    public func saveAndLog(using deps: CaptureDependencies) throws -> LogEntry {
        let food = try saveFood(using: deps)
        return try deps.log.logFood(
            food,
            grams: gramsToLog,
            mealSlot: mealSlot,
            source: entrySource,
            note: note
        )
    }
}
