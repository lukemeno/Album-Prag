# Expo migration status

## Completion predicate

The Expo Go app opens on both iPhones without an Apple Developer Program membership. Each person keeps a separate Supabase identity. The app preserves the trip, ideas and votes, itinerary, collections, photos and documents; local changes survive offline restarts and sync without data loss. A repeatable local-data export/import and a verified two-device run exist before the Swift app is retired.

## Scope and order

This is a cross-language migration, not a wrapper around SwiftUI. The existing iOS app stays intact as the fallback while the Expo project is built in `expo/`.

1. Confirm current Expo Go distribution constraints and SDK/package compatibility.
2. Define the TypeScript data contract and build the Expo Router, visual tokens and screen shell.
3. Port the seeded Prague ideas, local storage, votes and the idea inbox.
4. Add migration export/import and test idempotence against a copied album.
5. Port Supabase sessions, create/join, files, queued writes and realtime.
6. Port the map and place lookup, then the itinerary, collections and memories.
7. Port documents and the travel assistant.
8. Verify Expo Go on both devices, offline behavior and the no-fee use path before calling the move complete.

Each item ends with a focused typecheck/build or live run before the next starts. Items 1–4 have a working first slice; items 5–8 remain open.

## Decisions and blockers

- Keep the native project, Supabase schema and existing backend functions while the new client is developed.
- Keep secrets out of Expo public environment variables. Only the Supabase project URL and publishable/anon key may be included in a client.
- Do not copy simulator data as if it were the real trip. A real-device export is required for data migration.
- Two-device verification still needs both physical iPhones and confirmation of which Expo Go distribution path works for the installed versions.
- The connected physical iPhone has the native Album app and its private `album.json` was readable after device unlock: 80 places, 20 collection entries and one travel document. The actual PDF/photo assets still need a supported user-facing transfer into Expo.
- Expo Go is not installed on the connected iPhone yet. A native iOS bundle exports, but opening it on a physical device requires Expo Go or a signed development build.
- The Expo client now contains anonymous Supabase sessions, invite/create/join flow and place synchronization code; the live two-account path is not yet verified against the service.
- The old Swift app now has a share action for its `album.json` backup. Expo imports/exports places, collection records and extracted document text; JSON import/export has not yet been exercised on-device.
- Photo binaries are not yet uploaded/shared between devices; in-app photo-library import, TikTok oEmbed previews and the native iOS share extension are not yet ported. Trip/hotel editing, itinerary memories, automatic day-plan generation and the travel assistant are also open.
- `npm audit --omit=dev` reports 20 high and 12 moderate advisories in the current SDK 57 dependency tree. The suggested automatic repair downgrades Expo to SDK 44 or otherwise breaks the SDK-aligned package set, so no blind dependency rewrite was applied.

## Progress

- Read the migration plan from the preceding task and current project instructions.
- Existing source work is extensive and uncommitted; preserve it. Create the Expo client in its own `expo/` directory.
- Expo Router/SDK 57 shell with SQLite is under `expo/prague-album`; all 78 bundled seed IDs exactly match the native Prague seed.
- Ideen screen supports search, vote, offline SQLite and adding a place. Confirmed places can be assigned to October 4–9; the map draws the selected day's ordered stops and opens a walking route in Google Maps. This is manual day assignment, not the native automatic itinerary generator. Reise screen supports member names, invitation create/join, manual sync and local JSON export/import. Sammlung supports posts, links, comments and reactions.
- Database schema v2 retains collection records and document extraction metadata. Collection and travel-document files are not yet synced.
- Supabase configuration uses only the existing URL and public publishable key in ignored `.env.local`; auth sessions are stored in iOS SecureStore. No service-role or OpenAI key is included in the client.
- `xcrun devicectl` copied only the connected phone's `album.json` to `/tmp/prague-album-iphone-backup.json`; it contains 80 places, 20 collection records, and one extracted travel document. No private trip payload was placed in tracked source.
- At 2026-10-03 17:35 UTC, `npm run check:prague-seeds` (78 IDs), `npx tsc --noEmit`, and `npx expo lint` pass. Earlier iOS `expo export` and `npx expo-doctor` passed before the recent itinerary UI changes; the dependency audit advisories remain open.
- Metro is running at `http://localhost:8081`. The connected physical phone has only the Swift Album app; Expo Go is not installed, and Codex could not access the locked Mac UI to install/open it. Thus no native screen, Supabase two-account flow, or two-device behavior has been verified yet.
- Next: port TikTok link metadata/image handling, shared photo/PDF upload, automatic day planning and the travel assistant; then verify Expo Go, import and collaboration on both physical iPhones before retiring Swift.
