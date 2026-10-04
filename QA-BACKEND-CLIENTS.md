
## W1-B-014 — Swift-Supabase-Mehrclient-Gate (opt-in)

`AlbumTests/SupabaseSwiftIntegrationTests.swift` ist ein echter Swift-Client-
Gate für zwei getrennte anonyme `SupabaseClient`-Instanzen. Er läuft nur mit
`ALBUM_LIVE_SUPABASE=1`, liest `SupabaseURL`/`SupabaseAnonKey` ausschließlich
aus dem Test-Bundle und verlangt vor jedem Auth-Request einen beschreibbaren,
absoluten `QA_RUN_RECEIPT_PATH`. Die Receipt ist `0600` und enthält nur
`qa_run`, User-IDs, Trip-ID und Status; Tokens werden weder gespeichert noch
angehängt.

Jeder Client verwendet einen eigenen `AuthLocalStorage`, eigenes `storageKey`,
eigene `AlbumStore`- und `ShareInbox`-Wurzel. Der Test meldet beide Sessions
mit `qa_run`/`qa_role` an, prüft Create/Join, Trip-Roundtrip, Collection-Post,
Kommentar, Herz, Place-Link und einen anschließenden konkurrierenden CAS-
Abgleich derselben Place-Link-ID über den produktiven `sync(store:)`: Beide
Clients erzeugen dieselbe Löschung, A schreibt Version `n+1`, B bleibt zunächst
auf `n` dirty, führt den produktiven Retry aus und konvergiert auf eine höhere
Version. Der synthetische QA-Ort wird nur in A vor dem Create markiert und nach
B geroundtripped; Titel und Koordinaten werden geprüft. `syncService` wird für beide Stores direkt nach Initialisierung auf einen
testinternen `NoBackgroundSyncService` gesetzt. `nil` würde den Lazy-Produktionsclient
beim automatischen Collection-Sync zulassen und isoliert den Test deshalb nicht.
Realtime und Netzwerk-Hintergrund-Sync werden so verhindert. Vor erfolgreichem
Abschluss verlangt der Test exakt die beiden ursprünglichen IDs in `trip_members`
und prüft vor/nach jedem expliziten Sync ihre stabilen Sessions.

Die Cleanup-Verantwortung bleibt beim Parent-Lauf: Die Receipt muss nach jedem
Ergebnis anhand der exakten User-IDs, Trip-ID und `qa_run`-Metadaten über den
Supabase-MCP bereinigt und die Baseline erneut geprüft werden. Storage-Tests
gehören erst nach erfolgreichem Remote-Cleanup in einen getrennten Gate.

Der Live-Test und die Date-Codec-Regressionen sind als Compile Sources in
`Album.xcodeproj/project.pbxproj` aufgenommen. Der Backend-Test läuft ausschließlich
explizit mit Live-Flag und geschützter Receipt; eine normale Suite überspringt ihn.

### Date-Coding-Nachtrag (2026-10-03)

`SupabaseConfiguration.databaseOptions()` ist jetzt der gemeinsame Database-
Options-Helper für Produktionsclient und Swift-Live-Test. Sein Decoder akzeptiert
ISO-8601-Strings mit und ohne Bruchteile sowie endliche numerische Werte. Der
historische Seed-Sentinel `-62135769600` wird als Unix-Sekundenwert gelesen; die
übliche Swift-Referenzsekundenform bleibt ebenfalls unterstützt. Der SDK-
Standardencoder bleibt unverändert und schreibt weiterhin ISO-8601-Strings.

`AlbumTests/SupabaseDateCodecTests.swift` deckt gemischte Row-Daten,
fractional ISO, Encoder-Roundtrip, ungültige Daten und den Schutz einer neueren
lokalen Reise vor dem älteren Default-Seed ab. Die sechs Codec-Tests und neun Sync-Regressionen bestehen im Lauf
`work/date-codec-regressions.xcresult` (15 Pass, keine Fehler oder Skips).
Der Live-Nachtest `work/swift-runtime-proof.xcresult` besteht (1 Pass, keine Fehler/Skips).
Receipt-Revision `no-background-v3` und die unabhängige MCP-Nachprüfung bestätigen
exakt zwei Teilnehmer und unveränderte Client-Identitäten. Alle Testdaten wurden
guarded bereinigt; Baseline wieder 1 Reise, 3 Mitglieder, keine Collection-Einträge
und keine verbleibenden markierten Swift-Testnutzer. Realtime und Storage bleiben
getrennte offene Gates.

### W1-B-015: isolierter Storage-Roundtrip (opt-in, noch nicht runtimeverifiziert)

`testTwoSwiftClientsUploadDownloadAndRepairStorage` verwendet zwei Swift-Clients
mit getrennten Auth-/Store-/Inbox-Wurzeln, identischen Produktions-
DatabaseOptions, `NoBackgroundSyncService` und der Pflichtrevision
`storage-roundtrip-v1`. Nur synthetisches gültiges JPEG und PDF werden verwendet.
Die `0600`-Receipt enthält vor dem ersten Upload exakte Trip-/Place-/Document- /
User-IDs und beide vollständigen Bucketpfade, keine Tokens. A synchronisiert
explizit, B joint/synchronisiert, validiert JPEG/PDF und Bytegleichheit, lädt den
Store neu und prüft danach Reparatur nach gelöschtem Bild-/beschädigtem PDF-Cache.
Root bereinigt ausschließlich belegte QA-Objekte unter exakt diesem Trip-Präfix
und anschließend QAtrip/AuthIDs; Membership/Baseline unabhängig prüfen.
Keine Realtime-Aktivierung in diesem Gate; deren Lifecycle-Abnahme bleibt separat.

### W1-B-016: Swift-Realtime-Callback und Stop-Lifecycle (opt-in, Runtime bestanden)

`testTwoSwiftClientsReceiveRealtimeChangesAndStop` verwendet die Revision
`realtime-v5-startup-contract`, zwei getrennte Clients und isolierte Stores. Nach einem
expliziten Baseline-Sync wird nur für A der echte `SupabaseSync` als Service
gesetzt; der Callback führt `storeA.sync()` aus und erfüllt genau eine XCTest-
Startup-Catchup und danach getrennte Erwartungen für den neuen B-Ort,
Collection-Post, Kommentar/Herz und Trip-Änderung.
Readiness wird innerhalb von zehn Sekunden über `realtimeV2.channels` und den
SDK-Status `.subscribed` bestätigt; ein zweiter `startRealtime` darf keinen
zweiten Channel erzeugen. `stopRealtime()` muss alle Channels entfernen; ein
zweiter B-Write darf danach weder neuen A-Ort noch weiteren Callback erzeugen.
Receipt, exakte zwei Membership-IDs und Cleanup-Verantwortung bleiben wie bei
den anderen Live-Gates; Storage und SQL-Selbstcleanup sind ausgeschlossen.
Die Receipt führt zusätzlich eine Phasen-Timeline mit UTC-Zeitstempeln für
`subscription.start`, Startup-Catchup/`isRealtimeReady`, Readiness, B-Writer, Callback-Anfang/-Ende und die
15-Sekunden-Fulfillment-Waits jeder Phase. Ein Timeout bleibt als `failed-timeout` markiert;
er darf nicht als `completed` erscheinen.

Runtime 03.10.: `work/swift-realtime-lowercase.xcresult`: 14 Tests bestanden (Live-Gate plus 13 Lifecycle-Regressionen). UUID-Werte der vier Realtime-Filter werden lowercase serialisiert; der SDK-Dispatch vergleicht lokale und vom Server zurückgegebene Filter exakt. Nur diese Änderung ließ den Live-Callback eintreffen (count 1, Abgleich abgeschlossen, Stop verhindert weitere Änderungen). Das vorherige Replication-Ready-Experiment blieb erfolglos und wurde entfernt. QA-Daten anschließend guardiert bereinigt.

Aktuelle Erweiterung `realtime-v5-startup-contract`: Startup-Catchup und
`isRealtimeReady` werden vor dem ersten B-Write separat als Systemereignis
abgenommen; der Place-Callback wird relativ zum Startup-Count als genau ein
Genuine-Event bewertet. Die Zusatzphasen bleiben bis zum neuen Lauf
source-ready; Dokumente bleiben als Realtime-Gate offen.

Echtzeittest 2026-10-03: work/swift-realtime-v6-ready.xcresult bestätigt mit Runtime-Revision realtime-v6-place-delta initialen Abgleich sowie Place, CollectionPost, Comment/Heart und Trip. Exakt zwei Teilnehmer, Stop entfernt Kanal und verhindert weitere Callbacks. Dokument-Ereignisse und echte Wiederverbindung nach Netzunterbrechung bleiben separate offene Gates. QA-Daten exakt bereinigt.
