# Goldene Testliste für die Bildauswahl (22.10.2026)

100 Suchbegriffe, an denen jede Bildauswahl gemessen wird (Plan: [PLAN-BILDAUSWAHL.md](../../../PLAN-BILDAUSWAHL.md)).
Die Liste prüft **nicht** selbst Bilder. Sie legt fest, was richtig wäre. Der Messlauf gegen die Pipeline kommt als nächster Schritt.

## Inhalt

| Art (`kind`) | Anzahl | Was richtig ist |
|---|---|---|
| `landmark` | 52 | Referenzort per Wikidata belegt (50 von 52; Q-ID, Koordinaten); Bild muss diesen Ort zeigen |
| `venue` | 15 | Lokale. Nur 3 per Wikidata belegt, 12 Prager Lokale **brauchen eine menschliche Zuordnung** |
| `dish` | 10 | Gerichte und Begriffe („Pasta“): freies Gerichtsbild, kein Lokal-Foto |
| `ambiguous` | 10 | zu allgemein oder mehrdeutig („Fresca“, „Konzeptbar“): nie blind ein Bild wählen |
| `chain` | 6 | Ketten: Filiale, Straßenansicht oder neutral; Logo nicht als Hauptbild |
| `variant` | 7 | Schreibvarianten (ohne Umlaut, Landessprache, Englisch): müssen auf denselben Ort zeigen wie `same_as` |

Abdeckung: Prag (70 Fälle, darunter Gerichte, Mehrdeutiges, Ketten und Varianten mit Prag-Kontext), 30 Fälle in 18 anderen Städten, davon 8 in nicht-lateinischer Schrift (Japanisch, Russisch, Chinesisch, Koreanisch, Griechisch, Arabisch).
(Die Anzahlen stehen in `golden.json`; `validate_golden_test.ts` prüft Mindestmengen.)

## Wie belegt wurde

- `tools/seed.py`: der Entwurf mit meiner ungefähren Referenzkoordinate je Ort.
- `tools/resolve_wikidata.py`: sucht in Wikidata, nimmt nur Treffer **mit Koordinaten** innerhalb von 300 m (Flächenobjekte wie Kampa-Insel, East Side Gallery, Verbotene Stadt 600 m) und bevorzugt einen **exakten Namenstreffer** vor dem nächstgelegenen. Feld `match`: `exact` (47) oder `partial` (6).
- Erste Läufe lieferten vier falsche Nachbar-Einträge (z. B. „Naschmarktkapelle“ statt Naschmarkt); der Namensvorrang behebt das. Alle Zuordnungen wurden einmal von mir gegen den Namen gelesen. Das ist **keine** unabhängige Prüfung.
- Nicht belegt, bewusst: Letná Park, Schloss Troja, 12 Lokale. Für Lokale gibt es oft keinen Wikidata-Eintrag mit Koordinaten. `wikidata_candidates_unverified` sind nur Hinweise.

## Noch zu tun (von Hand)

1. Für die 14 unbelegten Fälle den richtigen Ort festlegen (Google-Place-ID oder Koordinaten) und `label_status` auf `human-verified` setzen.
2. Hinzufügen: eigene echte Ideen aus den Alben, besonders Fälle, in denen die App heute das falsche Bild zeigt. Ziel ab hier: mindestens 30 % echte Fälle.

## Prüfen

```bash
deno test --allow-read supabase/tests/place_photo_golden/validate_golden_test.ts
```

## Messlauf (Stand 22.10.2026)

```bash
export WIKIMEDIA_USER_AGENT="AlbumGoldenSet/1.0 (private travel app)"
deno run --allow-net --allow-read --allow-write --allow-env run_baseline.ts <name> <pfad-zu-_shared>
python3 make_report.py results/<neu>.json results/<alt>.json   # erzeugt results/bericht.html
```

Ruft die Wikimedia-Bildsuche von `place-photo` lokal auf (nur lesend). Wikimedia drosselt, ein Fall braucht 30–40 s, ein Volllauf ca. 1 Stunde.
Erste Teilmessung (20 von 100, neue Fassung): Treffer bei den meisten Prager Sehenswürdigkeiten, **kein Bild** bei Strahov-Bibliothek und Astronomischer Uhr.
Der vollständige Lauf steht noch aus. Ergebnisse liegen in `results/` (nicht im Git).
