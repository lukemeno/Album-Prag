# Expo functional migration checklist

Completion means working behavior with evidence, including offline persistence and two separate identities. A successful typecheck only confirms compilation; it does not establish functional parity. Keep the Swift app until the final device checks pass.

| Capability / native source | Expo implementation | Acceptance before completion |
| --- | --- | --- |
| Prague seed / Models.swift | 78 IDs match; SQLite seed present | All seeds retained; repeat launch/import creates no duplicates |
| Visual structure / AlbumRoot.swift, ReiseView.swift, InboxView.swift | Expo navigation reduced to Swift's three tabs; Ideen/Sammlung segmented control; Reise now has matching daily overview and global assistant pill | Side-by-side iPhone review still required. Match Swift stamp stack, tab capsule, toolbar, papers, spacing, and map drawer screen by screen. |
| Idea search, filters, votes / InboxView.swift | Timestamped votes and withdrawals implemented; local/live backend checks passed | Each person can approve, defer, reopen and undo; changed votes do not reappear after sync |
| Edit, delete, restore ideas / PlaceEditor.swift | Editor and archive implemented; SQLite regression passed | Fields, category, source and place identity survive restart and sync; deletion persists |
| Location search / PlaceEditor.swift | Batch geocoding exists | User can choose a location, reject a wrong match and see the same coordinates on partner device |
| Link metadata / OEmbedService in PlaceEditor.swift | Implemented; mocked full/short TikTok and HTML regression passed | TikTok full/short URLs, generic links, caption, author and preview; blocked metadata preserves original link and manual edit |
| Own photos / PlaceImageStorage.swift | Simulator photo/save/restart and live private two-identity transfer passed; UI partner flow pending | JPEG conversion, durable local copy, limit, private upload, partner download and offline reopen |
| Place photos / PlaceImageService.swift | Client candidates, credits, gallery and guards implemented; full UI check pending | Candidates, credits, explicit choice, gallery, stale result guard after moving the place |
| Look Around / PlaceImageResolver | Native API absent in Expo Go | Define and exercise a usable alternative; do not claim identical native Look Around parity |
| Map / TripMapView.swift | Integrated; local checks/iOS export and simulator map tiles passed | Filtering, selection, nearby pins, camera fit and foreground location work with real map tiles |
| Route/day assignment / PlacesDrawer.swift | Reorder/remove/reassign and individual route stages integrated; synthetic simulator day move passed | Reorder, remove, choose day, and route ordered stops on real device |
| Automatic itinerary / DayPlanGenerator.swift | Integrated; algorithm/SQLite regression passed; UI completion pending | Match grouping, shortest round, meal separation, opening days, flight windows and leftover behavior |
| Visit/remember / TripMemoriesView.swift | `/memories` chronological visited-place screen with photo/detail link; existing place sync carries visited state | Re-run UI and physical partner sync; real journey evidence |
| Trip/hotel/flights editing / TripDocumentsView.swift | Manual editor and stale-snapshot protection integrated | Verify all native flight/hotel fields, restart and two-device update |
| PDF import/view/share / TripDocumentsView.swift | PDF.js offline reader, sharing, durable local original and private CAS sync integrated; Expo Go synthetic two-page render/text extraction passed | Physical-device picker/share/offline restart and partner-sync acceptance |
| Booking extraction / TripDocumentParser.swift | Local PDF.js extraction and review-before-apply integrated; two-page synthetic simulator extraction passed | Real booking PDF edge cases/password/scan on device |
| Collection post/comment/heart / CollectionViews.swift | Local normalized store; canonical URL IDs, comments, stable participant hearts/Unlike, post tombstones; trip CAS sync. `check-collection.mjs` passes | Live two identity, stale mutation, comment tombstone, deletion and unlike |
| Collection place links and detection / CollectionPlaceSuggestions.swift | Explicit manual place link/unlink UI and store tombstones integrated; link metadata uses existing bounded preview service. Caption-to-place detection remains out of scope | Manually link/unlink several places and open idea; ensure metadata never creates or renames a Place |
| Native TikTok share intake / ShareExtension | Not available as a custom extension in Expo Go | Provide and verify paste/photo/deep-link intake; exact extension behavior requires a custom build |
| Assistant chat / AssistantService.swift | Chat implemented; live Expo Go send/answer/restart passed | Real send, history, sources, timeout, cancel, retry, web search and permission denial |
| Assistant suggestions / AssistantView.swift | Explicit save/reuse implemented; live duplicate detected | Explicit save/reuse, deduplication, source preservation and editable place suggestion |
| Assistant preferences / AssistantSession.swift | Implemented; full UI check pending | Remember/remove, local per-album storage and reload |
| Assistant plans / AssistantActions.swift | Implemented; SQLite regression checks passed | Confirmed atomic apply, stale response rejection, duplicates/invalid day rejection, conflict-safe undo |
| Create/join/session / SupabaseSync.swift | First slice present | Two separate accounts create/join same trip; invitation parsing, restart session and membership errors |
| Sync/realtime/offline / SupabaseSync.swift | First slice; UI refresh fix in progress | Places/trip/collections/files converge, retries preserve queued changes, airplane-mode restart and reconnection |
| Migration backup / album.json | Actual 80/20/1 phone JSON verified in isolated SQLite; binaries pending | Actual phone data plus binaries transfer; IDs retained; repeated import does not overwrite newer edits |
| Final distribution | Expo Go server path available | Both physical iPhones can open, reconnect and use required behavior with separate Apple IDs and no paid Apple membership |

## Latest evidence

- 2026-10-03: 78 seed IDs, TypeScript and Expo lint passed before this step.
- 2026-10-03: authenticated live assistant-chat returned HTTP 200 for a synthetic Prague question, with a valid answer and usage object. No private trip/document content was sent in this verification.
- Physical two-phone runs and real photo/PDF/share flows remain required.

- 2026-10-03: ExpoGo simulator sent a synthetic walking question, displayed backend answer and suggestion; complete app restart retained history. Saving Kampa recognized the existing idea. iOS export, TypeScript and lint passed. Older backup import preserves newer collection/document/trip changes (SQLite regression).

- 2026-10-03: two separate synthetic anonymous identities created/joined one verification trip, read/wrote each other’s vote events; withdrawal survived stale partner merge. Physical UI/offline collaboration still open.

- 2026-10-03: Live public TikTok oEmbed successful; real private phone JSON imported repeatedly without duplicates and with deletion tombstones preserved. Automatic itinerary SQLite/algorithm regression passed. Live Overpass opening-hours fetch currently fails (406/alternative timeout); does not assert invented hours.

- 2026-10-03: integrated documents/trip editor, local licensed PDF.js fonts; ExpoGo simulator rendered original and extracted text from both synthetic PDF pages. Document/Map/Media/Assistant/Itinerary regressions, TypeScript, lint, iOS export pass. Physical devices remain open.

- 2026-10-03: local collection UI/store supports manual place links/unlinks and bounded link previews; `/memories` lists visited places and photos. Collection trip-sync uses server-version CAS and preserves dirty tokens. Production-store `check-collection.mjs`, TypeScript/lint, Documents/Map/Media/Assistant/Itinerary scripts and Expo Doctor 21/21 pass; iOS export passes. Physical two-phone UI/sync remains open.

- 2026-10-03: visual parity pass started per user's one-to-one Swift design requirement. Three-tab structure, floating pill navigation, system-symbol icons, global assistant, Ideen/Sammlung segment, trip day strip, day agenda and travel-ticket rows added. TypeScript passes. Simulator comparison remains blocked by outdated installed Expo Go (`ExpoAsset` missing) and a native build that failed for insufficient free disk space.
