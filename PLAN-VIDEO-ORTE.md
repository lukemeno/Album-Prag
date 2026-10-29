# Plan: Alle Orte aus Reels und Videos übernehmen · Entwurf 28.10.2026

Status: Vorschlag, nichts umgesetzt. Start erst nach Freigabe. Kein Push, kein Backend-Deploy.

Entscheidung des Nutzers (28.10.): Orte aus dem Begleittext kommen über den Link. Orte, die nur im Video vorkommen, kommen über „Video öffnen“ (Bildschirmaufnahme oder gespeichertes Reel aus Fotos). Kein Video-Download von Instagram-Servern.

## 1. Befund (im Code und am Beispiel geprüft)

- Beispiel `instagram.com/reel/DOP_gWtiB2X`: Ohne Anmeldung liefert Instagram den vollen Begleittext in `og:description` (1.321 Zeichen). Er nennt 7 Orte (Žižkov-Fernsehturm, Holešovice, Černý-Skulpturen, Moldau-Tretboote, Střelecký-Insel, Technisches Nationalmuseum, Letná). Die „10 Things“ des Titels stehen nur im Video. Geprüft im Browser, **nicht** mit der URLSession der App.
- Heute: `OEmbedService.preview` holt Titel und Beschreibung. `CollectionPlaceExtractor.candidates` sucht groß geschriebene Wörter und gibt höchstens 12 Kandidaten zurück. `CollectionPlaceResolver.resolve` prüft davon höchstens 6 nacheinander per Apple Maps (`CollectionViews.swift:281`). Jeder Treffer wird einzeln über den Orts-Editor übernommen.
- Die Share-Extension nimmt nur Text und URL an, kein Video.
- Deployment-Ziel iOS 17. `SpeechAnalyzer`/`SpeechTranscriber` und `FoundationModels` (KI auf dem Gerät) gibt es erst ab iOS 26 (im SDK 27.1 geprüft). Vision-Texterkennung gibt es ab iOS 13.
- Abhängigkeit: Im Debug-Build füllt `configureQA` jede leere Reise mit Prag-Daten (`AlbumApp.swift:176`). Das verfälscht jeden Gerätetest mit neuen Reisen und muss zuerst behoben werden (Paket 0).

## 2. Ablauf für Nutzer

1. Reel-Link teilen oder einfügen. In der Sammlung erscheint der Beitrag mit Vorschau.
2. „Orte finden“ wertet den Begleittext aus. Es erscheint eine Liste mit Name, Adresse und Häkchen. Orte, die schon in Ideen stehen, sind als „schon in Ideen“ markiert und nicht angehakt.
3. Steht dort „Im Video stecken vermutlich mehr Orte“ oder fehlt etwas: „Video öffnen“ → Fotos-Auswahl (nur Videos) → Fortschritt „Bilder lesen · Ton hören · Orte suchen“ → die Liste ergänzt sich, mit der Quelle „im Video“.
4. „N Orte übernehmen“ legt alle angehakten Orte auf einmal als Ideen an, verknüpft mit dem Beitrag. Danach springt die Ideen-Liste zum ersten neuen Ort und markiert die neuen als „Neu“.

Das Video verlässt das iPhone nicht. Album analysiert eine temporäre Kopie und löscht sie danach.

## 3. Technischer Ansatz

**Erkennen der Orte (eine Schnittstelle, zwei Quellen):**
`PlaceMentionExtractor.extract(text: String, destination: String?) async -> [PlaceMention]`
- iOS 26 mit Apple Intelligence: `LanguageModelSession` mit `@Generable struct PlaceMention { name, kind (Ort/Viertel/Aktivität/Essen), hint }`. Nur `kind == Ort/Viertel` gehen weiter. Essen ohne Lokalnamen (Svíčková, Trdelník) wird verworfen.
- Sonst: die bestehende Heuristik `CollectionPlaceExtractor` als Rückfall, mit ehrlicher Anzeige „Einfache Erkennung, eventuell unvollständig“.

**Video (Stufe 2), alles auf dem Gerät:**
- Bilder: `AVAssetImageGenerator` alle 1 s, höchstens 180 Bilder. Vision-Texterkennung (`.accurate`, Sprachen de/en/cs, sofern verfügbar). Gleiche Zeilen aus aufeinanderfolgenden Bildern werden zusammengefasst.
- Ton (nur iOS 26): `SpeechTranscriber` auf der Tonspur. Die Sprache wird per `NLLanguageRecognizer` aus Bildtext und Begleittext geschätzt, Standard Englisch. Fehlt das Sprachpaket, wird es per `AssetInventory` geladen, sonst wird der Ton übersprungen und der Hinweis angezeigt.
- Bildtext, Transkript und Begleittext gehen gemeinsam in den Extractor. Wegen des Kontextfensters wird in Abschnitten gearbeitet, die Ergebnisse werden zusammengeführt.

**Auflösen:** `CollectionPlaceResolver` ohne die feste Grenze von 6, mit höchstens 3 gleichzeitigen Apple-Maps-Anfragen und Abbruch nach 40 Kandidaten, weil Apple Maps die Anfragen drosselt. Dubletten gegen bestehende Ideen prüfen: gleicher Name oder unter 150 m Abstand.

**Übernehmen:** neue Store-Funktion `addPlaces(_:linkedTo postID:)`. Persistiert einmal und schreibt nur bei Erfolg (gleiches Muster wie `upsert`). Danach `linkCollectionPlace` je Ort.

## 4. Pakete (je ein Issue-Entwurf; Linear braucht erst eine Anmeldung)

**P0 · Debug-Seeding abschalten (S).** `configureQA` nur bei gesetztem `ALBUM_TEST_STORE`. Beleg: Simulator-Lauf ohne Test-Variablen, neue Reise „Paris“ bleibt leer (Screenshot), Bibliotheks-UI-Tests grün.

**P1 · Begleittext vollständig (M).** Prüfen, ob die URLSession der App bei Instagram `og:description` bekommt (Spike, Log). Extractor-Schnittstelle mit Heuristik-Rückfall, KI-Weg ab iOS 26, Grenze 6 aufheben, Häkchenliste, Dubletten-Markierung, „N Orte übernehmen“. Dateien: `CollectionPlaceSuggestions.swift`, `CollectionViews.swift`, `CollectionStore.swift`/`AlbumStore.swift` (nur `addPlaces`), neu `PlaceMentionExtractor.swift`.

**P2 · Video öffnen (L).** PhotosPicker (Filter Video, höchstens 3 Minuten) im Sammlung-Beitrag und im „+“-Menü der Ideen. Neu `VideoPlaceAnalyzer.swift` (Bilder, Bildtext, Ton) mit Fortschritt und Abbrechen. `Info.plist`: `NSSpeechRecognitionUsageDescription`. `PrivacyInfo.xcprivacy` prüfen. XcodeGen für neue Dateien.

**P3 · Gefunden, was hinzugefügt wurde (S).** Ideen-Liste springt zu den neuen Orten und zeigt „Neu“-Marken, Bestätigung „7 Orte übernommen“. Das deckt auch Beta-Test 5 aus dem Review ab.

**Reihenfolge:** P0 → P1 → P2 → P3. P2 hängt an der Extractor-Schnittstelle aus P1.
**Rollen:** Opus plant (dieser Entwurf), du prüfst, Sonnet setzt jedes Paket um, ich prüfe Diff, Build und Tests selbst.

## 5. Fehlerfälle, vor dem Code festgehalten

| Fall | Erwartetes Verhalten |
|---|---|
| Instagram liefert Login-Seite statt Text | „Begleittext nicht lesbar, öffne das Video“; kein Absturz, keine leeren Orte |
| Reel nur mit Musik, Liedtext im Transkript | KI verwirft Nicht-Orte; Bildtext bleibt Hauptquelle |
| Ort außerhalb der Reisestadt (> 60 km) | nicht vorgeschlagen |
| Gleicher Ort in Text und Video | ein Eintrag, Quelle „Text + Video“ |
| Ort schon in Ideen | markiert, nicht angehakt, nicht doppelt angelegt |
| Video zu lang oder ohne Tonspur | Grenze 3 Minuten mit Hinweis; ohne Ton nur Bildtext |
| Gerät ohne iOS 26 oder ohne Apple Intelligence | Bildtext + Heuristik, Hinweis „einfache Erkennung“ |
| Sprachpaket fehlt, offline | Ton überspringen, Hinweis, Rest läuft |
| Abbrechen mitten in der Analyse | nichts gespeichert, temporäre Datei gelöscht |
| Apple Maps drosselt | Teilliste anzeigen, „Weitere suchen“ |
| Reise ohne Ziel | „Lege zuerst das Reiseziel fest“ statt stiller leerer Liste |
| App wird während der Analyse beendet | keine halben Ideen; temporäre Kopie wird beim nächsten Start gelöscht |

## 6. Prüfung (E2E, wiederholbare Belege)

- UI-Test „Begleittext“: Fixture mit dem Beispieltext, fester Resolver. Erwartet 7 Orte in der Liste, „7 Orte übernehmen“ → 7 neue Ideen mit „Neu“-Marke. Beleg: Screenshot und `album.json`-Auszug.
- UI-Test „Video“: kurzes eigenes Testvideo mit eingeblendeten Ortsnamen und gesprochenem Satz im Repo (`QA/fixtures`). Erwartet die eingeblendeten und gesprochenen Orte. Beleg: Screenshot und Log der Erkennungsschritte.
- Abbruch- und Dubletten-Fall je ein UI-Test.
- Geräteabnahme iPhone 15 Pro mit dem echten Reel als Bildschirmaufnahme. Dafür brauche ich einmal deine Soll-Liste der 10 Orte aus dem Video. Ziel: mindestens 8 von 10 und keine falschen Orte außerhalb Prags. Beleg: Screenshot der Liste.

## 7. Risiken und Grenzen

- Die Qualität der Bildtext-Erkennung bei tschechischen Sonderzeichen (ř, ů, ě) ist ungeprüft. Apple Maps findet meist trotzdem den Ort.
- Die KI auf dem Gerät ist klein. Bei langen Transkripten kann sie Orte übersehen. Deshalb abschnittsweise und immer mit Häkchenliste, nie automatisch speichern.
- Vor iOS 26 deutlich schwächer (keine Tonauswertung, nur Heuristik). Ob iOS 26 Mindestversion für V1 wird, ist eine spätere Produktentscheidung, nicht Teil dieses Plans.
- Instagram kann den öffentlichen Begleittext jederzeit sperren. Dann bleibt „Video öffnen“ der Weg.
- `LINK-ENRICHMENT-PLAN.md` (03.10.: „keine Auswertung des Videoinhalts“) wird durch die Entscheidung vom 28.10. für vom Nutzer geöffnete Videos abgelöst. Der Eintrag kommt bei Umsetzung ins `Decision Log`.
