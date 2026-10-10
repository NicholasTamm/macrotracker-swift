# Code Review: Issue #3 named serving sizes

**Reviewer**: AI Principal Engineer, independent review agent  
**Scope**: Full issue #3 working-tree changes against `9d4fdc9b86cc1c75d1b5e6db63793b30a3acd469`: models, repositories, editors, root/view-model integration, fixtures, project registration, tests, documentation.  
**Context**: Separate per-food named serving sizes from typed quantity while retaining historical nutrition and timestamp.  
**Vote**: **PASSES**

## Summary

The additive serving catalog and per-entry selection snapshot fit the existing per-100-g nutrition model. Both initial blocking findings are resolved: unchanged legacy portions retain exact weight, and custom-food basis changes synchronously rescale nutrient drafts. Independent GPT-6 Luna QA covers the issue acceptance paths on the same production binary at normal and narrow supported native widths. No blocking finding remains.

## Findings

### Blocking

None.

### Suggestions

#### S1: Preserve selection metadata through copy operations
**Location**: `Sources/DataLayer/Repositories/LogRepository.swift:L340-L352`; `Sources/FoodLogFeature/FoodLogClipboard.swift:L17-L61`  
**Issue**: Copy day and entry/block clipboard snapshots retain weight but omit the new serving size and count. A copied 1.5-scoop entry can reopen as a fractional primary size. This is outside issue #3's log/edit acceptance scope and does not block this change.  
**Suggestion**: Carry optional serving selections through copy snapshots and repository operations in a follow-up, with a copy/reopen persistence check.
```swift
copy.setServingSelection(entry.servingSelection)
```

### Nits

None.

## Resolution of initial findings

- **B1 resolved**: Exact quantity text and unchanged-portion saving preserve original grams and selection without new-entry precision/range validation. Runtime QA retained exact 37.555 g after save and relaunch.
- **B2 resolved**: The primary grams binding synchronously rescales all seven nutrient fields; removing the primary size converts to the next basis before replacing the array. Empty, nonnumeric, zero, negative, nonfinite, and excessive temporary weights leave the last valid basis intact. Runtime QA verified blank/invalid input, 100→200→100 g with 120→240→120 kcal, and bowl removal yielding a 25-g scoop with 30 kcal.
- **Initial S1 resolved**: Custom serving-weight drafts use an exact numeric representation instead of the rounded display formatter.
- Plus/minus controls use borderless styling to isolate actions in a SwiftUI List row. The test helper explicitly deletes selected text, checks entered values, and dismisses the keyboard without swiping across numeral keys.

## Verification and provenance

Reviewed full acceptance in [issue.md](docs/qa/issue-3/issue.md), final [normal report](docs/qa/issue-3/REPORT.md), [narrow report](docs/qa/issue-3/NARROW-REPORT.md), and their completed tickets/index. This reviewer inspected code and existing test results; runtime QA was performed by independent Luna lanes.

- **Build**: `1.0.0+1-4375880845b5`, built 2026-10-10 04:40:39 PDT; bundle `com.nicholastamm.MacroFactorClone`.
- **Code dylib SHA-256**: `4375880845b5fbfdf59a398daf9b855190c7467172f285627f38b99e16c43c4a`. Launcher SHA-256: `04cbe123d75ae2686e49e26ec4c1973e8c5b3e3e016c1a654842e123b19d9a8f`.
- **Source identity**: Base above plus issue #3 changes. All ten frozen source/project hashes in [final-source-sha256.txt](docs/qa/issue-3/final-source-sha256.txt) independently checked and matched reviewed files. `git diff --check` passed.
- **Normal**: iPhone 17 Pro, iOS 26.4, UDID `8665048C-59D6-405E-9851-3DE097ED4F52`. Six successful UI scenarios and 21 unit tests (16 DataLayer, five FoodLogFeature) in `/tmp/issue3-final-qa7.xcresult`; remaining two UI scenarios passed in `/tmp/issue3-final-qa12.xcresult`. Reviewer independently read QA12 summary: two passed, zero failed/skipped, assigned device confirmed.
- **Narrow**: iPhone SE (3rd generation), 375×667 pt, iOS 26.4, UDID `ACC76FC2-EF42-4A46-A287-11E11CEC229E`; three passed cases in `/tmp/issue3-narrow-437.xcresult`, same production hash. This is supported native iOS coverage; no browser-width test is claimed.
- **Acceptance**: Seeded Egg fraction/stepper/cancel; custom two-size creation and all four macro previews; duplicate/zero catalog rejection; selection/count save/edit/relaunch; legacy precision; invalid amount matrix; direct Gram conversion/bounds; timeline/Dashboard comparison; timestamp retention all passed.

QA7's initial two custom-food failures remain diagnostic failures, not passes: a keyboard swipe entered an extra zero. QA11 captured the input mutation; QA12 used corrected input and passed both affected scenarios. Product source stayed frozen. Manual VoiceOver quality was not audited; reports establish accessibility-driven control operation only.

## Dimension Summary

| Dimension | Assessment |
|-----------|-----------|
| Design & Architecture | Additive catalog and selection snapshots retain legacy compatibility and historical portion meaning. |
| Implementation Correctness | Portion preservation, synchronous basis conversion, repository scaling, and editor preview agree; initial blockers resolved. |
| Style & Conventions | SwiftUI state/bindings fit the architecture and row actions are isolated. |
| Testing & Verification | Focused persistence/validation tests and independent normal/narrow acceptance evidence pass on the frozen production binary. |
| Security | No material security concern found in this local data change. |
| Performance | Small serving catalogs introduce no material performance concern. |
| Scope Alignment | Issue #3 acceptance paths covered; copy metadata remains a nonblocking follow-up. |

## Verdict

**PASSES**. The reviewed changes are ready for the issue-handler's PR gates. Retain source/build provenance and verify that merged source matches the frozen implementation. Copy-selection preservation can be addressed separately.
