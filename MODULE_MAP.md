# Module / target map — MacroFactorClone

**Source of truth for the package layout** (defined in `app/Package.swift`,
swift-tools 5.9, iOS 17+). Read this before writing code in any module.

## Targets

| Target (product) | Path | Owner issue | Depends on | Contents |
|---|---|---|---|---|
| `DesignSystem` | `Sources/DesignSystem` | #1 (done) | — | Tokens (`MFColor`, `MFFont`, `MFMetrics`) + components + previews. **Consume, don't duplicate.** |
| `AppShell` | `Sources/AppShell` | #2 (scaffold) | DesignSystem + all feature modules | `@main` entry, onboarding, 5-tab bar, `MFRouter` deep links, `MFTheme`, quick-log sheet chrome, More/Settings + About (OpenMoji attribution) |
| `DataLayer` | `Sources/DataLayer` | #3 | DesignSystem | SwiftData models + repository protocols. Features program to protocols, never to SwiftData directly. |
| `FoodLogFeature` | `Sources/FoodLogFeature` | #4 | DesignSystem, DataLayer | Timeline log, food search, custom foods, quick-add form |
| `CaptureFeature` | `Sources/CaptureFeature` | #5 | DesignSystem, DataLayer | Barcode, label OCR, photo, voice, recipe import |
| `CoachingEngine` | `Sources/CoachingEngine` | #6 | *(none — pure Foundation)* | Expenditure estimation, weight trend, macro planner, weekly check-in. Stays UI-free so DataLayer/Analytics can import it without cycles. |
| `TrackingFeature` | `Sources/TrackingFeature` | #7 | DesignSystem, DataLayer | Weigh-in flow, measurements, progress photos, streaks |
| `AnalyticsFeature` | `Sources/AnalyticsFeature` | #8 | DesignSystem, DataLayer | Dashboard tab, Swift Charts, micros, insights |
| `HealthKitSync` | `Sources/HealthKitSync` | #9 | DesignSystem, DataLayer | HealthKit import + background delivery |
| `EngagementFeature` | `Sources/EngagementFeature` | #10 | DesignSystem, DataLayer | Notifications, widget data providers, watch sync bridge |

## Dependency rules

1. **Feature modules may depend only on `DesignSystem` and `DataLayer`** (and
   `CoachingEngine` where the #6 README's integration contract says so).
   Never on `AppShell`, never on each other.
2. **`DataLayer` depends on `DesignSystem` only.** No feature imports, no
   `AppShell` imports — the repository protocols must stay UI-agnostic.
3. **`CoachingEngine` depends on nothing** (Foundation only). Keep it that
   way: it is the one module every layer is allowed to import.
4. **`AppShell` composes everything.** Tab content, sheets, and deep-link
   routing live here; feature screens are embedded, not subclassed.
5. **No StoreKit anywhere.** Issue #11 is cancelled — no paywall, no
   subscription, no trial, no gating. Onboarding leads straight into the app.

## Tab → module mapping (MainTabView)

| Tab | Icon | Content owner |
|---|---|---|
| Dashboard | SF `square.grid.2x2` | `AnalyticsFeature` (#8) — placeholder in AppShell until then |
| Food Log | custom `MFAppleGlyph` | `FoodLogFeature` (#4) — placeholder in AppShell until then |
| (+) center | SF `plus.circle.fill` | `QuickLogSheet` chrome in AppShell; destinations in #4/#5 |
| Strategy | custom `MFStrategyGlyph` | `CoachingEngine` (#6) — placeholder in AppShell until then |
| More | SF `ellipsis.circle` | `SettingsView` in AppShell (feature settings rows added later) |

## Deep links (`mfclone://`)

Handled by `MFRouter` in AppShell: `dashboard`, `foodlog`, `quicklog`,
`strategy`, `more`, `settings`, `weighin`, `addfood?query=…`. Notification
taps and widgets (#10) route through these.

## Assets

- `Resources/Assets.xcassets` — app icon (`AppIcon.appiconset`, original
  placeholder art via `Scripts/make_app_icon.py`) + 12 OpenMoji food icons
  as `openmoji-<HEX>.imageset` (CC BY-SA 4.0; attribution in More → About
  and `FoodIcons/FOOD_ICONS_LICENSE.txt`). Referenced by
  `MFFoodIconAsset` / `MFFoodIcon` via `Image("openmoji-<HEX>")` — resolved
  from the **app target's** asset catalog at runtime.
- Re-run `Scripts/fetch_food_icons.sh` + `Scripts/make_imagesets.sh` to
  refresh the food art.

## Out-of-package targets (Xcode project only)

- **iOS app target** `MacroFactorClone` — links all products above; owns the
  asset catalog, Info.plist, entitlements (App Group, HealthKit, background
  modes). See `SETUP.md`.
- **watchOS app target** — sources in `app/WatchApp/`; links
  `DesignSystem`, `DataLayer`, `EngagementFeature`. See
  `app/WatchApp/README.md`.
- **WidgetKit extension** (issue #10) — created in the Xcode project;
  imports `EngagementFeature` for data.
