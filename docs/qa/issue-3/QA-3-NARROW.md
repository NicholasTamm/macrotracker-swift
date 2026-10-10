---
id: QA-3-NARROW
type: qa_journey
title: Named serving controls on smallest supported phone
status: complete
owner: issue3_narrow_qa
updated_at: 2026-10-10T04:45:00-07:00
depends_on: []
build_id: 1.0.0+1-4375880845b5
executable_sha256: 04cbe123d75ae2686e49e26ec4c1973e8c5b3e3e016c1a654842e123b19d9a8f
code_dylib_sha256: 4375880845b5fbfdf59a398daf9b855190c7467172f285627f38b99e16c43c4a
device: Issue 3 Narrow QA
udid: ACC76FC2-EF42-4A46-A287-11E11CEC229E
ios_version: 26.4
github_issue: https://github.com/NicholasTamm/macrotracker-swift/issues/3
---

Final source identity: `9d4fdc9b86cc1c75d1b5e6db63793b30a3acd469` plus the frozen issue #3 source diff. Bundle `com.nicholastamm.MacroFactorClone`, version 1.0.0, build 1. Build ID `1.0.0+1-4375880845b5`, built 2026-10-10 04:40:39 PDT. Device: iPhone SE (3rd generation), 375 pt, iOS 26.4. Installed launcher SHA-256 `04cbe123d75ae2686e49e26ec4c1973e8c5b3e3e016c1a654842e123b19d9a8f`; installed debug dylib SHA-256 `4375880845b5fbfdf59a398daf9b855190c7467172f285627f38b99e16c43c4a`. Both hashes were verified before and after the run.

Final bounded XCUITest run used the prebuilt `/tmp/issue3-final-derived/Build/Products/MacroFactorClone_iphonesimulator26.4-arm64.xctestrun` with `test-without-building`; no product rebuild occurred. On 2026-10-10 04:41–04:43 PDT, these cases passed on the assigned UDID: `testSeededEggLegacySizeFractionAndStepperCancel`, `testCustomNamedSizeTypedAmountEditAndRelaunch`, and `testNarrowCustomServingCatalogLayoutAndCancel`. Result bundle: `/tmp/issue3-narrow-437.xcresult`; full log: `/tmp/issue3-narrow-437.log`; detailed results and screenshot links: [`NARROW-REPORT.md`](NARROW-REPORT.md).

The lane passed its happy paths for Egg fractional preview/stepper/cancel, Oats negative zero feedback and disabled log, custom named-size fractional logging/edit/relaunch with Dashboard and timestamp checks, and narrow custom catalog layout/cancel. The test confirmed both serving-name rows fit at 375 pt after keyboard dismissal. Catalog duplicate/zero-weight validation was covered by the normal device lane; this narrow ticket specifically verified the catalog’s layout and cancel path. Feedback categories and visual evidence are documented in the report. Earlier runs against build `1.0.0+1-e133ae1955dd` are retained as historical diagnostics and do not change this final result.
