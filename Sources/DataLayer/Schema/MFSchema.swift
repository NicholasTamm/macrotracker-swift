//  MFSchema.swift
//  DataLayer — versioned schema and migration plan.
//
//  v1 is the baseline (first public data model). To evolve the model:
//    1. Add `MFSchemaV2: VersionedSchema` listing the new model set.
//    2. Append it to `MFSchemaMigrationPlan.schemas`.
//    3. Add a `MigrationStage` (`.lightweight` for additive changes,
//       custom for renames/transforms).
//  See MIGRATIONS.md for the full playbook and CloudKit constraints.

import Foundation
import SwiftData

public enum MFSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            FoodItem.self,
            RecipeIngredient.self,
            LogEntry.self,
            LogDay.self,
            WeightEntry.self,
            BodyMeasurement.self,
            ProgressPhoto.self,
            StepEntry.self,
            Habit.self,
            HabitCompletion.self,
            CycleEntry.self,
            ProgramSettings.self,
            NutrientTarget.self,
            MacroDayOverride.self,
            ExpenditureSnapshot.self,
            CheckInRecord.self,
            // NOTE: OpenFoodFactsCacheEntry is deliberately NOT in the
            // versioned schema — it lives in the local-only store
            // configuration (see MFModelContainerFactory) and never syncs.
        ]
    }
}

public enum MFSchemaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [MFSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        // v1 is the baseline — no stages yet.
        []
    }
}

// MARK: - Container factory

/// Builds the app's `ModelContainer`.
///
/// Two store configurations:
/// - `"synced"`: all user data. CloudKit-capable — pass a container
///   identifier to sync via the user's private database.
/// - `"local"`: `OpenFoodFactsCacheEntry` only. Never synced (caches are
///   device-local by design).
public enum MFModelContainerFactory {
    public enum Error: Swift.Error {
        case cloudKitRequestedWithoutIdentifier
    }

    /// - Parameters:
    ///   - inMemory: `true` for tests / previews (no disk persistence).
    ///   - cloudKitIdentifier: e.g. `"iCloud.com.example.macroclone"`. When
    ///     non-nil the synced store uses the private CloudKit database.
    ///     Requires the CloudKit capability in the Xcode target (see
    ///     MFSyncController docs and SETUP.md).
    public static func makeContainer(
        inMemory: Bool = false,
        cloudKitIdentifier: String? = nil
    ) throws -> ModelContainer {
        let syncedModels: [any PersistentModel.Type] = MFSchemaV1.models

        let syncedConfig: ModelConfiguration
        if inMemory {
            syncedConfig = ModelConfiguration(
                "synced",
                schema: Schema(syncedModels),
                isStoredInMemoryOnly: true
            )
        } else if let cloudKitIdentifier {
            syncedConfig = ModelConfiguration(
                "synced",
                schema: Schema(syncedModels),
                cloudKitDatabase: .private(cloudKitIdentifier)
            )
        } else {
            syncedConfig = ModelConfiguration(
                "synced",
                schema: Schema(syncedModels)
            )
        }

        let cacheConfig = ModelConfiguration(
            "local",
            schema: Schema([OpenFoodFactsCacheEntry.self]),
            isStoredInMemoryOnly: inMemory
        )

        return try ModelContainer(
            for: Schema(syncedModels + [OpenFoodFactsCacheEntry.self]),
            migrationPlan: MFSchemaMigrationPlan.self,
            configurations: [syncedConfig, cacheConfig]
        )
    }
}
