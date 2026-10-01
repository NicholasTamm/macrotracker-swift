//  MacroPlanner.swift
//  CoachingEngine — turning a calorie target into protein/fat/carb targets.

import Foundation

/// Computes macro targets from a calorie target, diet plan, and program.
public enum MacroPlanner {

    /// Maximum single-week calorie adjustment applied by the check-in (kcal).
    public static let maxWeeklyCalorieAdjustment: Double = 250
    /// Maximum proportional single-week calorie adjustment.
    public static let maxWeeklyCalorieAdjustmentFraction: Double = 0.10

    /// Split a calorie target into macros for the given program.
    ///
    /// Protein is set from `program.proteinGramsPerKg × bodyWeightKg` and
    /// never drops below that on any diet plan. Fat and carbs fill the
    /// remaining calories according to the diet plan:
    /// - balanced: ~30% of remaining calories from fat
    /// - lowCarb: ~55% of remaining calories from fat
    /// - carbFocused: ~15% of remaining calories from fat
    /// - keto: carbs capped at ``EnergyConstants/ketoMaxCarbsGrams``, the rest fat
    ///
    /// A minimum of 0.6 g fat per kg is enforced on every plan.
    public static func targets(
        calories: Double,
        bodyWeightKg: Double,
        program: CoachingProgram
    ) -> MacroTargets {
        let proteinGrams = max(0, program.proteinGramsPerKg * bodyWeightKg)
        let proteinKcal = proteinGrams * EnergyConstants.kcalPerGramProtein
        let remainingKcal = max(0, calories - proteinKcal)

        let fatKcal: Double
        let carbsKcal: Double
        switch program.dietPlan {
        case .balanced:
            fatKcal = remainingKcal * 0.30
            carbsKcal = remainingKcal - fatKcal
        case .lowCarb:
            fatKcal = remainingKcal * 0.55
            carbsKcal = remainingKcal - fatKcal
        case .carbFocused:
            fatKcal = remainingKcal * 0.15
            carbsKcal = remainingKcal - fatKcal
        case .keto:
            let ketoCarbKcal = min(
                remainingKcal,
                EnergyConstants.ketoMaxCarbsGrams * EnergyConstants.kcalPerGramCarb
            )
            carbsKcal = ketoCarbKcal
            fatKcal = remainingKcal - ketoCarbKcal
        }

        var fatGrams = fatKcal / EnergyConstants.kcalPerGramFat
        // Fat floor: 0.6 g/kg, taken from carbs when needed.
        let fatFloor = 0.6 * bodyWeightKg
        var carbsGrams = carbsKcal / EnergyConstants.kcalPerGramCarb
        if fatGrams < fatFloor {
            let deficitKcal = (fatFloor - fatGrams) * EnergyConstants.kcalPerGramFat
            fatGrams = fatFloor
            carbsGrams = max(0, carbsGrams - deficitKcal / EnergyConstants.kcalPerGramCarb)
        }

        return MacroTargets(
            calories: calories,
            proteinGrams: proteinGrams,
            fatGrams: fatGrams,
            carbsGrams: carbsGrams
        )
    }

    /// Targets for a specific day: applies per-day overrides and fasting-day
    /// reduction. `date` is interpreted in UTC.
    public static func targetsForDay(
        _ date: Date,
        baseCalories: Double,
        bodyWeightKg: Double,
        program: CoachingProgram
    ) -> MacroTargets {
        let weekday = CoachingEngine.weekday(of: date)
        if let override = program.dayOverrides[weekday] {
            return override
        }
        if program.fastingWeekdays.contains(weekday) {
            let fastingCalories = baseCalories * program.fastingDayCalorieFraction
            // Keep protein proportional to the reduced calories but never
            // below 1.2 g/kg so fasting days stay protein-sparing.
            var fasting = targets(calories: fastingCalories, bodyWeightKg: bodyWeightKg, program: program)
            let proteinFloor = 1.2 * bodyWeightKg
            if fasting.proteinGrams < proteinFloor {
                let extraProteinKcal = (proteinFloor - fasting.proteinGrams)
                    * EnergyConstants.kcalPerGramProtein
                fasting.proteinGrams = proteinFloor
                fasting.carbsGrams = max(
                    0,
                    fasting.carbsGrams - extraProteinKcal / EnergyConstants.kcalPerGramCarb
                )
            }
            return fasting
        }
        return targets(calories: baseCalories, bodyWeightKg: bodyWeightKg, program: program)
    }

    /// Clamp a proposed calorie target change to the weekly adjustment bounds.
    /// Low estimator confidence shrinks the allowed step further.
    public static func boundedAdjustment(
        from current: Double,
        to proposed: Double,
        confidence: Double
    ) -> Double {
        let maxStep = min(
            maxWeeklyCalorieAdjustment,
            current * maxWeeklyCalorieAdjustmentFraction
        ) * (0.5 + 0.5 * confidence)
        let delta = proposed - current
        return current + min(maxStep, max(-maxStep, delta))
    }
}
