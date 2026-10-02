# SETUP — opening the project in Xcode

`Package.swift` holds the library modules. The checked-in
`MacroFactorClone.xcodeproj` supplies the thin iOS app target, assets, and
two unit-test targets. `project.yml` is its XcodeGen 2.46.0 source. The app
deployment target remains iOS 17.0.

## 1. Open or regenerate the Xcode project

Open `MacroFactorClone.xcodeproj` and select the `MacroFactorClone` scheme.
No untracked local files or manual Xcode target creation are required. After
editing `project.yml`, regenerate the checked-in project with:

```bash
xcodegen generate
```

The app entry point is `App/MacroFactorCloneApp.swift`. The project links the
local `AppShell` package product and includes `Resources/Assets.xcassets`,
`Resources/PrivacyInfo.xcprivacy`, `Resources/Info.plist`, and the entitlements.

## 2. App target resources (Info.plist, entitlements, privacy)

Ready-made files live in `Resources/`:

| File | How to use |
|---|---|
| `Info.plist` | Set as the app target's Info.plist (or copy its keys into the target's Info). Contains: `mfclone` URL scheme, branded `UILaunchScreen` (`LaunchBackground` color + `LaunchLogo` image from the asset catalog), HealthKit usage strings, `UIBackgroundModes: healthkit`, capture usage strings (camera/mic/speech/photo library), `ITSAppUsesNonExemptEncryption = NO`. |
| `MacroFactorClone.entitlements` | Set as the app target's entitlements file: `com.apple.developer.healthkit` + App Group `group.com.macrofactor.clone`. |
| `PrivacyInfo.xcprivacy` | Add to the app target (privacy manifest: no tracking, UserDefaults reason CA92.1, no collected data types). See `PRIVACY.md` for the full privacy story and App Store label ("Data Not Collected"). |

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
   - Add `Widgets/MFWidgets.swift` to the extension target (see
     `Widgets/README.md`).
   - Link the `EngagementFeature` and `DesignSystem` products to the
     extension target.
   - Capabilities: add the App Group `group.com.macrofactor.clone`.
   - Widgets read `MFSharedSnapshot` from the shared container and deep-link
     `mfclone://foodlog` / `mfclone://quicklog` on tap.
2. **watchOS app** — File → New → Target → **watchOS → App**, product name
   `MacroFactorCloneWatch`:
   - Add `WatchApp/MacroFactorCloneWatchApp.swift` to the watch target
     (see `WatchApp/README.md`).
   - Link the package products the watch target needs (`DesignSystem`,
     `DataLayer`, `EngagementFeature`).
   - Capabilities: add the App Group `group.com.macrofactor.clone`.
   - The watch reads the snapshot via WatchConnectivity (App Context) with
     shared-container fallback; writes (quick-add, weigh-in) queue to the
     iPhone. The iPhone app works with or without a paired watch.
3. Verify: build each scheme; on the iPhone, logging food should refresh the
   widget timeline and (when paired) push the snapshot to the watch.

> Watch-ship caveat (from #10): this project currently tracks only the iOS
> app and test targets. The watchOS target and WatchConnectivity background
> delivery remain unverified until a watch target is added and built.

## 5. Build

From a clean checkout with Xcode 26.4 and an iOS 26.4 simulator installed:

```bash
xcodebuild -project MacroFactorClone.xcodeproj -scheme MacroFactorClone \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/MacroFactorClone-DerivedData \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project MacroFactorClone.xcodeproj -scheme MacroFactorClone \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/MacroFactorClone-TestData \
  CODE_SIGNING_ALLOWED=NO test
```

The test action runs `DataLayerTests` and `CoachingEngineTests`. For a launch
smoke test, install the resulting `MacroFactorClone.app` with `xcrun simctl
install <device-udid> <app-path>` and launch bundle ID
`com.nicholastamm.MacroFactorClone` with `xcrun simctl launch`.

### Verified clean baseline (2026-10-02)

- Xcode 26.4 (build 17E192), XcodeGen 2.46.0, iOS 26.4 runtime
  (build 23E244), iPhone 17 Pro simulator. Build destination target was
  `arm64-apple-ios17.0-simulator` with iOS 17.0 deployment.
- `xcodegen generate` succeeded from the issue worktree. The app built with
  new DerivedData at `/private/tmp/mf-issue6-dd`, and the generated project
  test action passed **43/43** tests with separate new DerivedData at
  `/private/tmp/mf-issue6-test-dd`.
- The tested app bundle installed and launched on a newly created simulator,
  reaching the onboarding screen. Its `MacroFactorClone` executable SHA-256
  was `345b4f3c5d5868fb46efbdcd41df43943713da69c48ce1709e9fdfe6e3863422`.

The compatibility edits remove `#Index` declarations unsupported at the
iOS 17 deployment target; this changes query indexing, not stored fields.
SwiftData relationship inverse declarations remain on the owning side and
their cascade behavior is covered by the in-memory schema test. The container
now includes the local cache model alongside the versioned synced models
when constructing `ModelContainer`; the cache retains its separate local
configuration. The remaining source edits correct compiler-visible SwiftUI
API names, call labels, and preview code, without implementing food-log
issues #1–#5.

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

**Release notes flow.** `ReleaseNotes/` holds one Markdown file per
build (`1.0.0-beta1.md`, …). Copy the previous file, update the "What's in
this build" list and the known-issues section, and paste it into the
TestFlight "Test Details" / "What to Test" field on upload. The Beta 1
notes document the known open questions (UTC day-bucketing, watch-target
caveat, photo-logging stub, voice parser limits).

**Crash reporting.** Deliberately **no third-party crash SDK** (privacy
posture: no tracking, no data sold — see `PRIVACY.md`). `MFCrashReporter`
(AppShell) subscribes to first-party **MetricKit** at launch; iOS delivers
crash/diagnostic payloads to App Store Connect automatically. Read them in
Xcode → Organizer → Crashes, or App Store Connect → TestFlight → Crashes.
No API keys, no extra setup, nothing to install.
