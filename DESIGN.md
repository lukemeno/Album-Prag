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

Stand: 01.10.2026, Branch `redesign/claude`. Code: `Album/Stitch/Stitch.swift` (der Namensraum heißt aus Verträglichkeit weiter `Stitch`).

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
| Nebentext | `inkSoft` | #6B645C | #B5ACA0 | 5,1:1 auf Papier |
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
| `TextActionButton` | leise Textaktion („Tage planen“, „Alle“, „Später entscheiden“) |
| `SectionTitle` | Fraunces-Überschrift mit optionaler Zahl oder Aktion rechts |

## Bedienung (jeder Knopf hat einen Grund)

- **Toolbar überall:** nur „Idee einwerfen“ (+). Das frühere „Mehr“-Menü ist aufgelöst.
- **Reise:** Kopf mit Personen-Knopf (Teilen), Tagesstreifen 4.–9.10. (gewählter Tag breit mit Foto), Plan des Tages, während der Reise „Als Nächstes“ mit Route, Unterlagen als Tickets („Alle“ öffnet die Unterlagen), Hinweis nur wenn Ideen warten.
- **Ideen:** Nein / Ja, „Später entscheiden“ als Textaktion und als Wischen nach oben, Rückgängig. Abgelehnte holt ein Link im leeren Zustand zurück.
- **Karte:** Briefmarken als Pins, eine durchgehende Route pro Tag, „Tage planen“ und „Ordnen“ beschriftet statt Symbol.
- **Ortsdetail:** Route, Besucht (Wisch-Spur), Quelle. Zurücklegen und Löschen nur im Editor.
- **Blätter:** links „Schließen“ (×), rechts die Aktion („Bearbeiten“ / „Speichern“).
- **Teilen:** ein Knopf („Einladung erstellen“ → „Einladung senden“). Abgleich automatisch und per Herunterziehen.

## Bewegung

Alle Muster aus dem Motion-Brief (A–F) bleiben und tragen jetzt das Briefmarken-Material: Schreibmaschinen-Schlitten im Namensfeld (A), Marken-Stapel (B), Briefkasten und Einladung mit Schlitz (C), Bordkarte (D), Stempelfarbe füllt Ja/Nein/Später und die Besucht-Spur (E), Abgleich-Insel (F). Frankieren: Poststempel fällt mit Nachdruck aufs Foto (Feder, schwere Haptik). Bei „Bewegung reduzieren“ wird überblendet statt bewegt.

## Prüfung

UI-Test `testScreenTour` (mit `TEST_RUNNER_ALBUM_PLAN_STORE=plan-demo`, `TEST_RUNNER_ALBUM_SHOT_DIR`) fährt alle Bildschirme über die neuen Knöpfe ab.
