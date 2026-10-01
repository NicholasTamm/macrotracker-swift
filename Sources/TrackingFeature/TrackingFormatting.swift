import Foundation
import SwiftUI
import DesignSystem
import DataLayer
import CoachingEngine

// MARK: - TrackingFormatting

/// Shared, original formatting helpers for the tracking module.
public enum TrackingFormatting {
    // MARK: Weight

    /// "172.4 lb" / "78.2 kg" from stored kilograms.
    public static func weight(_ kg: Double, unit: WeightUnit) -> String {
        let value = unit.fromKilograms(kg)
        let suffix = unit == .pounds ? "lb" : "kg"
        return "\(String(format: "%.1f", value)) \(suffix)"
    }

    /// Signed delta string: "−2.3 lb" / "+0.4 kg".
    public static func weightDelta(_ kg: Double, unit: WeightUnit) -> String {
        let value = unit.fromKilograms(kg)
        let sign = value > 0.0005 ? "+" : (value < -0.0005 ? "−" : "")
        let suffix = unit == .pounds ? "lb" : "kg"
        return "\(sign)\(String(format: "%.1f", abs(value))) \(suffix)"
    }

    /// Whether a trend delta counts as "good" for the given program goal.
    /// Maintain treats near-zero change (within 0.25 kg) as good.
    public static func deltaIsGood(_ changeKg: Double, goalType: GoalType) -> Bool {
        switch goalType {
        case .cut: return changeKg <= 0
        case .bulk: return changeKg >= 0
        case .maintain: return abs(changeKg) <= 0.25
        }
    }

    // MARK: Length (body measurements)

    /// Convert stored centimeters to the display unit.
    public static func length(_ cm: Double, metric: Bool) -> Double {
        metric ? cm : cm / 2.54
    }

    /// "32.5 in" / "82.6 cm" from stored centimeters.
    public static func measurement(_ cm: Double, metric: Bool) -> String {
        let value = length(cm, metric: metric)
        return "\(String(format: "%.1f", value)) \(metric ? "cm" : "in")"
    }

    /// Signed measurement delta, same unit convention.
    public static func measurementDelta(_ cm: Double, metric: Bool) -> String {
        let value = length(cm, metric: metric)
        let sign = value > 0.0005 ? "+" : (value < -0.0005 ? "−" : "")
        return "\(sign)\(String(format: "%.1f", abs(value))) \(metric ? "cm" : "in")"
    }

    // MARK: Dates

    public static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    public static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// "Sep 28" for chart axes and photo tiles.
    public static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    /// Steps as a plain integer with grouping separators.
    public static func steps(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }
}

// MARK: - LengthUnit app storage key

/// Shared display preference for body measurements (centimeters vs inches).
/// Defaults from the device locale's measurement system.
public enum TrackingLengthUnit: String, CaseIterable {
    case metric
    case imperial

    public var displayName: String {
        switch self {
        case .metric: return "cm"
        case .imperial: return "in"
        }
    }

    public static var deviceDefault: TrackingLengthUnit {
        Locale.current.measurementSystem == .us ? .imperial : .metric
    }
}
