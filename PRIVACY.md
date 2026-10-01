# Privacy — MacroFactorClone

**Posture: data never sold, no ads, no tracking.** This document is the
single source of truth for the app's privacy story: the privacy manifest,
the App Store privacy labels, and the reasoning behind both. Written for
issue #12 (release polish), 2026-09-28.

## Summary

- **No account.** There is no sign-up, no sign-in, no server-side user
  record. (The paywall/subscription system was cancelled — issue #11 — so
  there is no StoreKit, no receipt, no purchase history either.)
- **All personal data stays on the device.** Food log, weigh-ins, body
  measurements, progress photos, habits, step counts, program settings, and
  coaching history live in the on-device SwiftData store (with an optional,
  user-toggled CloudKit private-database sync designed in `MFSyncController`
  — Apple's CloudKit, not our server; we operate no servers).
- **No analytics SDK, no ad SDK.** The only "telemetry" is first-party
  MetricKit crash/diagnostic delivery (see `MFCrashReporter`), which iOS
  handles itself and reports through App Store Connect. Nothing is sent to
  any third party by the app.
- **HealthKit data never leaves the device.** Weight and steps are read from
  Apple Health into the local store; manual weigh-ins are written back to
  Apple Health. The app never transmits HealthKit data anywhere.
- **Network use is minimal and anonymous:**
  - Open Food Facts barcode/search lookups send only the query string or
    barcode to a public food database (no identity, no account).
  - The AI photo-logging backend is a clearly-marked local stub
    (`StubPhotoLoggingService`); no meal photos are uploaded anywhere.
  - Voice transcription uses on-device `SFSpeechRecognizer` where the OS
    supports it.

## App Store privacy labels

**Data Not Collected.** Rationale per Apple's definitions: the developer
(the user distributing this app) does not collect, sell, or share any data
linked to the user. Health and fitness data (weight, nutrition) is used
solely on-device for the app's core functionality and is never transmitted
off the device by the app. Anonymous public-database food lookups do not
constitute collection of user data.

## Privacy manifest

`app/Resources/PrivacyInfo.xcprivacy` (add to the Xcode app target):

- `NSPrivacyTracking` = false.
- Required-reason APIs: `NSPrivacyAccessedAPICategoryUserDefaults`
  (reason `CA92.1`) — the app persists settings, sync anchors, and flags in
  UserDefaults. No other required-reason APIs are used (no file-timestamp,
  boot-time, or disk-space API usage anywhere in the codebase).
- `NSPrivacyCollectedDataTypes` = empty.

## Review notes (for the App Store review / TestFlight notes)

- HealthKit usage descriptions explain exactly what is read and written
  (see `Info.plist`); the authorized read set is weight + steps + height +
  body composition only — nutrition read types were deliberately removed
  (2026-09-28) because the app never used them.
- Local notifications are reminders the user configures; no push, no
  notification content leaves the device.
- Camera/microphone/speech/photo-library usage is scoped to the capture
  flows (barcode, label OCR, photo/voice logging, cookbook import); each has
  a purpose string and a graceful denied-permission state.
