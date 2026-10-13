# CollectionPost

Beitrag in der geteilten Sammlung: Link oder Text, Linkvorschau, verknüpfte Orte, Herzen, Kommentare und Sync-Zustand.

**SwiftUI:** `CollectionViews.swift`, Daten `CollectionEntry` · Status: **Bestand; auf Kartensprache bringen**

- Kopf: Avatar (28 pt Initialen), Name, relative Zeit und Sync-Badge, falls nicht abgeglichen.
- Linkvorschau auf `paper` mit `rule`: Thumbnail 72 pt, Titel (z. B. „TikTok · @creator“), Caption in `meta`, höchstens 2 Zeilen. Solange `metadataState` = `pending`, erscheinen Skeleton und „Vorschau wird geladen …“.
- Instagram wird nie ausgelesen: Es erscheint nur „Instagram-Link“ mit Host und dem Hinweis „Vorschau nicht verfügbar“. TikTok nur über oEmbed.
- Orte: kleine Chips mit Pin. „Ort hinzufügen“ öffnet die Vorschläge („Orte aus dem Beitrag“); der Nutzer bestätigt, nichts geschieht automatisch.
- Fuß: Herz (gefüllt in `red`, wenn eigenes), Kommentaranzahl, „Quelle öffnen“.
