//  CoachingMappings.swift
//  DataLayer → CoachingEngine mapping.
//
//  The engine defines its own input value types (see CoachingEngine's
//  README); these extensions map DataLayer models onto them so the engine
//  consumes plain values with zero coupling to SwiftData.
//
//  Consumer cheat sheet:
//    IntakeDay       ← LogRepository.intakeDays(from:to:)
//    WeightSample    ← WeightRepository.samples(from:to:)
//    StepDay         ← StepRepository.stepDays(from:to:)
//    CoachingProgram ← ProgramRepository.coachingProgram()
//  then:
//    WeightTrend.summarize(samples:endDate:windowDays:)
//    ExpenditureEstimator.estimate(intake:weights:steps:)
//    MacroPlanner.targetsForDay(_:baseCalories:bodyWeightKg:program:)
//    WeeklyCheckIn.run(program:intake:weights:steps:currentCalorieTarget:bodyWeightKg:)

import Foundation
import CoachingEngine

// MARK: - Single-model mappings

extension WeightEntry {
    /// Maps onto the engine's `WeightSample` (kilograms, as stored).
    public var coachingSample: WeightSample {
        WeightSample(date: timestamp, weightKg: weightKg)
    }
}

extension StepEntry {
    /// Maps onto the engine's `StepDay`.
    public var coachingStepDay: StepDay {
        StepDay(date: dayStart, steps: steps)
    }
}

extension MFDayTotals {
    /// Maps a day's totals onto the engine's `IntakeDay`.
    public func coachingIntakeDay(date: Date, isComplete: Bool) -> IntakeDay {
        IntakeDay(
            date: date,
            calories: calories,
            proteinGrams: protein,
            fatGrams: fat,
            carbsGrams: carbs,
            isComplete: isComplete
        )
    }
}

extension ProgramSettings {
    /// Maps stored settings onto the engine's immutable `CoachingProgram`.
    public func coachingProgramValue(dayOverrides: [MacroDayOverride] = []) -> CoachingProgram {
        var overrides: [Int: MacroTargets] = [:]
        for o in dayOverrides {
            overrides[o.weekday] = o.macroTargets
        }
        return CoachingProgram(
            goalType: goalType,
            programStyle: programStyle,
            dietPlan: dietPlan,
            rateOfChangeKgPerWeek: rateOfChangeKgPerWeek,
            proteinGramsPerKg: proteinGramsPerKg,
            fastingWeekdays: fastingWeekdays,
            fastingDayCalorieFraction: fastingDayCalorieFraction,
            dayOverrides: overrides,
            weightUnit: weightUnit
        )
    }
}
