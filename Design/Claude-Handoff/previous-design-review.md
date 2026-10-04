Die Plan-Datei lässt sich in dieser Session nicht schreiben (Write ist deaktiviert) — hier ist der vollständige Befund und Plan.

# Album — Design- und Motion-Review

**Methodik:** Alles unter „Belegt" stammt aus Quellcode oder den vorhandenen Laufzeit-Screenshots in `.qa-shots/` (02.–03.10.2026), die ich angesehen habe. Alles unter *Empfehlung* ist Gestaltungsvorschlag.

## Kernbefund

Das Problem ist nicht fehlender Geschmack, sondern **fehlende Durchsetzung**. Es gibt ein dokumentiertes System (`DESIGN.md`, `.impeccable/design.json`, `Album/Stitch/Stitch.swift`) — aber jeder Screen hat eigene Schriftgrößen, eigene Federn und eigene Farben mitgebracht. Genau das erzeugt „Ansammlung einzelner Screens".

---

## 1 · Bewegung ist praktisch nicht tokenisiert (belegt)

- **79 Animationsstellen**, davon **31 verschiedene Spring-Paare** und **16 verschiedene ease-Dauern**. `Stitch.Motion` (`Album/Stitch/Stitch.swift:101-106`) hat 4 Werte.
- Die 15 `Stitch.Motion`-Verwendungen sind meist nur der *Reduce-Motion-Zweig*, während der Normalfall ein Literal bleibt — z. B. `ReiseView.swift:325`, `VisitedTrack.swift:43`, `SyncIsland.swift:89`.
- `spring(0.36, 0.78)` steht 5× unabhängig im Code (`InboxView.swift:279`, `VisitedTrack.swift:79`, `PhotoStack.swift:130`, `LetterSlot.swift:174`, `InboxView.swift:614`) — dieselbe Geste „federt zurück", fünfmal von Hand.
- Die Reduce-Motion-Gabel wird 32× als Ternary wiederholt; `QA-MOTION-INVENTORY.md` belegt drei Stellen, die trotzdem animieren (`LetterSlot:133-136`, `SyncIsland:142`, `VisitedTrack:63`).
- 15 `.sensoryFeedback`-Trigger ohne gemeinsame Regel oder Debounce.

## 2 · Token-Forks (belegt)

| Fundstelle | Befund |
|---|---|
| `PlacesDrawer.swift:38-41` | Privates zweites Rot (#A03222) und zweites Grau (#544D46), 7× benutzt |
| `AlbumApp.swift:35` vs. `AlbumRoot.swift:71` | Zwei Tints (`redFill` vs. `red`) — im Dunkelmodus zwei verschiedene Farben |
| `AlbumRoot:94`, `TripMapView:503`, `AssistantView:121`, `Design:62/128` | Rohes `.white` statt `onAccent` |
| `CollectionViews:50/333/335` | `cornerRadius: 8` und `12` + `.thinMaterial` — off-token |
| `AssistantView:108` | `.bordered` als fünfter Buttonstil |
| ≥8 Stellen | Literal `spacing: 2` als inoffizielles Token |

**Ein Ortsname in einer Zeile hat drei Schriften:** `Face.place(21)` (`ReiseView:474`, `PlacesDrawer:681`), `.body.weight(.semibold)` (`PlacesDrawer:655`, `DayPlanPreview:40`, `TripMapView:452`), `.headline` (`CollectionViews:53`, `AssistantView:232`).

**Abschnittsüberschriften haben vier Stile:** `Face.title(22)` (SectionTitle), `Face.title(19)` (`PlacesDrawer:614`), `.headline` (`CollectionViews:166/177`), `.caption.semibold` (`AssistantView:138/148/174`).

## 3 · Hülle und Navigation (belegt)

- **Zwei Titelsysteme.** Alles ist `.inline` — außer `InboxView:118` und `CollectionViews:34/84`, die `navigationTitle` ohne Display-Mode setzen. In `.qa-shots/03-ideen.png` steht „Ideen" in SF Pro Bold, in `.qa-shots/01-reise.png` steht „Prag" in Fraunces 48 im Inhalt.
- **Sammlung ist Tab-im-Tab.** Segment in `InboxView:53-60`, darunter setzt `CollectionHomeView` *eigenen* Titel und *eigene* Toolbar. Titel und Toolbar wechseln unter einem stehenden Segment.
- **Zwei runde Knöpfe übereinander.** In `01-reise.png` sitzt der System-`+` (Glas) direkt über dem `HeaderIconButton` (Karte + Kontur) aus `ReiseView:76-82`. Gleiche Form, zwei Materialien. Auf der Karte dasselbe mit `+` über `MapUserLocationButton`.
- **Blätter ohne Vertrag.** `presentationDetents` nur 3× gesetzt; Drag-Indicator mal versteckt, mal sichtbar, meist ungesetzt; Kopfzeile mal „× + Bearbeiten", mal „× + Titel + Bearbeiten", mal nur „×".
- **Orientierung:** alle vier Richtungen sind in `Info.plist`/`project.yml` deklariert — angepasst ist nur die Karte. Einzige Lesebreite der App: `TripMemoriesView:43` (680 pt).

## 4 · Screen-Befunde aus den Screenshots (belegt)

- `map-half.png`: Die letzte Zeile der Ortsliste („Route · 4. Okt") liegt **unter der Tab-Leiste** — Innenabstand ist `Space.xl` = 32 pt (`PlacesDrawer:521`). *(Ursache noch zu bestätigen: `.clipped()` auf dem Drawer-Rahmen kann die Safe-Area-Weitergabe unterbinden.)*
- `map-half.png`: Aktiver Filter-Chip ist **schwarz gefüllt** (`Stitch.ink`, `PlacesDrawer:412`) — eine Flächenfarbe, die es als Rolle nicht gibt. Letzter Chip hart abgeschnitten. Drei Textaktionen + „×" in einer Kopfzeile, in drei Gewichtungen.
- `map-landscape-left.png`: Die Tab-Leiste überdeckt im Querformat das Ortsblatt, eine Zeile ist angeschnitten.
- `05-ortsdetail.png`: Ohne Foto erzeugt der Verlauf (`Design.swift:118-123`) eine **harte Kante** quer über den Platzhalter. Darunter drei gleich aussehende graue Faktenzeilen, zwei volle Pillen übereinander, dann großes Nichts.
- `B-1-stapel.png`: „Foto: Demo" steht doppelt (`TripMapView:636-647`).
- `01-reise.png`: Das Datum steht **dreifach**. Der Tagesstreifen nutzt 38-pt-Kacheln mit um 90° gedrehten Wochentagen (`ReiseView:393-397`).
- `10-unterlagen.png` ist der stärkste Screen — er wird die Referenz.

**Ohne Beleg:** Sammlung und Assistent entstanden *nach* dem letzten Screenshot-Lauf (`.qa-shots` 13:19, `CollectionViews` 16:16, `AssistantView` 18:22). Deren Befunde sind rein quellcodebasiert.

---

## Leitidee

**Die Reise ist ein Briefmarkenalbum — das Album ist der Inhalt, iOS ist der Rahmen.** Systemhülle (Tab-Leiste, Nav-Leiste, Blätter, Karte) bleibt Apple; das Papier beginnt im Inhalt. Die App baut keine Systemelemente nach.

1. Ein Titel, eine Stimme — jeder große Text Fraunces, jeder Ortsname Instrument Serif, alles Bedienbare SF Pro.
2. Eine primäre Handlung pro Bildschirm.
3. Rot ist knapp — keine zweite Flächenfarbe.
4. Bewegung erklärt einen Zustandswechsel und gehört zu genau einer von acht Rollen.
5. Jede Geste hat einen Knopf (in der Komponente verankert, nicht pro Screen).
6. Jeder Screen kennt sein Querformat: Lesebreite begrenzen **oder** zweispaltig.

## Ziel-Tokensystem (additiv in `Stitch.swift`)

- **Abstand:** Skala bleibt; neu `tight = 2`. Rhythmus verbindlich: Überschrift→Inhalt 12, Karte→Karte 12, Abschnitt→Abschnitt 32, Rand 20.
- **Typografie als Modifier** (`Stitch.Text`), nicht als freies `.font()`: `screenTitle` Fraunces 36 *(Empfehlung: von 48 herunter — der Wunsch „moderate Schriftgrößen" betrifft genau diesen Wert)*, `sectionTitle` 20, `placeHero` Serif 28, `placeRow` Serif 20, `body`/`meta`, `label` (Buttonregel bleibt), `code`.
- **Farbe:** neu `inkSoftOnDeep`/`redOnDeep` (löst den Drawer-Fork auf, mit gemessenem Kontrast), `onPhoto`/`photoScrim`. Regel: ausgewählter Zustand ist immer `redFill`+`onAccent`, nie schwarze Fläche. Ein Tint.
- **Fläche:** neu `Stitch.Surface` mit genau drei Rollen (`paper`, `card`, `overlay` = `.ultraThinMaterial`+`Radius.card`) — Material wird nicht mehr pro Screen gewählt.

## Komponenten

Unverändert bleiben alle Markenträger (StampFrame, Ticket/BoardingPass, Postmark, Perforation, die drei Buttonstile, PhotoStack, VisitedTrack, SyncIsland, LetterSlot, PlacesDrawer).

Neu, jeweils einmal gebaut: `ScreenTitle` (ersetzt 5 Fassungen), `SheetScaffold` (11 Blätter), `AlbumRow` (7 Zeilenfassungen), `EmptyState` (5), `AlbumBanner` (4), `FactList`, `PhotoScrim`, `AlbumChip`.

## Motion-Spezifikation

| Rolle | Wert | Wofür |
|---|---|---|
| `press` | spring 0.25/0.75 | Druck, Chip |
| `change` | spring 0.38/0.90 | Tag, Filter, Liste |
| `panel` | spring 0.42/0.88 *(besteht)* | Blatt, Detent |
| `enter` | spring 0.45/0.80 | Pin landet, Banner, Insel |
| `exit` | easeIn 0.26 | Marke fliegt |
| `commit` | spring 0.30/0.60 | Stempel, Besucht, Herzen |
| `camera` | easeInOut 0.50 | Kartenflug, Cluster |
| `fade` | easeInOut 0.20 *(besteht)* | Überblenden |

Zentrale Gabel `Stitch.Motion.resolve(role:reduceMotion:)` + `View.albumAnimation(_:value:)` ersetzt 32 Ternaries — die Reduce-Motion-Entscheidung steht einmal je Rolle, nicht 79× im Screen. Haptik als fünf Rollen (`select`, `arm`, `commit`, `success`, `land`) mit Debounce — adressiert die in `QA-MOTION-INVENTORY.md` offene Mehrfachauslösung strukturell. Gestenschwellen bleiben; der Achsen-Lock aus `PlacesDrawer.updateDrag` wird auch für `PhotoStack` und `InboxView` genutzt. `LetterSlot`-Auto-Finish bleibt unverändert — der Fixplan nennt es ausdrücklich als mögliche Absicht.

## Arbeitspakete

**A — Grundlage + Beweislage** (additiv, kein sichtbares Verhalten): Tokens, Motion-Rollen, Haptik-Rollen, doppelter Tint weg. `testScreenTour` um Sammlung/Assistent/Erinnerungen und Querformat erweitern.
→ *Akzeptanz:* Baseline-Konfiguration unverändert grün, neue Screenshots existieren.

**B — Bewegung/Haptik vereinheitlichen** (mechanisch): alle 79 Stellen auf Rollen. Grenze: die fünf durch `AlbumMotionUITests` belegten Abläufe dürfen ±20 % Dauer nicht überschreiten (die Tests takten mit festen `asyncAfter`).
→ *Akzeptanz:* kein `spring(response:` außerhalb `Stitch.swift`; Konfigurationen „Focused Motion Layout" **und** „Reduced motion" grün, B/C/D/E/F-Shots verglichen.

**C — Hülle:** `ScreenTitle` + inline überall, geschachtelter Titel/Toolbar in Sammlung weg, `SheetScaffold` für alle Blätter, Teilen in die Toolbar, `SyncIsland` in den Inhaltskopf, Safe-Area statt fester Abstände, Querformatregel (680 pt / zweispaltig).
→ *Akzeptanz:* Tour in beiden Orientierungen ohne Aktion unter der Tab-Leiste, ohne zweiten Systemtitel; alle `accessibilityIdentifier` unverändert.

**D — Reise + Karte:** Tagesleiste als gleich breite Kapseln ohne gedrehten Text, Datum einmal, `AlbumChip`, Drawer-Kopf auf Titel + Überlaufmenü + „×", `AlbumRow`.
→ *Akzeptanz:* Accessibility-Konfiguration grün, Kontraste der `*OnDeep`-Werte gemessen und in `DESIGN.md` notiert.

**E — Detail/Ideen/Sammlung/Assistent/Teilen/Planänderung:** `PhotoScrim`, `FactList`, `EmptyState`, `AlbumBanner`; Credits entdoppeln; Assistent-Plan auf dieselbe Vorschau wie `DayPlanPreview`; `DESIGN.md` + `design.json` nachziehen.

## Verifikation

Nutzt die vorhandene Infrastruktur — nichts Neues nötig. `xcodebuild test -scheme "Album QA"` über alle vier Konfigurationen des `Album-QA-Full.xctestplan` (Baseline, Motion, Accessibility, Reduced Motion). `ALBUM_SHOT_DIR` ist überall gesetzt; `testScreenTour` erzeugt `01`–`12`, die Motion-Tests `B`–`F`. Der heutige `.qa-shots/`-Satz ist die Baseline; jedes Paket erzeugt ihn neu, Abweichungen werden benannt. **Nicht belegbar im Simulator:** physische Haptik und echte OS-Reduce-Motion-Einstellung — bleibt offen.

## Risiken

- UI-Tests hängen an `accessibilityIdentifier` (`Inbox-Ticket`, `Besucht-Spur`, `map-places-list`, `Abgleich-Insel`, `place-row-*`, `Ideas-Segment`) → keine Umbenennung, neue Komponenten übernehmen sie wörtlich.
- `matchedGeometryEffect`-IDs tragen den Kapsel↔Blatt-Übergang → in A/B nicht anfassen.
- Offene Fixpläne (FIX-DRAWER-INPUT, FIX-CLUSTER-SELECTION, FIX-EDITOR) berühren dieselben Dateien → D nach FIX-DRAWER-INPUT, E nach FIX-EDITOR.
- Target ist iOS 17, Screenshots zeigen iOS 26 (`sharedBackgroundVisibility` in `ReiseView:253`) → keine neuen iOS-26-exklusiven APIs.
- Paralleler Expo-Client (Schritt 2 = „visual tokens") → `.impeccable/design.json` wird in E die maßgebliche Tokenquelle, Rollen sprachneutral benennen.

**Reihenfolge mit den wenigsten Regressionen:** A → B → C → D → E. A und B zusammen sind schon spürbar: einheitliche Bewegung und eine Schriftstimme machen den größten Teil des „nicht stimmig"-Gefühls aus, ohne einen einzigen Screen umzubauen.

**Zur Durchführung schlage ich den Skill `impeccable` vor** — `critique` für die Bestandsaufnahme je Screen, dann `shape` für Reise/Karte (Paket D), `polish` für die Komponenten (C/E) und `animate` für die Motion-Spezifikation (B). Das passt, weil die Befunde oben schon die Inventur sind und impeccable genau auf dieser Ebene weiterarbeitet.