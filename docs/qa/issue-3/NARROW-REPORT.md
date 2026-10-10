# QA-3-NARROW report

**Final result: Pass.** Three focused XCUITests passed on the assigned iPhone SE (3rd generation), iOS 26.4, 375 × 667 points. The final run used build `1.0.0+1-4375880845b5`, test time 2026-10-10 04:41–04:43 PDT. Device: Issue 3 Narrow QA, UDID `ACC76FC2-EF42-4A46-A287-11E11CEC229E`.

Bundle: `com.nicholastamm.MacroFactorClone`, version/build `1.0.0 (1)`. Source identity: `9d4fdc9b86cc1c75d1b5e6db63793b30a3acd469` plus the frozen issue #3 source diff recorded by the build handoff. Build time: 2026-10-10 04:40:39 PDT. The prebuilt xctestrun was used with `xcodebuild test-without-building`; no rebuild or source changes were made for this lane. Installed hashes were checked before and after the run. Launcher SHA-256: `04cbe123d75ae2686e49e26ec4c1973e8c5b3e3e016c1a654842e123b19d9a8f`. `MacroFactorClone.debug.dylib` SHA-256: `4375880845b5fbfdf59a398daf9b855190c7467172f285627f38b99e16c43c4a`.

| Workflow | Happy path | Negative/boundary path | Outcome |
|---|---|---|---|
| Seeded Egg fractional portion and cancel | **Pass.** Entered `1.5`; preview showed `75 g` and `116.2 kcal`. Increased to `2` and saw `100 g`; decreased back to `1.5`. | **Pass.** Cancel returned to Food Log without adding the Egg entry. | Full test `testSeededEggLegacySizeFractionAndStepperCancel` passed. The test dismissed the numeric keyboard and scrolled preview/stepper targets into view before asserting. |
| Custom `QA3 Oats`, named size, edit/save/relaunch | **Pass.** Entered `1.5` of the `scoop (25 g)` size and saw `37.5 g` / `45 kcal`. Logged the entry, reopened and edited it to `2` (`50 g`), saved, terminated and relaunched the app. The reopened timeline showed `60 calories`; Dashboard increased by 60 calories. The reopened amount and weight remained `2` and `50 g`. | **Pass.** Entering zero displayed `Amount must be greater than zero.` and the log action was disabled. | Full test `testCustomNamedSizeTypedAmountEditAndRelaunch` passed. The log timestamp accessibility value remained `4:00 AM | Date and Time Picker | Oct 10, 2026` before and after relaunch. |
| Narrow custom catalog layout and cancel | **Pass.** Opening custom food and adding one serving size exposed both serving-name fields in the 375-point editor. | **Pass.** Cancel returned to Food Log; Search for a food remained available. | Full test `testNarrowCustomServingCatalogLayoutAndCancel` passed. See [custom-layout-cancel-437.png](narrow-evidence/custom-layout-cancel-437.png). Catalog duplicate/zero-weight validation is covered by the normal lane; this narrow-specific test verifies layout and cancellation. |

## Narrow-screen inspection

The saved captures are 2× simulator screenshots of the 375 × 667-point display. The named-size fields fit within the editor width, and both serving rows, grams fields, and remove controls are visible together after dismissing the keyboard. The seeded portion screenshot shows the full macro preview and log controls after scrolling; the relaunch screenshot shows the `scoop (25 g)` picker, amount `2`, and computed `50 g` without clipping or overlap. Focus remained in the amount field while typing and the keyboard `Done` control was available. The tests exercised the keyboard dismissal and scroll-to-visible flows required to reach controls on this device.

No runtime-observed overflow, clipped field text, overlapping controls, focus loss, or inaccessible control was found in the three scenarios. XCUITest diagnostics recorded `Invalid frame dimension (negative or non-finite)` warnings during the Egg and Oats cases; both cases completed successfully, and the captures show no corresponding visible layout problem. Treat this as a diagnostic warning for follow-up only if it recurs with user-visible impact.

## Feedback categories

- Functional/data bugs: none found in the tested flows. Portion math, invalid zero rejection, logging, editing, persistence, Dashboard totals, and timestamp retention passed.
- Requirements/spec gaps or conflicts: none observed; expectations were taken from [`issue.md`](issue.md) and [`NAMED_SERVINGS.md`](../../NAMED_SERVINGS.md).
- Usability: entry controls and feedback remained reachable at 375 points after the keyboard was dismissed and the view scrolled.
- Accessibility: amount, serving-size, plus/minus, and date/time controls were found by the UI tests; invalid amount feedback was exposed. Timestamp accessibility values were stable through relaunch.
- Visual quality: both serving rows and the portion preview fit at the target size; no visible overflow, clipping, or overlap.
- Copy: zero-amount feedback was clear; no additional copy concern found.
- Permissions/privacy: not applicable to these local fixture workflows; no permission prompt or personal data surfaced.
- Testability: the updated test runner’s Done and scroll-until-hittable steps enabled the narrow workflows to complete. The earlier pre-437 run failures were runner/view-state issues and are superseded by this passing run.

## Evidence

- Final result bundle: `/tmp/issue3-narrow-437.xcresult` (summary: 3 passed, 0 failed, 0 skipped; device metadata confirms assigned UDID/model/OS).
- Full xcodebuild log: `/tmp/issue3-narrow-437.log`.
- Final screenshots: [egg-fractional-437.png](narrow-evidence/egg-fractional-437.png), [oats-relaunch-437.png](narrow-evidence/oats-relaunch-437.png), [custom-layout-cancel-437.png](narrow-evidence/custom-layout-cancel-437.png).
- Earlier `1.0.0+1-e133ae1955dd` runner attempts are preserved in `/tmp/issue3-narrow.xcresult`, `/tmp/issue3-narrow-final.xcresult`, and their logs; those attempts are not the final build verdict.
