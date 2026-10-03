# Expo migration status

## Aktueller Arbeitsstand 03.10.2026

Assistent, Medien/Editor, automatische Tagesplanung, Karten, Unterlagen und Reiseeditor sind im primären Expo-Projekt integriert. Nutzer hat die visuelle Anforderung konkretisiert: Expo soll dem bestehenden Swift-Album Bildschirm für Bildschirm entsprechen. Aktuell umgesetzt: drei Tabs wie in Swift, schwebende Tab-Kapsel, globale Assistenz-Schaltfläche, Ideen/Sammlung-Segment und eine neue Reiseübersicht mit Tagesstreifen, Tagesplan, Tickets und Ideenhinweis. TypeScript besteht nach diesem UI-Slice. Expo-Go im vorhandenen Simulator ist SDK-inkompatibel (`ExpoAsset` fehlt); der lokale iOS-Simulator-Build scheitert derzeit am vollen Datenträger. Deshalb steht der visuelle Simulatorabgleich noch aus. UI-Parität auf Ideen/Karte/Assistent und der Geräteabgleich sind noch offen. Datenmigration und beide physischen iPhones bleiben ebenfalls offen. Historische Abschnitte unten nicht als aktuellen Fertigstand lesen.

## Accountwechsel-Checkpoint 03.10.2026

Accountwechsel abgeschlossen; Arbeit auf Nutzerwunsch fortgesetzt. Aktueller verbindlicher Übergabestand: ACCOUNT-HANDOFF.md; vollständige offene Funktionsliste: EXPO-FUNCTION-PARITY.md. Assistent inzwischen integriert, BackendHTTP200 und SQLite-Aktionsprüfungen erfolgreich; letzte Composer-Reparatur TypeScript erfolgreich, UI-Senden, Antwort, Verlauf nach vollständigem ExpoGo-Neustart und Vorschlags-Deduplizierung erfolgreich geprüft. TypeScript, Lint und iOS-Export erfolgreich. Medien-Zwischenstand dauerhaft unter expo/paused-media-20261003 gesichert; Luna setzt den Editor/Fotos/TikTok-Slice in isolierter Kopie fort. Ältere Abschnitte unten beschreiben den vorausgehenden Stand.

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

- Fortsetzung 03.10.: Import-Rückwärtsüberschreiben für Sammlung, Unterlagen und Trip korrigiert; SQLite-Regression mit älterem Backup und neueren lokalen Änderungen bestanden.

## Fortsetzung: Abstimmungen und Import

- `vote-events.ts`/`vote-store.ts`: zeitgestempelte Entscheidung pro Namen einschließlich „offen“; explizite Rücknahmen schlagen alte Array-Einträge. Lokale DB-Speicherung atomar, Sync führt Entscheidungen zusammen, JSON-Export/-Import erhält Events. Bestehende native Array-Felder bleiben lesbar. Gleichzeitige Nutzung unveränderter Swift-Clients ist damit noch nicht geprüft.
- SQLite-Prüfung: zwei Stimmen, Rücknahme einer Stimme, Wechsel der anderen auf später; Zusammenführung in beiden Richtungen und gleiche Zeitstempel; neuere Tombstones behalten.
- Live Backend mit zwei eigenen anonymen Identitäten und einer synthetischen Verifikationsreise: Erstellen, Einladung beitreten, Lesen/Schreiben beider Personen, getrennte Stimmen, Rücknahme und erneuter Merge mit veraltetem Partnerzustand bestanden. Das ist kein physischer Zwei-iPhone-Nachweis.
- Lokaler Prüfskript `/tmp/album-two-client-check.mjs`, private Wiederverwendungs-Sessions in Documents/Codex/2026-10-03/gr/Prag-Fortsetzung/private/two-client-verification.json. Keine Tokens im Prüfoutput oder Projektcode.

## Fortsetzung: Medien in Expo integriert

- Vollständiger Editor-Slice jetzt im primären Expo-Projekt: Fotoauswahl und JPEG-Konvertierung, private Uploads, Partner-Download mit lokalem Cache, Link-/TikTok-Vorschau, Bildquellen/Kandidaten/Galerie, Archiv/Wiederherstellen. Datenbank v3 enthält local_media.
- Expo-Go-Simulator: eigenes synthetisches 800×1200 Prüffoto ausgewählt, Idee gespeichert, vollständiger App-Neustart; Titel und Foto erneut sichtbar. Direkt geöffnete Editorroute erhält nach Speichern einen Rückweg zu den Ideen.
- Live Backend: synthetisches JPEG aus dem Simulator von Identität A privat hochgeladen, Identität B signierte es und lud byte-identische Daten; öffentlicher Bucketzugriff abgelehnt. Das ersetzt keine Zwei-iPhone-UI-Prüfung. Prüfsystem /tmp/album-photo-backend-check.mjs nutzt vorhandene private Verifikations-Sessions.
- TypeScript, Lint, SQLite-/Link-Medienregression bestanden. iOS-Export nach Medienintegration erfolgreich unter /tmp/prague-expo-media-export-20261003; abschließende kleine UI-Anpassungen erneut typgeprüft.
- Nächster Slice in Arbeit: automatische Tagesplanung, Öffnungszeiten, explizite Vorschau/Commit/Rücknahme. Luna arbeitet isoliert in /tmp/prague-expo-itinerary-20261003; erst nach Parent-Review integrieren.
- PDF-Originale, Reiseeditor, vollständige Sammlung/Erinnerungen und physischer Zwei-iPhone-Abschluss weiterhin offen.

## Fortsetzung: Tagesplan und echte Importregression

- Automatische Tagesplanung im Hauptprojekt integriert und auf Reise/Karte verlinkbar: sechs Tage, Flugfenster, Stunden-/Kapazitäts-/Routenregeln, Restliste, expliziter atomarer Commit und geschützte Rücknahme. Reproduzierbarer scripts/check-itinerary.mjs besteht; Tagesplan-Seite in ExpoGo sichtbar. Komplette UI-Anwendung/Rücknahme noch prüfen.
- Öffnungszeiten-Service implementiert, manuell abrufbar und abbrechbar. Liveprüfung derzeit fehlgeschlagen: overpass-api.de HTTP406, offiziell gelistete private.coffee/kumi Alternativen Timeout. Keine falschen Stunden gespeichert; unbekannte Werte bleiben als unbekannt markiert. Manuelles Stundenfeld wird im Karten-Slice ergänzt. Externen Abruf vor vollständiger Parität erneut prüfen.
- TikTok echter Abruf erfolgreich mit öffentlichem Video aus offizieller Dokumentation: Titel, Autor, Thumbnail und CanonicalURL. Full-/Short-Redirect-Regression bleibt reproduzierbar in check-media.
- Realer privater iPhone-JSON-Export in isolierter SQLite importiert: 80 Orts-IDs samt Bildreferenzen/Besucht/Tag, 20 Sammlungseinträge einschließlich gelöschter Tombstones, 1 Dokument-Metadatensatz, Reisehotel erhalten; wiederholter Import ohne Duplikate. Keine privaten Dateien dafür hochgeladen.
- Behobene Importfehler: unberührte Seeds dürfen alte native Date-Referenzwerte übernehmen; reine Seed-Korrekturen markieren keine Benutzeränderung mit Date.now. Collection-Export enthält Tombstones, sonst könnten gelöschte Beiträge nach Transfer wieder auftauchen. Dauerhafte Regression in check-assistant ergänzt.
- Karte/Reihenfolge/Positionswahl/GPS/Etappen integriert; check-map, ExpoGo-Simulator-Kartenkacheln und synthetische UI-Tagesverschiebung geprüft.
- Nächster vollständiger Feature-Slice: Original-PDF/Unterlagen/Reiseeditor gemäß EXPO-DOCUMENTS-NEXT-PLAN.md.

- Letzte Parent-Reparatur: Öffnungszeitenantworten prüfen neben tripID auch albumID und weiterhin bestätigten/aktiven Ort; paralleles Archivieren/Abwählen wird nicht überschrieben. TypeScript, Itinerary-Regression und Lint erfolgreich.

## Letzter Checkpoint: Karte integriert

- Owned-Dateien aus /tmp/prague-expo-map-20261003 gezielt übernommen; primäre Seed-/Import-/Sync-Reparaturen erhalten. Karte: Filter, Stoppreihenfolge/Tageswechsel, besucht, Einzel-Etappen, explizite Positionswahl, GPS-Näheliste, sichtbarer Hinweis auf fehlende Koordinaten.
- Parent: keine doppelte Selected-Zeile beim normalisierenden Tageswechsel; parallele Stunden bleiben erhalten, Ortswechsel entfernt alte Stunden. Eigene Foto-Uploads prüfen tripID/albumID vor und nach Await.
- check-map/check-media/check-assistant/check-itinerary, TypeScript und Lint erfolgreich; iOS-Export /tmp/prague-expo-map-export-20261003. Vollständige Geräte- und GPS/Routen-UI-Abnahme offen.
- Nur synthetische Simulator-Idee „Expo Prüffoto“ erhielt Testkoordinaten/Tag; UI verschob Tag4 nach Tag5 mit Ordnung0 und Abstimmung erhalten. Privates Reisebackup unverändert.
- Luna arbeitet weiter isoliert in /tmp/prague-expo-documents-20261003 (eigene Dependencies) an freigegebenem EXPO-DOCUMENTS-NEXT-PLAN.md. Probe/PDF-Reiseeditor-Integration noch offen. Sync-Patch muss frische Primary-Änderungen erhalten; globale running-Promise/Trip-CAS/Scope-Schutz sind explizit als Aufgaben übergeben.

## Unterlagen und Reiseeditor integriert

- PDF-Import prüft Signatur/25-MB-Limit, speichert Original unter lokaler UUID, PDF.js inkl. lizenzierter Standardfonts gebündelt. Im Expo-Go-Simulator (Album Codex) synthetische Zweitseiten-PDF offline geöffnet und sichtbar gerendert; lokale Texterkennung hat beide Testseiten ausgelesen. Das Original in der App geteilt/Neustart und physische iPhones sind noch gesondert abzunehmen.
- Parser zeigt erkennbare Flug-/Hotel-/Buchungsdaten vor manueller Übernahme; Reiseeditor speichert native TripInfo mit Apple-Referenzzeit, atomarem Scope/Version-CAS. Unterlagensync nutzt private trip-files mit Größen-/Signatur-/Pfadprüfung, Stagingdatei, CAS und Realtime/Supabase-Hook. Keine Nutzerdokumente in Testfixture/Repository übernommen.
- Dokumente/Reiseeditor samt WebView/PDF.js Dependencies gezielt in Primary integriert. check-documents, map, media, assistant, itinerary, TypeScript, Lint und iOS-Export `/tmp/prague-expo-final-export-20261003` bestanden. iOS-Bundle exportiert, ersetzt keinen Expo-Go- oder Zwei-Geräte-Livecheck.
- Offene Parität: Sammlung derzeit einfacher als native SAM-1…5 (Kanonisierung/Details/Löschungen/Ortsverknüpfung/Migration/CAS), Erinnerungen/Chronik; zwei physische iPhones/Offline-Realtime und restliche Systemflows. Über Overpass HTTP406 wird kein Öffnungszeiten-Erfolg behauptet.

## Fortsetzung: Sammlung und Erinnerungen · 03.10.2026

- Expo-Sammlung nutzt jetzt den normalisierten Collection-Store: lokale Posts/Links, idempotente kanonische Link-IDs, stabile Installations-UUID, Kommentare, Heart/Unlike, Delete-Tombstones, Link-Vorschau und manuelle Ortsverknüpfung/-lösung.
- Trip-Sync der Sammlung nutzt Insert oder Update mit erwarteter Serverversion; dirty Mutation-Tokens bleiben bei paralleler lokaler Änderung erhalten. Konflikte bleiben dirty und werden beim nächsten Pull erneut aufgelöst.
- Neue `/memories`-Ansicht listet besuchte Orte nach Tag/Reihenfolge mit gespeichertem Titel, Notiz und Foto; von der Reiseübersicht erreichbar. Besuchsstatus kommt aus den synchronisierten Places.
- TypeScript, Expo-Lint, Documents/Map/Media/Assistant/Itinerary-Regressionen und Expo Doctor (21/21) bestanden.
- `scripts/check-collection.mjs` prüft den echten Store: kanonische Link-IDs, Offline-Post/Kommentar, getrennte stabile Herzen, Unlike-/Ortslink-/Post-Tombstones. Expo-Go-Erneutlauf und physische Zwei-iPhone-Abnahme bleiben offen; automatische Ortsdetektion ist ausdrücklich nicht umgesetzt, SAM-4 Share Extension ist in Expo Go technisch nicht enthalten.
- iOS Expo-Export nach dieser Integration besteht unter `/tmp/prague-expo-collection-export-20261003` (8,7 MB Bundle). Der Export bestätigt Bündelung, nicht Gerätefunktion.
- Expo-Go 57 Simulator `Album Codex`: Reiseübersicht und Sammlungs-Tab gerendert; `/memories`-Route per Deep Link geöffnet, Empty State sichtbar. Interaktion mit echten Eingaben noch nicht simuliert. Verbundenes physisches „iPhone von Luke (2)“ wird von `devicectl` aktuell als unavailable gemeldet.
- Designkorrektur nach Nutzerfeedback: die lizenzierten Fraunces-SemiBold- und Instrument-Serif-Schriften aus dem Swift-Projekt werden jetzt in Expo gebündelt und geladen. Home-Karten/Typografie verkleinert, redundante „Reise“-Kopfleiste ausgeblendet. Expo-Go-Zahnradsymbol ist dessen Entwickleroverlay, kein Bestandteil der ausgelieferten App.
- Nach der Designkorrektur erneut `npx tsc --noEmit`, `npx expo lint` und iOS-Export bestanden; Bundler enthält jetzt beide lokal lizenzierten Schriften. Sichtprüfung in `Album Codex` zeigt die Reiseübersicht mit den vorgesehenen Fraunces-Überschriften.
