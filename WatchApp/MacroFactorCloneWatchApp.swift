//  MacroFactorCloneWatchApp.swift
//  watchOS companion app (issue #10).
//
//  DROP-IN: this file is NOT part of the Swift package. Add it to the
//  watchOS App target in the Xcode project (see WatchApp/README.md).
//
//  Three pages: Today's macro ring, quick-add logging, weigh-in. All data
//  comes from `MFSharedSnapshot` in the App Group container; all writes go
//  to the iPhone through `MFWatchClient` (WatchConnectivity), which applies
//  them to the DataLayer repositories and republishes the snapshot.

import SwiftUI
import DesignSystem
import EngagementFeature

// MARK: - App entry

@main
struct MacroFactorCloneWatchApp: App {
    @State private var client = MFWatchClient()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(client)
                .task {
                    client.activate()
                }
        }
    }
}

// MARK: - Root

struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchTodayView()
            WatchQuickAddView()
            WatchWeighInView()
        }
    }
}

// MARK: - Today: macro ring

struct WatchTodayView: View {
    @Environment(MFWatchClient.self) private var client

    var body: some View {
        ScrollView {
            if let snapshot = client.snapshot {
                VStack(spacing: 8) {
                    MFMacroRing(
                        caloriesEaten: snapshot.calories,
                        calorieTarget: max(snapshot.targetCalories, 1),
                        macros: [
                            MFMacroRing.Macro(
                                name: "Protein",
                                eaten: snapshot.proteinGrams,
                                target: max(snapshot.targetProteinGrams, 1),
                                kcalPerGram: 4,
                                color: MFColor.protein
                            ),
                            MFMacroRing.Macro(
                                name: "Fat",
                                eaten: snapshot.fatGrams,
                                target: max(snapshot.targetFatGrams, 1),
                                kcalPerGram: 9,
                                color: MFColor.fat
                            ),
                            MFMacroRing.Macro(
                                name: "Carbs",
                                eaten: snapshot.carbsGrams,
                                target: max(snapshot.targetCarbsGrams, 1),
                                kcalPerGram: 4,
                                color: MFColor.carbs
                            ),
                        ],
                        diameter: 128
                    )
                    if snapshot.logStreakDays > 0 {
                        Text("\(snapshot.logStreakDays)-day streak")
                            .font(MFFont.caption)
                            .foregroundColor(MFColor.textSecondary)
                    }
                    if let error = client.lastError {
                        Text(error)
                            .font(MFFont.caption2)
                            .foregroundColor(MFColor.danger)
                    }
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Syncing with iPhone…")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }
            }
        }
        .task {
            client.requestSnapshot()
        }
    }
}

// MARK: - Quick add

struct WatchQuickAddView: View {
    @Environment(MFWatchClient.self) private var client

    @State private var calories: Double = 300
    @State private var protein: Int = 20
    @State private var fat: Int = 10
    @State private var carbs: Int = 30
    @State private var didLog = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text("Calories")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                    Text(MFFormat.kcal(calories))
                        .font(MFFont.statMedium)
                        .foregroundColor(MFColor.calories)
                        .digitalCrownRotation(
                            $calories,
                            from: 0,
                            through: 3000,
                            by: 10,
                            sensitivity: .medium,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true
                        )
                    Text("Turn the crown")
                        .font(MFFont.caption2)
                        .foregroundColor(MFColor.textTertiary)
                }

                macroStepper(label: "Protein", value: $protein, color: MFColor.protein)
                macroStepper(label: "Fat", value: $fat, color: MFColor.fat)
                macroStepper(label: "Carbs", value: $carbs, color: MFColor.carbs)

                Button(didLog ? "Logged ✓" : "Log") {
                    client.sendQuickAdd(
                        calories: calories,
                        proteinGrams: Double(protein),
                        fatGrams: Double(fat),
                        carbsGrams: Double(carbs)
                    )
                    didLog = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        didLog = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(MFColor.buttonPrimary)
                .disabled(didLog)

                if let error = client.lastError {
                    Text(error)
                        .font(MFFont.caption2)
                        .foregroundColor(MFColor.danger)
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Quick Add")
    }

    private func macroStepper(label: String, value: Binding<Int>, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
            Spacer()
            Stepper("\(value.wrappedValue)g", value: value, in: 0...500, step: 5)
                .labelsHidden()
            Text("\(value.wrappedValue)g")
                .font(MFFont.caption)
                .foregroundColor(MFColor.textPrimary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

// MARK: - Weigh in

/// Display unit for the watch weigh-in screen. The snapshot's
/// `weightUnitRaw` ("kilograms"/"pounds") selects the initial unit.
private enum WatchWeightUnit: String, CaseIterable {
    case kilograms = "kg"
    case pounds = "lb"

    static let kgPerPound = 1 / 2.204_622_621_8

    func toKilograms(_ value: Double) -> Double {
        switch self {
        case .kilograms: return value
        case .pounds: return value * Self.kgPerPound
        }
    }

    func fromKilograms(_ kg: Double) -> Double {
        switch self {
        case .kilograms: return kg
        case .pounds: return kg / Self.kgPerPound
        }
    }
}

struct WatchWeighInView: View {
    @Environment(MFWatchClient.self) private var client

    @State private var unit: WatchWeightUnit = .kilograms
    @State private var weight: Double = 75
    @State private var didSave = false
    @State private var didInitFromSnapshot = false

    private var range: ClosedRange<Double> {
        unit == .kilograms ? 30...250 : 66...550
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Picker("Unit", selection: $unit) {
                    ForEach(WatchWeightUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: unit) { _, newUnit in
                    // Keep the same physical weight across unit switches.
                    weight = newUnit.fromKilograms(unit.toKilograms(weight))
                }

                VStack(spacing: 2) {
                    Text(String(format: "%.1f %@", weight, unit.rawValue))
                        .font(MFFont.statMedium)
                        .foregroundColor(MFColor.weightTrend)
                        .digitalCrownRotation(
                            $weight,
                            from: range.lowerBound,
                            through: range.upperBound,
                            by: unit == .kilograms ? 0.1 : 0.2,
                            sensitivity: .medium,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true
                        )
                    Text("Turn the crown")
                        .font(MFFont.caption2)
                        .foregroundColor(MFColor.textTertiary)
                }

                Button(didSave ? "Saved ✓" : "Save Weigh-in") {
                    client.sendWeighIn(weightKg: unit.toKilograms(weight))
                    didSave = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        didSave = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(MFColor.buttonPrimary)
                .disabled(didSave)

                if let error = client.lastError {
                    Text(error)
                        .font(MFFont.caption2)
                        .foregroundColor(MFColor.danger)
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Weigh In")
        .onAppear {
            guard !didInitFromSnapshot, let snapshot = client.snapshot else { return }
            didInitFromSnapshot = true
            unit = snapshot.weightUnitRaw == "pounds" ? .pounds : .kilograms
            if let latestKg = snapshot.latestWeightKg {
                weight = unit.fromKilograms(latestKg)
            }
        }
    }
}
