//  WeeklyCheckIn.swift
//  CoachingEngine — the weekly check-in flow: compare progress to the goal,
//  adjust targets, and explain the change in adherence-neutral language.
//
//  All user-facing copy in this file is original to this project. It is
//  deliberately adherence-neutral: it describes what happened and what the
//  plan is doing about it, never shames over-target days, and never moralizes
//  food or body weight.

import Foundation

/// How far the observed trend is from the goal pace.
public enum ProgressAssessment: Equatable, Sendable {
    /// Within tolerance of the goal rate.
    case onTrack
    /// Moving toward the goal, but slower than planned.
    case slowerThanPlanned
    /// Moving toward the goal faster than planned.
    case fasterThanPlanned
    /// Moving away from the goal (or flat when change is wanted).
    case offTrack
    /// Not enough data to assess.
    case insufficientData
}

/// The outcome of one weekly check-in.
public struct CheckInReport: Equatable, Sendable {
    /// When the check-in ran.
    public var date: Date
    /// The program this check-in ran against.
    public var program: CoachingProgram
    /// Estimated expenditure used for this check-in (nil when unavailable).
    public var expenditure: ExpenditureEstimate?
    /// Observed weight-trend rate (kg/week), nil when unavailable.
    public var observedRateKgPerWeek: Double?
    /// Goal rate (kg/week) after clamping.
    public var goalRateKgPerWeek: Double
    public var assessment: ProgressAssessment
    /// Calorie target before the check-in.
    public var previousCalorieTarget: Double
    /// Recommended calorie target after the check-in.
    public var recommendedCalorieTarget: Double
    /// Macro targets derived from the recommended calorie target.
    public var recommendedMacros: MacroTargets
    /// True when the engine applied the new target itself (Coached style).
    /// For Collaborative the caller applies it via `applyRecommendation`;
    /// for Manual it is advisory only.
    public var appliedAutomatically: Bool
    /// User-facing explanation lines, in display order. Adherence-neutral.
    public var explanation: [String]
}

/// The weekly check-in: pure functions over the program + recent data.
public enum WeeklyCheckIn {

    /// Tolerance around the goal rate (kg/week) that still counts as on track.
    public static let onTrackToleranceKgPerWeek: Double = 0.15
    /// Window (days) the check-in evaluates.
    public static let evaluationWindowDays: Int = 21

    /// Run the weekly check-in.
    ///
    /// - Parameters:
    ///   - program: The user's coaching program.
    ///   - intake: Recent intake records.
    ///   - weights: Recent weight samples.
    ///   - steps: Recent step counts.
    ///   - currentCalorieTarget: The calorie target in force before check-in.
    ///   - bodyWeightKg: Current trend weight (kg); used for macro math.
    ///   - date: When the check-in runs (defaults to now).
    public static func run(
        program: CoachingProgram,
        intake: [IntakeDay],
        weights: [WeightSample],
        steps: [StepDay] = [],
        currentCalorieTarget: Double,
        bodyWeightKg: Double,
        date: Date = Date()
    ) -> CheckInReport {
        let goalRate = program.clampedRateOfChangeKgPerWeek
        let expenditure = ExpenditureEstimator.estimate(
            intake: intake,
            weights: weights,
            steps: steps,
            endDate: date,
            windowDays: evaluationWindowDays
        )
        let trend = WeightTrend.summarize(
            samples: weights, endDate: date, windowDays: evaluationWindowDays
        )
        let observedRate = trend?.rateKgPerWeek
        let confidence = expenditure?.confidence ?? 0

        let assessment = assess(
            observedRate: observedRate,
            goalRate: goalRate,
            goalType: program.goalType,
            confidence: confidence
        )

        // Ideal target: estimated expenditure plus the goal's energy delta.
        // Without an expenditure estimate, hold the current target.
        let idealTarget: Double = {
            guard let expenditure else { return currentCalorieTarget }
            return expenditure.kcalPerDay + program.goalEnergyDeltaKcalPerDay
        }()

        let recommended: Double
        switch assessment {
        case .onTrack, .insufficientData:
            recommended = currentCalorieTarget
        case .slowerThanPlanned, .fasterThanPlanned, .offTrack:
            recommended = MacroPlanner.boundedAdjustment(
                from: currentCalorieTarget,
                to: idealTarget,
                confidence: confidence
            )
        }

        let macros = MacroPlanner.targets(
            calories: recommended, bodyWeightKg: bodyWeightKg, program: program
        )

        let appliedAutomatically = (program.programStyle == .coached)
            && assessment != .insufficientData
            && recommended != currentCalorieTarget

        let explanation = CoachingCopy.checkInExplanation(
            assessment: assessment,
            goalType: program.goalType,
            programStyle: program.programStyle,
            previousTarget: currentCalorieTarget,
            recommendedTarget: recommended,
            observedRateKgPerWeek: observedRate,
            goalRateKgPerWeek: goalRate,
            weightUnit: program.weightUnit
        )

        return CheckInReport(
            date: date,
            program: program,
            expenditure: expenditure,
            observedRateKgPerWeek: observedRate,
            goalRateKgPerWeek: goalRate,
            assessment: assessment,
            previousCalorieTarget: currentCalorieTarget,
            recommendedCalorieTarget: recommended,
            recommendedMacros: macros,
            appliedAutomatically: appliedAutomatically,
            explanation: explanation
        )
    }

    /// For Collaborative programs: accept the check-in's recommendation,
    /// returning updated targets. (Coached applies automatically; Manual
    /// ignores the recommendation.)
    public static func applyRecommendation(
        _ report: CheckInReport,
        bodyWeightKg: Double
    ) -> MacroTargets {
        MacroPlanner.targets(
            calories: report.recommendedCalorieTarget,
            bodyWeightKg: bodyWeightKg,
            program: report.program
        )
    }

    // MARK: - Assessment

    static func assess(
        observedRate: Double?,
        goalRate: Double,
        goalType: GoalType,
        confidence: Double
    ) -> ProgressAssessment {
        guard let observedRate, confidence > 0.25 else { return .insufficientData }

        let tolerance = onTrackToleranceKgPerWeek
        switch goalType {
        case .maintain:
            return abs(observedRate) <= tolerance ? .onTrack : .offTrack
        case .cut:
            if observedRate <= goalRate + tolerance && observedRate >= goalRate - tolerance {
                return .onTrack
            } else if observedRate < goalRate - tolerance {
                return .fasterThanPlanned
            } else if observedRate < 0 {
                // Any movement toward the goal counts as "slower", even when
                // the goal rate is small enough that no gap exists between the
                // on-track band and flat. (Previously `< -tolerance`, which
                // made this branch unreachable for |goalRate| <= 0.30.)
                return .slowerThanPlanned
            } else {
                return .offTrack
            }
        case .bulk:
            if observedRate >= goalRate - tolerance && observedRate <= goalRate + tolerance {
                return .onTrack
            } else if observedRate > goalRate + tolerance {
                return .fasterThanPlanned
            } else if observedRate > 0 {
                // Symmetric with the cut branch above.
                return .slowerThanPlanned
            } else {
                return .offTrack
            }
        }
    }
}

// MARK: - Adherence-neutral coaching copy

/// Original, adherence-neutral user-facing copy for the check-in flow.
/// Nothing here shames over-target days or moralizes food choices.
public enum CoachingCopy {

    public static func checkInExplanation(
        assessment: ProgressAssessment,
        goalType: GoalType,
        programStyle: ProgramStyle,
        previousTarget: Double,
        recommendedTarget: Double,
        observedRateKgPerWeek: Double?,
        goalRateKgPerWeek: Double,
        weightUnit: WeightUnit
    ) -> [String] {
        var lines: [String] = []
        let delta = recommendedTarget - previousTarget

        func rateLine(_ rate: Double) -> String {
            let converted = weightUnit.fromKilograms(abs(rate))
            let unit = weightUnit == .pounds ? "lb" : "kg"
            let direction: String
            switch goalType {
            case .cut: direction = "lost"
            case .bulk: direction = "gained"
            case .maintain: direction = "changed"
            }
            return String(format: "Your trend weight %@ about %.1f %@ per week.", direction, converted, unit)
        }

        switch assessment {
        case .onTrack:
            lines.append("Your trend is moving right along with your goal pace.")
            if let observedRate = observedRateKgPerWeek { lines.append(rateLine(observedRate)) }
            lines.append("No changes needed this week — steady as she goes.")
        case .slowerThanPlanned:
            lines.append("Your trend moved a little slower than your goal pace this week.")
            if let observedRate = observedRateKgPerWeek { lines.append(rateLine(observedRate)) }
            lines.append("That's normal — bodies adapt as they go. Your targets were adjusted slightly to keep things moving.")
        case .fasterThanPlanned:
            lines.append("Your trend moved a little faster than your goal pace this week.")
            if let observedRate = observedRateKgPerWeek { lines.append(rateLine(observedRate)) }
            lines.append("Faster isn't always better, so your targets were eased slightly to keep the pace sustainable.")
        case .offTrack:
            lines.append("Your trend drifted from your goal pace this week.")
            lines.append("Life happens — travel, stress, celebrations. Your targets were adjusted to get the trend back on course.")
        case .insufficientData:
            lines.append("There wasn't quite enough logged data to assess this week.")
            lines.append("Keep logging food and weighing in when you can, and next week's check-in will have more to work with.")
        }

        if abs(delta) >= 1, assessment != .insufficientData {
            let direction = delta > 0 ? "increased" : "decreased"
            lines.append(String(
                format: "Calorie target %@ from %.0f to %.0f to match your estimated expenditure.",
                direction, previousTarget, recommendedTarget
            ))
        }

        switch programStyle {
        case .coached:
            if abs(delta) >= 1, assessment != .insufficientData {
                lines.append("This change is already live — no action needed from you.")
            }
        case .collaborative:
            if abs(delta) >= 1, assessment != .insufficientData {
                lines.append("Review the proposed change when you're ready and accept it to apply.")
            }
        case .manual:
            lines.append("Your targets are yours to set — use this as a reference if you like.")
        }

        return lines
    }

    /// Short neutral note for a day that came in over the calorie target.
    public static func overTargetNote() -> String {
        "A little over target today — one day doesn't define the trend. Tomorrow is a fresh page."
    }

    /// Short neutral note for a day that came in under the calorie target.
    public static func underTargetNote() -> String {
        "A little under target today. If that wasn't intentional, there's room to add something satisfying."
    }
}
