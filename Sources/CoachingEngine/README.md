# CoachingEngine (issue #6)

Pure-logic module: adaptive expenditure estimation, weight-trend smoothing,
macro planning, and the weekly check-in. **Foundation only** — no SwiftUI,
UIKit, or SwiftData, so the data layer (#3) and analytics (#8) can import it
freely.

## Integration contract

The module defines its **own** input value types. Map your models onto these:

| Your data | This module's type |
|---|---|
| One day of logged food | `IntakeDay(date:calories:proteinGrams:fatGrams:carbsGrams:isComplete:)` |
| A weigh-in | `WeightSample(date:weightKg:)` (or `init(date:pounds:)`) |
| A day of step counts | `StepDay(date:steps:)` |
| Program configuration | `CoachingProgram(goalType:programStyle:dietPlan:rateOfChangeKgPerWeek:…)` |

Then call the pure functions:

```swift
// Smoothed weight trend (EWMA, missing days carried forward)
let summary = WeightTrend.summarize(samples: weights, endDate: Date(), windowDays: 21)

// Expenditure via energy-balance back-calculation + step modifier
let estimate = ExpenditureEstimator.estimate(intake: intake, weights: weights, steps: steps)

// Macro targets for a calorie budget (diet plan, fasting days, per-day overrides)
let macros = MacroPlanner.targetsForDay(date, baseCalories: 2200, bodyWeightKg: 79, program: program)

// Weekly check-in: adjust targets + adherence-neutral explanation
let report = WeeklyCheckIn.run(program: program, intake: intake, weights: weights,
                               steps: steps, currentCalorieTarget: 2200, bodyWeightKg: 79)
// Collaborative style: user accepts → applyRecommendation(_:bodyWeightKg:)
// Manual style: report is advisory; user edits targets directly.
```

## Key behaviors

- **Energy balance:** `expenditure = avgIntake − (trendWeightChangeKg × 7700) / days`.
- **Step modifier:** recent-third vs baseline step mean; engages past ±10% relative
  change, shifts estimate up to ±5%. **Smartwatch calorie estimates are never
  imported** — deliberate, documented in `CoachingModels.swift`.
- **Weekly adjustment** is bounded to `min(250 kcal, 10%)`, shrunk further by low
  confidence; Coached auto-applies, Collaborative proposes, Manual advises.
- **Goal rates** are clamped (cut ≤ 1.0 kg/wk loss, bulk ≤ 0.5 kg/wk gain).
- **All coaching copy is original and adherence-neutral** (no shaming language;
  enforced by `testCopyIsAdherenceNeutral`).
- No paywall, no gating anywhere in this module.

## Tests

`app/Tests/CoachingEngineTests/CoachingEngineTests.swift` — 25 tests covering
known energy-balance scenarios, trend smoothing, step modifier bounds, all three
program styles, diet plans, fasting days, and copy neutrality. They assume the
SPM target is named `CoachingEngine` (wiring belongs to issue #2's scaffold).
No Swift toolchain exists on this Linux machine, so they await the first Xcode
build for execution.
