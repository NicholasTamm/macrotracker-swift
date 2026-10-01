//  WeightRepository.swift
//  DataLayer — weigh-in CRUD + coaching mapping (WeightSample).

import Foundation
import SwiftData
import CoachingEngine

@MainActor
public protocol WeightRepository {
    @discardableResult
    func logWeight(_ weightKg: Double, timestamp: Date = Date(), note: String? = nil, source: WeightSource = .manual) throws -> WeightEntry
    func weights(from: Date, to: Date) throws -> [WeightEntry]
    func latestWeight() throws -> WeightEntry?
    func deleteWeight(_ entry: WeightEntry) throws
    /// Samples for the coaching engine's weight-trend analysis.
    func samples(from: Date, to: Date) throws -> [WeightSample]
}

@MainActor
public final class SwiftDataWeightRepository: WeightRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func logWeight(
        _ weightKg: Double,
        timestamp: Date = Date(),
        note: String? = nil,
        source: WeightSource = .manual
    ) throws -> WeightEntry {
        guard weightKg > 0, weightKg < 1000 else {
            throw MFDataError.invalidInput("Weight looks out of range.")
        }
        let entry = WeightEntry(timestamp: timestamp, weightKg: weightKg, source: source, note: note)
        context.insert(entry)
        try context.save()
        return entry
    }

    public func weights(from: Date, to: Date) throws -> [WeightEntry] {
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.timestamp >= from && $0.timestamp <= to },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try context.fetch(descriptor)
    }

    public func latestWeight() throws -> WeightEntry? {
        var descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    public func deleteWeight(_ entry: WeightEntry) throws {
        context.delete(entry)
        try context.save()
    }

    public func samples(from: Date, to: Date) throws -> [WeightSample] {
        try weights(from: from, to: to).map {
            WeightSample(date: $0.timestamp, weightKg: $0.weightKg)
        }
    }
}
