//  CoachingHistory.swift
//  DataLayer — expenditure estimate history and weekly check-in records.
//  Append-only: the coaching engine's past decisions stay auditable.

import Foundation
import SwiftData

/// How an expenditure estimate was produced.
public enum ExpenditureMethod: String, Codable, Sendable, CaseIterable {
    /// Back-calculated from intake + weight trend (energy balance).
    case energyBalance
    /// Energy balance refined by the step-trend modifier.
    case stepAdjusted
    /// Initial estimate before enough data exists (estimation from profile).
    case initialEstimate

    public var displayName: String {
        switch self {
        case .energyBalance: return "Energy balance"
        case .stepAdjusted: return "Step adjusted"
        case .initialEstimate: return "Initial estimate"
        }
    }
}

/// One expenditure estimate snapshot (written by the weekly check-in and by
/// any on-demand re-estimation). Powers the expenditure chart (#8).
@Model
public final class ExpenditureSnapshot {
    #Index<ExpenditureSnapshot>([\.date])

    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var estimateKcal: Double
    /// 0…1 confidence in the estimate.
    public var confidence: Double
    public var methodRaw: String
    public var intakeDaysUsed: Int
    public var averageSteps: Double?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        estimateKcal: Double,
        confidence: Double,
        method: ExpenditureMethod,
        intakeDaysUsed: Int,
        averageSteps: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.estimateKcal = estimateKcal
        self.confidence = confidence
        self.methodRaw = method.rawValue
        self.intakeDaysUsed = intakeDaysUsed
        self.averageSteps = averageSteps
    }

    public var method: ExpenditureMethod {
        get { ExpenditureMethod(rawValue: methodRaw) ?? .energyBalance }
        set { methodRaw = newValue.rawValue }
    }
}

/// Record of one weekly check-in: what the engine recommended, what changed,
/// and whether the user applied it. The summary text is stored so the
/// Strategy screen can show past check-ins verbatim.
@Model
public final class CheckInRecord {
    #Index<CheckInRecord>([\.date])

    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var programStyleRaw: String
    public var assessmentRaw: String

    public var previousCalories: Double
    public var previousProteinGrams: Double
    public var previousFatGrams: Double
    public var previousCarbsGrams: Double

    public var newCalories: Double
    public var newProteinGrams: Double
    public var newFatGrams: Double
    public var newCarbsGrams: Double

    /// Whether the recommendation was applied (auto for coached, accepted
    /// by the user for collaborative, n/a for manual).
    public var wasApplied: Bool
    /// Adherence-neutral summary shown to the user.
    public var summaryText: String

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        programStyleRaw: String,
        assessmentRaw: String,
        previousCalories: Double,
        previousProteinGrams: Double,
        previousFatGrams: Double,
        previousCarbsGrams: Double,
        newCalories: Double,
        newProteinGrams: Double,
        newFatGrams: Double,
        newCarbsGrams: Double,
        wasApplied: Bool,
        summaryText: String
    ) {
        self.id = id
        self.date = date
        self.programStyleRaw = programStyleRaw
        self.assessmentRaw = assessmentRaw
        self.previousCalories = previousCalories
        self.previousProteinGrams = previousProteinGrams
        self.previousFatGrams = previousFatGrams
        self.previousCarbsGrams = previousCarbsGrams
        self.newCalories = newCalories
        self.newProteinGrams = newProteinGrams
        self.newFatGrams = newFatGrams
        self.newCarbsGrams = newCarbsGrams
        self.wasApplied = wasApplied
        self.summaryText = summaryText
    }
}
