# ImageChoice

Bildwahl für einen Ort: Kandidaten in fester Quellenreihenfolge, unsichere Fotos zur manuellen Bestätigung, Credits sichtbar.

**SwiftUI:** „Bild wählen“ in `PlaceEditor`, `PlaceImageService.swift` · Status: **Bestand; Layout angleichen**

- Raster mit zwei Spalten, `radius-tile`, Foto 116 pt, darunter Quelle (`label`/13) und Credit (`caption` in `ink-soft`).
- Reihenfolge: Linkvorschau, Wikimedia (sicher), Wikimedia (unsicher, mit Badge „Ortszuordnung bitte prüfen“), eigenes Foto („Eigenes Foto wählen“), Apple-Karten-Vorschau.
- Hinweis über unsicheren Kandidaten: „Prüfe, ob das Foto wirklich Altstädter Ring zeigt.“
- Gewählt: Rahmen 3 pt `ink` + Häkchen. Eine manuelle Wahl und eigene Fotos haben Vorrang vor jeder Automatik.
- „Bild entfernen“ als destruktive Textaktion am Ende.
