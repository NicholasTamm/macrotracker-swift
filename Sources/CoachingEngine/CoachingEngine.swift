//  CoachingEngine.swift
//  CoachingEngine — module namespace.

import Foundation

/// Namespace for the coaching engine (issue #6).
///
/// Pure, deterministic, Foundation-only logic:
/// - ``WeightTrend`` — weight-trend smoothing
/// - ``ExpenditureEstimator`` — energy-balance back-calculation + step modifier
/// - ``MacroPlanner`` — calorie targets → macro splits, diet plans, fasting days
/// - ``WeeklyCheckIn`` — weekly target adjustments + adherence-neutral copy
///
/// Input value types (``IntakeDay``, ``WeightSample``, ``StepDay``,
/// ``CoachingProgram``, ``MacroTargets``) live in CoachingModels.swift and are
/// the integration surface for the data layer (issue #3) and analytics
/// (issue #8): map their models onto these types and call the pure functions.
public enum CoachingEngine {
    /// Module version, for future migration bookkeeping.
    public static let version = 1
}
