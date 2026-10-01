//  CoachingModels.swift
//  CoachingEngine — pure-logic module for the MacroFactor clone (issue #6).
//
//  This module is Foundation-only: no SwiftUI, no UIKit, no SwiftData.
//  It defines its OWN value types for every input so that the data layer
//  (issue #3) and analytics (issue #8) can map their models onto these types
//  without model-shape coupling. All energy values are kilocalories (kcal)
//  and all mass values are kilograms (kg) unless a function says otherwise.
//
//  Deliberate design stance (matches the reference app's documented policy):
//  step counts feed the expenditure modifier, but smartwatch / activity-tracker
//  calorie estimates are NEVER imported — they are judged unreliable and would
//  corrupt the energy-balance back-calculation.

import Foundation

// MARK: - Daily input records

/// One day of logged food intake. All macros are grams; calories are kcal.
/// A day with `isComplete == false` is partially logged and is down-weighted
/// by the expenditure estimator.
public struct IntakeDay: Equatable, Sendable {
    public var date: Date
    public var calories: Double
    public var proteinGrams: Double
    public var fatGrams: Double
    public var carbsGrams: Double
    public var isComplete: Bool

    public init(
        date: Date,
        calories: Double,
        proteinGrams: Double,
        fatGrams: Double,
        carbsGrams: Double,
        isComplete: Bool = true
    ) {
        self.date = date
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.carbsGrams = carbsGrams
        self.isComplete = isComplete
    }
}

/// One body-weight measurement, stored in kilograms.
public struct WeightSample: Equatable, Sendable {
    public var date: Date
    public var weightKg: Double

    public init(date: Date, weightKg: Double) {
        self.date = date
        self.weightKg = weightKg
    }

    public init(date: Date, pounds: Double) {
        self.date = date
        self.weightKg = pounds / WeightUnit.poundsPerKilogram
    }

    public var weightPounds: Double { weightKg * WeightUnit.poundsPerKilogram }
}

/// One day of step counts, e.g. synced from HealthKit step data.
/// Steps feed the expenditure modifier; see ``ExpenditureEstimator``.
public struct StepDay: Equatable, Sendable {
    public var date: Date
    public var steps: Double

    public init(date: Date, steps: Double) {
        self.date = date
        self.steps = steps
    }
}

// MARK: - Program configuration

/// The user's weight goal direction.
public enum GoalType: String, Equatable, Sendable, CaseIterable {
    case cut
    case maintain
    case bulk
}

/// How much autonomy the coaching engine has over target adjustments.
public enum ProgramStyle: String, Equatable, Sendable, CaseIterable {
    /// The engine applies weekly target adjustments automatically.
    case coached
    /// The engine proposes adjustments; the user reviews and accepts them.
    case collaborative
    /// The engine only reports observations; the user sets targets manually.
    case manual
}

/// How a calorie target is split into protein / fat / carbs.
public enum DietPlan: String, Equatable, Sendable, CaseIterable {
    case balanced
    case lowCarb
    case keto
    case carbFocused
}

/// Display unit for weight; storage is always kilograms.
public enum WeightUnit: String, Equatable, Sendable {
    case kilograms
    case pounds

    public static let poundsPerKilogram: Double = 2.204_622_621_8

    public func fromKilograms(_ kg: Double) -> Double {
        switch self {
        case .kilograms: return kg
        case .pounds: return kg * Self.poundsPerKilogram
        }
    }

    public func toKilograms(_ value: Double) -> Double {
        switch self {
        case .kilograms: return value
        case .pounds: return value / Self.poundsPerKilogram
        }
    }
}

/// The full coaching configuration for a user. Immutable value type:
/// any change (new check-in, new goal) produces a new value.
public struct CoachingProgram: Equatable, Sendable {
    /// Goal direction: cut / maintain / bulk.
    public var goalType: GoalType
    /// How much autonomy the engine has.
    public var programStyle: ProgramStyle
    /// Macro split strategy.
    public var dietPlan: DietPlan
    /// Desired rate of weight change in kg/week. Positive for bulk,
    /// negative for cut, ~0 for maintenance. The engine clamps this to
    /// safe bounds (see ``CoachingProgram/clampedRateOfChangeKgPerWeek``).
    public var rateOfChangeKgPerWeek: Double
    /// Protein target per kg of body weight (g/kg/day).
    public var proteinGramsPerKg: Double
    /// Weekdays (1 = Sunday … 7 = Saturday, `Calendar` convention) treated
    /// as fasting days with reduced targets.
    public var fastingWeekdays: Set<Int>
    /// Fraction of the normal calorie target applied on fasting days.
    public var fastingDayCalorieFraction: Double
    /// Optional per-weekday macro overrides; overrides win over the
    /// diet-plan computation. Keyed by weekday (1 = Sunday … 7 = Saturday).
    public var dayOverrides: [Int: MacroTargets]
    /// Display unit for weight in copy.
    public var weightUnit: WeightUnit

    public init(
        goalType: GoalType,
        programStyle: ProgramStyle = .coached,
        dietPlan: DietPlan = .balanced,
        rateOfChangeKgPerWeek: Double = 0,
        proteinGramsPerKg: Double? = nil,
        fastingWeekdays: Set<Int> = [],
        fastingDayCalorieFraction: Double = 0.25,
        dayOverrides: [Int: MacroTargets] = [:],
        weightUnit: WeightUnit = .kilograms
    ) {
        self.goalType = goalType
        self.programStyle = programStyle
        self.dietPlan = dietPlan
        self.rateOfChangeKgPerWeek = rateOfChangeKgPerWeek
        self.proteinGramsPerKg = proteinGramsPerKg ?? goalType.defaultProteinGramsPerKg
        self.fastingWeekdays = fastingWeekdays
        self.fastingDayCalorieFraction = fastingDayCalorieFraction
        self.dayOverrides = dayOverrides
        self.weightUnit = weightUnit
    }

    /// Safe bounds for the weekly rate of change (kg/week), by goal type.
    /// Rates beyond these are clamped; the UI layer should surface the clamp.
    public var clampedRateOfChangeKgPerWeek: Double {
        switch goalType {
        case .cut: return min(0, max(-1.0, rateOfChangeKgPerWeek))
        case .bulk: return max(0, min(0.5, rateOfChangeKgPerWeek))
        case .maintain: return 0
        }
    }

    /// Signed weekly energy delta (kcal/day) implied by the goal rate,
    /// using 7700 kcal per kg of body-weight change.
    public var goalEnergyDeltaKcalPerDay: Double {
        clampedRateOfChangeKgPerWeek * EnergyConstants.kcalPerKgBodyWeight / 7.0
    }
}

extension GoalType {
    /// Sensible default protein targets (g/kg/day) by goal.
    public var defaultProteinGramsPerKg: Double {
        switch self {
        case .cut: return 2.2
        case .maintain: return 1.8
        case .bulk: return 2.0
        }
    }
}

// MARK: - Targets

/// A calorie target plus its macro split. All macros are grams.
public struct MacroTargets: Equatable, Sendable {
    public var calories: Double
    public var proteinGrams: Double
    public var fatGrams: Double
    public var carbsGrams: Double

    public init(calories: Double, proteinGrams: Double, fatGrams: Double, carbsGrams: Double) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.carbsGrams = carbsGrams
    }

    /// Calories implied by the macro split (4/4/9 kcal per gram).
    public var macroImpliedCalories: Double {
        proteinGrams * EnergyConstants.kcalPerGramProtein
            + carbsGrams * EnergyConstants.kcalPerGramCarb
            + fatGrams * EnergyConstants.kcalPerGramFat
    }
}

// MARK: - Shared constants

/// First-principles energy constants used across the module.
public enum EnergyConstants {
    /// Approximate energy stored per kilogram of body-weight change (kcal/kg).
    public static let kcalPerKgBodyWeight: Double = 7_700
    public static let kcalPerGramProtein: Double = 4
    public static let kcalPerGramCarb: Double = 4
    public static let kcalPerGramFat: Double = 9
    /// Upper bound for net carbs on the keto diet plan (grams/day).
    public static let ketoMaxCarbsGrams: Double = 30
}

// MARK: - Calendar helpers (hybrid: UTC storage, device-local days)

extension CoachingEngine {
    /// A fixed Gregorian UTC calendar for absolute-time arithmetic where a
    /// stable 24-hour rhythm matters (durations, export). Never used to
    /// bucket records into days — see ``deviceCalendar``.
    public static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// The device calendar, following the user across time-zone changes.
    /// All day bucketing (trend windows, intake days, check-in weekdays)
    /// uses this, so a "day" is the user's lived day: weigh-ins, meals, and
    /// "today" line up with local midnight. Timestamps themselves remain
    /// absolute (`Date` is timezone-free), so travel only moves day
    /// boundaries — never the underlying samples.
    public static var deviceCalendar: Calendar {
        .autoupdatingCurrent
    }

    /// Start of the device-calendar day containing `date`.
    public static func startOfDay(_ date: Date) -> Date {
        deviceCalendar.startOfDay(for: date)
    }

    /// Weekday number 1…7 (1 = Sunday) for a date, in the device calendar.
    public static func weekday(of date: Date) -> Int {
        deviceCalendar.component(.weekday, from: date)
    }
}
