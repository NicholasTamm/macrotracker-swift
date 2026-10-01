import SwiftUI
import UIKit
import DataLayer
import DesignSystem

// MARK: - CookbookPhotoParser

/// Picks ingredient-like lines out of cookbook-page OCR: lines that start
/// with a quantity after stripping bullets.
public enum CookbookPhotoParser {
    public static func ingredientLines(from ocrLines: [String]) -> [String] {
        let bullets = CharacterSet(charactersIn: "•-*–—·")
        return ocrLines
            .map { line in
                line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: bullets)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { line in
                guard !line.isEmpty else { return false }
                return line.first?.isNumber ?? false
            }
    }
}

// MARK: - RecipeDraft

public struct RecipeDraftIngredient: Identifiable, Equatable {
    public var id: UUID
    public var line: String
    public var grams: Double
    /// Display name of the matched food, if any.
    public var matchedName: String?

    public init(id: UUID = UUID(), line: String, grams: Double, matchedName: String? = nil) {
        self.id = id
        self.line = line
        self.grams = grams
        self.matchedName = matchedName
    }
}

public struct RecipeDraft: Equatable {
    public var name: String
    public var servings: Double
    public var ingredients: [RecipeDraftIngredient]
    /// Where the recipe came from ("example.com", "Cookbook photo").
    public var sourceDescription: String?

    public init(
        name: String = "",
        servings: Double = 1,
        ingredients: [RecipeDraftIngredient] = [],
        sourceDescription: String? = nil
    ) {
        self.name = name
        self.servings = servings
        self.ingredients = ingredients
        self.sourceDescription = sourceDescription
    }

    public static func from(lines: [String], name: String, servings: Double, sourceDescription: String?) -> RecipeDraft {
        RecipeDraft(
            name: name,
            servings: servings,
            ingredients: lines.map { line in
                RecipeDraftIngredient(
                    line: line,
                    grams: QuantityParser.grams(from: line) ?? 100
                )
            },
            sourceDescription: sourceDescription
        )
    }
}

// MARK: - RecipeImportFlowView

/// Recipe import from a URL (schema.org JSON-LD) or a cookbook photo
/// (OCR → ingredient lines). Both land in `RecipeDraftEditorView`: the user
/// matches each ingredient to a database food, then saves a real recipe
/// (`FoodRepository.createRecipe`, source `.recipe`) and logs a serving.
public struct RecipeImportFlowView: View {
    public enum Focus: Hashable {
        case url
        case cookbook
    }

    private let deps: CaptureDependencies
    private let entrySourceForURL: EntrySource = .urlImport
    private let entrySourceForPhoto: EntrySource = .photo

    @State private var focus: Focus
    @State private var urlText = ""
    @State private var isImporting = false
    @State private var isRecognizing = false
    @State private var pickerSource: PickerSource?
    @State private var capturedImage: UIImage?
    @State private var draft: RecipeDraft?
    @State private var draftEntrySource: EntrySource = .urlImport
    @State private var errorMessage: String?
    @StateObject private var permissions = MFPermissionCenter()

    private struct PickerSource: Identifiable {
        let id = UUID()
        let value: MFImagePicker.Source
    }

    public init(deps: CaptureDependencies, focus: Focus = .url) {
        self.deps = deps
        self._focus = State(initialValue: focus)
    }

    public var body: some View {
        Group {
            if draft != nil {
                RecipeDraftEditorView(
                    draft: Binding(get: { draft ?? RecipeDraft() }, set: { draft = $0 }),
                    deps: deps,
                    entrySource: draftEntrySource,
                    onDone: reset
                )
            } else {
                inputView
            }
        }
        .navigationTitle("Import recipe")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pickerSource) { source in
            MFImagePicker(
                source: source.value,
                onPick: { image in
                    pickerSource = nil
                    recognizeCookbook(image)
                },
                onCancel: { pickerSource = nil }
            )
        }
    }

    // MARK: Input

    private var inputView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MFSpacing.lg) {
                if let errorMessage {
                    MFBanner(kind: .danger, title: "Couldn't import", message: errorMessage)
                }
                MFSegmentedControl(
                    options: [Focus.url, Focus.cookbook],
                    selection: $focus
                ) { $0 == .url ? "From link" : "Cookbook photo" }

                if focus == .url {
                    urlSection
                } else {
                    cookbookSection
                }
            }
            .padding(MFSpacing.lg)
        }
        .background(MFColor.background)
        .onAppear { permissions.refresh() }
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: MFSpacing.md) {
            MFEmptyState(
                icon: "book.pages",
                title: "Paste a recipe link",
                message: "We read the page's recipe data and pull out the ingredient list. You'll match each ingredient before saving."
            )
            MFTextField(
                "Recipe URL",
                placeholder: "https://example.com/recipe",
                text: $urlText,
                icon: "link",
                keyboard: .url
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            MFButton("Import recipe", style: .primary, icon: "arrow.down.circle", isLoading: isImporting) {
                importFromURL()
            }
            .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
        }
    }

    private var cookbookSection: some View {
        MFPermissionGate(
            state: permissions.camera,
            icon: "book.pages",
            title: "Camera access needed",
            message: "Allow camera access to photograph cookbook pages.",
            requestTitle: "Allow camera",
            onRequest: { Task { await permissions.requestCamera() } }
        ) {
            VStack(alignment: .leading, spacing: MFSpacing.md) {
                MFEmptyState(
                    icon: "book.pages",
                    title: "Photograph the recipe",
                    message: "Capture the ingredient list page. Lines starting with a quantity become ingredients you can match."
                )
                if MFImagePicker.Source.isCameraAvailable {
                    MFButton("Take photo", style: .primary, icon: "camera") {
                        pickerSource = PickerSource(value: .camera)
                    }
                }
                MFButton(
                    "Choose from library",
                    style: MFImagePicker.Source.isCameraAvailable ? .secondary : .primary,
                    size: .medium,
                    icon: "photo"
                ) {
                    pickerSource = PickerSource(value: .library)
                }
                if isRecognizing {
                    HStack(spacing: MFSpacing.sm) {
                        ProgressView()
                        Text("Reading the page…")
                            .font(MFFont.subheadline)
                            .foregroundColor(MFColor.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func importFromURL() {
        let raw = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: raw), components.host != nil || !raw.isEmpty else {
            errorMessage = RecipeImportError.invalidURL.localizedDescription
            return
        }
        if components.scheme == nil { components.scheme = "https" }
        guard let url = components.url else {
            errorMessage = RecipeImportError.invalidURL.localizedDescription
            return
        }
        errorMessage = nil
        isImporting = true
        Task {
            do {
                let imported = try await RecipeURLParser.importFrom(url: url)
                await MainActor.run {
                    draftEntrySource = entrySourceForURL
                    draft = RecipeDraft.from(
                        lines: imported.ingredientLines,
                        name: imported.name,
                        servings: imported.servings,
                        sourceDescription: url.host
                    )
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }

    private func recognizeCookbook(_ image: UIImage) {
        capturedImage = image
        errorMessage = nil
        isRecognizing = true
        Task {
            do {
                let lines = try await MFVisionOCR.recognizeText(in: image)
                let ingredients = CookbookPhotoParser.ingredientLines(from: lines)
                guard !ingredients.isEmpty else {
                    throw MFCaptureError.unexpected(
                        "No ingredient lines were found. Try a straighter photo of the ingredient list."
                    )
                }
                await MainActor.run {
                    draftEntrySource = entrySourceForPhoto
                    draft = RecipeDraft.from(
                        lines: ingredients,
                        name: "",
                        servings: 4,
                        sourceDescription: "Cookbook photo"
                    )
                    isRecognizing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRecognizing = false
                }
            }
        }
    }

    private func reset() {
        draft = nil
        capturedImage = nil
        errorMessage = nil
        isImporting = false
        isRecognizing = false
        urlText = ""
    }
}

// MARK: - RecipeDraftEditorView

/// Matches each ingredient line to a database food, previews computed
/// nutrition, then saves via `FoodRepository.createRecipe` and logs a
/// serving.
public struct RecipeDraftEditorView: View {
    @Binding private var draft: RecipeDraft
    private let deps: CaptureDependencies
    private let entrySource: EntrySource
    private let onDone: () -> Void

    /// Resolved foods keyed by ingredient id.
    @State private var matchedFoods: [UUID: FoodItem] = [:]
    @State private var matchTarget: MatchTarget?
    @State private var resolvingIDs: Set<UUID> = []
    @State private var mealSlot: MealSlot = .other
    @State private var isWorking = false
    @State private var errorMessage: String?

    private struct MatchTarget: Identifiable {
        let id: UUID
        let line: String
    }

    public init(
        draft: Binding<RecipeDraft>,
        deps: CaptureDependencies,
        entrySource: EntrySource,
        onDone: @escaping () -> Void
    ) {
        self._draft = draft
        self.deps = deps
        self.entrySource = entrySource
        self.onDone = onDone
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MFSpacing.lg) {
                if let errorMessage {
                    MFBanner(kind: .danger, title: "Couldn't save", message: errorMessage)
                }
                let matchedCount = draft.ingredients.filter { matchedFoods[$0.id] != nil }.count
                if matchedCount < draft.ingredients.count {
                    MFBanner(
                        kind: .info,
                        title: "\(matchedCount) of \(draft.ingredients.count) ingredients matched",
                        message: "Unmatched lines are skipped when saving."
                    )
                }

                MFTextField("Recipe name", placeholder: "e.g. Weeknight chili", text: $draft.name)
                MFStepper(
                    value: $draft.servings,
                    step: 0.5,
                    range: 0.5...60,
                    unit: "servings",
                    label: "Servings"
                )
                .frame(maxWidth: .infinity, alignment: .center)

                Text("Ingredients")
                    .font(MFFont.headline)
                    .foregroundColor(MFColor.textPrimary)
                ForEach($draft.ingredients) { $ingredient in
                    ingredientRow(ingredient: $ingredient)
                }
                MFButton("Add ingredient", style: .secondary, size: .medium, icon: "plus") {
                    draft.wrappedValue.ingredients.append(
                        RecipeDraftIngredient(line: "", grams: 100)
                    )
                }

                totalsPreview

                MFSegmentedControl(options: MealSlot.allCases, selection: $mealSlot) {
                    $0.displayName
                }

                MFButton(
                    "Save recipe & log serving",
                    style: .primary,
                    icon: "plus",
                    isLoading: isWorking,
                    action: saveRecipe
                )
                .disabled(!canSave || isWorking)
            }
            .padding(MFSpacing.lg)
        }
        .background(MFColor.background)
        .navigationTitle("Review recipe")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $matchTarget) { target in
            FoodMatchSheet(search: deps.search, initialQuery: target.line) { result in
                applyMatch(result, to: target.id)
            }
        }
    }

    // MARK: Rows

    private func ingredientRow(ingredient: Binding<RecipeDraftIngredient>) -> some View {
        VStack(alignment: .leading, spacing: MFSpacing.sm) {
            HStack {
                MFTextField("Ingredient", placeholder: "e.g. 2 cups black beans", text: ingredient.line)
                Button {
                    let id = ingredient.wrappedValue.id
                    draft.wrappedValue.ingredients.removeAll { $0.id == id }
                    matchedFoods.removeValue(forKey: id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(MFColor.danger)
                }
                .accessibilityLabel("Remove ingredient")
            }
            HStack {
                MFStepper(
                    value: ingredient.grams,
                    step: 10,
                    range: 1...20_000,
                    unit: "g",
                    label: "Amount"
                )
                Spacer()
                if resolvingIDs.contains(ingredient.wrappedValue.id) {
                    ProgressView()
                } else if let name = ingredient.wrappedValue.matchedName {
                    HStack(spacing: MFSpacing.xs) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(MFColor.success)
                        Text(name)
                            .font(MFFont.caption)
                            .foregroundColor(MFColor.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            Button {
                matchTarget = MatchTarget(
                    id: ingredient.wrappedValue.id,
                    line: ingredient.wrappedValue.line
                )
            } label: {
                Label(
                    ingredient.wrappedValue.matchedName == nil ? "Match to database" : "Change match",
                    systemImage: "magnifyingglass"
                )
                .font(MFFont.footnote.weight(.semibold))
                .foregroundColor(MFColor.accent)
            }
        }
        .padding(MFSpacing.md)
        .background(MFColor.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
    }

    // MARK: Totals

    private var totalsPer100g: [NutrientKey: Double] {
        var totals: [NutrientKey: Double] = [:]
        var grams = 0.0
        for ingredient in draft.wrappedValue.ingredients {
            guard let food = matchedFoods[ingredient.id], ingredient.grams > 0 else { continue }
            grams += ingredient.grams
            for key in NutrientKey.allCases {
                totals[key, default: 0] += food.per100g(key) * ingredient.grams / 100
            }
        }
        guard grams > 0 else { return [:] }
        return totals.mapValues { $0 / grams * 100 }
    }

    private var totalsPreview: some View {
        let totals = totalsPer100g
        return VStack(alignment: .leading, spacing: MFSpacing.sm) {
            Text("Estimated nutrition")
                .font(MFFont.headline)
                .foregroundColor(MFColor.textPrimary)
            if totals.isEmpty {
                Text("Match ingredients to see estimated nutrition per 100 g.")
                    .font(MFFont.footnote)
                    .foregroundColor(MFColor.textSecondary)
            } else {
                HStack(spacing: MFSpacing.xl) {
                    previewStat(value: totals[.calories] ?? 0, unit: "kcal", label: "Calories")
                    previewStat(value: totals[.protein] ?? 0, unit: "g", label: "Protein")
                    previewStat(value: totals[.fat] ?? 0, unit: "g", label: "Fat")
                    previewStat(value: totals[.carbs] ?? 0, unit: "g", label: "Carbs")
                }
                Text("per 100 g, from matched ingredients")
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            }
        }
        .padding(MFSpacing.md)
        .background(MFColor.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: MFRadii.md))
    }

    private func previewStat(value: Double, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(MFFormat.grams(value)) \(unit)")
                .font(MFFont.bodyBold)
                .monospacedDigit()
                .foregroundColor(MFColor.textPrimary)
            Text(label)
                .font(MFFont.caption)
                .foregroundColor(MFColor.textSecondary)
        }
    }

    // MARK: Actions

    private var canSave: Bool {
        !draft.wrappedValue.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.wrappedValue.ingredients.contains { matchedFoods[$0.id] != nil && $0.grams > 0 }
    }

    private func applyMatch(_ result: FoodSearchResult, to ingredientID: UUID) {
        resolvingIDs.insert(ingredientID)
        Task {
            do {
                let food: FoodItem = try await MainActor.run {
                    if let id = result.localFoodID,
                       let existing = try deps.foods.food(id: id)
                    {
                        return existing
                    }
                    guard let product = result.offProduct else {
                        throw MFCaptureError.unexpected("That result has no food data.")
                    }
                    return try deps.search.importOFFProduct(product)
                }
                await MainActor.run {
                    matchedFoods[ingredientID] = food
                    var updated = draft.wrappedValue
                    if let index = updated.ingredients.firstIndex(where: { $0.id == ingredientID }) {
                        updated.ingredients[index].matchedName = result.displayName
                        draft.wrappedValue = updated
                    }
                    resolvingIDs.remove(ingredientID)
                }
            } catch {
                await MainActor.run {
                    resolvingIDs.remove(ingredientID)
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func saveRecipe() {
        errorMessage = nil
        let snapshot = draft.wrappedValue
        let pairs: [(food: FoodItem, grams: Double)] = snapshot.ingredients.compactMap { ingredient in
            guard let food = matchedFoods[ingredient.id], ingredient.grams > 0 else { return nil }
            return (food: food, grams: ingredient.grams)
        }
        guard !pairs.isEmpty else {
            errorMessage = "Match at least one ingredient to a food first."
            return
        }
        let name = snapshot.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Give the recipe a name."
            return
        }
        let servings = max(snapshot.servings, 0.5)
        let totalGrams = pairs.reduce(0) { $0 + $1.grams }
        let slot = mealSlot
        let sourceNote = snapshot.sourceDescription
        isWorking = true
        Task {
            do {
                let recipe: FoodItem = try await MainActor.run {
                    var servingDescription = "\(MFFormat.grams(servings)) servings"
                    if let sourceNote, !sourceNote.isEmpty {
                        servingDescription += " · \(sourceNote)"
                    }
                    return try deps.foods.createRecipe(
                        name: name,
                        servingDescription: servingDescription,
                        servingSizeGrams: totalGrams / servings,
                        ingredients: pairs
                    )
                }
                try await MainActor.run {
                    try deps.log.logFood(
                        recipe,
                        grams: recipe.servingSizeGrams,
                        mealSlot: slot,
                        source: entrySource,
                        note: sourceNote.map { "Imported from \($0)" }
                    )
                    deps.noteFoodLogged()
                }
                await MainActor.run { onDone() }
            } catch {
                await MainActor.run {
                    isWorking = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
