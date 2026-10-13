# Ortsdetail

Ort öffnen: großes Foto, darüber ein Blatt mit Ortsname, Kategorie, Beschreibung, Tag, Aktionskacheln und dem Schieber „Als besucht markieren“.

**Referenz:** `approved-native-design.png` (rechts) + `2026-10-04-reference-detail.png` · **SwiftUI:** Detail in `TripMapView.swift`, `PlaceEditor.swift`, `VisitedTrack.swift`

- Foto beginnt unter einem Kartenstreifen (Detail öffnet aus der Karte) mit `radius-floating` oben. Zurück und „…“ als 50-pt-Kreise.
- Blatt überlappt das Foto, Greifer zentriert, Titel `place-xl`, Kategorie mit `pin-ell`-Symbol in `ink-soft`.
- Aktionskacheln: „Route“ und „Plan ändern“ (Hellblau). Mit Quelle zusätzlich „Teilen“ und „Website“.
- Weiter unten: Fotos/Galerie, Adresse, Öffnungszeiten (nur wenn vorhanden, sonst „Keine Öffnungszeiten hinterlegt“), Quelle, Bildnachweis, „Bearbeiten“, „In Sammlung“.
- Besucht: Badge, Schieber in `teal`, Undo-Toast. Danach schlägt die Hauptkachel „Foto ergänzen“ vor (Erinnerungen).
- **Weggelassen aus dem Mockup:** Sterne/„4.8 (12K)“, erfundene Beschreibungen. Text kommt aus `Place.note`.
