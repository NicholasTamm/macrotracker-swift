# Code Review: Issue #1 custom food logging handoff

**Reviewer**: AI Principal Engineer (independent of implementation)
**Scope**: Worktree diff against `origin/main` at `5c8e8d4`: `Sources/FoodLogFeature/FoodLogRootView.swift` (30 changed lines) and `docs/qa/issue-1/` (verification record and three screenshots), with the related custom food editor, detail editor, view model, and repository inspected for context.
**Context**: After creating a custom food from Food Log, open the amount, time, and nutrition preview before the user explicitly logs it. Preserve cancel and existing food edit behavior.
**Vote**: **PASSES**

---

## Summary

The change carries the saved `FoodItem` from the custom food sheet into the existing food detail editor, retains the originating timeline hour, and selects the logged date when it differs from the visible day. The new path writes a log entry only after the user taps **Log food**. Code inspection and iOS 26.4 simulator runs support all four acceptance criteria; no blocking issue was found.

---

## Findings

### Blocking

None.

### Suggestions

#### S1: Surface a failed log write
**Location**: `Sources/FoodLogFeature/FoodLogRootView.swift:L531-L539`
**Issue**: If `viewModel.logFood` returns `false`, the editor remains open without showing the error. This is inherited from the search result flow, but the new custom food path uses it too. The data layer rejects invalid amounts and can throw on persistence errors.
**Suggestion**: Show `viewModel.lastError` or a generic failure message in the existing toast or alert path. This is not a blocker for issue #1 because the successful and cancel paths work, and no failure was observed in the simulator.

```swift
if ok {
    // Existing success handling.
} else {
    showToast(viewModel.lastError ?? "Couldn't log food")
}
```

### Nits

None.

---

## Acceptance and verification

| Requirement | Evidence | Assessment |
|---|---|---|
| Saving a new custom food opens amount, time, and nutrition preview | `FoodLogRootView.swift:L477-L489` passes the persisted item to the same `FoodDetailEditorView` used by search; direct and cancel UI tests assert the `Log food` sheet, amount, date picker, and 120/10/4/18 preview. | Pass |
| Logging creates exactly one entry and updates the chosen day/hour and totals | Direct-create UI test taps **Log food**, asserts one matching tile and 120 kcal immediately, then one tile after relaunch. `FoodLogRootView.swift:L434-L438` preserves timeline hour; `L531-L539` selects the logged date when needed. | Pass for default selected day/hour; changed date and hour are code inspected, not separately exercised |
| Cancel creates no entry and retains the saved food | Cancel UI test asserts zero tiles, then re-searches and logs the saved food. | Pass |
| Existing custom food edit path remains available | Library edit UI test enters **Edit food**, saves changes, observes the success toast and retained log entry. `FoodLogRootView.swift:L506` continues to route existing food to the edit case. | Pass |

The Xcode 26.4 simulator runs used isolated iOS 26.4 device `A0851E73-412C-43C3-A9AF-F08210CA43DF`; the installed executable SHA-256 was `ccbd2d72f67d2fde9ee02abd6257a0e574aed7aee840950f7524163b3b98f57d`. The three passing XCUITest result bundles are `/private/tmp/issue1-ui-pass.xcresult`, `/private/tmp/issue1-ui-direct.xcresult`, and `/private/tmp/issue1-ui-edit.xcresult` (one test and zero failures each). I inspected the exported preview and post-log screenshots from the first and direct runs and checked that the committed-candidate screenshots in `docs/qa/issue-1/` match the result-bundle exports byte for byte. Its `VERIFICATION.md` accurately records the observed paths and serving-control limit. The project test suite passed 13 DataLayer and 30 CoachingEngine tests in `/private/tmp/issue1-unit.xcresult`; the app build and `git diff --check origin/main` passed.

The previous XCUITest tap on the existing `MFStepper` did not visibly adjust the amount. QA-002 called serving adjustment inconclusive, and issue #3 owns serving input. Thus an adjusted amount and its recalculated preview were not independently verified here. The preview's default amount and nutrition, date picker presence, direct log action, persistence, and existing edit flow were verified. My attempt to take an additional live simulator screenshot was blocked by the review process's CoreSimulatorService connection; the XCUITest screenshots and results remained available for inspection.

---

## Dimension Summary

| Dimension | Assessment |
|-----------|------------|
| Design & Architecture | Reuses the established detail editor and repository path; no new model or persistence abstraction. |
| Implementation Correctness | Saved item reaches preview, logging is explicit, cancel is non-logging, and cross-day selection follows a successful write. |
| Style & Conventions | Matches the view's existing sheet transition and `FoodLogSheet` identity patterns. |
| Testing & Verification | Unit suite and three simulator UI paths pass; adjusted serving and changed date/hour remain verification limits. |
| Security | No new external input, authorization boundary, or secret handling. |
| Performance | Only a constant-time sheet transition and normal existing repository calls were added. |
| Scope Alignment | Confined to issue #1's create-to-log handoff, selected day visibility, and existing edit routing. |

---

## Verdict

**PASSES.** The required create, preview, direct log, cancel, persistence, and edit flows work on the fixed iOS simulator build. The failed-log feedback suggestion can be handled separately; the serving adjustment verification limit belongs to issue #3.
