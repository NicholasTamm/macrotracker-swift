# DataLayer migrations

How the data model evolves without losing user data.

## Current state

- **v1** (`MFSchemaV1`, `Schema.Version(1, 0, 0)`) is the baseline — the first
  shipped model. `MFSchemaMigrationPlan` lists it with no stages.
- The container is built with the migration plan in
  `MFModelContainerFactory.makeContainer`, so any future versioned schema
  migrates automatically on launch.

## Adding a field (lightweight migration)

1. Add the stored property to the model (give it a default value).
2. Add `MFSchemaV2: VersionedSchema` with `versionIdentifier = Schema.Version(2, 0, 0)`
   and the full model list (copy from V1).
3. Append `MFSchemaV2.self` to `MFSchemaMigrationPlan.schemas`.
4. Add `MigrationStage.lightweight(fromVersion: MFSchemaV1.self, toVersion: MFSchemaV2.self)`
   to `stages`.
5. Default values backfill existing rows automatically.

## Renames / transforms (custom migration)

Use `MigrationStage.custom(...)` with a `migrate` closure. Keep the old and
new model structs side by side in the stage — SwiftData needs both shapes.

## CloudKit constraints (the sync toggle must keep working)

- Every synced attribute must be a CloudKit-compatible type. The v1 model
  was designed for this: nutrients are flattened `Double` columns (no
  transformable dictionaries), enums are stored as raw `String`s, fasting
  weekdays are an `Int` bitmask, and the OFF cache lives in a separate
  non-synced store configuration.
- Do NOT add `@Attribute(.transformable)` properties to synced models, and
  do NOT store `Data` blobs (other than the cache's raw JSON, which is
  local-only). Photo bytes stay in the file system (see `PhotoFileStore`).
- Adding a non-optional property without a default breaks CloudKit sync
  for existing rows — always provide defaults.
- `ProgressPhoto.relativePath` must stay relative: absolute paths break
  across devices even with CloudKit row sync.

## Seed database versioning

`seed_foods.json` carries a `version`. `SeedDataLoader` imports only foods
not already present (matched on source + name) and records the imported
version in UserDefaults. To ship more seed foods: bump `version`, append
entries — existing installs gain the new rows, nothing duplicates.

## Deleting data

Delete rules are declared per relationship (see model files):
- `FoodItem` → `LogEntry.food`: **nullify** (entries keep snapshots).
- `FoodItem` → `RecipeIngredient`: **cascade** (recipe dies with its food).
- `Habit` → `HabitCompletion`, `ProgramSettings` → targets/overrides: **cascade**.
- `resetAllData()` (ProgramRepository) purges user rows but preserves seed
  foods; photo files are removed via `PhotoFileStore`.
