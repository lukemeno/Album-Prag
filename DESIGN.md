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

Umgesetzt sind die gemeinsamen Farben, Flächen, Buttons und Symbole sowie die Reiseansicht mit Tagesauswahl, Tagesplan, Unterkunft, Unterlagen und beschlossenen Orten. Unterlagen verwenden die gemeinsame Abschnittsüberschrift; Teilen verwendet Ladezustände.

Die vollständige Umstellung von Ideen, Kartenblatt, Ortsdetail, Fotostapel und Namenseingabe steht noch aus. Diese Ansichten erhalten bereits die gemeinsamen Farben und Flächen. Ihre bestehenden Gesten und Rituale bleiben bis zur gezielten Überarbeitung erhalten. Die folgenden Komponentenregeln beschreiben die gemeinsame Grundlage; neue Zielregeln sind ausdrücklich als ausstehend markiert.

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

SF Pro über SwiftUI-Textstile: `.headline` für Ortsnamen, Abschnittstitel und Buttons; `.body` für Inhalte und Felder; `.subheadline` für zweite Zeilen; `.footnote`/`.caption` für Zähler und Bildnachweise. „Prag“ verwendet `.largeTitle` mit Systemserife. Alle Textstile folgen Dynamic Type.

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
| Formular | native `Form` | Papierzeilen, Systemfelder, sichtbare Fehler im Text |
| Navigation | native NavigationStack / TabView | Reise · Ideen · Karte; + oben, seltene Aktionen im Mehr-Menü |

Zielregeln für die nächste Stufe: Ja/Nein als gleich große Aktionen, Offen als separate Textaktion; Kartenblatt mit ruhigem Kapselgriff und neutralen Filterkonturen; Ortsdetail mit aufrechtem Fotostapel und klarer Route-Aktion; Namenseingabe ohne Stickdekoration. Chips tragen Auswahl zusätzlich zum Farbwechsel als Accessibility-Zustand. Fehler bleiben lesbar und erneut versuchbar; Erfolg verwendet ein dezentes Siegel oder Häkchen. Diese Anpassungen sind noch nicht vollständig umgesetzt.

Die bestehenden API-Namen `Stitch`, `LinenBackground` und `stitchCard` bleiben zur Kompatibilität erhalten. Sie beschreiben keine Stofftextur mehr. Einladung, Briefkasten und Bordkarte behalten ihre funktionierenden Bewegungsabläufe; ihre Zeichnungsprimitive werden gezielt weiterentwickelt.

## Bewegung

`Stitch.Motion`: `quick = 0,18 s`, `settle = 0,28 s`; Federn `press = 0,22 / 0,78`, `snap = 0,30 / 0,80`, `sheet = 0,38 / 0,86` (response / dampingFraction). Neue Auswahl- und Buttonbewegungen verwenden diese Werte.

„Bewegung reduzieren“ entfernt die neue Button-Skalierung und die animierte Tagesauswahl. Bestehende komplexe Rituale haben eigene Reduktionspfade; ihre Timingwerte sind noch nicht auf die neue Gruppe vereinheitlicht. Gesten dürfen nie für Speicherung notwendig sein. Ja/Nein/Offen und Rückgängig bleiben per Button und VoiceOver erreichbar.

## Prüfung

Screenshots mit einem Wegwerf-Album: Reise vor/unterwegs/nach der Reise, wechselnde Tage, Ideen, Karte und Liste, Ortsdetail, Editor, Tagesplanvorschlag, Unterlagen, Teilen. Zusätzlich Dunkelmodus und große Schrift.

Prüfpunkte: gleiche Seitenkanten und Abschnittsabstände; keine überdeckten Aktionen; verständliche leere Zustände; Bildnachweise erreichbar; Auswahl und Laden sichtbar; keine Änderung der Stimmen oder Persistenz. Build allein bestätigt die visuelle Hierarchie nicht.
