# Album Visual Refresh — Entwurf und Arbeitsplan

Branch: `design/album-visual-refresh`  
Isolated worktree: `/Users/alexandergorny/.codex/.chatgpt-projects/g-p-6aabf1a8b2b48191be855674e1d66a30/Album-visual-refresh`

**Implementierungsziel (Nutzerentscheidung vom 04.10.2026):** Die native Album-App unter `Album/` mit SwiftUI und UIKit. Die bestehende Swift-App ist die Grundlage für das modernisierte Design. Gesten, Sheets, Motion und Haptik werden mit nativen iOS-Techniken umgesetzt. Expo/React Native wird nicht weiterentwickelt. Die gefilterten X-Referenzen stehen in `Design/Claude-Handoff/X-BOOKMARK-INSPIRATION.md`.

## Zielrichtung

Verbindliche visuelle Vorlage: `Design/Claude-Handoff/references/approved-native-design.png`. Nutzerkorrektur vom 04.10.2026: Das Lob des letzten Zwischenstands galt ausschließlich dem kleinen schwebenden KI-Kreis. Die restliche App ist noch nicht visuell freigegeben. Die drei generierten Screens möglichst originalgetreu umsetzen, keine weitere eigene Interpretation. Proportionen, Schriftcharakter und -größen, Abstände, Radien, Bildkomposition, weiße Flächen, Navy, Hellblau, Fotopins, kompakte Zeilen, Teilnehmerzeile und Aktionskacheln anhand der Vorlage prüfen. Reale Reisedaten und deutsche Beschriftungen bleiben korrekt. Fehlende Bewertungen oder Profilfotos nicht erfinden. Unterstützende Screens aus genau diesen Komponenten ableiten. Der KI-Kreis ist die ausdrücklich genehmigte Ergänzung unten rechts.

Abnahme: gleiche Bildschirmgröße verwenden und Reise, Karte sowie Ortsdetail direkt neben der Vorlage vergleichen. Abweichungen konkret festhalten und beheben; ein erfolgreicher Build ist keine Designfreigabe.

Zusätzliche Interaktionsreferenz: Claudes klickbarer [Album-Prag-Prototyp](https://claude.ai/artifact/TrwNzkRx2dBdzncz1QZF9B). Besonders passende Ideen: Tages-Chips mit klebrigem Tageskopf beim Scrollen; Auswahlkarten, bei denen die gewählte Abstimmung wächst und die anderen ruhig zurücktreten, mit dauerhaft erreichbarem Undo; sich zeichnende Routen und zurückhaltend landende Pins; Monatskarten, die bei Auswahl Platz für Details schaffen; eine schwebende Tab-Leiste, die beim Scrollen kompakter wird. Diese Muster an Albums echte Inhalte und drei vorhandene Tabs anpassen, nicht zusätzliche Mockup-Screens oder erfundene Kennzahlen übernehmen. Details: `Design/Claude-Handoff/CLAUDE-ARTIFACT-REFERENCE.md`.

## Designprinzipien

- Reise und echte Orte stehen im Mittelpunkt; Fotos erhalten großzügige, klare Bildflächen.
- Jede wichtige Oberfläche nutzt dieselbe Typo-, Spacing-, Radius-, Farb- und Schattenlogik.
- Systemschrift bleibt für Bedienung, Beschreibungen und Metadaten; Display-Typografie bleibt auf kurze Titel und Ortsnamen beschränkt.
- Beschriftungen sitzen sichtbar und geometrisch zentriert in Buttons. Typogrößen bleiben moderat, mit klarer Hierarchie und genügend Zeilenabstand.
- Karte und Liste bilden einen gemeinsamen Ablauf: Auswahl eines Pins markiert den passenden Listeneintrag und umgekehrt; das Blatt ist sauber verschiebbar und vollständig ausblendbar.
- Bewegung und Haptik unterstützen Greifen, Zustandswechsel, Bestätigung und Rückweg. Die sechs Prompts in `Design/Claude-Handoff/MOTION-PROMPTS.md` liefern Bewegungsinspiration.
- Keine erfundenen Bewertungen, Öffnungszeiten oder Ortsfakten aus dem ImageGen-Mockup in Produktdaten übernehmen.
- Bestehende Funktionen, Navigation, Daten, Sync, Share Extension, Deep Links, Accessibility-IDs und unterstützte Ausrichtungen erhalten.

## Vorgeschlagene Umsetzungsabschnitte / Issue-Entwürfe

Linear ist in dieser Umgebung nicht verbunden; dies sind lokale Issue-Entwürfe und keine angelegten Linear-Issues.

### 1. Gemeinsames Designsystem auffrischen

**Ziel:** Neue visuelle Richtung über ein zentrales SwiftUI-/UIKit-Designsystem in `Album/Stitch/Stitch.swift` und den gemeinsamen Komponenten konsistent machen.  
**Umfang:** Farbrollen für helle, klare Reiseoberflächen; Typografierollen; Spacing-, Radius-, Border- und Elevation-Tokens; Foto- und Aktionskomponenten; zentrale Motion-/Haptikrollen.  
**Akzeptanz:** Primärscreens und Sheets teilen sichtbare Designrollen; keine duplizierten ad-hoc Farben/Buttons; Dynamic Type, Kontrast und Reduce Motion bleiben funktionsfähig.  
**Prüfung:** native iPhone-Screen-Tour, Xcode-Build und relevante iOS-Tests, Screenshotvergleich, Accessibility- und Reduce-Motion-Tests.

### 2. Reiseübersicht und Ideenfluss neu gestalten

**Ziel:** Reiseübersicht und Ideen wirken wie ein hochwertiges, lebendiges Reisejournal.  
**Umfang:** Reise-Header, Fotos und Tagesübersicht überarbeiten; Ideen-/Sammlungskarten, Filter/Leerzustände und Entscheidungsbuttons an das neue System angleichen; swipe states inklusive „Dafür“, „Dagegen“, „Offen“ und Undo.  
**Akzeptanz:** Bestehende Flows bleiben bedienbar, Text ist ausgewogen, Bild-/Text-Hierarchie klar und Aktionen erklären ihren Zustand.  
**Prüfung:** Tests für Screen-Tour, Idee entscheiden/undo, Sammlung und große Dynamic-Type-Stufen.

### 3. Karte, Ortsdetail und Planübergänge polieren

**Ziel:** Pin, ausgewählter Listeneintrag, Ortsdetail und Tagesplan fühlen sich wie ein zusammenhängender Flow an.  
**Umfang:** Karte/Drawer-Komposition, Filterchips, Zeilen, Auswahlzustände, Detailblatt und „Zum Plan“ sowie sichtbare Zustandsübergänge.  
**Akzeptanz:** Kein überdeckter letzter Listeneintrag, keine abgeschnittenen Filter, stabile Rotation; Pin- und Listen-Auswahl synchron; Liste kann vollständig geschlossen und kontrolliert wieder geöffnet werden.  
**Prüfung:** Map-UI-Journeys, beide Querformatseiten, Portrait, ausgewählter Pin, Sheet-Detents und VoiceOver.

### 4. Unterstützende Screens angleichen und Motion verifizieren

**Ziel:** Sammlung, Teilen, Unterlagen, Editoren und Assistent gehören sichtbar zum selben Album.  
**Umfang:** Geteilte Bausteine/Headers/Sheets anwenden, zentrale Motion-/Haptikrollen sowie reduzierte Bewegung.  
**Akzeptanz:** Keine isolierten Legacy-Oberflächen; Feedback ist sparsam und an tatsächliche Zustandswechsel gekoppelt; sämtliche unterstützten Ausrichtungen bleiben brauchbar.  
**Prüfung:** relevante bestehenden iOS-Tests, UI-Screen-Tour, Light/Dark, Reduce Motion und Querformat.

## Arbeitsstatus

- [x] Separaten Branch `design/album-visual-refresh` samt isoliertem Worktree erstellt.
- [x] Aktuellen Arbeitsstand in den Worktree übernommen; Hauptordner nicht verändert.
- [x] ImageGen-Konzept für Reiseübersicht, Karte und Ortsdetail erzeugt.
- [x] Claude-Prototyp als zusätzliche Bewegungsreferenz ausgewertet.
- [x] Issue-Entwürfe und Akzeptanzziele festgehalten.
- [ ] Natives SwiftUI-/UIKit-Designsystem und primäre Screens überarbeiten.
- [ ] Unterstützende Screens und Motion angleichen.
- [ ] Build, Tests, Screen-Aufnahmen und Diff prüfen.
