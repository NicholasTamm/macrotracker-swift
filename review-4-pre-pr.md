# Code Review: Issue #4 visible food names

**Reviewer**: AI Principal Engineer
**Scope**: Issue #4 diff against branch base `5c8e8d4f90339fd7aceab0237010d0d6010a7562` in `FoodTimelineView.swift`, `AppServices.swift`, `project.yml`, generated Xcode project and scheme, and `FoodTimelineNameTests.swift`; `docs/qa/issue-4-food-name.md` and its five simulator screenshots
**Context**: Make logged foods visibly identifiable in the timeline while retaining calories, tap behavior, and one useful VoiceOver identity
**Vote**: **PASSES**

---

## Summary

The change puts the full food name between the thumbnail and calorie value, widens the tile at accessibility text sizes, and retains the existing explicit accessibility label. The DEBUG-only fixture logs two foods with identical fallback artwork, and the UI test checks visible distinguishing words before and after relaunch, horizontal scrolling, and the edit tap. The supplied screenshots show the intended behavior on iPhone 17e, AX Large, and 375-point iPhone SE 3rd generation.

---

## Findings

### Blocking

None.

### Suggestions

#### S1: Scope the OCR assertions to the entry tiles

**Location**: `Tests/FoodLogUITests/FoodTimelineNameTests.swift:L45-L54`
**Issue**: The Vision assertion searches the whole screenshot. If a future header, toast, or overlay contains `nonfat` or `whole`, the test can pass without proving that the tile visibly renders that word. The accessibility lookup and screenshot attachments reduce this risk, and the reviewed screenshots confirm the current behavior.
**Suggestion**: Crop each screenshot to the matching entry button's screen frame before OCR, or verify the recognized word's bounding box intersects that frame. This can be done in a follow-up test improvement.

### Nits

None.

---

## Verification and limits

- The supplied iPhone 17e screenshots show both names and calorie values immediately and after relaunch. Both foods use the same fallback image yet are distinguishable.
- All five screenshots committed under `docs/qa/screenshots/issue-4/` are byte-identical to the screenshots I inspected before the QA document was added. The document's device-specific visual results and stated limits match those images.
- The supplied 375-point iPhone SE 3rd generation screenshot shows both complete distinguishing names and calories without overlap.
- At AX Large, the first tile's name and calories are readable; after horizontal scrolling the second tile's name and calories are readable. The tile remains tappable by the UI test. The supplied UI test run passed in all three configurations; I did not rerun it independently.
- The full Xcode scheme subsequently passed on the 375-point SE3 simulator: 13 DataLayer tests, 30 CoachingEngine tests, and 1 FoodLog UI test, with zero failures. I verified those suite totals and `** TEST SUCCEEDED **` in `/private/tmp/issue4-all-tests.log`.
- AX Large screenshots also show clipping in the existing week/day summary and hour header. Those components are outside the changed tile code and outside issue #4. The 320-point SE1 simulator is unavailable on the supplied iOS 26.4 runtime.
- `git diff --check` passes. The test fixture is compiled only under `DEBUG`; the release path does not seed entries.

## Dimension Summary

| Dimension | Assessment |
|-----------|------------|
| Design & Architecture | The tile change stays in the timeline view; the test fixture is confined to the DEBUG composition root. |
| Implementation Correctness | Names, calories, and tap handling are preserved at the reviewed sizes; the explicit VoiceOver label names each food once. |
| Style & Conventions | The SwiftUI code follows local token and modifier conventions. The generated project change reflects the UI test target. |
| Testing & Verification | The UI test exercises persistent entries, fallback images, relaunch, horizontal scroll, accessibility labels, and edit tap; screen-wide OCR could be more precise. |
| Security | No security-relevant production path changes. |
| Performance | One text view per visible tile and a small DEBUG-only fixture have no material cost. |
| Scope Alignment | The implementation addresses issue #4 without changing unrelated day summary or hour-header layout. |

---

## Verdict

**PASSES.** The issue #4 acceptance criteria are supported by the code, passing reported UI runs, and inspected screenshots. Narrowing OCR to tile bounds would improve future regression detection but does not block this change.
