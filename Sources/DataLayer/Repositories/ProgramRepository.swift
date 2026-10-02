//  ProgramRepository.swift
//  DataLayer — coaching program settings (singleton), nutrient targets,
//  per-weekday macro overrides, expenditure history, check-in records.

import Foundation
import SwiftData
import CoachingEngine

@MainActor
public protocol ProgramRepository {
    // MARK: Settings (singleton)
    func settings() throws -> ProgramSettings
    func updateSettings(_ transform: (ProgramSettings) -> Void) throws

    // MARK: Nutrient targets
    func nutrientTargets() throws -> [NutrientTarget]
    func target(for key: NutrientKey) throws -> NutrientTarget?
    func setTarget(_ key: NutrientKey, value: Double, isCustom: Bool) throws
    func resetTargetsToDefaults() throws

    // MARK: Day overrides
    func dayOverrides() throws -> [MacroDayOverride]
    func setDayOverride(weekday: Int, targets: MacroTargets) throws
    func clearDayOverride(weekday: Int) throws

    // MARK: Expenditure history
    @discardableResult
    func recordExpenditureSnapshot(_ snapshot: ExpenditureSnapshot) throws -> ExpenditureSnapshot
    func expenditureHistory(from: Date, to: Date) throws -> [ExpenditureSnapshot]
    func latestExpenditureSnapshot() throws -> ExpenditureSnapshot?

    // MARK: Check-ins
    @discardableResult
    func recordCheckIn(_ record: CheckInRecord) throws -> CheckInRecord
    func checkInHistory(from: Date, to: Date) throws -> [CheckInRecord]

    // MARK: Coaching mapping
    /// Builds the CoachingEngine's `CoachingProgram` from stored settings.
    func coachingProgram() throws -> CoachingProgram

    // MARK: Danger zone
    /// Deletes ALL user data (settings reset to defaults, everything else
    /// purged). Used by "Erase all data" in Settings.
    func resetAllData() throws
}

// MARK: - Defaulted convenience overloads
// Protocol requirements can't carry default arguments, so the defaults live
// here and forward to the requirement.

@MainActor
extension ProgramRepository {
    func setTarget(_ key: NutrientKey, value: Double, isCustom: Bool = true) throws {
        try setTarget(key, value: value, isCustom: isCustom)
    }
}

@MainActor
public final class SwiftDataProgramRepository: ProgramRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: Settings

    public func settings() throws -> ProgramSettings {
        var descriptor = FetchDescriptor<ProgramSettings>(
            predicate: #Predicate { $0.id == "singleton" }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let settings = ProgramSettings()
        context.insert(settings)
        try seedDefaultNutrientTargets(into: settings)
        try context.save()
        return settings
    }

    public func updateSettings(_ transform: (ProgramSettings) -> Void) throws {
        let current = try settings()
        transform(current)
        current.updatedAt = Date()
        try context.save()
    }

    // MARK: Nutrient targets

    public func nutrientTargets() throws -> [NutrientTarget] {
        let settings = try settings()
        let settingsID = settings.id
        let descriptor = FetchDescriptor<NutrientTarget>(
            predicate: #Predicate { $0.settings?.id == settingsID }
        )
        return try context.fetch(descriptor)
    }

    public func target(for key: NutrientKey) throws -> NutrientTarget? {
        let raw = key.rawValue
        let settingsID = try settings().id
        var descriptor = FetchDescriptor<NutrientTarget>(
            predicate: #Predicate { $0.settings?.id == settingsID && $0.nutrientKeyRaw == raw }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    public func setTarget(_ key: NutrientKey, value: Double, isCustom: Bool = true) throws {
        guard value >= 0 else { throw MFDataError.invalidInput("Target can't be negative.") }
        let settings = try settings()
        if let existing = try target(for: key) {
            existing.targetValue = value
            existing.isCustom = isCustom
        } else {
            let target = NutrientTarget(nutrientKey: key, targetValue: value, isCustom: isCustom)
            target.settings = settings
            context.insert(target)
        }
        try context.save()
    }

    public func resetTargetsToDefaults() throws {
        let settings = try settings()
        for target in try nutrientTargets() {
            context.delete(target)
        }
        try seedDefaultNutrientTargets(into: settings)
        try context.save()
    }

    /// Sensible daily defaults for micronutrients (general reference values).
    private func seedDefaultNutrientTargets(into settings: ProgramSettings) throws {
        let defaults: [(NutrientKey, Double)] = [
            (.fiber, 28), (.sugar, 50),
            (.saturatedFat, 20), (.cholesterol, 300),
            (.sodium, 2300), (.potassium, 3400),
            (.calcium, 1000), (.iron, 18), (.magnesium, 400),
            (.phosphorus, 700), (.zinc, 11), (.copper, 0.9), (.manganese, 2.3),
            (.vitaminA, 900), (.vitaminC, 90), (.vitaminD, 15),
            (.vitaminE, 15), (.vitaminK, 120),
            (.thiamin, 1.2), (.riboflavin, 1.3), (.niacin, 16),
            (.vitaminB6, 1.7), (.folate, 400), (.vitaminB12, 2.4),
            (.selenium, 55), (.iodine, 150), (.caffeine, 400),
        ]
        for (key, value) in defaults {
            let target = NutrientTarget(nutrientKey: key, targetValue: value, isCustom: false)
            target.settings = settings
            context.insert(target)
        }
    }

    // MARK: Day overrides

    public func dayOverrides() throws -> [MacroDayOverride] {
        let settingsID = try settings().id
        let descriptor = FetchDescriptor<MacroDayOverride>(
            predicate: #Predicate { $0.settings?.id == settingsID },
            sortBy: [SortDescriptor(\.weekday)]
        )
        return try context.fetch(descriptor)
    }

    public func setDayOverride(weekday: Int, targets: MacroTargets) throws {
        guard (1...7).contains(weekday) else {
            throw MFDataError.invalidInput("Weekday must be 1 (Sunday)…7 (Saturday).")
        }
        let settings = try settings()
        let settingsID = settings.id
        var descriptor = FetchDescriptor<MacroDayOverride>(
            predicate: #Predicate { $0.settings?.id == settingsID && $0.weekday == weekday }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.calories = targets.calories
            existing.proteinGrams = targets.proteinGrams
            existing.fatGrams = targets.fatGrams
            existing.carbsGrams = targets.carbsGrams
        } else {
            let override = MacroDayOverride(
                weekday: weekday,
                calories: targets.calories,
                proteinGrams: targets.proteinGrams,
                fatGrams: targets.fatGrams,
                carbsGrams: targets.carbsGrams
            )
            override.settings = settings
            context.insert(override)
        }
        try context.save()
    }

    public func clearDayOverride(weekday: Int) throws {
        let settingsID = try settings().id
        let descriptor = FetchDescriptor<MacroDayOverride>(
            predicate: #Predicate { $0.settings?.id == settingsID && $0.weekday == weekday }
        )
        for override in try context.fetch(descriptor) {
            context.delete(override)
        }
        try context.save()
    }

    // MARK: Expenditure history

    @discardableResult
    public func recordExpenditureSnapshot(_ snapshot: ExpenditureSnapshot) throws -> ExpenditureSnapshot {
        context.insert(snapshot)
        let settings = try settings()
        settings.expenditureEstimateKcal = snapshot.estimateKcal
        settings.expenditureUpdatedAt = snapshot.date
        try context.save()
        return snapshot
    }

    public func expenditureHistory(from: Date, to: Date) throws -> [ExpenditureSnapshot] {
        let descriptor = FetchDescriptor<ExpenditureSnapshot>(
            predicate: #Predicate { $0.date >= from && $0.date <= to },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    public func latestExpenditureSnapshot() throws -> ExpenditureSnapshot? {
        var descriptor = FetchDescriptor<ExpenditureSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: Check-ins

    @discardableResult
    public func recordCheckIn(_ record: CheckInRecord) throws -> CheckInRecord {
        context.insert(record)
        if record.wasApplied {
            let settings = try settings()
            settings.currentCalories = record.newCalories
            settings.currentProteinGrams = record.newProteinGrams
            settings.currentFatGrams = record.newFatGrams
            settings.currentCarbsGrams = record.newCarbsGrams
        }
        try context.save()
        return record
    }

    public func checkInHistory(from: Date, to: Date) throws -> [CheckInRecord] {
        let descriptor = FetchDescriptor<CheckInRecord>(
            predicate: #Predicate { $0.date >= from && $0.date <= to },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: Coaching mapping

    public func coachingProgram() throws -> CoachingProgram {
        let s = try settings()
        var overrides: [Int: MacroTargets] = [:]
        for o in try dayOverrides() {
            overrides[o.weekday] = o.macroTargets
        }
        return CoachingProgram(
            goalType: s.goalType,
            programStyle: s.programStyle,
            dietPlan: s.dietPlan,
            rateOfChangeKgPerWeek: s.rateOfChangeKgPerWeek,
            proteinGramsPerKg: s.proteinGramsPerKg,
            fastingWeekdays: s.fastingWeekdays,
            fastingDayCalorieFraction: s.fastingDayCalorieFraction,
            dayOverrides: overrides,
            weightUnit: s.weightUnit
        )
    }

    // MARK: Danger zone

    public func resetAllData() throws {
        // Seed foods are bundled content, not user data — keep them.
        let nonSeed = FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.sourceRaw != "seedDatabase" }
        )
        for food in try context.fetch(nonSeed) {
            context.delete(food)
        }
        try deleteAll(RecipeIngredient.self)
        try deleteAll(LogEntry.self)
        try deleteAll(LogDay.self)
        try deleteAll(WeightEntry.self)
        try deleteAll(BodyMeasurement.self)
        try deleteAll(ProgressPhoto.self)
        try deleteAll(StepEntry.self)
        try deleteAll(Habit.self)
        try deleteAll(CycleEntry.self)
        try deleteAll(ExpenditureSnapshot.self)
        try deleteAll(CheckInRecord.self)
        // ProgramSettings keeps its row but resets to defaults.
        for target in try nutrientTargets() { context.delete(target) }
        for override in try dayOverrides() { context.delete(override) }
        let settings = try settings()
        let fresh = ProgramSettings()
        settings.goalTypeRaw = fresh.goalTypeRaw
        settings.programStyleRaw = fresh.programStyleRaw
        settings.dietPlanRaw = fresh.dietPlanRaw
        settings.rateOfChangeKgPerWeek = fresh.rateOfChangeKgPerWeek
        settings.proteinGramsPerKg = fresh.proteinGramsPerKg
        settings.fastingWeekdayMask = fresh.fastingWeekdayMask
        settings.fastingDayCalorieFraction = fresh.fastingDayCalorieFraction
        settings.weightUnitRaw = fresh.weightUnitRaw
        settings.currentCalories = 0
        settings.currentProteinGrams = 0
        settings.currentFatGrams = 0
        settings.currentCarbsGrams = 0
        settings.expenditureEstimateKcal = nil
        settings.expenditureUpdatedAt = nil
        try seedDefaultNutrientTargets(into: settings)
        try context.save()
        // NOTE: progress-photo files are deleted by the caller via
        // MeasurementRepository (DataStore.resetAllData handles this).
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        for object in try context.fetch(FetchDescriptor<T>()) {
            context.delete(object)
        }
    }
}
