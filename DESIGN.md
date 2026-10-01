---
name: Album
description: Gemeinsames Reisealbum · Papier & Marke
colors:
  linen: "#F5F2EC"
  linen-night: "#1A1715"
  card: "#FEFDFA"
  card-night: "#262220"
  rule: "#E1DBD0"
  rule-night: "#3C3632"
  ink: "#24211E"
  ink-night: "#F3EFE8"
  ink-soft: "#6B6459"
  ink-soft-night: "#B0A79C"
  thread-red: "#9F3438"
  thread-red-night: "#E1898B"
  red-fill: "#9F3438"
  red-fill-night: "#8E3034"
  cobalt: "#3B5574"
  cobalt-night: "#9DB6D4"
  on-accent: "#FBF7F1"
  on-accent-night: "#FBF7F1"
rounded:
  thumb: "12pt"
  card: "20pt"
  floating: "28pt"
spacing:
  xxs: "4pt"
  xs: "8pt"
  s: "12pt"
  m: "16pt"
  l: "24pt"
  xl: "32pt"
  xxl: "48pt"
  page: "20pt"
---

# Album · Papier & Marke

Stand: 01.10.2026. SwiftUI-Implementierung: `Album/Stitch/Stitch.swift`.

## Umsetzung und Richtung

Album ist ein gemeinsames Reisealbum: warmes Papier, dunkle Tinte, Burgunder für Aktionen und sparsame Briefmarkenkanten an besonderen Fotos. Die Hauptansichten verwenden native Symbole und lesbare Systemschrift. Fotos, Orte und der Tagesplan stehen im Vordergrund.

Umgesetzt sind die gemeinsamen Farben, Flächen, Buttons und Symbole sowie Reise, Ideen, Kartenblatt, Ortsdetail, Fotostapel und Namenseingabe. Reise verwendet Tagesauswahl, Tagesplan, Unterkunft, Unterlagen und beschlossene Orte. Unterlagen verwenden die gemeinsame Abschnittsüberschrift; Teilen verwendet Ladezustände.

Ideen zeigen ein aufrechtes Briefmarkenfoto auf einer Papierkarte. Ja und Nein sind gleich groß; Offen steht darunter als leise Textaktion. Das Kartenblatt verwendet einen Kapselgriff, Filter mit neutraler Haarlinie und kompakte Ortszeilen. Im Ortsdetail stehen Name, Kategorie und Adresse lesbar unter den aufrechten Fotos; Route ist die Hauptaktion, Besucht die Nebenaktion. Notizen und Bildnachweise sind eigene Gruppen. Die Namenseingabe verwendet ein natives TextField auf Papier.

## Farben

Farben werden als Hell/Dunkel-Paar angelegt und reagieren auf den Systemmodus.

| Bedeutung / Swift-Name | Hell | Dunkel |
|---|---|---|
| Seitengrund · `linen` | #F5F2EC | #1A1715 |
| Karten und Felder · `card` | #FEFDFA | #262220 |
| Konturen und Trenner · `rule` | #E1DBD0 | #3C3632 |
| Text · `ink` | #24211E | #F3EFE8 |
| Nebentext · `inkSoft` | #6B6459 | #B0A79C |
| Links und Hinweise · `red` | #9F3438 | #E1898B |
| Aktionsfläche · `redFill` | #9F3438 | #8E3034 |
| Besucht / zweiter Kartenpfad · `cobalt` | #3B5574 | #9DB6D4 |
| Text auf Aktionsfläche · `onAccent` | #FBF7F1 | #FBF7F1 |
| Vollbildhintergrund · `scrim` | #141210 | #141210 |

Burgunder als Text und als Fläche bleiben getrennte Tokens. Nebentext, Links und Hauptbutton erreichen in beiden Modi mindestens 4,5:1; gemessen sind 5,75/6,65 für Nebentext auf Karte, 6,83/6,12 für Links auf Karte und 6,51/7,50 für Hauptbuttons. Haarlinien trennen Flächen, sie ersetzen keine sichtbaren Beschriftungen.

## Rhythmus und Maße

Alle Maße in Punkten. Abstandsskala: **4, 8, 12, 16, 24, 32, 48** (`Stitch.Space`). Der Seitenrand `page = 20` ist ein eigener Layoutwert.

| Beziehung | Maß |
|---|---:|
| Titel → Untertitel | 4 |
| Inhalt innerhalb einer Gruppe | 8–12 |
| Überschrift → Inhalt | 12 |
| Karte → Karte | 12 |
| Abschnitte | 32 |
| Karteninnenabstand | 16 |
| Seitenrand | 20 |
| Vorschaubild | 56 × 56 |
| Button-Mindesthöhe | 52 |
| Symbolbutton / Mindesttippziel | 44 × 44 |

Radien: **12** für Vorschaubilder und Tagesfelder, **20** für Karten und Buttons, **28** für Blätter. `floating` bleibt als Kompatibilitätsname für 28 erhalten.

Höhenstufen: `flat` ohne Schatten; `pinned` Schwarz 7 %, Radius 4, Y 1; `floating` Schwarz 12 %, Radius 14, Y 5. Beim Ziehen darf die Tiefe dem Finger folgen. Ruhende Listenkarten erhalten eine Haarlinie statt eines eigenen Schattens.

## Typografie

SF Pro über SwiftUI-Textstile: `.headline` für Ortsnamen und Abschnittstitel; `.body` für Inhalte und Felder; `.subheadline` für zweite Zeilen und mit Semibold für Buttons; `.footnote`/`.caption` für Zähler und Bildnachweise. „Prag“ verwendet `.largeTitle` mit Systemserife. Alle Textstile folgen Dynamic Type.

Beschriftungen flächiger Aktionsbuttons stehen horizontal und vertikal mittig. Die Standardschrift ist Subheadline Semibold (15 Punkt bei Standardgröße). Der Inhalt erhält 16 Punkte horizontal und 12 Punkte vertikal Innenabstand; Symbol oder Spinner und Text haben 8 Punkte Abstand. Mehrzeiliger Text ist zentriert und vergrößert den Button über seine Mindesthöhe von 52 hinaus. Keine feste Zeilenzahl oder automatische Verkleinerung. Nutzerpräferenz: ruhige Schriftgrößen, zentrierte Beschriftungen und ausreichend Luft zwischen Text, Symbolen und Rändern.

Keine feste Schriftgröße für lesbaren Text. Zeichnungen und Symbole dürfen geometrische Größen haben. Texte müssen bei großen Schriftgrößen umbrechen; das Datum darf nicht hinter einer Aktion verschwinden. Die Tagesleiste und der Ideenstapel müssen gesondert bei Accessibility-Schriftgrößen geprüft werden.

## Komponenten und Zustände

| Baustein | Implementierung | Regeln |
|---|---|---|
| Seitengrund | `LinenBackground` | Flaches Papier, keine Gewebekachel |
| Karte | `stitchCard()` | Papier, 16 innen, Radius 20, Haarlinie 1 |
| Hauptbutton | `StitchButton(primary: true)` | Burgunderfläche, heller Text, volle Breite, mindestens 52 hoch |
| Nebenbutton | `StitchButton()` | Papier, Tinte, neutrale Haarlinie; gleiche Form und Höhe |
| Laden | `StitchButton(loading: true)` | Spinner vor der Beschriftung; Aufrufer sperrt Mehrfachauslösung |
| Gesperrt | `.disabled(...)` | Deckkraft 40 %, nicht bedienbar; Beschriftung erklärt den Zustand |
| Gedrückt | ButtonStyle | 98 % Größe; dezente Flächentönung |
| Symbolbutton | `HeaderIconButton` | Kreis 44, native Symbolschrift, Haarlinie; Accessibility-Label am Aufrufer |
| Textaktion | `albumTextAction()` | Burgunder, semibold, mindestens 44 hoch |
| Abschnitt | `AlbumSectionHeader` | Headline, optional Heute-Hinweis und leiser Zähler; Header-Trait |
| Ortszeile | `AlbumPlaceRow` | Foto 56, Name, Metadaten, optional Nummer und Besucht-Siegel; ganze Zeile bedienbar |
| Foto | `PhotoCard` | Aufrecht, Radius 20; Verlauf nur bei Text auf dem Bild |
| Briefmarkenfoto | `StampPhoto` / `StampBorder` | Kleine Kerben, auf ausgewählten Fotos; kein Schmuck an jedem Feld |
| Reisetag | `DayStrip` | Gewählt burgundergefüllt; heute zusätzlicher Rahmen; Punkt bei vorhandenem Plan |
| Namensfeld | `StitchTextField` | Natives TextField, Papier und Haarlinie; insgesamt mindestens 52 hoch, wächst mit Schrift; Fokus, Binding und Submit bleiben erhalten |
| Formular | native `Form` | Papierzeilen, Systemfelder, sichtbare Fehler im Text |
| Ideenkarte | `IdeaPolaroid` | API-Name bleibt; Papierkarte ohne Heftkreuze, Briefmarkenkante nur am Foto, Ja-Siegel |
| Ideenaktionen | `InboxView` | Ja/Nein nebeneinander, gleiche Breite und 52 Mindesthöhe; Offen mittig mit 44 Mindesthöhe |
| Kartenblatt | `PlacesDrawer` | Drei Höhen, Kapselgriff, native Filter; Auswahl mit Rahmen und Accessibility-Zustand |
| Fotostapel | `PhotoStack` | Aufrecht in Ruhe; Ziehen darf neigen; Zähler und Vollbild ohne Geste erreichbar |
| Besucht | `VisitedTrack` / `VisitedStamp` | Neutrale Nebenaktion, skalierende Höhe und umbrechbarer Text; Erfolg mit Cobalt-Siegel |
| Navigation | native NavigationStack / TabView | Reise · Ideen · Karte; + oben, seltene Aktionen im Mehr-Menü |

Chips tragen Auswahl zusätzlich zum Farbwechsel als Accessibility-Zustand; die ausgewählte Ortskarte hat einen durchgehenden Rahmen. Ortszeilen erhalten Kategorie, berechneten Zeitabschnitt und Öffnungszeit-Hinweis aus dem unveränderten Tagesplan. Route, Tageszuordnung, Umsortieren und Details bleiben erreichbar; bei Accessibility-Schriftgrößen wandern die Ortsaktionen in zwei Zeilen. Fehler bleiben lesbar und erneut versuchbar; Erfolg verwendet ein dezentes Siegel oder Häkchen. Bildnachweise, Lizenz- und Quelllinks bleiben im Ortsdetail und im Vollbildfoto erreichbar.

Die bestehenden API-Namen `Stitch`, `LinenBackground` und `stitchCard` bleiben zur Kompatibilität erhalten. Sie beschreiben keine Stofftextur mehr. Einladung, Briefkasten und Bordkarte sind die ausdrückliche Ausnahme für bestehende Stick- und Schlitzrituale. Sie behalten ihre funktionierenden Zeichnungsprimitive und Bewegungsabläufe; Ideenkarte, Kartenblatt, Ortsdetail und Namensfeld verwenden keine Heftkreuze oder Stickunterlinien mehr.

## Bewegung

`Stitch.Motion`: `quick = 0,18 s`, `settle = 0,28 s`; Federn `press = 0,22 / 0,78`, `snap = 0,30 / 0,80`, `sheet = 0,38 / 0,86` (response / dampingFraction). Neue Auswahl- und Buttonbewegungen verwenden diese Werte.

„Bewegung reduzieren“ entfernt die neue Button-Skalierung und die animierte Tagesauswahl. Bestehende komplexe Rituale haben eigene Reduktionspfade; ihre Timingwerte sind noch nicht auf die neue Gruppe vereinheitlicht. Gesten dürfen nie für Speicherung notwendig sein. Ja/Nein/Offen, Rückgängig, Foto-Wechsel und Besucht bleiben per Tipp und VoiceOver erreichbar. Die Ideenkarte behält Auffächern, Gummiband, Geschwindigkeitsneigung und Abschluss-Callbacks; das neue Ja-Siegel verwendet denselben abgeschlossenen Commit-Pfad. Bei Bewegung reduzieren speichert Ja/Nein direkt, Fotos blättern durch Überblenden, Kartenpins springen ohne Neigung oder Fallschritt. Die Namenseingabe hat keine Nadel- oder Unterlinienanimation.

## Prüfung

Screenshots mit einem Wegwerf-Album: Reise vor/unterwegs/nach der Reise, wechselnde Tage, Ideen, Karte und Liste, Ortsdetail, Editor, Tagesplanvorschlag, Unterlagen, Teilen. Zusätzlich Dunkelmodus und große Schrift.

Prüfpunkte: gleiche Seitenkanten und Abschnittsabstände; keine überdeckten Aktionen; verständliche leere Zustände; Bildnachweise erreichbar; Auswahl und Laden sichtbar; keine Änderung der Stimmen oder Persistenz. Build allein bestätigt die visuelle Hierarchie nicht.

Geprüft am 01.10.2026 auf iPhone 17 Pro / iOS 26.5: Simulator-Build erfolgreich; 39 Unit-Tests mit einem vorgesehenen Skip und ohne Fehler. Neun unterschiedliche UI-Tests, elf Testausführungen inklusive Wiederholungen, ohne Fehler: Ideen anlegen und nach Neustart erhalten, Offen nach Neustart, Tagesauswahl, drei Kartenblatt-Höhen und Auswahl, Namenseingabe, Screen-Rundgang, Fotostapel, Besucht-Spur und Ideenstapel. Reise/Ideen/Karte zusätzlich im Dunkelmodus mit Accessibility-Medium-Schrift visuell geprüft. Das Namensfeld wurde nach Screenshotbefund auf die gemeinsame Gesamthöhe korrigiert und erneut geprüft. Screenshots stammen aus XCTest im Simulator; die Computer-Verbindung zum Device Hub war nicht erreichbar. Modelle, Speicherung und Backend sind unverändert.
