# Issue #2 — Food Log paste simulator QA

## Build and test provenance

- Base: `origin/main` at `4fe39d9` (includes merged PR #9).
- Xcode 26.4 (`17E192`); dedicated iPhone 17 Pro simulator `58596D73-F460-408B-91F9-448B99ADD2C5`, iOS 26.4.
- Debug app dylib SHA-256: `c9831e1298124cd0a1e6a8af133f7c917b58a477c703e03f28c41efb2a05e257`.
- Focused live XCUITest: `FoodPasteUITests/testSingleFoodAndHourBlockPasteIntoSelectedDay` passed (1/1), result `/private/tmp/issue2-ui-final2.xcresult`.
- Regression run after resetting the dedicated simulator: 49/49 passed, zero skips, including the existing food-name XCUITest and five new Food Log paste integration tests; result `/private/tmp/issue2-regression-final.xcresult`. The paste UI case was run separately to keep its fixture data isolated, making 50 passing tests in total.

## Observed behavior

The Debug fixture inserts two standard food entries into Today through the production repositories at 11:05 and 11:42, 120 kcal each. The XCUITest uses the real tile context menu, Day menu, and day-navigation buttons.

| Step | Live Food Log result | Evidence |
| --- | --- | --- |
| Before paste | Today: two entries, 240 kcal and 20 g protein | [Today source](screenshots/issue-2/today-source.png) |
| Copy Egg, select Yesterday, Paste food | Yesterday: one Egg, 120 kcal and 10 g protein | [Single paste](screenshots/issue-2/yesterday-single.png) |
| Relaunch app | Yesterday remains one Egg, 120 kcal; clipboard has no Paste item | [After relaunch](screenshots/issue-2/yesterday-relaunch.png) |
| Copy the two-food 11 AM block from Today and paste to Yesterday | Yesterday: three entries, 360 kcal and 30 g protein; Today still two entries, 240 kcal | [Block paste](screenshots/issue-2/yesterday-block.png) |
| Paste block a second time, relaunch | Yesterday retains five entries; Today still has the original two | XCUITest assertions |
| Check Dashboard before paste, after paste, and after relaunch | Today's source remains 240 kcal on Dashboard | XCUITest accessibility assertions |

The five `FoodPasteTests` use the real SwiftData repositories and a fresh model context to verify stored timestamps, source and destination counts, calories, meal slots, minutes, past and future destinations, empty clipboard, repeat paste, failed write, partial block write, and fallback on the Vancouver spring DST gap. The default source-clock-time and clipboard rules are in [FOOD_PASTE_RULES.md](../FOOD_PASTE_RULES.md).

## Limits

- The XCUITest verifies Dashboard's Today total stays at 240 kcal. The Dashboard has no selected-past-day view, so Yesterday's total is verified on Food Log and in the repository tests.
- The failed-write path is verified in integration tests using an invalid amount; the live UI test did not inject a storage failure.
- QA-003 Quick Add paste is a separate issue and was not classified by these food/block checks.
