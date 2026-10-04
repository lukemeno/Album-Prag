# Album release completion

## Goal

Private native iOS use on two iPhones with the existing Supabase backend, installed from Xcode with the Personal Team. No App Store or TestFlight release.

## Progress

- Added a `Weggelegt` inbox section with individual restore, edit/open, and restore-all actions.
- Added a regression test proving an individual restore leaves other rejected ideas archived.
- Focused iOS simulator test passed: `testRestoreOneDeferredIdeaLeavesOtherIdeasInArchive`.
- Removed the fixed signing team and made the core `Album` target independent of the App Group and embedded share extension. Clipboard → `+` remains the documented link workflow; `xcodegen` and the simulator app build pass.
- Added an end-to-end UI test for rejecting an idea, seeing it under `Weggelegt`, and restoring it; the QA-plan run passes after waiting for the decision animation to commit.
- Reworked the photo fallback UI fixture to use a unique store and one location with a deliberately unreachable source; the targeted QA test passes. The earlier shared-store run had actually displayed the live Speculum source photo, so it was checking stale data.
- Focused final-project QA run passes the archive store regression and skips the native-share test as expected for Personal Team.
- Simulator build and unsigned generic iOS-device build both complete; the device build reports existing Swift concurrency warnings in `AssistantService.swift` and `SupabaseSync.swift`.
- Full default scheme run on iPhone 17 Pro simulator (before the two fixture-test corrections): 177 passed, 13 failed, 16 skipped. Failures included opt-in iOS accessibility audits, ambiguous UI-test selectors around duplicate “Bearbeiten” buttons, native share-extension expectations, and stale demo fixtures. The archive and corrected thumbnail-fallback tests now pass in the QA plan; the complete QA plan remains unverified.
- Physical iPhone remains unavailable to Xcode, so device installation and two-device Supabase/offline checks are still outstanding.
- Existing user edits in `Album/AlbumApp.swift`, `AlbumTests/StoreRegressionTests.swift`, `AlbumUITests/*`, and `QA/recheck-screenshots/` must be preserved.

## Issue drafts

Linear is connected, but no matching Album project exists in the available workspace; these remain local drafts and were not created remotely.

### 1. Align signing with the private Personal-Team install path — implemented

**Scope:** Resolve the conflict between PRODUCT/README (no App Group or Share Extension entitlement) and `project.yml` (embeds `AlbumShare` with an App Group).

**Acceptance:** Core `Album` target no longer embeds the extension or requires an App Group; link intake through `+` and clipboard remains intact; existing bundle identity is preserved; XcodeGen and simulator build succeed. Physical signing/install remains unverified until a device is available.

**Decision gate:** Preserve the native share extension only if the user confirms a paid signing team is available and wants it in the default install.

### 2. Finish and reconcile existing regression fixes

**Scope:** Preserve current image-cancellation, late-result, and editor-cancel changes while finishing the inbox archive.

**Acceptance:** Rejected ideas can be inspected/restored individually; cancelled image searches do not replace newer data; editor cancel writes nothing; state survives relaunch.

### 3. Re-run release regression coverage

**Scope:** Validate the final working tree across unit and UI flows after the implementation is complete.

**Acceptance:** Core journey, map/drawer/rotation, ideas/undo/archive, day planning, documents, collection, assistant, offline persistence, and accessibility checks pass; `git diff --check` is clean.

### 4. Complete two-device/offline acceptance

**Scope:** Use the existing Supabase backend with two distinct iPhones and accounts.

**Acceptance:** Invitation, bidirectional ideas/votes/plan changes, offline edits across restart, reconnection, photos, and a PDF converge and remain usable offline.

**External needs:** Both phones, signing/trust on device, and the real `Prag Urlaub.pdf` fixture.

### 5. Install and hand off

**Scope:** Install the signed build on both devices and document renewal/setup.

**Acceptance:** Both copies launch with their data intact, join the same trip, and the README matches the release setup and remaining network dependencies.

## Next steps

1. Finish the archive UI regression and correct concrete UI-test/product defects.
2. Run targeted fixture-backed QA tests, unit regressions, and final build.
3. Complete Personal-Team signing and device-only checks when the iPhone is available; then verify two-device sync using the source PDF and both iPhones.
