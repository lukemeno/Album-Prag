# DayTile

Tageskachel im Reiseplan mit Datum (Versalien), Bildfläche und Titel. Sechs Kacheln, horizontal scrollend.

**SwiftUI:** `itineraryDay(_:)` in `ReiseView` · Status: **Bestand; Maße an Referenz**

- 104 × ~170 pt, `radius-tile`, `card` + `rule`, Innenabstand 8. Datum `eyebrow` („4. OKT“), Bild 92 pt hoch mit `radius-thumb`.
- Ohne Plan: `paper-deep` mit Kalendersymbol, Titel „Noch offen“. Mit Plan: Foto des ersten Orts, Titel = Ortsname oder Zusammenfassung.
- Heute: Rand 2 pt `selection`, Fläche zu 45 % `selection`, Datum in `ink`.
- Daten nur aus dem Repo: 4.–9. Oktober 2026 (So bis Fr), „Tag 1 von 6“.
