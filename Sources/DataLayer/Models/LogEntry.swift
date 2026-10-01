//  LogEntry.swift
//  DataLayer — food log entries and per-day records.
//
//  The timeline log is NOT locked to fixed meals: `mealSlot` is a grouping
//  hint and entries sort by `timestamp`. Each entry snapshots its nutrients
//  at log time so later food edits never rewrite history.

import Foundation
import SwiftData

/// Suggested meal grouping for the timeline. Free-form: entries are ordered
/// by timestamp, this only groups them under headers.
public enum MealSlot: String, Codable, Sendable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack
    case other

    public var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snacks"
        case .other: return "Other"
        }
    }
}

/// How a log entry was created (drives icons/attribution in the timeline).
public enum EntrySource: String, Codable, Sendable, CaseIterable {
    case manualSearch
    case barcode
    case labelScan
    case photo
    case voice
    case urlImport
    case quickAdd
    case copied
}

@Model
public final class LogEntry {
    #Index<LogEntry>([\.dayStart])
    #Index<LogEntry>([\.timestamp])

    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    /// Start of the log day (device calendar) this entry belongs to.
    public var dayStart: Date
    public var mealSlotRaw: String
    public var sourceRaw: String

    /// Optional link back to the food. Nullified if the food is deleted;
    /// the snapshot below keeps the entry fully usable.
    @Relationship(deleteRule: .nullify)
    public var food: FoodItem?

    /// Denormalized food name so deleted foods still render.
    public var foodName: String
    public var grams: Double
    public var note: String?

    // MARK: Nutrient snapshot — absolute amounts for `grams` at log time

    public var calories: Double = 0
    public var protein: Double = 0
    public var fat: Double = 0
    public var carbs: Double = 0
    public var fiber: Double = 0
    public var sugar: Double = 0
    public var saturatedFat: Double = 0
    public var transFat: Double = 0
    public var cholesterol: Double = 0
    public var alcohol: Double = 0
    public var sodium: Double = 0
    public var potassium: Double = 0
    public var calcium: Double = 0
    public var iron: Double = 0
    public var magnesium: Double = 0
    public var phosphorus: Double = 0
    public var zinc: Double = 0
    public var copper: Double = 0
    public var manganese: Double = 0
    public var vitaminA: Double = 0
    public var vitaminC: Double = 0
    public var vitaminD: Double = 0
    public var vitaminE: Double = 0
    public var vitaminK: Double = 0
    public var thiamin: Double = 0
    public var riboflavin: Double = 0
    public var niacin: Double = 0
    public var vitaminB6: Double = 0
    public var folate: Double = 0
    public var vitaminB12: Double = 0
    public var selenium: Double = 0
    public var iodine: Double = 0
    public var caffeine: Double = 0

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        dayStart: Date,
        mealSlot: MealSlot = .other,
        source: EntrySource = .manualSearch,
        food: FoodItem? = nil,
        foodName: String,
        grams: Double,
        nutrients: [NutrientKey: Double] = [:],
        note: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.dayStart = dayStart
        self.mealSlotRaw = mealSlot.rawValue
        self.sourceRaw = source.rawValue
        self.food = food
        self.foodName = foodName
        self.grams = grams
        self.note = note
        applySnapshot(nutrients)
    }

    public var mealSlot: MealSlot {
        get { MealSlot(rawValue: mealSlotRaw) ?? .other }
        set { mealSlotRaw = newValue.rawValue }
    }

    public var entrySource: EntrySource {
        get { EntrySource(rawValue: sourceRaw) ?? .manualSearch }
        set { sourceRaw = newValue.rawValue }
    }

    /// Absolute snapshot value for a nutrient key.
    public func snapshot(_ key: NutrientKey) -> Double {
        switch key {
        case .calories: return calories
        case .protein: return protein
        case .fat: return fat
        case .carbs: return carbs
        case .fiber: return fiber
        case .sugar: return sugar
        case .saturatedFat: return saturatedFat
        case .transFat: return transFat
        case .cholesterol: return cholesterol
        case .alcohol: return alcohol
        case .sodium: return sodium
        case .potassium: return potassium
        case .calcium: return calcium
        case .iron: return iron
        case .magnesium: return magnesium
        case .phosphorus: return phosphorus
        case .zinc: return zinc
        case .copper: return copper
        case .manganese: return manganese
        case .vitaminA: return vitaminA
        case .vitaminC: return vitaminC
        case .vitaminD: return vitaminD
        case .vitaminE: return vitaminE
        case .vitaminK: return vitaminK
        case .thiamin: return thiamin
        case .riboflavin: return riboflavin
        case .niacin: return niacin
        case .vitaminB6: return vitaminB6
        case .folate: return folate
        case .vitaminB12: return vitaminB12
        case .selenium: return selenium
        case .iodine: return iodine
        case .caffeine: return caffeine
        }
    }

    /// Overwrites the snapshot from absolute nutrient amounts.
    public func applySnapshot(_ nutrients: [NutrientKey: Double]) {
        for key in NutrientKey.allCases {
            setSnapshot(key, nutrients[key] ?? 0)
        }
    }

    public func setSnapshot(_ key: NutrientKey, _ value: Double) {
        switch key {
        case .calories: calories = value
        case .protein: protein = value
        case .fat: fat = value
        case .carbs: carbs = value
        case .fiber: fiber = value
        case .sugar: sugar = value
        case .saturatedFat: saturatedFat = value
        case .transFat: transFat = value
        case .cholesterol: cholesterol = value
        case .alcohol: alcohol = value
        case .sodium: sodium = value
        case .potassium: potassium = value
        case .calcium: calcium = value
        case .iron: iron = value
        case .magnesium: magnesium = value
        case .phosphorus: phosphorus = value
        case .zinc: zinc = value
        case .copper: copper = value
        case .manganese: manganese = value
        case .vitaminA: vitaminA = value
        case .vitaminC: vitaminC = value
        case .vitaminD: vitaminD = value
        case .vitaminE: vitaminE = value
        case .vitaminK: vitaminK = value
        case .thiamin: thiamin = value
        case .riboflavin: riboflavin = value
        case .niacin: niacin = value
        case .vitaminB6: vitaminB6 = value
        case .folate: folate = value
        case .vitaminB12: vitaminB12 = value
        case .selenium: selenium = value
        case .iodine: iodine = value
        case .caffeine: caffeine = value
        }
    }
}

// MARK: - LogDay — per-day log metadata

/// One log day's metadata. Entries are queried by `dayStart`; this record
/// carries the flags that aren't derivable from entries (day completeness
/// for the expenditure estimator, user notes).
@Model
public final class LogDay {
    @Attribute(.unique) public var dayStart: Date
    /// User-marked "done logging" — feeds `IntakeDay.isComplete`.
    public var isMarkedComplete: Bool
    public var note: String?
    public var updatedAt: Date

    public init(dayStart: Date, isMarkedComplete: Bool = false, note: String? = nil) {
        self.dayStart = dayStart
        self.isMarkedComplete = isMarkedComplete
        self.note = note
        self.updatedAt = Date()
    }
}

// MARK: - MFDayTotals — value type for day aggregation

/// Summed nutrients for one day. Produced by `LogRepository.dayTotals(_:)`;
/// consumed by the Food Log header, widgets (#10), and analytics (#8).
public struct MFDayTotals: Equatable, Sendable {
    public var entryCount: Int
    public var totals: [NutrientKey: Double]

    public init(entryCount: Int = 0, totals: [NutrientKey: Double] = [:]) {
        self.entryCount = entryCount
        self.totals = totals
    }

    public func total(_ key: NutrientKey) -> Double { totals[key] ?? 0 }

    public var calories: Double { total(.calories) }
    public var protein: Double { total(.protein) }
    public var fat: Double { total(.fat) }
    public var carbs: Double { total(.carbs) }

    public static func + (lhs: MFDayTotals, rhs: MFDayTotals) -> MFDayTotals {
        var totals = lhs.totals
        for (key, value) in rhs.totals { totals[key, default: 0] += value }
        return MFDayTotals(entryCount: lhs.entryCount + rhs.entryCount, totals: totals)
    }

    public static func summing(_ entries: [LogEntry]) -> MFDayTotals {
        var totals: [NutrientKey: Double] = [:]
        for entry in entries {
            for key in NutrientKey.allCases {
                totals[key, default: 0] += entry.snapshot(key)
            }
        }
        return MFDayTotals(entryCount: entries.count, totals: totals)
    }
}
