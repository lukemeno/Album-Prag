---
name: Album
description: Private Reise-App für zwei – Prag 2026, gestickt auf Leinen.
colors:
  linen: "#EFE6D2"
  linen-night: "#1D2130"
  card: "#FBF8F0"
  card-night: "#292E40"
  thread-red: "#B82A24"
  thread-red-night: "#F57A6C"
  red-fill: "#B82A24"
  red-fill-night: "#B23028"
  cobalt: "#1F3F8C"
  cobalt-night: "#80A2EE"
  mustard: "#D6A022"
  mustard-night: "#EEC054"
  ink: "#1C1A17"
  ink-night: "#F2ECDE"
  ink-soft: "#585044"
  ink-soft-night: "#BAB2A2"
  on-accent: "#FBF8F0"
typography:
  display:
    fontFamily: "New York (als Kreuzstich gerastert, StitchedText)"
    fontWeight: 700
  large-title:
    fontFamily: "SF Pro"
    fontSize: "34px"
    fontWeight: 700
    lineHeight: 1.2
  title:
    fontFamily: "SF Pro"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.2
  section:
    fontFamily: "SF Pro"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: 1.25
  headline:
    fontFamily: "SF Pro"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "SF Pro"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.3
  subheadline:
    fontFamily: "SF Pro"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.33
  footnote:
    fontFamily: "SF Pro"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.38
  caption:
    fontFamily: "SF Pro"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.33
rounded:
  thumb: "8px"
  card: "16px"
  floating: "24px"
  capsule: "999px"
spacing:
  xxs: "4px"
  xs: "8px"
  s: "12px"
  m: "16px"
  l: "24px"
  xl: "32px"
  page: "16px"
components:
  button-primary:
    backgroundColor: "{colors.red-fill}"
    textColor: "{colors.on-accent}"
    typography: "{typography.headline}"
    rounded: "{rounded.card}"
    height: "56px"
  button-secondary:
    backgroundColor: "{colors.card}"
    textColor: "{colors.thread-red}"
    typography: "{typography.headline}"
    rounded: "{rounded.card}"
    height: "56px"
  chip:
    backgroundColor: "{colors.card}"
    textColor: "{colors.ink}"
    typography: "{typography.subheadline}"
    rounded: "{rounded.capsule}"
    padding: "0 16px"
    height: "44px"
  chip-selected:
    backgroundColor: "{colors.red-fill}"
    textColor: "{colors.on-accent}"
    typography: "{typography.subheadline}"
    rounded: "{rounded.capsule}"
    padding: "0 16px"
    height: "44px"
  card:
    backgroundColor: "{colors.card}"
    textColor: "{colors.ink}"
    rounded: "{rounded.card}"
    padding: "16px"
  icon-button:
    backgroundColor: "{colors.card}"
    textColor: "{colors.ink}"
    rounded: "{rounded.capsule}"
    size: "44px"
  text-field:
    backgroundColor: "{colors.card}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.card}"
    padding: "16px"
  list-thumb:
    rounded: "{rounded.thumb}"
    size: "44px"
---

# Design System: Album

## Overview

**Creative North Star: "Das gestickte Reisetuch"**

Album ist ein Stück Leinen, auf das zwei Menschen ihre Reise sticken. Der Grund ist Aida-Stoff (hell ungefärbt, nachts indigo), alles Wichtige ist Garn: Rot, Kobalt, Senf. Karten liegen als Papier auf dem Stoff, besondere Dinge (Polaroids, Tickets, Zettel) sind mit einem einzelnen Heftstich angeheftet. Die Oberfläche ist sonst ruhig und nativ: Systemschrift, Systemnavigation, Liquid-Glass-Tab-Leiste. Die Welt lebt in den Details, nicht in Dekoration.

Die App wird bedient, nicht bestaunt. Unterwegs in Prag zählt, dass alles einhändig und mit einem Blick erreichbar ist; die gestickten Momente (Prag-Schriftzug, Brückenmotiv, Kreuz beim „Dafür“) sind selten und deshalb besonders.

**Key Characteristics:**
- Leinen als Grund, Farbe nur im Garn.
- Ein Abstandsraster auf 4-Punkt-Basis, drei Radien, drei Höhenstufen.
- Systemschrift für alles Lesbare; gestickte Schrift nur für den Ortsnamen.
- Heftstiche markieren Angeheftetes, nicht Listen oder Formulare.

## Colors

Warmes Leinen mit wenigen, satten Garnfarben; jede Farbe hat eine Tag- und eine Nachtfassung.

### Primary
- **Kreuzstich-Rot** (thread-red): Schrift und Garn für Aktionen, Links, Hinweise, das Kreuz beim Entscheiden. Auf Leinen und Karte in beiden Modi mindestens 4,5:1.
- **Rot als Fläche** (red-fill): gefüllte Knöpfe und gewählte Filter. Nachts dunkler als das Schrift-Rot, damit helle Schrift darauf mindestens 5,8:1 erreicht.

### Secondary
- **Kobalt-Garn** (cobalt): Sehenswürdigkeiten und Unterkunft auf der Karte, Heftstiche auf Papier, der zweite Tagesfaden.

### Tertiary
- **Senf-Garn** (mustard): nur im Stickbild (Brückengeländer, Kronen). Nie für Bedienelemente.

### Neutral
- **Leinen** (linen): Grund aller Seiten und Blätter, immer als Gewebe-Kachel, nie als glatte Fläche.
- **Papier** (card): Karten, Felder, Knöpfe ohne Füllung.
- **Tinte** (ink): Überschriften und Fließtext.
- **Blasse Tinte** (ink-soft): Zweitinformation, Hinweise, Zähler.
- **Auf Rot** (on-accent): Schrift auf red-fill, in beiden Modi hell.

### Named Rules
**The Thread Rule.** Farbe ist Garn. Flächen sind Leinen oder Papier; nur Knöpfe und gewählte Filter dürfen rot gefüllt sein.

**The Two-Reds Rule.** Rote Schrift nutzt thread-red, rote Flächen nutzen red-fill. Nie tauschen, sonst kippt der Kontrast im Dunkelmodus.

## Typography

**Display Font:** New York, gerastert als Kreuzstich (StitchedText)
**Body Font:** SF Pro über die Systemtextstile (Dynamic Type)

**Character:** Der gestickte Ortsname ist das einzige Schmuckstück; alles andere ist ruhige Systemschrift, damit die Welt nicht mit der Lesbarkeit konkurriert.

### Hierarchy
- **Display** (StitchedText): nur „Prag“ auf der Reise-Seite und Stickmotive.
- **Large Title** (34, bold, `.largeTitle`): Seitentitel der Tabs, Flugzeiten (gerundet, feste Ziffernbreite).
- **Title** (28, bold, `.title`): „Heute“ während der Reise.
- **Section** (20, bold, `.title3`): Abschnittsüberschriften („Angeheftet“, „Anreise“, Titel im Karten-Blatt).
- **Headline** (17, semibold, `.headline`): Namen von Orten auf Karten, Tagesüberschriften in Listen, Knopftext.
- **Body** (17, `.body`): Fließtext, Formularfelder.
- **Subheadline** (15, `.subheadline`): Zweitzeilen (Art · Tageszeit · Öffnungszeit), Filter.
- **Footnote / Caption** (13 / 12): Erklärsätze, Zähler, Bildnachweise.

### Named Rules
**The Dynamic Type Rule.** Keine festen Schriftgrößen. Wo eine Zahl bewusst groß sein muss (Abreißkalender), wächst sie über `@ScaledMetric` mit und darf im festen Blatt verkleinern.

## Layout

Ein 4-Punkt-Raster mit sechs Stufen (4, 8, 12, 16, 24, 32) und festem Seitenrand von 16 auf jeder Seite. Linke Kanten aller Überschriften, Karten und Listen fluchten auf diesem Rand; nur schräg angeheftete Objekte dürfen ihn um wenige Punkte verlassen.

**Rhythmus** (in dieser Reihenfolge prüfen):
- Beschriftung → Wert, Titel → Untertitel: 4 (xxs).
- Innerhalb einer Karte, zwischen Zeilen: 8–12 (xs–s).
- Abschnittsüberschrift → Inhalt: 12 (s).
- Karte → Karte in einer Liste: 12 (s).
- Abschnitt → Abschnitt: 32 (xl).
- Innenabstand jeder Stoffkarte: 16 (m).

**Feste Größen:** Tippfläche mindestens 44 × 44 (Size.touch), Hauptknopf 56 hoch (Size.button), Vorschaubild in Listen 44 × 44 (Size.thumb).

**Blatt über der Karte:** drei Höhen (nur Kopf, halbe Höhe, ganz). Es ist Teil der Ansicht, damit die Tab-Leiste erreichbar bleibt; die Karte rahmt ihre Nadeln im sichtbaren Teil darüber.

### Named Rules
**The Twelve-Thirty-Two Rule.** Zusammengehöriges steht 12 auseinander, Getrenntes 32. Wer einen Wert dazwischen braucht, hat die Gruppe falsch geschnitten.

**The No Empty Spacing Rule.** Ein Block ohne Inhalt wird nicht gezeichnet; sonst zählt sein Abstand doppelt.

## Elevation & Depth

Drei Stufen, benannt nach dem, was sie darstellen. Tiefe entsteht sonst durch Papier auf Leinen, nicht durch Schatten.

### Shadow Vocabulary
- **Flach** (kein Schatten): Karten in Listen, Felder, Knöpfe ohne Füllung.
- **Angeheftet** (Schwarz 14 %, Unschärfe 5, 3 nach unten): Polaroids, Tickets, Abreißkalender, Kartennadeln, gefüllte Knöpfe.
- **Schwebend** (Schwarz 18 %, Unschärfe 14, 6 nach unten): Blatt über der Karte, Zwischenablage-Zettel, Einwurf-Animation.

### Named Rules
**The Three Levels Rule.** Nur diese drei Stufen (`stitchElevation`). Einzige Ausnahme: Etwas, das gerade gezogen wird (Ideen-Polaroid beim Wischen), hebt sich mit dem Finger an und bekommt dabei mehr Schatten.

## Shapes

Weiche, kontinuierliche Ecken in drei Größen: 8 für Vorschaubilder, 16 für Karten, Felder und Knöpfe, 24 für schwebende Flächen (Blatt über der Karte). Filter und runde Symbolknöpfe sind Kapseln. Linien sind gestrichelt wie Stiche oder Perforation (`PerforationLine`), nie durchgezogen. Polaroids und Tickets haben keine Radien – Papier ist eckig.

## Components

### Buttons
- **Shape:** Karte-Radius (16), 56 hoch, volle Breite.
- **Primary:** red-fill mit heller Schrift, angeheftet.
- **Secondary:** Papier mit roter Schrift und 1,5 roter Kontur, flach.
- **Textknöpfe:** rote Headline-Schrift ohne Fläche, mindestens 44 hoch (Route, Tag ändern, Bearbeiten).
- **Pressed:** leicht kleiner (97 %), federnd.

### Chips
- **Style:** Kapsel, 44 hoch, 16 seitlich; gesticktes Symbol davor.
- **State:** gewählt = red-fill mit heller Schrift; sonst Papier mit gestrichelter Kontur (Tinte 12 %).

### Cards / Containers
- **Corner Style:** 16.
- **Background:** Papier.
- **Shadow Strategy:** flach; angeheftet nur, wenn sie ein Objekt darstellen.
- **Internal Padding:** 16 (`stitchCard()`).
- **Auswahl:** roter Heftstich-Rahmen (gestrichelt, 4 innen).

### Inputs / Fields
- **Style:** Papierfläche, Radius 16, Innenabstand 16, ganze Fläche tippbar (`StitchTextField`). In Formularen: native Liste mit Papier-Zeilen.

### Navigation
- **Tabs:** Reise · Ideen · Karte in der nativen Glas-Tab-Leiste, Rot als Farbe der Auswahl.
- **Toolbar:** genau eine Hauptaktion („+“) und alles Seltene im „Mehr“-Menü, auf jedem Tab gleich.

### Heftstich (Signatur)
Ein einzelnes Kreuz (12, `TackStitch`) heftet Papier an den Stoff: oben mittig bei Tickets und Zetteln, an beiden oberen Ecken bei Polaroids. Nicht auf Listenkarten, Formularen oder Unterlagen.

### Blatt über der Karte (Signatur)
Leinen mit Radius 24 oben, schwebend; Griff als kräftiger Vorstich auf einer blassen Saumlinie, ganze Griffzeile 44 hoch.

## Do's and Don'ts

### Do:
- **Do** jeden Abstand aus `Stitch.Space` nehmen (4, 8, 12, 16, 24, 32).
- **Do** Stoffkarten immer über `stitchCard()` bauen: 16 innen, Radius 16.
- **Do** Tippflächen auf mindestens 44 × 44 halten, auch wenn das sichtbare Zeichen kleiner ist.
- **Do** Tagesangaben immer als „Dienstag, 6. Oktober“ schreiben (`TripDates.dayTitle`).
- **Do** neue Farben nur als Paar für Tag und Nacht anlegen.

### Don't:
- **Don't** eigene Schatten schreiben; nur die drei Stufen.
- **Don't** feste Schriftgrößen setzen (`.system(size:)`), außer als `@ScaledMetric`.
- **Don't** Heftstiche an Listenkarten, Flugkarten oder Formularfelder setzen.
- **Don't** Senf oder Kobalt für Bedienelemente nutzen; Aktionen sind rot.
- **Don't** Werte wie 2, 6, 10, 14 oder 18 als Abstand nutzen.
