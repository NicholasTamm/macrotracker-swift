# Widgets — WidgetKit extension (issue #10)

SwiftPM can't produce an embeddable WidgetKit **app extension**, so the
widget sources live here as a drop-in. The extension target is created once
in the Xcode project.

## Wiring it up (Xcode)

1. In the Xcode project (see `app/SETUP.md`): **File → New → Target →
   iOS → Widget Extension**. Name it `MacroFactorCloneWidgets`.
   - Uncheck "Include Configuration Intent" (these widgets have no user
     configuration).
   - Minimum deployment: **iOS 17.0**.
2. Delete the template files Xcode generates for the extension.
3. Add `app/Widgets/MFWidgets.swift` to the **extension target only**
   (not the app target).
4. In the extension target → **Frameworks, Libraries, and Embedded
   Content**, add the `EngagementFeature` and `DesignSystem` products from
   the local `MacroFactorClone` package. (EngagementFeature already depends
   on DesignSystem + DataLayer, so one entry pulls the rest.)
5. Enable the **App Group** capability on the extension target with the same
   group as the iOS app: `group.com.macrofactor.clone`. Without this, the
   widget reads no data and shows placeholder values.
6. Build the `MacroFactorCloneWidgets` scheme.

## What it contains

| Widget | Families | Content |
|---|---|---|
| Today's nutrition | `.systemSmall`, `.systemMedium` | Calorie ring (remaining), macro bars |
| Calories remaining | `.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline` | Lock Screen compact readout |

## Data flow

- The iOS app publishes `MFSharedSnapshot` to the App Group container via
  `MFSnapshotPublisher.publishToday()` and calls
  `WidgetCenter.shared.reloadAllTimelines()`.
- The timeline provider reads the snapshot with
  `MFSharedSnapshotStore.read()`; the backstop refresh is next midnight.
- Taps deep-link via `mfclone://foodlog` / `mfclone://quicklog`
  (handled by `MFRouter` in AppShell).

## Notes

- The extension never touches SwiftData — the shared snapshot file is its
  only data source.
- All artwork and copy are original to this project; macro colors come
  from the `DesignSystem` tokens.
