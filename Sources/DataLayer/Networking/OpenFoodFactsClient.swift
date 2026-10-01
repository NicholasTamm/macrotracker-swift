//  OpenFoodFactsClient.swift
//  DataLayer — Open Food Facts API v2 client (barcode lookup + search).
//
//  Used for user-submitted/verified food data and barcode lookup. Responses
//  are cached locally (see OpenFoodFactsCacheEntry / FoodSearchService) so
//  repeat lookups work offline.
//
//  Open Food Facts data is © Open Food Facts contributors, ODbL licensed.
//  Per their usage guidance we send an identifying User-Agent and keep
//  request volume reasonable (search-as-you-type should debounce in UI).

import Foundation

// MARK: - Decodable payloads

/// A lossy double: OFF sometimes encodes nutriments as strings.
struct LossyDouble: Decodable {
    var value: Double
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode(Double.self) {
            value = d
        } else if let s = try? container.decode(String.self), let d = Double(s) {
            value = d
        } else {
            value = 0
        }
    }
}

struct OFFProductPayload: Decodable {
    var code: String?
    var productName: String?
    var brands: String?
    var servingSize: String?
    var nutriments: [String: LossyDouble]?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case nutriments
    }
}

struct OFFProductResponse: Decodable {
    var status: Int?
    var product: OFFProductPayload?
}

struct OFFSearchResponse: Decodable {
    var products: [OFFProductPayload]?
}

// MARK: - Domain value

/// A normalized Open Food Facts product, ready to display or import.
public struct OFFProduct: Equatable, Sendable {
    public var code: String
    public var name: String
    public var brand: String
    /// Raw serving text from OFF, e.g. "30 g".
    public var servingSizeText: String
    /// Parsed grams per serving (falls back to 100).
    public var servingSizeGrams: Double
    /// Nutrients per 100 g.
    public var nutrientsPer100g: [NutrientKey: Double]

    /// Converts the OFF product into a persistable FoodItem value.
    /// Callers insert it via `FoodRepository.saveFood(...)`.
    public func foodItemValues() -> (
        name: String,
        brand: String,
        barcode: String?,
        servingDescription: String,
        servingSizeGrams: Double,
        nutrientsPer100g: [NutrientKey: Double]
    ) {
        (
            name: name,
            brand: brand,
            barcode: code,
            servingDescription: servingSizeText,
            servingSizeGrams: servingSizeGrams,
            nutrientsPer100g: nutrientsPer100g
        )
    }
}

// MARK: - Client

/// Thin URLSession wrapper over the Open Food Facts API v2.
public struct OpenFoodFactsClient: Sendable {
    private static let baseURL = URL(string: "https://world.openfoodfacts.org")!
    /// Identifying user agent per OFF usage guidance.
    private static let userAgent = "MacroFactorClone/1.0 (iOS; +https://example.com)"

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: Barcode lookup

    /// Fetches a single product by barcode. Returns nil when OFF has no
    /// record for the code (caller should offer manual/custom-food entry).
    public func lookupBarcode(_ code: String) async throws -> (product: OFFProduct, rawJSON: Data)? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent("api/v2/product/\(trimmed).json"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "fields", value: offFields)]
        let (data, _) = try await get(components.url!)
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        guard response.status == 1, let payload = response.product else { return nil }
        return (Self.normalize(payload), data)
    }

    // MARK: Search

    public func search(query: String, pageSize: Int = 25) async throws -> [(product: OFFProduct, rawJSON: Data)] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent("cgi/search.pl"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: String(min(max(pageSize, 1), 50))),
            URLQueryItem(name: "fields", value: offFields),
        ]
        let (data, _) = try await get(components.url!)
        let response = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        return (response.products ?? []).map { (Self.normalize($0), data) }
    }

    // MARK: Private

    private func get(_ url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        do {
            return try await session.data(for: request)
        } catch {
            throw MFDataError.networkUnavailable
        }
    }

    private var offFields: String {
        "code,product_name,brands,serving_size,nutriments"
    }

    // MARK: Normalization

    /// Maps OFF nutriment keys (per 100 g) onto NutrientKey with unit fixes.
    /// Conversions below follow OFF's documented units; values OFF doesn't
    /// provide stay absent (treated as 0 downstream).
    static func normalize(_ payload: OFFProductPayload) -> OFFProduct {
        let nutriments = payload.nutriments ?? [:]
        func v(_ key: String) -> Double { nutriments[key]?.value ?? 0 }

        // (nutriment key, factor to our unit)
        let mapping: [(String, NutrientKey, Double)] = [
            ("energy-kcal_100g", .calories, 1),
            ("proteins_100g", .protein, 1),
            ("fat_100g", .fat, 1),
            ("carbohydrates_100g", .carbs, 1),
            ("fiber_100g", .fiber, 1),
            ("sugars_100g", .sugar, 1),
            ("saturated-fat_100g", .saturatedFat, 1),
            ("trans-fat_100g", .transFat, 1),
            ("cholesterol_100g", .cholesterol, 1000), // OFF: g → mg
            ("alcohol_100g", .alcohol, 1),
            ("sodium_100g", .sodium, 1000),           // OFF: g → mg
            ("potassium_100g", .potassium, 1000),
            ("calcium_100g", .calcium, 1000),
            ("iron_100g", .iron, 1000),
            ("magnesium_100g", .magnesium, 1000),
            ("phosphorus_100g", .phosphorus, 1000),
            ("zinc_100g", .zinc, 1000),
            ("copper_100g", .copper, 1000),
            ("manganese_100g", .manganese, 1000),
            ("vitamin-a_100g", .vitaminA, 1),         // OFF: µg
            ("vitamin-c_100g", .vitaminC, 1000),     // OFF: g → mg
            ("vitamin-d_100g", .vitaminD, 1),         // OFF: µg
            ("vitamin-e_100g", .vitaminE, 1000),
            ("vitamin-k_100g", .vitaminK, 1),         // OFF: µg
            ("thiamin_100g", .thiamin, 1000),
            ("riboflavin_100g", .riboflavin, 1000),
            ("niacin_100g", .niacin, 1000),
            ("vitamin-b6_100g", .vitaminB6, 1000),
            ("folate_100g", .folate, 1),              // OFF: µg
            ("vitamin-b12_100g", .vitaminB12, 1),     // OFF: µg
            ("selenium_100g", .selenium, 1_000_000),  // OFF: g → mcg
            ("iodine_100g", .iodine, 1_000_000),
            ("caffeine_100g", .caffeine, 1000),
        ]

        var nutrients: [NutrientKey: Double] = [:]
        for (offKey, key, factor) in mapping {
            let value = v(offKey) * factor
            if value > 0 { nutrients[key] = value }
        }

        let servingText = payload.servingSize ?? ""
        return OFFProduct(
            code: payload.code ?? "",
            name: (payload.productName ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            brand: (payload.brands ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            servingSizeText: servingText,
            servingSizeGrams: Self.parseServingGrams(servingText),
            nutrientsPer100g: nutrients
        )
    }

    /// Parses "30 g", "1 bar (45g)", "250ml" → grams (ml ≈ g for serving math).
    static func parseServingGrams(_ text: String) -> Double {
        let lower = text.lowercased()
        // Prefer an explicit "(NNNg)" parenthetical, then a bare number+unit.
        let patterns = ["\\(([0-9]+(?:\\.[0-9]+)?)\\s*g", "([0-9]+(?:\\.[0-9]+)?)\\s*(g|ml)"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(
                   in: lower,
                   range: NSRange(lower.startIndex..., in: lower)
               ),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: lower),
               let grams = Double(lower[range]), grams > 0
            {
                return grams
            }
        }
        return 100
    }
}
