# Vergleich HTML-Prototyp ↔ Swift-App · 20.10.2026

Nur Dokumentation und Vorschlag. Es wurde **kein Quellcode geändert**. Die drei uncommitteten Nutzerdateien (`AlbumStore.swift`, `InboxView.swift`, `expo/…/_layout.tsx`) sind am Ende per SHA-256 gegen den Ausgangsstand geprüft: unverändert.

## Prüfstand

| | |
|---|---|
| Swift-App | Repository `Album`, Branch `design/designsystem-v2`, HEAD `29af4c2`, frischer Debug-Build (Schema `Album`) |
| Gerät | iPhone 17, iOS-Simulator, 402 × 874 pt (Screenshots 3×) |
| Referenz | `album-app.html` im Scratch-Projekt, gerendert mit `screens/shoot.sh 874` (Headless-Chrome, Geräterahmen) |
| Testdaten | Isolierte Stores (`ALBUM_TEST_STORE=cmp-…`), `ALBUM_MY_NAME=QA`; Zustände: leer, `ALBUM_DEMO_MOTION` (1 Ort + Flüge), `ALBUM_DEMO_IMAGE_CHOICE` (1 Ort mit Koordinaten). Keine Schreibzugriffe auf die echte gemeinsame Reise. |
| Belege | `.qa-shots/vergleich-20261020/` (git-ignoriert): `nativ/` (16 Simulator-Bilder), `html/` (14 Referenzbilder), `paare/` (13 Nebeneinander-Bilder, HTML links, Swift rechts) |

**Bewusst nicht gezählt:** Inhaltsunterschiede aus echten Daten (Prag 4.–9.10. statt Demo 15.–18.10., keine erfundenen Teilnehmer, Wetter, Uhrzeiten, London/Paris/Lissabon). Gezählt werden Struktur, Optik und Funktion.

## Abweichungen mit Beleg

Art: **V** = visuell, **F** = funktional. „Bild" verweist auf Dateien in `paare/` bzw. `nativ/`.

| ID | Bereich | HTML-Prototyp | Swift-App | Beleg |
|---|---|---|---|---|
| F1 | Haptik | 35 Haptik-Aufrufe (select/light/medium/success/warning; u. a. beim Überfahren der Knoten, Auslösen, Speichern) | Im Bogen-Menü genau **ein** `.sensoryFeedback(.impact(.light))` beim Öffnen/Schließen; keine Haptik beim Knotenwechsel, Auslösen, Dwell, Speichern | `AlbumExperienceViews.swift:651`; `grep` in `album-app.html`. Im Simulator nicht fühlbar → Code-Beleg, am Gerät ungeprüft |
| V2 | Bogen-Menü | heller grüner Schleier; KI-Knoten „Reise fragen **KI**" wird im Untermenü aktiv (grün gefüllt) mit Kontext-Chip „Prag · Datum · n Stopps"; Labels „Plan für heute / Essen in der Nähe / Falls es regnet" | neutrales **graues Dim**; KI-Knoten „Assistent" ohne KI-Badge, ohne Aktiv-Zustand, ohne Kontext-Chip; Labels gekürzt „Plan heute / Essen / Regen"; FAB-Glyph „+" statt ✦ | `06-bogenmenue__fan.png`, `07-bogenmenue-ki__fansub.png`; Labels `AlbumExperienceViews.swift:704-714`. **Geometrie stimmt** (Knoten ≈ 51 pt, „Unterlagen" auf FAB-Höhe) → keine Abweichung |
| V3 | Farbsystem | grün (#164b3c) einziger Akzent | „Heute" in Rotbraun `(160,50,34)`; Pins/Thumbnails mit rosa Stempelrahmen (`rose`); Token `Stitch.red/redFill` sind grün belegt, heißen aber „red" | `15-karte-mit-ort__map.png`, `03-karte-leer.png`; `PlacesDrawer.swift:39,610`; `Stitch.swift:18-20,31`; `TripMapView.swift:370` (`StampPin`) |
| V4 | Tab-Leiste / FAB | deckende weiße Pille, Icon über Label; ein ✦-FAB | `.ultraThinMaterial`: Inhalt scheint **lesbar durch** (Ideen, Karte, Gruppe); Label neben Icon; FAB verdeckt Inhalt (Karte: Chevron der Ortskarte, Gruppe: Fußzeile); in Ideen **doppeltes „+"** (Kopf und FAB) | `02-ideen__ideas.png`, `04-gruppe__group.png`, `15-karte-mit-ort__map.png`; `AlbumExperienceViews.swift:193` |
| V5 | Ausgaben | Saldo-Karte volle Breite, Chips „Du/Lea/Max", EUR/CZK-Segment | Kopfkarte „Eure Reisekosten" **≈ 26–31 pt schmaler** als die Standardkarten (endet bei ≈ 350–356 pt, Standard bei 381,7 pt; am 3×-Bild gemessen), mit Schatten statt Rahmen; Schließen-Button 56 pt breit statt 44-pt-Kreis; Formular = iOS-Standardliste in neutralem Grau, Titel **„Ausgabe hi…" abgeschnitten**, „Bezahlt von" als Menü | `10-ausgaben__exp.png`, `11-ausgabe-formular__expense.png`; `NativeTravelExtras.swift:87,251`. Saldo/Verlauf/Ausgleichen **ungeprüft** (Testalbum ohne Ausgaben) |
| V6 | Unterlagen | dunkelgrüne Bordkarte (Inter), Titel + Lora-Untertitel, Offline-Hinweis | helle Flugkarten, Details in **Monospace** („Berlin", „EW4241", „ab 06:30"); Sheet ohne großen Titel/Untertitel | `09-unterlagen__doc.png`; `BoardingPass.swift` (ungelesen, Ursache der Schrift nicht verifiziert) |
| V1 | Plan-Kopf | „Heute in Prag", Datum (Lora), Wochentag-Chips „SO 4", „Tag 3 von 4", Avatare | statisch „Dein Plan"; Chips „Okt 4 … Okt 9" ohne Wochentag; „Route"/„Besucht" **doppelt** (Nächstes-Karte und Zeile) | `05-plan__plan.png`, `14-plan-mit-route.png`; `AlbumExperienceViews.swift:214` |
| V7 | Karte | volle Karte, nummerierte grüne Pins, gestrichelte Route, kompakte Nächstes-Karte, Tag-Chip | Stempel-Pins, hohes Listen-Sheet (≈ 45 % der Höhe, mit Filtern/„Tage planen"/„Ordnen"), warme orange Kacheln; Routenlinie bei 1 Ort nicht prüfbar | `15-karte-mit-ort__map.png`. Funktional reicher, optisch abweichend |
| V8 | Erinnerungen | Titel + „3 Fotos von euch dreien", randlose Fotos mit „Tag · Ort"-Chip, Auslöser + „Aus Fotos wählen" | kein Titel/Untertitel, Foto im Rahmen mit Namen, großer Kamera-Button zentriert, Mediathek nur als **Icon** oben rechts | `12-erinnerungen__mem.png` |
| V9 | Assistent | Vollbild, Kontext-Chips, Ergebniskarten mit „+ Plan"/„Im Plan", Folge-Chips | Sheet; in der Testantwort nur Text (Fixture) – Karten/Chips **ungeprüft**; Zeile „Standort verwenden / Web-Recherche" mit nicht eindeutig zuordenbarem Schalter | `08-assistent__aiaskfood.png` |
| F3 | Ideen | sichtbarer „+ Plan"-Button je Zeile | „Auf Tag legen" nur im …-Menü (2 Taps + Tagwahl); Chips „Essen & Trinken / Sehenswert / Aussicht" | `02-ideen__ideas.png`; `AlbumExperienceViews.swift:456` |
| V10 | Gruppe | Zeilen mit Live-Status („3 Dokumente · offline", „Du schuldest 47,50 €") | statische Untertitel („Flüge, Hotel und PDFs"); Live-Status mit Daten **ungeprüft** | `04-gruppe__group.png` |

## Gegenproben (zunächst verdächtig, **keine** Abweichung)

- **Route-Aktion:** Im Demo-Zustand ohne Koordinaten fehlte „Route". Mit Koordinaten erscheint sie (`14-plan-mit-route.png`, `AlbumExperienceViews.swift:304`).
- **Karte:** `NATIVE-PORT.md` nennt Kacheln als im Simulator nicht nachweisbar. Heute geladen und sichtbar (`15-karte-mit-ort.png`, 14:57). Einmalige Simulator-Beobachtung, nicht dauerhaft garantiert.
- **Halten → Ziehen → Loslassen:** öffnet „Unterlagen" auf Plan (`16-…png`) und auf Karte (je 1 erfolgreicher Versuch, Halten 900 ms, 80 ms-Schritte). Ein Versuch mit kürzeren Zeiten (700 ms/250 ms am Ziel) auf der Karte öffnete nichts. Ursache ungeklärt (Werkzeug-Timing oder Toleranz der Geste); als Beobachtung vermerkt, nicht als Fehler.
- **Menü-Geometrie:** stimmt mit dem Prototyp überein (siehe V2).

## Nicht geprüft

Ausgaben mit Daten (Saldo, Ausgleichen), Peek/Long-Press, Sheet-Drag und Rand-Wisch, Zoom-Übergänge, Reduce Motion, VoiceOver, kleine Höhe (667), Dark Mode, Assistent mit echten Ergebniskarten, Zwei-Geräte-Sync, fühlbare Haptik. Alles Gerät-/Hardware-Themen bleiben wie in `PROJECT-MAP.md` offen.

## Nebenbefund (nicht aus dem Vergleich)

Im Ideen-Menü löscht „Löschen" sofort (`copy.deleted = true`, `AlbumExperienceViews.swift:459`) ohne Rückfrage und ohne Rückgängig. Der Prototyp hat dafür keine Entsprechung (0 × „Rückgängig"), daher keine Vergleichs-Abweichung, aber ein Datensicherheits-Hinweis für den Hauptnutzer.

## Top 5 (Priorität nach Wirkung ÷ Aufwand/Risiko)

| # | Abweichung | Warum zuerst |
|---|---|---|
| 1 | **V2 + F1** Bogen-Menü angleichen (Schleier, KI-Badge/Aktiv, volle Labels, Haptik) | Kern-Interaktion der App und der ursprüngliche Haptik-Wunsch; ein Block in einer Datei, Geometrie bleibt unberührt |
| 2 | **V5** Ausgaben: Layoutfehler und Formular | Geldanzeige mit sichtbarem Layoutfehler und abgeschnittenem Titel; kleiner, klar abgegrenzter Eingriff |
| 3 | **V4** Tab-Leiste und FAB | betrifft jede Seite: Lesbarkeit durch Transparenz, Überdeckung, doppeltes „+" |
| 4 | **V3** Ein Akzent: Rot/Rosa entfernen | schärft das Designsystem („Grün als einziger Akzent"), geringes Risiko |
| 5 | **V1** Plan-Kopf und doppelte Aktionen | die meistgesehene Seite; Orientierung („Heute", Wochentag) |

Zurückgestellt (Backlog, nicht in den Fünf): V6 Unterlagen-Optik, V7 Karte (Pins/Sheet), V8 Erinnerungen, V9 Assistent, F3 „+ Plan" in Ideen, V10 Gruppen-Status.

## Begrenzter Umsetzungsplan (zur Freigabe)

Rahmen: ausschließlich die Hauptapp, jede Änderung klein und einzeln committbar, keine neuen Dependencies, keine Datenmodell-/Backend-Änderung, Nutzeränderungen bleiben unberührt. Am Ende: SHA-256-Vergleich der drei Nutzerdateien. Nach Plan-Freigabe empfohlener Ablauf nach `AGENTS.md`: Sol prüft den Plan, Luna setzt um.

1. **Bogen-Menü** · `Album/Native/AlbumExperienceViews.swift` (Fan-Block ca. 600–780)
   Eingriff: Scrim vom grauen Dim auf hellen Papier-Schleier; Label „Reise fragen" + KI-Badge, Aktiv-Zustand des KI-Knotens im Untermenü; volle Sub-Labels (Platz am linken Rand vorab messen); `.sensoryFeedback`: `.selection` beim Knotenwechsel, `.impact(.medium)` beim Auslösen, `.success` bei erfolgreicher Aktion. **Unverändert:** FAN-Koordinaten, Hold/Drag/Release-Logik, `accessibilityIdentifier`.
   Risiko: Labelbreite am rechten/linken Rand; Haptik hier nur im Code prüfbar.
2. **Ausgaben** · `Album/NativeTravelExtras.swift` (Zeilen ≈ 87 und 251)
   Eingriff: Kopfkarte auf volle Breite mit Rahmen statt Schatten; Schließen-Button auf Kreis 44 pt; Formular-Titel kürzen oder Titelzeile umbauen; Zeilenfarbe auf `Stitch.card`. Rechenlogik (Eurocent) unberührt.
   Risiko: gering; Betrags-Tests bleiben unverändert.
3. **Tab-Leiste/FAB** · `AlbumExperienceViews.swift:193` und Wurzel `AlbumExperienceRoot.swift`
   Eingriff: deckender Hintergrund (`Stitch.paper`) statt `.ultraThinMaterial`; unterer Inhaltsabstand für den FAB; „+" im Ideen-Kopf entfernen (FAB bleibt, `native-new-place` per FAB/Fan oder Menü erreichbar halten).
   Risiko: UI-Test-ID `native-new-place` darf nicht verschwinden → Test anpassen oder ID am verbleibenden Button halten.
4. **Ein Akzent** · `PlacesDrawer.swift:39` (+ Verwendungen), `Stitch.swift` (`rose`), `TripMapView.swift` (`StampPin`)
   Eingriff: Heute-/Hinweisfarbe auf Grün-Ton mit Kontrast ≥ 4,5:1; rosa Rahmen auf `Stitch.rule`/`paperDeep`. Pin-Form (Stempel) bleibt vorerst.
   Risiko: Kontrast im Dark Mode mitprüfen; Umfang der `rose`-Verwendungen vorab zählen.
5. **Plan-Kopf** · `AlbumExperienceViews.swift:214` ff.
   Eingriff: Titel „Heute in <Ort>" am heutigen Tag und Datum als Untertitel; Wochentag in den Tageschips; doppelte „Route/Besucht" (Zeile unter der Nächstes-Karte) für den nächsten Ort ausblenden. Wetter, Uhrzeiten und Entfernungsanzeigen ausdrücklich **nicht** erfinden.
   Risiko: Datumslogik (`ALBUM_TODAY`), bestehende Plan-Tests.

**Verifikation (E2E, keine nachträglichen Unit-Tests):** Build; vorhandene UI-Abläufe (Fan Halten/Ziehen, AI→Essen, Ausgaben-Neustart, Foto-Aktionen); Neuaufnahme derselben Zustände nach `nativ/` mit denselben Env-Variablen, Gegenüberstellung in `paare/`; Konsole ohne neue Fehler; Haptik als „ungeprüft am Gerät" ausweisen. Tests hängen laut Suche in `AlbumUITests`/`AlbumTests` nicht an den geänderten Label-Texten (Treffer: keine).

## Umsetzung · 20.10.2026 (Freigabe: Punkte 1–5 nacheinander, je ein Commit)

| # | Commit | Datei(en) | Ergebnis (Simulator, Vorher/Nachher in `.qa-shots/vergleich-20261020/paare/vorher-nachher__*.png`) |
|---|---|---|---|
| 1 | `aeec53f` | `Native/AlbumExperienceViews.swift` | Schleier hell (Papier 78 %), Knoten „Reise fragen **KI**" (im Untermenü grün aktiv), volle Unterlabels, Kontext-Chip „Prag · So, 4. Okt · 1 Ort", Haptik (mittel beim Öffnen und KI-Wechsel, leicht beim Schließen, Auswahl beim Überfahren). Geometrie, Geste und IDs unverändert |
| 2 | `f6da5de` | `NativeTravelExtras.swift` | Kopfkarte volle Breite mit Rahmen (Ursache: fehlendes `maxWidth` und doppeltes Padding), Titel „Neue Ausgabe" lesbar (✕/✓ statt Textbuttons), Zeilen in `Stitch.card`, Schließen-Button als Kreis |
| 3 | `ba315fe` | `Native/AlbumExperienceViews.swift`, `PlacesDrawer.swift` | Tab-Leiste deckend, gewählter Tab mit grünem Tint, FAB-Glyph ✦, Karten-Liste mit 128 pt Fußabstand |
| 4 | `6e35c61` | `PlacesDrawer.swift`, `Stitch/Stitch.swift` | „Heute"/Hinweise grün statt Rotbraun; Stempelrahmen aller Orte neutral (`Stitch.rule`) |
| 5 | `4554789` | `Native/AlbumExperienceViews.swift` | „Heute in Prag" am heutigen Reisetag, Wochentage in den Tageschips, Route/Besucht für den nächsten Ort nur einmal |

**Abweichungen vom freigegebenen Wortlaut (bewusst, jeweils kleiner):**
- **Punkt 3:** Das „+" im Ideen-Kopf blieb. Es ist die einzige direkte „Neue Idee"-Aktion. Die Verwechslung mit dem FAB-„+" ist stattdessen durch das FAB-Glyph ✦ (wie im Prototyp) gelöst. Folgeauftrag erledigt: Das Kopf-✦ (Assistent) ist entfernt (eigener Commit), der Assistent bleibt über FAB und „Mehr"-Menü erreichbar; `AssistantUITests` öffnen ihn jetzt über das Bogen-Menü (2/2 bestanden).
- **Punkt 4:** Nicht nur Rosa: `Place.mat` liefert für **alle** Kategorien Neutral, sonst bliebe eine halbe Pastellpalette (blau/gelb/grün/lila). Die Mat-Farben für Bordkarte, Einladung und Reise-Karte bleiben.
- **Punkt 5:** Kein Datum als Untertitel; es steht direkt darunter als Tagesüberschrift. Wetter, Uhrzeiten, Entfernungen nicht erfunden.
- **Punkt 2:** Zusätzlich der Schließen-Button der Erinnerungen (gleiche Ursache, gleiche Datei).

**Prüfung (20.10.2026, Repository `Album`, iPhone-17-Simulator, Commit `4554789`):**
- Simulator-Build erfolgreich nach jedem Punkt.
- `xcodebuild test`: **151 Unit-Tests, 0 Fehler, 4 übersprungen** (Live-Supabase-Gates ohne `ALBUM_LIVE_SUPABASE=1`); **`NativePrototypeUITests` 6/6 bestanden** (Home/Tabs, Fan öffnen/zurück, Halten→Ziehen→Unterlagen, KI→Essen mit Fixture, Ausgaben nach Neustart, Kamera/Mediathek getrennt). Ergebnis: `/tmp/cmp/tests.xcresult`, Log `/tmp/cmp/tests.log` (flüchtig).
- Sichtprüfung der Zustände aus der Befundtabelle nach jedem Punkt; SHA-256 der drei Nutzerdateien identisch zum Ausgangsstand.

**Weiterhin ungeprüft:** fühlbare Haptik am Gerät (nur Code und Simulator), Ausgaben mit Daten per Hand (Kopfkarte mit Saldo deckt nur der bestehende Ausgaben-UI-Test indirekt ab, ohne Bildvergleich), Dark Mode der neuen Farben (Kontrast rechnerisch ≥ 4,5:1 abgeschätzt, nicht gemessen), Peek/Sheet-Drag/Rand-Wisch/Zoom/VoiceOver. Zurückgestellt bleiben V6–V10 und F3 aus der Tabelle.
