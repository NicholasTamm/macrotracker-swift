//  DataStore.swift
//  DataLayer — composition root. AppShell creates ONE DataStore and injects
//  the repository protocols into feature modules; features never see
//  SwiftData types.
//
//  Wiring example (AppShell, issue #2):
//      let store = try DataStore()                       // throws on failure
//      ContentView()
//          .modelContainer(store.container)              // SwiftUI queries
//          .environment(\.foodRepository, store.foods)   // or @StateObject
//
//  CloudKit: construct with `cloudSync: true` (and set
//  `sync.cloudKitContainerIdentifier`) to use the private database.
//  Toggling sync at runtime requires rebuilding the store.

import Foundation
import SwiftData

@MainActor
public final class DataStore {
    public let container: ModelContainer
    public let context: ModelContext
    public let sync: MFSyncController
    public let photoStore: PhotoFileStore

    // Repository protocols — the only surface features consume.
    public let foods: any FoodRepository
    public let foodSearch: any FoodSearchService
    public let logs: any LogRepository
    public let weights: any WeightRepository
    public let measurements: any MeasurementRepository
    public let habits: any HabitRepository
    public let steps: any StepRepository
    public let cycles: any CycleRepository
    public let program: any ProgramRepository

    /// - Parameters:
    ///   - inMemory: `true` for tests/previews (no disk persistence, no seed).
    ///   - cloudSync: use the private CloudKit database for the synced store.
    ///   - cloudKitContainerIdentifier: the iCloud container id (from the
    ///     app's entitlements); required when `cloudSync` is true.
    ///   - seed: import the bundled seed food database on first launch.
    public init(
        inMemory: Bool = false,
        cloudSync: Bool = false,
        cloudKitContainerIdentifier: String? = nil,
        seed: Bool = true
    ) throws {
        sync = MFSyncController()
        sync.cloudKitContainerIdentifier = cloudKitContainerIdentifier
        let containerIdentifier = cloudSync ? cloudKitContainerIdentifier : nil
        container = try MFModelContainerFactory.makeContainer(
            inMemory: inMemory,
            cloudKitIdentifier: containerIdentifier
        )
        context = ModelContext(container)
        photoStore = try PhotoFileStore()

        let foodRepo = SwiftDataFoodRepository(context: context)
        foods = foodRepo
        foodSearch = MFFoodSearchService(context: context, foods: foodRepo)
        logs = SwiftDataLogRepository(context: context)
        weights = SwiftDataWeightRepository(context: context)
        measurements = SwiftDataMeasurementRepository(context: context, photoStore: photoStore)
        habits = SwiftDataHabitRepository(context: context)
        steps = SwiftDataStepRepository(context: context)
        cycles = SwiftDataCycleRepository(context: context)
        program = SwiftDataProgramRepository(context: context)

        if seed && !inMemory {
            try SeedDataLoader.loadIfNeeded(into: context)
        }
    }

    /// Erases ALL user data (database rows + progress-photo files) and
    /// resets settings to defaults. The seed database is NOT reimported
    /// here — the existing seed rows are untouched (they're not user data).
    public func resetAllData() throws {
        // Delete photo files first (rows are deleted by the repository).
        let photos = try measurements.photos(
            from: .distantPast,
            to: .distantFuture
        )
        for photo in photos {
            try? photoStore.delete(relativePath: photo.relativePath)
            if let thumbnail = photo.thumbnailRelativePath {
                try? photoStore.delete(relativePath: thumbnail)
            }
        }
        try program.resetAllData()
    }
}
