import Foundation

/// A named unit of a food. Nutrients remain stored per 100 g on FoodItem.
public struct ServingSize: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var grams: Double

    public init(id: String = UUID().uuidString, name: String, grams: Double) {
        self.id = id
        self.name = name
        self.grams = grams
    }
}

/// The portion chosen for one log entry. It is a snapshot: later food edits
/// cannot change the meaning of an already logged amount.
public struct ServingSelection: Equatable, Sendable {
    public var name: String
    public var gramsPerUnit: Double
    public var quantity: Double

    public init(name: String, gramsPerUnit: Double, quantity: Double) {
        self.name = name
        self.gramsPerUnit = gramsPerUnit
        self.quantity = quantity
    }

    public var totalGrams: Double { gramsPerUnit * quantity }
}

public enum ServingAmountError: Error, LocalizedError, Equatable {
    case notNumeric
    case notPositive
    case tooPrecise
    case tooLarge

    public var errorDescription: String? {
        switch self {
        case .notNumeric: return "Enter a numeric amount."
        case .notPositive: return "Amount must be greater than zero."
        case .tooPrecise: return "Use at most two decimal places."
        case .tooLarge: return "Maximum is 1,000 units or 100,000 g."
        }
    }
}

public enum ServingAmount {
    /// Decimal quantities from 0.01 to 1,000 with at most two places.
    /// A comma is accepted as a decimal separator for decimal keyboards.
    public static func parse(_ text: String, gramsPerUnit: Double) throws -> Double {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !value.isEmpty, let amount = Double(value), amount.isFinite else {
            throw ServingAmountError.notNumeric
        }
        guard amount > 0 else { throw ServingAmountError.notPositive }
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, value.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }) else {
            throw ServingAmountError.notNumeric
        }
        guard (parts.count == 1 || parts[1].count <= 2) else {
            throw ServingAmountError.tooPrecise
        }
        guard amount <= 1000, gramsPerUnit > 0, gramsPerUnit.isFinite,
              amount * gramsPerUnit <= 100_000 else {
            throw ServingAmountError.tooLarge
        }
        return amount
    }
}
