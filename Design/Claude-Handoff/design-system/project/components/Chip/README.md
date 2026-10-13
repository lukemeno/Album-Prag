# Chip

Filter- und Kategoriechips als Pillen, horizontal scrollend.

**SwiftUI:** Filterchips in `PlacesDrawer` / `TripMapView` („Alle“, „Essen“, „Sehenswert“, „Aussicht“) · Status: **Bestand (Referenz)**

- Höhe `size-touch` (44), `radius-pill`, `card` + `rule`, Label 16 pt semibold, Symbol links.
- Gewählt: `action-fill` + `on-accent`, ohne Kontur. Es ist immer genau ein Filter aktiv; „Alle“ ist Standard.
- Kleine Chips (32 pt) für Vorschläge im Assistenten und für Ortsverknüpfungen in der Sammlung.
- Der letzte Chip darf angeschnitten sein, um Scrollbarkeit zu zeigen (Referenz). Es gibt keinen Pfeil.
