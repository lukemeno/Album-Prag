# Live-Schnappschüsse (nicht deployen)

Live-Functions tragen jeweils ihre eigene Kopie von `_shared` aus dem Zeitpunkt ihres Deploys.
Stand 21.10.2026 weichen zwei Dateien ab:

| Datei | Repo `_shared/` (= live in `place-photo`) | live in `place-enrichment` (hier abgelegt) |
|---|---|---|
| `wikimedia_photos.ts` | Sprachen fest `de/cs/en`, Signatur mit 5 Parametern | Englisch + eine Sprache aus `regionName` (6. Parameter) |
| `place_photo.ts` | `normalize` nur ASCII | `normalize` Unicode-fähig |

Folge: `deno check place-enrichment/index.ts` schlägt im Repo mit TS2554 fehl (6 statt 5 Argumente).
Zur Laufzeit ist live alles konsistent, weil jede Function ihr eigenes Bundle hat.

Offene Entscheidung, bevor eine der beiden Functions aus dem Repo neu deployt wird: die neuere Fassung
übernehmen und `place-photo` die Reiseregion übergeben lassen. Ohne Region würde die neue Fassung für
Prag-Orte nur auf Englisch suchen, der Test `Wikipedia falls back …` scheitert dann.
