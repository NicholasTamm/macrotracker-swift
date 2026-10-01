import SwiftUI
import DesignSystem
import DataLayer

// MARK: - FoodDetailEditorView

/// Serving editor for logging a food (or editing an existing entry):
/// amount stepper, metric/imperial/serving unit picker, meal assignment,
/// timestamp, note, and a live macro preview.
///
/// Two modes:
/// - Log mode (`init(food:…)`): "Log food" + "Add to plate".
/// - Edit mode (`init(entry:…)`): "Save", "Copy", "Delete".
public struct FoodDetailEditorView: View {
    private enum Mode {
        case log(food: FoodItem, onLog: (Double, MealSlot, Date, String?) -> Void, onAddToPlate: (Double, MealSlot, String?) -> Void)
        case edit(entry: LogEntry, onSave: (Double, MealSlot, Date, String?) -> Void, onDelete: () -> Void, onCopy: () -> Void)
    }

    private let mode: Mode
    private let foodName: String
    private let brand: String
    private let iconHex: String?
    private let baseGrams: Double

    @State private var amount: Double
    @State private var unit: ServingUnit
    @State private var mealSlot: MealSlot
    @State private var date: Date
    @State private var note: String
    @Environment(\.dismiss) private var dismiss

    // MARK: Log mode

    public init(
        food: FoodItem,
        initialGrams: Double,
        defaultMealSlot: MealSlot = .other,
        defaultDate: Date = Date(),
        onLog: @escaping (Double, MealSlot, Date, String?) -> Void,
        onAddToPlate: @escaping (Double, MealSlot, String?) -> Void
    ) {
        self.mode = .log(food: food, onLog: onLog, onAddToPlate: onAddToPlate)
        self.foodName = food.displayName
        self.brand = food.brand
        self.iconHex = MFFoodIconMapper.hex(forName: food.name)
        self.baseGrams = initialGrams
        _amount = State(initialValue: FoodDetailEditorView.defaultAmount(for: initialGrams, food: food))
        _unit = State(initialValue: .serving)
        _mealSlot = State(initialValue: defaultMealSlot)
        _date = State(initialValue: defaultDate)
        _note = State(initialValue: "")
    }

    // MARK: Edit mode

    public init(
        entry: LogEntry,
        onSave: @escaping (Double, MealSlot, Date, String?) -> Void,
        onDelete: @escaping () -> Void,
        onCopy: @escaping () -> Void
    ) {
        self.mode = .edit(entry: entry, onSave: onSave, onDelete: onDelete, onCopy: onCopy)
        self.foodName = entry.foodName
        self.brand = entry.food?.brand ?? ""
        self.iconHex = MFFoodIconMapper.hex(forName: entry.foodName)
        self.baseGrams = entry.grams
        _amount = State(initialValue: entry.grams > 0 ? entry.grams : 1)
        _unit = State(initialValue: entry.grams > 0 ? .grams : .serving)
        _mealSlot = State(initialValue: entry.mealSlot)
        _date = State(initialValue: entry.timestamp)
        _note = State(initialValue: entry.note ?? "")
    }

    private static func defaultAmount(for grams: Double, food: FoodItem) -> Double {
        guard food.servingSizeGrams > 0 else { return 1 }
        let servings = grams / food.servingSizeGrams
        return max(servings, 0.25)
    }

    // MARK: Derived

    private var grams: Double {
        switch unit {
        case .serving: return amount * servingGrams
        case .grams: return amount
        case .ounces: return amount * 28.3495
        }
    }

    private var servingGrams: Double {
        switch mode {
        case .log(let food, _, _): return max(food.servingSizeGrams, 1)
        case .edit(let entry, _, _, _): return max(entry.food?.servingSizeGrams ?? 100, 1)
        }
    }

    private var servingDescription: String {
        switch mode {
        case .log(let food, _, _): return food.servingDescription
        case .edit(let entry, _, _, _): return entry.food?.servingDescription ?? ""
        }
    }

    private var nutrients: [NutrientKey: Double] {
        switch mode {
        case .log(let food, _, _): return food.scaledNutrients(grams: grams)
        case .edit(let entry, _, _, _):
            if let food = entry.food { return food.scaledNutrients(grams: grams) }
            // Foodless entry (quick add): scale the stored snapshot.
            let factor = entry.grams > 0 ? grams / entry.grams : 0
            var out: [NutrientKey: Double] = [:]
            for key in NutrientKey.allCases { out[key] = entry.snapshot(key) * factor }
            return out
        }
    }

    // MARK: Body

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: MFSpacing.md) {
                        MFFoodIcon(openmojiHex: iconHex)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(foodName)
                                .font(MFFont.headline)
                                .foregroundColor(MFColor.textPrimary)
                            if !servingDescription.isEmpty {
                                Text(servingDescription)
                                    .font(MFFont.caption)
                                    .foregroundColor(MFColor.textSecondary)
                            }
                        }
                    }
                    .padding(.vertical, MFSpacing.xs)
                }

                Section("Amount") {
                    Picker("Unit", selection: $unit) {
                        ForEach(ServingUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text(unit == .serving ? "Servings" : "Amount")
                            .font(MFFont.body)
                            .foregroundColor(MFColor.textPrimary)
                        Spacer()
                        MFStepper(
                            value: $amount,
                            step: unit == .serving ? 0.5 : 10,
                            range: 0...10000,
                            unit: unit.shortName,
                            label: "Amount"
                        )
                    }

                    HStack {
                        Text("Weight")
                            .font(MFFont.body)
                            .foregroundColor(MFColor.textPrimary)
                        Spacer()
                        Text("\(MFFormat.grams(grams)) g")
                            .font(MFFont.bodyBold)
                            .monospacedDigit()
                            .foregroundColor(MFColor.textPrimary)
                    }
                }

                Section("Details") {
                    Picker("Meal", selection: $mealSlot) {
                        ForEach(MealSlot.allCases, id: \.self) { slot in
                            Text(slot.displayName).tag(slot)
                        }
                    }
                    DatePicker("Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    TextField("Note (optional)", text: $note, axis: .vertical)
                }

                Section("Nutrition") {
                    macroPreviewRow(name: "Calories", value: nutrients[.calories] ?? 0, unit: "kcal", color: MFColor.calories)
                    macroPreviewRow(name: "Protein", value: nutrients[.protein] ?? 0, unit: "g", color: MFColor.protein)
                    macroPreviewRow(name: "Fat", value: nutrients[.fat] ?? 0, unit: "g", color: MFColor.fat)
                    macroPreviewRow(name: "Carbs", value: nutrients[.carbs] ?? 0, unit: "g", color: MFColor.carbs)
                }

                actionsSection
            }
            .navigationTitle(isEditMode ? "Edit entry" : "Log food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func macroPreviewRow(name: String, value: Double, unit: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10).accessibilityHidden(true)
            Text(name)
                .font(MFFont.body)
                .foregroundColor(MFColor.textPrimary)
            Spacer()
            Text("\(MFFormat.grams(value)) \(unit)")
                .font(MFFont.body)
                .monospacedDigit()
                .foregroundColor(MFColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(MFFormat.grams(value)) \(unit)")
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            switch mode {
            case .log(_, let onLog, let onAddToPlate):
                MFButton("Log food", style: .primary, size: .large) {
                    onLog(grams, mealSlot, date, note.isEmpty ? nil : note)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                MFButton("Add to plate", style: .secondary, size: .large) {
                    onAddToPlate(grams, mealSlot, note.isEmpty ? nil : note)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            case .edit(_, let onSave, let onDelete, let onCopy):
                MFButton("Save changes", style: .primary, size: .large) {
                    onSave(grams, mealSlot, date, note.isEmpty ? nil : note)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                HStack(spacing: MFSpacing.md) {
                    MFButton("Copy", style: .secondary, size: .medium, action: onCopy)
                    MFButton("Delete", style: .destructive, size: .medium, action: onDelete)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
    }
}

// MARK: - ServingUnit

/// Amount entry unit: the food's serving, metric grams, or imperial ounces.
public enum ServingUnit: CaseIterable, Hashable {
    case serving
    case grams
    case ounces

    public var displayName: String {
        switch self {
        case .serving: return "Serving"
        case .grams: return "Grams"
        case .ounces: return "Ounces"
        }
    }

    public var shortName: String {
        switch self {
        case .serving: return "srv"
        case .grams: return "g"
        case .ounces: return "oz"
        }
    }
}

#Preview("Food detail editor") {
    Text("FoodDetailEditorView preview needs a FoodItem; see FoodLogRootView.")
}
