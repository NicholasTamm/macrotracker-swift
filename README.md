# MacroTrack

A full-featured macro-tracking iOS app built with Swift and SwiftUI —
food logging, barcode/label/voice/photo capture, adaptive coaching,
body tracking, analytics, HealthKit sync, widgets, and an Apple Watch
companion. iOS 17+.

Everything is unlocked and free: **no account, no subscription, no ads,
no tracking.** (An earlier paywall plan was cancelled outright — there is
no StoreKit code in the project at all.)

> The Xcode application target is named `MacroFactorClone` (see
> `SETUP.md`); `macrotracker-swift` is the repository name.

## Features

- **Food Log** — timeline logging with a collapsing week banner, food
  search (recents first, Open Food Facts fallback), serving editor with
  metric/imperial units, meal slots, copy/paste for foods, time blocks
  and whole days, custom foods, recipe builder, food library, quick-add,
  and a "Your Plate" multi-add sheet.
- **Capture** — barcode scanning, nutrition-label OCR, photo logging,
  voice logging, and recipe import from URL or cookbook photo. Every
  capture route feeds the same logging pipeline and streak hook.
- **Dashboard** — today's macro ring, expenditure and weight-trend cards,
  weekly calories, micronutrient coverage, insight cards.
- **Strategy** — adaptive coaching: expenditure estimation, weight-trend
  smoothing, macro planner, and weekly check-ins (Coached / Collaborative /
  Manual programs; bulk / cut / maintenance goals).
- **Tracking** — weigh-ins with trend chart, body measurements, progress
  photos with side-by-side compare, habit streaks, period tracking, step
  history.
- **Health app sync** — 30-day weight + step import, background delivery,
  weigh-in write-back. Manual entries always win over synced values.
- **Engagement** — local notifications (meals, weigh-ins, weekly
  check-in) with deep links, Lock Screen widgets, and an Apple Watch app
  (quick-add, weigh-in; queues writes to iPhone when offline).

## Repository layout

```
macrotracker-swift/
├── Package.swift            # 11 SwiftPM library targets (swift-tools 5.9)
├── MacroFactorClone.xcodeproj/ # checked-in iOS app and unit-test project
├── project.yml              # XcodeGen source for the project
├── App/                     # thin @main iOS entry point
├── Sources/
│   ├── DesignSystem/        # tokens (MFColor, MFFont, MFMetrics) + components
│   ├── AppShell/            # 5-tab bar, router, onboarding, settings
│   ├── DataLayer/           # SwiftData models + repository protocols
│   ├── FoodLogFeature/      # timeline, search, plate sheet, recipes
│   ├── CaptureFeature/      # barcode, label OCR, voice, photo
│   ├── CoachingEngine/      # pure-Foundation coaching logic (UI-free)
│   ├── StrategyFeature/     # strategy tab: program, targets, check-in
│   ├── TrackingFeature/     # weigh-ins, measurements, photos, habits
│   ├── AnalyticsFeature/    # dashboard, charts, insights
│   ├── HealthKitSync/       # HealthKit import + background delivery
│   └── EngagementFeature/   # notifications, widget data, watch bridge
├── Tests/
│   ├── CoachingEngineTests/ # 30 unit tests (run on Linux, see below)
│   └── DataLayerTests/      # need Xcode (SwiftData)
├── WatchApp/                # watchOS app sources
├── Widgets/                 # WidgetKit extension sources
├── Resources/               # asset catalog, Info.plist, entitlements, privacy manifest
├── Scripts/                 # icon generation helpers
├── ReleaseNotes/            # one file per TestFlight build
├── docs/                    # architecture, testing, module map notes
├── SETUP.md                 # Xcode build and simulator setup
├── MODULE_MAP.md            # target dependency rules
└── PRIVACY.md               # privacy posture, manifest, App Store labels
```

## Getting started

1. Open `MacroFactorClone.xcodeproj` in Xcode. `project.yml` is the
   reproducible XcodeGen source for its app and test targets.
2. Build and run the `MacroFactorClone` scheme on an iPhone simulator.
   See `SETUP.md` for command-line build and test commands.
3. Run the test suites (below).

## Testing

- `Tests/CoachingEngineTests` — 30 tests covering the expenditure
  estimator, weight trend, macro planner, and weekly check-in. This
  target is pure Foundation, so it also runs on Linux:
  `swift test` in a scratch package containing `Sources/CoachingEngine`
  + `Tests/CoachingEngineTests` with Swift 6.2.1.
- `Tests/DataLayerTests` — SwiftData repository tests; require Xcode.
- Every Swift file additionally passes a `swiftc -parse` sweep (syntax +
  protocol-conformance shape). Full compilation of the UI targets
  requires Xcode — see `docs/TESTING.md`.

## Privacy

No account, no server, no analytics SDK, no crash-reporting SDK. Data
stays on-device in SwiftData (local-first; sync hooks are designed, not
wired). Crash reports come from first-party
MetricKit only. Full story in `PRIVACY.md`; the App Store label is
"Data Not Collected".

## Attribution

Food icons are [OpenMoji](https://openmoji.org) (CC BY-SA 4.0),
attributed in More → About and `Resources/.../FOOD_ICONS_LICENSE.txt`.
All code, artwork, branding, and copy are original.

## Status

Pre-release. The iOS app builds with Xcode 26.4, passes its iOS simulator
unit tests, and reaches onboarding on a fresh iPhone 17 Pro simulator.
Known open items are tracked as GitHub issues.
