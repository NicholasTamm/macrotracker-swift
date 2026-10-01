//  StrategyFeature.swift
//  StrategyFeature — the Strategy tab's purpose-built surface (issue #14).
//
//  Program overview, today's targets, expenditure estimate, and the weekly
//  coaching check-in. All coaching math runs through CoachingEngine's pure
//  functions (`MacroPlanner`, `ExpenditureEstimator`, `WeeklyCheckIn`) —
//  this module owns presentation, scheduling, and persistence only, never
//  duplicated logic.
//
//  Data flows in through ``StrategyDependencies`` (repository protocols,
//  never SwiftData types), mirroring the `AnalyticsDependencies` pattern.
//  Copy is original and adherence-neutral throughout.

import Foundation

/// Marker namespace for the Strategy feature module.
public enum StrategyFeature {
    /// Module version, for diagnostics.
    public static let version = "1.0.0"
}
