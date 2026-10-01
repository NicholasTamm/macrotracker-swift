//  EditProgramSheet.swift
//  StrategyFeature — edit the coaching program. Every change flows back
//  through `StrategyViewModel.saveProgramEdits`, which recomputes targets
//  with the engine; this sheet holds no coaching logic of its own.

import SwiftUI
import DesignSystem
import CoachingEngine

/// Editable draft of a `CoachingProgram`, bound to the sheet's controls.
public struct ProgramDraft {
    public var goalType: GoalType = .maintain
    public var programStyle: ProgramStyle = .coached
    public var dietPlan: DietPlan = .balanced
    /// Magnitude of the weekly rate (kg/week), always ≥ 0; sign derives
    /// from the goal type.
    public var rateMagnitudeKgPerWeek: Double = 0.5
    public var proteinGramsPerKg: Double = 1.8
    public var fastingWeekdays: Set<Int> = []
    public var fastingDayCalorieFraction: Double = 0.25
    public var weightUnit: WeightUnit = .kilograms

    public init() {}

    public init(program: CoachingProgram) {
        self.goalType = program.goalType
        self.programStyle = program.programStyle
        self.dietPlan = program.dietPlan
        self.rateMagnitudeKgPerWeek = abs(program.rateOfChangeKgPerWeek)
        self.proteinGramsPerKg = program.proteinGramsPerKg
        self.fastingWeekdays = program.fastingWeekdays
        self.fastingDayCalorieFraction = program.fastingDayCalorieFraction
        self.weightUnit = program.weightUnit
    }

    /// Signed rate for the engine: negative for cut, positive for bulk.
    public var signedRateKgPerWeek: Double {
        switch goalType {
        case .cut: return -abs(rateMagnitudeKgPerWeek)
        case .bulk: return abs(rateMagnitudeKgPerWeek)
        case .maintain: return 0
        }
    }

    /// Slider上限 for the rate, mirroring the engine's clamp bounds.
    public var maxRateMagnitudeKgPerWeek: Double {
        switch goalType {
        case .cut: return 1.0
        case .bulk: return 0.5
        case .maintain: return 0
        }
    }
}

/// Sheet for editing goal, style, pace, diet plan, protein, and fasting days.
public struct EditProgramSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProgramDraft
    private let onSave: (ProgramDraft) -> Void

    public init(program: CoachingProgram, onSave: @escaping (ProgramDraft) -> Void) {
        _draft = State(initialValue: ProgramDraft(program: program))
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    Picker("Goal", selection: $draft.goalType) {
                        ForEach(GoalType.allCases, id: \.self) { goal in
                            Text(goalTypeLabel(goal)).tag(goal)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Goal")
                }

                Section("Coaching style") {
                    Picker("Style", selection: $draft.programStyle) {
                        ForEach(ProgramStyle.allCases, id: \.self) { style in
                            Text(programStyleLabel(style)).tag(style)
                        }
                    }
                    Text(programStyleDescription(draft.programStyle))
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }

                if draft.goalType != .maintain {
                    Section("Pace") {
                        let unit = draft.weightUnit == .pounds ? "lb" : "kg"
                        let display = draft.weightUnit.fromKilograms(draft.rateMagnitudeKgPerWeek)
                        let maxDisplay = draft.weightUnit.fromKilograms(draft.maxRateMagnitudeKgPerWeek)
                        Slider(
                            value: Binding(
                                get: { draft.weightUnit.fromKilograms(draft.rateMagnitudeKgPerWeek) },
                                set: { draft.rateMagnitudeKgPerWeek = draft.weightUnit.toKilograms($0) }
                            ),
                            in: 0...max(0.01, maxDisplay),
                            step: 0.1
                        ) {
                            Text("Pace")
                        }
                        .accessibilityLabel("Weekly pace")
                        Text(paceText(display: display, unit: unit))
                            .font(MFFont.subheadline)
                            .foregroundColor(MFColor.textSecondary)
                    }
                }

                Section("Nutrition") {
                    Picker("Diet plan", selection: $draft.dietPlan) {
                        ForEach(DietPlan.allCases, id: \.self) { plan in
                            Text(dietPlanLabel(plan)).tag(plan)
                        }
                    }
                    HStack {
                        Text("Protein")
                        Spacer()
                        Text(String(format: "%.1f g/kg", draft.proteinGramsPerKg))
                            .foregroundColor(MFColor.textSecondary)
                    }
                    Slider(value: $draft.proteinGramsPerKg, in: 1.0...3.0, step: 0.1) {
                        Text("Protein per kilogram")
                    }
                    .accessibilityLabel("Protein grams per kilogram of body weight")
                }

                Section("Fasting days") {
                    ForEach(1...7, id: \.self) { weekday in
                        Toggle(
                            weekdayName(weekday),
                            isOn: Binding(
                                get: { draft.fastingWeekdays.contains(weekday) },
                                set: { isOn in
                                    if isOn { draft.fastingWeekdays.insert(weekday) }
                                    else { draft.fastingWeekdays.remove(weekday) }
                                }
                            )
                        )
                    }
                    if !draft.fastingWeekdays.isEmpty {
                        HStack {
                            Text("Fasting day calories")
                            Spacer()
                            Text("\(Int((draft.fastingDayCalorieFraction * 100).rounded()))% of normal")
                                .foregroundColor(MFColor.textSecondary)
                        }
                        Slider(value: $draft.fastingDayCalorieFraction, in: 0.1...0.75, step: 0.05) {
                            Text("Fasting day calorie fraction")
                        }
                        .accessibilityLabel("Fasting day calorie fraction")
                    }
                }

                Section("Units") {
                    Picker("Weight unit", selection: $draft.weightUnit) {
                        Text("Kilograms").tag(WeightUnit.kilograms)
                        Text("Pounds").tag(WeightUnit.pounds)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Edit program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func paceText(display: Double, unit: String) -> String {
        let direction = draft.goalType == .cut ? "loss" : "gain"
        return String(format: "About %.1f %@ %@ per week", display, unit, direction)
    }
}
