//  MFSharedSnapshot.swift
//  EngagementFeature — the Codable snapshot shared with widgets and the
//  watch (issue #10).
//
//  Everything the WidgetKit extension and the watchOS app render comes from
//  this value type. It is deliberately UI-agnostic and Codable so it can be
//  written to the App Group container by the iOS app and read from an
//  extension or watchOS process without touching SwiftData.

import Foundation

// MARK: - MFSharedSnapshot

/// Today's nutrition state, published by ``MFSnapshotPublisher``.
///
/// - Note: All energy values are kilocalories; macros are grams; weight is
///   kilograms. Presentation (unit conversion, formatting) happens at the
///   rendering site.
public struct MFSharedSnapshot: Codable, Sendable, Equatable {
    public var generatedAt: Date
    /// Start of the day this snapshot describes (local calendar).
    public var dayStart: Date

    // Intake
    public var calories: Double
    public var proteinGrams: Double
    public var fatGrams: Double
    public var carbsGrams: Double
    public var entryCount: Int
    public var isDayComplete: Bool

    // Targets (after per-weekday overrides, if any)
    public var targetCalories: Double
    public var targetProteinGrams: Double
    public var targetFatGrams: Double
    public var targetCarbsGrams: Double

    // Weight / streak context
    public var latestWeightKg: Double?
    public var weightUnitRaw: String
    public var logStreakDays: Int

    public init(
        generatedAt: Date = Date(),
        dayStart: Date,
        calories: Double = 0,
        proteinGrams: Double = 0,
        fatGrams: Double = 0,
        carbsGrams: Double = 0,
        entryCount: Int = 0,
        isDayComplete: Bool = false,
        targetCalories: Double = 0,
        targetProteinGrams: Double = 0,
        targetFatGrams: Double = 0,
        targetCarbsGrams: Double = 0,
        latestWeightKg: Double? = nil,
        weightUnitRaw: String = "kilograms",
        logStreakDays: Int = 0
    ) {
        self.generatedAt = generatedAt
        self.dayStart = dayStart
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.carbsGrams = carbsGrams
        self.entryCount = entryCount
        self.isDayComplete = isDayComplete
        self.targetCalories = targetCalories
        self.targetProteinGrams = targetProteinGrams
        self.targetFatGrams = targetFatGrams
        self.targetCarbsGrams = targetCarbsGrams
        self.latestWeightKg = latestWeightKg
        self.weightUnitRaw = weightUnitRaw
        self.logStreakDays = logStreakDays
    }

    // MARK: Derived

    /// Calories still available today (can go negative when over target).
    public var remainingCalories: Double { targetCalories - calories }

    /// 0…1 progress toward the calorie target.
    public var calorieProgress: Double {
        guard targetCalories > 0 else { return 0 }
        return min(max(calories / targetCalories, 0), 1)
    }

    public func macroProgress(eaten: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(eaten / target, 0), 1)
    }

    public var proteinProgress: Double { macroProgress(eaten: proteinGrams, target: targetProteinGrams) }
    public var fatProgress: Double { macroProgress(eaten: fatGrams, target: targetFatGrams) }
    public var carbsProgress: Double { macroProgress(eaten: carbsGrams, target: targetCarbsGrams) }

    /// True when the snapshot is for a previous day (stale until the app
    /// republishes).
    public var isStale: Bool {
        !Calendar.current.isDate(dayStart, inSameDayAs: Date())
    }
}

// MARK: - Preview

public extension MFSharedSnapshot {
    /// Deterministic sample for widget placeholders and SwiftUI previews.
    static var preview: MFSharedSnapshot {
        let calendar = Calendar.current
        return MFSharedSnapshot(
            dayStart: calendar.startOfDay(for: Date()),
            calories: 1240,
            proteinGrams: 118,
            fatGrams: 42,
            carbsGrams: 121,
            entryCount: 3,
            targetCalories: 2200,
            targetProteinGrams: 165,
            targetFatGrams: 73,
            targetCarbsGrams: 220,
            latestWeightKg: 78.4,
            weightUnitRaw: "kilograms",
            logStreakDays: 12
        )
    }
}
