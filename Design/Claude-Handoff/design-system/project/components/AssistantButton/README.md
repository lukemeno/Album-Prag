# AssistantButton

Der kleine schwebende KI-Kreis unten rechts. Er ist das einzige ausdrücklich freigegebene Element des bisherigen Zwischenstands und wird **unverändert** übernommen.

**SwiftUI:** Overlay in `AlbumRoot` (48 × 48, `Stitch.ink`, `sparkles` 20 pt medium, `elevation-floating`) · Status: **Freigegeben, nicht verändern**

- Position: `page` (20) vom rechten Rand, 76 pt über dem unteren Safe-Area-Rand, also über der Tab-Leiste.
- Auf der Karte sitzt er an der Oberkante des Ortsblatts (half/collapsed) und verdeckt keine Kartenaktion.
- Ausgeblendet, solange ein Editor, die Unterlagen, Teilen, der Erststart oder das Assistent-Sheet offen sind.
- VoiceOver: „Reise-Assistent“. Kontextuelle Einstiege bei Ort und Tagesplan öffnen denselben Chat mit Vorbelegung.
