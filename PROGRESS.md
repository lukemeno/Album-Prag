# Album – Stand
- Neues natives SwiftUI/Xcode-Projekt; Workspace enthielt keinen Code.
- Figma 6:7, 6:62, 23:6 gelesen. Fotos, Logo, Typografie und Farbtokens werden übernommen.
- Ziel: Home, Inbox-Swipe, MapKit/Ortsuche, PDF, lokale Speicherung und gemeinsame Supabase-Reise.
- Prag 4.–9.10.2026, Hotel Urban Crème. Figma-Flugdaten nur Entwurf.
- Umgesetzt: SwiftUI-App mit Home, Inbox-Wischen, Karte/MapKit, Place-Details, PDF-Import/PDFKit, lokaler Persistenz und Supabase-Synchronisierung über privaten Einladungslink.
- Backend: anonyme Auth-Sitzungen, RLS für vier Tabellen, private PDF-Ablage, Edge Functions für gehashte Einladungen und Realtime-Abgleich.
- Entfernt: CloudKit, App Groups und Share Extension. Dadurch ist die Signierung mit einem kostenlosen Personal Team möglich.
- Assets: originale Figma-Fotos, Zwei-Türme-Logo, Icons, Fraunces, Instrument Serif und IBM Plex Sans/Mono.
- Prüfung: Build für iPhone-Simulator erfolgreich; 11 Unit-Tests, 1 UI-Test und 2 Deno-Tests erfolgreich. Beide Edge Functions bestehen `deno check`.
- Offen: Supabase-Projekt anlegen, Migration und Edge Functions deployen, URL und Publishable Key eintragen und den Zwei-Geräte-Abgleich mit echten Konten prüfen.

## 23.09.2026 – Redesign „Kreuzstich“ (Branch `design/kreuzstich`)
- Neue Welt: Leinen, Garn, Kreuzstiche (alles von SwiftUI gezeichnet, keine Bilddateien). Produktgrundlage in `PRODUCT.md`, Interaktionen in `Design/INTERAKTIONEN.md`.
- Tabs heißen jetzt Reise, Ideen, Karte (native iOS-Tab-Leiste). „Frankieren/Zurücklegen“ heißt jetzt „Dafür/Später“.
- App-Sprache ist Deutsch (`CFBundleDevelopmentRegion: de`), damit auch System-Knöpfe deutsch sind.
- Gemeinsam entscheiden pro Person: Vorschläge der anderen Person bleiben in den eigenen Ideen, bis man selbst abstimmt; beide dafür = Magnet-Klick. Stimmen werden beim Abgleich vereinigt.
- Tagesplan mit Reihenfolge, Dunkelmodus.
- Behoben: „new row violates row-level security policy“. Ursache: unsignierte Test-Builds (`CODE_SIGNING_ALLOWED=NO`) können die Sitzung nicht im Schlüsselbund speichern und schreiben ohne Token (HTTP 401). Außerdem prüft die App jetzt vor jedem Abgleich ihre Mitgliedschaft und tritt mit der gemerkten Einladung wieder bei; beide iPhones merken sich die Einladung. Live geprüft am 23.09. mit signiertem Simulator-Build.
- Offen: Test auf zwei echten iPhones.

## 24.09.2026 – Design-Politur (Critique → Polish)
- Einheitliche Bausteine in `Stitch.swift`: Abstände 4/8/12/16/24/32, Radien 8/16/24, drei Schattenstufen, `stitchCard()`, `PerforationLine`. Alle Bildschirme nutzen sie; `AlbumStyle`, `AlbumButton`, `StampPin`, `TabHeader` und `BoardingPassView` sind entfernt.
- Navigation: echte Navigationsleisten mit Titel (Ideen, Karte), „Idee hinzufügen“ immer oben rechts, Unterlagen/Tagesplan/Teilen im „Mehr“-Menü. Tab-Leiste bleibt die native Glas-Leiste; Ideen-Tab zeigt, wie viele neue Ideen die andere Person gesammelt hat.
- Schrift nur noch über System-Textstile (skaliert mit Dynamic Type). Die vier Schriftdateien werden nicht mehr registriert.
- Kontrast: gefüllte Flächen nutzen im Dunkelmodus `redFill`, Text `red` (hell genug).
- Alle Tippziele mindestens 44 pt (Filter, Tag-Menü, Rückgängig, Stecknadeln als echte Buttons).
- Text: durchgehend „du“, Erklärsätze nur dort, wo noch nichts passiert ist; Autor nur, wenn es nicht du selbst bist; Linkvorschau lädt von selbst.
- Tagesplan mit Wochentagen und „Bearbeiten“-Knopf statt Dauer-Sortiermodus.

## 28.09.2026 – Typischere Ortsfotos (Edge Function `place-photo`)
- Ursache falscher Fotos: Es wurde nur das Wikidata-Hauptbild genommen (Letná → Obstgarten statt Moldaublick).
- Jetzt: Kandidaten aus Hauptbild, Commons-Kategorie des Orts und Fotos im Umkreis von 400 m; Bewertung in `_shared/place_photo.ts` (Verwendung in Wikipedia, Auszeichnungen, Stichworte je Kategorie, Ortsname in allen Sprachen, Serien nur einmal, „View from …“ bei Sehenswürdigkeiten abgewertet, Demos/Karten/Logos raus). Antwort enthält zusätzlich `candidates` (bis 8) für eine spätere Auswahl in der App.
- Wikimedia drosselt Anfrageschwälle (HTTP 429): Anfragen gebündelt und nacheinander, bei 429 einmal warten, sonst Fehler statt still „kein Bild“.
- Live geprüft am 28.09.: Letná → „Vltava in Prague at sunset“, Karlsbrücke → Brücke von oben. Deployt (place-photo).
- Bestehende Wikimedia-Fotos werden einmal automatisch neu ausgewählt (`ranking` am Bild); eine Straßenansicht ersetzt nie ein altes Wikimedia-Foto.

## 28.09.2026 – Automatischer Tagesplan
- Tagesplan → „Automatisch planen“ zeigt einen Vorschlag (Tag + Reihenfolge + ungefähre Tageszeit), erst „Übernehmen“ ändert etwas. Schon geplante Orte bleiben (abschaltbar).
- Rechnung lokal auf dem iPhone, ohne KI-Modell (`DayPlanGenerator.swift`): nahe Orte an denselben Tag, neue Viertel an lange Tage, höchstens zwei Mal Essen & Trinken pro Tag, Runde ab Hotel (nächster Nachbar + 2-opt), Anreise-/Abreisetag aus den Flugzeiten verkürzt.
- Öffnungszeiten aus OpenStreetMap (Overpass, ohne Schlüssel), eigener Parser für die übliche Form (`OpeningHours.swift`); Exotisches gilt als unbekannt. Gescheiterte Abfragen werden beim nächsten Planen wiederholt. Gespeichert am Ort (`openingHours`, im JSON, keine Migration).
- UI-Test `testAutomaticDayPlanPreview` läuft nur mit vorbereiteten Orten (`TEST_RUNNER_ALBUM_PLAN_STORE`) und Netz.
- Später möglich: Agent obendrauf für Wünsche in Worten; Apple Foundation Models für Tagesnamen.
- Zwei Mal Essen & Trinken nie direkt hintereinander (`separateMeals`).

## 29.09.2026 – Karte mit Orts-Übersicht (impeccable shape → Bau)
- Blatt von unten auf der Karte (`PlacesDrawer.swift`) mit drei Höhen, gesticktem Griff (Tippen oder Ziehen), Filtern, „Automatisch planen“ und „Bearbeiten“. Bewusst Teil der Ansicht statt Systemblatt, damit die Tab-Leiste erreichbar bleibt.
- Liste nach Tagen (Unterkunft zuerst, „Noch ohne Tag“ zuletzt, während der Reise „Heute“ mit Sprung dorthin). Jeder Ort als Stoffkarte: Art, Tageszeit, „bis 18:00“, Foto-Streifen (bis zu 3 Fotos), Route · Tag ändern · Details.
- Ersetzt das Tagesplan-Blatt und die schwebende Ortskarte; „Tagesplan“ im Mehr-Menü öffnet die Karte mit ausgeklappter Liste.
- Karte und Liste verbunden: Ort antippen → Karte fliegt hin, Rahmen im Heftstich; Nadel antippen → Liste springt zum Ort.
- Fotos: `Place.gallery` (bis zu zwei weitere Wikimedia-Fotos samt Urheber, im JSON, keine Migration); Vorschaubilder in festen Wikimedia-Breiten (andere liefern HTTP 400); größerer URL-Zwischenspeicher für schwaches Netz.
- Behoben dabei: Fotos, die über ihren Rahmen hinausragen, fingen Tipps auf Knöpfe darüber ab (`AlbumPhoto` hat jetzt eine begrenzte Tippfläche).

## 29.09.2026 – Designschema festgehalten und durchgesetzt (impeccable layout)
- `DESIGN.md` (+ `.impeccable/design.json`) beschreibt das Schema: Farben als Tag/Nacht-Paare, Systemtextstile, Abstände 4/8/12/16/24/32 mit Rand 16, Radien 8/16/24, drei Höhenstufen, feste Größen (`Stitch.Size`: Tippfläche 44, Knopf 56, Vorschaubild 44), Regeln wie „12 zusammen, 32 getrennt“.
- Durchgesetzt: Flug-/Hotelkarten als flache Stoffkarten ohne Heftstich, „Heute“ mit Wochentag und 16 innen, Liste auf der Karte im selben Rhythmus wie Unterlagen, Lücke im Ortsdetail entfernt, eigene Schatten und feste Schriftgrößen ersetzt, Griff-Tippfläche 44.
- Bewusst ausgenommen (Zeichnungsmaße): Nadel-Ring, Herzhälften, Briefschlitz, Kalendergröße; Polaroid-Schatten beim Ziehen.
- UI-Test `testScreenTour` fährt alle Bildschirme ab (mit `TEST_RUNNER_ALBUM_TODAY` auch während der Reise).

## 30.09.2026 – Briefkasten per Finger
- Die Karte wird nicht mehr automatisch eingeworfen: Der Finger zieht sie nach oben in den Schlitz (nur Y, halbe Geste = halber Zustand, Maske an der Schlitzkante bleibt). Ab 40 % Weg (oder vorhergesagtem Ende) wirft sie von selbst ein, Selection-Haptik beim Überschreiten, Klappe mit `.impact(.heavy)`; zu früh losgelassen federt sie zurück.
- Erfolg ohne Grün: die gestrichelte rote Naht schließt sich (`SeamRing`), danach kommt aus demselben Schlitz ein Zettel „Liegt bei Ideen“ (mit Partnernamen, wenn genau ein weiterer Name im Album vorkommt). Der Knopf unten wird „Nach oben einwerfen“ → „Wird eingeworfen …“ → „Eingeworfen“; Tippen wirft automatisch ein, VoiceOver hat die Aktion „Einwerfen“.
- Speichern bleibt unverändert beim Tipp auf „Sichern“ (`store.upsert`); das Ziehen ist nur Ritual, keine Idee geht verloren oder wird doppelt gespeichert („Speichern“ ist während des Rituals gesperrt).
- Bewegung reduzieren: keine Karte zum Ziehen, Zettel wird eingeblendet, dann schließt der Editor (vorher wurde direkt geschlossen).
- Behoben dabei: Die Tastatur blieb nach „Speichern“ offen und verdeckte Karte und Knopf.
- UI-Test `testLetterSlotThrow` läuft nur mit Wegwerf-Store (`TEST_RUNNER_ALBUM_SLOT_STORE=slot-…`).

## 30.09.2026 – Ideen-Stapel lebendig (Auffächern, Anheben, Foto groß, Schild)
- `InboxView.swift`: hintere Karten fächern beim Erscheinen auf und federn zurück; die oberste Karte hebt sich beim Ziehen (1,05, tieferer Schatten) und neigt sich mit der Geschwindigkeit; Foto im Vollbild (`PhotoViewer`, eigener Zoom aus dem Polaroid-Rahmen, kein `matchedGeometryEffect`, weil das Polaroid gedreht ist und die Zielansicht ein `fullScreenCover` ist); das Entscheidungsschild füllt sich mit Garn und rastet an der Schwelle ein.
- Briefkasten nachgebessert: deckender Hintergrund, erledigter Knopf mit Häkchen.
- UI-Test `testInboxStack` läuft nur mit Wegwerf-Store (`TEST_RUNNER_ALBUM_INBOX_STORE=slot-…`) mit offenen Ideen.
- Bekannt: Das Vollbildfoto füllt den Rahmen (Zuschnitt), es zeigt nicht das ganze Foto.

## 30.09.2026 – Eingabefeld mit Vorstich und Nadel
- `StitchTextField` (Namensabfrage und Einstellungen): Vorstich unter dem Text, Nadel folgt mit kleiner Verzögerung; die Breite misst ein unsichtbarer Text in gleicher Schrift (`onGeometryChange`). `NamePrompt`: Hand-Plopp beim ersten Buchstaben.
- UI-Test `testNamePromptStitch` (nur mit `TEST_RUNNER_ALBUM_SHOT_DIR`) startet die App mit `-album.myName ""`, tippt nie „Los geht’s“, damit der echte Name im Simulator unberührt bleibt.

## 01.10.2026 – Ja, Nein, Offen
- Ideen: rechts „Ja“, links „Nein“, eigener Knopf „Offen“; VoiceOver bietet alle drei Aktionen.
- „Nein“ ist eine persönliche Stimme (`passedBy`), keine globale Zurückstellung. Andere Personen können weiterhin entscheiden.
- „Offen“ stellt die Idee nur für den aktuellen Durchgang zurück, ohne Speicherung oder Synchronisierung einer Stimme. „Offene Ideen ansehen“ holt sie zurück; Rückgängig funktioniert auch hier.
- Bestehende Aufnahme auf die Karte bei einer Ja-Stimme bleibt unverändert.
- Prüfung: Simulator-Build erfolgreich; 39 Unit-Tests (1 übersprungen) und 1 UI-Test ohne Fehler.

## 01.10.2026 – Einladung einlösen (impeccable animate)
- Ein Einladungslink öffnet jetzt ein Vollbild statt still beizutreten (`Stitch/InvitationMoment.swift`, eingehängt in `AlbumApp.swift`): gestickte Fahrkarte „Prag · 4.–9. Oktober“ (Absender nur, wenn bekannt; der Link trägt heute keinen). Karte nach oben in den Schlitz ziehen oder „Einladung einlösen“ tippen; erst ab der Schwelle beginnt `store.joinSharedTrip` (unverändert). Knopf: „Einladung einlösen“ → „Album wird geöffnet …“ → „Album ansehen“, dazu druckt der Schlitz einen Zettel („13 Orte · 5 Tage“ aus den geladenen Daten).
- Fehler: Klappe öffnet sich, Karte federt zurück, Fehlertext ruhig über dem Knopf (kein Alert), erneut versuchbar. Schließen-Knopf oben rechts, solange kein Beitritt läuft.
- Mechanik herausgezogen: `SlotScene` in `Stitch/LetterSlot.swift` (Schlitz, Zug-Geste, Schwelle 40 %, Naht, Zettel, Knopf-Morph, `commit`-Hook). `LetterSlotDrop` (Briefkasten) ist jetzt ein dünner Aufsatz darauf; Verhalten und Zeiten unverändert, `testLetterSlotThrow` läuft wie vorher.
- Bewegung reduzieren: Karte bleibt stehen (keine Geste), Knopf löst aus, Karte und Zettel werden überblendet.
- Debug: `ALBUM_DEMO_INVITE=ok|fail|failthenok` (optional `ALBUM_DEMO_SENDER`) zeigt den Moment mit simuliertem Beitritt, ruft nie Supabase auf. UI-Test `testInvitationMoment` (neue Datei `AlbumUITests/AlbumMotionUITests.swift`, braucht `TEST_RUNNER_ALBUM_MOTION_STORE=slot-…`).

## 01.10.2026 – Abgleich-Insel (impeccable animate)
- `Stitch/SyncIsland.swift`: kleine Kapsel links in der Leiste der Reise-Seite (dort steht sonst nichts). Pulsiert dezent, wenn ein Abgleich länger als 0,5 s dauert (kurze bleiben unsichtbar). Bringt der Abgleich etwas von der anderen Person, wächst sie auf („Mia hat 2 Ideen eingeworfen · 1× Ja“, Text blendet nach der Hülle ein) und klappt nach 5 s oder per Tipp zu; jederzeit unterbrechbar. Ohne Neuigkeit bleibt sie klein und verschwindet.
- Ermittlung in `AlbumStore.sync`: Stand vorher/nachher vergleichen (`SyncChange.between`): neue Orte anderer Autoren, neue Ja-Stimmen anderer auf schon bekannten Orten. Eigene Ideen und Stimmen zählen nicht, ebenso wenig Stimmen auf neuen Ideen und der erste Abgleich nach dem Beitritt. Keine Schema- oder Supabase-Änderung.
- Beim Herunterziehen zum Abgleichen wartet die Insel (`refreshing`), damit sie nicht mit Spinner und Tram-Klingel kollidiert; Neuigkeiten erscheinen danach.
- Bewegung reduzieren: kein Pulsieren, Hülle springt, Text blendet ein.
- Debug: `ALBUM_DEMO_SYNC=1|none` simuliert Abgleich mit/ohne Neuigkeiten, schreibt nichts. UI-Test `testSyncIsland` (`AlbumMotionUITests.swift`).
- Bekannt: Bei sehr schmalen iPhones oder großer Schrift schrumpft der Text bis 80 %, danach wird er gekürzt.

## 01.10.2026 – Foto-Stapel im Ortsdetail (impeccable animate)
- `Stitch/PhotoStack.swift`: Hat ein Ort mehrere Fotos (Hauptfoto + `gallery`), liegen sie im Ortsdetail (`TripMapView.swift`, `PlaceDetail`) als kleiner Stapel: die hinteren leicht versetzt und gedreht (±2,5°). Horizontal wischen blättert zyklisch; die oberste Karte folgt dem Finger (Neigung mit dem Weg), die hinteren rücken anteilig nach vorn (halbe Geste = halbe Bewegung). Ab 80 pt oder vorhergesagtem Ende fliegt sie seitlich weg und gleitet von hinten wieder in den Stapel; zu früh losgelassen federt zurück. Senkrechtes Wischen scrollt weiter die Seite.
- Gleichwertig ohne Geste: Zähler „1 / 3“ oben rechts (44 × 44 Tippfläche) blättert weiter, VoiceOver hat „Nächstes Foto“ und „Foto vergrößern“. Tippen aufs Foto öffnet `PhotoViewer` (aus `InboxView.swift`, jetzt nicht mehr privat, mit optionalem `photo`) mit dem Bildnachweis des gewählten Fotos.
- Ein einziges Foto: unverändert `PhotoCard`, kein Stapel. Bewegung reduzieren: nur die vorderste Karte, Blättern per Wisch oder Zähler überblendet.
- `PhotoCard` bekam `thumbnailWidth` (der Stapel lädt vorn 960 pt breit wie die Liste, sonst luden Galerie-Fotos nicht).
- UI-Test `testPhotoStack` (`AlbumMotionUITests.swift`, Café Savoy im Demo-Store).
- Ungeprüft: Das Standbild mitten im Zug zeigt wegen langsamer Wikimedia-Antwort einen Platzhalter; die Bewegung selbst sah ich nur an Standbildern vorher/nachher und am Zählerstand.

## 01.10.2026 – Flug wird Bordkarte (impeccable animate)
- `Stitch/BoardingPass.swift` (`FlightTicket`): Das angeheftete Anreise-Ticket unter „Angeheftet“ (bisher `PinnedTicket`, das nur zu den Unterlagen führte) wächst bei Tippen an Ort und Stelle zur Bordkarte (Hülle mit weichem Überschwingen, response 0,5 / damping 0,72; nach 150 ms blendet der Inhalt ein): Abflug- und Ankunftszeit, Route, Flugnummer, Datum, „Am Flughafen“, Rückflug in einer Zeile. Schließen (Knopf oder Tippen) kehrt um und ist jederzeit unterbrechbar. Der Weg zu den Unterlagen bleibt: Knopf „Reiseunterlagen“ in der offenen Karte. Ohne Flugdaten führt das Tippen wie vorher direkt zu den Unterlagen.
- Beim Aufwachsen rollt die Reise-Seite so weit, dass die Karte über der Tab-Leiste steht (`ScrollViewReader` in `ReiseView`). `PinnedTicket` hat dafür `chrome: false` (nur Inhalt).
- Bewegung reduzieren: Hülle springt, Inhalt blendet über. UI-Test `testBoardingPass`.

## 01.10.2026 – Als besucht markieren per Wisch-Spur (impeccable animate)
- `Stitch/VisitedTrack.swift`: Im Ortsdetail ersetzt die Spur den Knopf „Als besucht markieren“. Daumen nach rechts, Garn füllt die Spur, Label „Als besucht markieren“ → „Loslassen“ (ab 85 %, Selection-Haptik) → „Besucht ✓“ (gesperrt). Zu früh losgelassen federt zurück. Tippen füllt die Spur von selbst, VoiceOver aktiviert sie. Erfolg setzt `visited = true` per `store.upsert`; ist der Ort schon besucht, steht sie eingerastet da. Rückgängig weiter über „Schon besucht“ im Editor.
- Gestickter Stempel (`VisitedStamp`) landet mit Feder auf dem Foto (oben links); bei „Bewegung reduzieren“ blendet er nur ein.
- UI-Test `testVisitedTrack` auf einer Wegwerf-Kopie.

## 01.10.2026 – Papier & Marke, erste Umsetzungsstufe
- Grundlage: flacher Papiergrund, Tinte/Burgunder, Hell/Dunkel-Paare, Haarlinien und ruhigere Schatten. Abstandsskala 4/8/12/16/24/32/48, Seitenrand 20; Radien 12/20/28; Tippziel 44, Button 52, Vorschaubild 56.
- Gemeinsame Komponenten in Stitch.swift: native Symbole, Buttonzustände inklusive Laden/Gesperrt/Bewegung reduzieren, AlbumSectionHeader, AlbumPlaceRow, StampPhoto/StampBorder. API-Namen bleiben kompatibel.
- Reise: kompakter Prag-Kopf, reales Ortsfoto, Tagesauswahl 4–9, Plan des gewählten Tages, Unterkunft/Unterlagen, beschlossene Orte als Markenfotos. Kalender/Glocke/Brückenmotiv entfernt; Bordkarten- und Sync-Abläufe erhalten.
- Unterlagen: gemeinsame Überschrift und konsistente Fertig/Bearbeiten-Kopfzeile. Teilen: Ladezustände.
- DESIGN.md und generierter Designkatalog beschreiben die neue Grundlage und kennzeichnen ausstehende Ansichten ausdrücklich.
- Prüfung: Simulator-Build erfolgreich, 39 Unit-Tests (1 übersprungen), 4 UI-Tests ohne Fehler. Tagesauswahl zusätzlich im Dunkelmodus mit Accessibility-Medium geprüft; Feldhöhe nach Screenshotbefund mit @ScaledMetric korrigiert und erneut geprüft. Screenshots des Rundgangs gespeichert. Modelle, Speicherung und Backend unverändert.
- Offen: gezieltes Layout für Ideen (Ja/Nein gleichwertig, Offen separate Textaktion), Kartenblatt/Ortsdetail/Fotostapel/Namensfeld. Externer Opus-Worker hat nach 4 UI-Dateien wegen Berechtigungsgrenzen abgebrochen; gleicher Modell-Retry meldet Sitzungslimit bis 13:10 Europe/Berlin. Zustimmung zum Modellwechsel auf Codex angefragt, noch nicht erhalten. Keine automatische Fortsetzung eingerichtet.

## 01.10.2026 – Papier & Marke, restliche Ansichten
- Nach Zustimmung zum Wechsel auf Codex im isolierten Checkout fortgesetzt; die bereits überarbeitete Reiseansicht bleibt erhalten.
- `InboxView.swift`: ruhende Karte aufrecht, Briefmarkenkante nur am Foto, natives Ja-Siegel statt Heftkreuz; Ja/Nein gleich breit und mindestens 52 hoch, Offen separat und mindestens 44 hoch. Auffächern, Ziehphysik, Geschwindigkeitsneigung, Magnet-Herzen bei gemeinsamer Zustimmung, Vollbildfoto und die abgeschlossenen Commit-Callbacks bleiben erhalten. Offen bleibt sitzungsbezogen; persönliche Nein-Stimme, Ja und Rückgängig verwenden dieselben Store-Aufrufe.
- `PlacesDrawer.swift`: ruhiger Kapselgriff, native Filter mit neutraler Haarlinie/Auswahlzustand, gemeinsame Abschnittsüberschriften und kompakte `AlbumPlaceRow` statt großer Fotostreifen. Kategorie, Zeitabschnitt, Schließzeit-Hinweis, Route, Tageszuordnung, Umsortieren, drei Höhen, Kartenauswahl und Heute-Sprung bleiben erhalten. Ortsaktionen verwenden bei Accessibility-Schriftgrößen zwei Zeilen.
- `TripMapView.swift`: native Kategoriesymbole auf Papier, durchgehende ruhigere Tageslinien; Kamera-, Auswahl- und Standortlogik erhalten. Ortsdetail mit aufrechten Fotos und Name/Kategorie/Adresse darunter, Route als Hauptaktion, Notizen/Bildnachweise als Gruppen; einzelne Fotos lassen sich ebenfalls vergrößern. Quelllinks, Lizenzhinweise, Bearbeiten/Fertig und Löschbestätigung bleiben erhalten.
- `Stitch/PhotoStack.swift`: konstante Ruhe-Neigung entfernt, Bildbeschriftung unter dem Foto; Galeriegesten, Zähler, Vollbild und Reduce-Motion-Pfad erhalten. `Stitch/VisitedTrack.swift`: neutrale Nebenaktion, skalierende Höhe und umbrechbares Label; Erfolg mit Cobalt auf dezent getönter Papierfläche. Geste, Speicherung, Zustände und IDs erhalten.
- `AlbumRoot.swift`: natives `StitchTextField` ohne Stickunterlinie/Nadel; Namensbindung, Fokus, Submit und Los-geht’s-Verhalten bleiben erhalten.
- `DESIGN.md` und `.impeccable/design.json`: tatsächliche Komponenten, Zustände, Typografie, Bewegung und Accessibility dokumentiert; ausdrückliche Legacy-Ausnahme für Einladung, Briefkasten und Bordkarte erhalten. Modelle, Backend und Stimmenstruktur unverändert.
- Prüfung: eigener generischer Simulator-Build unbestätigt; Abhängigkeiten aufgelöst, anschließend bei `actool --print-asset-tag-combinations` ohne Compilerdiagnosen stehengeblieben. Auf Parent-Anweisung beendet; Parent übernimmt den Build mit bestehendem Cache sowie Integration und Verhaltenstests. Keine Unit- oder UI-Tests durch diesen Worker.
- Integration: Patch in den Hauptcheckout übernommen, Designkatalog als JSON validiert und 13 geschützte Modell-/Speicher-/Backenddateien gegen 9251d67 geprüft: unverändert. Simulator-Build mit Xcode/iOS-SDK 27 erfolgreich; 39 Unit-Tests mit einem vorgesehenen Skip und ohne Fehler. UI-Rundgang und Gestenprüfung laufen noch; Simulator-Start unter hoher Systemlast verzögert.
- Abschlussprüfung: sechs UI-Regressionen/Rundgang bestanden; Fotostapel und Besucht-Spur bestanden; Ideenstapel mit Vollbild, Teilgeste, Ja-Commit, Nein und Rückgängig-Verfügbarkeit bestanden. Namensfeld nach Screenshotbefund von 76 auf mindestens 52 Gesamthöhe korrigiert und erneut geprüft. Tagesauswahl im Dunkelmodus mit Accessibility-Medium bestanden; Reise, Ideen und Karte anhand tatsächlicher Simulator-Screenshots visuell geprüft. Insgesamt neun unterschiedliche UI-Tests / elf Ausführungen ohne Fehler. Computer/Device Hub weiterhin Timeout; kein Computer-Audit vorgetäuscht. Simulator auf Hell/Standardgröße zurückgestellt. Designregeln und Zustände dokumentiert; Einladungs-, Briefkasten- und Bordkartenrituale bleiben die dokumentierte gestalterische Ausnahme.
