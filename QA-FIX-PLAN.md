# Fixplan — Sol 6.1, erste bestaetigte Datenfunde

Quelle: QA-FUNCTIONAL-AUDIT.md; Parent hat die betroffenen aktuellen Methoden selbst geprueft. Native Befunde werden nach ihrer Reproduktion ergaenzt. Jede Korrektur benoetigt produktive Codepfad-Tests und erneute Bedienung; das Gesamttestziel bleibt offen.

## Paket FIX-DATA (Luna, AlbumStore + eigener neuer Regressionstest)

- W1-B-002/003/005: lokale Mutation erst wirksam, wenn album.json atomar gespeichert wurde. Snapshot fuer upsert/updateTrip/PDF-Import zurueckrollen; alte Bilddatei erst nach erfolgreichem Commit entfernen, neu kopiertes PDF bei Fehler entfernen, vorhandenes PDF nicht loeschen. Fehler sichtbar halten, keinen Sync fuer nicht gespeicherte Mutation starten. Signaturkompatibilitaet und Caller-Abnahme erhalten.
- W1-B-004/010: asynchrone Oeffnungszeiten-/Geocoder-Ergebnisse nur in passenden aktuellen Ort uebernehmen. Nutzertext/Adresse/Koordinaten/Bild niemals durch alten Snapshot ueberschreiben; nur ergaenzte Felder mergen. Injektierbare Resolver fuer echte pausierbare Regressionen; Produktionsdefaults weiter echte Dienste.
- W1-B-008/014: nach erfolgreichem Create/Join Realtime starten. Ueberlappende Sync-Anforderung merken und nach erfolgreichem aktiven Lauf nachholen; neuere Dirty-Entitaeten auch ausserhalb Sammlung erneut uebertragen. Netzwerkfehler duerfen keine Endlosschleife erzeugen. Service-Counter/pausierbarer Service prueft reale Store-Methoden.
- Eigentum: Album/AlbumStore.swift und AlbumTests/StoreRegressionTests.swift. Kein SupabaseSync/Models/View-Protokollumbau ohne Abstimmung. Andere Agenten arbeiten parallel, Aenderungen erhalten.

## Paket FIX-SYNC (Luna, SupabaseSync + eigener neuer Regressionstest)

- W1-B-006: Trip/Place/Document-Snapshot vor jedem await behalten. Dirty-Marker nur bestaetigen, wenn aktuelle lokale Mutation noch exakt zum uebertragenen Snapshot passt. Bild-Upload-Metadaten duerfen nur passend zum gleichen Bild eingehaengt werden und keine neueren Ortsdaten ersetzen. IDs nach await neu suchen; keine stale Indizes verwenden. Datenverlust wird mit pausierbarem produktivem Transportweg fuer alle drei Typen getestet.
- W1-B-007: Subscribe-Fehler/Beendigung laesst einen spaeteren Start erneut zu. Veraltete Tasks duerfen Zustand einer neueren Trip-Subscription nicht loeschen. Kein wiederholter gleichzeitiger Kanal, keine ungebremste Retry-Schleife. Produktive Realtime-Startlogik mit injizierbarem Subscribe kontrolliert testen.
- Eigentum: Album/SupabaseSync.swift und AlbumTests/SyncRegressionTests.swift. FIX-DATA uebernimmt Store-Scheduling; gegenseitig API-Anforderungen melden. Kein Backend-Schema-Change und keine Produktions-Requests in Tests.

## Noch nicht als Fix autorisiert

- W1-B-001: automatische Retry-Verarbeitung eines fehlgeschlagenen Share-Items kann bewusst sinnvoll sein. Kein Nachweis, dass manuelles Retry exklusiv verlangt wurde; zunaechst Datenverlust/Idempotenz und sichtbare Wiederholung testen, keinen kuenstlichen Bedienzwang einfuehren.
- W1-B-009/011/012/013: konkreten Lebenszyklus/korrupten Artefakt-/Fehlerablauf reproduzieren; anschliessend naechstes Paket.
- LetterSlot unter Reduce Motion: Autoabschluss kann nach bereits bestaetigtem Speichern beabsichtigt sein; kein pauschales Abschalten ohne Caller-/Laufzeitbeweis.

## Pruefung / Integration

Neue sinnvolle Regressionen + gesamter Compile/Test nach Quelldelta, Native-Binaerstand sichtbar erfassen und betroffene Ablaeufe nochmals bedienen. Parent betreibt Build allein. Erste Gesamtsuite laeuft vor Integration zu Ende; ihre Baseline bleibt als Befund erhalten. Native CUA hat waehrenddessen genau einen Besitzer.

## FIX-EDITOR / Sol-Lifecycle-Plan
### Late-Resolver-QA-Gate
- `PlaceImageService.search` besitzt für DEBUG-`slot-*`-Stores mit vorhandener `ALBUM_IMAGE_RESPONSE_BASE64`-Antwort einen begrenzten `ALBUM_IMAGE_RESPONSE_DELAY_MS`-Hook (0–15000 ms). Der Delay läuft absichtlich detached, damit ein verspätetes Ergebnis trotz Cancel reproduzierbar bleibt; Produktions- und Netzwerkpfade bleiben unverändert.
- `AlbumUITests/testCancelDelayedPlaceImageSearch` startet einen eindeutigen isolierten Store, wartet auf `Bilder werden gesucht …`, bricht den Editor ab, wartet über den Delay hinaus und prüft, dass kein Bildauswahl-Sheet, kein QA-Credit und nach Relaunch kein Foto-Draft persistiert wurde.
- Der Late-Resolver-Test speichert den Fixture-Ort vor dem Suchlauf einmal als Baseline; beim Relaunch entfernt er die Demo-Seed-Variable und prüft denselben Ort aus `album.json`, damit die Persistenzprüfung nicht durch erneutes Demo-Seeding verfälscht wird.
- Der PhotosPicker-`photoTask`-Pfad bleibt ein separates Gate, da XCTest derzeit keinen sicheren deterministischen Systempicker-Loader besitzt.

Quellpruefung bestaetigt: PlaceEditor erzeugt unverwaltete Bildsuche-/PhotosPicker-/StreetView-Tasks; nach Abbrechen kann ein nicht kooperativ abbrechender Resolver noch eine neue lokale Datei schreiben. Bestehende Titel-/Adressguards erkennen ein geschlossenes, sonst unveraendertes Editor-Draft nicht.
- Eigentum Luna UI: Album/PlaceEditor.swift und bei Bedarf eine abgegrenzte Regressionstestdatei.
- Bild-/Foto-Tasks explizit verwalten. Jede neue Operation ersetzt/invalidiert die alte; Resultate brauchen Operationgeneration, Cancellation und gueltigen Editor-Lebenszyklus.
- Vor Resultatmutation UND Dateischreiben guards; auch Catch und Defer duerfen neue Operation nicht zuruecksetzen. Cancel und erfolgreicher Save stoppen laufende Arbeit sofort; fehlgeschlagener Save behaelt den Editor offen.
- onDisappear eines Kind-Pickers darf nicht irrtuemlich ein noch offenes Editor-Draft vernichten. Beim echten Editor-Ende ungespeicherte pendingPhoto-Dateien entfernen, gespeicherte Fotos erhalten.
- Standort-/Quellwechsel-Staleguards und manuelle Fotoauswahlprioritaet erhalten. Keine breite Designaenderung.
- Pruefung: kontrollierte verspätete Antwort nach Abbruch/Neustart einer Operation; kein Schreiben/State-Commit. Anschliessend Build/gezielter Nachlauf durch Parent; native Fotoauswahl bleibt zusaetzliche Abnahme.

## FIX-TRIP-EDITOR / Sol-Speichervertrag
- Bestaetigt: updateTrip rollt Speicherfehler inzwischen zurueck, liefert aber keinen Erfolg; TripEditor schliesst trotzdem und verliert den Entwurf. applyExtraction setzt Hotelarbeit trotz fehlgeschlagenem Trip-Commit fort.
- Luna-Eigentum: Album/AlbumStore.swift, Album/TripDocumentsView.swift, AlbumTests/StoreRegressionTests.swift.
- updateTrip wird @discardableResult Bool, true nur nach persist/scheduleSync, false nach Rollback. TripEditor dismiss nur bei true; bestehender globaler Fehlerdialog und Entwurf bleiben bei false. applyExtraction kehrt beim fehlgeschlagenen Trip-Commit vor Hotel/Geocoding zurueck.
- Vorhandene Rollbackregression auf false erweitern; Erfolg auf true/persistierte Reisedaten pruefen; keine neue Anbindung/Designaenderung.

## FIX-CLUSTER-SELECTION / Sol-Auswahlvertrag
Bestaetigter UX-Grenzfall: Orte in ca.2–6m Abstand bleiben bei der Zoomgrenze als Gruppe zusammen; ein weiterer Tap zoomt ohne nutzbare Auswahlmoeglichkeit. Ein einzelner ausgewaehlter Ort wird von pinGroups bereits separat dargestellt.
- Luna-Eigentum: Album/TripMapView.swift, AlbumUITests/AlbumUITests.swift (nur Cluster-Test), neue eng begrenzte Policy-Regressionsdatei bei Bedarf.
- Normales erstes Gruppentippen zoomt weiter wie bisher. Bleibt dieselbe Gruppe nach wiederholtem gezieltem Tap bestehen oder ist Zoomgrenze erreicht, native Mitgliederauswahl anbieten (bestehende Farben/Schriften/Spacing, kompakte Listenauswahl, Abbrechen).
- Ein Mitglied antippen schliesst Auswahl und ruft dieselbe select(place)-Logik auf: zugehoerige Listenzeile sichtbar/ausgewaehlt und Einzelpin desselben PlaceID. Originaldetail-Sheet bleibt getrennt, kein konkurrierendes doppeltes Sheet.
- Keine willkuerliche Ortsauswahl/zyklisches Ueberschreiben und keine Koordinatenaenderung. Gelöschte/gefilterte Orte nicht als veraltete Auswahl uebernehmen.
- Test durch echten UI-Pfad: Wiederholtes Clusterzoomen, bei angebotener Mitgliederauswahl erwartete ID gezielt waehlen, danach identischer Einzelpin und identische Listenzeile. Coarse Zoom und sehr nahe/identische Ortspositionen als getrennte Akzeptanzfaelle erhalten.

## FIX-DRAWER-INPUT / Sol-Gestenvertrag
- Video zeigt beim zweiten abwaerts gemeinten Swipe eine sichtbare Aufwaertsbewegung zum Ausgangsbild; End-AX ist half. Der genaue Zwischenrastpunkt/Handler ist nicht instrumentiert. Code besitzt konkurrierenden Button-Tap und highPriorityDrag plus100msRuecksetzdelay.
- Die UI-Pruefung benutzt swipeDown auf einem44pthohenGrabber, also keinen definierten menschlichen langen Fingerweg. Diese Testannahme separat korrigieren statt Physik fuer kurze Testevents zu verbiegen.
- Luna-Eigentum: Album/PlacesDrawer.swift, AlbumUITests/AlbumUITests.swift nurMapListHeightsAndSelection.
- Grabber-Tap und Drag als gegenseitig ausschliessende SwiftUI-Gesten kombinieren. Echte Drag-Erkennung darf beim Loslassen niemals den Tap-Detentwechsel ausloesen; zeitbasierten grabberDragDetected-Reset entfernen. Bestehenden Resolver/Achsen-/Scroll-/ReduceMotion-/Landscape-Vertrag erhalten, kein AnyView/Timer-Flicken.
- VoiceOver/Accessibility bleiben echte aktivierbare Schaltflaeche + Hoehenanpassung, identische Labels. Tap schaltet weiter half/full; Ziehen folgt direkt dem Finger und rastet danach.
- UI-Nachtest erzeugt bewusst langen Abwaertsweg vom tatsaechlichen Grabberzentrum zu einem sichtbaren unteren Punkt im App-Fenster. Maximal2Versuche, dann hidden/reopen; kein X-Ersatz und keine schwaechere Assertion. Beides gesondert: kurzerDrag kehrt ohne Tap zurueck, langerDrag schliesst.
- Native Videonachtest ist Pflicht; variableCaptureRate beweist keine60FPS.

## Journey-Selektoren und Audit-Diagnose
- Memories bewahrt das ausführliche VoiceOver-Label; Test findet den Button per Label-Präfix und verwendet einen eigenen Demo-Teststore.
- Ortsbearbeitung scrollt die tatsächliche vertikale Kartenliste zurück zum bekannten QA-Ort, öffnet dessen Details und erhält Cancel/Save/Neustart/Besucht-Undo-Prüfungen. Kein Ersatz durch Map-Gesten.
- Accessibility-Meldungen sind wegen schwarzer Elementexports bislang nicht seriös einzeln zugeordnet. Alle Beschreibungen und AX-Hierarchie auch bei geworfenem Auditfehler sichern; pauschale anonyme Ausnahmen entfernen. Erst nach Zielzuordnung Produktkorrekturen planen.

## Detailaktion und Besucht-Nachweis
- Audit-Anhang zeigt App-Button „Details zu Cluster A“ mit AX-Rahmen9,7×13,7pt. PlacesDrawer setzt44pt außerhalb des Buttonlabels. Label selbst erhält44pt-Mindestfläche plus contentShape; Chevron bleibt visuell unverändert, stabile place-details-ID ergänzt. Gezielter sichtbarer UI-Nachweis prüft mindestens44×44pt.
- Ortseditor-Journey scrollt ausschließlich sein Form bis zum hittable Besucht-Switch; Screenshots und AX vor/nach Tap sichern, begrenztes Warten auf den neuen Wert. Save/Neustart/Undo bleiben obligatorisch.
- Kontrastfunde außerhalb des sichtbaren Fensters sind noch nicht visuell bestätigt; DynamicType-Funde bleiben separat zur gezielten Abnahme offen.

## FIX-DOWNLOAD-CACHE / beschädigte Bilder und PDFs
Bestätigt im aktuellen Pullpfad: Existenz allein verhindert Reparatur; Dokumente mit gleichem updatedAt erreichen Download nicht.
- Luna Sync besitzt SupabaseSync.swift und DownloadRegressionTests.swift. Injektierbarer produktiver Storage-Download, echte Bild-/PDF-Decodierungsprüfung, fehlende/leere/korrupt gecachte Dateien reparieren.
- Remoteantwort vor atomarem Austausch validieren. Ungültige Antwort darf vorhandene Bytes nicht vernichten. Neuere bzw. dirty lokale Dokumentversion nicht durch ältere Remote-Datei ersetzen; bestehende Speicherpfad-/Zugriffsprüfung erhalten.
- Regressionsprüfung: beide Medienarten missing/empty/corrupt, gleiches updatedAt PDF-Reparatur, gültiger Cache ohne erneuten Download, ungültige Antwort ohne Ersatz und lokaler Vorrang. Keine Produktionsrequests. Parent koordiniert Build allein.

## FIX-DAY-PLAN-COMMIT / Sol-Atomaritätsvertrag
- `AlbumStore.apply(proposal)` mutiert alle gültigen aktuellen frankierten Orte in einer Kopie des Store-Zustands und persistiert den vollständigen Tages-/Reihenfolge-Batch genau einmal. Veraltete, gelöschte oder nicht mehr frankierte Stops werden nicht geschrieben.
- Bei einem Schreibfehler werden `AlbumData` einschließlich `dirty` vollständig zurückgesetzt; es gibt keinen Sync. Eine unveränderte Proposal liefert `true` ohne künstliche Mutation oder Sync. Nach erfolgreichem Commit wird genau einmal synchronisiert.
- `DayPlanPreview` meldet Erfolg und dismissiert nur bei `true`; bei `false` bleibt der Entwurf geöffnet und der bestehende globale Store-Fehlerdialog bleibt zuständig.
- Regressionen in `AlbumTests/DayPlanCommitRegressionTests.swift`: erfolgreicher Persist/Relaunch, unveränderte Proposal und vollständiger Batch-Rollback bei blockierter `album.json`.

### Ergänzung: Kartenliste / Scrollkonflikt

ScreenTour besteht im Isolationslauf erstmals nach Entfernung des gebundenen scrollPosition-Modifiers. Spindumps hatten ScrollStateRequestTransform/LazyScrollable statt MapKit als Hotspot gezeigt. Finales Paket vereinheitlicht automatische Heute-Position und explizite Ortsauswahl auf ScrollViewReader, erhält einmaligen Tagesstart bei sichtbarer Liste und prüft verzögerte Scrollziele gegen aktuelle Auswahl/Filter. Abnahme: vollständiger ScreenTour mit sichtbarem Heute-Abschnitt, Kartenwahl/Listenhöhen, Pull-Gestik und große Schrift nachtestbar; kein fortlaufendes Autoscrollen beim Nutzer-Scroll. Physische Haptik separat offen.
