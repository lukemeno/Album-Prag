# SearchField

Schwebende Suchpille über der Karte mit Filterknopf. Darunter: die Ortssuche im Editor.

**SwiftUI:** Suchfeld in `TripMapView` („Prag durchsuchen“), Ortssuche in `PlaceEditor` · Status: **Bestand (Referenz)**

- Karte: 52 pt hoch, volle Breite minus `page`, `radius-pill`, `card` + `elevation-floating`. Lupe links in `ink`, Filter (`sliders`) rechts mit eigenem Label „Karte filtern“.
- In Sheets flach mit `rule`-Kontur statt Schatten.
- Platzhalter immer konkret: „Prag durchsuchen“, „Ort suchen“, „In der Sammlung suchen“.
