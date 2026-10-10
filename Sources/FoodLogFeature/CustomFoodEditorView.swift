import SwiftUI
import DesignSystem
import DataLayer

// MARK: - CustomFoodEditorView

/// Create or edit a custom food: name, serving, and nutrition facts.
/// Nutrients are entered per serving and stored per 100 g.
public struct CustomFoodEditorView: View {
    private struct SizeDraft: Identifiable {
        var id: String
        var name: String
        var grams: String
    }
    private let existingFood: FoodItem?
    private let foods: any FoodRepository
    private let onDone: (FoodItem) -> Void

    @State private var name: String
    @State private var brand: String
    @State private var barcode: String
    @State private var servingSizes: [SizeDraft]
    @State private var nutritionBasisGrams: Double
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
        _servingSizes = State(initialValue: (food?.servingSizes ?? [ServingSize(name: "Serving", grams: 100)]).map {
            SizeDraft(id: $0.id, name: $0.name, grams: String($0.grams))
        })
        _nutritionBasisGrams = State(initialValue: food?.servingSizes.first?.grams ?? 100)
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
            && !servingSizes.isEmpty
            && servingSizes.allSatisfy {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && (Double($0.grams).map { $0.isFinite && $0 > 0 && $0 <= 100_000 } ?? false)
            }
            && Set(servingSizes.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }).count == servingSizes.count
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

                Section("Serving sizes") {
                    ForEach($servingSizes) { $size in
                        HStack {
                            TextField("Name, e.g. 1 bowl", text: $size.name)
                                .accessibilityLabel("Serving size name")
                            TextField("Grams", text: Binding(
                                get: { size.grams },
                                set: { value in
                                    let isBasis = servingSizes.first?.id == size.id
                                    size.grams = value
                                    if isBasis { rescaleNutritionBasis(to: value) }
                                }
                            ))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                                .accessibilityLabel("Serving size weight in grams")
                            Text("g").foregroundColor(MFColor.textSecondary)
                            if servingSizes.count > 1 {
                                Button {
                                    let remaining = servingSizes.filter { $0.id != size.id }
                                    if servingSizes.first?.id == size.id, let next = remaining.first {
                                        rescaleNutritionBasis(to: next.grams)
                                    }
                                    servingSizes = remaining
                                } label: { Image(systemName: "minus.circle.fill") }
                                    .accessibilityLabel("Remove \(size.name) serving size")
                            }
                        }
                    }
                    Button("Add serving size") {
                        servingSizes.append(SizeDraft(id: UUID().uuidString, name: "", grams: ""))
                    }
                    Text("Nutrition below is for one unit of the first size. Other sizes use the same nutrition per gram.")
                        .font(MFFont.caption).foregroundColor(MFColor.textSecondary)
                    if !isValid {
                        Text("Enter unique names and positive weights for all serving sizes.")
                            .font(MFFont.caption).foregroundColor(.red)
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

    private func rescaleNutritionBasis(to raw: String) {
        guard let grams = Double(raw),
              grams.isFinite, grams > 0, grams <= 100_000 else { return }
        let factor = grams / nutritionBasisGrams
        func scaled(_ text: String) -> String {
            guard let value = Double(text), value.isFinite else { return text }
            return String(value * factor)
        }
        calories = scaled(calories)
        protein = scaled(protein)
        fat = scaled(fat)
        carbs = scaled(carbs)
        fiber = scaled(fiber)
        sugar = scaled(sugar)
        sodium = scaled(sodium)
        nutritionBasisGrams = grams
    }

    private func save() {
        guard isValid else { return }
        let sizes = servingSizes.map {
            ServingSize(id: $0.id, name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), grams: Double($0.grams)!)
        }
        let grams = sizes[0].grams
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
                existing.servingSizes = sizes
                for (key, value) in nutrients { existing.setPer100g(key, value) }
                try foods.updateFood(existing)
                onDone(existing)
            } else {
                let food = try foods.saveFood(
                    name: name,
                    brand: brand,
                    barcode: barcode.isEmpty ? nil : barcode,
                    servingDescription: sizes[0].name,
                    servingSizeGrams: grams,
                    nutrientsPer100g: nutrients,
                    source: .custom
                )
                food.servingSizes = sizes
                try foods.updateFood(food)
                onDone(food)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
