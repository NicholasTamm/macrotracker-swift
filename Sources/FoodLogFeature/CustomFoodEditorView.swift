import SwiftUI
import DesignSystem
import DataLayer

// MARK: - CustomFoodEditorView

/// Create or edit a custom food: name, serving, and nutrition facts.
/// Nutrients are entered per serving and stored per 100 g.
public struct CustomFoodEditorView: View {
    private let existingFood: FoodItem?
    private let foods: any FoodRepository
    private let onDone: (FoodItem) -> Void

    @State private var name: String
    @State private var brand: String
    @State private var barcode: String
    @State private var servingDescription: String
    @State private var servingGrams: String
    @State private var calories: String
    @State private var protein: String
    @State private var fat: String
    @State private var carbs: String
    @State private var fiber: String
    @State private var sugar: String
    @State private var sodium: String
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    public init(
        food: FoodItem?,
        foods: any FoodRepository,
        onDone: @escaping (FoodItem) -> Void
    ) {
        self.existingFood = food
        self.foods = foods
        self.onDone = onDone
        let serving = food.map { $0.nutrientsPerServing() } ?? [:]
        _name = State(initialValue: food?.name ?? "")
        _brand = State(initialValue: food?.brand ?? "")
        _barcode = State(initialValue: food?.barcode ?? "")
        _servingDescription = State(initialValue: food?.servingDescription ?? "")
        _servingGrams = State(initialValue: food.map { MFFormat.grams($0.servingSizeGrams) } ?? "100")
        _calories = State(initialValue: Self.text(serving[.calories]))
        _protein = State(initialValue: Self.text(serving[.protein]))
        _fat = State(initialValue: Self.text(serving[.fat]))
        _carbs = State(initialValue: Self.text(serving[.carbs]))
        _fiber = State(initialValue: Self.text(serving[.fiber]))
        _sugar = State(initialValue: Self.text(serving[.sugar]))
        _sodium = State(initialValue: Self.text(serving[.sodium]))
    }

    private static func text(_ value: Double?) -> String {
        guard let value, value > 0 else { return "" }
        return MFFormat.grams(value)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Double(servingGrams) ?? 0) > 0
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Food") {
                    MFTextField("Name", placeholder: "e.g. Overnight oats", text: $name)
                    MFTextField("Brand", placeholder: "e.g. Homemade (optional)", text: $brand)
                    MFTextField("Barcode", placeholder: "e.g. 012345678905 (optional)", text: $barcode)
                        .keyboardType(.numberPad)
                }

                Section("Serving") {
                    MFTextField("Serving description", placeholder: "e.g. 1 bowl", text: $servingDescription)
                    HStack {
                        Text("Serving weight")
                            .font(MFFont.body)
                            .foregroundColor(MFColor.textPrimary)
                        Spacer()
                        TextField("100", text: $servingGrams)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(MFFont.bodyBold)
                            .monospacedDigit()
                            .frame(width: 80)
                            .accessibilityLabel("Serving weight in grams")
                        Text("g")
                            .font(MFFont.caption)
                            .foregroundColor(MFColor.textSecondary)
                    }
                }

                Section("Nutrition per serving") {
                    nutrientField(title: "Calories", text: $calories, unit: "kcal", color: MFColor.calories)
                    nutrientField(title: "Protein", text: $protein, unit: "g", color: MFColor.protein)
                    nutrientField(title: "Fat", text: $fat, unit: "g", color: MFColor.fat)
                    nutrientField(title: "Carbs", text: $carbs, unit: "g", color: MFColor.carbs)
                    nutrientField(title: "Fiber", text: $fiber, unit: "g", color: MFColor.carbs)
                    nutrientField(title: "Sugar", text: $sugar, unit: "g", color: MFColor.carbs)
                    nutrientField(title: "Sodium", text: $sodium, unit: "mg", color: MFColor.micro)
                }

                Section {
                    MFButton(
                        existingFood == nil ? "Save custom food" : "Save changes",
                        style: .primary,
                        size: .large,
                        action: save
                    )
                    .disabled(!isValid)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(existingFood == nil ? "Custom food" : "Edit food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Couldn't save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
        }
    }

    private func nutrientField(title: String, text: Binding<String>, unit: String, color: Color) -> some View {
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
                .accessibilityLabel("\(title) per serving in \(unit)")
            Text(unit)
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
                .frame(width: 30, alignment: .leading)
        }
    }

    private func save() {
        let grams = Double(servingGrams) ?? 0
        guard grams > 0 else { return }
        // Per-serving → per-100-g.
        let factor = 100.0 / grams
        func val(_ text: String) -> Double { max(Double(text) ?? 0, 0) }
        let nutrients: [NutrientKey: Double] = [
            .calories: val(calories) * factor,
            .protein: val(protein) * factor,
            .fat: val(fat) * factor,
            .carbs: val(carbs) * factor,
            .fiber: val(fiber) * factor,
            .sugar: val(sugar) * factor,
            .sodium: val(sodium) * factor,
        ]
        do {
            if let existing = existingFood {
                existing.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                existing.brand = brand
                existing.barcode = barcode.isEmpty ? nil : barcode
                existing.servingDescription = servingDescription
                existing.servingSizeGrams = grams
                for (key, value) in nutrients { existing.setPer100g(key, value) }
                try foods.updateFood(existing)
                onDone(existing)
            } else {
                let food = try foods.saveFood(
                    name: name,
                    brand: brand,
                    barcode: barcode.isEmpty ? nil : barcode,
                    servingDescription: servingDescription,
                    servingSizeGrams: grams,
                    nutrientsPer100g: nutrients,
                    source: .custom
                )
                onDone(food)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
