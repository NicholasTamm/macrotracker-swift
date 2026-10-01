//  WeightEntry.swift
//  DataLayer — weigh-ins. Storage is always kilograms; display units are a
//  presentation concern (see CoachingEngine.WeightUnit).

import Foundation
import SwiftData

public enum WeightSource: String, Codable, Sendable, CaseIterable {
    case manual
    case healthKit
}

@Model
public final class WeightEntry {
    #Index<WeightEntry>([\.timestamp])

    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    /// Kilograms, always.
    public var weightKg: Double
    public var sourceRaw: String
    public var note: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        weightKg: Double,
        source: WeightSource = .manual,
        note: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.weightKg = weightKg
        self.sourceRaw = source.rawValue
        self.note = note
    }

    public var source: WeightSource {
        get { WeightSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}
