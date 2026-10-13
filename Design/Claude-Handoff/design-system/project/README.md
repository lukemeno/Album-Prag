Album ist ein privates Reisejournal für zwei Menschen. Die erste Reise führt nach Prag, vom 4. bis 9. Oktober 2026. Das System beschreibt die **native iOS-App (SwiftUI/UIKit)**. Alle Werte stammen aus `Album/Stitch/Stitch.swift`, `Album/Design.swift` und `Album/AlbumRoot.swift`; die Proportionen folgen den verbindlichen Referenzscreens (`approved-native-design.png`, `2026-10-04-reference-reise|map|detail.png`). Die Web-Klassen in `components/bundle.css` sind statische Nachbildungen. Jede Klasse nennt ihr SwiftUI-Gegenstück.

Gefühl: **cozy und sweet, leicht, fotoorientiert, hochwertig.** Helle Flächen, Navy und Hellblau, große Fotos. Die Partnerschaft ist spürbar, steht aber nie im Mittelpunkt.

## Grundregeln

1. **Referenz vor Interpretation.** Reise, Karte und Ortsdetail entsprechen den Referenzscreens in Proportion, Typografie, Radien und Fotoanteil. Neue Screens werden ausschließlich aus diesen Bausteinen abgeleitet.
2. **Genau drei Tabs:** Reise, Ideen, Karte. Dazu kommen „Idee einwerfen“ (+), der Clipboard-Hinweis und der KI-Kreis. Weitere Haupt-Tabs gibt es nicht.
3. **Der KI-Kreis bleibt unverändert** (48 pt, `action-fill`, `sparkles`, unten rechts). Er ist das einzige freigegebene Element des Zwischenstands.
4. **Nichts erfinden.** Keine Bewertungen, Sterne, Profilfotos, Öffnungszeiten, Flugdaten oder Distanzen ohne Datenquelle. Fehlende Werte zeigen „—“ oder einen ehrlichen Leerzustand.
5. **Unterwegs schlägt schön.** Alles Wichtige ist einhändig erreichbar (unteres Drittel, 44-pt-Ziele) und funktioniert offline.
6. **Jede Geste hat einen Knopf.** Wischen auf Ideen, Ziehen des Ortsblatts und der Besucht-Schieber haben gleichwertige Schaltflächen und VoiceOver-Aktionen.

## Sprache und Ton

- Deutsch, du-Form an die einzelne Person, „ihr“ für beide: „Wie heißt du?“, „Warum möchtet ihr dorthin?“
- Kurz, konkret, freundlich. Keine Ausrufezeichen-Euphorie, keine Emojis, kein Marketing.
- Knöpfe sind Verben oder Ziele: „Einladen“, „Alle öffnen“, „Tage planen“, „Als besucht markieren“, „Plan prüfen und übernehmen“.
- Entscheidungen heißen **Ja · Nein · Offen** (Code und PRODUCT.md). „Dafür/Dagegen“ dient höchstens als VoiceOver-Hinweis.
- Zustände sagen, was bleibt: „Links und Nachrichten bleiben hier, auch wenn du gerade offline bist.“ „Er verschwindet auch auf dem anderen iPhone.“
- Daten im deutschen Format: „4.–9. Oktober“, „Mo, 5. Okt“, Kacheln in Versalien „5. OKT“. Ortsnamen so, wie sie gespeichert sind (z. B. „Altstädter Ring“, „Letná Park“, „Speculum Alchemiae“).

## Farbe

- Grund immer `paper`. Karten, Pillen, Felder und Tab-Leiste auf `card` mit 1 pt `rule`, schwebende Elemente mit `elevation-floating` statt Kontur.
- Schrift und Icons in `ink` (Navy), Metadaten in `ink-soft`. Kein reines Schwarz.
- **Hellblau `selection`** markiert Auswahl und die Hauptaktion: gewählte Listenzeile, heutige Tageskachel, „Plan ändern“.
- **Navy-Fläche `action-fill`** für die eine Primäraktion, den gewählten Chip, den KI-Kreis und Toasts.
- **Koralle `red`** ist die zweite Tinte für Orts- und Tagesaktionen („Tage planen“, „Route“, „5. Okt“, „Als besucht markieren“) und für Fehlertexte. Nie als große Fläche.
- **`teal`** steht für besucht, gespeichert und abgeglichen, immer zusammen mit Häkchen oder Wort.
- Kategorien haben feste Pastelle (`mat-rose` Essen, `mat-sky` Sehenswert, `mat-butter` Aussicht, `mat-lilac` Unterkunft, `mat-mint` Shopping). Sie erscheinen nur als Flächen, nie als Schrift.
- `system-blue` nur auf der Karte (ausgewählter Pin, Standort), `badge` nur am Ideen-Tab.
- Dunkelmodus: Alle Farbtokens haben Dunkelwerte. `action-fill` bleibt im Code Navy und braucht dort eine `rule`-Kontur. Das gilt auch für den KI-Kreis, ohne seine Form zu ändern.

## Typografie

- **Fraunces SemiBold** (`display`, `hero-title`, `sheet-title`, `title`, `section`) für App-Titel, Reisename und Abschnittsüberschriften. Nur kurze Titel.
- **Instrument Serif** (`place-xl` bis `place-s`) **ausschließlich für Ortsnamen**: Ortsdetail 44 pt, Ideenkarte 32 pt, Listenzeile 24 pt, kompakte Zeile 19 pt.
- **SF Pro** für alles Lesbare und Bedienbare: `body` 17, `label` 15 semibold für Buttons und Chips, `meta` 15 in `ink-soft`, `footnote` 13, `caption` 12, `eyebrow` 13 in Versalien mit +0.6 Laufweite.
- **SF Mono** (`ticket`) nur für Codes, Zeiten und Buchungsnummern.
- Alle Stile wachsen mit Dynamic Type (`relativeTo:`). Layouts dürfen in der Höhe wachsen, nie abschneiden.

## Raster, Abstände, Radien

- Seitenrand `page` = 20 pt überall. Abstände `space-xxs` 4 · `space-xs` 8 · `space-s` 12 · `space-m` 16 · `space-l` 24 · `space-xl` 32 · `space-xxl` 48.
- Radien: `radius-thumb` 12 (Thumbnails, Pins, Tickets), `radius-tile` 16 (Tages- und Aktionskacheln), `radius-card` 22 (Titelfoto, Karten, gewählte Zeile), `radius-floating` 28 (Sheets), `radius-pill` für Buttons, Chips, Suche und Tab-Leiste. Immer kontinuierliche Kurve (`style: .continuous`).
- Feste Größen: Tippziel `size-touch` 44, Button `size-button` 52, Ortszeilen-Thumbnail `size-row-thumb` 64, Pin `size-pin` 56 (gewählt 64), Tab-Leiste `size-tabbar` 62, Titelfoto `size-hero` 300.

## Höhen und Schatten

Drei Stufen, Schattenfarbe `shadow-ink` statt Schwarz: `elevation-flat` (Kontur), `elevation-pinned` (Pins, Marken, Kreise auf Fotos), `elevation-floating` (Tab-Leiste, Suche, KI-Kreis, Toast, Drawer). Mehr gibt es nicht.

## Fotos

- Fotos tragen die App. Titelfoto auf „Reise“ 362 × 300, Ortsdetail randlos oben, Ideenkarte 300 pt hoch, Tageskachel 92 pt.
- Verlauf nur unten und nur schwarz (0 → 84 %). Text darauf in `on-accent`.
- Bildquellen in fester Reihenfolge: Linkvorschau, Wikimedia, Tripadvisor (aus), eigenes Foto, Apple Look Around bzw. Kartensnapshot, gestalteter Platzhalter (`paper-deep` + Fotosymbol).
- Credits als dunkle Kapsel (`scrim` 68 %) unten links: „Foto: Thomas Fabian · CC BY-SA 2.0“, „Bild der Quelle“, „Apple Karten · Straßenansicht“.
- Unsichere Fotos werden nie still übernommen. Sie kommen in die Bildwahl („Prüfe, ob das Foto wirklich … zeigt.“). Instagram wird nicht ausgelesen.

## Bewegung und Haptik

| Rolle | Wert (SwiftUI) | CSS-Nachbildung | Einsatz |
|---|---|---|---|
| press | spring(0.25, 0.7) | `--motion-press` | Buttons 0.97, Icon-Buttons 0.94 |
| panel | spring(0.42, 0.88) | `--motion-panel` | Sheets, Ortsblatt-Detents, Tab-Leiste kompakt |
| decisionReturn | spring(0.4, 0.72) | `--motion-return` | Ideenkarte federt zurück |
| reducedFade | easeInOut 0.2 s | `--motion-fade` | Ersatz für alles bei Reduce Motion |

- Pins landen leicht federnd, Routen zeichnen sich, die gewählte Abstimmung wächst und die anderen treten zurück.
- Haptik nur bei echten Zustandswechseln: Einrasten des Ortsblatts, Entscheidung, Besucht, Clipboard-Hinweis.
- **Reduce Motion:** keine Skalierung, keine Flugbahnen, keine Schlitten. Stattdessen eine 0.2-s-Überblendung.

## Ikonografie

- In der App **SF Symbols** in `ink`: `suitcase.fill`, `tray.fill`, `map.fill` (Tabs), `sparkles` (KI-Kreis), `fork.knife`, `building.columns`, `binoculars`, `bed.double`, `bag`, `sparkle` (Kategorien), `location.north`, `figure.walk`, `calendar`, `person.2`, `plus`, `ellipsis`, `magnifyingglass`, `slider.horizontal.3`, `chevron.right.2`, `arrow.uturn.left`, `wifi.slash`.
- Die Vorschauen hier verwenden **nachgezeichnete Linien-SVGs** als Ersatz, weil SF Symbols im Web nicht verfügbar sind. Für die App gelten immer die SF-Symbol-Namen oben.
- Plattformlogos (TikTok, Instagram) werden nicht nachgebaut. Quelle = Wort-Badge.
- Kein Zwei-Türme-Logo im Interface. Der Name „Album“ steht als Fraunces-Wortmarke.

## Zugänglichkeit

- Kontrast (gemessen): `ink` auf `paper` 16.7:1, `red` 4.85:1, `teal` auf `card` 5.6:1. **`ink-soft` (Codewert) erreicht auf `card` 4.68:1, auf `paper` nur 4.48:1 und auf `selection` 4.16:1.** Dort Metadaten ab 15 pt semibold oder in `ink` setzen. Empfehlung an den Code: `ink-soft` hell auf `#6b6b70` (≈ 5.0:1 auf `paper`).
- Dunkelmodus: `action-fill` hat zu `paper` nur 1.01:1, deshalb bekommen Navy-Flächen dort immer eine `rule`-Kontur.
- Fokusring 2 pt `system-blue`, 3 pt Abstand.
- Jede Ikone hat ein deutsches `accessibilityLabel` („Reise-Assistent“, „Teilnehmende verwalten“, „Karte filtern“). Wischgesten sind zusätzlich als Accessibility-Aktionen verfügbar.
- Hoch- und Querformat in beiden Drehrichtungen. Im Querformat wird das Ortsblatt zum Panel links.

## Komponenten → Code

| Komponente | SwiftUI-Quelle |
|---|---|
| Button, IconButton, SectionTitle, Stamp, TicketCard | `Album/Stitch/Stitch.swift`, `BoardingPass.swift` |
| PhotoCard, ImageChoice | `Album/Design.swift`, `PlaceEditor.swift`, `PlaceImageService.swift` |
| TabBar, AssistantButton, Toast (Clipboard), TextField | `Album/AlbumRoot.swift` |
| ParticipantRow, DayTile | `Album/Stitch/ReiseView.swift` |
| PlaceRow, Chip, Sheet, MapPin, ActionTile | `PlacesDrawer.swift`, `TripMapView.swift`, `MapPinClustering.swift` |
| IdeaCard, DecisionBar, SegmentedControl | `InboxView.swift`, `LetterSlot.swift` |
| CollectionPost | `CollectionViews.swift`, `CollectionStore.swift` |
| AssistantMessage, AssistantAction, Composer | `AssistantView.swift`, `AssistantActions.swift` |
| DocumentCard | `TripDocumentsView.swift`, `TripDocumentParser.swift` |
| VisitSlider, SyncIsland | `Album/Stitch/VisitedTrack.swift`, `SyncIsland.swift` |
| StateView, Badge, ListRow, ConfirmDialog | neu vereinheitlicht aus verstreuten Leer- und Formularzuständen |
