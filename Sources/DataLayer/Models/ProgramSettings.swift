//  ProgramSettings.swift
//  DataLayer — the coaching program configuration (singleton), per-nutrient
//  daily targets, per-weekday macro overrides, and related settings.
//
//  Enums from CoachingEngine are stored as raw strings (CloudKit-safe);
//  typed accessors map them back. Fasting weekdays are an Int bitmask
//  (bit N = weekday N, Calendar convention 1 = Sunday … 7 = Saturday).

import Foundation
import SwiftData
import CoachingEngine

@Model
public final class ProgramSettings {
    /// Singleton row id.
    @Attribute(.unique) public var id: String

    // MARK: Coaching program (mirrors CoachingEngine.CoachingProgram)

    public var goalTypeRaw: String
    public var programStyleRaw: String
    public var dietPlanRaw: String
    public var rateOfChangeKgPerWeek: Double
    public var proteinGramsPerKg: Double
    /// Bitmask: bit N set → weekday N (1 = Sunday … 7 = Saturday) is a fasting day.
    public var fastingWeekdayMask: Int
    public var fastingDayCalorieFraction: Double
    public var weightUnitRaw: String

    // MARK: Current targets (set by weekly check-in or edited manually)

    public var currentCalories: Double
    public var currentProteinGrams: Double
    public var currentFatGrams: Double
    public var currentCarbsGrams: Double

    // MARK: Latest expenditure estimate

    public var expenditureEstimateKcal: Double?
    public var expenditureUpdatedAt: Date?

    // MARK: App preferences owned by the data layer

    public var onboardingCompleted: Bool
    /// Start of the coaching week for check-in scheduling (weekday 1…7).
    public var checkInWeekday: Int
    public var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \NutrientTarget.settings)
    public var nutrientTargets: [NutrientTarget] = []

    @Relationship(deleteRule: .cascade, inverse: \MacroDayOverride.settings)
    public var dayOverrides: [MacroDayOverride] = []

    public init(id: String = "singleton") {
        self.id = id
        let defaults = CoachingProgram(goalType: .maintain)
        self.goalTypeRaw = defaults.goalType.rawValue
        self.programStyleRaw = defaults.programStyle.rawValue
        self.dietPlanRaw = defaults.dietPlan.rawValue
        self.rateOfChangeKgPerWeek = 0
        self.proteinGramsPerKg = defaults.proteinGramsPerKg
        self.fastingWeekdayMask = 0
        self.fastingDayCalorieFraction = defaults.fastingDayCalorieFraction
        self.weightUnitRaw = WeightUnit.kilograms.rawValue
        self.currentCalories = 0
        self.currentProteinGrams = 0
        self.currentFatGrams = 0
        self.currentCarbsGrams = 0
        self.onboardingCompleted = false
        self.checkInWeekday = 1 // Sunday
        self.updatedAt = Date()
    }

    // MARK: Typed accessors

    public var goalType: GoalType {
        get { GoalType(rawValue: goalTypeRaw) ?? .maintain }
        set { goalTypeRaw = newValue.rawValue }
    }

    public var programStyle: ProgramStyle {
        get { ProgramStyle(rawValue: programStyleRaw) ?? .coached }
        set { programStyleRaw = newValue.rawValue }
    }

    public var dietPlan: DietPlan {
        get { DietPlan(rawValue: dietPlanRaw) ?? .balanced }
        set { dietPlanRaw = newValue.rawValue }
    }

    public var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw) ?? .kilograms }
        set { weightUnitRaw = newValue.rawValue }
    }

    /// Fasting weekdays as a set (1 = Sunday … 7 = Saturday).
    public var fastingWeekdays: Set<Int> {
        get {
            Set((1...7).filter { fastingWeekdayMask & (1 << $0) != 0 })
        }
        set {
            fastingWeekdayMask = newValue.reduce(0) { $0 | (1 << $1) }
        }
    }

    public func isFastingDay(weekday: Int) -> Bool {
        (1...7).contains(weekday) && (fastingWeekdayMask & (1 << weekday) != 0)
    }
}

// MARK: - NutrientTarget — daily goal for one nutrient (custom micros)

@Model
public final class NutrientTarget {
    @Attribute(.unique) public var id: UUID
    public var nutrientKeyRaw: String
    public var targetValue: Double
    public var unit: String
    /// True when the user customized it (vs. the app default).
    public var isCustom: Bool

    @Relationship(deleteRule: .nullify)
    public var settings: ProgramSettings?

    public init(
        id: UUID = UUID(),
        nutrientKey: NutrientKey,
        targetValue: Double,
        isCustom: Bool = false
    ) {
        self.id = id
        self.nutrientKeyRaw = nutrientKey.rawValue
        self.targetValue = targetValue
        self.unit = nutrientKey.unit
        self.isCustom = isCustom
    }

    public var nutrientKey: NutrientKey? { NutrientKey(rawValue: nutrientKeyRaw) }
}

// MARK: - MacroDayOverride — per-weekday macro targets

@Model
public final class MacroDayOverride {
    @Attribute(.unique) public var id: UUID
    /// Weekday 1 = Sunday … 7 = Saturday (Calendar convention).
    public var weekday: Int
    public var calories: Double
    public var proteinGrams: Double
    public var fatGrams: Double
    public var carbsGrams: Double

    @Relationship(deleteRule: .nullify)
    public var settings: ProgramSettings?

    public init(
        id: UUID = UUID(),
        weekday: Int,
        calories: Double,
        proteinGrams: Double,
        fatGrams: Double,
        carbsGrams: Double
    ) {
        self.id = id
        self.weekday = weekday
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.carbsGrams = carbsGrams
    }

    public var macroTargets: MacroTargets {
        MacroTargets(
            calories: calories,
            proteinGrams: proteinGrams,
            fatGrams: fatGrams,
            carbsGrams: carbsGrams
        )
    }
}
