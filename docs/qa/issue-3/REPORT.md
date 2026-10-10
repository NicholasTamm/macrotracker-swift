# QA-3 runtime report — Named serving save, edit, and persistence

Build `1.0.0+1-4375880845b5` (marketing version 1.0.0, build 1), built 2026-10-10 04:40:39 PDT from `9d4fdc9b86cc1c75d1b5e6db63793b30a3acd469` plus the frozen issue #3 changes. Bundle: `com.nicholastamm.MacroFactorClone`. Launcher stub SHA-256: `04cbe123d75ae2686e49e26ec4c1973e8c5b3e3e016c1a654842e123b19d9a8f`; `MacroFactorClone.debug.dylib` SHA-256: `4375880845b5fbfdf59a398daf9b855190c7467172f285627f38b99e16c43c4a`. Both were verified in the installed app and match the derived build. Derived data: `/tmp/issue3-final-derived`.

Normal device: Issue 3 Serving QA, iPhone 17 Pro simulator, iOS 26.4 (23E244), UDID `8665048C-59D6-405E-9851-3DE097ED4F52`. The six passing UI methods in QA7 plus the two final targeted QA12 reruns cover all eight issue-specific UI methods on the same app code hash. QA7 initially failed two custom-food scenarios because its keyboard swipe appended zeroes to numeric fields; after replacing that test gesture and verifying the inputs, QA12 passed both. Do not count QA7's initial failed attempts as passing. Unit tests: 21/21 passed in `/tmp/issue3-final-qa7.xcresult` (16 DataLayer, 5 FoodLogFeature). QA12 result bundle and log: `/tmp/issue3-final-qa12.xcresult`, `/tmp/issue3-final-qa12.log`; QA7: `/tmp/issue3-final-qa7.xcresult`, `/tmp/issue3-final-qa7.log`.

Narrow device: iPhone SE (3rd generation), 375 pt, iOS 26.4, UDID `ACC76FC2-EF42-4A46-A287-11E11CEC229E`. The separate lane passed 3/3 bounded UI cases using the same build and code hashes. See [QA-3-NARROW.md](QA-3-NARROW.md) and [NARROW-REPORT.md](NARROW-REPORT.md); result bundle `/tmp/issue3-narrow-437.xcresult`.

Expected behavior comes from `docs/qa/issue-3/issue.md` and `docs/NAMED_SERVINGS.md`. The existing `MFFormat.grams` formatting displays 116.25 kcal as 116.2 kcal; the initial 116.3 ticket expectation was corrected. This is formatting of the full-precision value, not a nutrient-storage discrepancy.

## Scenario results

| Workflow | Result | Evidence |
|---|---|---|
| Seeded egg fractional amount, stepper, and cancel | Pass | 1.5 eggs → 75 g and 116.2 kcal; stepper changed the amount, and cancel created no entry. QA7. |
| Create custom food with two named serving sizes | Pass | Bowl 100 g and scoop 25 g, basis 120 kcal / 10 g protein / 4 g fat / 18 g carbs. Scoop preview displayed 25 g, 30 kcal / 2.5 g protein / 1 g fat / 4.5 g carbs. Screenshot: [custom-food-two-sizes.png](normal-evidence/custom-food-two-sizes.png). |
| Reject duplicate/zero serving definitions and cancel | Pass | Save stayed disabled for duplicate names and zero grams; canceled food was absent from search. QA7. |
| Edit named size, persist on relaunch, check timeline and Dashboard | Pass | Oats persisted at 2 scoops / 50 g / 60 kcal after relaunch, appeared in timeline, and Dashboard increased by baseline +60 kcal. Screenshot: [oats-relaunch.png](normal-evidence/oats-relaunch.png). |
| Remove first custom size and rescale nutrient basis | Pass | Blank/invalid first-size weight did not replace the valid basis; 100→200→100 g scaled calories 120→240→120. Removing bowl left scoop 25 g and preview 30 kcal. Screenshot: [first-size-removed-preview.png](normal-evidence/first-size-removed-preview.png). |
| Save legacy amount without changing it | Pass | Exact 37.555 g retained after details save and relaunch; formatted view was 37.6 g. QA7. |
| Amount invalid matrix and range boundaries | Pass | UI checked blank, nonnumeric, negative, zero, excess precision, and excessive amount. Direct Gram accepted 0.01 g and 1000 g, rejected 1000.01 g; count/unit boundary cases were checked. QA7. DataLayer validation test also passed. |
| Timestamp retained through edit and relaunch | Pass | Accessibility value before and after was `4:00 AM | Date and Time Picker | Oct 10, 2026`. QA7 log. |
| Narrow layout and cancel | Pass | Three bounded tests passed on 375 pt: Egg fraction/stepper/cancel, Oats amount edit/relaunch, and custom catalog layout/cancel. Narrow report contains detail. |

The initial QA7 attempts at custom creation and first-size removal failed due to XCUITest input handling. QA11 demonstrated the cause: swiping over the numeric keyboard changed 18 to 180 and 120 to 1200 by entering a trailing zero. QA12 used a non-keyboard tap and confirmed the intended values before saving; both scenarios passed. Treat this as resolved test-harness diagnosis, not a product failure. QA12's pre-removal screenshot shows the keyboard while the field is actively edited; post-removal preview shows the remaining serving. Visual inspection found no overlap or clipping, and the below-fold macro rows are scrollable. See `/tmp/issue3qa12-attachments/318A2B1B-9978-4A2D-8811-CE3925B67B54.png` and `/tmp/issue3qa12-attachments/4683B341-39AC-4BF9-B926-28B58F33740E.png`.

Feedback: No runtime functional/data, spec, usability, visual, copy, or privacy defect was found in exercised paths. XCUITest accessibility locators worked; a manual VoiceOver audit was not performed. The workflows requested no new permission. Frozen production file hashes are in [final-source-sha256.txt](final-source-sha256.txt). All required runtime scenarios are complete; QA-3 status is `complete`.
