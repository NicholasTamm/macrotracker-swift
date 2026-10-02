# Testing

## What runs where

| Suite | Where it runs | Command |
|---|---|---|
| `CoachingEngineTests` | Linux **and** Xcode | `xcodebuild ... test` below |
| `DataLayerTests` | Xcode only (needs SwiftData) | `xcodebuild ... test` below |
| `swiftc -parse` sweep (all 138 Swift files) | Linux | see below |
| Full app compilation | Xcode only (Apple frameworks) | `xcodebuild ... build` in `SETUP.md` |

The checked-in `MacroFactorClone` scheme runs both test targets on an iOS
simulator:

```bash
xcodebuild -project MacroFactorClone.xcodeproj -scheme MacroFactorClone \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/MacroFactorClone-TestData \
  CODE_SIGNING_ALLOWED=NO test
```

On 2026-10-02, Xcode 26.4 ran 43 tests with no failures or skips on an
iPhone 17 Pro simulator with iOS 26.4.

SwiftUI, SwiftData, HealthKit, WidgetKit, WatchConnectivity,
AVFoundation, and VisionKit are Apple-proprietary frameworks that exist
only inside Xcode/macOS. No Linux toolchain can compile them — the first
Xcode build is the real verification gate for every UI target.

## Engine tests on Linux

`Sources/CoachingEngine` is pure Foundation, so its tests run on Linux
with the Swift 6.2.1 toolchain. The package's other test targets import
Apple frameworks, so `swift test` on the real package can't build there.
Instead, copy the engine sources and tests into a scratch package:

```bash
TOOL=~/workspace/toolchain/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin
mkdir -p /tmp/engine-test && cd /tmp/engine-test
# scratch Package.swift: targets CoachingEngine (Sources/CoachingEngine)
# and CoachingEngineTests (Tests/CoachingEngineTests)
cp -r <repo>/Sources/CoachingEngine Sources/
cp -r <repo>/Tests/CoachingEngineTests Tests/
$TOOL/swift test   # expect 30/30
```

## Parse sweep on Linux

`swiftc -parse` type-checks syntax and early-semantic shape (including
protocol requirements) without resolving Apple imports — it catches real
errors like default arguments on protocol methods. Run over every file:

```bash
TOOL=~/workspace/toolchain/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin
cd <repo>
for f in $(find Sources WatchApp Widgets Tests -name '*.swift') Package.swift; do
  $TOOL/swiftc -parse "$f" -o /dev/null || echo "FAIL: $f"
done
```

This is a complement to, not a replacement for, the Xcode build: it
cannot catch type-level errors (wrong member names, argument labels,
framework API misuse).

## QA plan

The device/simulator QA plan (scenarios for food logging, capture,
coaching, tracking, analytics, HealthKit, engagement, watch, release
polish) lives outside this repo. Execute it after the first successful
Xcode build, on a real device where hardware features (camera,
HealthKit, notifications, background sync) can be exercised.
