//  StepRepository.swift
//  DataLayer — step counts (written by HealthKitSync #9, read by coaching).

import Foundation
import SwiftData
import CoachingEngine

@MainActor
public protocol StepRepository {
    /// Upserts the step count for a log day (HealthKit re-deliveries update).
    func setSteps(_ steps: Double, for dayStart: Date, source: StepSource = .healthKit) throws
    func steps(from: Date, to: Date) throws -> [StepEntry]
    /// Day rollups for the coaching engine's step modifier.
    func stepDays(from: Date, to: Date) throws -> [StepDay]
}

@MainActor
public final class SwiftDataStepRepository: StepRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func setSteps(_ steps: Double, for dayStart: Date, source: StepSource = .healthKit) throws {
        let start = MFDates.startOfDay(dayStart)
        var descriptor = FetchDescriptor<StepEntry>(predicate: #Predicate { $0.dayStart == start })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            // HealthKit wins over manual on re-delivery; manual wins if newer.
            existing.steps = steps
            existing.source = source
            existing.updatedAt = Date()
        } else {
            context.insert(StepEntry(dayStart: start, steps: steps, source: source))
        }
        try context.save()
    }

    public func steps(from: Date, to: Date) throws -> [StepEntry] {
        let start = MFDates.startOfDay(from)
        let end = MFDates.startOfDay(to)
        let descriptor = FetchDescriptor<StepEntry>(
            predicate: #Predicate { $0.dayStart >= start && $0.dayStart <= end },
            sortBy: [SortDescriptor(\.dayStart)]
        )
        return try context.fetch(descriptor)
    }

    public func stepDays(from: Date, to: Date) throws -> [StepDay] {
        try steps(from: from, to: to).map {
            StepDay(date: $0.dayStart, steps: $0.steps)
        }
    }
}
