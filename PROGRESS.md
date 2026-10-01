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
