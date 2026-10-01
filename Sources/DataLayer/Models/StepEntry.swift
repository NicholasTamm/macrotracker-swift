//  StepEntry.swift
//  DataLayer — one day of step counts. Written by HealthKitSync (#9) and/or
//  manual entry; read by the coaching engine's step modifier.

import Foundation
import SwiftData

public enum StepSource: String, Codable, Sendable, CaseIterable {
    case healthKit
    case manual
}

@Model
public final class StepEntry {
    /// One record per log day.
    @Attribute(.unique) public var dayStart: Date
    public var steps: Double
    public var sourceRaw: String
    public var updatedAt: Date

    public init(dayStart: Date, steps: Double, source: StepSource = .healthKit) {
        self.dayStart = dayStart
        self.steps = steps
        self.sourceRaw = source.rawValue
        self.updatedAt = Date()
    }

    public var source: StepSource {
        get { StepSource(rawValue: sourceRaw) ?? .healthKit }
        set { sourceRaw = newValue.rawValue }
    }
}
