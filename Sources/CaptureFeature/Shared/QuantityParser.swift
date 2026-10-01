import Foundation

// MARK: - QuantityParser

/// Shared "2 cups" / "150 g" / "1 medium" → grams parsing, used by the
/// voice parser (spoken quantities) and the recipe draft (ingredient-line
/// quantities). All copy is original; unit weights are rough kitchen
/// equivalents the user can always edit.
public enum QuantityParser {

    /// Approximate grams per unit.
    public static let gramsPerUnit: [String: Double] = [
        "kg": 1_000, "kilo": 1_000, "kilos": 1_000,
        "g": 1, "gram": 1, "grams": 1,
        "oz": 28.35, "ounce": 28.35, "ounces": 28.35,
        "lb": 453.6, "pound": 453.6, "pounds": 453.6,
        "cup": 240, "cups": 240,
        "tbsp": 15, "tablespoon": 15, "tablespoons": 15,
        "tsp": 5, "teaspoon": 5, "teaspoons": 5,
        "ml": 1, "milliliter": 1, "milliliters": 1,
        "l": 1_000, "liter": 1_000, "liters": 1_000, "litre": 1_000, "litres": 1_000,
        "slice": 30, "slices": 30,
        "piece": 50, "pieces": 50,
        "small": 100, "medium": 150, "large": 200, "whole": 150,
        "can": 350, "cans": 350,
        "clove": 5, "cloves": 5,
        "scoop": 30, "scoops": 30,
        "serving": 100, "servings": 100,
        "bowl": 350, "bowls": 350,
        "plate": 500, "plates": 500,
        "handful": 40, "handfuls": 40,
        "glass": 250, "glasses": 250,
        "bottle": 500, "bottles": 500,
        "stick": 113, "sticks": 113,
        "packet": 30, "packets": 30,
    ]

    /// Parses a leading quantity from text: "2 cups flour" → 480.
    /// Returns nil when the text doesn't start with a number.
    public static func grams(from text: String) -> Double? {
        let pattern = try? NSRegularExpression(
            pattern: #"^\s*(\d+(?:\.\d+)?)\s*([a-zA-Z]+)?"#
        )
        let range = NSRange(text.startIndex..., in: text)
        guard let match = pattern?.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text),
              let quantity = Double(text[valueRange])
        else { return nil }

        var unit: String?
        if match.range(at: 2).location != NSNotFound,
           let unitRange = Range(match.range(at: 2), in: text)
        {
            unit = String(text[unitRange]).lowercased()
        }
        guard let unit, let factor = gramsPerUnit[unit] else {
            // Bare count ("2 eggs"): assume ~100 g each as an editable guess.
            return quantity * 100
        }
        return quantity * factor
    }

    /// Splits "2 cups of flour" into (grams, "flour").
    public static func splitQuantityAndName(_ text: String) -> (grams: Double?, name: String) {
        let pattern = try? NSRegularExpression(
            pattern: #"^\s*(\d+(?:\.\d+)?)\s*([a-zA-Z]+)?\s*(?:of\s+)?(.*)$"#
        )
        let range = NSRange(text.startIndex..., in: text)
        guard let match = pattern?.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text),
              let quantity = Double(text[valueRange])
        else {
            return (nil, text.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        var unit: String?
        if match.range(at: 2).location != NSNotFound,
           let unitRange = Range(match.range(at: 2), in: text)
        {
            unit = String(text[unitRange]).lowercased()
        }
        let nameRange = Range(match.range(at: 3), in: text)
        let rest = nameRange.map { String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""

        if let unit, let factor = gramsPerUnit[unit] {
            return (quantity * factor, rest.isEmpty ? unit : rest)
        }
        // Unknown unit: keep the words in the name, guess 100 g per count.
        let name = [unit, rest].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        return (quantity * 100, name)
    }
}
