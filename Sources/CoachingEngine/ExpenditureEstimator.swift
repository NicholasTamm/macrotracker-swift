//  ExpenditureEstimator.swift
//  CoachingEngine — adaptive expenditure estimation via energy-balance
//  back-calculation, with a step-informed modifier.

import Foundation

/// Result of an expenditure estimation pass.
public struct ExpenditureEstimate: Equatable, Sendable {
    /// Estimated total daily energy expenditure (kcal/day).
    public var kcalPerDay: Double
    /// 0…1 confidence in the estimate, from logging + weighing completeness.
    public var confidence: Double
    /// Mean logged intake over the window (kcal/day).
    public var averageIntakeKcalPerDay: Double
    /// Smoothed weight change over the window (kg).
    public var weightChangeKg: Double
    /// Multiplicative step-informed adjustment that was applied (1.0 = none).
    public var stepAdjustmentFactor: Double
    /// Number of days used in the window.
    public var days: Int
    /// Human-readable notes on how the estimate was derived (for debugging
    /// and for analytics surfaces; not user-facing copy).
    public var derivationNotes: [String]
}

/// Adaptive expenditure estimation.
///
/// Energy-balance back-calculation: over a window,
/// `expenditure = averageIntake − (weightChangeKg × 7700) / days`.
/// Intake comes from logged food, weight change from the smoothed trend.
/// Step counts apply a small bounded modifier: sustained step changes shift
/// activity energy, so the estimate follows them without ever importing
/// smartwatch calorie estimates.
public enum ExpenditureEstimator {

    /// Default estimation window in days.
    public static let defaultWindowDays: Int = 21
    /// Minimum window that still yields an estimate.
    public static let minimumWindowDays: Int = 7
    /// Relative step change needed before the modifier engages.
    public static let stepEngagementThreshold: Double = 0.10
    /// Maximum multiplicative step adjustment (i.e. ±5%).
    public static let maxStepAdjustment: Double = 0.05
    /// How strongly relative step changes move the estimate (0.5 = a 20%
    /// step increase shifts the estimate by 10% before capping).
    public static let stepSensitivity: Double = 0.5

    /// Estimate daily expenditure from intake logs + weight trend.
    ///
    /// - Parameters:
    ///   - intake: Daily intake records (any order; missing days ignored).
    ///   - weights: Weight samples.
    ///   - steps: Optional daily step counts. The modifier compares mean
    ///     steps in the most recent third of the window against the earlier
    ///     two thirds as its baseline.
    ///   - endDate: Last day of the window (inclusive).
    ///   - windowDays: Window length in days.
    /// - Returns: An estimate, or nil when the data is insufficient
    ///   (fewer than ``minimumWindowDays`` days or no weight trend).
    public static func estimate(
        intake: [IntakeDay],
        weights: [WeightSample],
        steps: [StepDay] = [],
        endDate: Date = Date(),
        windowDays: Int = defaultWindowDays
    ) -> ExpenditureEstimate? {
        guard windowDays >= minimumWindowDays else { return nil }

        let calendar = CoachingEngine.deviceCalendar
        let endDay = CoachingEngine.startOfDay(endDate)
        guard let startDay = calendar.date(byAdding: .day, value: -(windowDays - 1), to: endDay) else {
            return nil
        }

        // Bucket complete intake days; incomplete days count at half weight.
        var intakeByDay: [Date: (kcal: Double, weight: Double)] = [:]
        var completeDays = 0
        var day = startDay
        while day <= endDay {
            intakeByDay[day] = (0, 0)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        for record in intake {
            let recordDay = CoachingEngine.startOfDay(record.date)
            guard recordDay >= startDay, recordDay <= endDay else { continue }
            let w = record.isComplete ? 1.0 : 0.5
            let existing = intakeByDay[recordDay] ?? (0, 0)
            intakeByDay[recordDay] = (existing.kcal + record.calories * w, existing.weight + w)
            if record.isComplete { completeDays += 1 }
        }
        let totalKcal = intakeByDay.values.reduce(0) { $0 + $1.kcal }
        let totalWeight = intakeByDay.values.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }
        let averageIntake = totalKcal / totalWeight

        guard let trend = WeightTrend.summarize(
            samples: weights, endDate: endDate, windowDays: windowDays
        ) else { return nil }

        // Energy balance: expenditure = intake − stored-energy change / days.
        let storedEnergyChangeKcal = trend.totalChangeKg * EnergyConstants.kcalPerKgBodyWeight
        var kcalPerDay = averageIntake - storedEnergyChangeKcal / Double(windowDays)

        // Step-informed modifier.
        let stepFactor = stepAdjustmentFactor(steps: steps, startDay: startDay, endDay: endDay, windowDays: windowDays)
        kcalPerDay *= stepFactor

        // Confidence: geometric-ish blend of intake completeness and
        // weighing completeness. Partial logs still count, just less.
        let intakeCompleteness = min(1.0, totalWeight / Double(windowDays))
        let confidence = sqrt(intakeCompleteness * trend.samplingCompleteness)

        var notes: [String] = [
            "windowDays=\(windowDays)",
            String(format: "avgIntake=%.0f", averageIntake),
            String(format: "trendChangeKg=%+.3f", trend.totalChangeKg),
            String(format: "stepFactor=%.3f", stepFactor),
        ]
        if intakeCompleteness < 1.0 {
            notes.append(String(format: "partial logging: intake completeness %.0f%%", intakeCompleteness * 100))
        }

        return ExpenditureEstimate(
            kcalPerDay: max(0, kcalPerDay),
            confidence: confidence,
            averageIntakeKcalPerDay: averageIntake,
            weightChangeKg: trend.totalChangeKg,
            stepAdjustmentFactor: stepFactor,
            days: windowDays,
            derivationNotes: notes
        )
    }

    /// Step-informed adjustment factor (1.0 = no adjustment).
    ///
    /// Compares mean daily steps in the most recent third of the window to
    /// the mean of the earlier portion (the baseline). Relative changes
    /// below the engagement threshold are ignored; larger changes shift the
    /// estimate proportionally, capped at ±``maxStepAdjustment``.
    public static func stepAdjustmentFactor(
        steps: [StepDay],
        startDay: Date,
        endDay: Date,
        windowDays: Int
    ) -> Double {
        guard windowDays >= 3, !steps.isEmpty else { return 1.0 }
        let calendar = CoachingEngine.deviceCalendar

        var baselineTotal = 0.0, baselineDays = 0
        var recentTotal = 0.0, recentDays = 0
        let recentCutoffDays = max(1, windowDays / 3)
        guard let recentStart = calendar.date(
            byAdding: .day, value: -(recentCutoffDays - 1), to: endDay
        ) else { return 1.0 }

        var byDay: [Date: Double] = [:]
        for entry in steps {
            let d = CoachingEngine.startOfDay(entry.date)
            guard d >= startDay, d <= endDay else { continue }
            byDay[d, default: 0] += entry.steps
        }
        guard !byDay.isEmpty else { return 1.0 }

        var day = startDay
        while day <= endDay {
            if let s = byDay[day] {
                if day >= recentStart {
                    recentTotal += s; recentDays += 1
                } else {
                    baselineTotal += s; baselineDays += 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        guard baselineDays > 0, recentDays > 0 else { return 1.0 }

        let baseline = baselineTotal / Double(baselineDays)
        let recent = recentTotal / Double(recentDays)
        guard baseline > 0 else { return 1.0 }

        let relativeChange = (recent - baseline) / baseline
        guard abs(relativeChange) >= stepEngagementThreshold else { return 1.0 }

        let raw = relativeChange * stepSensitivity
        let clamped = min(maxStepAdjustment, max(-maxStepAdjustment, raw))
        return 1.0 + clamped
    }
}
