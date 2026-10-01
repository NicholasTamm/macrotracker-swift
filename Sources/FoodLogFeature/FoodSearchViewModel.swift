import Foundation
import DataLayer

// MARK: - FoodSearchViewModel

/// Food search: recent/smart history first, then debounced local +
/// Open Food Facts results.
@MainActor
@Observable
public final class FoodSearchViewModel {
    private let searchService: any FoodSearchService
    private let foods: any FoodRepository

    public var query: String = ""
    public private(set) var recentFoods: [FoodItem] = []
    public private(set) var results: [FoodSearchResult] = []
    public private(set) var isSearching: Bool = false
    public private(set) var lastError: String?

    /// Non-nil while a barcode lookup is running.
    public var barcodeEntry: String = ""
    public private(set) var barcodeResult: FoodSearchResult?
    public private(set) var barcodeLookupFailed: Bool = false

    public init(searchService: any FoodSearchService, foods: any FoodRepository) {
        self.searchService = searchService
        self.foods = foods
    }

    public func loadRecents() async {
        do {
            recentFoods = try await searchService.recentFoods(limit: 12)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Debounced search. Call from `.task(id: query)`; cancellation
    /// restarts the debounce.
    public func runSearch(for query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            try await Task.sleep(for: .milliseconds(350))
            try Task.checkCancellation()
            results = try await searchService.search(query: trimmed, includeNetwork: true)
            lastError = nil
        } catch is CancellationError {
            // Superseded by a newer keystroke — not an error.
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Resolves a search result to a loggable `FoodItem`, importing Open
    /// Food Facts products into the local database on first use.
    public func resolveFood(for result: FoodSearchResult) throws -> FoodItem {
        if let localID = result.localFoodID, let food = try foods.food(id: localID) {
            return food
        }
        if let product = result.offProduct {
            return try searchService.importOFFProduct(product)
        }
        throw MFDataError.invalidInput("Couldn't open that food.")
    }

    public func lookupBarcode(_ code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        barcodeLookupFailed = false
        barcodeResult = nil
        do {
            barcodeResult = try await searchService.lookupBarcode(trimmed)
            barcodeLookupFailed = barcodeResult == nil
        } catch {
            lastError = error.localizedDescription
            barcodeLookupFailed = true
        }
    }

    public func clearBarcode() {
        barcodeEntry = ""
        barcodeResult = nil
        barcodeLookupFailed = false
    }
}
