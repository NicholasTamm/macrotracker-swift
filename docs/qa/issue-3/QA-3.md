---
id: QA-3
type: qa_journey
title: Named serving save edit and persistence
status: complete
owner: Luna
updated_at: 2026-10-10T04:59:00-07:00
depends_on: []
build_id: 1.0.0+1-4375880845b5
executable_sha256: 04cbe123d75ae2686e49e26ec4c1973e8c5b3e3e016c1a654842e123b19d9a8f
code_dylib_sha256: 4375880845b5fbfdf59a398daf9b855190c7467172f285627f38b99e16c43c4a
device: Issue 3 Serving QA
udid: 8665048C-59D6-405E-9851-3DE097ED4F52
ios_version: 26.4
github_issue: https://github.com/NicholasTamm/macrotracker-swift/issues/3
---

Final QA used supported XCUITest input on the assigned iPhone 17 Pro simulator, iOS 26.4. Bundle: `com.nicholastamm.MacroFactorClone`. Build ID: `1.0.0+1-4375880845b5`. Built 2026-10-10 04:40:39 PDT from source revision `9d4fdc9b86cc1c75d1b5e6db63793b30a3acd469` plus the frozen issue #3 changes. Launcher SHA-256: `04cbe123d75ae2686e49e26ec4c1973e8c5b3e3e016c1a654842e123b19d9a8f`; app code dylib SHA-256: `4375880845b5fbfdf59a398daf9b855190c7467172f285627f38b99e16c43c4a`. Both installed hashes match the built app. Derived data: `/tmp/issue3-final-derived`.

The normal lane passed all eight issue-specific UI scenarios across `/tmp/issue3-final-qa7.xcresult` and the final targeted rerun `/tmp/issue3-final-qa12.xcresult`. The six successful UI scenarios from QA7 plus the two QA12 reruns cover the same build ID and app code hash; QA7's first attempts at custom creation and first-size removal had test-input/setup failures, then both passed in QA12 after correcting the XCUITest input and checking entered values. The 21 unit tests passed in `/tmp/issue3-final-qa7.xcresult` (16 DataLayer, 5 FoodLogFeature). The separate narrow lane passed 3/3 on the same app build; see [QA-3-NARROW.md](QA-3-NARROW.md) and [NARROW-REPORT.md](NARROW-REPORT.md).

## Scenario results

| Scenario | Result | Observed result and evidence |
|---|---|---|
| Seeded egg fractional serving, stepper, cancel | Pass | 1.5 eggs displayed 75 g and 116.2 kcal; stepper changed the count and cancel created no log. The stored math is 116.25 kcal; the existing formatter displays the tie as 116.2. QA7. |
| Custom food with two named sizes and nutrients | Pass | Created bowl 100 g and scoop 25 g with 120 kcal, 10 g protein, 4 g fat, 18 g carbs per basis. Selecting scoop showed 25 g, 30 kcal, 2.5 g protein, 1 g fat, 4.5 g carbs. Screenshot: [custom-food-two-sizes.png](normal-evidence/custom-food-two-sizes.png). |
| Catalog invalid values, duplicate name, cancel | Pass | Duplicate serving name and zero weight left Save disabled; cancel left the uncommitted food absent from search. QA7. |
| Custom named-size edit, save, and relaunch | Pass | Oats entry changed to 2 scoops, persisted as 50 g / 60 kcal after relaunch, and appeared in the timeline. The Dashboard total increased by baseline +60 kcal. Screenshot: [oats-relaunch.png](normal-evidence/oats-relaunch.png). |
| First-size removal and nutrient-basis preservation | Pass | With bowl 100 g, scoop 25 g, and basis 120 kcal, blank/invalid first-size input remained invalid; valid 100→200→100 updates scaled calories 120→240→120. Removing bowl left scoop at 25 g and recalculated the basis/preview to 30 kcal. Screenshot: [first-size-removed-preview.png](normal-evidence/first-size-removed-preview.png). |
| Legacy precision on unchanged details save/relaunch | Pass | Legacy 37.555 g remained exactly 37.555 g after save and relaunch (formatted display 37.6 g). QA7. |
| Invalid amount matrix and boundaries | Pass | UI covered blank, nonnumeric, negative, zero, too-precise and excessive amounts with validation/disabled action. Direct Gram entry accepted 0.01 g and 1000 g and rejected 1000.01 g; count/unit limits were also exercised. QA7. The DataLayer boundary test passed. |
| Timestamp retention through edit/relaunch | Pass | Oats timestamp accessibility value matched before and after save/relaunch at displayed precision: `4:00 AM | Date and Time Picker | Oct 10, 2026`. QA7 log. |
| Narrow supported layout | Pass | Separate iPhone SE (3rd generation), 375 pt lane passed the Egg, Oats persistence, and custom catalog layout/cancel paths 3/3 on the same build. See narrow report. |

## Verification details and feedback

QA7's two initial UI test failures were caused by the test helper swiping the numeric keyboard: the gesture entered a trailing zero, changing intended carbs 18 to 180 and calories 120 to 1200. QA11 logged the before/after values. The helper was corrected to use a non-keyboard navigation-bar tap; QA12 then verified exact entered values and passed both affected scenarios. This was a test-harness issue, not a product defect. QA7 overall therefore remains a diagnostic run with two failed attempts; QA12 is the final evidence for those two scenarios. No other app code changed after build 437.

Visual inspection of QA12 attachments found the custom two-size preview and post-removal serving screen aligned without overlap or clipping. The lower nutrient rows are available by scrolling; the keyboard in the pre-removal capture is expected while editing. The narrow lane separately confirmed the two serving rows fit at 375 pt. No functional/data, requirements, usability, visual, copy, or privacy defect was observed in the covered paths. Accessibility-driven XCUITest locators worked; a manual VoiceOver audit was not part of this lane. No new permission was requested. Source-file hashes for the frozen production implementation are recorded in [final-source-sha256.txt](final-source-sha256.txt).

The final focused UI result bundle is `/tmp/issue3-final-qa12.xcresult`; QA7 diagnostics and successful test cases are in `/tmp/issue3-final-qa7.xcresult` and `/tmp/issue3-final-qa7.log`. Narrow result bundle: `/tmp/issue3-narrow-437.xcresult`. No required runtime scenario remains blocked or unrun.
