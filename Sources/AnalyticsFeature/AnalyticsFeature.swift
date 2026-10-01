import SwiftUI
import DesignSystem
import DataLayer

// MARK: - AnalyticsFeature (issue #8)
//
// Progress analytics: expenditure, weight, and nutrition dashboards built on
// Swift Charts, full micronutrient tracking with custom targets, top
// contributors for any nutrient, nutrient-timing insights, and habit views.
//
// Design notes:
// - All charts are Swift Charts (iOS 17+) and consume DesignSystem tokens
//   only (MFColor.*, MFFont, mfCard) — never hardcoded colors.
// - Nutrient identity comes from DataLayer's `NutrientKey` catalog
//   (33 keys); this module never hardcodes its own nutrient list.
// - Expenditure + weight-trend math is consumed from CoachingEngine
//   (WeightTrend, ExpenditureEstimator) per the #6 README contract;
//   AnalyticsFeature is the one feature target with a sanctioned
//   CoachingEngine dependency (see Package.swift).
// - Repository access is protocol-typed and injected by AppShell; feature
//   modules never touch SwiftData directly.
// - Copy is original and adherence-neutral (no shaming language).

// MARK: - AnalyticsDependencies

/// Repository bundle injected by AppShell into the dashboard.
/// Program to protocols; keep SwiftData behind the repository boundary.
/// (Not `Sendable`: the repositories are `@MainActor`-isolated. The bundle
/// only ever crosses the main actor, which is where SwiftUI lives.)
public struct AnalyticsDependencies {
    public var logs: any LogRepository
    public var weights: any WeightRepository
    public var program: any ProgramRepository
    public var foods: any FoodRepository
    public var habits: any HabitRepository
    public var steps: any StepRepository

    public init(
        logs: any LogRepository,
        weights: any WeightRepository,
        program: any ProgramRepository,
        foods: any FoodRepository,
        habits: any HabitRepository,
        steps: any StepRepository
    ) {
        self.logs = logs
        self.weights = weights
        self.program = program
        self.foods = foods
        self.habits = habits
        self.steps = steps
    }
}

// MARK: - DashboardRootView

/// The Dashboard tab root. AppShell embeds this in place of
/// `AnalyticsDashboardPlaceholder`:
/// `DashboardRootView(dependencies: AnalyticsDependencies(logs: store.logs, ...))`.
public struct DashboardRootView: View {
    private let dependencies: AnalyticsDependencies

    public init(dependencies: AnalyticsDependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        DashboardHomeView(dependencies: dependencies)
            .navigationTitle("Dashboard")
    }
}
