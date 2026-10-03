# QA-Diagnose: Drawer-Geste

Quelle: `outputs/editor-map-qa-media/378505B4-3F14-489F-B160-BA7F178063B9.mp4`.
Die Aufnahme dauert 27,901667 s und enthält 581 H.264-Bilder. `ffprobe` meldet
eine variable Rate (`avg_frame_rate=348600/16741`, etwa 20,8 Bilder/s); daraus
wird keine 60-FPS-Aussage abgeleitet.

## Beobachtung

Die beiden `swipeDown(velocity: .fast)`-Aufrufe aus
`AlbumUITests/AlbumUITests.swift:444–448` liegen nach dem bekannten Offset
ungefähr bei Video 20,5 s und 23,7 s.

- Vor dem ersten Aufruf bleibt der Grabber bei ungefähr y=1426 px. Zwischen
  20,65 s und 20,70 s bewegt sich der Drawer nach unten auf ungefähr y=1492 px
  und bleibt dort. Ein Übergang zu `.hidden` ist nicht zu sehen. Ohne Detent-Trace
  lässt die kleine sichtbare Bewegung den internen Rastpunkt nicht sicher bestimmen.
- Vor dem zweiten Aufruf bleibt er bei ungefähr y=1492 px. Zwischen 23,50 s
  und 23,80 s bewegt er sich um ungefähr 66 px **nach oben** auf y=1426 px und
  bleibt dort. Es gibt in diesem Zeitfenster keine sichtbare Abwärtsbewegung
  bis zur versteckten Kapsel (`map-drawer-reopen`).

Der XCTest-Log passt dazu: Nach dem zweiten Swipe existieren weiterhin die
`place-row-*`-Elemente und `Liste ausklappen`, aber kein
`map-drawer-reopen` (`StandardOutputAndStandardError.txt:78–110`). Die Aufnahme
zeigt eine sichtbare Aufwärtsbewegung zurück zum Ausgangsbild. Der AX-Endzustand
entspricht `.half`; der Zwischenrastpunkt ist nicht instrumentiert.

## Technische Einordnung

Der Grabber besitzt in `Album/PlacesDrawer.swift:311–322` sowohl eine normale
Button-Aktion als auch ein `highPriorityGesture`. Die Button-Aktion schaltet
bei jedem Zustand außer `.half` auf `.half` (`PlacesDrawer.swift:312–314`);
aus `.collapsed` ergibt das genau die im Video sichtbare Aufwärtsbewegung.
Die Drag-Erkennung verwirft einen Endzustand, wenn die Achse nicht eindeutig
ist (`PlacesDrawer.swift:169–186`), und setzt den Drag-Schutz erst 100 ms nach
`onEnded` zurück (`PlacesDrawer.swift:182–184`). Damit ist eine
Code-konsistente Hypothese: Der zweite synthetische Swipe erreicht
nicht den gültigen vertikalen Drag-Endpfad und der Grabber fällt auf seine
Tap-Aktion zurück. Das Video beweist den ausgelösten Handler selbst nicht.

Der Resolver ist nicht isoliert als Fehler bewiesen. Bei einem tatsächlich
ausreichend großen positiven `actualTranslation` sollte er von `.collapsed`
nach `.hidden` wählen; seine Momentumschätzung ist in
`Album/PlacesDrawer.swift:18–30` zudem begrenzt. Die Aufnahme enthält keine
Touch-Translation oder `DrawerDetent`-Tracewerte, und im bereitgestellten
`.xcresult`-Staging wurden keine separaten Recorded-Event-/Manifest-Dateien
gefunden. Deshalb bleibt offen, ob der zweite Drag zu kurz/seitlich war oder
vor dem Resolver als Tap endete.


## Nachtest: erfolgreiche Grabber-Geste

Quelle: `outputs/gesture-cluster-journey-media/F1D89DD2-54D0-4E10-B6F3-06E7E6B42144.mp4`.
Die Aufnahme dauert 48,590000 s und enthält 1164 H.264-Bilder. Die gemeldete
Rate ist variabel (`avg_frame_rate=116400/4859`, etwa 23,95 Bilder/s); daraus
wird keine 60-FPS-Aussage abgeleitet.

### Sichtbarer Verlauf

- **Kurzer Drag:** Im Fenster nach der Auswahl und vor dem langen Schließen
  (visuell ungefähr 23,9–24,5 s; die genaue Touch-Zeit ist im Video nicht
  separat markiert) verschiebt sich der Grabber samt Blatt kurz nach unten.
  Die Folge der Einzelbilder `f-0235`, `f-0239`, `f-0242`, `f-0245` zeigt danach
  die Rückkehr auf dieselbe mittlere Höhe. Die Liste bleibt sichtbar; es gibt
  keinen Wechsel in den Vollzustand und keinen sichtbaren Aufwärts-Sprung wie
  im vorherigen Video. Das belegt die sichtbare Bewegung und den Endzustand,
  nicht den internen Gesture-Handler.
- **Langer Drag zum Schließen:** Ab ungefähr 32,3 s startet das Blatt aus dem
  mittleren Zustand und bewegt sich über die folgenden Bilder nach unten.
  `f-0333` beziehungsweise das Einzelbild bei 33,5 s zeigen die sichtbare
  `map-drawer-reopen`-Kapsel; ab dort bleibt der Drawer verborgen. Nach dem
  Loslassen ist kein Rücksprung nach oben oder Wechsel zurück zur Liste zu
  sehen.
- **Wiederöffnen:** Zwischen ungefähr 36,7 und 38,0 s wechselt die Kapsel
  wieder zum mittleren Drawer (`f-0367`, `f-0368`, danach die Bilder bei 37,5
  und 38,0 s). Die Liste erscheint auf der mittleren Höhe ohne zusätzlichen
  Fehl-Sprung. Die späteren Landschaftsbilder sind ein separater
  Orientierungsschritt und wurden nicht zur Ableitung der Portrait-Zeitpunkte
  verwendet.

### Vergleich zum vorherigen Befund und Grenzen

Das vorherige Video (`outputs/editor-map-qa-media/378505B4-3F14-489F-B160-BA7F178063B9.mp4`)
zeigte beim zweiten kurzen synthetischen Wisch eine sichtbare Bewegung nach
oben zurück zur mittleren Höhe, während der Drawer offen blieb. Im Nachtest
führt der kurze Drag sichtbar nur zu einer kleinen Bewegung mit stabilem
mittleren Endzustand; der lange Drag erreicht anschließend zuverlässig den
verborgenen Zustand und bleibt dort bis zum Reopen. Kanten- und Listenlayout
bleiben in diesen Sequenzen ruhig; ein Start-/Endsprung ist im sichtbaren
Verlauf nicht erkennbar.

Die Zeitfenster sind aus den Videobildern und dem Testablauf abgeleitet. Das
Video enthält keinen direkten Finger-/Touch-Trace, keinen Detent-Trace und
keine separate Recorded-Event-Datei. Die Aussage beschränkt sich daher auf
sichtbare Blattbewegung, sichtbare Zustände und deren Stabilität nach dem
Loslassen.

## Nachtest: globaler Drag-Koordinatenraum

Quelle: `outputs/global-drawer-media/783EA28C-1755-4433-9CA0-CFEBF2E4B885.mp4`.
Die Aufnahme dauert 56,133333 s und enthält 936 H.264-Bilder. Die Rate ist
variabel (`avg_frame_rate=7020/421`, etwa 16,7 Bilder/s); daraus wird keine
60-FPS-Aussage abgeleitet. Der zugehörige Lauf meldete 45 Tests bestanden,
0 Fehler und 1 übersprungenen Test (echte Buchungs-PDF).

Der lange Abwärtszug folgt dem Blatt sichtbar nach unten und endet in der
verdeckten Darstellung mit der `6 Orte`-Kapsel am unteren Rand. In den
anschließenden Einzelbildern bleibt diese Kapsel stabil; ein Rücksprung auf
die kollabierte Liste ist nicht zu sehen. Das erneute Öffnen bewegt das Blatt
wieder nach oben und zeigt die Liste anschließend ohne sichtbaren Start- oder
Endsprung. Die Karten- und Listenflächen bleiben während dieser Folge ruhig.

Damit ist der vorherige sichtbare Ablauf – Blatt folgt dem Zug, springt nach
Loslassen zurück und `map-drawer-reopen` fehlt – in diesem Lauf nicht mehr zu
beobachten. Der Test verwendete nun genau einen langen Zug bis zum verdeckten
Zustand und bestätigte danach `map-drawer-reopen` sowie das Reopen-Verhalten.
Die Aufzeichnung belegt den sichtbaren Ablauf und den erfolgreichen Endzustand;
sie beweist nicht allein, welcher interne Gesture-Handler den Detent gesetzt
hat. Die Änderung am Griff verwendet `coordinateSpace: .global`; SwiftUI
dokumentiert diese Koordinatenraum-Eigenschaft in der
[DragGesture-Referenz](https://developer.apple.com/documentation/swiftui/draggesture/coordinatespace).
