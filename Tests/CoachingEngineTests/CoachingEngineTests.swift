//  CoachingEngineTests.swift
//  XCTest coverage for the coaching engine (issue #6).
//
//  NOTE: Package.swift (issue #2's scaffold) declares the "CoachingEngine"
//  SPM target these tests link against. They are written to review
//  standard; no Swift toolchain is available on this machine.

import XCTest
@testable import CoachingEngine

final class CoachingEngineTests: XCTestCase {

    // MARK: - Test helpers

    /// Fixed absolute base instant so every test is deterministic. Timestamps
    /// are absolute; day bucketing follows the device calendar (hybrid model).
    private let base = Date(timeIntervalSince1970: 1_757_000_000) // ~2026-09-04 00:00 UTC

    private func day(_ offset: Int) -> Date {
        CoachingEngine.deviceCalendar.date(byAdding: .day, value: offset, to: CoachingEngine.startOfDay(base))!
    }

    /// `count` complete intake days ending at offset 0, each `kcal` calories.
    private func intakeDays(count: Int, kcal: Double, complete: Bool = true) -> [IntakeDay] {
        (-(count - 1)...0).map { offset in
            IntakeDay(
                date: day(offset),
                calories: kcal,
                proteinGrams: kcal * 0.25 / 4,
                fatGrams: kcal * 0.30 / 9,
                carbsGrams: kcal * 0.45 / 4,
                isComplete: complete
            )
        }
    }

    /// Weight samples falling linearly from `startKg` to `endKg` over `count` days.
    private func linearWeights(count: Int, startKg: Double, endKg: Double) -> [WeightSample] {
        (0..<count).map { i in
            let fraction = count == 1 ? 0 : Double(i) / Double(count - 1)
            return WeightSample(
                date: day(-(count - 1) + i),
                weightKg: startKg + (endKg - startKg) * fraction
            )
        }
    }

    private func cutProgram(style: ProgramStyle = .coached) -> CoachingProgram {
        CoachingProgram(
            goalType: .cut,
            programStyle: style,
            dietPlan: .balanced,
            rateOfChangeKgPerWeek: -0.5
        )
    }

    // MARK: - WeightTrend

    func testTrendIsFlatForConstantWeight() {
        let samples = (0..<21).map { WeightSample(date: day(-$0), weightKg: 80) }
        let summary = WeightTrend.summarize(samples: samples, endDate: day(0), windowDays: 21)!
        XCTAssertEqual(summary.rateKgPerWeek, 0, accuracy: 1e-9)
        XCTAssertEqual(summary.totalChangeKg, 0, accuracy: 1e-9)
    }

    func testTrendCapturesWeightLoss() {
        let samples = linearWeights(count: 21, startKg: 80, endKg: 79)
        let summary = WeightTrend.summarize(samples: samples, endDate: day(0), windowDays: 21)!
        // True rate is -1/3 kg/week; smoothing lags slightly, so expect near it.
        XCTAssertLessThan(summary.rateKgPerWeek, -0.2)
        XCTAssertGreaterThan(summary.rateKgPerWeek, -0.4)
    }

    func testTrendCarriesForwardAcrossMissingDays() {
        // Samples only on the first and last day; trend must still span the window.
        let samples = [
            WeightSample(date: day(-20), weightKg: 80),
            WeightSample(date: day(0), weightKg: 79),
        ]
        let series = WeightTrend.trendSeries(samples: samples, endDate: day(0), windowDays: 21)
        XCTAssertEqual(series.count, 21)
        // Middle days carry the trend forward without a sample.
        XCTAssertNil(series[10].sampleKg)
        XCTAssertEqual(series[10].trendKg, series[9].trendKg, accuracy: 1e-12)
    }

    func testTrendNeedsASeed() {
        // No samples at all → no trend.
        XCTAssertNil(WeightTrend.summarize(samples: [], endDate: day(0), windowDays: 21))
    }

    func testTrendAveragesDuplicateSamplesPerDay() {
        let samples = [
            WeightSample(date: day(0), weightKg: 80),
            WeightSample(date: day(0), weightKg: 82),
        ]
        let series = WeightTrend.trendSeries(samples: samples, endDate: day(0), windowDays: 1)
        // Seed = mean(80, 82) = 81; single day → trend == seed.
        XCTAssertEqual(series.first?.trendKg ?? 0, 81, accuracy: 1e-9)
    }

    // MARK: - ExpenditureEstimator: known energy-balance scenarios

    func testExpenditureBackCalculationWeightLoss() {
        // Ate 2200 kcal/day, lost ~0.5 kg over 21 days.
        // Expected: 2200 + (0.5 × 7700)/21 ≈ 2383 kcal/day (within smoothing tolerance).
        let estimate = ExpenditureEstimator.estimate(
            intake: intakeDays(count: 21, kcal: 2200),
            weights: linearWeights(count: 21, startKg: 80, endKg: 79.5),
            endDate: day(0),
            windowDays: 21
        )!
        XCTAssertEqual(estimate.kcalPerDay, 2383, accuracy: 100)
        XCTAssertEqual(estimate.confidence, 1.0, accuracy: 1e-9)
        XCTAssertEqual(estimate.averageIntakeKcalPerDay, 2200, accuracy: 1e-9)
    }

    func testExpenditureBackCalculationWeightGain() {
        // Ate 2800 kcal/day, gained ~0.5 kg over 21 days.
        // Expected: 2800 − (0.5 × 7700)/21 ≈ 2617 kcal/day.
        let estimate = ExpenditureEstimator.estimate(
            intake: intakeDays(count: 21, kcal: 2800),
            weights: linearWeights(count: 21, startKg: 80, endKg: 80.5),
            endDate: day(0),
            windowDays: 21
        )!
        XCTAssertEqual(estimate.kcalPerDay, 2617, accuracy: 100)
    }

    func testExpenditureAtMaintenance() {
        // Ate 2400 kcal/day, weight perfectly flat → expenditure ≈ intake.
        let estimate = ExpenditureEstimator.estimate(
            intake: intakeDays(count: 21, kcal: 2400),
            weights: linearWeights(count: 21, startKg: 80, endKg: 80),
            endDate: day(0),
            windowDays: 21
        )!
        XCTAssertEqual(estimate.kcalPerDay, 2400, accuracy: 50)
    }

    func testIncompleteLoggingLowersConfidence() {
        let estimate = ExpenditureEstimator.estimate(
            intake: intakeDays(count: 21, kcal: 2200, complete: false),
            weights: linearWeights(count: 21, startKg: 80, endKg: 79.5),
            endDate: day(0),
            windowDays: 21
        )!
        XCTAssertLessThan(estimate.confidence, 1.0)
        XCTAssertGreaterThan(estimate.confidence, 0)
    }

    func testEstimatorReturnsNilWithoutData() {
        XCTAssertNil(ExpenditureEstimator.estimate(intake: [], weights: [], endDate: day(0)))
        // Intake but no weights → no trend → nil.
        XCTAssertNil(ExpenditureEstimator.estimate(
            intake: intakeDays(count: 21, kcal: 2200), weights: [], endDate: day(0)
        ))
    }

    // MARK: - Step-informed modifier

    func testStepIncreaseRaisesEstimateWithinCap() {
        // Baseline 8000 steps, recent third at 12000 (+50%) → +5% capped.
        let steps: [StepDay] = (-20...0).map { offset in
            StepDay(date: day(offset), steps: offset >= -6 ? 12_000 : 8_000)
        }
        let factor = ExpenditureEstimator.stepAdjustmentFactor(
            steps: steps,
            startDay: CoachingEngine.startOfDay(day(-20)),
            endDay: CoachingEngine.startOfDay(day(0)),
            windowDays: 21
        )
        XCTAssertEqual(factor, 1.05, accuracy: 1e-9)
    }

    func testSmallStepChangeIsIgnored() {
        let steps: [StepDay] = (-20...0).map { offset in
            StepDay(date: day(offset), steps: offset >= -6 ? 8_400 : 8_000) // +5%
        }
        let factor = ExpenditureEstimator.stepAdjustmentFactor(
            steps: steps,
            startDay: CoachingEngine.startOfDay(day(-20)),
            endDay: CoachingEngine.startOfDay(day(0)),
            windowDays: 21
        )
        XCTAssertEqual(factor, 1.0, accuracy: 1e-12)
    }

    func testStepDecreaseLowersEstimate() {
        let steps: [StepDay] = (-20...0).map { offset in
            StepDay(date: day(offset), steps: offset >= -6 ? 4_000 : 8_000) // −50%
        }
        let factor = ExpenditureEstimator.stepAdjustmentFactor(
            steps: steps,
            startDay: CoachingEngine.startOfDay(day(-20)),
            endDay: CoachingEngine.startOfDay(day(0)),
            windowDays: 21
        )
        XCTAssertEqual(factor, 0.95, accuracy: 1e-9)
    }

    // MARK: - WeeklyCheckIn

    func testCoachedCheckInAdjustsDownWhenLosingTooSlowly() {
        // Cut at −0.5 kg/week goal, but only ~−0.1 kg/week observed → target drops.
        let report = WeeklyCheckIn.run(
            program: cutProgram(style: .coached),
            intake: intakeDays(count: 21, kcal: 2200),
            weights: linearWeights(count: 21, startKg: 80, endKg: 79.7),
            currentCalorieTarget: 2200,
            bodyWeightKg: 79.8,
            date: day(0)
        )
        XCTAssertLessThan(report.recommendedCalorieTarget, report.previousCalorieTarget)
        XCTAssertTrue(report.appliedAutomatically)
        XCTAssertFalse(report.explanation.isEmpty)
    }

    func testOnTrackCheckInHoldsTarget() {
        // ~−1.5 kg over 21 days ≈ −0.45 kg/week vs −0.5 goal → on track.
        let report = WeeklyCheckIn.run(
            program: cutProgram(style: .coached),
            intake: intakeDays(count: 21, kcal: 2200),
            weights: linearWeights(count: 21, startKg: 80, endKg: 78.5),
            currentCalorieTarget: 2200,
            bodyWeightKg: 79,
            date: day(0)
        )
        XCTAssertEqual(report.assessment, .onTrack)
        XCTAssertEqual(report.recommendedCalorieTarget, report.previousCalorieTarget, accuracy: 1e-9)
        XCTAssertFalse(report.appliedAutomatically)
    }

    func testCollaborativeCheckInRequiresAcceptance() {
        let report = WeeklyCheckIn.run(
            program: cutProgram(style: .collaborative),
            intake: intakeDays(count: 21, kcal: 2200),
            weights: linearWeights(count: 21, startKg: 80, endKg: 79.7),
            currentCalorieTarget: 2200,
            bodyWeightKg: 79.8,
            date: day(0)
        )
        XCTAssertLessThan(report.recommendedCalorieTarget, report.previousCalorieTarget)
        XCTAssertFalse(report.appliedAutomatically)
        // Accepting the recommendation yields macro targets at the new calories.
        let applied = WeeklyCheckIn.applyRecommendation(report, bodyWeightKg: 79.8)
        XCTAssertEqual(applied.calories, report.recommendedCalorieTarget, accuracy: 1e-9)
    }

    func testManualCheckInIsAdvisory() {
        let report = WeeklyCheckIn.run(
            program: cutProgram(style: .manual),
            intake: intakeDays(count: 21, kcal: 2200),
            weights: linearWeights(count: 21, startKg: 80, endKg: 79.7),
            currentCalorieTarget: 2200,
            bodyWeightKg: 79.8,
            date: day(0)
        )
        XCTAssertFalse(report.appliedAutomatically)
        XCTAssertTrue(report.explanation.joined(separator: " ").contains("yours to set"))
    }

    func testInsufficientDataHoldsTarget() {
        let report = WeeklyCheckIn.run(
            program: cutProgram(),
            intake: [],
            weights: [],
            currentCalorieTarget: 2200,
            bodyWeightKg: 80,
            date: day(0)
        )
        XCTAssertEqual(report.assessment, .insufficientData)
        XCTAssertEqual(report.recommendedCalorieTarget, 2200, accuracy: 1e-9)
        XCTAssertFalse(report.appliedAutomatically)
    }

    func testWeeklyAdjustmentIsBounded() {
        // Huge gap between ideal and current must not move more than the cap.
        let bounded = MacroPlanner.boundedAdjustment(from: 2000, to: 3000, confidence: 1.0)
        XCTAssertEqual(bounded, 2200, accuracy: 1e-9) // min(250, 10%) = 200
        // Low confidence shrinks the step further.
        let lowConfidence = MacroPlanner.boundedAdjustment(from: 2000, to: 3000, confidence: 0.0)
        XCTAssertEqual(lowConfidence, 2100, accuracy: 1e-9)
    }

    // MARK: - MacroPlanner: diet plans, fasting days, overrides

    func testProteinTargetScalesWithBodyWeight() {
        let program = cutProgram()
        let targets = MacroPlanner.targets(calories: 2000, bodyWeightKg: 80, program: program)
        XCTAssertEqual(targets.proteinGrams, 2.2 * 80, accuracy: 1e-9)
        // Macro calories roughly reconcile with the calorie target.
        XCTAssertEqual(targets.macroImpliedCalories, 2000, accuracy: 60)
    }

    func testKetoCapsCarbsAndPreservesProtein() {
        var program = cutProgram()
        program.dietPlan = .keto
        let targets = MacroPlanner.targets(calories: 2000, bodyWeightKg: 80, program: program)
        XCTAssertLessThanOrEqual(targets.carbsGrams, EnergyConstants.ketoMaxCarbsGrams + 1e-9)
        XCTAssertEqual(targets.proteinGrams, 2.2 * 80, accuracy: 1e-9)
    }

    func testDietPlansShiftFatCarbSplit() {
        let lowCarb = CoachingProgram(goalType: .maintain, dietPlan: .lowCarb)
        let carbFocused = CoachingProgram(goalType: .maintain, dietPlan: .carbFocused)
        let lc = MacroPlanner.targets(calories: 2400, bodyWeightKg: 80, program: lowCarb)
        let cf = MacroPlanner.targets(calories: 2400, bodyWeightKg: 80, program: carbFocused)
        XCTAssertGreaterThan(lc.fatGrams, cf.fatGrams)
        XCTAssertGreaterThan(cf.carbsGrams, lc.carbsGrams)
    }

    func testFastingDayReducesCaloriesAndSparesProtein() {
        var program = cutProgram()
        let weekday = CoachingEngine.weekday(of: day(0))
        program.fastingWeekdays = [weekday]
        let targets = MacroPlanner.targetsForDay(day(0), baseCalories: 2000, bodyWeightKg: 80, program: program)
        XCTAssertEqual(targets.calories, 500, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(targets.proteinGrams, 1.2 * 80 - 1e-9)
        // A non-fasting day is unaffected.
        let normal = MacroPlanner.targetsForDay(day(1), baseCalories: 2000, bodyWeightKg: 80, program: program)
        XCTAssertEqual(normal.calories, 2000, accuracy: 1e-9)
    }

    func testPerDayOverrideWins() {
        var program = cutProgram()
        let weekday = CoachingEngine.weekday(of: day(0))
        let override = MacroTargets(calories: 1800, proteinGrams: 150, fatGrams: 60, carbsGrams: 165)
        program.dayOverrides = [weekday: override]
        let targets = MacroPlanner.targetsForDay(day(0), baseCalories: 2200, bodyWeightKg: 80, program: program)
        XCTAssertEqual(targets, override)
    }

    // MARK: - Program configuration

    func testGoalRateClamping() {
        let cut = CoachingProgram(goalType: .cut, rateOfChangeKgPerWeek: -2.0)
        XCTAssertEqual(cut.clampedRateOfChangeKgPerWeek, -1.0, accuracy: 1e-9)
        let bulk = CoachingProgram(goalType: .bulk, rateOfChangeKgPerWeek: 1.0)
        XCTAssertEqual(bulk.clampedRateOfChangeKgPerWeek, 0.5, accuracy: 1e-9)
        let maintain = CoachingProgram(goalType: .maintain, rateOfChangeKgPerWeek: 0.3)
        XCTAssertEqual(maintain.clampedRateOfChangeKgPerWeek, 0, accuracy: 1e-9)
    }

    func testGoalEnergyDeltaSign() {
        let cut = CoachingProgram(goalType: .cut, rateOfChangeKgPerWeek: -0.5)
        XCTAssertEqual(cut.goalEnergyDeltaKcalPerDay, -550, accuracy: 1e-9)
        let bulk = CoachingProgram(goalType: .bulk, rateOfChangeKgPerWeek: 0.25)
        XCTAssertEqual(bulk.goalEnergyDeltaKcalPerDay, 275, accuracy: 1e-9)
    }

    func testWeightUnitConversion() {
        let sample = WeightSample(date: day(0), pounds: 176.37)
        XCTAssertEqual(sample.weightKg, 80, accuracy: 0.01)
        XCTAssertEqual(WeightUnit.pounds.fromKilograms(80), 176.37, accuracy: 0.01)
    }

    // MARK: - Adherence-neutral copy

    func testCopyIsAdherenceNeutral() {
        let banned = ["bad", "fail", "cheat", "guilt", "shame", "lazy", "disappoint", "punish"]
        var allCopy: [String] = [
            CoachingCopy.overTargetNote(),
            CoachingCopy.underTargetNote(),
        ]
        for assessment in [ProgressAssessment.onTrack, .slowerThanPlanned, .fasterThanPlanned, .offTrack, .insufficientData] {
            for style in ProgramStyle.allCases {
                allCopy += CoachingCopy.checkInExplanation(
                    assessment: assessment,
                    goalType: .cut,
                    programStyle: style,
                    previousTarget: 2200,
                    recommendedTarget: 2100,
                    observedRateKgPerWeek: -0.3,
                    goalRateKgPerWeek: -0.5,
                    weightUnit: .kilograms
                )
            }
        }
        XCTAssertFalse(allCopy.isEmpty)
        for line in allCopy {
            for word in banned {
                XCTAssertFalse(
                    line.lowercased().contains(word),
                    "Copy contains shaming language '\(word)': \(line)"
                )
            }
        }
    }
}
