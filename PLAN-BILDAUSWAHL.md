# Plan: Die richtigen Bilder für Ideen · Entwurf 22.10.2026

Status: nur Recherche und Vorschlag, nichts umgesetzt.

## 0. Grenzen der Recherche (ehrlich)

- **Reddit war nicht erreichbar.** Mein Suchwerkzeug blockiert reddit.com und stackoverflow.com. Aussagen „so machen es andere auf Reddit“ kann ich nicht belegen. Wenn du Threads kennst, schick sie mir als Link oder Text.
- Wie Wanderlog und andere Reise-Apps ihre Fotos wählen, habe ich **nicht gefunden**. Die Übersicht in Abschnitt 2 stützt sich auf Anbieter-Dokumentation und Fachartikel, nicht auf Interna anderer Apps.
- Alles, was als „Annahme“ markiert ist, ist meine Einschätzung ohne Beleg.

## 1. Wie die App es heute macht (im Code geprüft)

- **Ort finden:** Kandidaten werden nach Name, Entfernung und Adresse bewertet. Liegt der Zweite zu nah am Besten (Abstand < 50 Punkte), wird **nicht** geraten (`place_photo.ts`, `choosePlace`).
- **Foto wählen:** Wikimedia (Wikidata, Commons, Wikipedia). Bewertung (`scorePhoto`): Nutzungshäufigkeit, Qualitäts-Auszeichnungen („featured“, „quality“), Ortsname im Dateinamen, ob das Bild den Ort zeigt, Querformat, Auflösung, Entfernung. Ergebnis `verified` oder `suggested`.
- **Zusätze:** Tripadvisor (optional, per Schalter), Vorschaubild der verlinkten Seite (`og:image`, nur `suggested`), Google Places nur zur **Ortsauflösung**.
- **Bei Unsicherheit:** mehrere Kandidaten, der Nutzer wählt (Bildauswahl in der App).

Schwäche (Annahme, noch nicht an echten Fällen gemessen): Wikimedia kennt kleine Bars und Restaurants („Konzeptbar“, „Fresca“) vermutlich kaum, und allgemeine Begriffe („Pasta“) sind gar kein Ort.

## 2. Was die Quellen können (belegt)

| Quelle | Stärke | Einschränkung (laut Dokumentation) |
|---|---|---|
| **Wikimedia** (Wikidata P18, Commons „depicts“ P180) | freie Lizenzen, Orte und Sehenswürdigkeiten, Qualitätsmarken | wenig bei Lokalen; [Commons: Depiction](https://commons.wikimedia.org/wiki/Commons:Structured_data/Modeling/Depiction) trennt „wo aufgenommen“ von „was zeigt das Bild“ |
| **Google Places Photos** | größte Fotobasis, Bilder von Betreibern und Nutzern | Reihenfolge der Fotos **nicht dokumentiert**; Zwischenspeichern der Fotos nicht erlaubt, nur die Place-ID darf dauerhaft gespeichert werden; Namensnennung Pflicht ([Place Photos](https://developers.google.com/maps/documentation/places/web-service/place-photos), [Richtlinien](https://developers.google.com/maps/documentation/places/web-service/policies)) |
| **Foursquare Places** | Nutzerfotos mit **Klassifikation** (z. B. `food_or_drink`, `indoor_general`, `menu`, `logos`) → gezielt Außen-/Essensbilder wählen | Zwischenspeichern eingeschränkt, Quellenangabe Pflicht ([Place Photos](https://docs.foursquare.com/fsq-developers-places/reference/place-photos), [Nutzungsregeln](https://developer.foursquare.com/docs/usage-guidelines)) |
| **Tripadvisor** | gute Lokal-Fotos | höchstens 5 Fotos je Ort; laut Master Terms darf nur die `location_id` dauerhaft gespeichert werden; Marke muss mit angezeigt werden ([Caching](https://tripadvisor-content-api.readme.io/reference/caching-policy), Terra-Nachfolge angekündigt) |
| **Yelp Fusion** | gute Lokal-Fotos in Originalgröße | höchstens 3 Fotos, Zwischenspeichern bis 24 h (Angaben aus Zweitquellen, offizielle Seite nicht geprüft) |
| **Webseite des Ortes** (`og:image`) | zeigt genau diesen Ort | Urheberrecht liegt beim Betreiber; Favicons und Logos als Vorschaubild sind ein bekanntes Problem; nur als „Vorschlag“ |

**Wichtig für den App Store:** Google und Tripadvisor erlauben keine dauerhafte Speicherung ihrer Fotos. Wenn die App solche Bilder in den eigenen Speicher legt oder lange zwischenspeichert, müssen wir das **vor der Veröffentlichung klären** (Annahme: heutiger Tripadvisor-Pfad ist nur ein optionaler Schalter, Details nicht geprüft).

## 3. Methoden aus Forschung und Praxis (belegt, aber nicht für Orte getestet)

- **Zwei Stufen:** erst schnell viele Kandidaten holen, dann die besten wenigen genauer prüfen. Bild-Text-Modelle wie CLIP liefern die schnelle Ähnlichkeit, die Bildeinbettungen lassen sich einmal vorab berechnen ([INQUIRE](https://arxiv.org/pdf/2411.02537)).
- **Bild-KI als Prüfer:** Ein Sprach-Bild-Modell beurteilt „zeigt das Bild denselben Ort?“ mit JSON-Antwort und Begründung; bei Unklarheit gilt der bisherige Treffer ([Auditing](https://arxiv.org/pdf/2607.12818), [Refiner](https://arxiv.org/pdf/2406.17520), [Bewertungsskala 0–1](https://arxiv.org/pdf/2509.02129)). Hinweis dort: Wetter und Licht ausblenden lassen.
- **Marker-Abgleich:** Patente zu Fotos von Orten bewerten Textmarken gegen die Suchanfrage und bevorzugen die gewünschte Fotoart, etwa Außen- oder Innenansicht ([US 9460160](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9460160)).
- **Speisenfotos sind oft Rauschen:** Google-Galerien mischen Getränke, Innenräume und Gerichte; Filter sind normal ([Beispiel](https://apify.com/nomad-agent/dish-photo-matcher-managed)).
- **Grenzen:** CLIP verwechselt ähnlich aussehende Dinge ([RankCLIP](https://arxiv.org/pdf/2404.09387)). Für Orte gibt es keine fertige Bewertung, wir müssen selbst messen.

## 4. Vorschlag: Pipeline in fünf Schritten

1. **Suchbegriff einordnen** (günstiges Textmodell, JSON): *Ort mit Namen* („Konzeptbar“, „Franz-Kafka-Museum“), *Gericht oder Begriff* („Pasta“), *mehrdeutig* („Fresca“). Das Modell erzeugt auch Suchvarianten (Schreibweisen, Ortsnamen in Landessprache).
2. **Ort eindeutig bestimmen** (nur für Orte): Suche im Reisegebiet (Region, Koordinaten der Reise, Adresse falls vorhanden) → Place-ID und Koordinaten. Bei zwei ähnlich guten Treffern **nicht raten**, sondern nachfragen (existiert heute schon als Regel).
3. **Kandidaten sammeln** in fester Reihenfolge der Vertrauenswürdigkeit: Wikimedia → Foursquare (Klassifikation passend zur Kategorie) → Webseite des Ortes (`og:image`) → optional Google/Tripadvisor/Yelp zur Laufzeit ohne Speicherung. Für Gerichte: freie Commons-Kategorie oder Stockfoto-Dienst mit passender Lizenz.
4. **Bewerten:** bestehende Signale (Entfernung, Namensübereinstimmung, Auflösung, Qualitätsmarken) plus **Bildprüfung** der besten 3–5 Kandidaten: „Zeigt das Bild *diesen* Ort bzw. dieses Gericht? Außenansicht oder Signature-Gericht? Keine Logos, Speisekarten, Personen im Vordergrund?“ → Punktzahl 0–1 und Grund. Die Bildprüfung ist teuer und kommt nur nach dem Vorfilter.
5. **Entscheiden:** hohe Sicherheit → automatisch (`verified`); mittlere → bestes Bild als Vorschlag mit sichtbarem Hinweis; niedrige oder Streit zwischen Treffern → **drei Kandidaten zur Auswahl** (vorhanden). Gewählte Bilder protokollieren, um die Gewichte später zu verbessern.

**Regulatoren (Stellschrauben):** Mindestauflösung und Format, Entfernung zum Ort, Namensübereinstimmung, Kategorie ↔ Fotoart (Essen: Außenansicht oder Gericht; Museum: Fassade; Aussicht: Blick), Quellen-Rang, Lizenz, Schwellen für `verified` / `suggested` / Auswahl.

## 5. Prüfen, bevor wir bauen

- **Goldene Testliste** mit ca. 100 Orten, mit Absicht schwierig: „Konzeptbar“, „Pasta“, „Fresca“, „Franz-Kafka-Museum“, Ketten, gleiche Namen in verschiedenen Städten, nicht-lateinische Schrift.
- Je Quelle messen: Anteil richtiger erster Treffer, Anteil „kein Bild“, Anteil falscher Bilder. Falsche Bilder sind schlimmer als fehlende.
- Kosten je Ort (Textmodell, Bildprüfung, Foto-Abrufe) mit echten Preisen und Mengen schätzen; die Limits aus [PLAN-NUTZUNGSLIMITS.md](PLAN-NUTZUNGSLIMITS.md) gelten auch hier.
- Lizenz- und Speicherfragen je Quelle klären, bevor ein Anbieter aktiviert wird.

## 6. Entscheidungen für dich

1. Dürfen Bilder von **Google, Tripadvisor, Yelp** nur zur Laufzeit angezeigt werden (ohne Speicherung, mit Namensnennung), auch wenn das Kosten pro Anzeige bedeutet?
2. Soll die **Bildprüfung per KI** dabei sein (bessere Treffer, zusätzliche Kosten pro Idee) oder erst später?
3. Für **Gerichte und Begriffe** ohne Ort: freie Bilder (Wikimedia/Stockfoto-Dienst) oder gar kein Bild?
