//  DataLayer.swift
//  DataLayer — persistent data model for everything the app tracks.
//
//  Module contract (see MODULE_MAP.md):
//  - Depends on DesignSystem and CoachingEngine only. Never on AppShell or
//    feature modules.
//  - Features program to the repository protocols in Repositories/ — never
//    to SwiftData directly. AppShell owns the single `DataStore` and injects
//    repositories into feature modules.
//
//  Contents:
//  - Models/        — SwiftData @Model classes (see models for delete rules)
//  - Schema/        — MFSchemaV1 (VersionedSchema), migration plan, seed DB
//  - Repositories/ — protocols + SwiftData implementations + DataStore
//  - Networking/    — Open Food Facts API v2 client
//  - Sync/          — CloudKit toggle (local-first; designed for sync)
//  - Mapping/       — DataLayer → CoachingEngine value-type mappings
//  - Support/       — date helpers
//
//  Food-database strategy: bundled seed DB (generic foods, original data)
//  + Open Food Facts integration for barcode lookup and search, with a
//  30-day local cache. Imported OFF products are persisted as FoodItems
//  (source: .openFoodFacts) so repeat searches hit the local DB.

import Foundation

/// Marker namespace for the DataLayer module.
public enum DataLayer {
    /// Current schema version (see MFSchemaV1).
    public static let schemaVersion = "1.0.0"
}
