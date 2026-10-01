import SwiftUI
import DesignSystem
import DataLayer

// MARK: - QuickAddView

/// Quick-add: calories and macros by hand, no food record.
public struct QuickAddView: View {
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var carbs: String = ""
    @State private var mealSlot: MealSlot = .snack
    @State private var showsError = false
    @Environment(\.dismiss) private var dismiss

    private let onLog: (Double, Double, Double, Double, MealSlot) -> Void

    public init(onLog: @escaping (Double, Double, Double, Double, MealSlot) -> Void) {
        self.onLog = onLog
    }

    private var parsed: (calories: Double, protein: Double, fat: Double, carbs: Double)? {
        guard let kcal = Double(calories), kcal >= 0 else { return nil }
        let p = Double(protein) ?? 0
        let f = Double(fat) ?? 0
        let c = Double(carbs) ?? 0
        guard p >= 0, f >= 0, c >= 0 else { return nil }
        return (kcal, p, f, c)
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    macroField(title: "Calories", text: $calories, color: MFColor.calories, unit: "kcal")
                    macroField(title: "Protein", text: $protein, color: MFColor.protein, unit: "g")
                    macroField(title: "Fat", text: $fat, color: MFColor.fat, unit: "g")
                    macroField(title: "Carbs", text: $carbs, color: MFColor.carbs, unit: "g")
                } header: {
                    Text("Enter what you ate — numbers only, no food needed.")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                        .textCase(nil)
                }

                Section("Meal") {
                    Picker("Meal", selection: $mealSlot) {
                        ForEach(MealSlot.allCases, id: \.self) { slot in
                            Text(slot.displayName).tag(slot)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    MFButton("Log quick add", style: .primary, size: .large) {
                        guard let values = parsed else {
                            showsError = true
                            return
                        }
                        onLog(values.calories, values.protein, values.fat, values.carbs, mealSlot)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Quick add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Check your numbers", isPresented: $showsError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enter a calories value of 0 or more. Macros are optional.")
            }
        }
    }

    private func macroField(title: String, text: Binding<String>, color: Color, unit: String) -> some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10).accessibilityHidden(true)
            Text(title)
                .font(MFFont.body)
                .foregroundColor(MFColor.textPrimary)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(MFFont.bodyBold)
                .monospacedDigit()
                .frame(width: 90)
                .accessibilityLabel("\(title) in \(unit)")
            Text(unit)
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
                .frame(width: 28, alignment: .leading)
        }
    }
}

#Preview("Quick add") {
    QuickAddView { _, _, _, _, _ in }
        .mfThemed()
}
