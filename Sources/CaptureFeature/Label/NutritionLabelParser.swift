import Foundation
import DataLayer

// MARK: - NutritionLabelParser

/// Turns raw OCR lines from a nutrition-facts photo into per-100-g
/// nutrient values. Handles both US-style "per serving" labels and
/// EU/AU-style "per 100 g" tables.
///
/// Strategy:
/// 1. Find the serving size ("Serving size 30 g").
/// 2. Detect the value basis ("per 100 g" present → per-100-g, else per serving).
/// 3. Match nutrient keywords longest-first, extract the first number+unit
///    on the line, normalize to the nutrient's display unit.
/// 4. Convert per-serving values to per-100-g.
///
/// Special cases: Energy in kJ → kcal; "Salt" → sodium (salt g × 400 = sodium mg).
public enum NutritionLabelParser {

    public struct Result: Sendable {
        /// e.g. "1 bar (45 g)" when found, "" otherwise.
        public var servingDescription: String
        public var servingSizeGrams: Double
        /// Per-100-g nutrients.
        public var nutrientsPer100g: [NutrientKey: Double]
        /// True when no serving size was found and 100 g was assumed.
        public var assumedServingSize: Bool
        public var linesSeen: Int
    }

    public static func parse(lines: [String]) -> Result {
        let cleaned = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else {
            return Result(
                servingDescription: "",
                servingSizeGrams: 100,
                nutrientsPer100g: [:],
                assumedServingSize: true,
                linesSeen: 0
            )
        }

        let joined = cleaned.joined(separator: "\n").lowercased()
        let isPer100g = joined.contains("per 100")
            || joined.contains("per100")
            || joined.contains("/100g")
            || joined.contains("/ 100 g")

        let (servingGrams, servingDescription) = parseServingSize(from: cleaned)
        let assumedServing = servingGrams == nil
        let basisGrams = servingGrams ?? 100

        var perBasis: [NutrientKey: Double] = [:]
        for line in cleaned {
            let lower = line.lowercased()
            guard let match = matchers.first(where: { lower.contains($0.keyword) }),
                  let (value, unit) = firstValue(in: line)
            else { continue }
            let normalized = match.convert(value, unit)
            // First match wins per nutrient; labels repeat nutrients in
            // %DV columns we can't reliably disambiguate.
            if perBasis[match.key] == nil {
                perBasis[match.key] = normalized
            }
        }

        let factor = isPer100g ? 1.0 : 100.0 / max(basisGrams, 1)
        var nutrientsPer100g: [NutrientKey: Double] = [:]
        for (key, value) in perBasis {
            nutrientsPer100g[key] = max(0, value * factor)
        }

        return Result(
            servingDescription: servingDescription,
            servingSizeGrams: basisGrams,
            nutrientsPer100g: nutrientsPer100g,
            assumedServingSize: assumedServing,
            linesSeen: cleaned.count
        )
    }

    // MARK: Serving size

    private static func parseServingSize(from lines: [String]) -> (Double?, String) {
        let pattern = try? NSRegularExpression(
            pattern: #"(?i)serving(?:\s+size)?[^0-9]{0,12}(\d+(?:[.,]\d+)?)\s*(g|ml)\b"#
        )
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = pattern?.firstMatch(in: line, range: range),
               let valueRange = Range(match.range(at: 1), in: line)
            {
                let value = Double(line[valueRange].replacingOccurrences(of: ",", with: ".")) ?? 0
                guard value > 0 else { continue }
                return (value, line.trimmingCharacters(in: .whitespaces))
            }
        }
        return (nil, "")
    }

    // MARK: Value extraction

    /// First number+unit on the line that isn't a %DV figure.
    private static func firstValue(in line: String) -> (Double, String?)? {
        let pattern = try? NSRegularExpression(
            pattern: #"(\d+(?:[.,]\d+)?)\s*(kcal|kj|g|mg|mcg|µg|μg)?\s*(%)?"#,
            options: .caseInsensitive
        )
        let range = NSRange(line.startIndex..., in: line)
        let matches = pattern?.matches(in: line, range: range) ?? []
        for match in matches {
            // Skip %DV figures ("12%").
            if match.range(at: 3).location != NSNotFound { continue }
            guard let valueRange = Range(match.range(at: 1), in: line) else { continue }
            let raw = String(line[valueRange]).replacingOccurrences(of: ",", with: ".")
            guard let value = Double(raw) else { continue }
            var unit: String?
            if match.range(at: 2).location != NSNotFound,
               let unitRange = Range(match.range(at: 2), in: line)
            {
                unit = String(line[unitRange]).lowercased()
            }
            return (value, unit)
        }
        return nil
    }

    // MARK: Keyword matchers (longest first)

    private struct Matcher {
        let keyword: String
        let key: NutrientKey
        /// Converts the raw (value, unit) pair into the nutrient's base unit.
        let convert: (Double, String?) -> Double
    }

    private static let matchers: [Matcher] = {
        // Plain unit normalization: g→g, mg→mg, mcg→mcg.
        func plain(_ key: NutrientKey) -> (Double, String?) -> Double {
            { value, unit in convertUnit(value, from: unit, to: key.unit) }
        }
        var list: [Matcher] = [
            Matcher(keyword: "saturated fat", key: .saturatedFat, convert: plain(.saturatedFat)),
            Matcher(keyword: "trans fat", key: .transFat, convert: plain(.transFat)),
            Matcher(keyword: "dietary fiber", key: .fiber, convert: plain(.fiber)),
            Matcher(keyword: "dietary fibre", key: .fiber, convert: plain(.fiber)),
            Matcher(keyword: "total fat", key: .fat, convert: plain(.fat)),
            Matcher(keyword: "total carbohydrate", key: .carbs, convert: plain(.carbs)),
            Matcher(keyword: "total sugars", key: .sugar, convert: plain(.sugar)),
            Matcher(keyword: "carbohydrate", key: .carbs, convert: plain(.carbs)),
            Matcher(keyword: "sugars", key: .sugar, convert: plain(.sugar)),
            Matcher(keyword: "sugar", key: .sugar, convert: plain(.sugar)),
            Matcher(keyword: "protein", key: .protein, convert: plain(.protein)),
            Matcher(keyword: "cholesterol", key: .cholesterol, convert: plain(.cholesterol)),
            Matcher(keyword: "potassium", key: .potassium, convert: plain(.potassium)),
            Matcher(keyword: "calcium", key: .calcium, convert: plain(.calcium)),
            Matcher(keyword: "magnesium", key: .magnesium, convert: plain(.magnesium)),
            Matcher(keyword: "phosphorus", key: .phosphorus, convert: plain(.phosphorus)),
            Matcher(keyword: "selenium", key: .selenium, convert: plain(.selenium)),
            Matcher(keyword: "iodine", key: .iodine, convert: plain(.iodine)),
            Matcher(keyword: "caffeine", key: .caffeine, convert: plain(.caffeine)),
            Matcher(keyword: "alcohol", key: .alcohol, convert: plain(.alcohol)),
            Matcher(keyword: "vitamin a", key: .vitaminA, convert: plain(.vitaminA)),
            Matcher(keyword: "vitamin c", key: .vitaminC, convert: plain(.vitaminC)),
            Matcher(keyword: "vitamin d", key: .vitaminD, convert: plain(.vitaminD)),
            Matcher(keyword: "vitamin e", key: .vitaminE, convert: plain(.vitaminE)),
            Matcher(keyword: "vitamin k", key: .vitaminK, convert: plain(.vitaminK)),
            Matcher(keyword: "vitamin b6", key: .vitaminB6, convert: plain(.vitaminB6)),
            Matcher(keyword: "vitamin b12", key: .vitaminB12, convert: plain(.vitaminB12)),
            Matcher(keyword: "thiamin", key: .thiamin, convert: plain(.thiamin)),
            Matcher(keyword: "riboflavin", key: .riboflavin, convert: plain(.riboflavin)),
            Matcher(keyword: "niacin", key: .niacin, convert: plain(.niacin)),
            Matcher(keyword: "folate", key: .folate, convert: plain(.folate)),
            Matcher(keyword: "folic acid", key: .folate, convert: plain(.folate)),
            Matcher(keyword: "pyridoxine", key: .vitaminB6, convert: plain(.vitaminB6)),
            Matcher(keyword: "cobalamin", key: .vitaminB12, convert: plain(.vitaminB12)),
            Matcher(keyword: "copper", key: .copper, convert: plain(.copper)),
            Matcher(keyword: "manganese", key: .manganese, convert: plain(.manganese)),
            Matcher(keyword: "zinc", key: .zinc, convert: plain(.zinc)),
            Matcher(keyword: "iron", key: .iron, convert: plain(.iron)),
            Matcher(keyword: "fibre", key: .fiber, convert: plain(.fiber)),
            Matcher(keyword: "fiber", key: .fiber, convert: plain(.fiber)),
            Matcher(keyword: "fat", key: .fat, convert: plain(.fat)),
            // Specials must come after their plain counterparts can't
            // shadow them: "salt" contains no other keyword; "sodium" and
            // "energy"/"calories" are checked here to keep ordering explicit.
            Matcher(keyword: "salt", key: .sodium, convert: { value, unit in
                // Salt (g) → sodium (mg): 1 g salt ≈ 400 mg sodium.
                convertUnit(value, from: unit ?? "g", to: "g") * 400
            }),
            Matcher(keyword: "sodium", key: .sodium, convert: plain(.sodium)),
            Matcher(keyword: "energy", key: .calories, convert: { value, unit in
                unit == "kj" ? value / 4.184 : value
            }),
            Matcher(keyword: "calories", key: .calories, convert: { value, _ in value }),
        ]
        // Longest keyword first so "saturated fat" beats "fat".
        list.sort { $0.keyword.count > $1.keyword.count }
        return list
    }()

    /// Converts between g / mg / mcg (and kcal for energy).
    private static func convertUnit(_ value: Double, from unit: String?, to base: String) -> Double {
        func multiplier(_ unit: String?) -> Double {
            switch unit?.lowercased() {
            case "g": return 1
            case "mg": return 1_000
            case "mcg", "µg", "μg": return 1_000_000
            case "kcal": return 1
            default:
                // No unit printed: assume the value is already in the base unit.
                return multiplier(base)
            }
        }
        return value * multiplier(unit) / multiplier(base)
    }
}
