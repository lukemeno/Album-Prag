# Plan Paket 1 · Reisebibliothek (ML-01), nur Datenschicht

Stand 26.10.2026. Erstellt von Opus (nur lesend), geprüft vom Hauptchat. Basis: `main` @ `1ee00bd`. Kein Push, kein Backend, keine neuen Branches oder Worktrees. Produktplan: `PLAN-FERTIG-V1.md` §6. Alter Entwurf nur lesbar über `git show 0f02198:<pfad>`.

## Befund (Belege Datei:Zeile)

- `AlbumApp` erzeugt genau einen `AlbumStore` im `@State`-Initialisierer (`AlbumApp.swift:15-109`). Produktiv `AlbumStore()` mit Root `Application Support/Album/` (`AlbumStore.swift:166-168`). `ALBUM_TEST_STORE` → `Application Support/AlbumUITests/<safeName>/` (`AlbumApp.swift:17-24`); `existed` prüft vorher, ob `album.json` da ist.
- `AlbumStore.init` hat Seiteneffekte: liest `album.json` (`legacyAlbumID`, `:177-181`), setzt bei Ladefehler `loadFailed` (danach schreibt `persist()` nichts, `:191-196`, `:432-433`), ergänzt ohne Testumgebung fehlende `prague-*`-Beispielideen (`:261-283`), migriert Planungsdaten auf Schema 2 mit `album.legacy-planning-backup.json` (`:284`, `:299-320`), persistiert (`:287-290`), veröffentlicht den Share-Kontext (`:293`).
- Alle reisebezogenen Dateien liegen relativ zu `store.root`: `album.json`, PDFs, `images/`, `trip-memories/`, `sync-v2-<tripID>.json`, `discovery-<albumID>-<participant>.json`, `assistant-<albumID>-<participant>.json`. Eine Verzeichniskopie nimmt alles mit. Global bleiben nur `album.myName`/`album.participantID` (UserDefaults) und der `URLCache`.
- Sync: `scenePhase == .active` und `.task` rufen `sync()` und `refreshPlaceImages()` (nicht bei Unit-Test-Host/isoliertem Store). Realtime je Store (`AlbumStore.swift:1254-1279`). Ein Beitritt überschreibt `collaboration` des aktuellen Albums (`:1311-1322`).
- Sharing-Inbox: ein Kontext im App-Group-Container, Schlüssel `trip:<tripID>` sonst `local:<albumID>` (`AlbumStore.swift:384-388`); fremder `tripKey` → `trip-mismatch` (`:404-407`). Kopie und Original haben dieselbe `albumID`/`collaboration`, wartende Einträge passen nach der Migration weiter.
- **Prag-Vorgaben im Modell:** `AlbumData()` füllt `places = Place.examples` (`Models.swift:632`, auch beim Decodieren ohne `places`), `TripInfo.hotel` Standard „Hotel Urban Crème“ (`:494`), `hasPragueIdentity` erkennt Prag am Hotel (`AlbumStore.swift:353-360`). Eine mit `AlbumData()` angelegte neue Reise wäre „Prag“. **Die Fabrik schreibt deshalb eine leere `AlbumData` selbst.**
- Das Xcode-Projekt wird per XcodeGen aus `project.yml` erzeugt (`/opt/homebrew/bin/xcodegen`). Neue Dateien: `xcodegen generate`, danach `git diff` auf `pbxproj` prüfen, dass nur die neuen Dateien dazukommen.
- **Alter Entwurf `0f02198:Album/TripLibrary.swift`:** übertragbar sind Ideen (Index mit Version/Einträgen/lastOpenID, Ordner `Trips/<UUID>`, Migrationsbeleg mit stabiler ID, Kopie über `.staging`, Baumvergleich `contentsEqual`, atomares Schreiben, `unavailableReason`, Testfälle aus `TripLibraryTests`). **Nicht übernehmen:** Aufrufe, die auf `main` fehlen (`AlbumStore(... isDemo:managesShareContext:)`, `setLibraryActive`, `groupMembers`, `memberVotes`, `drainShareQueue(tripKey:)`, `ShareInbox.clearContext()` u. a.), `joinInvitation`/`makeDraftStore`/`synchronizePendingTrips` (gehören zu ML-03/04) und die Schwäche, für jede Reise beim Auflisten einen vollen `AlbumStore` zu bauen (Seiteneffekte) sowie dass ein defekter Index die ganze Bibliothek sperrt.

## Zielentwurf

**Verzeichnislayout (produktiv)**
```
Application Support/
  Album/                      Altbestand, nach Umschalten eingefroren, nie gelöscht
  AlbumLibrary/
    library.json              Index v1 (Cache + lastOpened)
    legacy-migration.json     Beleg {id, state, Zählwerte}
    library.corrupt-<ts>.json beiseitegelegter defekter Index
    Trips/<UUID>/…            je Reise das bisherige Store-Layout
    Trips/.staging-<UUID>/    nur während der Kopie
```
DEBUG mit `ALBUM_TEST_STORE=<n>`: Altbestand `AlbumUITests/<n>/`, Bibliothek `AlbumUITestLibraries/<n>/`.

**Typen** (neu in `Album/TripLibrary.swift`)
- `TripLibraryIndex: Codable { version = 1; entries; lastOpenedID: UUID? }`. Tolerant decodieren (`decodeIfPresent`). `version > 1` → nur lesen, nichts schreiben, Fehler zeigen.
- `TripLibraryEntry: Codable, Identifiable, Equatable`: `id: UUID` (= Verzeichnisname), `albumID: String`, `origin` (`.migrated/.starter/.blank`), `title`, `destination?`, `startDate?/endDate?: TripDay`, `remoteTripID: UUID?`, `travelers: [String]`, `createdAt`, `lastOpenedAt?`, `unavailableReason?`.
- `LegacyMigrationReceipt: Codable { id; state (.copying/.committed); sourceFiles; sourceBytes; places; documents; memories; albumID; committedAt? }`.

**ID-Regeln.** Verzeichnis-ID ist eine neue UUID, nie aus Nutzereingaben oder `albumID` abgeleitet. `albumID` bleibt bei der Migration unverändert (hängt an Discovery-/Assistent-Dateien und Share-Schlüssel). Die Beleg-ID wird bei Wiederholung weiterverwendet. Im Index keine absoluten Pfade.

**Wahrheit liegt in den Reiseordnern.** Der Index ist Cache plus „zuletzt geöffnet“. Fehlt er oder ist er defekt, wird er durch Scannen von `Trips/*/album.json` neu aufgebaut (nur `AlbumData` decodieren, **keinen** `AlbumStore` bauen).

**Fabrik.** `TripLibrary` instanziiert einen `AlbumStore` nur für die geöffnete Reise. `makeStore(id:origin:)` → `AlbumStore(root: tripRoot(id), shareInbox:, seedsPragueExamples: origin != .blank)`. `createBlankTrip(title:destination:) -> UUID?` schreibt zuerst eine leere `AlbumData` in `.staging-<id>` (`places = []`, `trip.hotel = ""`, `schemaVersion = 2`, `trip.planningSchemaVersion = 2`, neue `albumID`), dann Umbenennen, dann Index. `createStarterTrip()` (nur Neuinstallation) entspricht dem heutigen `AlbumStore()`.

**Schnittstelle für Paket 2** (`@MainActor @Observable`): `entries`, `activeID`, `activeStore`, `error`; `restoreLastOpenedTrip() -> Bool` (false = Übersicht zeigen); `open(_ id:) -> Bool` (alten Store persistieren, neuen öffnen, `publishShareContext()`, `lastOpenedID` schreiben); `showLibrary() -> Bool`; `createBlankTrip(...)`; `refreshActiveEntry()` (Titel/Ziel/Zeitraum aus dem Store in den Index; bei `open`, `showLibrary`, `scenePhase .background`). Paket 2 muss `AlbumExperienceRoot` mit `.id(library.activeID)` versehen, sonst bleiben `assistantSession`/Discovery der alten Reise im View-State (`AlbumExperienceRoot.swift:91`, `:132`). Titelbild: optional `coverImage: String?` in Paket 2.

**Zuletzt geöffnet.** `lastOpenedID` wird nur nach erfolgreichem `open` geschrieben. Kaltstart: gültig und verfügbar → öffnen; sonst erste verfügbare Reise (Paket 1); keine Reise → Entscheidung 1.

**Minimale Änderungen an `AlbumStore`:** (a) `private var loadFailed` → `private(set) var loadFailed` (`:48`). (b) Init-Parameter `seedsPragueExamples: Bool = true`, der `:261-283` absichert. Alle bestehenden Aufrufer und Tests bleiben unverändert.

## Migrationsablauf (einmal je Prozess, im `TripLibrary`-Init, bevor ein `AlbumStore` den Altbestand öffnet)

1. **Index laden.** Fehlt → leer. Defekt → in `library.corrupt-<ts>.json` umbenennen, aus `Trips/` neu aufbauen. `version > 1` → nur lesen, keine Migration.
2. **Schon erledigt?** Beleg `committed` und `Trips/<id>/album.json` decodierbar → fertig, Altbestand nie wieder lesen. Beleg `committed`, Ordner fehlt → Eintrag unavailable, **kein** Rückfall auf den veralteten Altbestand, Fehler anzeigen.
3. **Altbestand prüfen.** Kein `Album/album.json` → nichts zu migrieren. Nicht als `AlbumData` decodierbar → **nicht migrieren**, Altbestand wie heute öffnen (`loadFailed` verhindert Schreiben), Fehler melden.
4. **Speicherplatz:** mindestens Quellgröße × 1,2 + 50 MB (`volumeAvailableCapacityForImportantUsage`). Reicht nicht → Abbruch ohne Schreiben, Altbestand in place, Hinweis „Reisen werden beim nächsten Start übernommen“.
5. Beleg `copying` mit (wiederverwendeter) ID schreiben; liegengebliebene `.staging-<id>` löschen.
6. `copyItem(Album → Trips/.staging-<id>)`.
7. **Prüfen:** gleiche Menge relativer Pfade, byteweise `contentsEqual`; Kopie decodiert als `AlbumData`; `albumID`, Orte, Dokumente, Erinnerungen gleich der Quelle. Jeder Fehler → Staging löschen, weiter wie Schritt 4.
8. Umbenennen `.staging-<id>` → `Trips/<id>` (atomar, gleiches Volume).
9. **Commit-Punkt:** Index mit Eintrag (`origin .migrated`, `lastOpenedID = id`) atomar schreiben, danach Beleg `committed` mit Zählwerten.
10. Erst jetzt `AlbumStore(root: Trips/<id>)` öffnen (der Init darf die Kopie umstellen; das Original bleibt unberührt).

| Fehlerfall | Abfang |
|---|---|
| Defekter Index | beiseitelegen, aus `Trips/` neu aufbauen; alten Index nie überschreiben |
| Halbe Kopie / Abbruch in 6–7 | nächster Start findet Beleg `copying` + Staging, löscht Staging, kopiert neu mit derselben ID |
| Abbruch zwischen 8 und 9 | `Trips/<belegID>` ohne Indexeintrag: erneut byteweise mit dem Altbestand vergleichen; gleich → committen, ungleich → verwaiste Kopie entfernen, neu kopieren |
| Volle Platte | Vorprüfung in 4; `ENOSPC` in 6 → Staging löschen, Altbestand in place, nächster Start versucht erneut. Index-Schreibfehler in 9 → Sitzung bleibt im Altbestand |
| Doppelter Start | statisches Prozess-Flag, Wiederholung idempotent über Beleg und Index |
| Defekte Einzelreise | `unavailableReason` setzen, andere Reisen öffnen, nichts überschreiben |

## Dateien

**Neu:** `Album/TripLibrary.swift`; `AlbumTests/TripLibraryTests.swift` (isolierte Migrationstests, **vor** dem Code); `AlbumUITests/TripLibraryMigrationUITests.swift`; `QA/library-check.py` (liest nur, vergleicht Altbestand und Kopie, JSON-Beleg).
**Geändert:** `Album/AlbumStore.swift` (nur (a), (b)); `Album/AlbumApp.swift` (`TripLibrary` statt `AlbumStore` halten, Zugriffe auf `library.activeStore`, einfache Fehleransicht bei `activeStore == nil`, DEBUG-Abbildung von `ALBUM_TEST_STORE`, DEBUG-Fehlerinjektion, `refreshActiveEntry()` bei `.background`); `QA/prepare-fixtures.py` (beim Neuschreiben eines Slots auch `AlbumUITestLibraries/<slot>` leeren); `Album.xcodeproj/project.pbxproj` (nur über `xcodegen generate`); `PROGRESS.md` (Eintrag am Ende).

## Arbeitsschritte (einzeln abhaken)

1. [ ] Vorbedingung: `git status` sauber (außer unversionierten Plan-Dateien), `HEAD` = `1ee00bd`, kein Branch, kein Worktree.
2. [ ] Im Kopf von `TripLibraryTests.swift` alle Fehlerarten als Kommentar auflisten (Liste unten), dann die Tests schreiben (Port der alten Fälle Migration, Container-Umzug, defekte Reise, Fortsetzung nach Abbruch; neu: volle Platte, `ENOSPC`, Abbruch 8/9 mit geändertem Altbestand, defektes Altbestand-JSON, Index `version 2`, neue leere Reise ohne Prag-Vorgaben). Sie kompilieren noch nicht, das ist gewollt.
3. [ ] Testnähte in `TripLibrary.init`: `availableCapacity: () -> Int64?` und `copier: (URL, URL) throws -> Void` mit produktiven Standardwerten.
4. [ ] `AlbumStore` (a) und (b).
5. [ ] `TripLibrary.swift`: Typen, Pfade, atomares Schreiben, Index laden und neu aufbauen.
6. [ ] Migration Schritte 1–10 samt Belegverwaltung.
7. [ ] Fabrik und Öffnen: `createBlankTrip`, `createStarterTrip`, `open`, `restoreLastOpenedTrip`, `showLibrary`, `refreshActiveEntry`.
8. [ ] `xcodegen generate`; `pbxproj`-Diff prüfen (nur neue Dateien), sonst Einträge von Hand setzen.
9. [ ] `TripLibraryTests` grün (Ausgabe sichern).
10. [ ] `AlbumApp` verdrahten. DEBUG: `existed = legacy/album.json existiert || library.json existiert`, berechnet vor dem Bibliotheks-Init. DEBUG-Variablen nur zusammen mit `ALBUM_TEST_STORE`: `ALBUM_QA_MIGRATION_FAULT=during-copy|after-rename|no-space`, `ALBUM_QA_CORRUPT_INDEX=1`, `ALBUM_QA_CREATE_TRIP=<Titel>`.
11. [ ] `QA/prepare-fixtures.py` anpassen.
12. [ ] `TripLibraryMigrationUITests.swift` und `QA/library-check.py` schreiben.
13. [ ] Voller Lauf Unit und UI, `.xcresult` sichern. Bekannte Altlasten (siehe „Basislinie“) getrennt ausweisen.
14. [ ] Migration einer echten Kopie auf dem Simulator (E1).
15. [ ] `PROGRESS.md`-Eintrag mit Commit-Stand, Belegen, offenen Punkten. Commit nur nach Freigabe, kein Push.

## Entscheidungen und Risiken

1. **Neuinstallation in Paket 1** (noch ohne Übersicht): Startreise wie heute mit Prag-Beispielen (`origin .starter`), damit sich bis Paket 2/3 nichts ändert. *Entschieden (Empfehlung übernommen).*
2. **Volle Platte / Kopie scheitert:** Altbestand in place weiternutzen, beim nächsten Start erneut versuchen. *Entschieden.*
3. **Vor dem ersten Installieren von Paket 1 auf dem iPhone** den App-Container über Xcode → Devices → „Download Container“ sichern (Nutzeraktion, Pflicht-Gate).
4. **`Album/` nie automatisch löschen** (V1).

Risiken: Auf dem iPhone läuft `a63fb6f` ohne B1; Gerätedaten haben vermutlich das Schema vor B1 (Test E1b ist Pflicht). Downgrade: ein alter Build liest den eingefrorenen `Album/`-Stand und könnte `dirty`-Einträge erneut hochladen (keine alten Builds mehr installieren). Doppelter Speicherplatz. Ein einziger Share-Kontext (bei mehreren Reisen `trip-mismatch`, Lösung in ML-03/04). *Annahme, nicht geprüft:* `album.json` enthält keine absoluten Pfade (nur die DEBUG-Fixture `qa-photo.png`, `AlbumApp.swift:57-62`). `xcodegen` kann mehr als die neuen Dateien umschreiben.

## Prüfplan

**Fehlerarten (vor dem Code festhalten):** Index fehlt / kein JSON / `version 2`; Beleg `copying` mit liegengebliebenem Staging; Ordner ohne Indexeintrag (Altbestand gleich bzw. geändert); Beleg `committed` aber Ordner fehlt; Altbestand-JSON defekt; zu wenig Platz vorher bzw. `ENOSPC`; Index-Schreibfehler nach dem Umbenennen; Zählwerte weichen ab; neue leere Reise erhält Prag-Ideen/Hotel/Daten; zweiter Init im selben Prozess; Container-Umzug.

| # | Szenario (XCUITest, isolierte Stores) | Beleg |
|---|---|---|
| E1 | Echte Kopie des produktiven `Album/` aus dem Simulator (`simctl get_app_container … data`, `cp -Rp` nach `AlbumUITests/slot-prag-migration-<datum>/`, vorher `shasum`-Manifest). Start zeigt Reise „Prag“, Ideen und Karte sichtbar | Screenshots; `legacy-migration.json`; `library-check.py`-JSON: gleiche Orts-IDs, Stimmen, Dokumente, Erinnerungen, Dateien; Manifest des Slot-Originals vor und nach dem Lauf identisch |
| E1b | wie E1 mit Fixture im Stand vor B1 (ohne `schemaVersion`) | Kopie hat `schemaVersion 2` und eigene Backup-Datei; Original-Hash unverändert |
| E2 | zweimal starten | Index mit genau 1 Eintrag, 1 Ordner in `Trips/`, kein `.staging-*` |
| E3 | `MIGRATION_FAULT=during-copy`, dann `after-rename`, jeweils danach normal starten | gleiche Trip-ID im Beleg vor und nach; 1 Eintrag |
| E4 | `MIGRATION_FAULT=no-space` | Reise öffnet aus dem Altbestand, Hinweis sichtbar, kein Indexeintrag; nächster Start migriert |
| E5 | `CORRUPT_INDEX=1` | `library.corrupt-*.json`, neuer Index mit derselben ID, Reise geöffnet |
| E6 | `CREATE_TRIP=Paris` nach migriertem Prag, Neustart ohne Flag | Paris ohne Ideen, „Zeitraum offen“, kein „Urban Crème“; Neustart öffnet Paris; Prags `album.json`-Hash unverändert; 2 Ordner |
| R | voller bestehender Unit- und UI-Lauf über die Bibliothek | `.xcresult`, bestanden/übersprungen/fehlgeschlagen, Altlasten getrennt |

Echte Geräte sind nicht Teil der Abnahme von Paket 1. Belege unter `.qa-shots/library-<datum>/`.

## Basislinie (Ergänzung des Hauptchats, 26.10.2026)

Der volle UI-Lauf auf `1ee00bd` zeigt Fehler in den alten Klassen `AlbumUITests` und `AlbumMotionUITests` (z. B. `testBoardingPass`, `testSyncIsland`, `testInboxStack`, `testLetterSlotThrow`), die die frühere Tab-Oberfläche prüfen. Vor Schritt 13 wird die Fehlerliste auf dem Vergleichsstand `6af99c5` bestimmt (`git archive` in ein Temp-Verzeichnis, kein Worktree), damit nur echte Regressionen von Paket 1 gezählt werden.
