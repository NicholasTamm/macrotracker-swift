//  FoodItem.swift
//  DataLayer — the food database: seed foods, Open Food Facts products,
//  custom foods, and recipes. All nutrients are stored per 100 g; servings
//  are presentation metadata on top.

import Foundation
import SwiftData

/// Where a food record came from.
public enum FoodSource: String, Codable, Sendable, CaseIterable {
    /// Bundled seed database (generic foods, original data).
    case seedDatabase
    /// Imported from Open Food Facts (barcode lookup / search, cached).
    case openFoodFacts
    /// Created by the user in-app.
    case custom
    /// Built from ingredients (recipe builder / URL import / cookbook photo).
    case recipe
    /// Created from a nutrition-label scan.
    case labelScan
    /// Estimated from a photo.
    case photoEstimate
    /// Estimated from a voice description.
    case voiceEstimate
}

@Model
public final class FoodItem {

    @Attribute(.unique) public var id: UUID
    public var sourceRaw: String
    public var name: String
    public var brand: String
    public var barcode: String?
    /// Human serving description, e.g. "1 medium apple (182 g)".
    public var servingDescription: String
    /// Grams per serving; nutrient math always goes through per-100-g values.
    public var servingSizeGrams: Double
    /// Open Food Facts product code, when imported from OFF.
    public var openFoodFactsCode: String?
    /// Soft-delete flag for user foods (keeps log-entry snapshots intact).
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    // MARK: Nutrients per 100 g (see MFNutrientFields.swift for the catalog)

    public var caloriesPer100g: Double = 0
    public var proteinPer100g: Double = 0
    public var fatPer100g: Double = 0
    public var carbsPer100g: Double = 0
    public var fiberPer100g: Double = 0
    public var sugarPer100g: Double = 0
    public var saturatedFatPer100g: Double = 0
    public var transFatPer100g: Double = 0
    public var cholesterolPer100g: Double = 0
    public var alcoholPer100g: Double = 0
    public var sodiumPer100g: Double = 0
    public var potassiumPer100g: Double = 0
    public var calciumPer100g: Double = 0
    public var ironPer100g: Double = 0
    public var magnesiumPer100g: Double = 0
    public var phosphorusPer100g: Double = 0
    public var zincPer100g: Double = 0
    public var copperPer100g: Double = 0
    public var manganesePer100g: Double = 0
    public var vitaminAPer100g: Double = 0
    public var vitaminCPer100g: Double = 0
    public var vitaminDPer100g: Double = 0
    public var vitaminEPer100g: Double = 0
    public var vitaminKPer100g: Double = 0
    public var thiaminPer100g: Double = 0
    public var riboflavinPer100g: Double = 0
    public var niacinPer100g: Double = 0
    public var vitaminB6Per100g: Double = 0
    public var folatePer100g: Double = 0
    public var vitaminB12Per100g: Double = 0
    public var seleniumPer100g: Double = 0
    public var iodinePer100g: Double = 0
    public var caffeinePer100g: Double = 0

    // MARK: Relationships

    /// Log entries referencing this food. Nullified on delete — entries keep
    /// their nutrient snapshot, so history never breaks.
    @Relationship(deleteRule: .nullify, inverse: \LogEntry.food)
    public var logEntries: [LogEntry] = []

    /// Ingredients, when this food is a recipe. Cascaded on delete.
    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    public var recipeIngredients: [RecipeIngredient] = []

    public init(
        id: UUID = UUID(),
        source: FoodSource,
        name: String,
        brand: String = "",
        barcode: String? = nil,
        servingDescription: String = "",
        servingSizeGrams: Double = 100,
        openFoodFactsCode: String? = nil
    ) {
        self.id = id
        self.sourceRaw = source.rawValue
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.servingDescription = servingDescription
        self.servingSizeGrams = servingSizeGrams
        self.openFoodFactsCode = openFoodFactsCode
        self.isArchived = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public var source: FoodSource {
        get { FoodSource(rawValue: sourceRaw) ?? .custom }
        set { sourceRaw = newValue.rawValue }
    }

    public var isRecipe: Bool { !recipeIngredients.isEmpty }

    /// Display name including brand, e.g. "Greek Yogurt — Plain Brand".
    public var displayName: String {
        brand.isEmpty ? name : "\(name) — \(brand)"
    }
}

// MARK: - Nutrient access

extension FoodItem {
    /// Per-100-g value for a nutrient key.
    public func per100g(_ key: NutrientKey) -> Double {
        switch key {
        case .calories: return caloriesPer100g
        case .protein: return proteinPer100g
        case .fat: return fatPer100g
        case .carbs: return carbsPer100g
        case .fiber: return fiberPer100g
        case .sugar: return sugarPer100g
        case .saturatedFat: return saturatedFatPer100g
        case .transFat: return transFatPer100g
        case .cholesterol: return cholesterolPer100g
        case .alcohol: return alcoholPer100g
        case .sodium: return sodiumPer100g
        case .potassium: return potassiumPer100g
        case .calcium: return calciumPer100g
        case .iron: return ironPer100g
        case .magnesium: return magnesiumPer100g
        case .phosphorus: return phosphorusPer100g
        case .zinc: return zincPer100g
        case .copper: return copperPer100g
        case .manganese: return manganesePer100g
        case .vitaminA: return vitaminAPer100g
        case .vitaminC: return vitaminCPer100g
        case .vitaminD: return vitaminDPer100g
        case .vitaminE: return vitaminEPer100g
        case .vitaminK: return vitaminKPer100g
        case .thiamin: return thiaminPer100g
        case .riboflavin: return riboflavinPer100g
        case .niacin: return niacinPer100g
        case .vitaminB6: return vitaminB6Per100g
        case .folate: return folatePer100g
        case .vitaminB12: return vitaminB12Per100g
        case .selenium: return seleniumPer100g
        case .iodine: return iodinePer100g
        case .caffeine: return caffeinePer100g
        }
    }

    public func setPer100g(_ key: NutrientKey, _ value: Double) {
        switch key {
        case .calories: caloriesPer100g = value
        case .protein: proteinPer100g = value
        case .fat: fatPer100g = value
        case .carbs: carbsPer100g = value
        case .fiber: fiberPer100g = value
        case .sugar: sugarPer100g = value
        case .saturatedFat: saturatedFatPer100g = value
        case .transFat: transFatPer100g = value
        case .cholesterol: cholesterolPer100g = value
        case .alcohol: alcoholPer100g = value
        case .sodium: sodiumPer100g = value
        case .potassium: potassiumPer100g = value
        case .calcium: calciumPer100g = value
        case .iron: ironPer100g = value
        case .magnesium: magnesiumPer100g = value
        case .phosphorus: phosphorusPer100g = value
        case .zinc: zincPer100g = value
        case .copper: copperPer100g = value
        case .manganese: manganesePer100g = value
        case .vitaminA: vitaminAPer100g = value
        case .vitaminC: vitaminCPer100g = value
        case .vitaminD: vitaminDPer100g = value
        case .vitaminE: vitaminEPer100g = value
        case .vitaminK: vitaminKPer100g = value
        case .thiamin: thiaminPer100g = value
        case .riboflavin: riboflavinPer100g = value
        case .niacin: niacinPer100g = value
        case .vitaminB6: vitaminB6Per100g = value
        case .folate: folatePer100g = value
        case .vitaminB12: vitaminB12Per100g = value
        case .selenium: seleniumPer100g = value
        case .iodine: iodinePer100g = value
        case .caffeine: caffeinePer100g = value
        }
    }

    /// Absolute nutrient amounts for `grams` of this food.
    public func scaledNutrients(grams: Double) -> [NutrientKey: Double] {
        let factor = grams / 100.0
        var out: [NutrientKey: Double] = [:]
        for key in NutrientKey.allCases {
            out[key] = per100g(key) * factor
        }
        return out
    }

    /// Nutrients for one serving (`servingSizeGrams`).
    public func nutrientsPerServing() -> [NutrientKey: Double] {
        scaledNutrients(grams: servingSizeGrams)
    }
}

// MARK: - Recipe ingredient join

@Model
public final class RecipeIngredient {
    @Attribute(.unique) public var id: UUID
    public var grams: Double
    public var sortOrder: Int

    @Relationship(deleteRule: .nullify)
    public var food: FoodItem?

    @Relationship(deleteRule: .nullify)
    public var recipe: FoodItem?

    public init(id: UUID = UUID(), food: FoodItem? = nil, grams: Double, sortOrder: Int = 0) {
        self.id = id
        self.food = food
        self.grams = grams
        self.sortOrder = sortOrder
    }
}
