import SwiftUI
import DesignSystem
import DataLayer

// MARK: - FoodSearchView

/// Food search: recent/smart history first, then debounced local + Open
/// Food Facts results. Selecting a food resolves it to a `FoodItem`
/// (importing OFF products on first use) and hands it to `onSelectFood`.
public struct FoodSearchView: View {
    @State private var viewModel: FoodSearchViewModel
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let onSelectFood: (FoodItem) -> Void
    private let onQuickAdd: () -> Void
    private let onCreateCustomFood: () -> Void
    private let onCreateRecipe: () -> Void

    public init(
        searchService: any FoodSearchService,
        foods: any FoodRepository,
        onSelectFood: @escaping (FoodItem) -> Void,
        onQuickAdd: @escaping () -> Void = {},
        onCreateCustomFood: @escaping () -> Void = {},
        onCreateRecipe: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: FoodSearchViewModel(
            searchService: searchService,
            foods: foods
        ))
        self.onSelectFood = onSelectFood
        self.onQuickAdd = onQuickAdd
        self.onCreateCustomFood = onCreateCustomFood
        self.onCreateRecipe = onCreateRecipe
    }

    public var body: some View {
        NavigationStack {
            List {
                if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    recentsSection
                } else {
                    resultsSection
                }
                createSection
            }
            .listStyle(.plain)
            .navigationTitle("Search foods")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, prompt: "Search for a food")
            .task(id: viewModel.query) {
                await viewModel.runSearch(for: viewModel.query)
            }
            .task {
                await viewModel.loadRecents()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Couldn't open food", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    // MARK: Sections

    private var recentsSection: some View {
        Section {
            if viewModel.recentFoods.isEmpty {
                Text("Foods you log will appear here for quick re-logging.")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
            } else {
                ForEach(viewModel.recentFoods, id: \.id) { food in
                    recentRow(food)
                }
            }
        } header: {
            Text("Recents")
                .font(MFFont.caption.weight(.semibold))
                .foregroundColor(MFColor.textSecondary)
        }
    }

    private func recentRow(_ food: FoodItem) -> some View {
        Button { onSelectFood(food) } label: {
            HStack(spacing: MFSpacing.md) {
                MFFoodIcon(openmojiHex: MFFoodIconMapper.hex(forName: food.name))
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.displayName)
                        .font(MFFont.body)
                        .foregroundColor(MFColor.textPrimary)
                        .lineLimit(1)
                    Text("\(MFFormat.kcal(food.per100g(.calories))) kcal per 100 g")
                        .font(MFFont.caption)
                        .foregroundColor(MFColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(MFColor.textTertiary)
            }
            .padding(.vertical, MFSpacing.xs)
        }
    }

    private var resultsSection: some View {
        Section {
            if viewModel.isSearching && viewModel.results.isEmpty {
                ForEach(0..<3, id: \.self) { _ in MFFoodRowSkeleton() }
            } else if viewModel.results.isEmpty && !viewModel.isSearching {
                Text("No matches. Try a different search, or create a custom food below.")
                    .font(MFFont.subheadline)
                    .foregroundColor(MFColor.textSecondary)
            } else {
                ForEach(viewModel.results) { result in
                    MFFoodSearchRow(
                        name: result.name,
                        brand: result.brand.isEmpty ? nil : result.brand,
                        kcal: result.caloriesPer100g,
                        protein: result.proteinPer100g,
                        carbs: 0,
                        fat: 0,
                        servingText: "100",
                        unitText: "g",
                        isVerified: result.source == .seedDatabase,
                        openmojiHex: MFFoodIconMapper.hex(forName: result.name)
                    ) {
                        select(result)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        } header: {
            Text("Results")
                .font(MFFont.caption.weight(.semibold))
                .foregroundColor(MFColor.textSecondary)
        }
    }

    private var createSection: some View {
        Section {
            Button(action: onQuickAdd) {
                createRow(icon: "wand.and.stars", title: "Quick add", detail: "Calories and macros by hand")
            }
            Button(action: onCreateCustomFood) {
                createRow(icon: "plus.circle", title: "Create custom food", detail: "Save a food with your own nutrition facts")
            }
            Button(action: onCreateRecipe) {
                createRow(icon: "list.bullet.clipboard", title: "Build a recipe", detail: "Combine ingredients into one food")
            }
        } header: {
            Text("Can't find it?")
                .font(MFFont.caption.weight(.semibold))
                .foregroundColor(MFColor.textSecondary)
        }
    }

    private func createRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: MFSpacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(MFColor.accent)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MFFont.body)
                    .foregroundColor(MFColor.textPrimary)
                Text(detail)
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(MFColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, MFSpacing.xs)
    }

    private func select(_ result: FoodSearchResult) {
        do {
            let food = try viewModel.resolveFood(for: result)
            onSelectFood(food)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Food search") {
    struct Demo: View {
        var body: some View {
            Text("FoodSearchView preview needs a DataStore; see FoodLogRootView.")
        }
    }
    return Demo()
}
