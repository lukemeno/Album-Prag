# QA Motion / Haptics / Accessibility Inventory

Stand: 2026-10-02. Quelleninventur aus dem aktuellen SwiftUI-Stand; keine CUA-, Simulator- oder iPhone-Abnahme. Jede Zeile braucht noch einen Lauf mit Normalfall, Abbruch/Wiederholung und Reduce Motion. Haptik ist aus Quellcode allein nicht fühlbar verifiziert.

## Bewegungs- und Haptikpfade

| ID | Datei:Zeile | Auslöser und erwarteter Ablauf | Reduce Motion laut Quelle | Erforderlicher Runtime-Fall |
|---|---|---|---|---|
| MOT-01 | `Album/AlbumRoot.swift:56,85` | Clipboard-Hinweis erscheint/verschwindet als Feder; Banner kann nach oben gewischt oder geschlossen werden. | Feder/Move entfallen, Fade/sofortiger Zustand. | Zwischenablage-Link bei Aktivierung, Einfügen, Schließen, 6-s-Auto-dismiss, Unterbrechung. |
| MOT-02 | `Album/AlbumRoot.swift:102-122` | Namens-Stempel pulsiert beim ersten Zeichen; Fokus folgt nach 600 ms. | Pulse bleibt bei 1; Fokus-Delay bleibt. | Nameprompt öffnen, sofort tippen, Reduce Motion, Rotation/Hintergrundwechsel. |
| MOT-03 | `Album/AlbumRoot.swift:175-187` | Schreibmaschinen-Schlitten folgt Text mit 40–90 ms Task-Delay und Feder. | Schlitten wird direkt gesetzt. | Schnelle Eingabe/Löschen, Fokuswechsel, Wiederstart. |
| MOT-04 | `Album/Stitch/ReiseView.swift:27-44` | Pull-to-refresh startet Sync und leichte Impact-Haptik nach Abschluss. | Keine sichtbare Motion-Gabel im Refresh-System; Haptik technisch nicht reduziert. | Mehrfaches Ziehen, Abbruch, Offline/Retry, echtes Gerät für Haptik. |
| MOT-05 | `Album/Stitch/ReiseView.swift:192,319-324` | Tageswechsel federt; horizontales Wischen wechselt einen Tag, Selection-Haptik. | Fade statt Feder, Geste bleibt aktiv. | Tap/Wisch an den Grenzen Tag 4/9, schneller Richtungswechsel, VoiceOver. |
| MOT-06 | `Album/Stitch/BoardingPass.swift:18-108` | Ticket wächst/klappt mit verzögertem Inhalt auf; Tippen/Haptik; Schließen per Chevron. | Reduced fade setzt beide Zustände gemeinsam. | Auf/Zu schnell wiederholen, Unterlagen öffnen, große Schrift, Haptik. |
| MOT-07 | `Album/Stitch/LetterSlot.swift:94,120-251` | Karte hochziehen oder Button: Einwurf, Klappe, Naht, Zettel; Fehler federt zurück; Arm-/Impact-Haptik. | Karte wird nicht gezogen; bei `keepsCardWhenReduced == false` startet `settleWithoutMotion` und blendet automatisch fertig. | Neu anlegen/speichern, VoiceOver-Aktion, Abbruch während Commit, Fehler/Retry, Reduce Motion. |
| MOT-08 | `Album/Stitch/PhotoStack.swift:21-155` | Foto horizontal wischen, halbe Geste federt zurück, Karte fliegt hinten ein; Tap/Counter öffnen/wechseln; Selection-Haptik. | Stapel zeigt nur Vorderkarte, Wechsel blendet. | Kurzer/langer/umgekehrter Wisch, vertikales Scrollkonflikt, Tap während Flug, ein Foto, Reduce Motion. |
| MOT-09 | `Album/Stitch/SyncIsland.swift:89-143` | Sync-Kapsel pulsiert, wächst bei Neuigkeit, Text folgt verzögert, schließt nach 5 s oder Tippen. | Timeline pausiert; reduced fade für Hülle. | Kurzer Sync (<500 ms), mehrere Änderungen, während Refresh unterdrückt, manueller/Auto-Schluss. |
| MOT-10 | `Album/InboxView.swift:52-121,176-318` | Ideenstapel fächert auf; Drag nach Ja/Nein/Offen, Neigung, Stempel/Herz, Fly-out; vier Haptiktrigger. | Drag-/Fly-Animationen werden zu sofortigem Store-Update; VoiceOver-Aktionen bleiben. | Langsam/schnell/kurz/Abbruch, beide Stimmen, Wiederholung/Undo, Reduce Motion, Haptikgerät. |
| MOT-11 | `Album/InboxView.swift:419-551` | Foto öffnet Vollbild und wächst; nach unten ziehen verkleinert/schließt. | Geste deaktiviert, Foto sofort groß; Escape/X schließen. | Foto öffnen, X/Escape, Pull-Abbruch/Schluss, Rotation, Dynamic Type, Reduce Motion. |
| MOT-12 | `Album/PlacesDrawer.swift:158-184,322-325,473` | Karten-Drawer per Drag zwischen hidden/collapsed/half/full; Grabber-Tap und AdjustableAction; Liste scrollt animiert zum Pin. | Drawer/list scroll ohne Animation. | Vertikal/horizontal/diagonal, Drag-Abbruch, X/Grabber gleicher Endzustand, Rotation, VoiceOver adjustable. |
| MOT-13 | `Album/TripMapView.swift:45-72,178-204` | Drawer morph; Cluster zoomt, Pin selektiert/öffnet Drawer, Liste fliegt zur Koordinate. | Animationen entfallen. | Cluster/Pin, schnelle Auswahlwechsel, Kartenbewegung bei Drawer-Drag, Landscape, Reduce Motion. |
| MOT-14 | `Album/TripMapView.swift:268-277,438-441` | Neue Pins fallen zeitversetzt, Delle/Haptik; Besuchsstempel skaliert ein. | `drops` ist false; visited nutzt reduced fade. | Neuimport mehrere Pins, Wiederstart, Kartenfilter, echtes Gerät für Haptik. |
| MOT-15 | `Album/Stitch/VisitedTrack.swift:41-89` | Besuchsspur ziehen oder tippen; Schwelle rastet, zu kurz federt zurück; Selection-Haptik. | reduced fade; Drag wird deaktiviert, Tap bleibt. | Abbruch knapp unter Schwelle, predicted-end, Tap/VoiceOver, Undo im Editor. |
| MOT-16 | `Album/PlaceEditor.swift:191-212` | Quellenanreicherung wartet 500 ms; beim neuen Speichern erscheint LetterSlot mit Fade. | LetterSlot behandelt den Einwurf ohne Geste. | Schnelles Abbrechen während Enrichment, veraltete Anfrage, Save/Cancel, Reduce Motion. |
| MOT-17 | `Album/DayPlanPreview.swift:75`, `Album/Stitch/TripDataViews.swift:150` | Anwenden meldet Success-Haptik. | Keine eigene Reduce-Motion-Gabel. | Vorschlag anwenden/abbrechen/wiederholen, echtes Gerät. |
| MOT-18 | `Album/Stitch/InvitationMoment.swift:16`, `Album/AlbumStore.swift:229` | Einladungs-/Sync-Abläufe haben 1.2 s bzw. 1 s Task-Delay. | Keine Motion-Gabel im Delay. | Einladung Erfolg/Fehler/Retry, Szene verlassen, Offline. |

## Accessibility- und Dynamic-Type-Risiken

- `ReiseView.swift:321` legt eine globale `DragGesture` auf den Tagesstreifen. Die Tiles haben zwar Buttons und Labels, aber der Container selbst bietet keine benannte VoiceOver-Aktion für „nächster/vorheriger Tag“; prüfen, ob der Container die Kinder-Aktivierung überschattet.
- `PhotoStack.swift:50,113` ist Wischen für Blättern; Counter und `accessibilityAction(named: "Nächstes Foto")` sind Alternativen. Der übergeordnete Tap öffnet das Foto; Runtime prüfen, ob Counter/Foto-Aktion doppelt feuern.
- `PlacesDrawer.swift:322-325` ist der einzige Höhen-Drag, hat aber AdjustableAction. Die eigentliche Liste ist bei kleinem Drawer per `.accessibilityHidden` verborgen; prüfen, ob der Zugriff nach Rotation wieder sichtbar wird.
- `InboxView.swift:77,201-218` hat Ja/Nein/Offen-AccessibilityActions und sichtbare Buttons; die Karten-Geste ist daher nicht der einzige Bedienweg. Prüfen, dass Actions nicht wegen `.allowsHitTesting(!committing)` verschwinden.
- `LetterSlot.swift:94,158` hat eine benannte AccessibilityAction und CTA; bei Reduce Motion wird die Karte entfernt/automatisch abgeschlossen. Prüfen, dass VoiceOver den CTA vor dem Autoabschluss noch erreicht.
- `InboxView.swift:504,532` (verschachtelter `PhotoViewer`) deaktiviert Drag bei Reduce Motion, bietet X und Escape. Prüfen, dass X bei sehr großer Schrift nicht außerhalb der Safe Area liegt.
- `VisitedTrack.swift:48-52` hat Tap und VoiceOver-Aktion neben Drag. `label(p:)` nutzt `fixedSize` vertikal, was bei sehr großen Größen die feste Track-Höhe (`@ScaledMetric`) überlaufen lassen kann.
- `BoardingPass.swift:104-108` verwendet feste Layoutwerte und `Stitch.Face.display(36)` in der geöffneten Karte; mit Accessibility Dynamic Type auf Überlauf/Abschneiden prüfen.
- `PlacesDrawer.swift:208-218` verzweigt bei Accessibility Dynamic Type, aber `wide`/Detents bleiben 244/360/420/480 pt; lange Titel, Filter und deutsche Labels auf Clipping prüfen.
- `ReiseView.swift:318` setzt bei Accessibility Dynamic Type eine nil-Höhe für den Tagesstreifen; die umgebende ScrollView muss die horizontale Scrollfläche trotzdem korrekt messen.
- `TripMapView.swift:139` beschreibt die Karte, aber einzelne normale Pins verlassen sich auf die innere `StampPin`-Beschriftung (`:282`); Cluster hat Label. Runtime mit VoiceOver auf Pin-Titel, Kategorie und Auswahlwert prüfen.
- `CollectionViews.swift:127` schaltet bei Accessibility-Größe Layout um; Kommentar-/Herz-/Ort-Aktionen und `ellipsis.circle` auf 44-pt-Ziel, Reflow und abgeschnittene URLs prüfen.
- `PlaceEditor.swift:148-174` ersetzt Toolbar durch Safe-Area-Fußzeile bei Accessibility-Größe; lange Validierungs-/Fehlermeldungen und Tastatur müssen die Speichern-Schaltfläche nicht verdecken.

## Quellbefunde: Beweisstatus

**Bestätigt aus Quelle (kein Runtime-Bug):** Es existieren 18 getrennte Motion-/Haptikpfade; Haptik wird an mindestens 13 Triggern über `.sensoryFeedback` ausgelöst. Mehrere Animationen sind bewusst Reduce-Motion-gated, aber nicht alle: insbesondere `LetterSlot`-Stage/Failure (`:133-136`), `SyncIsland.close()` (`:142`) und `VisitedTrack`-Label (`:63`) animieren auch im Reduced-Motion-Zweig. Das ist ein prüfbarer Quellbefund, die Nutzerwirkung bleibt offen.

**Intent-Prüffall, kein bestätigter Defekt:** `LetterSlot` blendet unter Reduce Motion bei `keepsCardWhenReduced == false` ohne Nutzerzug automatisch in `.done` und ruft bei `autoFinish` anschließend `onFinished` auf (`:145`, `:229-246`). Das kann bei Einwurf/Einladung den Dialog schließen, bevor der Nutzer die CTA bewusst bedient; die Aufrufer können dieses Auto-Finish aber absichtlich konfigurieren. Auf Gerät mit Reduce Motion und jedem Caller separat als Produktentscheidung prüfen.

**Ungetestete Hypothesen:** Haptik-Mehrfachauslösung bei schneller Wiederholung (`InboxView`, `TripMapView`, `LetterSlot`); Tap-/Drag-Gesten-Konflikte in `PhotoStack`, `FlightTicket`, `PlacesDrawer`; Clipping bei Dynamic Type in `BoardingPass`, `VisitedTrack`, Drawer und Collection. Ein ruhiger Screenshot oder grüner Build belegt keinen dieser Punkte.

## Abdeckungslücken für die Abnahme

Es fehlen in diesem Quellinventar echte Messungen für FPS/Interruptions/Endzustände, Reduce Motion, Transparency/Contrast, Dynamic Type bis Accessibility, Rotation während Drag, VoiceOver-Reihenfolge und physische Haptik. Die vorhandenen UI-Tests terminieren Motion-Aufnahmen mit festen `asyncAfter`-Werten, sind aber kein Beweis für eine laufende Animation oder fühlbare Haptik.

## Nächste Runtime-Gates

Die bisherigen Belege decken überwiegend den normalen Simulatorzustand ab: `work/full-fix-retest-summary.json` meldet 30 grüne Tests, und die vorhandenen Motion-/Journey-Läufe enthalten keinen systemweiten Reduce-Motion- oder Large-Type-Lauf. Für isolierte DEBUG-Motionläufe kann der Runner `ALBUM_QA_REDUCE_MOTION=1` setzen; die App setzt dann nur unter `ALBUM_TEST_STORE` die SwiftUI-Umgebung und der Root bestätigt sie über eine technische QA-ID. Das ist ein SwiftUI-Umgebungstest, kein Nachweis der echten OS-Einstellung; die OS-Abnahme bleibt offen. Die folgenden fünf Gates sind deshalb die wichtigsten noch offenen Interaktionen; Quellenbefund oder ein grüner Normalfall wird hier nicht als Abnahme gewertet.

1. **Reduce Motion über die wichtigsten Geste-/Auto-Finish-Pfade** (`MOT-07`, `MOT-08`, `MOT-10`, `MOT-11`, `MOT-15`). Im Simulator „Bewegung reduzieren“ aktivieren, einen isolierten Store starten und nacheinander LetterSlot-Einwurf (inklusive Abbruch), Foto-Stapel mit kurzem/langem/umgekehrtem Wisch, Inbox-Aktion mit VoiceOver-Alternative, Erinnerungsfoto öffnen/schließen und `Besucht-Spur` per Tap/VoiceOver ausführen. Dabei jeweils prüfen: Endzustand wird ohne sichtbare Zwischenanimation erreicht, CTA bleibt erreichbar, kein Auto-Finish schließt den Dialog vor der beabsichtigten Aktion. Wiederholen mit deaktivierter Einstellung im selben Ablauf. Der aktuelle `AlbumMotionUITests`-Lauf beweist nur Normalbewegung.

2. **Accessibility Large Type mit realem System-Content-Size** (`BoardingPass`, `PlacesDrawer`, `VisitedTrack`, `CollectionViews`, `PlaceEditor`). Vor dem Lauf über `simctl` die größte praktikable Accessibility-Schriftgröße setzen, App mit eigenem Store starten, Reise-Tagesstreifen, geöffnete Bordkarte, Kartenliste mit Filter, Ortseditor inklusive Tastatur und Sammlung öffnen. Konkrete Akzeptanz: keine Pflichtaktion außerhalb des sichtbaren Fensters, keine abgeschnittene Validierung/URL, mindestens 44-pt-Ziele bleiben hittable, Rückkehr nach Portrait/Landscape funktioniert. Danach Content-Size zurücksetzen. Die vorhandenen Accessibility-Audit-Hinweise und `Dynamic Type`-Befunde sind Diagnosematerial, kein bestandener Large-Type-Lauf.

3. **Erinnerungs-PhotoViewer: Wischen und verschachteltes Schließen** (`NAV-10`, `MOT-11`). Mit `ALBUM_DEMO_MEMORIES=1` den Reise-Rückblick öffnen, ein Stapelfoto antippen, im Vollbild einen kurzen Wisch abbrechen und einen vollständigen vertikalen Schließwisch ausführen; danach erneut öffnen, X/Escape verwenden, in beide Landscape-Richtungen drehen und zur Ortsdetailansicht zurückkehren. Der aktuelle Populated-Memories-Test belegt Fotoöffnung, Counter, Rotation und X; `AlbumMotionUITests.testPhotoStack` prüft Wischen an einem Ortsdetail. Der konkrete Memories-Viewer-Wisch ist damit noch nicht runtimegeprüft.

4. **Share-Extension-/Einladungsübergang** (`NAV-01`, `NAV-11`, `MOT-18`). Einen realen Share-Extension-Aufruf mit URL/Text an den isolierten Store senden, Extension abbrechen und erneut mit gültigem Inhalt bestätigen; anschließend in der App Inbox/Sammlung öffnen, Offline-Queue prüfen, App terminieren/relaunch durchführen und denselben Eintrag ohne Doppelung öffnen. Danach Fehler/Retry und Szenewechsel während des 1-s/1,2-s Delays ausführen. Es gibt derzeit keinen entsprechenden UI-Runtimebeleg; die vorhandenen Sammlungstests prüfen lokalen Offline-Post, Kommentar, Herz und Neustart, keine Share-Extension.

5. **Sammlung-Realtime und Konfliktauflösung** (`NAV-11`, `TASK-07`, `HAP-14`). Zwei isolierte Teilnehmer mit demselben Trip öffnen, einen Post, Kommentar und Herz in Teilnehmer A erzeugen, während B sichtbar ist; B muss nach Realtime-Update genau eine Zeile erhalten. Anschließend gleichzeitige Textänderung, stale Update/Retry, App-Hintergrund und Wiederaufnahme prüfen; Ergebnis muss eine deterministische Version ohne doppelte Reaktionen und mit sichtbarem Offline-Queue-Zustand sein. `AlbumTests/CollectionTests.swift` und `SyncRegressionTests.swift` liefern Store-/Transportbelege, `CollectionUITests` nur Offline-Neustart; die echte Zwei-Prozess-UI-Realtime-Kette ist offen.

## Präsentation, Navigation und Dismissal

| ID | Datei:Zeile | Präsentationspfad / Zustandswechsel | Runtime-Fall |
|---|---|---|---|
| NAV-01 | `Album/AlbumApp.swift:53-54` | Deep-Link-Einladung öffnet `InvitationMoment` als Full-Screen-Cover; Abschluss setzt `invitation = nil`. | Einladung-Link öffnen, Erfolg/Fehler/Retry, Swipe-Dismiss deaktiviert?, Hintergrundwechsel. |
| NAV-02 | `Album/AlbumRoot.swift:62-66` | Reise öffnet PlaceEditor, AlbumSettings, TripDocuments, NamePrompt und ExtractedTripSheet als Sheets. | Jeden Sheet öffnen/schließen, verschachtelte Sheets, interaktives Dismiss, Rotation/Dynamic Type. |
| NAV-03 | `Album/AlbumRoot.swift:46-53` | Reise öffnet PlaceDetail und Erinnerungen; Memories callback schließt zuerst und wechselt zur Karte. | Detail → Editor → zurück, Erinnerungen → Ort/Fotobetrachter → schließen, callback zur Karte. |
| NAV-04 | `Album/AlbumRoot.swift:97-126` | NamePrompt large detent, interaktives Dismiss deaktiviert; Fokus startet nach 600 ms. | Sofortige Eingabe, Tastatur/Rotation, Reduce Motion, Save/Validation. |
| NAV-05 | `Album/InboxView.swift:117-124` | Ideen-Editor als Sheet; Foto als Full-Screen-Cover. | Editor Save/Cancel mit LetterSlot, Foto X/Escape/Pull, Cover während Store-Update. |
| NAV-06 | `Album/TripMapView.swift:78,415-416` | Karten-Detail sheet; Detail wiederum Editor sheet oder PhotoViewer full-screen. | Map → Detail → Editor/Viewer, Dismiss nach Löschung, Auswahlzustand behalten. |
| NAV-07 | `Album/Stitch/ReiseView.swift:51-52` | Tagesort-Detail und Erinnerungen-Sheet. | Tageswechsel während Sheet, Detail dismiss, Memories callback. |
| NAV-08 | `Album/PlacesDrawer.swift:111` | Drawer öffnet DayPlanPreview-Sheet; `editing` fährt Drawer vorher full. | Vorschlag öffnen/abbrechen/anwenden, Drawer-Detent danach, Rotation. |
| NAV-09 | `Album/TripDocumentsView.swift:108-110` | PDF-Import/„Auslesen“ öffnet Extraction-Sheet; Dokument öffnet Detail-Sheet; TripEditor sheet. | Ungültiges PDF, Extraction abbrechen/anwenden, PDF Original/Text umschalten, verschachtelte Editor-Schließung. |
| NAV-10 | `Album/Stitch/TripMemoriesView.swift:70-72` | Erinnerung öffnet PlaceDetail oder PhotoViewer full-screen; Fertig liegt Toolbar bzw. Accessibility-Footer. | Großtext-Footer, Foto-Stack/Viewer, Ort zurück, Cover schließen. |
| NAV-11 | `Album/CollectionViews.swift:34-35,175-180` | Sammlung öffnet Composer/Detail; Detail öffnet PlaceEditor und PlaceDetail. | Composer Save/Cancel/Fehler, Detail löschen, verschachtelte PlaceEditor/Detail, Offline-Queue. |
| NAV-12 | `Album/PlaceEditor.swift:145-196` | ImagePicker sheet und LetterSlot overlay; ConfirmationDialog für Löschen. | Bildauswahl abbrechen/veraltet, Delete-Abbruch, Save während Enrichment, Reduce Motion. |

### Reduced-Motion-Testzweige

`AlbumMotionUITests` nutzt bei `ALBUM_QA_REDUCE_MOTION=1` ausschließlich die vom Produkt vorgesehenen Bedienalternativen: Der PhotoStack blättert über `Foto-Zähler` zyklisch weiter, `Besucht-Spur` wird per Tap aktiviert, und der Invitation-Slot nutzt den sichtbaren Button „Einladung einlösen“ für den ersten Fehler- und den anschließenden Retry-Pfad. Die App bestätigt in diesem isolierten DEBUG-Umgebungstest, dass SwiftUI `accessibilityReduceMotion` im Root liest. Das ersetzt keine echte OS-Reduce-Motion-Abnahme; diese bleibt offen.

## Vollständige sensoryFeedback-Trigger

| ID | Datei:Zeile | Trigger / Bedingung | Debounce-/Mehrfachrisiko |
|---|---|---|---|
| HAP-01 | `ReiseView.swift:44` | `refreshed += 1` nach `await store.sync()` | Wiederholtes Pull-to-refresh erzeugt pro Abschluss einen Impact. |
| HAP-02 | `ReiseView.swift:320` | Tagesauswahl `selection` ändert sich per Tap/Wisch | Schnelle Richtungswechsel können jeden Zwischenwert taktil melden. |
| HAP-03 | `LetterSlot.swift:140` | Drag überschreitet Arm-Schwelle (`armTick`) | Arm/disarm bei wiederholtem Drag; auch VoiceOver-CTA separat testen. |
| HAP-04 | `LetterSlot.swift:141` | Einwurf erreicht Klappenphase (`clack`) | Commit/Animation-Abbruch darf keinen doppelten Clack erzeugen. |
| HAP-05 | `BoardingPass.swift:26` | Ticket-Tap (`toggles`) | Schnelles Auf/Zu kann mehrere Impacts stapeln. |
| HAP-06 | `TripDataViews.swift:150` | Daten anwenden (`applied`) | Wiederholtes Anwenden/Fehlerpfad. |
| HAP-07 | `PhotoStack.swift:53` | Foto weiterblättern (`flip`) | Counter, AccessibilityAction und Swipe können konkurrieren. |
| HAP-08 | `VisitedTrack.swift:46` | Schwelle/Tap erhöht `tick` | Schwellen-Haptik plus `fill()`-Haptik kann doppelt feuern. |
| HAP-09 | `TripMapView.swift:269` | Pin landet nach Drop (`landedTick`) | Mehrere neue Pins, `onAppear`/Re-render und stabile `landed`-Persistenz. |
| HAP-10 | `DayPlanPreview.swift:75` | Plan anwenden (`applied`) | Doppeltippen während Apply. |
| HAP-11 | `InboxView.swift:118` | Entscheidung/Undo (`feedback`) | Button, VoiceOver und Drag können dasselbe Ereignis mehrfach auslösen. |
| HAP-12 | `InboxView.swift:119` | Drag überschreitet Ja/Nein/Offen-Schwelle (`thresholdFeedback`) | Schwelle kann bei Hin-und-her mehrfach überschritten werden. |
| HAP-13 | `InboxView.swift:120` | Stempel landet (`stampTick`) | Animation completion nach Unterbrechung/Ansichtswechsel. |
| HAP-14 | `InboxView.swift:121` | Beide stimmen zu (`magnetTick`) | Wiederholte Sync/Approval-Updates. |
| HAP-15 | `AlbumRoot.swift:231` | Clipboard-Banner erscheint (`appeared`) | Banner-Recreation kann Trigger erneut auslösen. |

Die Trigger sind aus dem Quelltext vollständig erfasst; `.sensoryFeedback` selbst ist ohne physisches iPhone kein Beweis für Intensität, Timing oder tatsächliche Geräteausgabe. Für jeden HAP-Fall sind Normalfall, schnelle Wiederholung, Unterbrechung und Reduce Motion zu prüfen.

## Kartenstatus und Aktionen

| ID | Quelle | Zustand/Aktion | Runtime-Fall |
|---|---|---|---|
| MAP-01 | `TripMapView.swift:6-20,130-150` | Kamera startet Prag-Region, wird einmal automatisch auf sichtbare Orte gefittet; MapCameraChange aktualisiert `visibleRegion`. | Keine Orte, ein Ort, mehrere Orte, Reload nach Filter/Sync, Rotation. |
| MAP-02 | `TripMapView.swift:101-126` | Einzel-Pin selektiert Ort; Cluster zoomt anhand aktueller Region; Landed-Pins persistieren in AppStorage. | Cluster nach Filter, Pin direkt danach, Neustart mit bereits gelandeten Pins, falsche Auswahl. |
| MAP-03 | `TripMapView.swift:178-204` | `zoom`, `select`, `show` ändern Kamera, Selection-Request und Drawer-Detent. | Pin → Liste, Liste → Pin, Full/Collapsed/Hidden, schnelle Gegenaktionen. |
| MAP-04 | `PlacesDrawer.swift:164-205` | Achsen-Lock unterscheidet Landscape-Horizontal und Portrait-Vertikal; `DrawerDetentResolver` nutzt begrenzten Schwung. | Diagonaler Drag, kurzer Drag, Umkehr mitten im Ziehen, Rotation während Drag, X vs. Grabber. |
| MAP-05 | `PlacesDrawer.swift:344-357,455-468` | Filterchips setzen Kategorie; Auswahl scrollt per Request animiert zum Listeneintrag. | Filter entfernt selektierten Ort, mehrfacher Request, VoiceOver, Reduce Motion. |
| MAP-06 | `PlacesDrawer.swift:207-285` | Accessibility Dynamic Type stellt Header-Aktionen vertikal um; Editing fährt automatisch auf full. | Großtext, Bearbeiten/Sortieren, Sheet DayPlanPreview, zurück zu normalem Drawer. |

## Initiale Tasks, Delays und Re-Render-Fallen

| ID | Quelle | Initial-/Änderungs-Task | Runtime-Fall |
|---|---|---|---|
| TASK-01 | `AlbumApp.swift:30,63` | App-Aktivierung und initialer Task drain/sync/refresh; keine Ausführung im isolierten XCTest-Store. | Kaltstart, Hintergrund → aktiv, Offline, doppelter Sync. |
| TASK-02 | `AlbumRoot.swift:67-71,120,232-235` | Pasteboard-Prüfung bei Aktivierung; NamePrompt fokussiert nach 600 ms; Clipboard-Banner dismiss nach 6 s. | Sheet-Wechsel genau während Delay, mehrfach aktiv/inaktiv, Reduce Motion. |
| TASK-03 | `PlaceEditor.swift:185-196` | `task(id: sourceURL)` invalidiert und reichert nach 500 ms an; onDisappear cancelt Search. | URL schnell ändern, Editor schließen, veraltete Antwort, Save während Task. |
| TASK-04 | `LetterSlot.swift:142-147,251` | Szene resigniert Keyboard; Flow läuft bis Commit/Fertig, onDisappear cancelt Flow; Pausen sind Task.sleep. | View während Commit verlassen, Fehler/Retry, Reduce Motion/AutoFinish. |
| TASK-05 | `SyncIsland.swift:95-108,132-135` | Pulse erst nach 500 ms sichtbar; Collapse nach 5 s; suppressed/pending verschiebt Open. | Kurzer Sync, mehrere Änderungen, Ansicht verlassen, Background. |
| TASK-06 | `InboxView.swift:122-123,176-181,249-251,300-314` | Stack spread bei appear/oberster Karte; Tilt decay 300 ms; Stamp/Magnet/Fly delays. | Schnelles Entscheiden, neue Karte während Flug, Undo, Background. |
| TASK-07 | `DayPlanPreview.swift:71`, `CollectionViews.swift:241-242` | Keep-assigned/reload Tasks und Queue-Revision reagieren auf Store-Änderungen. | Wiederholtes Anwenden, Offline-Queue, Sheet schließen während Reload. |
| TASK-08 | `Design.swift:43,69` | Bild-Lade-Tasks sind asset/key-identifiziert und ändern Preview/Fallback. | Asset wechseln, fehlendes Bild, View-Reuse, Reduce Motion irrelevant aber Ladewechsel prüfen. |

## Priorisierte Runtime-Lücken nach Artefaktabgleich

Die fünf `AlbumMotionUITests` (`testInvitationMoment`, `testSyncIsland`,
`testPhotoStack`, `testBoardingPass`, `testVisitedTrack`) liefen im normalen
Simulatorlauf `89293` grün. Der Reduce-Motion-Marker fehlte dort; diese fünf
Pfade sind deshalb nur als Normalfall belegt. `full-unit-postfix` meldet 103
Tests aus `AlbumTests` bestanden, ersetzt aber keine der folgenden Motion-Gates.

| Priorität | Pfade ohne belastbaren Runtime-Nachweis | Minimaler nächster UI-Lauf und Fixture |
|---|---|---|
| P0 | **Reduce Motion für MOT-07/08/10/11/15**: keine gültige Abnahme trotz vorhandener Testzweige; der Marker `qa-reduce-motion-root` war im Lauf nicht nachweisbar. | Dieselben fünf `AlbumMotionUITests` mit nachgewiesener `ALBUM_QA_REDUCE_MOTION=1`-Runner-Umgebung und `slot-motion-*`; zusätzlich echte OS-Einstellung separat. Erwartet werden Counter-/Tap-/VoiceOver-Ersatzbedienung und kein vorzeitiges Auto-Finish. |
| P0 | **MOT-11/NAV-10 Erinnerungs-PhotoViewer-Wisch**: `testMemoriesJourneyRotatesAndDismisses` belegt nur Öffnen, Rotation und `Fertig`; `testPhotoStack` prüft einen Ortsdetail-Viewer, nicht den Erinnerungs-Viewer. | `FullJourneyUITests.testMemoriesJourneyRotatesAndDismisses` um ein Demo-Foto (`ALBUM_DEMO_MEMORIES=1`, sechs-Orte-Store) erweitern: kurzer Pull-Abbruch, vollständiger Pull-Schluss, danach X/Escape und Rückkehr zur Reise. |
| P0 | **MOT-18/NAV-01 Share-Extension-/Einladungsübergang**: `testInvitationMoment` deckt den simulierten Slot ab, kein echter Extension-Aufruf/Queue-Recovery-Lauf. | Isolierter `slot-share-*`-Store plus signierte Share-Extension: URL/Text abbrechen, gültig bestätigen, App relaunchen, Queue ohne Doppelung prüfen; danach Fehler/Retry und Szenewechsel während der Delays. |
| P1 | **MOT-16/TASK-03 Bildsuche-Abbruch**: `testCancelDelayedPlaceImageSearch` existiert, der aktuelle Late-Resolver-/12-s-Async-Nachweis ist laut `QA-FULL-STATUS` noch nicht gelaufen. | Der bestehende Test mit `slot-*` und kontrolliert verspätetem Resolver muss nach dem neuen Runtime-Marker laufen; Editor während `await` schließen und Datei/State auf unverändert prüfen. Native PhotosPicker bleibt eigener Gate. |
| P1 | **MOT-01 bis MOT-03 Clipboard-/NamePrompt-Delays**: kein belastbarer Lauf für Pasteboard-Banner, 600-ms-Fokus und Typewriter-Schlitten; `testNamePromptStitch` prüft den normalen Prompt, nicht Timing/Unterbrechung. | Kleiner `slot-name-*`-UI-Test mit Clipboard-Link: Aktivierung, sofortige Eingabe, Banner schließen/Auto-dismiss, Fokuswechsel und Relauch; Rotation und Reduce Motion als Wiederholung. |
| P1 | **MOT-04/05 Refresh und Tagesstreifen-Geste**: `testSelectTravelDay` belegt Auswahl per Control, nicht horizontales Wischen an Tag-4/9-Grenzen oder Pull-to-refresh-Abbruch/Offline. | `qa-full-plan`-Fixture mit sechs Tagen: gerichtete Links-/Rechtszüge an beiden Grenzen, schneller Richtungswechsel und Pull-to-refresh online/offline; Tageslabel und Sync-Endzustand assertieren. |
| P1 | **MOT-13/MAP-01 Karten-Übergang nach Kamera-Fix**: Drawer-/Cluster-Normalfälle haben Video-/UI-Belege, aber ScreenTour hängt weiterhin beim Grabber-Übergang; Reduce Motion, VoiceOver-Adjustable und Pin-Drop (MOT-14) sind nicht vollständig belegt. | Ein gezielter Map-Lauf mit der sechs-Orte-Fixture: `Liste ausklappen`, Drawer-Drag/Close/Reopen, Cluster → Mitglied → Pin, Filterwechsel und Reload; `ALBUM_QA_REDUCE_MOTION=1` als separater Lauf. |
| P2 | **Physische Haptik HAP-01…15**: kein Simulator-/Quelltest beweist fühlbare Ausgabe oder Timing. | Bestehende Normal-/Reduce-Motion-Flows auf einem signierten iPhone mit denselben isolierten Fixtures wiederholen und pro Trigger nur Auftreten/Mehrfachauslösung protokollieren; keine Simulatorpassage als Haptikbeleg werten. |

### Aktualisierung: belegter SwiftUI-Reduce-Motion-Lauf

Lauf95180 (`Album-fqxrofgafpxoqwflvwaovjajrshr/Logs/Test/Test-Album QA-2026.10.02_22-45-18-+0200.xcresult`) besteht mit fünf Tests, ohne Fehler oder Skips. Alle fünf Startmarker belegen `ALBUM_QA_REDUCE_MOTION=1`; alle fünf Activities prüfen erfolgreich `qa-reduce-motion-root`. Die fünf oben genannten Flows sind damit für die reduzierte SwiftUI-Umgebung belegt. Die frühere P0-Zeile bleibt historischer Stand; echte iOS-Systemeinstellung und physische Haptik bleiben offen. Artefakte: `outputs/reduced-motion-explicit-runner-media` im Chat-Arbeitsverzeichnis.

### Memory-Photo-Pull: Runtime und Video

Der Lauf work/hours-memory-regressions.xcresult besteht mit12Tests/0Fehlern/0Skips, darunter kurzer60ptPullbleibtoffen,220ptPullschließt,XundverschachtelteOrtrückkehr. Luna hat den26,78sClip outputs/hours-memory-media/7E6C058A-CEE7-4D1C-8830-226D99E1690A.mp4 geprüft: Bild skaliert/verschiebt sich über der Memory-Ansicht, anschließend stabiler Zustand ohne sichtbare Layerreste oder dauerndes Overlay. Codierte Aufnahme ca23,9fps; weder60FPS-LaufzeitnochphysischeHaptikdamitbelegt.
