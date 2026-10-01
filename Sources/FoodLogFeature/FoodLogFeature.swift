import SwiftUI
import DesignSystem
import DataLayer

// MARK: - FoodLogFeature (issue #4)
//
// The core logging loop: the Food Log tab's day timeline (collapsing
// calendar week banner, hour blocks, live macro totals), food search
// (recents first, debounced local + Open Food Facts search), the "Your
// Plate" multi-add sheet, the serving editor (metric/imperial units, meal
// assignment), quick-add calories/macros, custom foods, the recipe builder,
// a food library, and copy/paste for foods, time blocks, and whole days.
//
// Public surface:
// - `FoodLogRootView` — the Food Log tab. Constructed with the repository
//   protocols it needs; AppShell embeds it once the DataStore is wired
//   (see `MainTabView.FoodLogRootPlaceholder`). The optional `onFoodLogged`
//   hook is how AppShell connects food logging to the habit streak
//   (issue #7); nil keeps the module self-contained.
// - `MFWeekBannerMode` + `FoodLogPreferences` — the Calendar Week Banner
//   display setting (Show / Show & Pin / Hide), persisted with AppStorage
//   so AppShell's Settings screen can bind to it later.
// - `FoodSearchView`, `PlateSheetView`, `QuickAddView`,
//   `CustomFoodEditorView`, `RecipeBuilderView`, `FoodLibraryView` —
//   standalone sheets/flows reusable from the quick-log sheet (#2/#5).
// - `FoodLogClipboard` — in-memory copy/paste for foods, blocks, and days.
//
// Dependencies: DesignSystem + DataLayer only (see MODULE_MAP.md).
// Capture UI (barcode camera, label OCR, photo, voice) belongs to issue
// #5; this module only consumes `FoodSearchService.lookupBarcode` for
// manual code entry.
//
// Tracking integration (issue #7 coordination, 2026-09-28): food logging
// feeds the "Log food" habit streak. This module must not import
// TrackingFeature (MODULE_MAP rule 1: features never depend on each
// other), so `FoodLogViewModel.onFoodLogged` is a plain hook closure.
// AppShell wires it when it embeds the tab:
//     FoodLogRootView(logs:foods:foodSearch:program:,
//         onFoodLogged: { trackingEnv.logTodayCompletion(kind: .foodLogging) })
// The hook fires on every successful food write for *today* (log, plate,
// quick add, paste); backfilling a past day does not touch today's streak.
// `logTodayCompletion` is per-day idempotent, so repeated logging is safe.
//
// Fidelity notes (researched 2026-09-28, see issues/04-food-logging.md):
// - Timeline day-totals strip prefixes macro letters ("P 29 / 107");
//   the plate header trails them ("56 / 52 F"). `MFMacroMiniBar` grew a
//   `badgePosition` parameter to express both; this module passes
//   `.leading` in the timeline strip.
// - The week banner collapses on scroll in `show` mode (threshold 72pt,
//   matching the palette showcase demo), stays pinned in `showAndPin`,
//   and is removed in `hide`.

/// Module marker. The real food-logging UI lives in the views below.
public enum FoodLogFeature {
    public static let ownerIssue = "#4"
}
