---
name: Album
description: Private Reise-App für zwei – Prag 2026, als Briefmarkenalbum.
source: Figma „Album Foundations“ (BvFJ4PzwQXAxhPlrEw73rB) + Pastellränder je Kategorie
colors:
  paper: "#F4EFE4"
  paper-night: "#1A1714"
  paper-deep: "#E8DFD0"
  paper-deep-night: "#2A2520"
  card: "#FBF8F2"
  card-night: "#25211D"
  rule: "#DDD3C2"
  rule-night: "#3E3831"
  ink: "#1C1915"
  ink-night: "#F2EDE3"
  ink-soft: "#6B645C"
  ink-soft-night: "#B5ACA0"
  postmark: "#B64532"
  postmark-night: "#EC8672"
  postmark-fill-night: "#A63D2C"
  teal: "#3D5C5A"
  teal-night: "#8DB3AF"
  gold: "#C4A574"
  mat-rose: "#F0CEC6"
  mat-sky: "#CBDDEB"
  mat-butter: "#F2E3B2"
  mat-mint: "#CFE3D1"
  mat-lilac: "#DDD3EB"
typography:
  display: "Fraunces SemiBold (statische Instanz wght 600, opsz 48), Titel und große Zeiten"
  place: "Instrument Serif Regular, Ortsnamen"
  body: "SF Pro, Systemtextstile"
  code: "SF Mono Medium, Flugnummern, Strecken, Buchungscodes"
spacing: [4, 8, 12, 16, 24, 32, 48]
page-margin: 20
rounded:
  stamp: 4
  thumb: 10
  card: 18
  floating: 26
---

# Album · Briefmarke

Stand: 02.10.2026, Claude-Design in den Hauptstand integriert. Code: `Album/Stitch/Stitch.swift` (der Namensraum heißt aus Verträglichkeit weiter `Stitch`).

## Idee

Die Reise ist ein Briefmarkenalbum: ruhiges Papier, dunkle Tinte, Poststempel-Rot nur für Aktionen. Jeder Ort ist eine Marke mit gezähntem Rand und einem Pastellrand, der seine Kategorie verrät. „Ja“ zu einer Idee heißt frankieren: Ein Poststempel landet auf dem Foto.

Verworfen (aus der Kritik vom 30.09.): Leinenmuster, Kreuzstich-Skyline und -Symbole, 3D-Glocke, Heftstiche, gedrehte Polaroids, mehrere Bildwelten gleichzeitig.

## Farben

| Rolle | Swift | Hell | Dunkel | Regel |
|---|---|---|---|---|
| Seitengrund | `paper` | #F4EFE4 | #1A1714 | überall flach, kein Muster |
| Vertieft | `paperDeep` | #E8DFD0 | #2A2520 | Ticketabschnitt, Platzhalter, schmale Tage |
| Markenweiß | `card` | #FBF8F2 | #25211D | Karten, Marken, Felder |
| Kontur | `rule` | #DDD3C2 | #3E3831 | 1 pt um flache Karten |
| Text | `ink` | #1C1915 | #F2EDE3 | |
| Nebentext | `inkSoft` | #686159 | #B5ACA0 | mindestens 4,6:1 auf Vertieft, 5,3:1 auf Papier |
| Aktion | `red` / `redFill` | #B64532 | #EC8672 / #A63D2C | nur Aktionen und „heute“; 4,7:1 auf Papier, Weiß darauf 5,2:1 |
| Zweite Tinte | `teal` | #3D5C5A | #8DB3AF | besucht, zweite Tagesroute |
| Zierde | `gold` | #C4A574 | #D6BA8A | nie Schrift |

Pastellränder (`Stitch.Mat`) nur als Markenrand, nie für Schrift: Essen & Trinken Rosé, Sehenswert Himmel, Aussicht Butter, Unterkunft Flieder, Shopping Minze, sonst `paperDeep`.

## Schrift

- **Fraunces SemiBold** (`Face.display`, `Face.title`): „Prag“, Abschnittsüberschriften, Bildschirmtitel, Uhrzeiten auf Tickets.
- **Instrument Serif** (`Face.place`): jeder Ortsname.
- **SF Pro**: alles Lesbare und Bedienbare.
- **SF Mono** (`Face.ticket`, `Face.code`): Flugnummern, Strecken, Buchungscodes.
- Alle Stile wachsen mit Dynamic Type (`relativeTo:`). Keine Dachzeilen über Überschriften; die Kategorie steht unter dem Namen.
- Bei Bedienungshilfen wird der Tagesstreifen zu horizontal scrollbaren Tageskarten; Tickettexte umbrechen ohne Kürzung. Die Ideenmarke reserviert mehr Platz für Titel und Quelle.
- Im Editor wandert die Überschrift in den Inhalt und „Abbrechen“/„Speichern“ in zentrierte Flächenknöpfe am unteren Rand. Dekorative Poststempel bleiben feste Illustrationen und sind für VoiceOver ausgeblendet.
- Schriftdateien liegen in `Album/Fonts` mit OFL-Lizenz, registriert über `UIAppFonts` in `project.yml`.

## Bausteine

| Baustein | Wofür |
|---|---|
| `StampFrame` + `StampShape` | Foto als Briefmarke: gezähntes Markenweiß, Pastellrand, Bild |
| `TicketShape` / `TicketRow` / `FlightTicket` | Flug und Hotel als Ticket mit Abschnitt; Flug wächst zur Bordkarte |
| `Postmark` | runder Poststempel: Frankieren, Besucht, leere Zustände, Teilen |
| `PerforationLine` | gepunktete Trennung in Tickets |
| `StitchButton` | Pille 52 hoch; primär Poststempel, sekundär Markenweiß mit Kontur |
| `HeaderIconButton` | runder Symbolknopf 44 |
| `TextActionButton` | leise Textaktion („Tage planen“, „Alle“, „Offen“), mittig und mit mindestens 44 × 44 pt Trefferfläche |
| `SectionTitle` | Fraunces-Überschrift mit optionaler Zahl oder Aktion rechts |
| `PlacesDrawer` | Papierblatt mit vier Rastpunkten; unten in Hochformat, links im Querformat; gemeinsame Pin-/Listenauswahl |

## Bedienung (jeder Knopf hat einen Grund)

- **Toolbar überall:** nur „Idee einwerfen“ (+). Das frühere „Mehr“-Menü ist aufgelöst.
- **Reise:** Kopf mit Personen-Knopf (Teilen), Tagesstreifen 4.–9.10. (gewählter Tag breit mit Foto), Plan des Tages, während der Reise „Als Nächstes“ mit Route, Unterlagen als Tickets („Alle“ öffnet die Unterlagen), Hinweis nur wenn Ideen warten. Nach dem 9.10. öffnet „Erinnerungen ansehen“ die besuchten Orte chronologisch; ihre Fotos verwenden denselben Foto-Stapel und Vollbild-Übergang wie das Ortsdetail. Ohne markierte Besuche führt der leere Zustand direkt zur Karte.
- **Ideen:** Nein / Ja, „Offen“ als Textaktion und als Wischen nach oben, Rückgängig. Abgelehnte holt ein Link im leeren Zustand zurück.
- **Karte:** Briefmarken als Pins, leise gestrichelte Tagesverbindungen und eine rote Hervorhebung für den ausgewählten Tag; „Tage planen“ und „Ordnen“ sind beschriftet statt nur Symbol. Das Ortsblatt hat verborgen, kompakt, halb und breit als vier Rastpunkte: in Hochformat von unten, in Querformat seitlich links. Die kompakte Seitenansicht lässt Filter und Planung weg. Ein Pin markiert seinen Listeneintrag; die Liste übernimmt dessen Auswahl und Kartenausschnitt. Ein verborgener Drawer kehrt als „N Orte“-Kapsel zurück.
- **Ortsdetail:** Route, Besucht (Wisch-Spur), Quelle. Zurücklegen und Löschen nur im Editor.
- **Blätter:** links „Schließen“ (×), rechts die Aktion („Bearbeiten“ / „Speichern“).
- **Teilen:** ein Knopf („Einladung erstellen“ → „Einladung senden“). Abgleich automatisch und per Herunterziehen.

## Bewegung

Die kreativen Referenzen liefern Bewegungsmechanik, kein fremdes Branding:

| Referenz | Umsetzung in Album |
|---|---|
| [Raffiki – Schreibmaschinen-Schlitten](https://x.com/raffiki_art/status/2105045064988959021) | Der rote Schlitten folgt der Eingabe im Namensfeld mit leicht unregelmäßiger Feder (`AlbumRoot.swift`). |
| [Finno – Fotokarten](https://x.com/FinnoTaylor/status/2104731442928615929) | `PhotoStack` fächert Fotos auf, führt die oberste Karte am Finger und reiht sie hinten ein; Tippen öffnet das Foto aus derselben Stelle. |
| [Roc – Schlitz und Neudruck](https://x.com/roczhang9673/status/2103123371865276587) | `LetterSlot` schluckt die Einladung erst nach der Zugschwelle; Erfolg druckt die Rückmeldung aus, ein Fehler federt zurück. |
| [60fps – Pill → Card](https://60fps.design) | Ortskapsel und Kartenblatt teilen Form und Titel; die Liste folgt dem Finger unten im Hochformat und links im Querformat. |
| [60fps – Swipe-to-commit](https://60fps.design) | Die Ideenmarke neigt sich mit der Ziehgeschwindigkeit; Ja/Nein füllen den Wischfortschritt, „Offen“ bleibt als eigene klare Aktion erhalten. |
| [60fps – Compact ↔ Expanded Island](https://60fps.design) | `SyncIsland` wächst bei einer neuen gemeinsamen Änderung, blendet den Text nach der Hülle ein und klappt per Tipp oder Zeit wieder zu. |
| [Mobbin – Placify: Memories](https://mobbin.com/flows/2ee14141-fead-4e13-82fb-d00181c7e433) und [5 Minute Journal: Gallery](https://mobbin.com/flows/30c4fa29-41f2-475a-a776-cb27c3296981) | Rückblicke bleiben nach Tagen eingeordnet; ein Foto öffnet aus seiner Position groß und kehrt zur Galerie zurück. Album verbindet das mit dem vorhandenen Fotostapel pro Ort. |

Das sind konkrete Zustandswechsel, keine Dauerdekoration. Bei „Bewegung reduzieren“ wird die Bewegung ersetzt oder weggelassen; Stecknadeln federn bei Auswahl dann nicht.

Wiederverwendete Werte liegen in `Stitch.Motion`: `press` (kurze Druckfeder), `panel` (Feder für Blatt und gemeinsame Hülle), `decisionReturn` (Karte zurück in die Hand) und `reducedFade` (200-ms-Überblendung). A–F behalten ihre eigenen Schwellen und Schrittfolgen, weil sie jeweils eine andere Handlung erklären. Unter „Bewegung reduzieren“ wird die Swipe-Auswahl zur unmittelbaren Zustandsänderung; Foto-/Panelwechsel dürfen kurz überblenden.

## Prüfung

UI-Test `testScreenTour` (mit `TEST_RUNNER_ALBUM_PLAN_STORE=plan-demo`, `TEST_RUNNER_ALBUM_SHOT_DIR`) fährt alle Bildschirme über die neuen Knöpfe ab.

Die vollständige Apple-Accessibility-Prüfung der Reise-, Editor-, Ideen- und Kartenansicht ist mit `ALBUM_RUN_ACCESSIBILITY_AUDITS=1` zuschaltbar. Sie bleibt aus der normalen Suite heraus, weil Xcode die Simulator-Prüfung deutlich verlangsamt und nach einem abgebrochenen Audit eine mehrminütige Gerätediagnose starten kann. System-Misattributionen und konkret vermessene Kontrast-Fehlalarme sind im UI-Test eng begrenzt dokumentiert.

## Button-Typografie

Nutzerpräferenz: zentrierte Beschriftungen, ruhige Schriftgrößen und ausreichend Luft. Flächige Buttons verwenden Subheadline Semibold (15 Punkte Standard), 16 Punkte seitlichen und 12 Punkte vertikalen Innenabstand, mindestens 52 Punkte Höhe. Mehrzeiliger Text ist zentriert und darf den Button vergrößern. Textaktionen haben ebenfalls mittige Beschriftung und eine Mindesttrefferfläche von 44 × 44 Punkten. Dynamic Type bleibt aktiv. Die Besucht-Spur wächst mit der Schriftgröße und kürzt ihren Text nicht.


## Bildauswahl

„Bild wählen“ öffnet ein natives Blatt mit den gemeinsamen Papierfarben, Kartenradien und Abstandstokens. Jede Karte zeigt Foto, zentrierten Subheadline-Titel, optional den Hinweis „Ortszuordnung bitte prüfen“, Urheber und Quelle. Karten verwenden 16 Punkte Innenabstand, die Liste 24 Punkte Abstand; die Quellenaktion hat mindestens 44 Punkte Höhe. „Straßenansicht“ verwendet den gemeinsamen Buttonstil. Die Auswahl wird explizit gespeichert und nach Neustart erhalten.


## UX-Leitlinie des Nutzers

Vollständige zusammenhängende Abläufe entwerfen und prüfen: Auswahl, sichtbarer Inhalt, Navigation und Rückweg bleiben konsistent. Für Karte und Liste gilt: Ein ausgewählter Pin zeigt den zugehörigen Eintrag; die Liste kann vollständig geschlossen und per Geste bewegt werden, damit die Karte frei nutzbar ist. Auswahl und Kontext bleiben beim Wiederöffnen und bei der Rückkehr aus Details erhalten. Einfach, ästhetisch und durchdacht; vertraute Apple-Interaktionen, unmittelbares Feedback, unterbrechbare Bewegungen und Systemkomponenten bevorzugen. Alle Orientierungen, Dynamic Type und reduzierte Bewegung berücksichtigen. Gestaltungsmarke und UI-Verhalten gemeinsam beurteilen.
