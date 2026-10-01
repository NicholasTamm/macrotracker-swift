# WatchApp — watchOS companion (issue #10)

SwiftPM cannot define a watchOS **app** target, so the watch app lives here
as a source drop-in instead of a package target.

## Wiring it up (Xcode)

1. In the Xcode project (see `app/SETUP.md`), add a **watchOS → App** target
   named `MacroFactorCloneWatch`.
2. Add `MacroFactorCloneWatchApp.swift` (this folder) to that target —
   **watch target only**, not the iOS app target.
3. Add the `MacroFactorClone` Swift package to the watch target's
   **Frameworks, Libraries, and Embedded Content**, linking
   `DesignSystem` and `EngagementFeature`. (`EngagementFeature` pulls in
   `DataLayer` + `CoachingEngine` transitively; the package declares
   `.watchOS(.v10)` in its platforms so this resolves.)
4. Set the watch target's **App Group** to the same group as the iOS app
   (`group.com.macrofactor.clone`) so the watch can read the shared
   snapshot container.
5. Deployment target: **watchOS 10+**.
6. On the **iPhone side**, AppShell must create `MFWatchBridge` at launch,
   call `activate()`, and set the snapshot publisher's `onPublish` to
   `bridge.pushSnapshot(_:)` — otherwise the watch only sees data from the
   shared container and can't send entries back.

## Scope

Three pages: **Today** (macro ring from the shared snapshot), **Quick Add**
(calories via Digital Crown + macro steppers → queued to the iPhone),
**Weigh In** (Digital Crown + kg/lb toggle → queued to the iPhone).

Two-way sync lives in `EngagementFeature/MFWatchSync.swift`:
- iPhone → watch: `MFWatchBridge.pushSnapshot(_:)` via
  `updateApplicationContext`, plus the App Group snapshot file as fallback.
- Watch → iPhone: `MFWatchClient.sendQuickAdd` / `sendWeighIn` via
  `transferUserInfo` (queued, background-delivered); the phone applies them
  to the DataLayer repositories and republishes.

The phone must be paired for writes; reads always work from the last
published snapshot in the shared container.
