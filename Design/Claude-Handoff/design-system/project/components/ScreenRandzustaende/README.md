# Randzustände

Offline, leere Karte, Laden und Fehler. Alle nutzen StateView, Banner und Skeletons, damit kein Zustand improvisiert aussieht.

**SwiftUI:** quer durch `ReiseView`, `TripMapView`, `InboxView`, `AlbumStore` · Status: **neu**

- **Offline (Reise):** Inhalte bleiben, Banner oben. Routen öffnen Apple Karten, die Ortssuche sagt, dass sie Netz braucht.
- **Leere Karte:** Das Blatt steht auf 0 Orte mit Erklärung und zwei Wegen: „Zu den Ideen“ und „Idee einwerfen“.
- **Laden (Ideen):** Skeleton in Kartenform statt Spinner. Ein Bildfehler erscheint als Banner mit „Erneut“, ohne den Stapel zu blockieren.
- Weitere Zustände: Sync ausstehend, Fehler und erfolgreich (siehe Teilen), fehlende Bildquelle (PhotoCard-Platzhalter, Look Around), manueller Bildentscheid (ImageChoice), Bestätigung und Undo (Toast, ConfirmDialog).
- Große Dynamic Type: Zeilen wachsen in der Höhe, Kacheln brechen um, nichts wird abgeschnitten. VoiceOver-Labels stehen in den Komponenten-READMEs.
