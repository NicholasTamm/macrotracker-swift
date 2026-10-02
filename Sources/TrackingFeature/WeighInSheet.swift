import SwiftUI
import DesignSystem
import DataLayer
import CoachingEngine

// MARK: - WeighInSheet

/// Log-a-weigh-in sheet. Replaces `WeighInPlaceholderSheet` in AppShell;
/// the `mfclone://weighin` deep link should present this view.
///
/// Value entry respects the user's display unit (storage is always kg);
/// a successful save also logs today's completion on the "Weigh in" habit
/// so streaks stay in sync, and invokes
/// `TrackingEnvironment.onManualWeighIn` so AppShell can write the
/// weigh-in back to HealthKit (issue #9 integration contract).
public struct WeighInSheet: View {
    @Environment(TrackingEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var valueText: String = ""
    @State private var unit: WeightUnit = .pounds
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var error: String?
    @State private var didSeedLatest = false

    /// Called with the saved entry after a successful save.
    public var onSaved: ((WeightEntry) -> Void)?

    public init(onSaved: ((WeightEntry) -> Void)? = nil) {
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("0.0", text: $valueText)
                            .keyboardType(.decimalPad)
                            .font(MFFont.statLarge)
                            .monospacedDigit()
                            .multilineTextAlignment(.leading)
                            .accessibilityLabel("Weight")
                        Spacer()
                        Picker("Unit", selection: $unit) {
                            Text("lb").tag(WeightUnit.pounds)
                            Text("kg").tag(WeightUnit.kilograms)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                        .accessibilityLabel("Weight unit")
                    }
                    DatePicker("Date & time", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                } header: {
                    Text("Weigh in")
                } footer: {
                    if let latest = latestText {
                        Text(latest)
                    }
                }

                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                }

                if let error {
                    Section {
                        MFBanner(kind: .danger, title: "Couldn't save", message: error)
                    }
                }
            }
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .task {
                unit = env.weightUnit
                // Prefill with today's latest weigh-in so repeat entries are quick edits.
                if !didSeedLatest, let latest = try? env.weights.latestWeight() {
                    valueText = String(format: "%.1f", unit.fromKilograms(latest.weightKg))
                    didSeedLatest = true
                }
            }
        }
    }

    private var latestText: String? {
        guard let latest = try? env.weights.latestWeight() else { return nil }
        let formatted = TrackingFormatting.weight(latest.weightKg, unit: unit)
        let when = TrackingFormatting.shortDateTime.string(from: latest.timestamp)
        return "Latest: \(formatted) · \(when)"
    }

    private var canSave: Bool {
        guard let value = Double(valueText.trimmingCharacters(in: .whitespaces)),
              value > 0 else { return false }
        return true
    }

    private func save() {
        error = nil
        guard let value = Double(valueText.trimmingCharacters(in: .whitespaces)), value > 0 else {
            error = "Enter a weight above zero."
            return
        }
        do {
            let entry = try env.weights.logWeight(
                unit.toKilograms(value),
                timestamp: date,
                note: note.isEmpty ? nil : note,
                source: .manual
            )
            env.logTodayCompletion(kind: .weighIn)
            // HealthKit write-back (issue #9): AppShell wires this hook to
            // MFHealthKitStore.shared.writeWeighIn. Manual source only.
            if let hook = env.onManualWeighIn {
                hook(entry.weightKg, entry.timestamp)
            }
            onSaved?(entry)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview("Weigh-in sheet") {
    withPreviewEnvironment { env in
        WeighInSheet()
            .environment(env)
    }
}
