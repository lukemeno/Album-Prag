# Isolated UI QA fixtures

Run `python3 QA/prepare-fixtures.py --app-container "$SIM_APP_CONTAINER" --store slot-full-plan --pdf` with the simulator application Data container. It writes only `Library/Application Support/AlbumUITests/slot-full-plan/album.json` and `Documents/QA/qa-valid-booking.pdf`; production `Application Support/Album` is never touched.

The encoded fixture has six franked places, two nearby cluster pins, non-default `trip.updatedAt`, two flights, hotel details, and no collaboration or collection data. Use `ALBUM_PLAN_STORE=slot-full-plan` for the plan/map tests, `ALBUM_JOURNEY_STORE=slot-full-plan` for `FullJourneyUITests`, `ALBUM_MY_NAME=Luke`, `ALBUM_TODAY=2026-10-06`, and a caller-owned `ALBUM_SHOT_DIR` for UI runs. `ALBUM_DEMO_MEMORIES=1` is additionally required for the populated memories journey. `--pdf` writes a deterministic synthetic PDF containing parser smoke text; it is not an authentic booking confirmation and must not be supplied to `ALBUM_SAMPLE_PDF` or described as a real booking. The `testRealBookingPDFIfAvailable` gate remains open until a caller provides an actual local booking PDF; without one the test must stay skipped.

The scheme is `Album QA` and its default test plan is `Album-QA-Full.xctestplan`; use `xcodebuild -showTestPlans` to verify that plan association before running it. Its target identifiers are `C945C44FF2A6FF074EB5CE7A` (`AlbumTests`) and `CDBAE63A375341030F4CAAB0` (`AlbumUITests`), read from the current project file. Test targets are declared at plan level, not per configuration, so focused CLI runs must use `-only-testing:AlbumUITests/<TestClass>` (and optionally `-only-testing:AlbumUITests/<TestClass>/<testMethod>`). The plan does not activate Large Type or Reduce Motion; enable those simulator settings externally before claiming either accessibility variant. Automatic capture uses the Xcode 26 schema keys `preferredScreenCaptureFormat: screenRecording` and `uiTestingScreenshotsLifetime: keepAlways` (plus `userAttachmentLifetime: keepAlways`).

Verified locally: UUID-shaped configuration IDs, JSON parsing, target IDs, fixture JSON decoding shape, and synthetic PDF header/output. Pending until the parent attaches the plan to the shared scheme and runs Xcode's parser: whether `$(SRCROOT)` expands as the host path for `ALBUM_SHOT_DIR` in this exact runner, and whether the installed Xcode accepts every plan option. No claim is made that recordings were exported before the plan is executed.

Verify the plan association:

```sh
xcodebuild -project Album.xcodeproj -scheme 'Album QA' -showTestPlans
```

Parent integration command:

```sh
xcodebuild test -project Album.xcodeproj -scheme 'Album QA' \
  -testPlan Album-QA-Full \
  -destination 'platform=iOS Simulator,name=<installed device>' \
  -resultBundlePath "$PWD/.qa-results/Album-QA-Full.xcresult"
```

The plan intentionally does not claim that video files were exported; confirm recordings in the resulting `.xcresult` and retain any `.mp4`/`.mov` according to the runner output.
