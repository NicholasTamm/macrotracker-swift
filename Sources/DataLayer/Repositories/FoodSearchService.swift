//  FoodSearchService.swift
//  DataLayer — unified food search: local database (seed + custom +
//  previously imported OFF foods) first, cached Open Food Facts results
//  second, live OFF network search last. Barcode lookup follows the same
//  order. Results are deduplicated by (source, id/code).

import Foundation
import SwiftData

// MARK: - Result value

/// One row in food-search results, regardless of origin.
public struct FoodSearchResult: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var brand: String
    public var barcode: String?
    public var caloriesPer100g: Double
    public var proteinPer100g: Double
    public var source: FoodSource
    /// Set when the result is backed by a local FoodItem.
    public var localFoodID: UUID?
    /// Set when the result came from Open Food Facts (cached or live).
    public var offProduct: OFFProduct?

    public var displayName: String {
        brand.isEmpty ? name : "\(name) — \(brand)"
    }

    public static func == (lhs: FoodSearchResult, rhs: FoodSearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Protocol

@MainActor
public protocol FoodSearchService {
    /// Searches local foods, then cached OFF results, then live OFF search.
    /// Set `includeNetwork = false` for fully offline behavior.
    func search(query: String, includeNetwork: Bool) async throws -> [FoodSearchResult]
    /// Barcode lookup: local foods → OFF cache → live OFF lookup.
    /// Returns nil when nothing is found anywhere.
    func lookupBarcode(_ code: String) async throws -> FoodSearchResult?
    /// Recently logged foods (smart history for the search screen).
    func recentFoods(limit: Int) async throws -> [FoodItem]
    /// Persists an OFF product as a local FoodItem (source: .openFoodFacts)
    /// so future searches hit the local DB. Returns the saved food.
    func importOFFProduct(_ product: OFFProduct) throws -> FoodItem
    /// Removes cache entries older than the TTL (maintenance).
    func pruneExpiredCache() throws
}

// MARK: - Defaulted convenience overloads
// Protocol requirements can't carry default arguments, so the defaults live
// here and forward to the requirement.

@MainActor
extension FoodSearchService {
    func search(query: String, includeNetwork: Bool = true) async throws -> [FoodSearchResult] {
        try await search(query: query, includeNetwork: includeNetwork)
    }
}

// MARK: - Implementation

@MainActor
public final class MFFoodSearchService: FoodSearchService {
    private let context: ModelContext
    private let foods: any FoodRepository
    private let client: OpenFoodFactsClient

    public init(
        context: ModelContext,
        foods: any FoodRepository,
        client: OpenFoodFactsClient = OpenFoodFactsClient()
    ) {
        self.context = context
        self.foods = foods
        self.client = client
    }

    // MARK: Search

    public func search(query: String, includeNetwork: Bool = true) async throws -> [FoodSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // 1. Local database (seed + custom + recipes + imported OFF foods).
        let local = try foods.searchFoods(query: trimmed, limit: 40)
        var results = local.map(Self.result(for:))
        var seenIDs = Set(results.map(\.id))

        // 2. Cached OFF results for this query.
        for product in try cachedSearchResults(query: trimmed) {
            let result = Self.result(for: product)
            if seenIDs.insert(result.id).inserted { results.append(result) }
        }

        // 3. Live network search (cached for next time).
        if includeNetwork {
            do {
                let network = try await client.search(query: trimmed)
                if !network.isEmpty {
                    try cacheSearch(query: trimmed, rawJSON: network[0].rawJSON)
                }
                for (product, _) in network {
                    let result = Self.result(for: product)
                    if seenIDs.insert(result.id).inserted { results.append(result) }
                }
            } catch MFDataError.networkUnavailable {
                // Offline: local + cache results stand on their own.
            }
        }

        return results
    }

    // MARK: Barcode

    public func lookupBarcode(_ code: String) async throws -> FoodSearchResult? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. Local foods with this barcode.
        if let local = try foods.foods(barcode: trimmed).first {
            return Self.result(for: local)
        }

        // 2. Cache.
        if let cached = try cachedBarcodeResult(trimmed) {
            return cached
        }

        // 3. Live OFF lookup → cache it.
        do {
            guard let (product, rawJSON) = try await client.lookupBarcode(trimmed) else {
                return nil
            }
            try cacheBarcode(trimmed, product: product, rawJSON: rawJSON)
            return Self.result(for: product)
        } catch MFDataError.networkUnavailable {
            return nil
        }
    }

    // MARK: Recents + import

    public func recentFoods(limit: Int = 20) async throws -> [FoodItem] {
        var descriptor = FetchDescriptor<LogEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit * 3
        let entries = try context.fetch(descriptor)
        var seen = Set<UUID>()
        var out: [FoodItem] = []
        for entry in entries {
            guard let food = entry.food, !food.isArchived, seen.insert(food.id).inserted else { continue }
            out.append(food)
            if out.count >= limit { break }
        }
        return out
    }

    @discardableResult
    public func importOFFProduct(_ product: OFFProduct) throws -> FoodItem {
        // Avoid duplicates: same OFF code imported twice.
        if !product.code.isEmpty {
            let code: String? = product.code
            var descriptor = FetchDescriptor<FoodItem>(
                predicate: #Predicate { $0.openFoodFactsCode == code }
            )
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first { return existing }
        }
        let values = product.foodItemValues()
        return try foods.saveFood(
            name: values.name.isEmpty ? "Unknown product" : values.name,
            brand: values.brand,
            barcode: values.barcode,
            servingDescription: values.servingDescription,
            servingSizeGrams: values.servingSizeGrams,
            nutrientsPer100g: values.nutrientsPer100g,
            source: .openFoodFacts
        )
    }

    public func pruneExpiredCache() throws {
        let descriptor = FetchDescriptor<OpenFoodFactsCacheEntry>()
        let now = Date()
        for entry in try context.fetch(descriptor) where now.timeIntervalSince(entry.fetchedAt) > OpenFoodFactsCacheEntry.timeToLive {
            context.delete(entry)
        }
        try context.save()
    }

    // MARK: Cache helpers

    private func cacheEntry(queryKey: String) throws -> OpenFoodFactsCacheEntry? {
        var descriptor = FetchDescriptor<OpenFoodFactsCacheEntry>(
            predicate: #Predicate { $0.queryKey == queryKey }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func cachedSearchResults(query: String) throws -> [OFFProduct] {
        let key = "search:\(query.lowercased())"
        guard let entry = try cacheEntry(queryKey: key), !entry.isExpired else { return [] }
        let response = try JSONDecoder().decode(OFFSearchResponse.self, from: entry.rawJSON)
        return (response.products ?? []).map { OpenFoodFactsClient.normalize($0) }
    }

    private func cacheSearch(query: String, rawJSON: Data) throws {
        let key = "search:\(query.lowercased())"
        if let existing = try cacheEntry(queryKey: key) {
            existing.rawJSON = rawJSON
            existing.fetchedAt = Date()
        } else {
            context.insert(OpenFoodFactsCacheEntry(queryKey: key, rawJSON: rawJSON))
        }
        try context.save()
    }

    private func cachedBarcodeResult(_ code: String) throws -> FoodSearchResult? {
        let key = "barcode:\(code)"
        guard let entry = try cacheEntry(queryKey: key), !entry.isExpired else { return nil }
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: entry.rawJSON)
        guard let payload = response.product else { return nil }
        return Self.result(for: OpenFoodFactsClient.normalize(payload))
    }

    private func cacheBarcode(_ code: String, product: OFFProduct, rawJSON: Data) throws {
        let key = "barcode:\(code)"
        if let existing = try cacheEntry(queryKey: key) {
            existing.rawJSON = rawJSON
            existing.fetchedAt = Date()
            existing.productName = product.name
        } else {
            context.insert(OpenFoodFactsCacheEntry(
                queryKey: key,
                barcode: code,
                productName: product.name,
                rawJSON: rawJSON
            ))
        }
        try context.save()
    }

    // MARK: Mapping

    private static func result(for food: FoodItem) -> FoodSearchResult {
        FoodSearchResult(
            id: "local:\(food.id.uuidString)",
            name: food.name,
            brand: food.brand,
            barcode: food.barcode,
            caloriesPer100g: food.per100g(.calories),
            proteinPer100g: food.per100g(.protein),
            source: food.source,
            localFoodID: food.id,
            offProduct: nil
        )
    }

    private static func result(for product: OFFProduct) -> FoodSearchResult {
        FoodSearchResult(
            id: "off:\(product.code)",
            name: product.name,
            brand: product.brand,
            barcode: product.code.isEmpty ? nil : product.code,
            caloriesPer100g: product.nutrientsPer100g[.calories] ?? 0,
            proteinPer100g: product.nutrientsPer100g[.protein] ?? 0,
            source: .openFoodFacts,
            localFoodID: nil,
            offProduct: product
        )
    }
}
