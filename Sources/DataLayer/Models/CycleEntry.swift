//  CycleEntry.swift
//  DataLayer — period tracking (one entry per day).

import Foundation
import SwiftData

public enum FlowIntensity: String, Codable, Sendable, CaseIterable {
    case spotting
    case light
    case medium
    case heavy

    public var displayName: String {
        switch self {
        case .spotting: return "Spotting"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        }
    }
}

@Model
public final class CycleEntry {
    /// One entry per log day.
    @Attribute(.unique) public var dayStart: Date
    public var flowRaw: String
    public var notes: String?
    public var updatedAt: Date

    public init(dayStart: Date, flow: FlowIntensity, notes: String? = nil) {
        self.dayStart = dayStart
        self.flowRaw = flow.rawValue
        self.notes = notes
        self.updatedAt = Date()
    }

    public var flow: FlowIntensity {
        get { FlowIntensity(rawValue: flowRaw) ?? .light }
        set { flowRaw = newValue.rawValue }
    }
}
