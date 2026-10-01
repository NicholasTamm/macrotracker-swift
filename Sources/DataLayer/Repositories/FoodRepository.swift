//  FoodRepository.swift
//  DataLayer — CRUD for FoodItem and recipes. Features program to
//  `FoodRepository`; only this file touches SwiftData for foods.

import Foundation
import SwiftData

@MainActor
public protocol FoodRepository {
    // MARK: Reads
    func food(id: UUID) throws -> FoodItem?
    func searchFoods(query: String, limit: Int) throws -> [FoodItem]
    func foods(barcode: String) throws -> [FoodItem]
    func allFoods(limit: Int, source: FoodSource?) throws -> [FoodItem]
    func recipes() throws -> [FoodItem]
    func customFoods() throws -> [FoodItem]

    // MARK: Writes
    @discardableResult
    func saveFood(
        name: String,
        brand: String = "",
        barcode: String? = nil,
        servingDescription: String = "",
        servingSizeGrams: Double = 100,
        nutrientsPer100g: [NutrientKey: Double] = [:],
        source: FoodSource = .custom
    ) throws -> FoodItem
    func updateFood(_ food: FoodItem) throws
    /// Soft-delete: archived foods stay out of search but keep history intact.
    func archiveFood(_ food: FoodItem) throws
    func unarchiveFood(_ food: FoodItem) throws
    /// Hard delete. Log entries referencing the food keep their snapshots
    /// (relationship is nullify); recipe ingredients keep their grams.
    func deleteFood(_ food: FoodItem) throws

    // MARK: Recipes
    @discardableResult
    func createRecipe(
        name: String,
        servingDescription: String = "",
        servingSizeGrams: Double = 100,
        ingredients: [(food: FoodItem, grams: Double)] = []
    ) throws -> FoodItem
    func addIngredient(to recipe: FoodItem, food: FoodItem, grams: Double) throws
    func updateIngredient(_ ingredient: RecipeIngredient, grams: Double) throws
    func removeIngredient(_ ingredient: RecipeIngredient) throws
    /// Recomputes the recipe's per-100-g nutrients from its ingredients.
    func recomputeRecipeNutrients(_ recipe: FoodItem) throws
}

// MARK: - SwiftData implementation

@MainActor
public final class SwiftDataFoodRepository: FoodRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: Reads

    public func food(id: UUID) throws -> FoodItem? {
        var descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    public func searchFoods(query: String, limit: Int = 50) throws -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate {
                $0.isArchived == false
                    && ($0.name.localizedStandardContains(trimmed)
                        || $0.brand.localizedStandardContains(trimmed))
            },
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    public func foods(barcode: String) throws -> [FoodItem] {
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.barcode == barcode && $0.isArchived == false }
        )
        return try context.fetch(descriptor)
    }

    public func allFoods(limit: Int = 200, source: FoodSource? = nil) throws -> [FoodItem] {
        let descriptor: FetchDescriptor<FoodItem>
        if let raw = source?.rawValue {
            descriptor = FetchDescriptor<FoodItem>(
                predicate: #Predicate { $0.isArchived == false && $0.sourceRaw == raw },
                sortBy: [SortDescriptor(\.name)]
            )
        } else {
            descriptor = FetchDescriptor<FoodItem>(
                predicate: #Predicate { $0.isArchived == false },
                sortBy: [SortDescriptor(\.name)]
            )
        }
        var limited = descriptor
        limited.fetchLimit = limit
        return try context.fetch(limited)
    }

    public func recipes() throws -> [FoodItem] {
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.sourceRaw == "recipe" && $0.isArchived == false },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    public func customFoods() throws -> [FoodItem] {
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.sourceRaw == "custom" && $0.isArchived == false },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: Writes

    @discardableResult
    public func saveFood(
        name: String,
        brand: String = "",
        barcode: String? = nil,
        servingDescription: String = "",
        servingSizeGrams: Double = 100,
        nutrientsPer100g: [NutrientKey: Double] = [:],
        source: FoodSource = .custom
    ) throws -> FoodItem {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MFDataError.invalidInput("Food name can't be empty.") }
        guard servingSizeGrams > 0 else { throw MFDataError.invalidInput("Serving size must be positive.") }
        let food = FoodItem(
            source: source,
            name: trimmed,
            brand: brand,
            barcode: barcode,
            servingDescription: servingDescription,
            servingSizeGrams: servingSizeGrams
        )
        for (key, value) in nutrientsPer100g {
            food.setPer100g(key, max(0, value))
        }
        context.insert(food)
        try context.save()
        return food
    }

    public func updateFood(_ food: FoodItem) throws {
        food.updatedAt = Date()
        try context.save()
    }

    public func archiveFood(_ food: FoodItem) throws {
        food.isArchived = true
        food.updatedAt = Date()
        try context.save()
    }

    public func unarchiveFood(_ food: FoodItem) throws {
        food.isArchived = false
        food.updatedAt = Date()
        try context.save()
    }

    public func deleteFood(_ food: FoodItem) throws {
        context.delete(food)
        try context.save()
    }

    // MARK: Recipes

    @discardableResult
    public func createRecipe(
        name: String,
        servingDescription: String = "",
        servingSizeGrams: Double = 100,
        ingredients: [(food: FoodItem, grams: Double)] = []
    ) throws -> FoodItem {
        let recipe = try saveFood(
            name: name,
            servingDescription: servingDescription,
            servingSizeGrams: servingSizeGrams,
            source: .recipe
        )
        for (index, ingredient) in ingredients.enumerated() {
            guard ingredient.grams > 0 else { continue }
            let join = RecipeIngredient(
                food: ingredient.food,
                grams: ingredient.grams,
                sortOrder: index
            )
            join.recipe = recipe
            context.insert(join)
        }
        try recomputeRecipeNutrients(recipe)
        try context.save()
        return recipe
    }

    public func addIngredient(to recipe: FoodItem, food: FoodItem, grams: Double) throws {
        guard grams > 0 else { throw MFDataError.invalidInput("Ingredient amount must be positive.") }
        let order = (recipe.recipeIngredients.map(\.sortOrder).max() ?? -1) + 1
        let join = RecipeIngredient(food: food, grams: grams, sortOrder: order)
        join.recipe = recipe
        context.insert(join)
        try recomputeRecipeNutrients(recipe)
        try context.save()
    }

    public func updateIngredient(_ ingredient: RecipeIngredient, grams: Double) throws {
        guard grams > 0 else { throw MFDataError.invalidInput("Ingredient amount must be positive.") }
        ingredient.grams = grams
        if let recipe = ingredient.recipe {
            try recomputeRecipeNutrients(recipe)
        }
        try context.save()
    }

    public func removeIngredient(_ ingredient: RecipeIngredient) throws {
        let recipe = ingredient.recipe
        context.delete(ingredient)
        if let recipe {
            try recomputeRecipeNutrients(recipe)
        }
        try context.save()
    }

    public func recomputeRecipeNutrients(_ recipe: FoodItem) throws {
        let ingredients = recipe.recipeIngredients.sorted { $0.sortOrder < $1.sortOrder }
        let totalGrams = ingredients.reduce(0) { $0 + $1.grams }
        guard totalGrams > 0 else { return }
        for key in NutrientKey.allCases {
            let total = ingredients.reduce(0.0) { partial, ingredient in
                guard let food = ingredient.food else { return partial }
                return partial + food.per100g(key) * ingredient.grams / 100.0
            }
            recipe.setPer100g(key, total / totalGrams * 100.0)
        }
        recipe.updatedAt = Date()
    }
}
