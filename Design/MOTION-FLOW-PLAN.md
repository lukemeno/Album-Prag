# Motion-, Haptik- und Flow-Plan (04.10.2026)

Branch `claude/motion-flow`, baut auf `claude/ready-to-land` auf. **In der Cloud gebaut und geprüft (GitHub Actions, Xcode 26.6, iPhone 17 Pro / iOS 26.5):** Simulator- und iPhone-Build ohne Fehler, 162 Unit-Tests ohne Fehler, 37 Screenshots der Screen-Tour (hell, dunkel, quer, große Schrift) einzeln durchgesehen (Branch `ci-screens/claude-motion-flow`). Bewegung und Haptik lassen sich im Simulator nicht fühlen: dafür ist die Prüfliste unten.

## Ausgangslage

Album hat schon 18 Bewegungspfade und 15 Haptik-Auslöser (`QA-MOTION-INVENTORY.md`): Briefschlitz, Bordkarte, Fotostapel, Besucht-Spur, Ideenstapel, Pin-Drop, Abgleich-Insel. Mehr Effekte würden die App nicht besser machen. Die Lücken liegen woanders:

1. **Offline nervt statt beruhigt.** Ein fehlgeschlagener Abgleich setzt `store.error`. Unterwegs mit Roaming erscheint dann bei jedem App-Wechsel eine Meldung. Einen sichtbaren Offline-Zustand gibt es nicht.
2. **Der Tagesstreifen springt nicht mit.** Am 8. Oktober liegt der heutige Tag außerhalb des sichtbaren Bereichs. Ein Tageswechsel gibt keine Haptik.
3. **Leere Tage wirken kaputt.** Ein Kalendersymbol auf grauem Grund, „Noch offen“, und nur der Weg zur Karte.
4. **Kein Abschluss.** Wenn alle Orte des Tages besucht sind, passiert nichts. Das Ende eines Reisetags ist aber der Moment, der in Erinnerung bleibt (Peak-End-Regel).
5. **Das Ortsdetail kommt aus dem Nichts.** Es erscheint als normales Blatt, obwohl man auf ein Foto getippt hat (MOTION-PROMPTS #2: „Detail öffnet sich als Erweiterung des Elements, aus dem es stammt“).
6. **„Zum Reiseplan hinzufügen“ ist stumm.** Das Symbol wechselt hart, ohne Haptik und ohne VoiceOver-Ansage.
7. **Bildnachweis nur ganz unten** im Ortsdetail, nicht am Foto.
8. **`inkSoft` #737378 hat zu wenig Kontrast** auf Papier (Vorschlag aus der Spezifikation: #66676C).
9. **Der KI-Kreis verdeckt** am Ende der Reise-Seite den Route-Knopf der letzten Zeile.

## Umsetzung

| # | Was | Wo | Bewegung / Haptik | Bewegung reduzieren |
|---|---|---|---|---|
| 1 | Kein Fehlerfenster mehr bei Netzfehlern; leise Kapsel „Offline“ im Kopf der Reise-Seite, Tippen gleicht erneut ab | `AlbumStore.sync()`, `ReiseView` | Kapsel wächst aus dem Titel; Symbol pulsiert während des Versuchs; Auswahl-Haptik beim Tippen | Überblenden, kein Pulsieren |
| 2 | Tagesstreifen zentriert den gewählten Tag (auch beim Öffnen) | `ReiseView.itinerary` | Feder wie Panels; Auswahl-Haptik je Tag | Sprung ohne Animation |
| 3 | Leerer Tag: gestrichelte Marke mit „+“, Titel „Noch frei“; Karte mit „Ideen ansehen“ und „Tage planen“ | `ReiseView` | – | – |
| 4 | **Tagesstempel:** Beim ersten Öffnen eines Reisetags drückt ein Poststempel „PRAHA 4.10.26“ auf das Titelfoto, mit einem satten Haptik-Schlag. Danach bleibt er dort für den Tag. | `ReiseView` (`DayPostmark`) | Stempel fällt aus 1,7-facher Größe unscharf auf das Foto und federt ein; schwere Haptik beim Aufsetzen | Blendet ruhig ein, Haptik bleibt |
| 5 | **Tag geschafft:** Sind alle heutigen Orte besucht, erscheint eine Karte „Heute alles erlebt“ mit Stempel und Weg zu den Erinnerungen | `ReiseView` (`DayComplete`) | Karte wächst sanft ein | Überblenden |
| 6 | **Zoom ins Ortsdetail:** Das Detail wächst aus der angetippten Marke im Tagesplan und schrumpft beim Schließen dorthin zurück (iOS 18+) | `ReiseView`, `Stitch.swift` | System-Zoom-Übergang | Normales Blatt |
| 7 | Merken-Knopf im Ortsdetail: Symbol morpht, kurzer Hüpfer, Erfolgs-Haptik, VoiceOver sagt „Zum Reiseplan hinzugefügt“ | `PlaceDetail` | Symbol-Ersatz + Bounce | Nur Ersatz, kein Hüpfer |
| 8 | Bildnachweis als kleine Kapsel unten rechts auf dem Foto im Ortsdetail | `PlaceDetail` | – | – |
| 9 | Zahlen rollen weich („3 Orte“, „5 Ideen warten“) | `ReiseView` | Numerischer Inhaltsübergang | Überblenden (System) |
| 10 | `inkSoft` hell auf #66676C | `Stitch.swift` | – | – |
| 11 | Reise-Seite endet mit genug Platz über dem KI-Kreis | `ReiseView` | – | – |
| 12 | „Link kopieren“ bestätigt mit Häkchen-Morph und Erfolgs-Haptik | `AlbumSettings` | Symbol-Ersatz | – |

## Zweite Runde: Lücken aus der Spezifikation

| # | Was | Wo |
|---|---|---|
| 13 | **Kartenfilter „Besucht“:** neuer Eintrag im Filtermenü. Er filtert nach Status statt nach Kategorie, Route und Liste folgen. | `MapFilter`, `TripMapView`, `PlacesDrawer` |
| 14 | **Einheitlicher Ortsstatus:** Unter der Kategorie im Ortsdetail steht „Idee — Geplant — Besucht“, der aktuelle Schritt ist hervorgehoben (Besucht in Teal). Bei großer Schrift steht nur der aktuelle Schritt da. VoiceOver: „Status, Geplant“. | `PlaceDetail` (`PlaceStatusTrail`) |
| 15 | **Abgelehnte Ideen einzeln:** Ein Knopf in der Ideen-Leiste und im leeren Stapel öffnet die Liste „Abgelehnt“. Jede Idee lässt sich einzeln zurückholen (sie gleitet heraus, kurze Haptik, VoiceOver-Ansage), dazu „Alle zurückholen“. Vorher gab es nur „alle zurückholen“, und das erst bei leerem Stapel. | `InboxView` (`RejectedIdeasSheet`), `AlbumStore.restore` |
| 16 | **PDF-Zustände:** Im geteilten Album steht unter jedem PDF „Auf beiden iPhones“, „Wird hochgeladen …“ oder „Wartet auf Netz“. Die 25-MB-Grenze steht sichtbar da, und die Fehlermeldung nennt die echte Größe. | `TripDocumentsView`, `AlbumStore.importPDF` |

Neue Tests: `testVisitedMapFilterUsesStatusNotCategory`, `testRestoringOneRejectedIdeaLeavesTheOthers` (`DayPlanTests`).

## Dritte Runde: Feinschliff nach Screenshot- und Testprüfung (05.10.2026)

| # | Was | Wo |
|---|---|---|
| 17 | **Ja zählt sofort:** Nach rechts wischen oder „Ja“ entscheidet direkt, ohne Speichern. Fehlt ein Kartenort, steht daneben „Ort ergänzen“. | `InboxView` |
| 18 | **Abgleich-Insel sichtbar:** Sie hing an der ausgeblendeten Leiste der Reise und war nie zu sehen. Jetzt schwebt sie über dem Kopf. | `ReiseView` |
| 19 | **Querformat:** KI-Kreis im seitlichen Rand statt über „Einladen“ und „Route“; Apple-Karten-Logo frei neben dem Ortsblatt; Ortsdetail mit niedrigerem Foto. | `AlbumRoot`, `TripMapView` |
| 20 | **Sehr große Schrift:** „Einladen“ als Symbol statt „Ein-laden“, Reiseplan-Kopf untereinander. | `ReiseView` |
| 21 | **Nach der Reise:** kein „0 eigene Fotos“, vergangene Tage ohne Plan heißen „Ohne Plan“. | `ReiseView` |
| 22 | **Kartenliste:** springt beim Öffnen sauber zu „Heute“; vorher lag die Überschrift halb unter dem Kopf. | `PlacesDrawer` |
| 23 | **Barrierefreiheit:** unsichtbarer Stempel nicht mehr im Baum, „Offen“ in Tinte statt Grau. Die Audits auf Reise, Ideen, Karte und Editor laufen ohne Fund (Cloud-Lauf vom 05.10., Commit e133bce); Messfehler (Text unter Leisten-Kantenblenden, herausgescrollter Text, Systemteile ohne Element) sind im Test einzeln begründet. | `InboxView`, `AlbumUITests` |

Noch rot in der Cloud, alle auch auf dem Ausgangsstand: die Tests mit Apples Fotos-Auswahl und Teilen-Blatt (Automatisierung von Systemoberflächen) und `testMissingSeedPhotoShowsLocationFallback` (braucht einen vorbereiteten Datenstand vom Mac).

## Bewusst nicht gemacht

- **Querformat-Tab-Leiste über dem Ortsblatt:** braucht Sichtprüfung im Simulator.
- **Animationen pro Listenzeile, Parallaxe, Daueranimationen:** Das widerspricht `MOTION-PROMPTS.md` #5 und #6.
- **Keine neuen Swift-Dateien:** XcodeGen müsste sie erst ins Projekt aufnehmen. Alles steckt in bestehenden Dateien.

## Prüfliste am Mac

- [ ] Build (⌘B), danach `DayPlanTests` und `AlbumTests`.
- [ ] Reise am 4.–9.10. öffnen: Der Stempel fällt einmal pro Tag auf das Titelfoto. Beim zweiten Öffnen liegt er nur still da.
- [ ] Tag antippen: Der Streifen zentriert ihn, ein leichtes Klicken ist zu spüren.
- [ ] Einen Tag ohne Plan wählen: Marke „Noch frei“ mit „+“, darunter „Ideen ansehen“ und „Tage planen“.
- [ ] Orte im Tagesplan antippen: Das Detail wächst aus der Marke (iOS 18+). Wirkt das falsch, `.zoomDestination` in `ReiseView` entfernen.
- [ ] Alle heutigen Orte als besucht markieren: Die Karte „Heute alles erlebt“ erscheint.
- [ ] Flugmodus an, App neu aktivieren: Kein Fehlerfenster, sondern die Kapsel „Offline“. Flugmodus aus, Kapsel antippen: Sie verschwindet.
- [ ] Ortsdetail: „Zum Reiseplan hinzufügen“ morpht und vibriert, der Bildnachweis steht auf dem Foto.
- [ ] Karte → Filter → „Besucht“: nur besuchte Orte, Liste und Route passen dazu.
- [ ] Ortsdetail: Statuszeile Idee — Geplant — Besucht wechselt beim Merken und beim Abstempeln.
- [ ] Ideen: Eine Idee mit Nein ablehnen, dann oben links „Abgelehnte Ideen“ öffnen und einzeln zurückholen.
- [ ] Unterlagen im geteilten Album: Ein neues PDF zeigt erst „Wartet auf Netz“ bzw. „Wird hochgeladen …“, danach „Auf beiden iPhones“.
- [ ] Ideen: nach rechts wischen. Die Idee gilt sofort als „Ja“, ohne Speichern.
- [ ] iPhone quer halten: Der KI-Kreis sitzt rechts im Rand und verdeckt nichts.
- [ ] Alles einmal mit „Bewegung reduzieren“ und mit sehr großer Schrift.
