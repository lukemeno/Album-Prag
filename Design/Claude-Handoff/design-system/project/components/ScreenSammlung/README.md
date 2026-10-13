# Sammlung

Geteilte Inspirations- und Beitragsliste unter „Ideen“ → „Sammlung“. Beiträge entstehen aus URL, Text oder Bild und sind sofort lokal gespeichert.

**SwiftUI:** `CollectionViews.swift`, `CollectionStore.swift`, `CollectionPlaceSuggestions.swift` · Status: **neu abgeleitet**

- Liste: CollectionPost-Karten, Suche oben, Sync-Badge nur bei „Ausstehend“ oder Fehler.
- Beitrag: Vorschau groß, „Quelle öffnen“, „Vorschau aktualisieren“, Abschnitt **Orte aus dem Beitrag** (Vorschläge aus Titel/Beschreibung via Apple Karten). Der Nutzer wählt; „Als Ort speichern“ öffnet den vorhandenen Ortseditor.
- Kommentare und Herzen sind eigene Datensätze. Kommentar löschen erfolgt mit Bestätigung.
- Sammeln-Blatt: Link oder Text, Skeleton während `metadataState = pending`, Offline-Hinweis. Kein Pflichtort.
- Mehrere Orte pro Beitrag sind möglich. „Kein Ort erkannt“ ist ein neutraler Zustand, kein Fehler.
