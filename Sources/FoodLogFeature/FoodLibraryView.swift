import SwiftUI
import DesignSystem
import DataLayer

// MARK: - FoodLibraryView

/// The user's food library: custom foods and recipes, searchable, with
/// edit and log actions.
public struct FoodLibraryView: View {
    private enum Tab: String, CaseIterable {
        case custom = "Custom foods"
        case recipes = "Recipes"
    }

    private let foods: any FoodRepository
    private let onSelectFood: (FoodItem) -> Void
    private let onEditFood: (FoodItem) -> Void
    private let onEditRecipe: (FoodItem) -> Void

    @State private var tab: Tab = .custom
    @State private var query: String = ""
    @State private var customFoods: [FoodItem] = []
    @State private var recipes: [FoodItem] = []
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    public init(
        foods: any FoodRepository,
        onSelectFood: @escaping (FoodItem) -> Void,
        onEditFood: @escaping (FoodItem) -> Void,
        onEditRecipe: @escaping (FoodItem) -> Void
    ) {
        self.foods = foods
        self.onSelectFood = onSelectFood
        self.onEditFood = onEditFood
        self.onEditRecipe = onEditRecipe
    }

    private var filteredCustom: [FoodItem] {
        filterItems(customFoods)
    }

    private var filteredRecipes: [FoodItem] {
        filterItems(recipes)
    }

    private func filterItems(_ items: [FoodItem]) -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.brand.localizedCaseInsensitiveContains(trimmed)
        }
    }

    public var body: some View {
        NavigationStack {
            List {
                Picker("Library", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                let items = tab == .custom ? filteredCustom : filteredRecipes
                if items.isEmpty {
                    Text(tab == .custom
                         ? "No custom foods yet. Create one from food search."
                         : "No recipes yet. Build one from food search.")
                        .font(MFFont.subheadline)
                        .foregroundColor(MFColor.textSecondary)
                } else {
                    ForEach(items, id: \.id) { food in
                        libraryRow(food)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search library")
            .task { await reload() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Couldn't load library", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
        }
    }

    private func reload() async {
        do {
            customFoods = try foods.customFoods()
            recipes = try foods.recipes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func libraryRow(_ food: FoodItem) -> some View {
        HStack(spacing: MFSpacing.md) {
            MFFoodIcon(openmojiHex: MFFoodIconMapper.hex(forName: food.name))
            VStack(alignment: .leading, spacing: 2) {
                Text(food.displayName)
                    .font(MFFont.body)
                    .foregroundColor(MFColor.textPrimary)
                    .lineLimit(1)
                Text("\(MFFormat.kcal(food.per100g(.calories))) kcal · \(MFFormat.grams(food.per100g(.protein)))P \(MFFormat.grams(food.per100g(.fat)))F \(MFFormat.grams(food.per100g(.carbs)))C per 100 g")
                    .font(MFFont.caption)
                    .monospacedDigit()
                    .foregroundColor(MFColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
                Button("Log food") { onSelectFood(food) }
                Button("Edit") {
                    if food.source == .recipe { onEditRecipe(food) } else { onEditFood(food) }
                }
                Button("Archive", role: .destructive) {
                    do {
                        try foods.archiveFood(food)
                        Task { await reload() }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(MFColor.textSecondary)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Options for \(food.displayName)")
            }
        }
        .padding(.vertical, MFSpacing.xs)
        .contentShape(Rectangle())
        .onTapGesture { onSelectFood(food) }
    }
}
