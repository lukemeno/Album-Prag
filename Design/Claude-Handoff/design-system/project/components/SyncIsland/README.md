# SyncIsland

Kleine schwebende Abgleich-Insel für den Sync-Zustand zwischen beiden iPhones.

**SwiftUI:** `SyncIsland.swift`, Abgleich in `ReiseView` / `AlbumStore` · Status: **Bestand**

- Pille 40 pt, `card` + `elevation-floating`, Punkt + Text `label`/14.
- Zustände: **Abgleich** (Spinner), **Abgeglichen** (`teal`), **Ausstehend** (`ink-soft`, „2 Änderungen warten“), **Fehler** (`red`, „Nicht abgeglichen · Erneut“), **Neu von Mia** (kurz, wenn die andere Person etwas geändert hat).
- Offline zuerst: Lokale Eingaben gehen nie verloren. Bei Konflikten gewinnt der neuere Zeitstempel, ohne Rückfrage.
- Erscheint beim Herunterziehen oder nach Änderungen, sonst bleibt sie verborgen.
