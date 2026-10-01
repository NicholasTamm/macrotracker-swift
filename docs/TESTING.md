# Testing

## What runs where

| Suite | Where it runs | Command |
|---|---|---|
| `CoachingEngineTests` (30 tests) | Linux **and** Xcode | see below |
| `DataLayerTests` | Xcode only (needs SwiftData) | `⌘U` in Xcode |
| `swiftc -parse` sweep (all 138 Swift files) | Linux | see below |
| Full app compilation | Xcode only (Apple frameworks) | `⌘B` |

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
cp -r <repo>/app/Sources/CoachingEngine Sources/
cp -r <repo>/app/Tests/CoachingEngineTests Tests/
$TOOL/swift test   # expect 30/30
```

## Parse sweep on Linux

`swiftc -parse` type-checks syntax and early-semantic shape (including
protocol requirements) without resolving Apple imports — it catches real
errors like default arguments on protocol methods. Run over every file:

```bash
TOOL=~/workspace/toolchain/swift-6.2.1-RELEASE-ubuntu24.04/usr/bin
cd <repo>/app
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
