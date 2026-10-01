//  SeedData.swift
//  DataLayer — first-launch import of the bundled seed food database.
//
//  Strategy: a small, credible set of generic foods ships in the bundle
//  (Schema/Resources/seed_foods.json). It is imported once (tracked via
//  UserDefaults `seedVersion`); future app versions can ship a higher
//  `version` to add more seed foods without duplicating existing ones
//  (matched on source + name).

import Foundation
import SwiftData

public enum SeedDataLoader {
    private static let seedVersionKey = "MFSeedDatabaseVersion"

    private struct SeedFile: Decodable {
        var version: Int
        var foods: [SeedFood]
    }

    private struct SeedFood: Decodable {
        var name: String
        var brand: String?
        var servingDescription: String?
        var servingSizeGrams: Double?
        var nutrients: [String: Double]?
    }

    /// Imports the bundled seed database if it hasn't been imported yet.
    /// Safe to call on every launch; no-ops when up to date.
    @MainActor
    public static func loadIfNeeded(into context: ModelContext) throws {
        guard let url = Bundle.module.url(forResource: "seed_foods", withExtension: "json") else {
            return // No seed bundled (shouldn't happen in the app target).
        }
        let data = try Data(contentsOf: url)
        let seed = try JSONDecoder().decode(SeedFile.self, from: data)

        let importedVersion = UserDefaults.standard.integer(forKey: seedVersionKey)
        guard seed.version > importedVersion else { return }

        for seedFood in seed.foods {
            // Skip foods already imported by an earlier seed version.
            let name = seedFood.name
            var descriptor = FetchDescriptor<FoodItem>(
                predicate: #Predicate {
                    $0.sourceRaw == "seedDatabase" && $0.name == name
                }
            )
            descriptor.fetchLimit = 1
            if try context.fetch(descriptor).first != nil { continue }

            let food = FoodItem(
                source: .seedDatabase,
                name: seedFood.name,
                brand: seedFood.brand ?? "",
                servingDescription: seedFood.servingDescription ?? "",
                servingSizeGrams: seedFood.servingSizeGrams ?? 100
            )
            for (key, value) in seedFood.nutrients ?? [:] {
                if let nutrientKey = NutrientKey(rawValue: key) {
                    food.setPer100g(nutrientKey, value)
                }
            }
            context.insert(food)
        }

        try context.save()
        UserDefaults.standard.set(seed.version, forKey: seedVersionKey)
    }
}
