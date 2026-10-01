//  StrategyCards.swift
//  StrategyFeature — the Strategy tab's cards: program summary, today's
//  targets, expenditure estimate, and the weekly check-in.

import SwiftUI
import DesignSystem
import CoachingEngine
import DataLayer

// MARK: - Program summary

/// Current program at a glance: goal, style, rate, diet plan, protein.
struct ProgramSummaryCard: View {
    let program: CoachingProgram
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            HStack {
                Text("Your program")
                    .font(MFFont.title3)
                    .foregroundColor(MFColor.textPrimary)
                Spacer()
                Button("Edit", action: onEdit)
                    .font(MFFont.subheadline.weight(.semibold))
                    .foregroundColor(MFColor.accent)
                    .accessibilityLabel("Edit program")
            }
            summaryRow(label: "Goal", value: goalTypeLabel(program.goalType))
            summaryRow(
                label: "Style",
                value: "\(programStyleLabel(program.programStyle)) — \(programStyleDescription(program.programStyle))"
            )
            summaryRow(label: "Pace", value: rateText)
            summaryRow(label: "Diet plan", value: dietPlanLabel(program.dietPlan))
            summaryRow(
                label: "Protein",
                value: String(format: "%.1f g per kg of body weight", program.proteinGramsPerKg)
            )
        }
        .mfCard()
        .accessibilityElement(children: .combine)
    }

    private var rateText: String {
        let rate = program.clampedRateOfChangeKgPerWeek
        let converted = abs(program.weightUnit.fromKilograms(rate))
        let unit = program.weightUnit == .pounds ? "lb" : "kg"
        switch program.goalType {
        case .maintain:
            return "Maintain current weight"
        case .cut:
            return String(format: "Lose about %.1f %@ per week", converted, unit)
        case .bulk:
            return String(format: "Gain about %.1f %@ per week", converted, unit)
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: MFSpacing.md) {
            Text(label)
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textSecondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(MFFont.subheadline.weight(.medium))
                .foregroundColor(MFColor.textPrimary)
        }
    }
}

// MARK: - Today's targets

/// Today's calorie + macro targets from `MacroPlanner.targetsForDay`,
/// honoring weekday overrides and fasting days.
struct TodayTargetsCard: View {
    let targets: MacroTargets?
    let kind: StrategyDayKind
    let usedEstimatedWeight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            HStack {
                Text("Today's targets")
                    .font(MFFont.title3)
                    .foregroundColor(MFColor.textPrimary)
                Spacer()
                dayKindBadge
            }
            if let targets {
                HStack(alignment: .firstTextBaseline, spacing: MFSpacing.xs) {
                    Text("\(Int(targets.calories.rounded()))")
                        .font(MFFont.largeTitle)
                        .foregroundColor(MFColor.calories)
                    Text("cal")
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textSecondary)
                }
                .accessibilityLabel("\(Int(targets.calories.rounded())) calories today")
                macroRow(color: MFColor.protein, label: "Protein", grams: targets.proteinGrams)
                macroRow(color: MFColor.fat, label: "Fat", grams: targets.fatGrams)
                macroRow(color: MFColor.carbs, label: "Carbs", grams: targets.carbsGrams)
                if usedEstimatedWeight {
                    Text("Using an estimated body weight — log a weigh-in to personalize protein targets.")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }
            } else {
                Text("No targets yet. Set up your program to get daily calorie and macro targets.")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
            }
        }
        .mfCard()
    }

    @ViewBuilder
    private var dayKindBadge: some View {
        switch kind {
        case .standard:
            EmptyView()
        case .customOverride:
            Text("Custom day")
                .font(MFFont.caption.weight(.semibold))
                .padding(.horizontal, MFSpacing.sm)
                .padding(.vertical, MFSpacing.xs)
                .background(MFColor.surfaceSunken)
                .clipShape(Capsule())
                .foregroundColor(MFColor.textSecondary)
        case .fasting:
            Text("Fasting day")
                .font(MFFont.caption.weight(.semibold))
                .padding(.horizontal, MFSpacing.sm)
                .padding(.vertical, MFSpacing.xs)
                .background(MFColor.surfaceSunken)
                .clipShape(Capsule())
                .foregroundColor(MFColor.textSecondary)
        }
    }

    private func macroRow(color: Color, label: String, grams: Double) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textSecondary)
            Spacer()
            Text("\(Int(grams.rounded())) g")
                .font(MFFont.subheadline.weight(.semibold))
                .foregroundColor(MFColor.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(Int(grams.rounded())) grams")
    }
}

// MARK: - Expenditure estimate

/// Estimated daily expenditure with confidence, from `ExpenditureEstimator`.
struct ExpenditureCard: View {
    let estimate: ExpenditureEstimate?

    var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            Text("Expenditure estimate")
                .font(MFFont.title3)
                .foregroundColor(MFColor.textPrimary)
            if let estimate {
                HStack(alignment: .firstTextBaseline, spacing: MFSpacing.xs) {
                    Text("\(Int(estimate.kcalPerDay.rounded()))")
                        .font(MFFont.largeTitle)
                        .foregroundColor(MFColor.textPrimary)
                    Text("cal / day")
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textSecondary)
                }
                .accessibilityLabel("Estimated expenditure \(Int(estimate.kcalPerDay.rounded())) calories per day")
                HStack {
                    Text("Confidence")
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textSecondary)
                    Spacer()
                    Text(confidenceLabel(estimate.confidence))
                        .font(MFFont.subheadline.weight(.semibold))
                        .foregroundColor(MFColor.textPrimary)
                }
                if !estimate.derivationNotes.isEmpty {
                    VStack(alignment: .leading, spacing: MFSpacing.xs) {
                        ForEach(estimate.derivationNotes.indices, id: \.self) { index in
                            Text(estimate.derivationNotes[index])
                                .font(MFFont.caption)
                                .foregroundColor(MFColor.textSecondary)
                        }
                    }
                }
                Text("Back-calculated from your logged intake and weight trend. It gets more reliable as you log consistently.")
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            } else {
                Text("Not enough data yet. Log food and weigh in regularly for about a week and your expenditure estimate will appear here.")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
            }
        }
        .mfCard()
    }
}

// MARK: - Weekly check-in

/// Weekly check-in card. Coached programs show auto-applied results;
/// collaborative programs show a proposal to accept or decline; manual
/// programs show the advisory report with a shortcut to edit targets.
struct CheckInCard: View {
    let report: CheckInReport?
    let lastCheckIn: CheckInRecord?
    let checkInWeekday: Int
    let programStyle: ProgramStyle
    let onRun: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onEditTargets: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            HStack {
                Text("Weekly check-in")
                    .font(MFFont.title3)
                    .foregroundColor(MFColor.textPrimary)
                Spacer()
                if report == nil {
                    Button("Run now", action: onRun)
                        .font(MFFont.subheadline.weight(.semibold))
                        .foregroundColor(MFColor.accent)
                        .accessibilityLabel("Run weekly check-in now")
                }
            }
            if let report {
                reportContent(report)
            } else {
                Text("Check-ins run every \(weekdayName(checkInWeekday)). They compare your trend weight against your goal pace and suggest small target adjustments when needed.")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
                if let lastCheckIn {
                    Text("Last check-in: \(lastCheckIn.date, style: .date) — \(lastCheckIn.assessmentRaw)")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }
            }
        }
        .mfCard()
    }

    @ViewBuilder
    private func reportContent(_ report: CheckInReport) -> some View {
        HStack {
            Text(assessmentLabel(report.assessment))
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            Spacer()
            if report.appliedAutomatically {
                Text("Applied")
                    .font(MFFont.caption.weight(.semibold))
                    .padding(.horizontal, MFSpacing.sm)
                    .padding(.vertical, MFSpacing.xs)
                    .background(MFColor.surfaceSunken)
                    .clipShape(Capsule())
                    .foregroundColor(MFColor.textSecondary)
                    .accessibilityLabel("Adjustment applied automatically")
            }
        }
        ForEach(report.explanation.indices, id: \.self) { index in
            Text(report.explanation[index])
                .font(MFFont.subheadline)
                .foregroundColor(MFColor.textPrimary)
        }
        if report.recommendedCalorieTarget != report.previousCalorieTarget {
            HStack {
                Text("Calories")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
                Spacer()
                Text("\(Int(report.previousCalorieTarget.rounded())) → \(Int(report.recommendedCalorieTarget.rounded()))")
                    .font(MFFont.subheadline.weight(.semibold))
                    .foregroundColor(MFColor.textPrimary)
            }
            .accessibilityLabel(
                "Recommended calories change from \(Int(report.previousCalorieTarget.rounded())) to \(Int(report.recommendedCalorieTarget.rounded()))"
            )
        }
        switch programStyle {
        case .coached:
            if report.appliedAutomatically {
                Text("Your coached program applied this adjustment for you.")
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            }
        case .collaborative:
            if !report.appliedAutomatically {
                Text("Review the suggestion — nothing changes until you accept it.")
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
                HStack(spacing: MFSpacing.md) {
                    MFButton("Accept", style: .primary, size: .medium, action: onAccept)
                    MFButton("Not now", style: .secondary, size: .medium, action: onDecline)
                }
            }
        case .manual:
            Text("Your manual program keeps coaching advisory — adjust targets yourself whenever you're ready.")
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
            MFButton("Edit targets", style: .secondary, size: .medium, action: onEditTargets)
        }
    }
}
