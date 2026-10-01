//  StrategyViewModel.swift
//  StrategyFeature — loads program state, runs the coaching engine, and
//  persists check-in / program-edit outcomes.
//
//  Every number on screen comes from CoachingEngine's pure functions; this
//  type only maps repository data onto the engine's input types, schedules
//  the weekly check-in, and writes results back through `ProgramRepository`
//  (which owns target persistence — see `recordCheckIn`).

import Foundation
import Observation
import CoachingEngine
import DataLayer

/// What kind of day today is, for the targets card.
public enum StrategyDayKind: Equatable {
    /// Normal day: diet-plan computation.
    case standard
    /// Today matches a per-weekday override.
    case customOverride
    /// Today is a fasting day.
    case fasting
}

@MainActor
@Observable
public final class StrategyViewModel {
    /// Days of history pulled for the estimator / check-in.
    private static let historyWindowDays = 28
    /// Body weight used only when no weigh-in exists yet; the UI flags it
    /// as an estimate so the user knows to log a weigh-in.
    private static let fallbackBodyWeightKg = 70.0

    public let dependencies: StrategyDependencies

    // MARK: Loaded state

    public private(set) var settings: ProgramSettings?
    public private(set) var program: CoachingProgram?
    public private(set) var bodyWeightKg: Double = fallbackBodyWeightKg
    public private(set) var usedEstimatedWeight = false
    public private(set) var todayTargets: MacroTargets?
    public private(set) var todayKind: StrategyDayKind = .standard
    public private(set) var estimate: ExpenditureEstimate?
    public private(set) var report: CheckInReport?
    public private(set) var lastCheckIn: CheckInRecord?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    // Engine inputs, cached at load time so check-ins and program edits
    // reuse the exact same data.
    private var intake: [IntakeDay] = []
    private var weightSamples: [WeightSample] = []
    private var stepDays: [StepDay] = []

    public init(dependencies: StrategyDependencies) {
        self.dependencies = dependencies
    }

    // MARK: Loading

    /// Loads settings, history, and every engine-derived value.
    public func load() {
        isLoading = true
        defer { isLoading = false }
        do {
            let programRepo = dependencies.program
            let settings = try programRepo.settings()
            let program = try programRepo.coachingProgram()
            let end = Date()
            let start = Calendar.current.date(
                byAdding: .day, value: -Self.historyWindowDays, to: end
            ) ?? end

            let intake = try dependencies.logs.intakeDays(from: start, to: end)
            let weightSamples = try dependencies.weights.samples(from: start, to: end)
            let stepDays = try dependencies.steps.stepDays(from: start, to: end)

            let latestKg = try dependencies.weights.latestWeight()?.weightKg
            let trendKg = WeightTrend.currentTrendKg(samples: weightSamples)
            self.bodyWeightKg = latestKg ?? trendKg ?? Self.fallbackBodyWeightKg
            self.usedEstimatedWeight = latestKg == nil && trendKg == nil

            self.settings = settings
            self.program = program
            self.intake = intake
            self.weightSamples = weightSamples
            self.stepDays = stepDays

            if settings.currentCalories > 0 {
                self.todayTargets = MacroPlanner.targetsForDay(
                    Date(),
                    baseCalories: settings.currentCalories,
                    bodyWeightKg: bodyWeightKg,
                    program: program
                )
            } else {
                self.todayTargets = nil
            }

            let weekday = CoachingEngine.weekday(of: Date())
            if program.dayOverrides[weekday] != nil {
                self.todayKind = .customOverride
            } else if program.fastingWeekdays.contains(weekday) {
                self.todayKind = .fasting
            } else {
                self.todayKind = .standard
            }

            self.estimate = ExpenditureEstimator.estimate(
                intake: intake, weights: weightSamples, steps: stepDays
            )

            let history = try programRepo.checkInHistory(from: start, to: end)
            self.lastCheckIn = history.first

            self.errorMessage = nil
            maybeAutoCheckIn()
        } catch {
            self.errorMessage = "Couldn't load your strategy. Please try again."
        }
    }

    // MARK: Weekly check-in

    /// Runs the check-in on schedule: on the user's check-in weekday, when
    /// no check-in has been recorded in the last 6 days.
    private func maybeAutoCheckIn() {
        guard let settings, report == nil else { return }
        guard CoachingEngine.weekday(of: Date()) == settings.checkInWeekday else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        let recent = (try? dependencies.program.checkInHistory(from: cutoff, to: Date())) ?? []
        guard recent.isEmpty else { return }
        runCheckIn()
    }

    /// Runs the engine's check-in now. Coached programs apply automatically;
    /// collaborative/manual programs surface the report for review.
    public func runCheckIn() {
        guard let settings, let program else { return }
        let report = WeeklyCheckIn.run(
            program: program,
            intake: intake,
            weights: weightSamples,
            steps: stepDays,
            currentCalorieTarget: settings.currentCalories,
            bodyWeightKg: bodyWeightKg
        )
        self.report = report

        if let expenditure = report.expenditure {
            let snapshot = ExpenditureSnapshot(
                estimateKcal: expenditure.kcalPerDay,
                confidence: expenditure.confidence,
                method: expenditure.stepAdjustmentFactor == 1.0 ? .energyBalance : .stepAdjusted,
                intakeDaysUsed: expenditure.days,
                averageSteps: nil
            )
            _ = try? dependencies.program.recordExpenditureSnapshot(snapshot)
        }

        if report.appliedAutomatically {
            let macros = WeeklyCheckIn.applyRecommendation(report, bodyWeightKg: bodyWeightKg)
            persistCheckIn(report: report, macros: macros, wasApplied: true)
        }
    }

    /// Collaborative flow: the user accepts the pending proposal.
    public func acceptProposal() {
        guard let report else { return }
        let macros = WeeklyCheckIn.applyRecommendation(report, bodyWeightKg: bodyWeightKg)
        persistCheckIn(report: report, macros: macros, wasApplied: true, clearProposal: true)
    }

    /// Collaborative flow: the user declines the pending proposal. Recorded
    /// as reviewed-but-not-applied so history stays honest.
    public func declineProposal() {
        guard let report else { return }
        let macros = MacroPlanner.targets(
            calories: report.previousCalorieTarget,
            bodyWeightKg: bodyWeightKg,
            program: report.program
        )
        persistCheckIn(report: report, macros: macros, wasApplied: false, clearProposal: true)
    }

    private func persistCheckIn(
        report: CheckInReport,
        macros: MacroTargets,
        wasApplied: Bool,
        clearProposal: Bool = false
    ) {
        let record = CheckInRecord(
            programStyleRaw: report.program.programStyle.rawValue,
            assessmentRaw: assessmentLabel(report.assessment),
            previousCalories: report.previousCalorieTarget,
            previousProteinGrams: settings?.currentProteinGrams ?? 0,
            previousFatGrams: settings?.currentFatGrams ?? 0,
            previousCarbsGrams: settings?.currentCarbsGrams ?? 0,
            newCalories: macros.calories,
            newProteinGrams: macros.proteinGrams,
            newFatGrams: macros.fatGrams,
            newCarbsGrams: macros.carbsGrams,
            wasApplied: wasApplied,
            summaryText: report.explanation.joined(separator: " ")
        )
        try? dependencies.program.recordCheckIn(record)
        // `recordCheckIn` writes the new targets into settings when applied.
        if clearProposal { self.report = nil }
        load()
    }

    // MARK: Program editing

    /// Saves program edits, then recomputes the calorie target through the
    /// engine: estimated expenditure plus the goal's energy delta when an
    /// estimate exists, otherwise the existing target is kept and only the
    /// macro split is refreshed for the new plan.
    public func saveProgramEdits(_ draft: ProgramDraft) {
        do {
            try dependencies.program.updateSettings { s in
                s.goalType = draft.goalType
                s.programStyle = draft.programStyle
                s.dietPlan = draft.dietPlan
                s.rateOfChangeKgPerWeek = draft.signedRateKgPerWeek
                s.proteinGramsPerKg = draft.proteinGramsPerKg
                s.fastingWeekdays = draft.fastingWeekdays
                s.fastingDayCalorieFraction = draft.fastingDayCalorieFraction
                s.weightUnit = draft.weightUnit
            }
            let program = try dependencies.program.coachingProgram()
            let baseCalories: Double
            if let est = ExpenditureEstimator.estimate(
                intake: intake, weights: weightSamples, steps: stepDays
            ) {
                baseCalories = max(0, est.kcalPerDay + program.goalEnergyDeltaKcalPerDay)
            } else {
                baseCalories = settings?.currentCalories ?? 0
            }
            if baseCalories > 0 {
                let macros = MacroPlanner.targets(
                    calories: baseCalories, bodyWeightKg: bodyWeightKg, program: program
                )
                try dependencies.program.updateSettings { s in
                    s.currentCalories = macros.calories
                    s.currentProteinGrams = macros.proteinGrams
                    s.currentFatGrams = macros.fatGrams
                    s.currentCarbsGrams = macros.carbsGrams
                }
            }
            report = nil
            errorMessage = nil
            load()
        } catch {
            errorMessage = "Couldn't save your program. Please try again."
        }
    }

    /// Manual style: the user sets targets directly; coaching stays advisory.
    public func saveManualTargets(_ targets: MacroTargets) {
        do {
            try dependencies.program.updateSettings { s in
                s.currentCalories = max(0, targets.calories)
                s.currentProteinGrams = max(0, targets.proteinGrams)
                s.currentFatGrams = max(0, targets.fatGrams)
                s.currentCarbsGrams = max(0, targets.carbsGrams)
            }
            report = nil
            errorMessage = nil
            load()
        } catch {
            errorMessage = "Couldn't save your targets. Please try again."
        }
    }
}

// MARK: - Presentation helpers (original, adherence-neutral copy)

/// Short label for a check-in assessment.
public func assessmentLabel(_ assessment: ProgressAssessment) -> String {
    switch assessment {
    case .onTrack: return "On track"
    case .slowerThanPlanned: return "A little behind pace"
    case .fasterThanPlanned: return "A little ahead of pace"
    case .offTrack: return "Off track"
    case .insufficientData: return "Not enough data yet"
    }
}

/// Short label for a goal type.
public func goalTypeLabel(_ goal: GoalType) -> String {
    switch goal {
    case .cut: return "Cut"
    case .maintain: return "Maintain"
    case .bulk: return "Bulk"
    }
}

/// Short label for a program style.
public func programStyleLabel(_ style: ProgramStyle) -> String {
    switch style {
    case .coached: return "Coached"
    case .collaborative: return "Collaborative"
    case .manual: return "Manual"
    }
}

/// One-line description of what a program style does.
public func programStyleDescription(_ style: ProgramStyle) -> String {
    switch style {
    case .coached:
        return "Targets adjust automatically at each weekly check-in."
    case .collaborative:
        return "You review and accept weekly suggestions before they apply."
    case .manual:
        return "You set targets yourself; coaching stays advisory."
    }
}

/// Short label for a diet plan.
public func dietPlanLabel(_ plan: DietPlan) -> String {
    switch plan {
    case .balanced: return "Balanced"
    case .lowCarb: return "Low carb"
    case .keto: return "Keto"
    case .carbFocused: return "Carb focused"
    }
}

/// Confidence band for an expenditure estimate (0…1).
public func confidenceLabel(_ confidence: Double) -> String {
    if confidence < 0.4 { return "Low" }
    if confidence < 0.7 { return "Moderate" }
    return "High"
}

/// Weekday name for a Calendar-convention weekday (1 = Sunday … 7 = Saturday).
public func weekdayName(_ weekday: Int) -> String {
    guard (1...7).contains(weekday) else { return "" }
    return Calendar.current.weekdaySymbols[weekday - 1]
}
