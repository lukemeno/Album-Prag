# Expo functional migration checklist

Completion means working behavior with evidence, including offline persistence and two separate identities. A successful typecheck only confirms compilation; it does not establish functional parity. Keep the Swift app until the final device checks pass.

| Capability / native source | Expo implementation | Acceptance before completion |
| --- | --- | --- |
| Prague seed / Models.swift | 78 IDs match; SQLite seed present | All seeds retained; repeat launch/import creates no duplicates |
| Idea search, filters, votes / InboxView.swift | Implemented first slice | Each person can approve, defer, reopen and undo; changed votes do not reappear after sync |
| Edit, delete, restore ideas / PlaceEditor.swift | Pending | Fields, category, source and place identity survive restart and sync; deletion persists |
| Location search / PlaceEditor.swift | Batch geocoding exists | User can choose a location, reject a wrong match and see the same coordinates on partner device |
| Link metadata / OEmbedService in PlaceEditor.swift | Pending | TikTok full/short URLs, generic links, caption, author and preview; blocked metadata preserves original link and manual edit |
| Own photos / PlaceImageStorage.swift | Pending | JPEG conversion, durable local copy, limit, private upload, partner download and offline reopen |
| Place photos / PlaceImageService.swift | Existing backend reusable; client pending | Candidates, credits, explicit choice, gallery, stale result guard after moving the place |
| Look Around / PlaceImageResolver | Native API absent in Expo Go | Define and exercise a usable alternative; do not claim identical native Look Around parity |
| Map / TripMapView.swift | Markers and selected-day lines present | Filtering, selection, nearby pins, camera fit and foreground location work with real map tiles |
| Route/day assignment / PlacesDrawer.swift | Manual assignment and external walking directions present | Reorder, remove, choose day, and route ordered stops on real device |
| Automatic itinerary / DayPlanGenerator.swift | Pending | Match grouping, shortest round, meal separation, opening days, flight windows and leftover behavior |
| Visit/remember / TripMemoriesView.swift | Pending | Visit toggle and chronological photo memories persist and sync |
| Trip/hotel/flights editing / TripDocumentsView.swift | Data retained; editor pending | Editable flight legs, travelers, booking/hotel fields and route; both devices receive updates |
| PDF import/view/share / TripDocumentsView.swift | JSON text metadata import only | Original PDF durable locally, private upload/download, offline view and sharing |
| Booking extraction / TripDocumentParser.swift | Pending | Extract text and present flights/hotel for explicit review before applying; preserve original PDF |
| Collection post/comment/heart / CollectionViews.swift | Basic write actions present | Partner updates display; own comment/post deletion and reaction removal persist |
| Collection place links and detection / CollectionPlaceSuggestions.swift | Pending | Detect candidate place names, review, link/unlink, open associated idea |
| Native TikTok share intake / ShareExtension | Not available as a custom extension in Expo Go | Provide and verify paste/photo/deep-link intake; exact extension behavior requires a custom build |
| Assistant chat / AssistantService.swift | Implementation in progress; live backend HTTP 200 | Real send, history, sources, timeout, cancel, retry, web search and permission denial |
| Assistant suggestions / AssistantView.swift | Pending | Explicit save/reuse, deduplication, source preservation and editable place suggestion |
| Assistant preferences / AssistantSession.swift | Pending | Remember/remove, local per-album storage and reload |
| Assistant plans / AssistantActions.swift | Pending | Confirmed atomic apply, stale response rejection, duplicates/invalid day rejection, conflict-safe undo |
| Create/join/session / SupabaseSync.swift | First slice present | Two separate accounts create/join same trip; invitation parsing, restart session and membership errors |
| Sync/realtime/offline / SupabaseSync.swift | First slice; UI refresh fix in progress | Places/trip/collections/files converge, retries preserve queued changes, airplane-mode restart and reconnection |
| Migration backup / album.json | JSON import/export present | Actual phone data plus binaries transfer; IDs retained; repeated import does not overwrite newer edits |
| Final distribution | Expo Go server path available | Both physical iPhones can open, reconnect and use required behavior with separate Apple IDs and no paid Apple membership |

## Latest evidence

- 2026-10-03: 78 seed IDs, TypeScript and Expo lint passed before this step.
- 2026-10-03: authenticated live assistant-chat returned HTTP 200 for a synthetic Prague question, with a valid answer and usage object. No private trip/document content was sent in this verification.
- Physical two-phone runs and real photo/PDF/share flows remain required.
