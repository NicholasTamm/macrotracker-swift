//  ManualTargetsSheet.swift
//  StrategyFeature — direct target editing for manual-style programs.
//  Writes straight to the stored targets; the engine stays advisory.

import SwiftUI
import DesignSystem
import CoachingEngine

/// Sheet for hand-editing calorie + macro targets (manual program style).
public struct ManualTargetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var calories: Double
    @State private var protein: Double
    @State private var fat: Double
    @State private var carbs: Double
    private let onSave: (MacroTargets) -> Void

    public init(current: MacroTargets, onSave: @escaping (MacroTargets) -> Void) {
        _calories = State(initialValue: current.calories)
        _protein = State(initialValue: current.proteinGrams)
        _fat = State(initialValue: current.fatGrams)
        _carbs = State(initialValue: current.carbsGrams)
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Daily targets") {
                    targetField(label: "Calories", value: $calories, unit: "cal")
                    targetField(label: "Protein", value: $protein, unit: "g")
                    targetField(label: "Fat", value: $fat, unit: "g")
                    targetField(label: "Carbs", value: $carbs, unit: "g")
                }
                Section {
                    Text("Coaching stays advisory on a manual program — these are the numbers your food log measures against.")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }
            }
            .navigationTitle("Edit targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(MacroTargets(
                            calories: calories,
                            proteinGrams: protein,
                            fatGrams: fat,
                            carbsGrams: carbs
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func targetField(label: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(
                "0",
                value: value,
                format: .number.precision(.fractionLength(0))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 90)
            .accessibilityLabel("\(label) target")
            Text(unit)
                .foregroundColor(MFColor.textSecondary)
        }
    }
}
