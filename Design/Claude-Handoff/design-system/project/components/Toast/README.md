# Toast

Kurzmeldungen am unteren Rand mit Undo und der Clipboard-Hinweis oben.

**SwiftUI:** Undo-Leiste in `InboxView`, `ClipboardNote` (AlbumRoot.swift) · Status: **Bestand; Undo-Toast vereinheitlichen**

- Undo-Toast: Navy-Pille (`action-fill`), Text `body`/15 links, „Rückgängig“ rechts als helle Innenpille. Sitzt 12 pt über der Tab-Leiste und bleibt bis zur nächsten Aktion bzw. 6 s.
- Gilt für Ideen-Entscheidungen, übernommene Pläne, „Als besucht markieren“ und gelöschte Kommentare.
- Clipboard-Hinweis: Karte oben unter der Toolbar, Icon-Mulde `paper-deep` mit `link` in `red`, „Link kopiert“ / „Als Idee einwerfen?“ und nativer „Einfügen“-Knopf (`red-fill`). Wegwischen nach oben, verschwindet nach 6 s.
- Der Inhalt der Zwischenablage wird erst beim Tippen auf „Einfügen“ gelesen.
