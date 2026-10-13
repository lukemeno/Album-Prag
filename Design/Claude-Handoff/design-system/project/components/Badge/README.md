# Badge

Kleine Kapseln für Kategorie, Quelle, Zustand und Zahlen.

**SwiftUI:** verstreut (Kategorie-Label, „Besucht“, Sync, Inbox-Badge) · Status: **Neu als einheitlicher Baustein**

- 24 pt hoch, `radius-pill`, Schrift `caption`. Kategorie auf `mat-*`, Text immer `ink`.
- Quelle: `card` + `rule` mit Plattformname („TikTok“, „Instagram“, „prague.eu“). Plattformlogos werden nicht nachgezeichnet.
- Zustände: `ok` (teal, „Besucht“, „Abgeglichen“), `warn` (red, „Nicht abgeglichen“, „Ortszuordnung prüfen“), neutral (`paper-deep`, „Noch offen“).
- Jeder Zustand trägt Wort **und** Symbol. Farbe allein reicht nie.
- Zählbadge (`badge`, weiß) nur am Ideen-Tab.
