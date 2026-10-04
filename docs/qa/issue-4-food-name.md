# Issue #4 — visible food names: simulator QA

## Build and devices

- Screenshot QA source base: `5c8e8d4f90339fd7aceab0237010d0d6010a7562` plus the issue #4 diff. The final branch was rebased onto `105c5f7` after issue #1 merged and the full scheme passed again on that base.
- Xcode 26.4 (`17E192`), Debug, iOS Simulator 26.4.
- Built app's `MacroFactorClone.debug.dylib` SHA-256: `020a0c16f44d8090f14763fe6936386fe360ce46adb9430740279d5f69969562`.
- Final-base Debug dylib SHA-256: `b80bd451c41bf6e5f8d272f6239c29c98abbe44d63717b11760ad70336e53ebb`.
- iPhone 17e QA simulator: `C3C237E7-DA47-45DE-8D2D-53B93BD0905E`, 390-point width. Also checked at Accessibility Large text.
- iPhone SE (3rd generation) QA simulator: `079037C2-C7D7-4F28-9CD8-6B5F592CA3B6`, 375-point width. The 320-point iPhone SE (1st generation) is incompatible with iOS 26.4.

## Result

The DEBUG-only `-issue4FoodTileFixture` launch argument creates two custom foods and logs them through the production `FoodRepository` and `LogRepository`. Both names use the same fallback thumbnail: `QA4 Yogurt plain nonfat` (100 kcal) and `QA4 Yogurt plain whole` (180 kcal). The production Food Log timeline renders their complete names and calories immediately and after relaunch. The UI test checks their accessibility labels for one name and calories, OCR checks the distinguishing visible words, and tapping the second tile after horizontal scrolling opens Edit entry.

| Configuration | Evidence | Result |
| --- | --- | --- |
| iPhone 17e, standard text | [Immediate](screenshots/issue-4/standard-immediate.png), [after relaunch](screenshots/issue-4/standard-relaunch.png) | Both names and calories visible together; no tile overlap. |
| iPhone 17e, Accessibility Large | [Before horizontal scroll](screenshots/issue-4/ax-large-before-scroll.png), [after scroll](screenshots/issue-4/ax-large-after-scroll.png) | Full name and calories readable for each tile when scrolled into view; second tile remains tappable. |
| iPhone SE (3rd generation), 375 points | [Immediate](screenshots/issue-4/iphone-se3-375pt.png) | Both names and calories visible together; no tile overlap. |

The full Xcode scheme passed on the iPhone SE simulator: 13 DataLayer tests, 30 CoachingEngine tests, and 1 FoodLog UI test, with zero failures. It passed again after the final-base rebase. The FoodLog UI test also passed on the iPhone 17e at standard and Accessibility Large text. Result bundles are local at `/private/tmp/issue4-all-tests.xcresult`, `/private/tmp/issue4-rebased-tests.xcresult`, `/private/tmp/issue4-ui-test-2.xcresult`, and `/private/tmp/issue4-ui-test-ax2.xcresult`.

## Limits

- At Accessibility Large, the existing week strip, day summary, and hour header clip or wrap. Those components are outside issue #4's tile change and need separate layout work.
- The XCUITest checks the accessibility element labels and tap behavior; it does not record VoiceOver speech audio.
- A first attempt to use the bundled seed food `Milk, whole` returned “No matches” on the fresh simulator. The fixture uses the production repository save/log path so the issue #4 rendering check is independent of that separate search behavior.
