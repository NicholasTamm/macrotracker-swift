//  BodyMeasurement.swift
//  DataLayer — tape-measure body measurements. Stored in centimeters;
//  display units are a presentation concern.

import Foundation
import SwiftData

@Model
public final class BodyMeasurement {

    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var note: String?

    // All values centimeters, optional (users track what they want).
    public var chestCm: Double?
    public var waistCm: Double?
    public var hipsCm: Double?
    public var thighCm: Double?
    public var armCm: Double?
    public var neckCm: Double?
    public var calfCm: Double?
    public var shoulderCm: Double?
    public var bodyFatPercent: Double?

    public init(id: UUID = UUID(), date: Date = Date(), note: String? = nil) {
        self.id = id
        self.date = date
        self.note = note
    }

    /// True when at least one measurement is present.
    public var hasAnyMeasurement: Bool {
        chestCm != nil || waistCm != nil || hipsCm != nil || thighCm != nil
            || armCm != nil || neckCm != nil || calfCm != nil || shoulderCm != nil
            || bodyFatPercent != nil
    }
}

/// Identifies which tape measurement a value refers to (charts, #8).
public enum MeasurementSite: String, CaseIterable, Sendable {
    case chest, waist, hips, thigh, arm, neck, calf, shoulder, bodyFat

    public var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .waist: return "Waist"
        case .hips: return "Hips"
        case .thigh: return "Thigh"
        case .arm: return "Arm"
        case .neck: return "Neck"
        case .calf: return "Calf"
        case .shoulder: return "Shoulder"
        case .bodyFat: return "Body fat"
        }
    }

    public var unit: String { self == .bodyFat ? "%" : "cm" }
}

extension BodyMeasurement {
    public func value(for site: MeasurementSite) -> Double? {
        switch site {
        case .chest: return chestCm
        case .waist: return waistCm
        case .hips: return hipsCm
        case .thigh: return thighCm
        case .arm: return armCm
        case .neck: return neckCm
        case .calf: return calfCm
        case .shoulder: return shoulderCm
        case .bodyFat: return bodyFatPercent
        }
    }

    public func setValue(_ value: Double?, for site: MeasurementSite) {
        switch site {
        case .chest: chestCm = value
        case .waist: waistCm = value
        case .hips: hipsCm = value
        case .thigh: thighCm = value
        case .arm: armCm = value
        case .neck: neckCm = value
        case .calf: calfCm = value
        case .shoulder: shoulderCm = value
        case .bodyFat: bodyFatPercent = value
        }
    }
}
