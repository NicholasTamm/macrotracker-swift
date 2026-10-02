//  DataLayerTests.swift
//  XCTest coverage for DataLayer's pure logic (no SwiftData container needed).
//
//  Run through the MacroFactorClone iOS simulator test scheme.

import XCTest
import SwiftData
@testable import DataLayer

final class DataLayerTests: XCTestCase {

    // MARK: - Nutrient catalog

    func testNutrientKeyUnits() {
        XCTAssertEqual(NutrientKey.calories.unit, "kcal")
        XCTAssertEqual(NutrientKey.protein.unit, "g")
        XCTAssertEqual(NutrientKey.sodium.unit, "mg")
        XCTAssertEqual(NutrientKey.vitaminD.unit, "mcg")
        XCTAssertEqual(NutrientKey.cholesterol.unit, "mg")
    }

    func testHeadlineMacros() {
        let headlines = NutrientKey.allCases.filter(\.isHeadlineMacro)
        XCTAssertEqual(Set(headlines), [.calories, .protein, .fat, .carbs])
    }

    func testRawValuesAreValidPropertyNames() {
        // Raw values double as stored-property base names.
        for key in NutrientKey.allCases {
            XCTAssertFalse(key.rawValue.isEmpty)
            XCTAssertTrue(
                key.rawValue.allSatisfy { $0.isLetter || $0.isNumber },
                "\(key.rawValue) is not a valid identifier fragment"
            )
        }
    }

    // MARK: - FoodItem nutrient scaling

    func testScaledNutrients() throws {
        let food = FoodItem(source: .custom, name: "Test Food")
        food.setPer100g(.calories, 200)
        food.setPer100g(.protein, 20)
        let scaled = food.scaledNutrients(grams: 150)
        XCTAssertEqual(try XCTUnwrap(scaled[.calories]), 300, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(scaled[.protein]), 30, accuracy: 0.001)
        XCTAssertEqual(food.per100g(.calories), 200, accuracy: 0.001)
    }

    // MARK: - LogEntry snapshot

    func testLogEntrySnapshotRoundTrip() {
        let day = Date()
        let entry = LogEntry(
            dayStart: day,
            foodName: "Test",
            grams: 100,
            nutrients: [.calories: 250, .protein: 30, .fat: 10, .carbs: 20]
        )
        XCTAssertEqual(entry.snapshot(.calories), 250, accuracy: 0.001)
        XCTAssertEqual(entry.snapshot(.protein), 30, accuracy: 0.001)
        XCTAssertEqual(entry.snapshot(.vitaminC), 0, accuracy: 0.001)

        entry.applySnapshot([.calories: 100])
        XCTAssertEqual(entry.snapshot(.calories), 100, accuracy: 0.001)
        XCTAssertEqual(entry.snapshot(.protein), 0, accuracy: 0.001)
    }

    func testDayTotalsSumming() {
        let day = Date()
        let a = LogEntry(dayStart: day, foodName: "A", grams: 100,
                          nutrients: [.calories: 200, .protein: 20])
        let b = LogEntry(dayStart: day, foodName: "B", grams: 50,
                          nutrients: [.calories: 100, .fat: 5])
        let totals = MFDayTotals.summing([a, b])
        XCTAssertEqual(totals.entryCount, 2)
        XCTAssertEqual(totals.calories, 300, accuracy: 0.001)
        XCTAssertEqual(totals.protein, 20, accuracy: 0.001)
        XCTAssertEqual(totals.fat, 5, accuracy: 0.001)

        let combined = totals + MFDayTotals(entryCount: 1, totals: [.calories: 50])
        XCTAssertEqual(combined.entryCount, 3)
        XCTAssertEqual(combined.calories, 350, accuracy: 0.001)
    }

    // MARK: - Program settings

    func testFastingWeekdayBitmaskRoundTrip() {
        let settings = ProgramSettings()
        settings.fastingWeekdays = [1, 7] // Sunday + Saturday
        XCTAssertTrue(settings.isFastingDay(weekday: 1))
        XCTAssertTrue(settings.isFastingDay(weekday: 7))
        XCTAssertFalse(settings.isFastingDay(weekday: 3))
        XCTAssertEqual(settings.fastingWeekdays, [1, 7])

        settings.fastingWeekdays = []
        XCTAssertEqual(settings.fastingWeekdayMask, 0)
    }

    func testProgramSettingsDefaultsMirrorEngine() {
        let settings = ProgramSettings()
        XCTAssertEqual(settings.goalType, .maintain)
        XCTAssertEqual(settings.programStyle, .coached)
        XCTAssertEqual(settings.dietPlan, .balanced)
    }

    @MainActor
    func testInMemorySchemaPreservesRelationshipsAndLocalCache() throws {
        let container = try MFModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let settings = ProgramSettings()
        let target = NutrientTarget(nutrientKey: .fiber, targetValue: 30)
        settings.nutrientTargets.append(target)
        let habit = Habit(name: "Test")
        let completion = HabitCompletion(dayStart: Date())
        habit.completions.append(completion)
        let cache = OpenFoodFactsCacheEntry(queryKey: "test", rawJSON: Data())

        context.insert(settings)
        context.insert(habit)
        context.insert(cache)
        try context.save()

        XCTAssertEqual(target.settings?.id, settings.id)
        XCTAssertEqual(completion.habit?.id, habit.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<NutrientTarget>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HabitCompletion>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<OpenFoodFactsCacheEntry>()).count, 1)

        context.delete(settings)
        context.delete(habit)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<NutrientTarget>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HabitCompletion>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<OpenFoodFactsCacheEntry>()).count, 1)
    }

    // MARK: - Open Food Facts normalization

    func testParseServingGrams() {
        XCTAssertEqual(OpenFoodFactsClient.parseServingGrams("30 g"), 30, accuracy: 0.001)
        XCTAssertEqual(OpenFoodFactsClient.parseServingGrams("1 bar (45g)"), 45, accuracy: 0.001)
        XCTAssertEqual(OpenFoodFactsClient.parseServingGrams("250ml"), 250, accuracy: 0.001)
        XCTAssertEqual(OpenFoodFactsClient.parseServingGrams(""), 100, accuracy: 0.001)
        XCTAssertEqual(OpenFoodFactsClient.parseServingGrams("a pinch"), 100, accuracy: 0.001)
    }

    func testOFFNutrimentNormalization() throws {
        let json = """
        {
            "code": "123",
            "product_name": "Test Bar",
            "brands": "Test Brand",
            "serving_size": "40 g",
            "nutriments": {
                "energy-kcal_100g": 400,
                "proteins_100g": 20,
                "fat_100g": 10,
                "carbohydrates_100g": 50,
                "sodium_100g": 0.5,
                "cholesterol_100g": 0.05
            }
        }
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(OFFProductPayload.self, from: json)
        let product = OpenFoodFactsClient.normalize(payload)
        XCTAssertEqual(product.name, "Test Bar")
        XCTAssertEqual(product.servingSizeGrams, 40, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(product.nutrientsPer100g[.calories]), 400, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(product.nutrientsPer100g[.protein]), 20, accuracy: 0.001)
        // Unit conversions: OFF grams → milligrams.
        XCTAssertEqual(try XCTUnwrap(product.nutrientsPer100g[.sodium]), 500, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(product.nutrientsPer100g[.cholesterol]), 50, accuracy: 0.001)
    }

    func testLossyDoubleDecoding() throws {
        let json = #"{"a": 12.5, "b": "3.25", "c": "n/a"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: LossyDouble].self, from: json)
        XCTAssertEqual(try XCTUnwrap(decoded["a"]?.value), 12.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(decoded["b"]?.value), 3.25, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(decoded["c"]?.value), 0, accuracy: 0.001)
    }

    // MARK: - Cache keys

    func testCacheTTL() {
        XCTAssertEqual(OpenFoodFactsCacheEntry.timeToLive, 30 * 24 * 3600, accuracy: 0.001)
        let fresh = OpenFoodFactsCacheEntry(queryKey: "k", rawJSON: Data())
        XCTAssertFalse(fresh.isExpired)
        let old = OpenFoodFactsCacheEntry(
            queryKey: "k", rawJSON: Data(),
            fetchedAt: Date(timeIntervalSinceNow: -31 * 24 * 3600)
        )
        XCTAssertTrue(old.isExpired)
    }
}
