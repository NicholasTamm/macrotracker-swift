//  Habit.swift
//  DataLayer — habit tracking for logging streaks (food logging, weigh-ins,
//  photos, plus user-defined habits).

import Foundation
import SwiftData

public enum HabitKind: String, Codable, Sendable, CaseIterable {
    case foodLogging
    case weighIn
    case progressPhoto
    case custom

    public var displayName: String {
        switch self {
        case .foodLogging: return "Log food"
        case .weighIn: return "Weigh in"
        case .progressPhoto: return "Progress photo"
        case .custom: return "Custom"
        }
    }
}

@Model
public final class Habit {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var kindRaw: String
    public var targetPerWeek: Int
    public var isActive: Bool
    public var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    public var completions: [HabitCompletion] = []

    public init(
        id: UUID = UUID(),
        name: String,
        kind: HabitKind = .custom,
        targetPerWeek: Int = 7,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.targetPerWeek = targetPerWeek
        self.isActive = isActive
        self.createdAt = Date()
    }

    public var kind: HabitKind {
        get { HabitKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
public final class HabitCompletion {
    #Index<HabitCompletion>([\.dayStart])

    @Attribute(.unique) public var id: UUID
    /// Log-day this completion counts toward.
    public var dayStart: Date
    /// 1.0 = done; allows partial credit for quantitative habits.
    public var value: Double
    public var note: String?

    @Relationship(deleteRule: .nullify, inverse: \Habit.completions)
    public var habit: Habit?

    public init(
        id: UUID = UUID(),
        dayStart: Date,
        value: Double = 1,
        note: String? = nil,
        habit: Habit? = nil
    ) {
        self.id = id
        self.dayStart = dayStart
        self.value = value
        self.note = note
        self.habit = habit
    }

    public var isComplete: Bool { value >= 1 }
}
