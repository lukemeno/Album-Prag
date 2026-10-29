# Plan: Designsystem „Briefmarke“ in jeder einzelnen Ansicht · Entwurf 29.10.2026

Status: Freigegeben am 29.10.2026 mit den drei Empfehlungen (kleine Radien 16, Dunkel ableiten, Reihenfolge P0 → Beta-Checkliste → Redesign → Video-Orte). Kein Push.

Quelle: Figma `BvFJ4PzwQXAxhPlrEw73rB`, Seite „Designsystem · Briefmarke“ (42:11). Als Screen-Bestand dient zusätzlich die Seite „Album · Native Screens · 14.10.2026“ (51:11, 36 Screens). Dieses Design ersetzt das weiß-grüne Design vom 19.10. Das Haltemenü bleibt als Funktion erhalten und bekommt die neue Optik.

## 1. Was das Designsystem festlegt (aus 42:11 abgelesen)

- **Farben:** Papier `#F5F2EC` (Fläche), Karte `#FFFFFF`, Linie `#E6E0D6`, Tinte `#1C1A17`, Tinte leise `#6B645A`, Rot `#B82A24` **nur für Aktionen**.
- **Briefmarken je Kategorie, nie für Schrift:** Rose `#F6C9CF` Essen, Himmel `#CFE0F5` Sehenswert, Butter `#F7E3A6` Aussicht, Minze `#CDEBD9` Café & Natur, Flieder `#E3D5F2` Unterkunft, Zettel `#FBE7A1`.
- **Schrift:** SF Pro mit Dynamic Type (34 Bold · 28 Bold · 20 Semibold · 17 Semibold · 17 · 15 · 13 · 12 Medium) und Caveat 24 nur auf Zetteln. Das sind genau 2 Schriften.
- **Abstände:** 4er-Raster, Seitenrand 16, „12 zusammen, 32 getrennt“.
- **Radien und Schatten:** Foto in Marke 4 (Schatten Objekt) · Klein 12 (Schatten Karte) · Karte 24 (Schatten Karte) · Schwebend 32 (Schatten Schwebend).
- **Regeln:**
  - Obere Leiste: links ein runder Knopf für Zurück oder Abbrechen, rechts Mehr plus „+“ bzw. „Fertig“.
  - Eine rote Pille pro Screen, unten im Daumenbereich.
  - Abschnittsköpfe in Tinte, die Anzahl als Fußnote rechts.
  - Aktionszeilen 44 hoch, immer mit Symbol.
  - Höchstens 1–2 aufgeklebte Objekte (Marke, Sticker, Zettel) pro Screen, nie auf Formularen.
  - Chips scrollen waagerecht und werden nie abgeschnitten.
  - Der Tagesstreifen zeigt den gewählten Tag breit mit Foto.
  - Löschen nur im Mehr-Menü und mit Rückfrage.
  - Kein Muster im Hintergrund.

## 2. Abnahme-Gates (deine neun Ziele, gelten für jede einzelne Ansicht)

Dein Skill `design-gates` prüft Web-Seiten im Browser. Für die iOS-App setze ich dieselben Ziele als UI-Test-Tour (`AlbumUITests/DesignGatesUITests.swift`) und Code-Prüfskript (`QA/design-gates.sh`) um. Ergebnis ist ein Bericht mit Screenshot je Ansicht in hell, dunkel und größter Schrift. Bewusste Ausnahmen kommen mit Begründung in `design-gates.json`.

| Gate | Prüfung |
|---|---|
| 1 Keine Info doppelt, Abstände Vielfache von 4 | Skript: keine Abstandswerte außer `Stitch.Space`. Sichtprüfung je Screen gegen die Bestandsliste. |
| 2 Karten Radius 24, innen 16, Schatten einheitlich | Skript: `cornerRadius`/`shadow` nur über Tokens |
| 3 Knöpfe mindestens 44 hoch, nichts abgeschnitten bei größter Schrift | UI-Tour mit `accessibility5`: jede Schaltfläche ≥ 44 pt, kein abgeschnittener Text (Screenshot) |
| 4 Nur Markenfarben, höchstens 2 Schriften | Skript: kein `Color(`/`.white`/`.black` außerhalb `Stitch`, nur SF und Caveat |
| 5 Fehler sagen was, warum, was jetzt | Liste aller Fehlertexte im Code, jeder mit drei Teilen und einer Aktion |
| 6 Leere Ansicht: ein Symbol, ein Satz, ein Knopf | gemeinsame Komponente `EmptyState`, UI-Tour mit leeren Stores |
| 7 Laden mit Skelett statt Spinner, Kopf und Tab-Leiste springen nicht | Komponente `Skeleton` je Layout; UI-Tour vergleicht die Rahmen von Kopf und Tab-Leiste vor und nach dem Laden |
| 8 Kleine Animationen ~0,25 s mit kurzer Feder | nur `Stitch.Motion`, Skript sucht freie `.animation`-Werte |
| 9 Zahlen mit festbreiten Ziffern | Beträge, Zeiten, Zähler mit `.monospacedDigit()`; Skript und Sichtprüfung |

**„Jede einzelne Ansicht“:** Die Bestandsliste in Abschnitt 4 ist die verbindliche Liste. Ein Paket ist erst fertig, wenn jede Ansicht darin alle Gates besteht. Eine einzelne fertige Ansicht reicht nicht.

## 3. Vorgehen

1. **Tokens (S):** `Stitch.swift` bekommt die Werte aus Figma und ehrliche Namen. `action` statt `red`, `stamp.rose` usw.; die Fake-Namen `red`/`teal`/`gold` fallen weg. Inter und Lora werden entfernt, Caveat kommt hinzu. Die globale Tint-Farbe wird `action`, das behebt nebenbei den unlesbaren Dark-Mode-Text.
2. **Komponenten (M):** obere Leiste, rote Pille, weiße Nebenknöpfe, Chips (scrollbar), Karte, Aktionszeile, Abschnittskopf, Tagesstreifen, Briefmarke, Zettel, `EmptyState`, `ErrorState`, `Skeleton`, Tab-Leiste, Haltemenü.
3. **Fehlende Screens zuerst in Figma (M):** Folgende Ansichten gibt es in Figma noch nicht: Deine Reisen, Neue Reise, Ausgaben, Entdecken, Orte aus Video/Begleittext (Häkchenliste), Haltemenü offen, Rückfragen zu „Löschen“ und „Verwerfen“ aus der Beta-Checkliste. Ich entwerfe sie in deiner Datei „Album Redesign“ mit den Briefmarke-Tokens, du gibst frei.
4. **Screens in Wellen (L):** Welle A Kern (Reisen, Plan, Ideen, Karte, Gruppe, Haltemenü) · Welle B Orte (Detail, Neue Idee, Bearbeiten, Ort suchen, Bild wählen, Tag wählen, Galerie) · Welle C Reise-Daten (Unterlagen, PDF, Reisedaten, Ausgaben, Erinnerungen, Teilen, Erststart) · Welle D Sammlung und Assistent (Sammlung, Beitrag, Assistent, Vorlieben, Entdecken) · Welle E Zustände (leer, offline, Fehler, Abgleich, Löschen bestätigen).
5. Nach jeder Welle laufen Gates und Beta-Checkliste. Screenshots legen wir in Figma neben das Soll.

**Rollen:** Opus plant und entwirft die fehlenden Screens, du gibst frei, Sonnet setzt je Welle um, ich prüfe Diff, Build, Gates und Screenshots selbst.

## 4. Bestandsliste: jede einzelne Ansicht

Reisen · Neue Reise · Erststart · Plan (Tag) · Automatischer Plan · Ideen (Stapel, Liste, leer) · Entdecken · Karte (halb, Liste, Vollbild, Filter, Orte auswählen) · Ortsdetail (+ weitere Infos, Galerie) · Neue Idee · Ort bearbeiten · Ort suchen · Bild wählen · Tag wählen · Gruppe · Album teilen · Einladung · Unterlagen · PDF ansehen · Aus PDF gelesen · Reisedaten · Ausgaben (+ neue Ausgabe) · Erinnerungen (+ Foto groß) · Sammlung · Beitrag · Sammeln · Orte aus Text/Video · Reise-Assistent (+ Vorschlag) · Meine Vorlieben · Offline · Import fehlgeschlagen · Abgleich · Löschen bestätigen · Verwerfen bestätigen · Haltemenü · Name eingeben. Das sind 40 Ansichten, jede in hell, dunkel und größter Schrift.

## 5. Entscheidungen (29.10.2026, Nutzer: alle drei Empfehlungen übernommen)

1. **Kleine Radien:** In Figma steht 12, in deinem Gate 16. Empfehlung: **16**, weil das Gate die neuere Regel ist. Ich trage das dann in Figma nach.
2. **Dunkelmodus:** Figma enthält nur Hell. Empfehlung: Dunkel daraus ableiten (warmes Fast-Schwarz statt Papier, Rot aufgehellt für Kontrast ≥ 4,5:1) und die Werte in Figma als zweite Variante ablegen.
3. **Reihenfolge:** Empfehlung: P0 → Beta-Checkliste → **Redesign** → P1/P2 Video-Orte. Sonst würde die neue Video-Oberfläche zweimal gebaut.

Hinweis: Seite 51:11 wirkt in der Übersicht dunkler blau als 42:11. Ich nehme die Seite 42:11, die du verlinkt hast, als Maßstab und 51:11 nur für Aufbau und Inhalt der Screens.
