# Issue #1 custom-food handoff verification

- Source: `5c8e8d4` (`origin/main`) plus the issue #1 worktree change.
- Build: Xcode 26.4, `MacroFactorClone` Debug, iOS 26.4 simulator.
- Device: isolated iPhone 17 Pro, `A0851E73-412C-43C3-A9AF-F08210CA43DF`.
- Installed executable SHA-256: `ccbd2d72f67d2fde9ee02abd6257a0e574aed7aee840950f7524163b3b98f57d`.

## Results

| Check | Result |
| --- | --- |
| App build | Passed. |
| Existing DataLayer and CoachingEngine suites | Passed: 43 tests, 0 failures. |
| Create `Issue1 Direct Oats 9754`, save, inspect amount/time and 120 kcal / 10 g protein / 4 g fat / 18 g carbs preview, then tap **Log food** directly | Passed: exactly one entry, selected 3 PM hour and 120 kcal day total refreshed immediately, and entry persisted after relaunch. |
| Create `Issue1 Cocoa Oats 9753`, cancel from preview, re-search, log, and relaunch | Passed: cancel created no entry while the saved food stayed searchable; later explicit logging created exactly one 120 kcal entry and persisted. |
| Reopen a saved custom food from Library, edit, and save changes | Passed: the edit form and completion path still worked; the existing log entry remained. |

The [direct preview](direct-preview.png), [direct log result](direct-after-log.png), and [relaunch result](after-relaunch.png) are screenshots from the installed simulator build. The local Xcode result bundles are `/private/tmp/issue1-ui-direct.xcresult`, `/private/tmp/issue1-ui-pass.xcresult`, `/private/tmp/issue1-ui-edit.xcresult`, and `/private/tmp/issue1-unit.xcresult`.

## Verification limit

The existing `MFStepper` exposes an `Add` child to XCUITest, but tapping that child did not change the serving amount in the automated probe. QA-002 previously classified this automation result as inconclusive. Issue #3 owns serving-input behavior; this issue uses the existing detail editor and verifies its amount control is present. No serving-size behavior was changed here.
