//  MFHealthKitTypes.swift
//  HealthKitSync — shared types for the Apple Health integration (issue #9).
//
//  Locked decisions:
//  - Weight + steps sync only. Calorie estimates from watches and other apps
//    are deliberately NEVER imported (matches MacroFactor's stance).
//  - Manual entries always win over synced values (the documented conflict
//    rule). Steps feed the coaching engine's expenditure modifier through
//    DataLayer's StepRepository → StepDay mapping.

import Foundation
import HealthKit

/// The HealthKit surface this app uses.
///
/// Authorization scope (issue #9, confirmed 2026-09-28 by the #4/#12 review):
/// - Read: body mass, steps, height, body fat, lean body mass.
/// - Write: body mass (manual weigh-in write-back).
/// - Never requested, never imported: active/basal energy burned, and the
///   nutrition read types (dietary energy, water). The #4 food-logging module
///   never consumed them — it uses its own nutrient database — and importing
///   nutrition samples from Health would conflict with manual log entries
///   (there is no conflict story for nutrition, unlike weight/steps where
///   manual entries win). Requesting HealthKit types the app never uses is
///   also an App Store review risk, so they stay out of the auth request
///   until a real nutrition-import feature is designed.
public enum MFHealthKitTypes {
    public static var bodyMass: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    }
    public static var stepCount: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .stepCount)!
    }
    public static var height: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .height)!
    }
    public static var bodyFatPercentage: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
    }
    public static var leanBodyMass: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .leanBodyMass)!
    }

    /// Types the app asks HealthKit to read: weight + steps sync only.
    public static var readTypes: Set<HKObjectType> {
        [bodyMass, stepCount, height, bodyFatPercentage, leanBodyMass]
    }

    /// Types the app asks HealthKit to write. Body mass only: manual
    /// weigh-ins logged in-app are written back so the Health app stays in
    /// sync.
    public static var writeTypes: Set<HKSampleType> {
        [bodyMass]
    }
}

/// Connection state shown in the sync-status UI.
public enum MFHealthConnectionState: String, Sendable, CaseIterable {
    /// HealthKit isn't available on this device (e.g. iPad).
    case unsupported
    /// Never connected.
    case notConnected
    /// The user denied access (or revoked it later in Settings).
    case denied
    /// At least one of weight/steps is authorized for reading.
    case connected
}

/// The result of one import/sync pass.
public struct MFHealthSyncSummary: Sendable {
    public var weightsImported: Int = 0
    public var stepDaysUpdated: Int = 0
    /// Samples/days where a manual entry existed, so the synced value was
    /// discarded. Manual entries always win.
    public var manualConflictsKept: Int = 0
    public var completedAt: Date = Date()

    public init(
        weightsImported: Int = 0,
        stepDaysUpdated: Int = 0,
        manualConflictsKept: Int = 0,
        completedAt: Date = Date()
    ) {
        self.weightsImported = weightsImported
        self.stepDaysUpdated = stepDaysUpdated
        self.manualConflictsKept = manualConflictsKept
        self.completedAt = completedAt
    }

    public var totalChanges: Int { weightsImported + stepDaysUpdated }
}

public enum MFHealthSyncError: Error, LocalizedError {
    case healthKitUnavailable
    case authorizationDenied
    case notConfigured
    case queryFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .healthKitUnavailable:
            return "Apple Health isn't available on this device."
        case .authorizationDenied:
            return "Apple Health access wasn't granted."
        case .notConfigured:
            return "Health sync isn't set up yet."
        case .queryFailed(let underlying):
            return underlying.localizedDescription
        }
    }
}
