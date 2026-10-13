# ActionTile

Quadratische Aktionskachel mit Symbol über Label, im Ortsdetail in einer Reihe.

**SwiftUI:** Kacheln in `TripMapView` (Ortsdetail: „Route“, „Plan ändern“, „Teilen“, „Website“) · Status: **Vereinheitlichen**

- Höhe ≥ 72, `radius-tile`, `card` + `rule`, Symbol 24 pt in `ink`, Label `body`/15 pt.
- Die kontextuelle Hauptaktion („Plan ändern“ bzw. „Zum Plan“) liegt auf `selection` (Hellblau), genau wie „Add to plan“ in der Referenz.
- 2 bis 4 Kacheln, gleich breit, 12 pt Abstand. Bei großer Dynamic Type umbrechen sie in zwei Zeilen und schneiden nichts ab.
- „Website“ erscheint nur, wenn eine Quelle existiert. Fehlt sie, rücken die übrigen Kacheln zusammen.
