# Journey-UI-Abnahme

Stand: 2026-10-02. `AlbumUITests/FullJourneyUITests.swift` ergänzt die vorhandenen Einzel- und Motion-Tests um fünf echte UI-Journeys über verschachtelte Sheets, Tastatur, Rotation und Large Type. Die Tests schreiben ausschließlich unter `Application Support/AlbumUITests/<slot>/`; `ALBUM_TEST_STORE` verhindert beim App-Start echten Sync und Bildabrufe.

## Laufvoraussetzungen

Der Parent muss zuerst die Fixture mit `QA/prepare-fixtures.py --store slot-full-plan --pdf` im Simulator-App-Container erzeugen und für diese Tests `ALBUM_JOURNEY_STORE=slot-full-plan` setzen. Ein Build oder Lauf wurde in diesem Auftrag nicht gestartet. Die Testdatei muss außerdem in das `AlbumUITests`-Target aufgenommen werden, falls die Xcode-Projektdatei die neue Quelldatei nicht automatisch über die bestehende Projektgenerierung erfasst.

Für `testLargeTypeMapAndEditorJourney` setzt der Parent vor dem Lauf die tatsächliche Simulator-Schriftgröße (Accessibility Extra Extra Extra Large). Der Test setzt diese Systemeinstellung nicht selbst, öffnet keine Fotos und benötigt keine Netzwerkdaten.

`testMemoriesJourneyRotatesAndDismisses` aktiviert die Demo-Daten ausschließlich für diesen Test in einem pro Lauf erzeugten `slot-journey-memories-*`-Store. Die übrigen Journeys starten explizit auf dem Reise-Tab ohne Demo-Erinnerungsorte. Das Reisedaten-Notizfeld trägt im aktuellen Editor den stabilen AX-Identifier `TripEditor-Notes`; der Journey-Test verwendet diesen Identifier, weil ein gefülltes Textfeld seinen Placeholder nicht als Label exponiert. Die Kartenreise verwendet die benannte `map-places-list`-ScrollView und scrollt begrenzt zurück, weil der Startabschnitt auf den heutigen Tag springt und `qa-oldtown` davor liegt.

## Abdeckung

| Test | Ablauf und Beweis | Abgrenzung |
| --- | --- | --- |
| `testTravelDocumentsEditCancelSaveAndNestedDismissalAcrossOrientations` | Reise → Unterlagen; Flug-/Hotel-/Reisenden-/Buchungsdaten sichtbar; Unterlagen in Portrait, Landscape Left und Landscape Right; Reisedaten-Sheet mit Tastatur öffnen, abbrechen und den Originalwert nach erneutem Öffnen prüfen; erneut ändern, speichern und den Wert nach Relaunch prüfen; äußeres Sheet schließen. | Der lokale PDF-Importer ist ein System-File-Importer und kann aus XCTest ohne sichere Dateiauswahl nicht zuverlässig eine konkrete lokale Datei injizieren. `qa-valid-booking.pdf` ist eine synthetische QA-Datei ohne echte Buchungsdaten und darf deshalb nicht als `ALBUM_SAMPLE_PDF` für das echte Booking-Gate verwendet werden. |
| `testPlaceEditorCancelSaveAndExplicitVisitedUndoThroughNestedSheets` | Karte → die konkrete Fixture-Zeile `place-row-qa-oldtown` (Altstädter Ring) → Editor; Originaltitel lesen, Titel per Tastatur ändern und abbrechen, Originalwert nach erneutem Öffnen prüfen; das benannte Editor-Formular bis zum äußeren gelabelten `Schon besucht`-Switch scrollen, daraus genau den verschachtelten echten Switch prüfen (Hittability und Rahmen innerhalb der Zeile), Screenshot/AX vor/nach dem Tap sichern, aktivieren, über `Besucht-Spur` speichern und denselben Ort nach Relaunch prüfen; Formular erneut scrollen, den inneren Switch deaktivieren und `Besucht-Spur` auf „Als besucht markieren“ prüfen. | Keine beliebige `Details zu`-Auswahl, keine direkte Datenmutation und kein impliziter „Undo“-Tap: der Rückweg wird ausschließlich über den echten verschachtelten Switch, begrenztes AX-Warten sowie äußeren und inneren AX-Zustand verifiziert. |
| `testMemoriesJourneyRotatesAndDismisses` | Populierte Nach-Reise-Reise → Erinnerungen; Rückblick in beiden Landscape-Richtungen und Portrait; `Fertig` schließt das Sheet. | Demo-Fixture muss beim Prozessstart aktiviert sein. Der leere Erinnerungszustand mit `Karte öffnen` bleibt durch den bestehenden `testAfterTripOpensMemoriesAndReturnsToMap` abgedeckt; Foto-Viewer-/Stack-Gesten bleiben durch die vorhandenen Memories-Tests abgedeckt. |
| `testMemoriesPhotoPullAndNestedReturn` | Eindeutiger Demo-Erinnerungsstore → Letná-Fotostapel → Vollbild; im Normalzweig kurzer langsamer 60-pt-Pull mit Screenshot/AX vor und nach dem Zurückfedern, danach 220-pt-Pull zum Schließen; X separat erneut prüfen; `Ort ansehen: Letná` öffnen, verschachteltes Ortsdetail mit `Schließen` verlassen und das Erinnerungs-Sheet mit `Fertig` beenden. Bei `ALBUM_QA_REDUCE_MOTION=1` ersetzt X den deaktivierten Pull. | Keine Rotationsduplikation und keine direkte Zustandsmutation. Der Test beweist die Memories-Viewer-Geste und den verschachtelten Rückweg; der bestehende Populated-Memories-Test behält den Viewer-Rotationsnachweis. |
| `testLargeTypeMapAndEditorJourney` | Mit systemweiter Accessibility-Schriftgröße: Kartenliste öffnen, Drawer-Header (`Tage planen`, `Ordnen`, `Liste schließen`) in Portrait/Landscape links/rechts/zurück auf Hittability und mindestens 44pt prüfen; gezielt zur `qa-oldtown`-Zeile scrollen, lesbaren Titel/Metadaten prüfen, Details → Editor öffnen und abbrechen. Jede Orientierung erhält AX- und KeepAlways-Screenshot-Anhang; der Editor verwendet den Identifier und bei fehlendem runtime-AX-Identifier den eindeutigen sichtbaren Button `Abbrechen`. | Der Test prüft die aktuelle UI-Geometrie und Interaktion, keine Pixelgleichheit. Die tatsächliche Simulator-Schriftgröße wird extern gesetzt; ein Normalgrößenlauf ersetzt diesen Gate nicht. |

## Offene Punkte und bekannte Quellenrisiken

- Es gibt keinen neuen Laufnachweis. Ergebnisse dürfen erst nach Parent-Build und Simulatorlauf in `QA-FULL-STATUS.md` eingetragen werden; Parse-Erfolg der Swift-Datei ist kein Runtime-Erfolg.
- Für die Dokumentenreise bleibt der echte PDF-Import-/Extraktions-/Abbruchpfad ein separates offenes Gate: Die synthetische `qa-valid-booking.pdf` darf dafür nicht über `ALBUM_SAMPLE_PDF` eingesetzt werden. Dieser Journey-Test prüft deshalb die bereits vorhandenen Reiseinformationen und die verschachtelte Editor-Navigation; ein Runtimebeweis des echten Booking-Gates steht separat aus.
- Rotation prüft Fenstergeometrie und erreichbare aktuelle Controls, keine Pixelgleichheit und keine Haptik. Haptik, VoiceOver-Reihenfolge und echte PDF-Systemauswahl bleiben gesonderte Geräte-/CUA-Gates.

## Tagesplan und Rundgang

### Fixture-Wahrheit

`QA/prepare-fixtures.py` erzeugt für den Tageswechsel sechs Orte: Tag 4 enthält `qa-oldtown` (Altstädter Ring) und `qa-letna` (Letná), Tag 5 `qa-cafe` (Café Savoy), Tag 6 `qa-castle` (Prager Burg) und Tag 7 `qa-cluster-a` sowie `qa-cluster-b`. Eine Prüfung „Tag 4 ist leer“ wäre daher eine falsche Testannahme; fehlende Fixture-Daten sind für diesen Ablauf nicht der Grund, den Test zu überspringen.

### Minimaler Fixplan für `testSelectTravelDay`

1. Vor `launch()` `ALBUM_START_TAB = "Reise"`, `ALBUM_TODAY = "2026-10-06"`, `ALBUM_TEST_STORE` und `ALBUM_MY_NAME` setzen. Dadurch startet der Test deterministisch auf der Reiseansicht und markiert Tag 6 als heute.
2. Die Day-Card über ihr aktuelles AX-Label wählen: `Sonntag, 4. Oktober, 2 Orte` (der genaue `TripDates.dayTitle`-Text darf aus der Quelle abgeleitet werden). Nach dem Tap müssen beide bekannten Orte bzw. deren Zeilenlabels und mindestens die beiden `Route zu …`-Controls erreichbar sein; `Noch nichts geplant` und ein Negativassert auf Route sind hier unzulässig.
3. `Dienstag, 6. Oktober, 1 Ort` wählen und als Postcondition `Prager Burg` plus `Route zu Prager Burg` prüfen. Danach zurück auf Tag 4 wechseln und erneut mindestens `qa-oldtown` und `qa-letna` prüfen. Das belegt echten Auswahlwechsel statt nur vorhandener Karten.
4. Erst danach auf `Ideen` und `Karte` wechseln und jeweils den Tab sowie `Offen` bzw. `Tage planen` verifizieren. Screenshots kommen nach diesen Assertions; der Test darf nicht allein aus sichtbaren Endbildern bestehen.

### Minimaler Fixplan für `testAutomaticDayPlanPreview`

1. Für diesen Test eine separate `--unassigned --known-hours`-Fixture über `ALBUM_AUTOPLAN_STORE` verwenden; `--known-hours` setzt nur leere, als bekannt markierte Öffnungszeiten und ist kein Live-Öffnungszeiten-Nachweis. Die normale `ALBUM_PLAN_STORE`-Fixture bleibt unverändert. Vor der Vorschau müssen `qa-oldtown` und ein `Tag festlegen`-Control sichtbar sein. Den Starttab explizit setzen: `ALBUM_START_TAB = "Karte"`, `Liste ausklappen` gezielt antippen und dann `Tage planen` wählen; der aktuelle implizite Weg über `Mehr` ist vom Startzustand abhängig.
2. Im Sheet zunächst `Vorschlag` und `Übernehmen` prüfen. Auf den aktivierten Zustand warten, ohne einen anfänglichen deaktivierten Zustand zu erzwingen oder einen erfolgreichen Lauf vorzutäuschen, wenn der Resolver innerhalb des bestehenden 90-Sekunden-Fensters nicht fertig wird.
3. Vor dem Anwenden mindestens zwei quellengestützte Vorschlagsorte (z. B. `Altstädter Ring`, `Letná`, `Prager Burg`) und mindestens eine Tagesüberschrift (`TripDates.dayTitle`) prüfen. Keine instabilen Reihenfolgen oder Öffnungszeiten als Pflichtassertion aufnehmen.
4. `Übernehmen` antippen und anschließend `Karte`, `Liste ausklappen`/`Liste einklappen`, die Tagesabschnitte sowie konkrete `place-row-qa-*`-Zeilen prüfen. Zusätzlich `Ordnen` öffnen und einen `Tag ändern, jetzt …`-Control prüfen; `Tag festlegen` darf bei dieser zuvor vollständig unzugewiesenen Fixture nicht mehr vorhanden sein. Damit wird die angewandte Tageszuordnung in der Kartenliste sichtbar belegt und nicht nur das Schließen des Sheets. Einen separaten Abbruchpfad mit `Abbrechen` kann anschließend prüfen, dass die Karte unverändert sichtbar bleibt.

### Minimaler Fixplan für `testScreenTour`

`ALBUM_START_TAB = "Reise"` und, für den Stand während der Reise, `ALBUM_TODAY = "2026-10-06"` setzen. Jede Aufnahme soll erst nach einer konkreten Assertion entstehen:

- Reise: Tab `Reise`, ein Tageskartenlabel mit Ortanzahl, `Idee einwerfen`, bei vorhandenen Fixtures `Flug-Ticket`, und `Alle Reiseunterlagen` prüfen. Für das Ticket/Unterlagenblatt jeweils den aktuellen Close-Control finden, öffnen, den Titel bzw. eine bekannte Ticketzeile prüfen und schließen.
- Ideen: Tab `Ideen`, Segment `Offen`, `Idee einwerfen`; Editor öffnen, einen eindeutigen Formular-Control prüfen und mit `Abbrechen` zurückkehren.
- Karte: Tab `Karte`, `Liste ausklappen` **antippen** statt den Grabber mit einem Root-Swipe zu bedienen; danach `Liste einklappen` und `map-places-list` prüfen. Eine konkrete Zeile wie `place-row-qa-oldtown` wählen, den stabilen Detail-Control `place-details-qa-oldtown` öffnen, `Bearbeiten` prüfen, abbrechen und die Rückkehr zur Detail-/Kartenansicht assertieren.
- Tagesplan: `Tage planen` öffnen, `Vorschlag`, `Übernehmen` und `Abbrechen` prüfen; den Vorschlag abbrechen und danach wieder `Tage planen`/Karte als sichtbaren Ausgangspunkt prüfen. Keine generische `Details zu`-Suche, wenn eine ID aus der Fixture vorhanden ist.
- Reiseunterlagen und Einladung: `Alle Reiseunterlagen` öffnen, den Sheet-Titel/Close-Control prüfen und schließen; anschließend `Jemanden einladen` oder `Gemeinsames Album` öffnen, den sichtbaren Einladungstitel prüfen und ohne Senden schließen.

Die bestehenden globalen `swipeUp`/`swipeDown`-Aufrufe sollen nur durch zielgebundene ScrollViews oder bekannte Controls ersetzt werden. Ein Testlauf ist erst nach Parent-Build und Simulatorlauf als Ergebnis zu dokumentieren; dieser Abschnitt ist ein Fixplan und behauptet keinen neuen Laufnachweis. Der Kontrast-/Accessibility-Bericht bleibt unverändert.

### Nachlauf 43034: tatsächliche AX-Abweichungen

Der Lauf `outputs/download-dayplan-media/manifest.json` / `work/download-dayplan-tests.json` hatte 15 Tests mit 11 Pass und vier Fehlern; die drei hier relevanten UI-Fehler sind Testannahmen bzw. ein unzureichend instrumentierter Sichtbarkeitsassert, kein belegter Produktfehler.

- **Tageswechsel:** Der tatsächlich exportierte AX-Text lautet `Dienstag, 6. Oktober, 1 Ort, heute`. Das bisherige exakte Label ohne `, heute` konnte deshalb nicht gefunden bzw. getappt werden. Der Test muss `label BEGINSWITH 'Dienstag, 6. Oktober, 1 Ort'` oder eine äquivalente stabile Teilbedingung verwenden und anschließend das vollständige Label als Beleg protokollieren.
- **Screen-Tour / Ideen:** Die vorbereitete `qa-full-plan`-Fixture setzt für alle sechs Orte `franked: true`. `InboxView` zeigt dann den leeren Zustand (`Alles entschieden` und `Idee einwerfen`); der Button `Offen` wird nur innerhalb des nichtleeren, noch unentschiedenen Kartenstapels erzeugt. Der 180-Sekunden-Fehler beim Warten auf `Offen` ist daher mit dieser Fixture reproduzierbar, aber eine falsche Postcondition. Für diesen Rundgang entweder den leeren Ideenstatus plus `Idee einwerfen` prüfen oder eine ausdrücklich unfrankierte, isolierte Ideen-Fixture verwenden; keine globale Demo-Umgebung aktivieren.
- **Autoplan / `qa-oldtown`:** Der Lauf belegt nur, dass `place-row-qa-oldtown` nach `Übernehmen` innerhalb des aktuellen `map-places-list`-AX-Baums existiert, nach dem begrenzten Scrollversuch aber nicht `isHittable` war. Es gibt im Fehlermaterial keinen Nachher-Screenshot oder Nachher-AX-Snapshot an dieser Assertion, daher ist weder eine falsche Zuweisung noch ein Produktfehler bewiesen. Die Kartenliste startet kontextbezogen am heutigen Tag; ein einseitiger `swipeUp`-Versuch reicht für einen früheren Ort nicht als Sichtbarkeitsbeweis. Der nächste Testnachlauf soll nach `Übernehmen` die Row-Frames und `map-places-list`-Frame anhängen, gezielt mit der Listenposition/Scrollrichtung arbeiten und danach den konkreten Tagesabschnitt sowie `Tag ändern, jetzt …` prüfen. Erst wenn der Ort trotz nachweislich erreichbarer Listenposition nicht sichtbar wird, ist daraus ein Kartenlistenfehler ableitbar.

Der Testplan behauptet für diese drei Punkte keinen bestandenen Nachlauf. Die übrigen Accessibility- und Kontrastbefunde bleiben unverändert.

### Umsetzung der Nachlaufkorrekturen

- `testSelectTravelDay` verwendet für Tag 6 die AX-Bedingung `BEGINSWITH 'Dienstag, 6. Oktober, 1 Ort'`; der Laufbeleg darf den dynamischen Suffix `, heute` enthalten.
- `testScreenTour` erwartet bei der vollständig frankierten `qa-full-plan`-Fixture den belegten leeren Ideenstatus (`Alles entschieden` und `Idee einwerfen`). `Offen` bleibt für eine separate unfrankierte Ideen-Fixture reserviert.
- Dieselbe Empty-State-Postcondition gilt jetzt auch für `testSelectTravelDay`; ein selektiver Nachlauf dieses Tests ist nach dem bereits kompilierten Lauf erforderlich.
- `testAutomaticDayPlanPreview` scrollt nach dem Anwenden zunächst gezielt ab dem heutigen Abschnitt nach unten bis `qa-oldtown` hittable ist, legt dort einen AX-Screenshot ab und sucht `qa-castle` anschließend in einem eigenen gerichteten Scrollschritt. Die beiden Orte müssen nicht gleichzeitig sichtbar sein. Die Prüfung ergänzt `Ordnen`/`Tag ändern, jetzt …` sowie einen Relaunch-Nachweis; konkrete Tagesnummern werden nicht erfunden.

### ScreenTour-Hang Nachlauf (xcresult 22:11:23)

Der aktuelle Lauf belegt keinen sichtbaren Freeze. In `work/screen-tour-activities.json` und `outputs/day-tour-media/manifest.json` ist der Ablauf bis zur Kartenansicht erfolgreich: Reise, Bordkarte öffnen/schließen, leerer Ideenstatus, Wechsel zu Karte und `Liste ausklappen` werden erreicht. Der Tap auf `Liste ausklappen` wird als synthetisiertes Event mit anschließendem „Wait for de.privatealbum.prague to idle“ protokolliert. Danach meldet XCTest „App event loop idle notification not received, will attempt to continue“, erstellt einen Spindump und prüft fünf Sekunden später `Liste einklappen`; der Element-AX-Check findet zunächst die Debugbeschreibung, erhält aber bis zum 3-Minuten-Limit keinen stabilen Treffer. Es gibt keinen Nachher-Screenshot oder AX-Snapshot nach dem Tap, daher ist ein sichtbarer Drawer-Freeze nicht bewiesen.

Die aktuelle Quelle führt beim Grabber-Tap `move(to: .full)` mit einer endlichen Spring-Animation (`response: 0.42`, `dampingFraction: 0.88`) aus. Gleichzeitig ändern `detent`/`headerSize` über `reportCovered()` die gebundene Karten-Safe-Area; `TripMapView` verarbeitet diese Änderung zusammen mit MapKit-Annotationen und `onMapCameraChange(frequency: .onEnd)`. Die Quelle enthält keinen offensichtlichen unendlichen Timer oder eine Endlosanimation im Drawer. Die belastbare Fix-Hypothese ist deshalb ein XCTest-Idle-/MapKit-Synchronisationsproblem während des detentbedingten Layout-/Kartenupdates oder ein daraus ausgelöstes wiederholtes Layout, nicht ein bereits bewiesenes falsches Einrasten des Sheets.

Für die nächste Diagnose müssen unmittelbar nach dem Tap ein Screenshot, `app.debugDescription`, die Frames/Labels von `Liste ausklappen` und `Liste einklappen` sowie die aktuelle Drawer-/Kartenoberfläche angehängt werden. Zusätzlich soll der Spindump aus dem xcresult exportiert und auf wiederholte App-/MapKit-/SwiftUI-Stacks geprüft werden. Erst ein sichtbarer Nachher-Zustand mit stabiler AX-Struktur oder ein Spindump mit wiederholtem Layout-/Map-Kamera-Stack rechtfertigt einen Produktfix. Bis dahin darf der Test nicht einfach mit längeren Wartezeiten oder einer entfernten Idle-Prüfung abgeschwächt werden.

### Videoabgleich des ScreenTour-Hangs

Die beiden exportierten Aufzeichnungen in `outputs/day-tour-media/` liefern einen sichtbaren Endzustand, der die Idle-Hypothese präzisiert:

- `DCF81C6B-07C6-4ED9-84C5-342205B60B4D.mp4` (47,015 s) endet sichtbar in `Karte` mit vollständig geöffnetem Drawer: `6 Orte`, `Fertig`, `Altstädter Ring`, `Cluster A`, `Cluster B`, `Café Savoy`, `Letná` und `Prager Burg`. Der Drawer ist damit visuell angekommen; die Aufnahme zeigt keinen dauerhaft eingefrorenen Zwischenzustand.
- `E15520A4-5EC5-444A-BE80-E61F449AE267.mp4` (30,740 s) endet in `Karte` mit halb geöffnetem Drawer, sichtbarem Grabber, `6 Orte`, `Tage planen`, `Ordnen`, `Heute Dienstag, 6. Oktober` und `Prager Burg`. Auch hier ist die Oberfläche nach dem Übergang sichtbar gezeichnet und bedienbar wirkend.

Die repräsentativen Endframes wurden offline aus den vorhandenen Videos extrahiert (`DCF…_47.jpg`, `E155…_31.jpg`). Sie belegen den visuellen Drawer-/Listen-Endzustand, aber keine kontinuierliche FPS-Qualität und keine eindeutige Zuordnung eines Videos zum einzelnen 22:12:20-xcresult-Lauf; die Manifest-Zeitstempel der beiden Dateien liegen bei 22:11:32 bzw. 22:15:39. Zusammen mit der Activity-Sequenz („Tap Liste ausklappen“ → fehlende Idle-Notification) spricht das gegen einen sichtbaren Dauerfreeze und für ein XCTest-Idle-/Synchronisationsproblem während bzw. nach dem Drawer-Layoutübergang. Ein Produktfix bleibt bis zum Spindump-/Nachher-AX-Beleg unbegründet.

### Region-Feedback-Guard (Gate offen)

Die Kartenansicht verwirft jetzt ungültige Kamera-Regionen und schreibt eine
`.onEnd`-Region nur bei einer materiellen Änderung (1e-7 Grad bei Zentrum oder
Span). Das adressiert die belegte Hypothese redundanter SwiftUI/MapKit-
Invalidierungen; ein Runtime-Nachweis steht aus. Erst ein erneuter `testScreenTour`
mit stabiler `Liste einklappen`-AX-Struktur darf dieses Gate schließen.

### Reduced-Motion-Lauf 89293: Konfigurationsbefund

Der Lauf `Test-Album QA-2026.10.02_22-21-33-+0200.xcresult` meldet fünf von fünf `AlbumMotionUITests` bestanden. `outputs/reduced-motion-media/manifest.json` enthält jedoch in keinem der fünf Tests den erwarteten Anhang `Reduce Motion environment marker` und keinen Nachweis der AX-ID `qa-reduce-motion-root`. Die vorhandenen Screen Recordings/Drag-Aktivitäten belegen deshalb nur den normalen Gestenpfad; sie beweisen nicht, dass die `reduceMotionRequested`-Zweige ausgeführt wurden.

Die aktuelle Testquelle setzt den Marker ausschließlich, wenn der **Test-Runner-Prozess** `ProcessInfo.processInfo.environment["ALBUM_QA_REDUCE_MOTION"] == "1"` sieht. Der installierte Testbundle-Binary enthält die Strings `ALBUM_QA_REDUCE_MOTION`, `Reduce Motion environment marker` und `qa-reduce-motion-root`; der Codepfad ist also im geprüften Binary grundsätzlich vorhanden. Die `.xctestrun`-Plist enthält `ALBUM_QA_REDUCE_MOTION=1` in `EnvironmentVariables` für beide TestTargets der Reduced-Motion-Konfiguration. Trotzdem fehlt der Marker im Ergebnis. Das trennt die korrekte Plan-/Plist-Erzeugung von der tatsächlich vererbten Runner-Umgebung bzw. einem möglichen stale Runner-Artefakt. Zusätzlich liegt der Quelltextzeitstempel nach dem Binary-Zeitstempel; eine vollständige Source/Binary-Identität des Laufs ist damit nicht belegt, obwohl die relevanten Strings vorhanden sind.

Der belastbare Nachlauf ist ein selektiver Lauf der fünf `AlbumMotionUITests` mit `ALBUM_QA_REDUCE_MOTION=1` explizit in der Umgebung des `xcodebuild`-Prozesses, danach muss der Manifest-Eintrag `Reduce Motion environment marker` für jeden Test und die AX-Prüfung `qa-reduce-motion-root` erscheinen. Erst dann dürfen bestandene Counter-/Button-Pfade als Reduced-Motion-Nachweis gelten; bis dahin ist der Lauf „5/5 bestanden, Reduced Motion nicht verifiziert“. Keine Gesten- oder App-Änderung aus diesem Ergebnis ableiten.

### Large-Type-Screenshotreview (Lauf `large-type-media`)

Die vier Keep-Always-Snapshots stammen vom iPhone-17-Pro-Simulator und wurden offline visuell sowie mit dem jeweils zugehörigen AX-Snapshot geprüft. Die AX-Existenz/Hittability der Header-Controls ist dabei kein Beleg für eine unverdeckte Darstellung.

- **Landscape links und rechts: Kartenliste praktisch auf 15 pt geklemmt (konkreter Befund).** In beiden Landscape-AX-Snapshots hat `map-places-list` den Frame `{{0,387.3},{557,14.7}}` bei einem Fenster von `874 × 402`. Der erste Tageskopf beginnt erst bei `y=419.5` und liegt damit vollständig außerhalb des Fensters; sichtbare Ortszeilen/Details können in diesem Zustand nicht erreicht werden. Die Screenshots zeigen entsprechend nur den Kartenbereich und den oberen Drawer-/Filterbereich, keine nutzbare innere Liste. Das ist ein Landscape-Layout-/Clipping-Befund, unabhängig davon, dass `Liste einklappen`, `Liste schließen`, `Tage planen` und `Ordnen` im AX-Baum existieren.
- **Landscape Filterleiste ragt über den verfügbaren Drawerbereich hinaus.** Die Filter-ScrollView ist im AX-Baum nur `70.7 pt` hoch; ihre Inhalte reichen bis x=1.099 pt, während der sichtbare Drawer bei x=557 endet. Das ist als horizontale Scrollfläche plausibel, aber zusammen mit dem 14.7-pt-Listenrest bleibt kein sichtbarer Bereich für Ortszeilen. Ein separater Filtertap-/Drawer-Detent-Fehler ist aus diesen Endbildern nicht ableitbar.
- **Portrait: Tageskopf teilweise unter Filterchips sichtbar abgeschnitten.** In `Large-Type-Portrait` und `Large-Type-Portrait zurück` ist unterhalb der Chips nur der obere/untere Rest des Tagesnamens (`Oktober`) zu sehen; der Text läuft hinter der Chipzeile bzw. wird von ihr verdeckt. Die AX-Daten zeigen zwar einen vorhandenen Tageskopf, beweisen aber nicht seine visuelle Freistellung. Der Befund ist an die aufgezeichnete Scrollposition gebunden; ein eigenständiger Fehler bei jedem Portrait-Start ist damit nicht bewiesen.
- **Kein belastbarer Befund für X-/Header-Überlappung oder Motion.** In den Landscape-Endzuständen bleiben X, Grabber, `Tage planen` und `Ordnen` als getrennte Controls vorhanden; die Aufnahmen sind End-/Orientierungs-Snapshots und erlauben keine Aussage über flüssige Rotation, Zwischenframes oder 60 fps. Die schwarzen Flächen in den Landscape-PNGs werden deshalb nicht als App-Renderingfehler gewertet.

### Large-Type-Landscape-Fix (Source-/Teststand)

`PlacesDrawer` verwendet für Landscape mit Accessibility-Schrift einen kompakten 44-pt-Werkzeugkopf (`Listenaktionen`-Menü plus 44-pt-Schließen). Titel, Untertitel und Filterchips liegen in diesem Modus in derselben vertikalen `map-places-list`-ScrollView oberhalb der Lazy-Ortszeilen; die normale Portrait-/Normalgrößenstruktur bleibt unverändert. Der normale und der kompakte Pfad teilen jetzt denselben Listenaufbau, damit `scrollPosition`/Selection-IDs identisch bleiben. Das Menü exponiert `Tage planen` und `Ordnen`; beim Editieren wird `Fertig` als direktes 44-pt-Checkmark mit AX-Label angeboten.

`testLargeTypeMapAndEditorJourney` prüft Landscape links/rechts jetzt über das Menü, bestätigt beide Aktionen, beendet den Editierpfad ohne Planerstart, prüft den 44-pt-Schließen-Control und verlangt für `map-places-list` mindestens 100 pt sichtbare Höhe. Zusätzlich wird je Landscape-Orientierung `Details zu Altstädter Ring` durch begrenztes Listen-Rückscrollen sichtbar/hittable geprüft. Die gezielte `qa-oldtown`-Scroll-/Hittability- und Editorprüfung bleibt erhalten; je Orientierung werden AX und Keep-Always-Screenshot angehängt. Ein Build-/Simulator-Nachlauf steht noch aus.

Der Nachlauf `large-type-landscape-retest` zeigte dabei keine Produktblockade: In Landscape lag die Detailaktion bei y=647 außerhalb des Listenfensters y=166–402, während der Test pauschal `swipeDown()` verwendete. Die Large-Type-Prüfung bestimmt die Scrollrichtung jetzt aus Detail-Frame versus Listenviewport; falls die Lazy-Zeile noch nicht exponiert ist, wird die sichtbare Tagessektion als begrenzter Fallback verwendet. Der Test behauptet weiterhin keinen Erfolg, wenn die Detailaktion danach nicht hittable ist.

### Native PhotosPicker-Probe

`testInspectSystemPhotoPicker` startet einen eindeutigen isolierten `slot-photo-picker-*`-Store mit dem vorhandenen Café-Louvre-Bildwahl-Demo, navigiert über Kartenblatt → Ortsdetail → Bearbeiten und prüft die echte Editorquelle `Eigenes Foto wählen`. Nach dem Tap wird die beobachtete Hierarchie des aktuell foregrounden PhotosPicker-Systemprozesses (oder des systemverwalteten Picker-Blatts) zusammen mit Startup-AX und Keep-Always-Screenshot angehängt. Die Probe tippt keinen Dateinamen bzw. kein Bild an, ändert keine Fixture und speichert nicht; unerwartete Berechtigungsdialoge werden dadurch nur als beobachteter Pickerzustand dokumentiert, nicht automatisch bestätigt.

### Cached MapProxy projection (Gate offen)

Die Karteninhalte verwenden jetzt zwischengespeicherte Pixelprojektionen außerhalb des `Map`-Content-Builders. Während eine vollständige Projektion nach Kamera-Ende, Geometrieänderung oder sichtbarem ID-/Koordinaten-Fingerprint noch aussteht, werden sichtbare Orte als einzelne Platzhalter-Nadeln gerendert; Clustering greift erst auf einen vollständigen, zur aktuellen Sichtmenge passenden Cache zu. Ein post-build `testScreenTour` muss den fehlenden Idle-/Grabber-Hang erneut prüfen; dieser Abschnitt behauptet keinen Runtime-Nachweis.

### ScreenTour-Scroll-Isolation (laufender Diagnoseversuch)

Für den nächsten kontrollierten Lauf ist ausschließlich der gebundene `.scrollPosition(id:anchor:)`-Modifier in `PlacesDrawer.drawerList` auskommentiert. `scrollTargetLayout`, `ScrollViewReader`, die fachliche Heute-Initialisierung und der bestehende `scrollTo`-Pfad bleiben bewusst erhalten; damit ist dies ein Diagnoseversuch und noch kein finaler Fix. Kein Runtime-Ergebnis wird vor dem separaten Nachlauf behauptet.

### ScrollReader-Einzelpfad nach Isolation

Der erfolgreiche Isolationstest ohne gebundenen `.scrollPosition`-Modifier bestätigt den Hotspot. Der Drawer verwendet nun einen einmaligen `ScrollViewReader`-Pfad: ein sichtbarer, tatsächlich vorhandener Heute-Abschnitt wird genau einmal angefahren; eine ausstehende Auswahlanfrage hat Vorrang und wird mit ID-, Request- und Filter-Fingerprint vor dem verzögerten `scrollTo` geprüft. Filterwechsel, Detent-Animationen und Nutzer-Scrollen lösen keinen erneuten Heute-Sprung aus. Dieser Source-Stand ist noch nicht separat nachgebaut; Runtime-Beleg bleibt dem Parent-Lauf vorbehalten.

Der Nachlauf ergänzt einen Pending-Marker gegen doppelte `DispatchQueue.main.async`-Scrolls. `handledSelectionRequest` und `initialScrollApplied` werden erst nach allen Laufzeit-Guards direkt vor dem tatsächlichen `proxy.scrollTo` gesetzt; bei veraltetem Detent, Filter, Request oder Ziel wird der Pending-Marker verworfen und ein späterer Reentry darf erneut versuchen.
