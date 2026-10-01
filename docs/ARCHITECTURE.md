# Architecture

Cross-cutting design notes for MacroTrack. For the module/target layout
and dependency rules, see `../MODULE_MAP.md` (source of truth).

## Layering

```
SwiftUI views (feature modules + AppShell)
        │  programs to protocols, never to implementations
        ▼
DataLayer repository protocols  (FoodRepository, LogRepository, …)
        │  implemented by
        ▼
SwiftData*Repository  (SwiftData + ModelContext, @MainActor)
        │
CoachingEngine  (pure Foundation — importable from anywhere, UI-free)
```

- Feature modules depend only on `DesignSystem`, `DataLayer`, and
  (where the coaching contract says so) `CoachingEngine`. Never on
  `AppShell`, never on each other.
- `AppShell` composes everything: tab bar, sheets, `MFRouter` deep links,
  onboarding, settings.
- There is no StoreKit, no networking layer beyond the Open Food Facts
  client, and no backend.

## Repository protocols and default arguments

Swift forbids default parameter values on protocol requirements, so the
protocols declare full parameter lists and the defaults live in
`@MainActor` protocol-extension overloads that forward to the
requirement, e.g.:

```swift
public protocol WeightRepository {
    func logWeight(_ weightKg: Double, timestamp: Date, note: String?,
                   source: WeightSource) throws -> WeightEntry
}

@MainActor
extension WeightRepository {
    func logWeight(_ weightKg: Double, timestamp: Date = Date(),
                   note: String? = nil,
                   source: WeightSource = .manual) throws -> WeightEntry {
        try logWeight(weightKg, timestamp: timestamp, note: note, source: source)
    }
}
```

Call sites keep the convenient short forms (`logWeight(80)`);
conformances implement the full signature. Keep this pattern when adding
repository methods.

## The streak hook

Every capture route — manual search, barcode, label OCR, voice, photo,
recipe import — calls the streak hook exactly once per successful save.
Rules:

- Backdated entries never affect today's streak.
- No double-counting: the hook is idempotent per log day.
- Failed saves never credit the streak (the UI surfaces the error and
  stays open).

## Dates: hybrid model

- Timestamps are stored as absolute `Date` (UTC).
- Days are bucketed with the **device calendar**
  (`.autoupdatingCurrent`), so day boundaries follow the user across
  time-zone changes.
- `MFDates.startOfDay(_:)` is the single choke point for bucketing —
  don't scatter `Calendar.current.startOfDay` call sites.

## Coaching engine

`Sources/CoachingEngine` is deliberately UI-free (Foundation only):

- `ExpenditureEstimator` — adaptive TDEE from intake + weight history.
- `WeightTrend` — smoothed trend from noisy weigh-ins.
- `MacroPlanner` — calorie/macro targets from program, goal rate, and
  diet style.
- `WeeklyCheckIn` — adherence classification (`onTrack`,
  `slowerThanPlanned`, `offTrack`) driving Coached / Collaborative /
  Manual program adjustments.

Because it has no Apple-framework imports, it compiles and tests on
Linux — it is the most-verified module in the project (30 unit tests).

## Deep links

`MFRouter` (AppShell) handles the `mfclone://` scheme: `dashboard`,
`foodlog`, `quicklog`, `strategy`, `more`, `settings`, `weighin`,
`addfood?query=…`. Notification taps and widgets route through these —
add new destinations here, not ad-hoc.

## Widgets & watch data flow

Widgets and the watch never touch SwiftData directly. The iPhone app
writes an `MFSharedSnapshot` (today's totals, streak, targets) to the App
Group container (`group.com.macrofactor.clone`); widgets read the
snapshot, and the watch receives it via WatchConnectivity App Context
with shared-container fallback. Watch writes (quick-add, weigh-in) queue
to the iPhone. The phone app works with or without a paired watch.
