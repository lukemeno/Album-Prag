# Karte

MapKit-Karte mit Fotopins und Clustern, schwebender Suche, Filterchips und verschiebbarem Ortsblatt. Pin und Liste sind synchron.

**Referenz:** `approved-native-design.png` (Mitte) + `2026-10-04-reference-map.png` · **SwiftUI:** `TripMapView.swift`, `PlacesDrawer.swift`, `MapPinClustering.swift`

- Suche schwebt 62 pt unter dem oberen Rand (unter der Statusleiste), volle Breite minus 2 × `page`.
- Ortsblatt **half** beginnt bei ~49 % der Höhe (Referenz 428 pt). Der KI-Kreis sitzt rechts auf dessen Oberkante.
- Kopf: „2 Orte“ (`sheet-title`), „Heute 1 Ort“, rechts „Tage planen“ (Koralle), „Ordnen“, Schließen.
- Auswahl: Pin 64 pt mit `system-blue` und gleichzeitig die Listenzeile auf `selection` mit „Route“ und Tag.
- **full:** Suche wandert ins Blatt, Liste scrollt, der letzte Eintrag bleibt über der Tab-Leiste frei.
- **Querformat:** Das Blatt wird zum schwebenden Panel links (360 pt), die Suche rückt nach rechts. Beide Drehrichtungen werden unterstützt.
- Keine Bewertungen und keine „km“-Distanzen, solange kein Standort freigegeben ist.
