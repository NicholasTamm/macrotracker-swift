import Foundation

// MARK: - ImportedRecipe

/// A recipe pulled from a web page's schema.org/JSON-LD `Recipe` markup.
public struct ImportedRecipe: Equatable, Sendable {
    public var name: String
    public var ingredientLines: [String]
    /// Parsed from `recipeYield`; defaults to 1 when absent.
    public var servings: Double
    public var sourceURL: URL

    public init(name: String, ingredientLines: [String], servings: Double, sourceURL: URL) {
        self.name = name
        self.ingredientLines = ingredientLines
        self.servings = servings
        self.sourceURL = sourceURL
    }
}

// MARK: - RecipeImportError

public enum RecipeImportError: Error, LocalizedError {
    case invalidURL
    case network(Error)
    case invalidPage
    case noRecipeFound
    case noIngredients

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "That doesn't look like a valid web address."
        case .network(let error):
            return "Couldn't load the page: \(error.localizedDescription)"
        case .invalidPage:
            return "Couldn't read that page."
        case .noRecipeFound:
            return "No recipe data was found on that page. Many sites only expose it to search engines — try the cookbook photo instead."
        case .noIngredients:
            return "The recipe had no ingredient list to import."
        }
    }
}

// MARK: - RecipeURLParser

/// Imports a recipe from a URL by extracting schema.org `Recipe` JSON-LD
/// (`<script type="application/ld+json">`). No site-specific scraping —
/// anything publishing standard recipe markup works.
public enum RecipeURLParser {

    public static func importFrom(url: URL) async throws -> ImportedRecipe {
        let normalized = normalizedURL(url)
        let html: String
        do {
            let (data, _) = try await URLSession.shared.data(from: normalized)
            guard let text = String(data: data, encoding: .utf8) else {
                throw RecipeImportError.invalidPage
            }
            html = text
        } catch let error as RecipeImportError {
            throw error
        } catch {
            throw RecipeImportError.network(error)
        }

        guard let recipeJSON = firstRecipeJSON(in: html) else {
            throw RecipeImportError.noRecipeFound
        }
        let name = (recipeJSON["name"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ingredients = ingredientLines(from: recipeJSON["recipeIngredient"])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !ingredients.isEmpty else { throw RecipeImportError.noIngredients }

        return ImportedRecipe(
            name: name.isEmpty ? "Imported recipe" : name,
            ingredientLines: ingredients,
            servings: servings(from: recipeJSON["recipeYield"]),
            sourceURL: normalized
        )
    }

    // MARK: URL

    private static func normalizedURL(_ url: URL) -> URL {
        if url.scheme != nil { return url }
        return URL(string: "https://\(url.absoluteString)") ?? url
    }

    // MARK: JSON-LD extraction

    private static func firstRecipeJSON(in html: String) -> [String: Any]? {
        let pattern = try? NSRegularExpression(
            pattern: #"<script[^>]+type=["']application/ld\+json["'][^>]*>(.*?)</script>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
        let range = NSRange(html.startIndex..., in: html)
        let matches = pattern?.matches(in: html, range: range) ?? []
        for match in matches {
            guard let jsonRange = Range(match.range(at: 1), in: html) else { continue }
            let jsonText = String(html[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = jsonText.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data)
            else { continue }
            if let recipe = findRecipe(in: json) { return recipe }
        }
        return nil
    }

    private static func findRecipe(in json: Any) -> [String: Any]? {
        if let dict = json as? [String: Any] {
            if isRecipe(dict) { return dict }
            if let graph = dict["@graph"] as? [Any] {
                for item in graph {
                    if let recipe = findRecipe(in: item) { return recipe }
                }
            }
        } else if let array = json as? [Any] {
            for item in array {
                if let recipe = findRecipe(in: item) { return recipe }
            }
        }
        return nil
    }

    private static func isRecipe(_ dict: [String: Any]) -> Bool {
        switch dict["@type"] {
        case let type as String:
            return type.lowercased() == "recipe"
        case let types as [String]:
            return types.contains { $0.lowercased() == "recipe" }
        default:
            return false
        }
    }

    // MARK: Fields

    private static func ingredientLines(from value: Any?) -> [String] {
        switch value {
        case let lines as [String]:
            return lines
        case let mixed as [Any]:
            return mixed.compactMap { $0 as? String }
        case let single as String:
            return single.components(separatedBy: "\n")
        default:
            return []
        }
    }

    private static func servings(from value: Any?) -> Double {
        let text: String
        switch value {
        case let number as Double: return max(1, number)
        case let number as Int: return max(1, Double(number))
        case let string as String: text = string
        case let parts as [String]: text = parts.joined(separator: " ")
        case let parts as [Any]: text = parts.compactMap { $0 as? String }.joined(separator: " ")
        default: return 1
        }
        let pattern = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)"#)
        let range = NSRange(text.startIndex..., in: text)
        if let match = pattern?.firstMatch(in: text, range: range),
           let valueRange = Range(match.range(at: 1), in: text),
           let parsed = Double(text[valueRange]), parsed > 0
        {
            return parsed
        }
        return 1
    }
}
