import SwiftUI
import DataLayer
import DesignSystem

// MARK: - FoodMatchSheet

/// Database-match sheet shared by the voice and recipe flows: search the
/// local DB + Open Food Facts, pick a result, and the caller resolves it to
/// a `FoodItem` (local fetch or `importOFFProduct`).
public struct FoodMatchSheet: View {
    private let search: any FoodSearchService
    private let initialQuery: String
    private let onSelect: (FoodSearchResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var results: [FoodSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    public init(
        search: any FoodSearchService,
        initialQuery: String,
        onSelect: @escaping (FoodSearchResult) -> Void
    ) {
        self.search = search
        self.initialQuery = initialQuery
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: MFSpacing.md) {
                MFTextField(
                    "Search foods",
                    placeholder: "e.g. chicken breast",
                    text: $query,
                    icon: "magnifyingglass"
                )
                .padding(.horizontal, MFSpacing.lg)
                .padding(.top, MFSpacing.md)
                .onChange(of: query) { _, newValue in debounceSearch(newValue) }

                if let errorMessage {
                    MFBanner(kind: .danger, title: "Search failed", message: errorMessage)
                        .padding(.horizontal, MFSpacing.lg)
                }

                if isSearching && results.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    MFEmptyState(
                        icon: "magnifyingglass",
                        title: "No matches yet",
                        message: "Type to search your foods and Open Food Facts."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(results) { result in
                        Button {
                            onSelect(result)
                            dismiss()
                        } label: {
                            matchRow(result)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(MFColor.background)
            .navigationTitle("Match food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                query = initialQuery
                runSearch(query: initialQuery)
            }
        }
    }

    private func matchRow(_ result: FoodSearchResult) -> some View {
        HStack(spacing: MFSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.displayName)
                    .font(MFFont.body)
                    .foregroundColor(MFColor.textPrimary)
                Text("\(MFFormat.grams(result.caloriesPer100g)) kcal / 100 g")
                    .font(MFFont.caption)
                    .foregroundColor(MFColor.textSecondary)
                    .monospacedDigit()
            }
            Spacer()
            Image(systemName: "checkmark.circle")
                .foregroundColor(MFColor.accent)
        }
        .contentShape(Rectangle())
    }

    private func debounceSearch(_ newValue: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await runSearch(query: newValue)
        }
    }

    private func runSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await MainActor.run { results = [] }
            return
        }
        await MainActor.run { isSearching = true }
        defer { Task { await MainActor.run { isSearching = false } } }
        do {
            let found = try await search.search(query: trimmed, includeNetwork: true)
            await MainActor.run {
                results = found
                errorMessage = nil
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}
