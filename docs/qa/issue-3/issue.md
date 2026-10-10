wave: 0
depends: #6
blocks: none
conflicts: #1 #5
priority: feature

## Problem

QA-002 opened seeded Egg (`1 large egg (50 g)`) and found a fixed `Serving / Grams / Ounces` control with a stepper-only `1 srv` amount. There was no named serving-size selector or field to type `1.5` servings, both requested for the food-entry workflow. The automated tap on the stepper's exposed Add child did not change its value, but that test does not establish that physical touch is broken. The missing controls are visible and source confirmed.

## Scope

Make serving size and serving count separate controls: select a named, per-food serving size with a defined gram equivalent, then type or adjust a numeric amount of that size. Replace the fixed Serving/Grams/Ounces switch as the primary portion model. Define how foods obtain, edit, and present multiple named sizes, including custom foods; decide whether direct mass entry remains an additional option. Recalculate grams and nutrition live, and preserve the chosen size and amount when logging and editing. Define accepted precision, rounding, zero/negative rejection, and upper bounds. Evidence: `qa-handoffs/feedback/QA-002.md` F-003; `docs/qa/food-entry-runtime.md` FL-03; `docs/qa/screenshots/QA-002-serving-controls.png`. Build `1.0.0+1-441a78833d82`, iPhone 17 Pro/iOS 26.4, installed executable SHA-256 `441a78833d82de0de7cc57eeb0d07d4e5f12b8f3d7cea9fdd372db21e56094df`.

## Acceptance criteria

- [ ] A food exposes its available named serving sizes and each selected size's gram equivalent.
- [ ] A user can directly enter `1.5` serving units and see the corresponding weight and calorie/protein/fat/carbohydrate preview before save.
- [ ] Logged and reopened entries retain the selected serving size, quantity, computed nutrition, and timestamp.
- [ ] Custom foods can define usable named serving sizes under the documented catalog rule.
- [ ] Blank, nonnumeric, zero, negative, and excessive amounts receive clear feedback and cannot silently create an invalid entry.
- [ ] Any optional grams/ounces path has a clear conversion rule and does not obscure the named-size workflow.

## Verification

- Tier: B
- [ ] Exercise seeded Egg and a custom food with at least two named sizes, fractional quantities, edit, cancel, save, and relaunch.
- [ ] Compare preview, persisted grams/nutrients, timeline, and Dashboard across size and quantity changes.
- [ ] Test invalid and boundary amounts after the product precision and range rules are set.
- [ ] Test the current stepper separately with a manual or accessibility-adjustable input channel; do not use the inconclusive XCUITest child tap as a defect assertion.

