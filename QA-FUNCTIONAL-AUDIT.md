# QA-FUNCTIONAL-AUDIT — W1-B Daten, Sync, Import

Stand: 2026-10-02. Geprüft wurde der aktuelle Main-Quellstand lesend gegen `QA-FULL-PLAN.md`. Es wurden keine Produktionsdaten geschrieben, kein Build und kein UI-Lauf gestartet. `CollectionStore`/CAS-Details aus den bereits behobenen Collection-Aufträgen sind hier nicht erneut bewertet; geprüft ist die Anbindung an Persistenz, Share-Queue, normale Orte, Dokumente und Collaboration.

## Aktuelle Statusmatrix W1-B-001 bis W1-B-014

Abgleich mit dem aktuellen Quellstand und dem Regressionstestlauf mit 103
bestanden Unit-Tests (2026-10-02, 22:07:10). „Sourcefixed + Unit“ bedeutet,
dass der produktive Methodenpfad durch den genannten Test kontrolliert wird;
es ist kein Nachweis eines echten Supabase-Mehrclientlaufs.

| ID | Aktueller Status | Nachweis / offener Gate |
| --- | --- | --- |
| W1-B-001 | **Offen – Produktentscheidung** | `AlbumStore.drainShareQueue()` verarbeitet fehlgeschlagene Items weiterhin automatisch erneut. Das Verhalten ist im Fixplan als möglicherweise gewünschte Idempotenz/Retry-Policy eingeordnet; kein Bug-Fix behauptet. |
| W1-B-002 | **Sourcefixed + Unit nachgewiesen** | `StoreRegressionTests.testUpsertRollsBackWithoutDeletingCallerOwnedImageWhenPersistenceFails`; erfolgreicher Bildtausch zusätzlich in `testSuccessfulImageReplacementRemovesOldFileAfterCommit`. |
| W1-B-003 | **Sourcefixed + Unit nachgewiesen** | `StoreRegressionTests.testTripAndPDFMutationsRollBackTogetherWithCopiedPDF` und `testUpdateTripReturnsTrueAndPersistsCommittedTrip`. |
| W1-B-004 | **Sourcefixed + Unit nachgewiesen** | `StoreRegressionTests.testOpeningHoursResultIsDroppedWhenPlaceChangedWhileRequestWasInFlight`. |
| W1-B-005 | **Sourcefixed + Unit nachgewiesen** | `StoreRegressionTests.testTripAndPDFMutationsRollBackTogetherWithCopiedPDF` prüft atomaren Fehlerpfad und keine Waisen-PDF. |
| W1-B-006 | **Sourcefixed + Unit nachgewiesen** | `SyncRegressionTests` prüft Trip-/Place-/Dokumentmutation während Await sowie Bildupload-Payload, Dirty-Marker und Bildpfad (`testTripMutationDuringWriteKeepsDirtyMarkerAndPayload`, `testPlaceMutationDuringWriteKeepsDirtyMarkerAndPayload`, `testDocumentMutationDuringUploadDoesNotUpsertOldMetadata`, `testImageUploadPreservesNewerPlacePayloadAndAttachesOnlySameImagePath`, `testImageUploadDoesNotAttachOldPathToNewerImage`). |
| W1-B-007 | **Sourcefixed + Unit nachgewiesen** | `SyncRegressionTests.testRealtimeSubscribeFailureAllowsLaterStart` und `testObsoleteRealtimeTaskCannotClearNewerTripState`. |
| W1-B-008 | **Sourcefixed + Unit nachgewiesen; Mehrclient-Gate offen** | `StoreRegressionTests.testCreateJoinStartRealtimeAndOverlappingSyncRunsOneFollowUp` prüft die produktiven Store-Methoden mit Probe-Service. Ein echter Swift-/Supabase-Mehrclientlauf bleibt separat offen. |
| W1-B-009 | **Offen – Photo-/Bildsuche-Async-Cancel** | `PlaceEditor` verwaltet Such-/Import-/StreetView-Tasks weiterhin nicht vollständig über den Editor-Lebenszyklus. Ein kontrollierter Late-Result-Abbruchtest und native Fotoauswahl-Abnahme stehen aus. |
| W1-B-010 | **Sourcefixed + Unit nachgewiesen** | `StoreRegressionTests.testGeocodeResultIsDroppedWhenHotelAddressChangedWhileRequestWasInFlight`. |
| W1-B-011 | **Sourcefixed + Unit nachgewiesen** | `DownloadRegressionTests.testMissingEmptyAndCorruptPDFsAreRepairedIncludingSameUpdatedAt`, `testMissingEmptyAndCorruptImagesAreRepaired`, `testValidCachesSkipDownload`, `testInvalidRemoteResponseDoesNotReplaceExistingFiles`, `testNewerDirtyLocalVersionsAreNeverReplacedByOlderRemoteFiles`. |
| W1-B-012 | **Offen – ShareContext-Korruption** | `ShareInbox.loadContext()` unterscheidet beschädigten und fehlenden Kontext weiterhin nicht ausreichend. Isolierte Queue-/Recovery-Reproduktion fehlt. |
| W1-B-013 | **Offen – Cleanup-Fehler** | `PlaceImageStorage.remove` verschluckt Löschfehler weiterhin. Schreibgeschützter Root und verständlicher Retry-/Cleanup-Zustand sind ungeprüft. |
| W1-B-014 | **Sourcefixed + Unit nachgewiesen; Mehrclient-Gate offen** | `StoreRegressionTests.testCreateJoinStartRealtimeAndOverlappingSyncRunsOneFollowUp` und `testFailedSyncDoesNotCreateAutomaticRetryLoop`; echter Swift-/Supabase-Mehrclient-Realtimeablauf bleibt offen. |

## Bestätigte Codefehler

### W1-B-001 — Fehlgeschlagene Share-Items werden beim nächsten Vordergrund automatisch erneut importiert

- Priorität: P1 · Status: offen · Eigentum: AlbumStore/ShareInbox
- Schritte: Share-Item importieren lassen, sodass `addCollectionPost` oder das lokale Entfernen fehlschlägt; App erneut aktivieren.
- Erwartet: Ein `failed`-Item bleibt sichtbar und wird erst nach „Erneut versuchen“ erneut verarbeitet.
- Ist: `drainShareQueue()` iteriert über jedes Item außer `cancelled`; ein bereits als `failed` markiertes Item wird erneut verarbeitet und kann seinen Fehlerzustand ohne Nutzeraktion ändern.
- Beleg: `Album/AlbumStore.swift:166-187`.
- Minimaler Regressionstest: fehlgeschlagenes Item speichern, `drainShareQueue()` zweimal aufrufen, sicherstellen, dass der zweite Aufruf keinen Importversuch macht; Retry muss den Zustand explizit auf `pending` setzen.

### W1-B-002 — Ortsänderungen werden bei fehlgeschlagener Persistenz nicht zurückgerollt

- Priorität: P1 · Status: bestätigt · Eigentum: AlbumStore
- Schritte: `upsert(_:)` mit einem Root ausführen, in dem `album.json` nicht geschrieben werden kann; danach Store weiterverwenden oder neu laden.
- Erwartet: Arbeitsspeicher, Dirty-Marker und lokale Bilddatei entsprechen weiterhin dem zuletzt gespeicherten Zustand.
- Ist: `upsert` ersetzt den Ort, entfernt gegebenenfalls die alte Bilddatei und setzt Dirty-Marker vor `persist()`. Bei `false` bleibt der neue Ort im Speicher; die entfernte Datei ist nicht wiederhergestellt.
- Beleg: `Album/AlbumStore.swift:205-221`.
- Minimaler Regressionstest: Schreibblockade mit bestehendem Ort und Bild; nach fehlgeschlagenem Upsert müssen Ort, Bild und Dirty-Marker unverändert bleiben.

### W1-B-003 — Trip-Änderungen ignorieren Persistenzfehler

- Priorität: P1 · Status: bestätigt · Eigentum: AlbumStore
- Schritte: `updateTrip(_:)` mit nicht beschreibbarem Root ausführen, anschließend Neustart oder Sync.
- Erwartet: Fehler wird als fehlgeschlagene Mutation behandelt und die alte Trip-Version bleibt maßgeblich.
- Ist: `updateTrip` verwirft den Rückgabewert von `persist()`, plant trotzdem Sync und lässt die nicht gespeicherte Trip-Version im Speicher.
- Beleg: `Album/AlbumStore.swift:288-290`.
- Minimaler Regressionstest: `XCTAssertFalse`-Pfad für Persistenz ergänzen und prüfen, dass kein Sync für die nicht persistierte Version gestartet wird.

### W1-B-004 — Öffnungszeiten überschreiben eine zwischenzeitliche Ortsänderung

- Priorität: P1 · Status: bestätigt · Eigentum: AlbumStore
- Schritte: `proposeDayPlan` starten, während `OpeningHoursService.fetch` wartet den Ortstitel, die Adresse oder Koordinate ändern und speichern.
- Erwartet: Die asynchrone Antwort wird verworfen, wenn der Ort nicht mehr der Anfrage entspricht.
- Ist: `proposeDayPlan` hält den alten `Place`-Wert, wartet und ruft danach `upsert(checked)` ohne `matchesRequest`-Prüfung auf. Dadurch können neuere Nutzeränderungen überschrieben werden.
- Beleg: `Album/AlbumStore.swift:263-273`.
- Minimaler Regressionstest: pausierbarer Öffnungszeiten-Service; Mutation während `await`; Antwort darf nur Öffnungszeiten in den unveränderten Ort übernehmen.

### W1-B-005 — PDF-Import kann Datei und Arbeitsspeicher ohne Album-Commit hinterlassen

- Priorität: P1 · Status: bestätigt · Eigentum: AlbumStore
- Schritte: gültiges PDF importieren, Persistenz danach absichtlich fehlschlagen lassen.
- Erwartet: Entweder sind PDF-Datei und Dokument-Metadaten vollständig gespeichert oder beide Änderungen werden zurückgenommen.
- Ist: Die Datei wird zuerst kopiert und `data.documents` danach verändert. Schlägt `persist()` fehl, bleibt die kopierte Datei als Waisen-Datei und der Dokumenteintrag im Speicher.
- Beleg: `Album/AlbumStore.swift:384-399`.
- Minimaler Regressionstest: fehlgeschlagener Commit muss Dokumentliste und Ziel-PDF zurückrollen oder den Import atomar über temporäre Datei abschließen.

### W1-B-006 — Normaler Trip-/Ort-/Dokument-Sync kann In-Flight-Mutationen löschen

- Priorität: P0 · Status: bestätigt · Eigentum: SupabaseSync
- Schritte: Sync für einen dirty Trip, Ort oder Dokument starten; während Upload/Upsert wartet dieselbe lokale Entität ändern und speichern.
- Erwartet: Die neue Mutation bleibt dirty und wird in einem Folgesync übertragen.
- Ist: `pushDirty` nimmt einen Snapshot, wartet auf Netzwerkoperationen und entfernt danach blind den Dirty-Marker. Bei Orten wird zusätzlich `store.data.places[index] = place` mit dem alten Wert geschrieben. Trip und Dokumente löschen den Marker ebenfalls ohne Versions-/Token-Prüfung.
- Beleg: `Album/SupabaseSync.swift:289-326`.
- Minimaler Regressionstest: pausierbarer Transport für Trip, Place und Document; Mutation während `await`; Payload und Dirty-Marker müssen erhalten bleiben.

### W1-B-007 — Fehlgeschlagener Realtime-Subscribe wird dauerhaft nicht erneut versucht

- Priorität: P1 · Status: bestätigt · Eigentum: SupabaseSync
- Schritte: Realtime-Subscribe einmal fehlschlagen lassen; danach Netzwerk wiederherstellen oder erneut synchronisieren.
- Erwartet: Nach erfolgreichem Sync wird der Realtime-Kanal erneut aufgebaut.
- Ist: `realtimeTripID` wird vor `subscribeWithError()` gesetzt. Bei Fehler wird die Task beendet, aber `realtimeTripID` bleibt gesetzt; weitere `startRealtime`-Aufrufe passieren die Guard-Bedingung nicht mehr.
- Beleg: `Album/SupabaseSync.swift:250-267`.
- Minimaler Regressionstest: Subscribe-Fehler, danach erneuter Start; zweiter Versuch muss einen neuen Kanal erzeugen.

### W1-B-008 — Beitritt und Reiseerstellung starten Realtime nicht unmittelbar

- Priorität: P1 · Status: bestätigt · Eigentum: AlbumStore
- Schritte: Reise erstellen oder Einladung annehmen, während die App bereits aktiv ist; auf Änderung des zweiten Clients warten, ohne Scene-Wechsel.
- Erwartet: Nach erfolgreichem Beitritt/Erstellen sind Pull-Sync und Realtime aktiv.
- Ist: `createSharedTrip` und `joinSharedTrip` rufen `service.sync` beziehungsweise `service.createTrip` direkt auf, aber kein `startRealtime`. Der Kanal wird erst in `AlbumStore.sync()` nach einem späteren vollständigen Sync gestartet.
- Beleg: `Album/AlbumStore.swift:425-448`, `Album/SupabaseSync.swift:250-267`.
- Minimaler Regressionstest: Mock-Service zeichnet `startRealtime` nach Create und Join auf; zusätzlich echte Änderung ohne erneuten Scene-Aktiv-Zyklus prüfen.

### W1-B-009 — Asynchrone Bildsuche aus dem Editor ist nicht an den View-Lebenszyklus gebunden

- Priorität: P2 · Status: Quellfehler, Laufzeitnachweis offen · Eigentum: PlaceEditor
- Schritte: Bildsuche oder Fotoimport starten, Editor sofort abbrechen/schließen, danach Root und UI beobachten.
- Erwartet: Arbeit wird abgebrochen oder das Ergebnis wird vollständig verworfen.
- Ist: Button-/PhotosPicker-Aktionen starten ungespeicherte `Task { ... }`; `.onDisappear` cancelt nur `searchTask`, nicht `findImage`/`importPhoto`/`useStreetView`. Nach dem Schließen kann noch eine Datei geschrieben oder eine veraltete State-Änderung ausgeführt werden.
- Beleg: `Album/PlaceEditor.swift:94`, `101`, `182`, `196`, `198-200`, `305-395`.
- Minimaler Regressionstest: kontrollierbarer Resolver, Editor schließen während `await`, danach keine neue Bilddatei und keine Mutation des geschlossenen Entwurfs.

### W1-B-010 — Geocoding in der PDF-Übernahme hat keinen Stale-State-Schutz

- Priorität: P2 · Status: Quellfehler, Laufzeitnachweis offen · Eigentum: AlbumStore
- Schritte: `applyExtraction` starten, während `CLGeocoder` wartet denselben Hotel-Ort im Editor ändern, dann Geocoder antworten lassen.
- Erwartet: Die Antwort wird nur auf die noch passende Hotelmutation angewendet.
- Ist: `applyExtraction` hält `place`, wartet auf Geocoding und ruft danach `upsert(place)` ohne Vergleich mit dem aktuellen Store-Ort auf.
- Beleg: `Album/AlbumStore.swift:368-381`.
- Minimaler Regressionstest: pausierbarer Geocoder; lokale Mutation während `await` muss Vorrang behalten.

## Weitere Risiken zur Laufzeit verifizieren

- **W1-B-011 · P2:** `downloadDocument` und `downloadImageIfNeeded` überspringen den Download, sobald am Zielpfad irgendeine Datei existiert (`SupabaseSync.swift:427-443`). Ein beschädigtes oder veraltetes lokales Artefakt wird daher nicht repariert. Mit fehlender, leerer und korrupt ersetzter Datei im Neustart-/Sync-Test prüfen.
- **W1-B-012 · P2:** `loadContext()` behandelt kaputtes `ShareContext.json` genauso wie fehlenden Kontext (`Shared/ShareInbox.swift:54-56`); die UI zeigt nur „Album einmal öffnen“. Eine absichtlich beschädigte Kontextdatei muss sichtbar und wiederherstellbar sein, ohne Queue-Dateien zu löschen.
- **W1-B-013 · P2:** `PlaceImageStorage.remove` verschluckt jeden Löschfehler (`Album/PlaceImageStorage.swift:30-32`). Mit schreibgeschütztem Bildroot prüfen, ob ein verständlicher Retry-/Cleanup-Zustand existiert.
- **W1-B-014 · P2:** `sync()` verwirft überlappende Aufrufe über `!syncing` (`Album/AlbumStore.swift:402-405`). Realtime-Events während eines laufenden Syncs müssen im echten Mehrclientlauf zeigen, dass der nächste Zustand dennoch sicher abgeholt wird.

## Testlücken und reproduzierbare Konfiguration

- `AlbumUITests.testSelectTravelDay`, `testAutomaticDayPlanPreview`, `testMapListHeightsAndSelection`, `testMapPinClustersZoomToPlaces` und `testScreenTour` laufen nur mit `ALBUM_PLAN_STORE`, für die meisten Pfade mit Präfix `slot-`. Der Store muss unter `Application Support/AlbumUITests/<store>/album.json` vorhanden sein und Orte mit gültigen Koordinaten, Kategorien, Franken-/Tagesplanstatus sowie für Map-Cluster nahe Koordinaten enthalten. `ALBUM_TODAY=2026-10-06`, optional `ALBUM_MAP_ROW_ID=<placeID>`, `ALBUM_SHOT_DIR=<directory>` und `ALBUM_SHOT_SUFFIX=<suffix>`.
- `AlbumMotionUITests` benötigt `ALBUM_MOTION_STORE=slot-*` und optional `ALBUM_SHOT_DIR`. `testPhotoStack`, `testVisitedTrack` und die Ticketprüfung setzen zusätzlich `ALBUM_DEMO_MOTION=1`; `testInvitationMoment` setzt `ALBUM_DEMO_INVITE=failthenok` und optional `ALBUM_DEMO_SENDER=Mia`; `testSyncIsland` setzt `ALBUM_DEMO_SYNC=1`.
- `testLetterSlotThrow` verwendet `ALBUM_SLOT_STORE=slot-*` (oder erzeugt bei fehlender Variable selbst einen Store), `testInboxStack` `ALBUM_INBOX_STORE=slot-*`; beide akzeptieren `ALBUM_SHOT_DIR`.
- Bildauswahl-/Fallbackpfade werden deterministisch mit `ALBUM_IMAGE_RESPONSE_BASE64=<JSON-base64>`, `ALBUM_DEMO_IMAGE_CHOICE=1`, `ALBUM_START_TAB=Karte` und optional `ALBUM_DISABLE_LOOK_AROUND=1` aktiviert. Der JSON-Response muss `selection_version >= 3`, verifizierte Haupt-/Kandidatenbilder und gültige URLs enthalten.
- `testRealBookingPDFIfAvailable` benötigt `ALBUM_SAMPLE_PDF=/absolute/path/file.pdf`; ohne diese Variable wird der Test übersprungen. Für den echten Importtest zusätzlich einen nicht beschreibbaren Store, ein gesperrtes PDF, ein >25-MB-PDF und einen Neustartlauf vorbereiten.
- Accessibility-Audits sind nur mit `ALBUM_RUN_ACCESSIBILITY_AUDITS=1` aktiv. Der App-Host deaktiviert Sync und Share-Queue-Drain bei `XCTestConfigurationFilePath`; jeder UI-Lauf muss trotzdem `ALBUM_TEST_STORE=...` setzen, damit kein produktiver Root beschrieben wird.

## Empfohlene minimale Regression-Welle

1. Fehler- und Rollbacktests für W1-B-001 bis W1-B-005, jeweils mit isoliertem Store und wiederholtem Neustart.
2. Injektierbarer Fake-Transport für Trip/Place/Document und Realtime-Subscribe, analog zum bestehenden Collection-Transport; deckt W1-B-006 bis W1-B-008 ab.
3. Kontrollierbare Geocoder-/Bildresolver-Tests für Abbruch und Stale-State (W1-B-009/010).
4. Ein vorbereiteter `slot-plan-*`-Store und ein `.xctestplan`-Lauf mit den oben genannten Variablen, damit Tagesplan, Karte/Cluster, Dokumente, Motion und Accessibility nicht als Skip in der Abnahme erscheinen.
