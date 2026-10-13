# IdeaCard

Ideenkarte im Entdecken-Stapel: großes Foto, Ortsname, Quelle, Kategorie und Beschreibung.

**SwiftUI:** Karte in `InboxView` · Status: **Vereinheitlichen auf Referenzsprache**

- Volle Breite minus `page`, `radius-card`, `card` + `elevation-floating`. Foto 300 pt hoch, darunter 16/18 pt Innenabstand.
- Zeile 1: Quelle als Badge (`line`) und Kategorie (`mat-*`). Zeile 2: Name `place-l`. Zeile 3: Beschreibung `body`, höchstens 3 Zeilen, dann „Mehr anzeigen“.
- Autor der Idee als kleine Zeile in `meta` („Von LU eingeworfen“). Die Partnerschaft bleibt Beiwerk.
- Gesten: rechts = **Ja**, links = **Nein**, oben = **Offen** (nur für diesen Durchgang, ohne Stimme). Beim Ziehen erscheint der Stempel „Ja“ (`teal`), „Nein“ (`red`) oder „Offen“ (`ink`).
- Rücklauf ohne Entscheidung mit `--motion-return`. Reduce Motion: Karte blendet aus statt zu fliegen.
- Dahinter liegen zwei Karten als Stapelkanten (versetzt um 10/20 pt), sonst nichts.
