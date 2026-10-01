# SETUP — opening the project in Xcode

The Swift package (`app/Package.swift`) holds every library module, but
SwiftPM cannot produce the iOS app bundle, the asset catalog wiring, or the
watchOS app. Those live in a thin Xcode project you create once:

## 1. Create the Xcode project

1. Xcode → **File → New → Project → iOS → App**.
   - Product name: `MacroFactorClone`
   - Interface: **SwiftUI**, Language: **Swift**
   - Minimum deployments: **iOS 17.0**
2. **File → Add Package Dependencies → Add Local…** → select
   `~/workspace/goals/macrofactor-clone-app/app`.
3. In the app target → **Frameworks, Libraries, and Embedded Content**,
   add all ten products: `DesignSystem`, `AppShell`, `DataLayer`,
   `FoodLogFeature`, `CaptureFeature`, `CoachingEngine`,
   `TrackingFeature`, `AnalyticsFeature`, `HealthKitSync`,
   `EngagementFeature`.
4. Delete the template `ContentView.swift` / `MacroFactorCloneApp.swift`
   Xcode generated — the real `@main` entry is
   `Sources/AppShell/MacroFactorCloneApp.swift` in the package. (If the
   linker ever complains about the entry point living in a library, move
   that 8-line `@main` struct into the Xcode target as a fallback.)
5. Drag `app/Resources/Assets.xcassets` into the project (or set it as the
   target's asset catalog). It contains:
   - `AppIcon.appiconset` — original placeholder icon (1024×1024,
     regenerable via `app/Scripts/make_app_icon.py`). Replace with final
     art before TestFlight.
   - Twelve `openmoji-<HEX>.imageset` food icons (OpenMoji, CC BY-SA 4.0,
     vector-preserving). `MFFoodIcon` loads them via
     `Image("openmoji-<HEX>")` from the app bundle.

## 2. App target resources (Info.plist, entitlements, privacy)

Ready-made files live in `app/Resources/` — use them instead of hand-editing:

| File | How to use |
|---|---|
| `Info.plist` | Set as the app target's Info.plist (or copy its keys into the target's Info). Contains: `mfclone` URL scheme, branded `UILaunchScreen` (`LaunchBackground` color + `LaunchLogo` image from the asset catalog), HealthKit usage strings, `UIBackgroundModes: healthkit`, capture usage strings (camera/mic/speech/photo library), `ITSAppUsesNonExemptEncryption = NO`. |
| `MacroFactorClone.entitlements` | Set as the app target's entitlements file: `com.apple.developer.healthkit` + App Group `group.com.macrofactor.clone`. |
| `PrivacyInfo.xcprivacy` | Add to the app target (privacy manifest: no tracking, UserDefaults reason CA92.1, no collected data types). See `app/PRIVACY.md` for the full privacy story and App Store label ("Data Not Collected"). |

Key table (for reference — these are all in `Info.plist` already):

| Key | Value / notes |
|---|---|
| `CFBundleURLTypes` → `CFBundleURLSchemes` | `mfclone` — deep-link scheme handled by `MFRouter` (`mfclone://dashboard`, `foodlog`, `quicklog`, `strategy`, `more`, `settings`, `weighin`, `addfood?query=…`) |
| `UILaunchScreen` | `{ UIColorName: LaunchBackground, UIImageName: LaunchLogo }` — branded splash (issue #12). The in-app `MFLaunchScreen` continues the same branding while services build. |
| `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` | Weight + step sync strings (issue #9) |
| `NSCameraUsageDescription` | Barcode/label/photo capture (issue #5) |
| `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` | Voice logging (issue #5) |
| `NSPhotoLibraryUsageDescription` | Meal/cookbook photo picking (issue #5) |

## 3. Capabilities

- **App Groups**: `group.com.macrofactor.clone` — enable on **all three**
  targets (iOS app, WidgetKit extension, watchOS app); widgets and the
  watch read the snapshot from the shared container.
- **Background Modes**: `healthkit` (silent background delivery, issue #9);
  **Push Notifications** not needed — reminders are local (issue #10).
- **HealthKit** capability (issue #9).

## 4. watchOS + widgets (issue #10)

Concrete Xcode steps (from the #10 worker's brief):

1. **WidgetKit extension** — File → New → Target → **Widget Extension**,
   product name `MacroFactorCloneWidgets`:
   - Add `app/Widgets/MFWidgets.swift` to the extension target (see
     `app/Widgets/README.md`).
   - Link the `EngagementFeature` and `DesignSystem` products to the
     extension target.
   - Capabilities: add the App Group `group.com.macrofactor.clone`.
   - Widgets read `MFSharedSnapshot` from the shared container and deep-link
     `mfclone://foodlog` / `mfclone://quicklog` on tap.
2. **watchOS app** — File → New → Target → **watchOS → App**, product name
   `MacroFactorCloneWatch`:
   - Add `app/WatchApp/MacroFactorCloneWatchApp.swift` to the watch target
     (see `app/WatchApp/README.md`).
   - Link the package products the watch target needs (`DesignSystem`,
     `DataLayer`, `EngagementFeature`).
   - Capabilities: add the App Group `group.com.macrofactor.clone`.
   - The watch reads the snapshot via WatchConnectivity (App Context) with
     shared-container fallback; writes (quick-add, weigh-in) queue to the
     iPhone. The iPhone app works with or without a paired watch.
3. Verify: build each scheme; on the iPhone, logging food should refresh the
   widget timeline and (when paired) push the snapshot to the watch.

> Watch-ship caveat (from #10): the watchOS package compile and
> WatchConnectivity background delivery can't be verified until the first
> Xcode build on a Mac. If the watch target surfaces issues, defer it to v2 —
> the phone app is unaffected.

## 5. Build

Select the `MacroFactorClone` scheme (iPhone 17 simulator) and build
(`⌘B`). The scaffold compiles to the five-tab shell with placeholders;
feature workers fill in the tabs issue by issue.

> Note: Swift cannot compile on the Linux build machine — all code is
> written to review standard. The first Xcode build on a Mac is the real
> verification.

## 6. TestFlight prep (issue #12)

**Build config.**
1. App target → General: set **Version** `1.0.0`, **Build** `1` (bump the
   build number for every TestFlight upload; keep the marketing version in
   sync with the About screen in `SettingsView`).
2. Signing & Capabilities: your Apple Developer team; the entitlements file
   (`MacroFactorClone.entitlements`) requires the HealthKit and App Groups
   capabilities to be enabled for the App ID.
3. Scheme → **Release** build configuration for archiving
   (Product → Scheme → Edit Scheme → Archive = Release).
4. Product → **Archive**, then Distribute App → **TestFlight & App Store**.
   First upload registers the bundle ID and the `mfclone` URL scheme needs
   no extra review.

**Release notes flow.** `app/ReleaseNotes/` holds one Markdown file per
build (`1.0.0-beta1.md`, …). Copy the previous file, update the "What's in
this build" list and the known-issues section, and paste it into the
TestFlight "Test Details" / "What to Test" field on upload. The Beta 1
notes document the known open questions (UTC day-bucketing, watch-target
caveat, photo-logging stub, voice parser limits).

**Crash reporting.** Deliberately **no third-party crash SDK** (privacy
posture: no tracking, no data sold — see `app/PRIVACY.md`). `MFCrashReporter`
(AppShell) subscribes to first-party **MetricKit** at launch; iOS delivers
crash/diagnostic payloads to App Store Connect automatically. Read them in
Xcode → Organizer → Crashes, or App Store Connect → TestFlight → Crashes.
No API keys, no extra setup, nothing to install.
