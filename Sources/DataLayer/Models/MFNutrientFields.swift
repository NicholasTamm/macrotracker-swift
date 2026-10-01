//  MFNutrientFields.swift
//  DataLayer — canonical nutrient catalog.
//
//  Every nutrient the app tracks, in one place. `NutrientKey` is the single
//  source of truth for nutrient identity: FoodItem stores per-100g values,
//  LogEntry stores absolute snapshot values, NutrientTarget stores daily
//  goals, and Analytics (#8) iterates `NutrientKey.allCases` for "top
//  contributors" and micro dashboards.
//
//  Storage note: nutrients are flattened into individual Double columns on
//  the models (rather than a transformable dictionary) so they stay
//  CloudKit-compatible and SQL-queryable. The property-name convention is:
//    FoodItem  →  `<rawValue>Per100g`   (e.g. `proteinPer100g`)
//    LogEntry  →  `<rawValue>`          (e.g. `protein`, absolute grams logged)

import Foundation

/// Every nutrient the app can store, with its display unit.
/// Raw value doubles as the model's stored-property base name.
public enum NutrientKey: String, CaseIterable, Codable, Sendable {
    // Energy + macros
    case calories
    case protein
    case fat
    case carbs
    case fiber
    case sugar
    case saturatedFat
    case transFat
    case cholesterol
    case alcohol
    // Minerals (mg unless noted)
    case sodium
    case potassium
    case calcium
    case iron
    case magnesium
    case phosphorus
    case zinc
    case copper
    case manganese
    // Vitamins
    case vitaminA      // mcg RAE
    case vitaminC      // mg
    case vitaminD      // mcg
    case vitaminE      // mg
    case vitaminK      // mcg
    case thiamin       // mg (B1)
    case riboflavin    // mg (B2)
    case niacin        // mg (B3)
    case vitaminB6     // mg
    case folate        // mcg DFE
    case vitaminB12    // mcg
    case selenium      // mcg
    case iodine        // mcg
    case caffeine      // mg

    /// Display unit for this nutrient.
    public var unit: String {
        switch self {
        case .calories:
            return "kcal"
        case .protein, .fat, .carbs, .fiber, .sugar,
             .saturatedFat, .transFat, .alcohol:
            return "g"
        case .cholesterol,
             .sodium, .potassium, .calcium, .iron, .magnesium,
             .phosphorus, .zinc, .copper, .manganese,
             .vitaminC, .vitaminE,
             .thiamin, .riboflavin, .niacin, .vitaminB6,
             .caffeine:
            return "mg"
        case .vitaminA, .vitaminD, .vitaminK,
             .folate, .vitaminB12, .selenium, .iodine:
            return "mcg"
        }
    }

    /// Short display name (original copy — not copied from any app).
    public var displayName: String {
        switch self {
        case .calories: return "Calories"
        case .protein: return "Protein"
        case .fat: return "Fat"
        case .carbs: return "Carbs"
        case .fiber: return "Fiber"
        case .sugar: return "Sugar"
        case .saturatedFat: return "Saturated fat"
        case .transFat: return "Trans fat"
        case .cholesterol: return "Cholesterol"
        case .alcohol: return "Alcohol"
        case .sodium: return "Sodium"
        case .potassium: return "Potassium"
        case .calcium: return "Calcium"
        case .iron: return "Iron"
        case .magnesium: return "Magnesium"
        case .phosphorus: return "Phosphorus"
        case .zinc: return "Zinc"
        case .copper: return "Copper"
        case .manganese: return "Manganese"
        case .vitaminA: return "Vitamin A"
        case .vitaminC: return "Vitamin C"
        case .vitaminD: return "Vitamin D"
        case .vitaminE: return "Vitamin E"
        case .vitaminK: return "Vitamin K"
        case .thiamin: return "Thiamin (B1)"
        case .riboflavin: return "Riboflavin (B2)"
        case .niacin: return "Niacin (B3)"
        case .vitaminB6: return "Vitamin B6"
        case .folate: return "Folate"
        case .vitaminB12: return "Vitamin B12"
        case .selenium: return "Selenium"
        case .iodine: return "Iodine"
        case .caffeine: return "Caffeine"
        }
    }

    /// The four headline macros shown in the food-log header ring.
    public var isHeadlineMacro: Bool {
        switch self {
        case .calories, .protein, .fat, .carbs: return true
        default: return false
        }
    }

    /// Nutrients typically tracked as micronutrients (everything past the macros).
    public var isMicronutrient: Bool {
        switch self {
        case .calories, .protein, .fat, .carbs: return false
        default: return true
        }
    }
}
