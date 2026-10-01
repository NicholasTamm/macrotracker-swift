# CaptureFeature (issue #5)

Fast-logging inputs for the MacroFactor clone: barcode scanning, nutrition-label
OCR, AI photo logging, voice logging, and recipe import (URL + cookbook photo).

## Layout

| Path | Contents |
|---|---|
| `CaptureFeature.swift` | Module entry: `CaptureMethod`, `CaptureDependencies`, `CaptureMenuView` (the six-method hub AppShell embeds) |
| `CaptureDraft.swift` | Editable food candidate every flow produces; `saveFood(using:)` / `saveAndLog(using:)` |
| `NutritionDraftEditorView.swift` | Shared editable nutrition draft screen (design-system components only) |
| `MFPermissionCenter.swift` | Camera/mic/speech permission state + `MFPermissionGate` / `MFPermissionDeniedView` |
| `MFImagePicker.swift` | Camera / photo-library picker |
| `Barcode/` | `MFBarcodeScanner.swift` (VisionKit `DataScannerViewController` wrapper + AVFoundation fallback), `BarcodeFlowView.swift` (scan → OFF lookup → found / not-found → create custom) |
| `Label/` | `MFVisionOCR.swift` (Vision `VNRecognizeTextRequest` wrapper), `NutritionLabelParser.swift` (OCR lines → per-100-g nutrients), `LabelScanFlowView.swift` |
| `Photo/` | **`PhotoLoggingService.swift` — STUB seam (see below)**, `PhotoLogFlowView.swift` |
| `Voice/` | `VoiceRecognizer.swift` (`SFSpeechRecognizer` live dictation), `VoiceFoodParser.swift` (transcript → items), `VoiceLogFlowView.swift` |
| `Recipe/` | `RecipeURLParser.swift` (schema.org JSON-LD), `RecipeImportFlowView.swift` (URL + cookbook OCR → `RecipeDraft` → `createRecipe`) |
| `Shared/` | `QuantityParser.swift` ("2 cups" → grams), `FoodMatchSheet.swift` (DB-match sheet for voice/recipe) |

All copy is original. Icons are SF Symbols from `MFIconCatalog`
(`barcode.viewfinder`, `text.viewfinder`, `camera.viewfinder`, `mic.fill`,
`book.pages`) — no emoji anywhere.

## Photo logging stub

> **STUB — not real AI.** `Photo/PhotoLoggingService.swift` defines the
> `PhotoLoggingService` protocol and a clearly-marked `StubPhotoLoggingService`
> that returns hardcoded demo items (flagged `isStubEstimate`, with a visible
> "Demo estimate" banner in the UI). The full local draft-review UI
> (`PhotoLogFlowView`) is real and complete; only the network call is faked.

Swapping in a real backend later is a one-line change: pass your own
`PhotoLoggingService` into `CaptureDependencies` instead of the default
`StubPhotoLoggingService()`. A real implementation should upload the JPEG,
decode the backend's JSON into `PhotoMealEstimate`, and **throw on failure
instead of fabricating data** — the UI presents every value as an editable
estimate.

## Info.plist keys (for AppShell / the Xcode project)

`CaptureFeature` does **not** own Info.plist — the app target does. These keys
must be wired there before the capture flows can request access:

| Key | Suggested usage string |
|---|---|
| `NSCameraUsageDescription` | "Scan barcodes, nutrition labels, meals, and cookbook pages to log food faster." |
| `NSMicrophoneUsageDescription` | "Record your spoken meal descriptions for voice logging." |
| `NSSpeechRecognitionUsageDescription` | "Turn your spoken meal descriptions into text for logging." |
| `NSPhotoLibraryUsageDescription` | "Pick meal and cookbook photos from your library." |

All strings are original copy (not copied from any app). Each flow gates on
`MFPermissionCenter` and shows a graceful denial state with an "Open Settings"
shortcut when access is denied or restricted.

## Notes for integrators (AppShell)

- Construct `CaptureDependencies(foods:search:log:)` with the live
  repositories and embed `CaptureMenuView(deps:)` in the QuickLogSheet or
  Food Log navigation stack.
- Capture flows vend `FoodItem`s into DataLayer and log via `LogRepository`;
  the timeline UI stays in `FoodLogFeature` (#4).
- Barcode lookup order: local DB → OFF cache → live Open Food Facts
  (`FoodSearchService.lookupBarcode`). Not found → editable custom-food draft
  prefilled with the barcode (source `.custom`, entry source `.barcode`).
- Label OCR basis detection: "per 100 g" tables stay as-is; "per serving"
  values are normalized to per-100-g using the parsed serving size
  (100 g assumed, flagged in the draft note, when no serving size is found).
- Voice transcript parsing is heuristic (digits + units); unmatched voice
  items save as `.voiceEstimate` foods with a note, matched items resolve to
  real database nutrition.
- Recipe import requires ≥1 ingredient matched to a database food; unmatched
  lines are skipped with an on-screen notice.

## Verification

Swift cannot compile on this Linux machine — all code is written to review
standard. The user's first Xcode build is the real verification.
