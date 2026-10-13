# TabBar

Schwebende Tab-Leiste mit genau drei Tabs: Reise, Ideen und Karte. Weitere Haupt-Tabs gibt es nicht.

**SwiftUI:** `TabView` in `AlbumRoot` (Symbole `suitcase`, `tray`, `map`) · Status: **Vereinheitlichen auf Referenz**

- 274 × `size-tabbar` (62), `radius-pill`, `card` + `elevation-floating`, 26 pt über dem unteren Rand und horizontal zentriert.
- Aktiver Tab: Pille `tab-selected` hinter Symbol und Label. Alle Symbole gefüllt, 26 pt, in `ink`. Label im Stil `tab`.
- Badge am Ideen-Tab: Anzahl offener Ideen (`store.inbox.count`) in `badge`, z. B. 81.
- Beim Scrollen wird die Leiste kompakter (48 pt, nur Symbole). Reduce Motion: kein Größenwechsel.
- „Idee einwerfen“ ist keine Tab-Position, sondern das „+“ in der Kopfzeile bzw. Toolbar.
