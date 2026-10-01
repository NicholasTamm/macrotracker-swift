//  StrategyDependencies.swift
//  StrategyFeature — dependency bundle for the Strategy tab.

import Foundation
import DataLayer

/// Repository protocols the Strategy surface needs. AppShell builds this
/// from the `DataStore`, following the `AnalyticsDependencies` pattern —
/// the feature never touches SwiftData types directly.
public struct StrategyDependencies {
    public var logs: any LogRepository
    public var weights: any WeightRepository
    public var steps: any StepRepository
    public var program: any ProgramRepository

    public init(
        logs: any LogRepository,
        weights: any WeightRepository,
        steps: any StepRepository,
        program: any ProgramRepository
    ) {
        self.logs = logs
        self.weights = weights
        self.steps = steps
        self.program = program
    }
}
