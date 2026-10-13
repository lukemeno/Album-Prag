# PhotoCard

Fotofläche mit Verlauf, Titel und Bildnachweis. Sie ist die tragende Bildsprache der App: Titelfoto auf „Reise“, Ideenkarte, Ortsdetail und Tageskachel.

**SwiftUI:** `AlbumPhoto`, `PhotoCard` (Album/Design.swift) · Status: **Bestand, Maße an Referenz angleichen**

## Verwendung
- Titelfoto „Reise“: 362 × `size-hero` (300), `radius-card`, Titel in `hero-title`, Untertitel in `callout`, beides `on-accent` links unten (28 pt Innenabstand).
- Ortsdetail: randlos oben, das Blatt (`radius-floating`) überlappt das Foto um 28 pt.
- Verlauf exakt wie im Code: transparent bis 50 %, 6 % bei 74 %, 58 % bei 84 %, 84 % Schwarz am Boden. Kein farbiger Verlauf.

## Bildquellen in Reihenfolge
1. Linkvorschau (OG/Twitter, JSON-LD) – Kapsel „Bild der Quelle“
2. Wikimedia Commons – Kapsel „Foto: Urheber · Lizenz“
3. Tripadvisor (vorbereitet, standardmäßig aus)
4. Eigenes Foto / Upload – ohne Kapsel
5. Apple Look Around bzw. Kartensnapshot – Kapsel „Foto nicht verfügbar · Apple Karten · Straßenansicht“
6. Gestalteter Platzhalter: `paper-deep` mit Foto-Symbol in `ink-soft`

## Was der Consumer liefert
Bild-URL oder Asset, Titel, Untertitel, optional Credit/Lizenz. Für Fotos ohne gesicherten Ortsbezug immer die Bildwahl (ImageChoice) anbieten.

## Nicht
- Keine Bewertungen, Sterne oder erfundene Kennzahlen auf das Foto legen (die Referenz zeigt „4.8 (12K)“ – bewusst weggelassen).
- Credit nie weglassen, wenn die Lizenz ihn verlangt (CC BY-SA).
