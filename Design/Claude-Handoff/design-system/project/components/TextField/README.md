# TextField

Ein- und mehrzeilige Eingabe auf `card` mit Schreibmaschinen-Schiene. Ein kleiner Korallen-Schlitten folgt dem Text.

**SwiftUI:** `StitchTextField` (AlbumRoot.swift), Felder im `PlaceEditor` · Status: **Bestand; Editorfelder angleichen**

- Fläche `card`, `radius-card`, 1 pt `rule`, Text `body`, Platzhalter `ink-soft`, Label darüber in `footnote`/semibold `ink-soft`.
- Fokus: Die Schiene färbt sich in `ink` 35 %, der Schlitten (14 × 5, `red`) folgt mit 40–90 ms Verzögerung. Reduce Motion: kein Schlitten.
- Fehler: 1.5 pt `red`-Kontur und eine Zeile mit `warn`-Symbol, z. B. „Der Link muss mit https:// beginnen.“
- Felder im Editor: „Name der Idee“, „Link von TikTok oder Instagram“, „Warum möchtet ihr dorthin?“, „Ort oder Adresse in Prag“.
