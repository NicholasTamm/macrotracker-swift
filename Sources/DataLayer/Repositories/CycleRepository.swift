//  CycleRepository.swift
//  DataLayer — period tracking (one entry per day, upsert semantics).

import Foundation
import SwiftData

@MainActor
public protocol CycleRepository {
    @discardableResult
    func logEntry(dayStart: Date, flow: FlowIntensity, notes: String? = nil) throws -> CycleEntry
    func entries(from: Date, to: Date) throws -> [CycleEntry]
    func deleteEntry(_ entry: CycleEntry) throws
}

@MainActor
public final class SwiftDataCycleRepository: CycleRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func logEntry(dayStart: Date, flow: FlowIntensity, notes: String? = nil) throws -> CycleEntry {
        let start = MFDates.startOfDay(dayStart)
        var descriptor = FetchDescriptor<CycleEntry>(predicate: #Predicate { $0.dayStart == start })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.flow = flow
            existing.notes = notes
            existing.updatedAt = Date()
            try context.save()
            return existing
        }
        let entry = CycleEntry(dayStart: start, flow: flow, notes: notes)
        context.insert(entry)
        try context.save()
        return entry
    }

    public func entries(from: Date, to: Date) throws -> [CycleEntry] {
        let start = MFDates.startOfDay(from)
        let end = MFDates.startOfDay(to)
        let descriptor = FetchDescriptor<CycleEntry>(
            predicate: #Predicate { $0.dayStart >= start && $0.dayStart <= end },
            sortBy: [SortDescriptor(\.dayStart)]
        )
        return try context.fetch(descriptor)
    }

    public func deleteEntry(_ entry: CycleEntry) throws {
        context.delete(entry)
        try context.save()
    }
}
