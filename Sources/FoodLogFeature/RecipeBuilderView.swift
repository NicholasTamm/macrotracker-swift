import SwiftUI
import DesignSystem
import DataLayer

// MARK: - RecipeBuilderView

/// Build a recipe from ingredients: name, servings, ingredient list with
/// per-ingredient amounts, live macro totals. Saves via
/// `FoodRepository.createRecipe` (or updates an existing recipe).
public struct RecipeBuilderView: View {
    private let existingRecipe: FoodItem?
    private let foods: any FoodRepository
    private let searchService: any FoodSearchService
    private let onDone: (FoodItem) -> Void

    @State private var name: String
    @State private var servingsDescription: String
    @State private var ingredients: [BuilderIngredient]
    @State private var showingPicker = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    private struct BuilderIngredient: Identifiable {
        var id: UUID
        var food: FoodItem
        var grams: Double
    }

    public init(
        recipe: FoodItem?,
        foods: any FoodRepository,
        searchService: any FoodSearchService,
        onDone: @escaping (FoodItem) -> Void
    ) {
        self.existingRecipe = recipe
        self.foods = foods
        self.searchService = searchService
        self.onDone = onDone
        _name = State(initialValue: recipe?.name ?? "")
        _servingsDescription = State(initialValue: recipe?.servingDescription ?? "")
        let loaded = (recipe?.recipeIngredients ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { join -> BuilderIngredient? in
                guard let food = join.food else { return nil }
                return BuilderIngredient(id: join.id, food: food, grams: join.grams)
            }
        _ingredients = State(initialValue: loaded)
    }

    private var totalGrams: Double {
        ingredients.reduce(0) { $0 + $1.grams }
    }

    private var totals: [NutrientKey: Double] {
        var out: [NutrientKey: Double] = [:]
        for ingredient in ingredients {
            for (key, value) in ingredient.food.scaledNutrients(grams: ingredient.grams) {
                out[key, default: 0] += value
            }
        }
        return out
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !ingredients.isEmpty
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Recipe") {
                    MFTextField("Name", placeholder: "e.g. Protein pancakes", text: $name)
                    MFTextField(
                        "Serving description",
                        placeholder: "e.g. 2 pancakes",
                        text: $servingsDescription
                    )
                }

                Section("Ingredients") {
                    ForEach($ingredients) { $ingredient in
                        HStack(spacing: MFSpacing.md) {
                            MFFoodIcon(openmojiHex: MFFoodIconMapper.hex(forName: ingredient.food.name))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ingredient.food.displayName)
                                    .font(MFFont.body)
                                    .foregroundColor(MFColor.textPrimary)
                                    .lineLimit(1)
                                Text("\(MFFormat.grams(ingredient.grams)) g")
                                    .font(MFFont.caption)
                                    .foregroundColor(MFColor.textSecondary)
                            }
                            Spacer()
                            MFStepper(
                                value: $ingredient.grams,
                                step: 10,
                                range: 1...10000,
                                unit: "g",
                                label: "\(ingredient.food.name) amount"
                            )
                        }
                        .padding(.vertical, MFSpacing.xs)
                    }
                    .onDelete { offsets in
                        ingredients.remove(atOffsets: offsets)
                    }

                    Button {
                        showingPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(MFColor.accent)
                            Text("Add ingredient")
                                .font(MFFont.body)
                                .foregroundColor(MFColor.accent)
                        }
                    }
                }

                Section("Totals (\(MFFormat.grams(totalGrams)) g)") {
                    totalsRow(name: "Calories", value: totals[.calories] ?? 0, unit: "kcal", color: MFColor.calories)
                    totalsRow(name: "Protein", value: totals[.protein] ?? 0, unit: "g", color: MFColor.protein)
                    totalsRow(name: "Fat", value: totals[.fat] ?? 0, unit: "g", color: MFColor.fat)
                    totalsRow(name: "Carbs", value: totals[.carbs] ?? 0, unit: "g", color: MFColor.carbs)
                }

                Section {
                    MFButton(
                        existingRecipe == nil ? "Save recipe" : "Save changes",
                        style: .primary,
                        size: .large,
                        action: save
                    )
                    .disabled(!isValid)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(existingRecipe == nil ? "New recipe" : "Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPicker) {
                IngredientPickerView(searchService: searchService, foods: foods) { food in
                    if !ingredients.contains(where: { $0.food.id == food.id }) {
                        ingredients.append(BuilderIngredient(
                            id: UUID(),
                            food: food,
                            grams: food.servingSizeGrams
                        ))
                    }
                    showingPicker = false
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

    private func totalsRow(name: String, value: Double, unit: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10).accessibilityHidden(true)
            Text(name).font(MFFont.body).foregroundColor(MFColor.textPrimary)
            Spacer()
            Text("\(MFFormat.grams(value)) \(unit)")
                .font(MFFont.body).monospacedDigit()
                .foregroundColor(MFColor.textSecondary)
        }
    }

    private func save() {
        do {
            if let recipe = existingRecipe {
                recipe.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                recipe.servingDescription = servingsDescription
                // Rebuild the ingredient list, then recompute.
                for join in recipe.recipeIngredients {
                    try foods.removeIngredient(join)
                }
                for ingredient in ingredients {
                    try foods.addIngredient(to: recipe, food: ingredient.food, grams: ingredient.grams)
                }
                try foods.recomputeRecipeNutrients(recipe)
                try foods.updateFood(recipe)
                onDone(recipe)
            } else {
                let recipe = try foods.createRecipe(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    servingDescription: servingsDescription,
                    servingSizeGrams: max(totalGrams, 1),
                    ingredients: ingredients.map { ($0.food, $0.grams) }
                )
                onDone(recipe)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - IngredientPickerView

/// Minimal food search for picking recipe ingredients.
private struct IngredientPickerView: View {
    @State private var viewModel: FoodSearchViewModel
    private let onPick: (FoodItem) -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        searchService: any FoodSearchService,
        foods: any FoodRepository,
        onPick: @escaping (FoodItem) -> Void
    ) {
        _viewModel = State(initialValue: FoodSearchViewModel(
            searchService: searchService,
            foods: foods
        ))
        self.onPick = onPick
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isSearching && viewModel.results.isEmpty {
                    ForEach(0..<3, id: \.self) { _ in MFFoodRowSkeleton() }
                } else {
                    ForEach(viewModel.results) { result in
                        Button {
                            do {
                                onPick(try viewModel.resolveFood(for: result))
                            } catch {
                                // Swallowed: picker stays open; the recipe
                                // screen surfaces save errors.
                            }
                        } label: {
                            HStack {
                                MFFoodIcon(openmojiHex: MFFoodIconMapper.hex(forName: result.name))
                                VStack(alignment: .leading) {
                                    Text(result.displayName)
                                        .font(MFFont.body)
                                        .foregroundColor(MFColor.textPrimary)
                                        .lineLimit(1)
                                    Text("\(MFFormat.kcal(result.caloriesPer100g)) kcal per 100 g")
                                        .font(MFFont.caption)
                                        .foregroundColor(MFColor.textSecondary)
                                }
                            }
                            .padding(.vertical, MFSpacing.xs)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Add ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, prompt: "Search foods")
            .task(id: viewModel.query) {
                await viewModel.runSearch(for: viewModel.query)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
