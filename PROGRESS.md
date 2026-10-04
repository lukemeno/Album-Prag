# Album – Stand, 02.10.2026
- Native SwiftUI-App für die gemeinsame Prag-Reise (4.–9.10.2026): Ideen sammeln und abstimmen, Orte auf Karte und Tagesplan verbinden, Flüge/Hotel/PDFs ablegen, offline verfügbar halten und nach der Reise Fotos ansehen.
- Supabase ist im Projekt konfiguriert; gemeinsame Einladungen, lokale Warteschlange, Realtime und private PDF-Dateien sind implementiert. Die Ortsbildsuche wurde im bestehenden Backend aktualisiert und live geprüft.
- Aktuelles Designsystem: Briefmarken-Album, dokumentierte Farben/Typografie/Abstände/Radien, komponierte Text- und Flächenbuttons sowie Bewegungsmuster A–F mit gemeinsamen Timings in `Stitch.Motion` und Reduce-Motion-Varianten. Die kreative Motion-Richtung ist sichtbar in Kartenstapeln mit Fächerung/Neigung (Ideen und Fotos), gefülltem Wischfortschritt (Entscheidungen) und dem gemeinsamen Kapsel-zu-Blatt-Übergang (Karte).
- Karte und Liste teilen Auswahl, Scrollanker und Kamerakontext. Das Ortsblatt öffnet sich unten in Hochformat und links im Querformat; `Info.plist` deklariert alle vier Orientierungen. iOS ignoriert Hochkant umgedreht auf iPhone-Modellen ohne Home-Button.
- Release-Archiv und lokale Entwicklungs-IPA erfolgreich erstellt. IPA-ZIP intakt, Codesignatur gültig, Bundle-ID `de.privatealbum.prague`, arm64 und alle vier Orientierungen verifiziert. Das Entwicklungsprofil läuft am 08.10.2026 ab und enthält genau ein registriertes iPhone; keine Geräteinstallation wurde behauptet.
- Prüfung: jüngster Unit-Testlauf 47 bestanden, 1 übersprungen, 0 Fehler; darunter 3 Karten-Cluster-Tests und ein Offline-Retry-Test. Übersprungen wurde nur der optionale Parser-Test mit einem echten Reise-PDF, weil kein Dateipfad dafür bereitgestellt ist; synthetischer PDF-Import und -Parser sind getestet. Der vollständige Simulatorlauf davor hatte 45 bestanden, 14 optionale Prüfungen übersprungen, 0 Fehler. Die Accessibility-Audits für Reise, Editor, Ideen und die Karte mit ausgewähltem Ort bestehen mit 0 app-eigenen Funden. Der Karten-Audit deckte zusätzlich einen bei großer Schrift abgeschnittenen Textknopf auf; Kopfzeile und gemeinsame Textaktion passen sich jetzt an. MapKits Rechtslink erscheint in iOS 26.5 als anonymer Systemknoten und ist nur auf diesem Karten-Audit eng ausgenommen. Der Neustarttest bestätigt: Nach einer mit „Offen“ ausgeblendeten Karte erscheint die Idee wieder unentschieden; nur Ja/Nein werden als Stimme gespeichert. `git diff --check` ist sauber. Supabase Swift 2.55.2 meldet im Test eine nicht blockierende Warnung zur künftigen `authStateChanges`-Initialsession; die App verwendet aktuell direkt `auth.session`.
- Offen: Mac/iPhone entsperren und zwei echte iPhones mit persönlichen Konten verbinden; Einladung, Abgleich, Offline-Änderungen, PDF-Upload, echte Orientierung, VoiceOver und Touch-Gesten durchspielen. Für den 09.10. muss das Entwicklungsprofil vor Ablauf erneuert oder eine länger gültige Verteilung vorbereitet werden. TestFlight setzt ein bezahltes Apple-Developer-Konto voraus.
- Karten-Regression nachgezogen: Die Ziehgeste des Listengriffs wird nicht mehr als zusätzlicher Button-Tap gewertet. Der fokussierte UI-Test wählt einen Ort aus, schließt die Liste vollständig, öffnet sie wieder und prüft Hochkant, beide Querformate sowie die Rückkehr ins Hochformat anhand der Fenstergeometrie. Ergebnis auf iPhone-17-Pro-Simulator/iOS 26.5: 1 bestanden, 0 Fehler. Hochkant umgedreht bleibt in der App-Deklaration enthalten; iOS ignoriert es auf diesem Gerät ohne Home-Button. Screenshots: `/Users/alexandergorny/Documents/Codex/2026-10-01/such/work/album-qa/screens/map-*.png`.

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
- UI-Test `testAutomaticDayPlanPreview` läuft nur mit vorbereiteten Orten (`ALBUM_PLAN_STORE`) und Netz.
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
- UI-Test `testScreenTour` fährt alle Bildschirme ab (mit `ALBUM_TODAY` auch während der Reise).

## 30.09.2026 – Briefkasten per Finger
- Die Karte wird nicht mehr automatisch eingeworfen: Der Finger zieht sie nach oben in den Schlitz (nur Y, halbe Geste = halber Zustand, Maske an der Schlitzkante bleibt). Ab 40 % Weg (oder vorhergesagtem Ende) wirft sie von selbst ein, Selection-Haptik beim Überschreiten, Klappe mit `.impact(.heavy)`; zu früh losgelassen federt sie zurück.
- Erfolg ohne Grün: die gestrichelte rote Naht schließt sich (`SeamRing`), danach kommt aus demselben Schlitz ein Zettel „Liegt bei Ideen“ (mit Partnernamen, wenn genau ein weiterer Name im Album vorkommt). Der Knopf unten wird „Nach oben einwerfen“ → „Wird eingeworfen …“ → „Eingeworfen“; Tippen wirft automatisch ein, VoiceOver hat die Aktion „Einwerfen“.
- Speichern bleibt unverändert beim Tipp auf „Sichern“ (`store.upsert`); das Ziehen ist nur Ritual, keine Idee geht verloren oder wird doppelt gespeichert („Speichern“ ist während des Rituals gesperrt).
- Bewegung reduzieren: keine Karte zum Ziehen, Zettel wird eingeblendet, dann schließt der Editor (vorher wurde direkt geschlossen).
- Behoben dabei: Die Tastatur blieb nach „Speichern“ offen und verdeckte Karte und Knopf.
- UI-Test `testLetterSlotThrow` läuft nur mit Wegwerf-Store (`ALBUM_SLOT_STORE=slot-…`).

## 30.09.2026 – Ideen-Stapel lebendig (Auffächern, Anheben, Foto groß, Schild)
- `InboxView.swift`: hintere Karten fächern beim Erscheinen auf und federn zurück; die oberste Karte hebt sich beim Ziehen (1,05, tieferer Schatten) und neigt sich mit der Geschwindigkeit; Foto im Vollbild (`PhotoViewer`, eigener Zoom aus dem Polaroid-Rahmen, kein `matchedGeometryEffect`, weil das Polaroid gedreht ist und die Zielansicht ein `fullScreenCover` ist); das Entscheidungsschild füllt sich mit Garn und rastet an der Schwelle ein.
- Briefkasten nachgebessert: deckender Hintergrund, erledigter Knopf mit Häkchen.
- UI-Test `testInboxStack` läuft nur mit Wegwerf-Store (`ALBUM_INBOX_STORE=slot-…`) mit offenen Ideen.

## 30.09.2026 – Eingabefeld mit Vorstich und Nadel
- `StitchTextField` (Namensabfrage und Einstellungen): Vorstich unter dem Text, Nadel folgt mit kleiner Verzögerung; die Breite misst ein unsichtbarer Text in gleicher Schrift (`onGeometryChange`). `NamePrompt`: Hand-Plopp beim ersten Buchstaben.
- UI-Test `testNamePromptStitch` startet die App mit `-album.myName ""`, tippt nie „Los geht’s“ und hängt sein Standbild direkt an den Testbericht; der gespeicherte Name bleibt unberührt.

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
- Debug: `ALBUM_DEMO_INVITE=ok|fail|failthenok` (optional `ALBUM_DEMO_SENDER`) zeigt den Moment mit simuliertem Beitritt, ruft nie Supabase auf. UI-Test `testInvitationMoment` in `AlbumUITests/AlbumMotionUITests.swift` benötigt `ALBUM_MOTION_STORE=slot-…` mit vorbereitetem Einladungszustand.

## 01.10.2026 – Abgleich-Insel (impeccable animate)
- `Stitch/SyncIsland.swift`: kleine Kapsel links in der Leiste der Reise-Seite (dort steht sonst nichts). Pulsiert dezent, wenn ein Abgleich länger als 0,5 s dauert (kurze bleiben unsichtbar). Bringt der Abgleich etwas von der anderen Person, wächst sie auf („Mia hat 2 Ideen eingeworfen · 1× Ja“, Text blendet nach der Hülle ein) und klappt nach 5 s oder per Tipp zu; jederzeit unterbrechbar. Ohne Neuigkeit bleibt sie klein und verschwindet.
- Ermittlung in `AlbumStore.sync`: Stand vorher/nachher vergleichen (`SyncChange.between`): neue Orte anderer Autoren, neue Ja-Stimmen anderer auf schon bekannten Orten. Eigene Ideen und Stimmen zählen nicht, ebenso wenig Stimmen auf neuen Ideen und der erste Abgleich nach dem Beitritt. Keine Schema- oder Supabase-Änderung.
- Beim Herunterziehen zum Abgleichen wartet die Insel (`refreshing`), damit sie nicht mit Spinner und Tram-Klingel kollidiert; Neuigkeiten erscheinen danach.
- Bewegung reduzieren: kein Pulsieren, Hülle springt, Text blendet ein.
- Debug: `ALBUM_DEMO_SYNC=1|none` simuliert Abgleich mit/ohne Neuigkeiten, schreibt nichts. UI-Test `testSyncIsland` (`AlbumMotionUITests.swift`) erzeugt einen leeren, isolierten Store selbst; fixtureabhängige Motion-Tests benötigen `ALBUM_MOTION_STORE=slot-…`.

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

## 01.10.2026 – Button-Typografie und Zentrierung
- StitchButton: Subheadline Semibold (15 Punkt Standard), horizontal/vertikal zentriert, mehrzeilig zentriert; 16 Punkte horizontal und 12 vertikal innen, 8 zwischen Symbol/Spinner und Text. Mindesthöhe 52, längere Beschriftungen wachsen ohne Kürzung oder Schriftverkleinerung.
- Besucht-Spur: derselbe Textstil und dazu passende skalierende Höhe; Geste und Speicherung erhalten. DESIGN.md und Designkatalog aktualisiert; Nutzerpräferenz für ruhige Schriftgrößen und ausreichende Abstände gespeichert.
- Prüfung: Simulator-Build erfolgreich. Rundgang, Ideenstapel und Besucht-Geste bei Standardgröße bestanden; Tagesauswahl und Rundgang im Dunkelmodus mit Accessibility-Medium bestanden (fünf erfolgreiche Ausführungen, vier unterschiedliche Tests). Gerenderte Button-Layouts visuell geprüft. Zwei erste große Rundgänge scheiterten allein an der Startannahme, dass „Mehr“ sichtbar sein müsse; die native Toolbar ist dort zusammengeklappt. Rundgang wartet jetzt auf Tagesinhalt wie der Tagesauswahltest; Menüinteraktionen unverändert und abschließend bestanden.
- Designkatalog validiert, Diff geprüft, 13 Modell-/Speicher-/Backenddateien gegen 10cad29 unverändert. Keine neuen Kommentare. Simulator auf Hell/Standardgröße zurückgestellt.

## 01.10.2026 – Claude-Design übernommen
- Auf Nutzerwunsch Branch redesign/claude (85f9107) als Designgrundlage zusammengeführt. Fraunces/Instrument Serif, Pastell-Briefmarken, Papier/Poststempelrot, Tagesstreifen, Tickets und neue Navigation übernommen. Bildsuche und Speichermodelle werden separat bearbeitet.
- Offen statt Später entscheiden; zentrierte kleinere Buttontexte mit Innenabständen sowie umbrechende skalierende Besucht-Spur übertragen. Bestehende Offen-Persistenz- und Tagesauswahltests erhalten und an die neue Navigation angepasst.
- Prüfung: Simulator-Build und fünf UI-Prüfungen bestanden (Rundgang, Tagesauswahl, Offen/Neustart, Ideenstapel, Besucht-Geste). Der Neustarttest bestätigt, dass die Idee offen und ohne gespeicherte Stimme wieder erscheint. Echte Screens von Reise und Ortsdetail geprüft. Computer/Device Hub meldet Timeout; Simulator-Screens als tatsächliche Layout-Prüfung verwendet.

## 01.10.2026 – Präzisere Ortsbilder
- Ortsidentität: strengere Name-/Distanzprüfung, mehrsprachige Aliase, Adress-/Hausnummernprüfung und Ablehnung ähnlich guter unterschiedlicher Orte. Motivqualität und Ortsbezug getrennt; Hauptbild, Dateiname, Commons-Kategorie und strukturierte P180-Motivangaben fließen ein. Generische Umgebungspanoramen und Bilder vom Blick aus einem anderen Ort werden nicht automatisch gewählt.
- Auswahlversion 3: automatische Übernahme nur explizit zugeordneter Bilder; unsichere Treffer im manuellen Bildwähler mit Foto, Urheber und Quelle. Manuelle Auswahl über Neustart erhalten, veraltete Suchantworten bei Ortsänderungen verworfen. Eigene Fotos erhalten; bestehende Bilder bei Netzwerkfehlern erhalten. Keine neue Datenbankmigration oder kostenpflichtiger Dienst.
- Prüfung: 44 Unit-Tests (1 übersprungen), 24 Backend-Tests und acht UI-Testausführungen ohne Fehler. UI inklusive Bildauswahl/Speicherung/Neustart sowie Rundgang und Tagesauswahl im Dunkelmodus mit Accessibility-Medium. Ein erster Bildauswahltest musste die Quellenzeile vor der Sichtbarkeitsprüfung ins Sichtfeld scrollen; abschließende Prüfung bestanden. Die Resolver-Integrationstests verwenden kontrollierte API-Antworten.
- Server: place-photo im konfigurierten bestehenden Projekt prag-album erfolgreich aktualisiert. Live-Prüfung: Café Louvre HTTP 200 mit Auswahlversion 3, ohne Bildkandidaten; Karlsbrücke HTTP 500. Direkte lokale Wikimedia-Anfragen meldeten HTTP 429. Die Zuordnung ist durch Negativfälle und Integrationstests geprüft, reale Bildverfügbarkeit bleibt durch die externe API eingeschränkt.
- Tatsächliche Simulator-Aufnahmen und Designsystem nach outputs/album-briefmarke kopiert. Kein erfolgreicher Computer-Audit behauptet.

## 01.10.2026 – Live-Bildsuche repariert
- Reproduziert: Karlsbrücke lud bis zu 100 Dateien plus mehrere Metadaten-/Motivabfragen und verlor bei späterem HTTP 429 alle bereits gefundenen Bilder. Café Louvre wurde durch „Praha 1“ als vermeintliche Hausnummer verworfen. Drei reproduzierende Tests schlugen vor dem Fix fehl.
- Hausnummern am Ende der Straßenadresse erkennen, tschechische Bezirk-/PLZ-Angaben ausnehmen und Doppelnummern 1987/22 korrekt vergleichen. Strenge Ablehnung falscher Hausnummern erhalten.
- Eindeutige Wikidata-Zuordnung beendet Sprachsuche. Hauptfoto zuerst laden; Zusatzdaten optional. Kategorien/Umgebung auf 20 begrenzt, weitere Metadaten auf 24 begrenzt, unnötige P180-Abfragen vermieden. Anfrage-Timeout acht Sekunden, längeres Retry-After nicht durch voreiligen Retry missachten.
- Alternative: Wikipedia-Geosuche (cs/en) mit derselben strengen Namen-/Koordinatenprüfung; Fotos weiterhin über Commons mit Attribution. Falscher benachbarter Ort wird nicht gewählt. Cache je Edge-Prozess: erfolgreiche Ergebnisse eine Stunde, leere Ergebnisse eine Minute, Fehler nicht cachen; parallele identische Anfragen zusammenführen, maximal 128 Einträge.
- Erwartbare Quellenausfälle als HTTP 503 mit Retry-After. App/Speichermodelle/Design unverändert.
- Prüfung: 32 Backend-Tests ohne Fehler, Deno-Typprüfung und gezielter Diff-Check bestanden. Live nach Deployment: Karlsbrücke HTTP 200, vier Fotos, 2,3 Sekunden; Café Louvre HTTP 200, acht Fotos, 1,4 Sekunden. Wikipedia-Rückfall separat mit kontrollierten API-Antworten geprüft.

## 01.10.2026 – Kartenblatt und Orientierungen
- Orte auf Karte und Liste verwenden dieselbe Auswahl; wiederholtes Pin-Tippen löst erneut den Sprung zum Listeneintrag aus. Eine kurzzeitig ausgeblendete ScrollView holt ausstehende Auswahl beim Erscheinen nach. Listentippen fährt die Karte zum Ort; ohne Koordinaten öffnet es die Details statt wirkungslos zu bleiben. Filter und gelöschte Orte räumen veraltete Auswahl/Details auf. Die automatische Kartenrahmung läuft nur beim ersten passenden Inhalt.
- Das Blatt hat verborgen, kompakt, halb und breit als vier Rastpunkte. Ein gemeinsames Papier-/Titel-Element verbindet die geschlossene „N Orte“-Kapsel mit der geöffneten Karte. Die Map erfährt die aktuelle Panelkante schon während des Zugs; horizontale Filterbewegung löst kein vertikales Schließen aus. In Querformat wechselt das Blatt nach links, reserviert Kartenfläche rechts und verfolgt den Finger horizontal.
- „Bewegung reduzieren“ unterdrückt die Auswahlfeder der Stecknadeln. „Liste schließen“ und VoiceOver-Rastpunkte erlauben die Bedienung ohne Ziehen. project.yml und die generierte Info.plist erlauben Portrait, Portrait Upside Down und beide Landscape-Ausrichtungen; die Vollbildpflicht ist entfernt.
- DESIGN.md und Designkatalog dokumentieren Panelzustände und die Zuordnung zum Motion-Muster „Pill → Card“.
- Prüfung: XcodeGen regeneriert; Simulator-Build erfolgreich (xcodebuild ... build), git diff --check ohne Beanstandung. App installiert und gestartet; interaktive Kartenprüfung scheiterte daran, dass Device Hub auf dem gesperrten Mac keine Eingabe annahm. Keine Unit-/UI-Tests in diesem Schritt; reale Orientierung, VoiceOver und Touch-Gesten bleiben offen.
- Zusatzprüfung: generischer iOS-Gerätebuild erfolgreich (ohne Signierung). Xcode erkennt ein echtes iPhone, meldet es aber als nicht verfügbar und verlangt Entsperren sowie Kabel-/WLAN-Verbindung und bei WLAN Entwicklermodus. Deshalb wurde kein Gerät installiert oder verändert.

## 02.10.2026 – Typografie, Querformate und Motion-System
- Große Dynamic-Type-Stufen: Tageskarten rollen horizontal, statt zu schmalen Streifen zu schrumpfen; Ticket-/Ortszeilen umbrechen, und der Ort-Editor setzt Titel sowie Aktionen in den Inhalt. Entscheidungskarten reservieren mehr Platz für lange Titel.
- „Offen“ wird in der Ideen-Hilfe ausdrücklich als dritte Entscheidung benannt. Karten-, Swipe- und Sync-Motion behalten ihre Bedeutung und respektieren „Bewegung reduzieren“.
- DESIGN.md hält die kreative Motion-Zuordnung des Briefs fest: Schreibschlitten, Fächer-/Stapelphysik, Einladungs-Schlitz, Kapsel→Karte, gefüllte Schwellen-Geste und Sync-Insel. Die Muster dienen konkreten Zustandswechseln statt dekorativer Dauerbewegung.
- Prüfung: vollständige iPhone-17-Pro-Simulator-Suite auf iOS 26.5: 45 bestanden, 14 übersprungen, 0 Fehler. Apple Accessibility Audit nach den letzten Korrekturen und Prüfung auf echten Geräten bleiben offen; UI-Audit ist opt-in.

## 02.10.2026 – Karten-Cluster und Release-Prüfung
- Nahe Fotomarken bündeln sich anhand ihrer Bildschirmposition zu antippbaren Stapeln mit Anzahl. Antippen zoomt in den Bereich; eine ausgewählte Marke bleibt als Einzelpin sichtbar und wählt denselben Ort in der Liste aus. Das verhindert überlagerte Pins in der Prager Altstadt, ohne weit auseinanderliegende Orte zusammenzufassen.
- Tagesverbindungen sind auf der Übersicht nun dünn und gestrichelt; die gekoppelte Ortsauswahl hebt nur den relevanten Tag rot hervor. Der Karten-Hinweis für VoiceOver beschreibt jetzt korrekt, dass ein Pin den Ort in der Liste auswählt.
- Die Landscape-Liste rundet nun die innere Kante zur Karte und bleibt außen bündig. Der Cluster-UI-Test verfolgt jetzt dieselbe Orts-ID durch wechselnde Gruppen und prüft deren konkreten Listeneintrag.
- Produkttext und interne Laufzeitnamen verwenden einheitlich Ja/Nein/Offen. „Offen“ blendet eine Karte nur im aktuellen Durchgang aus; nach Neustart erscheint sie wieder unentschieden.
- 3 gezielte Cluster-Unit-Tests und der Offline-Retry-Test bestanden; der komplette aktuelle Unit-Testlauf: 47 bestanden, 1 übersprungen, 0 Fehler. Generischer iOS-Release-Build erfolgreich. Eine direkte Simulatoraufnahme zeigt 13 Orte als zwei gezählte Stapel plus Einzelpins.
- Haupt- und Symbolknöpfe unterdrücken bei „Bewegung reduzieren“ jetzt auch ihre Skalierungsfeder; der aktuelle Release-Build und `git diff --check` bestehen.
- Der fokussierte Cluster-UI-Test besteht auf iPhone 17 Pro / iOS 26.5: Cluster antippen, hineinzoomen, Einzelpin wählen, den Drawer schließen und wieder öffnen; derselbe Ort steht danach weiterhin sichtbar in der Liste. Der Apple-Accessibility-Audit besteht auf diesem Zustand ebenfalls. Für große Bedienungsschrift wechselt der Drawer-Header in eine adaptive Anordnung; Textaktionen haben eine zentrierte Mindestfläche von 44 × 44 pt.
- Die Screen-Tour überspringt Ortsdetail und Ortseditor nicht mehr. Der aktuelle Build besteht die Tour über 14 Screens einschließlich Reise, Ideen, Karte, Ortsdetail/-editor, Unterlagen, Vorschlag und Teilen; alle 14 Standbilder wurden erzeugt. Wiederverwendete Button-, Panel- und Reduced-Motion-Werte liegen jetzt zentral in `Stitch.Motion`; die referenzgebundenen A–F-Choreografien bleiben individuell.

## 02.10.2026 – Erinnerungen nach der Reise
- `TripDates.phase` unterscheidet vor, während und nach der Reise. Nach dem 9.10. ist der letzte Reisetag vorausgewählt und „Erinnerungen ansehen“ erscheint mit der Zahl besuchter Orte und eigener Fotos.
- `TripMemoriesView` zeigt ausschließlich tatsächlich besuchte Orte, nach Reisetag sortiert. Fotos nutzen den vorhandenen `PhotoStack` samt Feder-/Wischverhalten und den bestehenden Vollbild-Viewer; Orte ohne Bild bleiben sichtbar und führen zum Ortsdetail. Der leere Zustand erklärt die Besuchsmarkierung und öffnet die Karte.
- Mobbin geprüft: Placify „Memories“ und 5 Minute Journal „Gallery“ halten Bilder nach Zeit einordenbar und öffnen einzelne Fotos in Vollbild. Das ist in Album auf Tagesgruppen, Ortsstapel und denselben Foto-Viewer übertragen.
- `ALBUM_DEMO_MEMORIES=1` liefert einen reproduzierbaren Debug-Datensatz mit mehreren Tagen, einem Mehrbild-Ort und einem Ort ohne Foto. Dadurch deckt der UI-Test gefüllte und leere Rückblicke, Stapelwechsel offline, Vollbild-Rückkehr sowie den Weg zu Ortsdetails ab.
- Prüfung auf iPhone 17 Pro / iOS 26.5: Datumsgrenzen-Unit-Test, leerer UI-Rückweg zur Karte und gefüllter Galerieablauf bestanden. Der gefüllte Ablauf öffnet nun auch das vordere Stapelfoto über sein benanntes VoiceOver-Ziel und kehrt danach zu den Orten zurück. Der tatsächlich ausgeführte Apple-Accessibility-Audit fand zunächst kleine Foto-Treffflächen, zu wenig Textkontrast auf Fotos und eine nicht skalierende Toolbar-Aktion. Die Fotokarte ist nun ein großes benanntes VoiceOver-Ziel, der Bildverlauf sichert den Kontrast, und „Fertig“ wandert bei Accessibility-Schriftgrößen in eine breite, skalierende Leiste. Der Wiederholungslauf besteht; Hoch- und beide Querformate bleiben bedienbar. Screenshot visuell geprüft; doppelte Ortsüberschrift entfernt. Generischer iOS-Release-Build und `git diff --check` bestehen; iOS-17-Deployment-Target bleibt erhalten.
- Foto-Vollbild nutzt denselben randlosen Geometrierahmen für Bild und Abdunklung; die Schließen-Aktion bleibt per Safe Area geschützt. Fill- und Fit-Layer teilen nun die explizite Viewportgröße, sodass das vollständige 4:3-Foto nach einer Drehung mittig bleibt. Beide Bildlayer ergeben ein einziges VoiceOver-Bildziel.
- Prüfung auf iPhone 17 Pro / iOS 26.5: Galerie-Test einschließlich Portrait, beider Landscape-Ausrichtungen, Mitte/Erreichbarkeit und Rückkehr bestanden. Die XCTest-Aufnahme war während der Drehung veraltet; der direkte Live-Simulator-Screenshot bestätigt das zentrierte, unbeschnittene Bild.

## 02.10.2026 – Motion und große Bedienungsschrift
- Die Abgleich-Insel nutzt nun natürliche Textumbrüche statt Textverkleinerung oder Zeilenbegrenzung; die Capsule wächst mit ihrer Meldung. Die bestehenden Motion-Referenzen für Eingabeschlitten, Foto-Stapel, Einladungs-Schlitz, Kartenblatt, Swipe-Entscheidung und Abgleich-Insel bleiben an die jeweilige Handlung gebunden.
- `testSyncIsland` läuft mit eigenem temporärem Test-Store und hängt den geöffneten Zustand als Screenshot an.
- Prüfung auf iPhone 17 Pro / iOS 26.5: der Insel-Test besteht bei maximaler Accessibility-Schriftgröße (1 bestanden, 0 übersprungen, 0 Fehler); Screenshot visuell geprüft. Der Simulator wurde danach auf die vorherige Schriftgröße zurückgesetzt.
- `testNamePromptStitch` läuft jetzt ohne lokale Screenshot-Variable und hängt den Schreibschlitten-Zustand direkt ans XCTest-Ergebnis; der fokussierte Test besteht und das Bild wurde visuell geprüft.
- Vollständige Simulator-Suite auf iPhone 17 Pro / iOS 26.5: 53 bestanden, 13 optionale bzw. fixtureabhängige Tests übersprungen, 0 Fehler. Vier Motion-Tests benötigen weiterhin vorbereitete Reise-Fixtures; `testSyncIsland` erzeugt seinen eigenen Wegwerf-Store.
- Generischer iOS-Release-Gerätebuild und `git diff --check` bestehen.

## 02.10.2026 – Persistence-Fixture und vollständige aktuelle Prüfung
- `testLetterSlotThrow` nutzt einen reproduzierbaren, leeren Debug-Test-Store. Die App legt ihn nur an, wenn der Store noch nicht existiert; wiedergeöffnete App-Instanzen laden dieselben Daten erneut. Dadurch prüft der Test echte Speicherung statt bereits sichtbare Demo-Karten vorauszusetzen.
- Ursache des alten UI-Fehlschlags: Das Ideenfach zeigt höchstens drei Karten zugleich; zusätzliche Demo-Orte waren gespeichert, aber nicht im sichtbaren Accessibility-Baum. Der Test prüft beide neu angelegten Orte nach erneutem App-Start einzeln.
- Serielle vollständige iPhone-17-Pro-/iOS-26.5-Simulator-Suite: **59 bestanden, 7 übersprungen, 0 fehlgeschlagen**. Alle Motion-UI-Tests und der Persistence-Test bestehen. Die sieben Skips sind optionale externe PDF-/Screenshot-Fixtures sowie Tests, die vorbereitete Orte, Bilder oder einen Reiseplan erwarten.
- Generischer iOS-Release-Build erfolgreich; Designkatalog-JSON und `git diff --check` sind gültig.
- Noch offen: vorbereitete Fixtures für die sieben optionalen Tests, reales PDF-Dokument sowie Validierung der Synchronisierung zwischen zwei physischen Geräten. Ein verbundenes iPhone ist verfügbar; ein zweites Gerät ist nicht nachgewiesen.


## 02.10.2026 – Ortsbild-Auswahl und Backend-Nachweis
- Produktionsfunktion `place-photo` aktiv (Version 5); Live-Aufruf für Café Louvre liefert HTTP 200, Auswahlversion 3 und acht Kandidaten einschließlich verifizierter Commons-Fotos mit Urheber-/Lizenzdaten. Unauthentifizierter Aufruf wird mit HTTP 401 abgewiesen. Beide vorgesehenen Supabase-Migrationen sind remote angewendet.
- 32 Backend-Tests bestanden. Ortswechsel entfernt alte ortsgebundene Bilder und Galerien; eigene Uploads bleiben erhalten. Der fokussierte Unit-Test dazu besteht. Editor und Detailansicht zeigen Lizenz und Quelle.
- Bildauswahl-UI-Test läuft jetzt ohne externe Datei-Fixture oder Skip: manuell gewählter Vorschlag wird gespeichert und nach App-Neustart samt Urheber/Lizenz wieder geladen. Prüfung bestanden; Fixture überschreibt beim Neustart keine gespeicherten Daten mehr. SwiftUI-Link-Assertions verwenden die tatsächlichen Accessibility-Labels.
- Release-Simulator-Build und Diff-Check bestanden. Beim abschließenden Codecheck zusätzlich gefunden: Ein Ortswechsel während laufender Bildsuche konnte die neue Suche verlieren. `PlaceEditor` merkt weitere Anfragen vor und bearbeitet anschließend den aktuellen Ort; veraltete Ergebnisse bleiben ausgeschlossen. Abschließende fokussierte UI-/Unit-Wiederholung: 2 bestanden, 0 fehlgeschlagen, 0 übersprungen. Release-Simulator-Build und Diff-Check nach dem letzten Fix ebenfalls bestanden.
- Echte Hauptbild-URLs aus den Live-Antworten für Karlsbrücke und Café Louvre abgerufen: beide HTTP 200 mit JPEG-Daten (ca. 1,2 bzw. 1,1 MB).
- Live-Test hat einen anonymen Auth-Testnutzer angelegt; Selbstlöschung per Auth-Endpunkt war mit HTTP 405 nicht möglich. Keine anderen Nutzer verändert. Kein Commit in diesem Schritt.


## 02.10.2026 – UI-/UX-Rundgang: Kartenblatt
- Nutzerwunsch: erst Plan, Luna für interaktive Prüfung via @Computer, Sol für Überarbeitung; anschließend erneute Luna-Prüfung. Plan: outputs/map-ux-plan.md im Chat-Arbeitsordner.
- Luna reproduziert im isolierten Simulator-Store `slot-map-ux-luna` (Album Ansicht/iOS 26.5) mit Café Savoy: kurzer Abwärtszug ca. 20 bzw. 66 Bildschirm-Pixel schließt das Blatt komplett zur Ortskapsel. Endzustände belegt; kein FPS-Nachweis durch CUA. QA: outputs/map-ui-audit-luna/QA-LUNA.md im Chat-Arbeitsordner.
- Sol arbeitet im isolierten Worktree `work/map-ux-sol-20261002` des Chat-Arbeitsordners an PlacesDrawer/gekoppelter Kartenansicht. Aktueller Main-Arbeitsstand als Index-Baseline übernommen; kein Commit, Hauptkopie bislang unverändert außer dieser Fortschrittsnotiz.
- Nächste Schritte: Sol-Patch prüfen/übernehmen, Simulator-Build aktualisieren, Luna denselben Ablauf erneut prüfen lassen; verbleibende Befunde durch Sol beheben.

- Fortsetzung: Sol-Fix in Hauptkopie übernommen. Ziel-Rastpunkt nutzt reale Translation plus begrenzten Schwunganteil (20 % des nächsten Abstandes, max. 64 pt); doppelte Grabber-Geste entfernt. Zwei gezielte Regressionstests bestehen; Debug-Build mit vorhandenem Cache erfolgreich und auf Album Ansicht mit isolierter Fixture installiert. Sol-eigener fehlgeschlagener DerivedData-Cache entfernt.
- Nutzer autorisiert nun alle gefundenen UI-/UX-Fehler zu beheben. Luna wiederholt zuerst den Kartenblatt-Befund und prüft danach weitere lokale App-Flows; Sol wird für nächste bestätigte Befunde wiederverwendet. Isolierter Worktree-Index enthält jetzt auch den übernommenen ersten Fix; spätere unstaged Patches enthalten nur nächste Änderungen.

- Phase 2 übernommen: Live-Drag publiziert keine Kartenabdeckung mehr; Grabber ist die einzige Drag-Fläche, Filter bleiben separat. Debug-Build und Luna-Nachtest bestehen: 20/66px halten den Rastpunkt, langer Zug schließt, Querformat-Filter scrollt ohne Drawer-Kollaps. Video des Nutzers offline ausgewertet; Header-Clipping unterhalb collapsed bleibt konkret und wird eng behoben.
- Bilder-Fallback übernommen: Remote-Fehler/Leerresultat/alte Auswahlversion → Apple Look Around → MKMapSnapshotter mit Ortsmarkierung. Herkunft und Ortsbindung werden gespeichert; eigene/manuell gewählte Bilder bleiben geschützt; fehlgeschlagene CDN-Bilder erhalten nur eine beschriftete View-Vorschau, keinen stillen Asset-Ersatz. Zwei Compilerbefunde aus dem vollständigen Build korrigiert (Optional-Typ und explizite Return-Zweige); fokussierte Wiederholungsprüfung läuft. Noch kein Live-UI-Nachweis des letzten Karten-Fallbacks.

- Header-Fix übernommen: sichtbare Ausdehnung bleibt fingergebunden; unter collapsed hält das Layout den vollständigen Kopf und verschiebt Papier/Inhalt gemeinsam aus dem Bildschirm (Portrait unten, Landscape links). Native SwiftUI-DragGesture/Federanimation bleiben bestehen. Debug- und generischer iOS-Release-Build bestehen.
- Fokussierte Regression: 4 Tests bestanden, 0 Fehler/Skips (zwei Rastpunkt-, zwei Fallback-Herkunft/Erhalt-Tests). Luna bestätigt echten gerenderten Apple-Kartensnapshot mit roter Café-Louvre-Marke und Quellencredit nach expliziter Bildwahl/Speichern/Wiederöffnen. Root bestätigt JSON mit generatedSource=mapSnapshot, Ortsbindung und 236188-Byte-JPEG; JPEG visuell geprüft. Echter App-Neustart ohne Demo und Fehlerantwort-Fixture sowie finaler Header-Nachtest laufen noch.
- Zweite Priorität Linkimport: enge Reparatur bestehender Metadaten-Vorfüllung geplant (Titel→Suchquery→Kandidaten, keine automatische Ortszuweisung); Nutzerquery/-bilder und stale Responses schützen. Keine neuen Provider oder Sprachaufnahme.

- Neustart-Fixture bereinigt: Simulator erbte ALBUM_DEMO_MOTION=1 und überschrieb beim Start den sichtbaren Datensatz mit Café Savoy. Gespeichertes Café-Louvre-JSON/JPEG war intakt. Alle DEMO-Flags beim Test-Neustart explizit auf 0 gesetzt. Luna bestätigt danach denselben Ort, roten Marker, Bild und Apple-Quellencredit nach echtem Neustart ohne Reseed.

- Finaler Luna-Gestencheck auf Header-Build bestanden: Portrait 20/66px bleiben am Rastpunkt; langer Zug schließt, Kapsel öffnet. Querformat-Filter verschiebt nicht den Drawer; horizontaler Grabber schließt/vergrößert wie vorgesehen; Portrait wiederhergestellt. CUA bestätigt Endzustände, keine FPS-Messung.
- Link-Vorfüllungsfix übernommen in PlaceEditor/AlbumTests: verfügbare Metadaten füllen unangetastete Suche und starten reale MapKit-Kandidaten; Nutzer bestätigt Ort. Titel/Query/Bilder geschützt; getrennte Such-/Metadatengenerationen samt Query-/Source-Abgleich blocken verspätete Resultate und Fehler. 4 neue Policy-Tests plus bestehender Bildauswahl-/Persistenz-UI-Test bestehen (5/5 ohne Skips). Zusammen 9 gezielte Tests dieses Fix-Batches; endgültiger generischer iOS-Release-Build und Diff-Check bestehen. Luna prüft jetzt einmal den Vorfüllungsablauf mit deterministischer Metadaten-Fixture; tatsächliche TikTok/Instagram-Links noch nicht neu nachgewiesen, kein Beispiel vom Nutzer beantwortet.

- Luna-Linkcheck bestanden: leerer neuer Vorschlag übernimmt Café-Savoy-Titel und Suchquery aus kontrollierten Linkmetadaten; MapKit-Kandidat Café Savoy/Vítězná 5 sichtbar nach Ort-suchen-Aktion; manuell auf Louvre geänderte Query bleibt erhalten, keine stille Ortszuweisung. Testvorschlag abgebrochen. Metadatenprovider war DEBUG-Fixture; echte Social-Link-Metadaten bleiben von Verfügbarkeit/Linkinhalt abhängig. Bilder-/Link-/Demo-Response-Fixtures anschließend aus Simulator-Testumgebung entfernt; neuester Build startet mit demselben gespeicherten Café-Louvre-Teststore auf Karte. Keine Commits/Pushes.

## 02.10.2026 – Echter Google-Kurzlink statt Testmetadaten
- Nutzer-Screenshot zeigt LPErrorDomain-Fehler 2 bei https://share.google/hin4VZELKRpWzVu17; bisheriger Linkimport verlässt sich für Nicht-TikTok-Links allein auf LPMetadataProvider. Voriger Vorfüllungsnachweis nutzte vorbereitete Metadaten und deckte echte Weiterleitungen nicht ab.
- Live urllib-Aufruf: Google-Suche mit kgmid=/g/11b8t6x_p4 und q=Cafe+No.+3. Tatsächlicher Swift-URLSession-Aufruf: HTTP200, consent.google.com/ml mit encoded continue auf denselben Google-Ort. Name steht im Redirectziel und lässt sich ohne HTML-Scraping/Zustimmung extrahieren.
- Sol implementiert engen Redirect-/Ortsnamenresolver plus Regressionen im isolierten Worktree (PlaceEditor/AlbumTests). Anschließend echte URL im Simulator durch Luna prüfen, ohne ALBUM_LINK_PREVIEW_TITLE-Fixture. Physisches iPhone Luke ist verbunden; App dort noch nicht aktualisiert.

- Resolver übernommen (PlaceEditor/AlbumTests); native Redirect-/Consent-Zielquery wird ohne zusätzlichen Zielabruf ausgewertet. Fünf URL-Regressionen plus zwei Vorfüllungs-/Nutzerwert-Tests bestehen (7/7, keine Skips). Literales percent-encoded Plus bleibt erhalten; Google-Dokumente werden nicht irrtümlich als Kartenanbieter blockiert. Live-Ausführung des tatsächlichen Produktionsresolvers per Swift/URLSession liefert für Original-Kurzlink Cafe No. 3.
- Erster echter Simulatorlauf ohne Metadaten-Fixture: Titel/Query automatisch Cafe No.3, aber MapKit liefert falsche Cafés. Native Live-MKLocalSearch-Probe isoliert Ursache: erzwungener Zusatz ` Prag` verschlechtert das Parsing (`Cafe No.3 Prag` → andere Cafés); exakt `Cafe No.3` mit derselben bereits vorhandenen Prag-Region → ausschließlich Cafe No.3, Jakubská3/Prague1. Zusatz entfernt, regionaler Request bleibt. Debug-Build besteht; Luna prüft endgültigen echten Link/Kandidaten erneut. Keine künstlichen Suchvarianten, Hardcodings oder neuen Provider.

- Finaler echter Google-Link-UI-Test durch Luna bestanden: automatischer Titel/Suchquery Cafe No.3, ohne Ort-suchen-Tipp korrekter Kandidat Jakubská3/Prague1 sichtbar; erst Kandidatentipp übernahm Adresse und startete Bildsuche. Vorschlag ohne Speichern abgebrochen. Beleg outputs/map-ui-audit-luna/link-google-final-selected.png im Chat-Arbeitsordner. Finaler generischer iOS-Release-Build besteht. Simulator zum gespeicherten Café-Louvre-Teststore zurückgesetzt; keine Mock-Metadaten/Bildantworten aktiv. Physisches iPhone noch mit bestehendem Build, Aktualisierung über Xcode notwendig. Kein Commit/Push.

- Neuer Nutzerbefund: Abwärtsziehen sieht weiterhin schlecht aus, X-Schließen gut. Sol-Motionpatch integriert: innerer Listenviewport bleibt beim Abwärtsziehen am Ausgangsdetent stabil, Liste wird während Drag nicht aus dem View-Tree entfernt. Debugbuild/echte Bewegungsaufnahme durch Luna noch offen; Endzustandschecks reichen nicht als Bewegungsnachweis.
- Echter TikTok-Link 7614843797150698774 geprüft: oEmbed HTTP200, Produktionsresolver via Swift/URLSession liefert Caption mit 2117 Zeichen, Autor und Thumbnail-URL. Caption enthält mehrere Prag-Orte. Aktuelle SourceMetadataPolicy verwendet vollständige Caption als Titel/MapKitquery; Vorschauabruf funktioniert, einzelne Orte werden nicht strukturiert extrahiert. Native UI-Nachweis noch offen; keine TikTok-Ortserkennung behaupten.

- Drawer-Motionpatch Debugbuild besteht, im Album-Ansicht-Simulator installiert. Zwei gezielte Detent-Regressionen bestehen (2/2, keine Skips). Luna konnte zwei native DeviceHub-Videos speichern, deren Frames aber trotz AX-Zustandswechsel unverändert blieben; damit kein belastbarer In-Flight-Beleg. Sichtprüfung beim Ziehen auf echtem iPhone bleibt offen. TikTok echter UI-Retest läuft.

- Echter TikTok-UI-Test im neuen Build durch Luna abgeschlossen: Autor wird übernommen; vollständige 2117-Zeichen-Caption landet in Titel UND Ortsquery. Ortsuche zeigt „Ortssuche fehlgeschlagen. Bitte erneut versuchen.“; kein Kandidat und kein sichtbares Thumbnail im Editor. Screenshot outputs/map-ui-audit-luna/tiktok-overlong-caption-error.png im Chat-Arbeitsordner. Vorschlag ohne Speichern abgebrochen. Metadatenabruf funktioniert, ortsgenauer Social-Import weiterhin unvollständig; Bilddarstellungsursache nicht allein Caption nachgewiesen. Nutzerauftrag war diesen konkreten Link prüfen; keine neue Multi-Ort-Importoberfläche implementiert.

## Gemeinsame Sammlung — 2026-10-02
- Nutzer bestätigt Umsetzung für alle Reiseteilnehmer: fester Einstieg unter Ideen, Link-/Nachrichtenfeed, Kommentare, Herzen, mehrere manuell ergänzte Orte, Teilen-Menü. SAMMLUNG-PLAN.md enthält vier konkrete Issue-Entwürfe samt Akzeptanz/Prüfung. Linear-Suche Album findet kein Projekt; keine Issues erstellt.
- Supabase prag-album akzrlkbylglwrlbaacjo aktiv; Bestand public.trips/trip_members/places/documents mit RLS, 1 Reise/3 Mitglieder. Noch keine Collection-Tabelle oder Migration angewendet.
- Konfigurierte Feature-Rolle claude:claude-opus-5@xhigh über pstack-Runner im isolierten Worktree gestartet; Login bestanden, API429 Wochenlimit (Rücksetzung 04.10.2026 13:00 Europe/Berlin), keine Codeänderungen. Receipt work/collection-feature-receipt.json im Chat-Arbeitsordner. Kein stiller Modell-Fallback. Nutzer gefragt, ob Sol übernehmen soll; Umsetzung wartet auf Modellentscheidung.

- Nutzer-Modellentscheidung: Sol plant, Luna implementiert. Claude-Blocker damit aufgehoben; kein weiterer Claude-Versuch. Sol konkretisiert SAMMLUNG-PLAN.md, danach Luna als einzelner Implementierer im isolierten Worktree. Modellpräferenz im Projekt-AGENTS.md festgehalten.

- Sol-Plan SAM-1…SAM-5 fertig: getrennte CollectionEntry-Records, collectionSync serverVersion/mutationToken, backend CAS statt blind upsert, kanonische Link-ID + eigenständige Notizen, stabile Teilnehmer-ID, ShareContext tripKey-match und idempotente Queue, PlaceEditor autoSourceEnrichment/onSaved Defaults. Luna /root/luna_collection_build implementiert im isolierten Worktree; Parent prüft/integrates/deployt.
- Backend-QA vorbereitet im Chat-Arbeitsordner work/collection-backend-qa.sql: vollständig zurückgerollte Fixture-Transaktion mit 2 Mitgliedern + Fremdem, Unique/CAS/Unlike/RLS. Entwicklungssignatur vorhanden, aktuelles Main-Profil noch ohne AppGroup; native Signing-Prüfung nach Quellintegration erforderlich.

- Luna erster Sourceblock fertig/Parse+Diffcheck; Parentreview fand OriginalURL-Verlust (TikTokcanonical /video/id stattOriginal), nichtatomare Notiz-/Queuepersistenz, CAS-Konfliktzweig überschreibt in-flight Token/Payload, Detail-Snapshot stale, Queuefehler/Testisolation. Luna korrigiert + ergänzt sinnvolle Sync-/UI-Regressionen; Parent integriert Source erstnachKorrektur.
- Nutzer fragt Cloudfortsetzung und erlaubt ausdrücklich lokalweiter fallsnichtmöglich. Keine Gitremote/zugänglichesAlbumCloudprojekt, daher wiegehabtweiter; kein leererCloudchat erstellt.
- Collection-Migration vomParent übernommen (Server-Zeittrigger INSERT/UPDATE), nachMainkopiert und auf prag-album akzrlkbylglwrlbaacjo als collection_entries erfolgreich angewendet. RLS/CAS/Unique/Unlike-QA in rollback-only Transaktion bestanden: zweiMitglieder können, Fremdernicht, staleVersionüberschreibtnicht; alleFixtures zurückgerollt. KeinEintraginrealeReisegesendet.

- Sammlung: korrigierte Quellen und 14 Unit-/2 UI-Testfälle in Main integriert, Xcode-Projekt neu erzeugt. Echte Build-Prüfung fand Share-Selektoren/fehlende Extension-URL-Hilfe, PostgREST-Int64-Filter und Catch-Shadowing. Erste beiden Blöcke korrigiert; Luna bearbeitet weitere Compilerfehler mit vollständigem Build. Noch keine Sammlung-App-/UI-Test-Erfolge behaupten.
- Native Abnahme wird durch bestehende Luna-UI-Rolle vorbereitet; Start erst nach erfolgreichem Build. Kein Produktivbeitrag gesendet.

## Sammlung - integrierter Stand 02.10.2026
- Luna-Implementierung in Main integriert: Ideen / Sammlung, Link- und Textbeitraege ohne Pflichtort, Kommentare, Herzen, mehrere manuelle Ortsverknuepfungen und Quelldetails. Getrennte CAS-Records, Original-URLs, atomare/idempotente Share-Queue.
- XcodeGen dauerhaft korrigiert: AppGroup in beiden Entitlements und NSExtension-Registrierung deklarativ; generierte Dateien geprueft. Debug-App inkl. Extension und unsigned Release-Geraetecode erfolgreich gebaut. Neue Debug-App auf Album Ansicht installiert.
- XCTest: 14 Collection-Datentests + 6 bestehende Regressionen (Drawer/Google-Import/Bildwahl/Fallback) bestanden, 0 Fehler. Beide Collection-UI-Tests bestanden (Kommentar/Herz/Neustart und Ortsanlage Abbrechen/Speichern). Ergebnisbuendel 17-38-57 und 17-33-53 im bestehenden DerivedData. Vier urspruengliche Testfehler waren ungueltige Trip-Fixtures/veraltete Erwartungen, gezielt korrigiert; keine Produktionsregeln abgeschwaecht.
- Backend-Migration und rollback-only Zwei-Mitglieder/RLS/CAS/Unique/Unlike-Abnahme erfolgreich, keine Nachricht in bestehende Reise gesendet.
- Offen: CUA meldet gesperrten Mac/Unlock fehlgeschlagen; Nutzer um Entsperren gebeten. Native TikTok-/Querformat-/Share-Menue-Pruefung daher noch offen. Signierter Build meldet No Accounts, fehlendes Share-Profil und Main-Profil ohne AppGroup; Apple-Konto muss in Xcode angemeldet werden. Kein physisches Geraet aktualisiert.
- Kein Cloud-Handoff (kein Remote/Album-Cloudprojekt), kein Commit/Push. Kontolimits zu Beginn/Ende geprueft, keine exakte Aufgabenverbrauchsbehauptung.


## iPhone 15 Pro – 03.10.2026
- Gerät `iPhone von Luke (2)` ist verbunden (00008130-001C6C8A3481001C).
- Aktueller Debug-Gerätebuild inklusive AlbumShare kompiliert erfolgreich mit CODE_SIGNING_ALLOWED=NO; Log: /tmp/album-iphone15-compile.log. Noch nicht installierbar ohne Signierung.
- Signierter Build scheitert an Xcode „No Accounts“, fehlender App-Group-Berechtigung im vorhandenen Hauptprofil und fehlendem Profil für de.privatealbum.prague.share. Log: /tmp/album-iphone15-build.log.
- Nutzer um Anmeldung unter Xcode Settings > Accounts gebeten; Projekt in Xcode geöffnet. Danach signierten Build erneut erstellen, mit devicectl auf genau dieses Gerät installieren und de.privatealbum.prague starten. Bestehende App-Daten nicht löschen.

- Nach Xcode-Anmeldung: signierter Debug-Build einschließlich AlbumShare erfolgreich. Über devicectl auf iPhone 15 Pro (00008130-001C6C8A3481001C) installiert und de.privatealbum.prague erfolgreich gestartet. Bestehende App-Daten nicht gelöscht. Physische Bedienung/Haptik noch vom Nutzer zu prüfen.


## Link-Anreicherung – 03.10.2026
- Sol-Plan in LINK-ENRICHMENT-PLAN.md; Luna implementierte Vorschauen/Backfill/Ortsvorschläge, Sol prüfte und korrigierte Kandidatenfilter und ergänzte Tests.
- TikTok oEmbed, Redirect-Auflösung und HTML-OpenGraph-Fallback; Beschreibungen erhalten, Titel gekürzt; fehlende Vorschauen bis zu zwölf Beiträge pro Öffnen/Refresh nachladen. Detail: Vorschau aktualisieren, Mehr anzeigen, Orte erkennen. Bestätigte Apple-Maps-Vorschläge öffnen den vorhandenen Ortseditor, Speichern verknüpft mit Beitrag. Keine Video-/Audioanalyse, keine neuen API-Schlüssel.
- 24 CollectionTests bestanden (/tmp/album-link-tests-3-20261003.xcresult). Vier bestehende Sammlung-UI-Tests bestanden (/tmp/album-link-tests-20261003.xcresult, initiale neue Unit-Tests waren dort noch rot). Neuer Vorschau-/Notiz-/Neustart-UI-Test bestanden (/tmp/album-link-tests-2-20261003.xcresult; dort zwei Tests mit nicht verwendeter Test-Injektion zunächst rot, danach korrigiert und 24 Unit-Tests grün).
- Echter Nutzer-TikTok liefert Beschreibung und JPEG-Vorschau (HTTP 206 bei Range-Abfrage). Standalone-Live-MapKit-Prüfung liefert Altes Rathaus/Astronomische Uhr und St.-Nikolaus-Kirche im Prag-Kontext. Keine Garantie für gesperrte/private oder metadata-arme Posts.
- Signierter Debug-Gerätebuild inklusive Teilen-Erweiterung erfolgreich (/tmp/album-link-iphone-build.log), auf iPhone 15 Pro 00008130-001C6C8A3481001C ohne Datenlöschung installiert.


## Chatbot-Plan – 03.10.2026
- grilling-Interview: private Chats, gemeinsamer Reisekontext, schwebender Button, bedienbare Ergebnisse, Text/Diktieren, bestätigte reversible Aktionen, Recherche/Belege, Standort auf Abruf, private bearbeitbare Vorlieben und Zielbudget10EUR bestätigt.
- Read-only Luna-Inventar abgeschlossen. CHATBOT-PLAN.md enthält Code-Anschlüsse, offene Infrastruktur und acht Issue-Entwürfe; keine Implementierung begonnen. Linear-Suche Album: kein Zielprojekt, keine Issues erstellt.
- Nächster Schritt: konkreten Plan/technische Vorschläge bestätigen sowie Anbieter/API-Zugang und Linear-Zielprojekt vor Umsetzung zuordnen.


## OpenAI-Zugang – 03.10.2026
- Nutzer bestätigte lokalen Speicherort per Chat, nachdem Speicherort-Formular trotz zweimaligem Aufruf nicht angezeigt wurde und sofort decline lieferte. Secure Platform picker hatte Travel Buddy / Personal / Default project gewählt, keine Ablaufzeit.
- Schlüssel über OpenAI Developers verschlüsselt erstellt und mit lokalem Helper als OPENAI_API_KEY in .env.local gespeichert; Datei untracked, Git-ignoriert und Modus0600. Kein Klartext in Tool-Ausgaben oder Chat.
- Authentifizierter GET /v1/models/gpt-6-luna: HTTP200, Modell-ID korrekt. Kein kostenpflichtiger Chat-Test, kein Backend-Secret-Upload, noch kein Chatbot in der App.
- CHATBOT-PLAN.md und START-HERE.md aktualisiert; nächste Arbeit: serverseitige Responses-Anbindung, Quoten und freigegebene Feature-Pakete.


## Assistent Umsetzung – 03.10.2026
- AssistantModels/Actions, privater Chat und Supabase assistant-chat werden integriert. Backend-Migration assistant_usage angewendet, Funktion veröffentlicht; OPENAI_API_KEY ausschließlich als Backend-Secret gespeichert.
- Echter Responses-Test: HTTP429 credit_balance_exhausted. Offener externer Schritt: Nutzer muss OpenAI-Guthaben hinzufügen. Kein echter Chat-Erfolg behauptet.
- Live Backend: ohne Sitzung401, fremde Reise403, Provider-Guthabenfehler503billing_required, doppelte Request-ID409. Eigene temporäre QA-Identität gezielt entfernt, Reise-/Teilnehmerdaten nicht geändert.
- Grenzen: lokaler Snapshot plus Sync vor bestätigtem Planapply; noch kein serverseitiger CAS für bestehende Place-Sync-Schreibvorgänge.
- Nächste Schritte: integrierter Simulatorbuild, Assistant Action/UItests, signierter iPhonebuild installieren.

- Abschlussprüfung: 5 Deno-Backendtests, 5 AssistantActionsTests und 2 AssistantUITests bestanden; Simulator-Testbundle /tmp/album-assistant-tests-20261003.xcresult. Signierter finaler Gerätebuild /tmp/album-assistant-iphone-build.log erfolgreich, auf verbundenem iPhone15Pro ohne Datenlöschung installiert und gestartet. App-Bundle enthält keinen OPENAI_API_KEY. git diff --check sauber.
- Einziger Blocker für echte KI-Antworten: OpenAI Personal/Default project hat kein Guthaben. Kein Guthaben-Kauf durch Agent vorgenommen. Nach Aufladung Chat und Webquellen live nachprüfen.

## Guthaben-Diagnose – 03.10.2026
- Nutzer zeigt 9.58USD API-Guthaben. Browser-Organisation org-XMtJuw0jshN831JbJgkTjTOI, Projektlink proj_lEDlqaTEIvXiKU0iuTbLLvjy.
- OpenAI Developers Connector bleibt auf anderer Organisation org-ufBBAI73cNoVFTTmKiSLwmKM / proj_kgShYo1lNlr7vZ7hzqiTzJLz. Bestehender Schlüssel gehört diesem Ziel, Responses weiterhin429credit_balance_exhausted, Backend503billing_required.
- Ursache: Guthaben und Schlüssel in verschiedenen Organisationen. Nächster Schritt: Connector mit aufgeladenem Konto verbinden, richtigen Zielschlüssel sicher bereitstellen; nicht erneut Guthaben kaufen. Keine neue Credential ohne Bestätigung. Eigene Funded-QA-Identität entfernt, keine Reiseänderung.

## Neuer API-Key aktiviert – 03.10.2026
- Nutzer hat neuen Schlüssel lokal gespeichert; .env.local Rechte0600, Secret sicher nach Supabase übertragen.
- Echter assistant-chat Request HTTP200: Check-in-Frage mit synthetischer Buchung korrekt beantwortet, echte document_id und wörtliches Zitat korrekt geliefert, usage verfügbar. Guthabenblocker behoben.
- Eigene QA-Identität d1417962-5fe8-47de-a52c-08454823594b gezielt entfernt; echte Reise nicht verändert. Kein App-Neubuild nötig, da Key nur Backend. Webrecherche noch nicht live geprüft.

## Web-Recherche repariert – 03.10.2026
- Nutzer meldete Fehler ausschließlich mit Webtoggle. Request fehlte include:web_search_call.action.sources; Extractor erkannte action.sources nicht. Strict source validation wurde zudem als generischer provider_error maskiert.
- Request fordert echte Suchquellen an; Extractor akzeptiert action.sources nur unter echten web_search_call Items, erfundene Messagequellen bleiben gesperrt. Validierungsfehler jetzt gezielte deutsche Meldung und Diagnose ohne Prompt/Secret.
- 7 Deno-Regressionstests +deno check bestanden, assistant-chat erneut veröffentlicht. Echter Backend-Webtest HTTP200: Café Savoy, Adresse/Ortsvorschlag und geprüfte prague.eu-Webquelle. Eigene QA-Identität gezielt entfernt. Kein iPhone-Neubuild nötig. Luna weiterhinlow.


## Stundenlauf abgeschlossen – 04.10.2026, 10:50 MESZ
- Drei getrennte Luna-Pakete umgesetzt: Karte/Drawer/Swipe, Assistent-Speichern/Snapshots, Reise/Detail. Root prüfte Integration und ergänzte finales Such-Routenfilter, Snap-Haptik sowie Regressionsfälle.
- 144 Unit + 14 unterschiedliche UI-Abläufe bestanden; vier opt-in Spezialtests ausgelassen. Finale Kartenregression ebenfalls bestanden. git diff --check sauber.
- Aktueller signierter Build inklusive Share-Extension ohne Datenlöschung auf iPhone 15 Pro installiert. Gerät gesperrt, physischer Start deshalb nicht bestätigt. Simulator startete, Reise/Suche/Detail visuell geprüft.
- Ergebnis/Belege/offene Accessibility- und Haptik-Abnahme: QA/ONE-HOUR-READINESS.md. Branch design/album-visual-refresh; keine Commits/Pushes, bestehende Änderungen erhalten.


## Konkreter Bildfehler behoben – 04.10.2026, 11:19 MESZ
- Nutzerfoto zeigte leeres Speculum Alchemiae: persistierter Seed ohne Koordinaten wurde von Bildpipeline übersprungen. Seed verifiziert, vorsichtiger Bestands-Backfill, sichtbare Einzelabfrage und gekennzeichneter unmittelbarer Kartenfallback umgesetzt. Ohne Lage Quellen-Thumbnail versuchen, keine geratenen Koordinaten.
- 15 fokussierte Tests bestanden; finaler Nachtest nach Adress-/Layoutschutz 3/3. Simulator-Screenshot speculum-fallback.png belegt den konkreten vorher leeren Ort. Dunkelmodus-Buttonfarbfehler und KI/Offen-Überlagerung korrigiert.
- Signierter Gerätebuild fertig, neue Installation blockiert durch getrenntes iPhone (CoreDevice4016). Vorher installierter Build enthält diesen Fix noch nicht. Weiter: verbinden/entsperren, /tmp/album-hour-device-build/Build/Products/Debug-iphoneos/Album.app installieren. Bericht QA/PHOTO-FALLBACK-FIX.md.


## Quellenbilder + direkte Links – 04.10.2026, 11:28 MESZ
- Idee hat jetzt direkt erreichbare Quelle/Kartenlink. OG/Twitter + begrenzte ortsbezogene JSON-LD Bildextraktion; keine allgemeinen Firmenlogos übernehmen. Quellenpreview auch bei bestätigter Lage/erzeugtem Kartenfallback, schützt persönliche Bilder und bleibt bei leerem Foto-Backend erhalten.
- Speculum real von Prague City Tourism ausgelesen und Remote-Foto im Simulator geladen. Screenshot QA/one-hour-screenshots/speculum-source-photo.png. Legacy-Museumslink präzise auf funktionierende Stadtseite migriert.
- 20 Tests bestanden (18 Unit + Live-Quellenfoto-UI + erzwungener Fallback-UI), 0 Fehler/Skips. Signierter iPhone-Build erfolgreich, Installation weiterhin durch unavailable-Gerät blockiert. Quelle/Belege QA/PHOTO-FALLBACK-FIX.md.


## Ideen zusätzlich als Liste · 04.10.2026
- Ideen → Alle: sämtliche nicht gelöschten Ideen, Suche über Titel/Kategorie/Adresse/Notiz, Anzahl, Status und Ortsdetails. Ja/Nein-Ideen bleiben sichtbar. 44pt Suchlöschaktion und Lazy-Liste.
- Finaler Listentest und Autoplan-Nachtest 2/2 bestanden; Offen/Neustart und Bildabbruch vorher bestanden. Neue gesamte Unit-Suite 156 erfolgreich, 4 optionale Spezialtests ausgelassen, keine Fehler. Recheck-Belege QA/RECHECK-2026-10-04.md.
- Signierter Gerätebuild mit Personal Team als Buildargument erfolgreich. Eine frühere Installation auf dem iPhone 15 Pro wurde protokolliert; aktuell meldet `devicectl` das Gerät als nicht verfügbar. Installierte Version und Start sind damit heute nicht erneut überprüfbar. Hauptsource bleibt unangetastet, isolierter Branch `design/album-visual-refresh`.
- Weiterer Auftrag: Design/Claude-Spec/README.md lesen und Claude-Design auf separatem Branch pushen. Datei bisher in lokalen Album-Worktrees und vorhandenen GitHub-Branches nicht gefunden; Speicherort erfragt. Nicht umgesetzt/gepusht behaupten.
- Finaler gezielter Simulator-Nachlauf: Alle Ideen + Autoplan 2/2; Bildsuche abbrechen + offene Ideen nach Neustart 2/2; Großschrift, Hoch-/Querformat und Karteneditor 1/1. Insgesamt 5 gezielte UI-Flows bestanden; der alte „Bearbeiten“-Locator ist durch `place-detail-edit` ersetzt. Vollständige UI-Suite nach diesen letzten Änderungen nicht erneut ausgeführt.
