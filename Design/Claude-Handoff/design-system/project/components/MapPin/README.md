# MapPin

Fotopins, Cluster, Kategorie-Fallback, Standortpunkt und Route auf der MapKit-Karte.

**SwiftUI:** Annotationen in `TripMapView`, `MapPinClustering.swift` · Status: **Bestand (Referenz)**

- Fotopin `size-pin` (56): Foto mit 3 pt `card`-Rahmen, `radius-thumb`, `elevation-pinned`, darunter ein 7-pt-Punkt als Fuß.
- Ausgewählt: 64 pt, Rahmen 3 pt `system-blue`, Fuß in `system-blue`. Die zugehörige Listenzeile wird gleichzeitig `selection`.
- Ohne Foto: Fläche in `mat-*` der Kategorie mit Symbol. Besucht: kleines `teal`-Häkchen oben rechts.
- Cluster: zwei versetzte Fotos plus Zahl in `action-fill`. Tippen zoomt hinein, die Liste filtert auf diese Orte („3 Orte“).
- Bei aktivem Filter treten nicht passende Pins auf 45 % zurück.
- Pins landen beim Erscheinen mit einem leichten Federn (nicht bei Reduce Motion). Routen zeichnen sich als gepunktete Linie in `red`.
