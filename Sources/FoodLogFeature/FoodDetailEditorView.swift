import SwiftUI
import DesignSystem
import DataLayer

// MARK: - FoodDetailEditorView

/// Serving editor for logging a food (or editing an existing entry):
/// named serving-size picker, typed quantity, meal assignment,
/// timestamp, note, and a live macro preview.
///
/// Two modes:
/// - Log mode (`init(food:…)`): "Log food" + "Add to plate".
/// - Edit mode (`init(entry:…)`): "Save", "Copy", "Delete".
public struct FoodDetailEditorView: View {
    private enum Mode {
        case log(food: FoodItem, onLog: (ServingSelection, MealSlot, Date, String?) -> Void, onAddToPlate: (Double, MealSlot, String?) -> Void)
        case edit(entry: LogEntry, onSave: (ServingSelection?, MealSlot, Date, String?) -> Void, onDelete: () -> Void, onCopy: () -> Void)
    }

    private let preservedSelection: ServingSelection?
    private let preservedSizeID: String?
    private let mode: Mode
    private let foodName: String
    private let brand: String
    private let iconHex: String?
    @State private var quantityText: String
    @State private var selectedSizeID: String
    @State private var mealSlot: MealSlot
    @State private var date: Date
    @State private var note: String
    @FocusState private var amountFocused: Bool
    @Environment(\.dismiss) private var dismiss

    // MARK: Log mode

    public init(
        food: FoodItem,
        initialGrams: Double,
        defaultMealSlot: MealSlot = .other,
        defaultDate: Date = Date(),
        onLog: @escaping (ServingSelection, MealSlot, Date, String?) -> Void,
        onAddToPlate: @escaping (Double, MealSlot, String?) -> Void
    ) {
        self.preservedSelection = nil
        self.preservedSizeID = nil
        self.mode = .log(food: food, onLog: onLog, onAddToPlate: onAddToPlate)
        self.foodName = food.displayName
        self.brand = food.brand
        self.iconHex = MFFoodIconMapper.hex(forName: food.name)
        let primary = food.servingSizes[0]
        _quantityText = State(initialValue: Self.quantityString(initialGrams / primary.grams))
        _selectedSizeID = State(initialValue: primary.id)
        _mealSlot = State(initialValue: defaultMealSlot)
        _date = State(initialValue: defaultDate)
        _note = State(initialValue: "")
    }

    // MARK: Edit mode

    public init(
        entry: LogEntry,
        onSave: @escaping (ServingSelection?, MealSlot, Date, String?) -> Void,
        onDelete: @escaping () -> Void,
        onCopy: @escaping () -> Void
    ) {
        self.mode = .edit(entry: entry, onSave: onSave, onDelete: onDelete, onCopy: onCopy)
        self.foodName = entry.foodName
        self.brand = entry.food?.brand ?? ""
        self.iconHex = MFFoodIconMapper.hex(forName: entry.foodName)
        let saved = entry.servingSelection
        let primary = entry.food?.servingSizes.first
        let matchingSavedSize = saved.flatMap { selection in
            entry.food?.servingSizes.first {
                $0.name == selection.name && abs($0.grams - selection.gramsPerUnit) < 0.000001
            }
        }
        let exactPrimary = primary.map { abs((entry.grams / $0.grams * 100).rounded() / 100 - entry.grams / $0.grams) < 0.000001 } ?? false
        let chosen = saved ?? (exactPrimary ? ServingSelection(name: primary!.name, gramsPerUnit: primary!.grams, quantity: entry.grams / primary!.grams) : ServingSelection(name: "Gram", gramsPerUnit: 1, quantity: entry.grams))
        let sizeID = saved != nil ? (matchingSavedSize?.id ?? "saved") : (exactPrimary ? primary!.id : "gram")
        self.preservedSelection = chosen
        self.preservedSizeID = sizeID
        _quantityText = State(initialValue: Self.exactQuantityString(chosen.quantity))
        _selectedSizeID = State(initialValue: sizeID)
        _mealSlot = State(initialValue: entry.mealSlot)
        _date = State(initialValue: entry.timestamp)
        _note = State(initialValue: entry.note ?? "")
    }

    private static func exactQuantityString(_ amount: Double) -> String {
        amount.rounded() == amount && amount < Double(Int.max) ? String(Int(amount)) : String(amount)
    }

    private var unchangedSelection: ServingSelection? {
        guard let preservedSelection, selectedSizeID == preservedSizeID,
              quantityText == Self.exactQuantityString(preservedSelection.quantity) else { return nil }
        return preservedSelection
    }

    private static func quantityString(_ amount: Double) -> String {
        String(format: "%.2f", amount).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }

    // MARK: Derived

    private var availableSizes: [ServingSize] {
        let catalog: [ServingSize]
        switch mode {
        case .log(let food, _, _): catalog = food.servingSizes
        case .edit(let entry, _, _, _): catalog = entry.food?.servingSizes ?? []
        }
        var sizes = catalog
        if case .edit(let entry, _, _, _) = mode, let saved = entry.servingSelection,
           !catalog.contains(where: { $0.name == saved.name && abs($0.grams - saved.gramsPerUnit) < 0.000001 }) {
            sizes.insert(ServingSize(id: "saved", name: saved.name, grams: saved.gramsPerUnit), at: 0)
        }
        sizes.append(ServingSize(id: "gram", name: "Gram", grams: 1))
        return sizes
    }

    private var selectedSize: ServingSize {
        availableSizes.first(where: { $0.id == selectedSizeID }) ?? availableSizes[0]
    }

    private var quantityError: String? {
        if unchangedSelection != nil { return nil }
        do {
            _ = try ServingAmount.parse(quantityText, gramsPerUnit: selectedSize.grams)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private var selection: ServingSelection? {
        if let unchangedSelection { return unchangedSelection }
        guard let quantity = try? ServingAmount.parse(quantityText, gramsPerUnit: selectedSize.grams) else { return nil }
        return ServingSelection(name: selectedSize.name, gramsPerUnit: selectedSize.grams, quantity: quantity)
    }

    private var grams: Double { selection?.totalGrams ?? 0 }

    private func adjustQuantity(by step: Double) {
        let current = Double(quantityText.replacingOccurrences(of: ",", with: ".")) ?? 0
        quantityText = Self.quantityString(max(0, min(1000, current + step)))
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
            // Match repository portion edits by scaling the historical snapshot.
            let factor = entry.grams > 0 ? grams / entry.grams : 1
            var out: [NutrientKey: Double] = [:]
            for key in NutrientKey.allCases { out[key] = entry.snapshot(key) * factor }
            return out
        }
    }

    // MARK: Body

    private var isWeightlessQuickAdd: Bool {
        if case .edit(let entry, _, _, _) = mode { return entry.food == nil && entry.grams == 0 }
        return false
    }

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

                if !isWeightlessQuickAdd { Section("Amount") {
                    Picker("Serving size", selection: $selectedSizeID) {
                        ForEach(availableSizes) { size in
                            Text("\(size.name) (\(MFFormat.grams(size.grams)) g)").tag(size.id)
                        }
                    }
                    .accessibilityIdentifier("servingSizePicker")

                    HStack {
                        Text("Amount")
                            .font(MFFont.body)
                            .foregroundColor(MFColor.textPrimary)
                        Spacer()
                        TextField("1.5", text: $quantityText)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(width: 90)
                            .accessibilityLabel("Serving amount")
                            .accessibilityIdentifier("servingAmountField")
                        Button("−") { adjustQuantity(by: -0.5) }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Decrease amount")
                        Button("+") { adjustQuantity(by: 0.5) }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Increase amount")
                    }

                    if let quantityError {
                        Text(quantityError).font(MFFont.caption).foregroundColor(.red)
                            .accessibilityIdentifier("servingAmountError")
                    }

                    Text("Changing size keeps the typed count and recalculates weight.")
                        .font(MFFont.caption).foregroundColor(MFColor.textSecondary)

                    HStack {
                        Text("Weight")
                            .font(MFFont.body)
                            .foregroundColor(MFColor.textPrimary)
                        Spacer()
                        Text(selection.map { "\(MFFormat.grams($0.totalGrams)) g" } ?? "—")
                            .font(MFFont.bodyBold)
                            .monospacedDigit()
                            .foregroundColor(MFColor.textPrimary)
                    }
                } }

                Section("Details") {
                    Picker("Meal", selection: $mealSlot) {
                        ForEach(MealSlot.allCases, id: \.self) { slot in
                            Text(slot.displayName).tag(slot)
                        }
                    }
                    DatePicker("Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    TextField("Note (optional)", text: $note, axis: .vertical)
                }

                if selection != nil || isWeightlessQuickAdd { Section("Nutrition") {
                    macroPreviewRow(name: "Calories", value: nutrients[.calories] ?? 0, unit: "kcal", color: MFColor.calories)
                    macroPreviewRow(name: "Protein", value: nutrients[.protein] ?? 0, unit: "g", color: MFColor.protein)
                    macroPreviewRow(name: "Fat", value: nutrients[.fat] ?? 0, unit: "g", color: MFColor.fat)
                    macroPreviewRow(name: "Carbs", value: nutrients[.carbs] ?? 0, unit: "g", color: MFColor.carbs)
                } }

                actionsSection
            }
            .navigationTitle(isEditMode ? "Edit entry" : "Log food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountFocused = false }
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
                    if let selection { onLog(selection, mealSlot, date, note.isEmpty ? nil : note) }
                }
                .disabled(selection == nil)
                .accessibilityIdentifier("logFoodButton")
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                MFButton("Add to plate", style: .secondary, size: .large) {
                    if selection != nil { onAddToPlate(grams, mealSlot, note.isEmpty ? nil : note) }
                }
                .disabled(selection == nil)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            case .edit(_, let onSave, let onDelete, let onCopy):
                MFButton("Save changes", style: .primary, size: .large) {
                    if selection != nil || isWeightlessQuickAdd {
                        onSave(unchangedSelection != nil ? nil : selection, mealSlot, date, note.isEmpty ? nil : note)
                    }
                }
                .disabled(selection == nil && !isWeightlessQuickAdd)
                .accessibilityIdentifier("saveFoodChangesButton")
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

#Preview("Food detail editor") {
    Text("FoodDetailEditorView preview needs a FoodItem; see FoodLogRootView.")
}
