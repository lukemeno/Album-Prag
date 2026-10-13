# PlaceRow

Ortszeile im Kartenblatt und in Listen: Thumbnail, Ortsname in Instrument Serif und Metadaten.

**SwiftUI:** Zeilen in `PlacesDrawer` · Status: **Bestand (Referenz)**

- Thumbnail `size-row-thumb` (64) mit `radius-thumb`, Abstand 14. Name `place-m` in `ink`, Meta `meta`: „Kategorie · Tageszeit“ oder „Noch ohne Tag“.
- Ausgewählt (Pin ↔ Liste synchron): ganze Zeile auf `selection`, `radius-card`, darunter die Schnellaktionen „Route“ und „5. Okt“ in `red`.
- Besucht: Name in `ink-soft`, Häkchen-Badge in `teal`. Kein Durchstreichen.
- Im Tagesplan: Nummer (26-pt-Kreis, `action-fill`) statt Thumbnail-Badge, erledigt in `teal`.
- **Keine Sterne oder Bewertungen.** Die Referenz zeigt „4.8 (12K)“, Album hat diese Daten nicht.
